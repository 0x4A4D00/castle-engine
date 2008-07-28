{
  Copyright 2003-2005,2008 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "Kambi VRML game engine"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

{ @abstract(Calculating normal vectors for various 3D objects,
  with appropriate smoothing.)

  This is developed for VRML / X3D geometric primitives,
  although some parts are not coupled with VRML stuff.
  So it can be used in other situations too. }
unit NormalsCalculator;

interface

uses SysUtils, KambiUtils, VectorMath, VRMLNodes;

{ Calculate normal vectors for indexed faces, smoothing them according
  to CreaseAngleRad.

  CoordIndex are indexes to Vertices. Indexes < 0 are used to separate
  faces. So this works just like VRML IndexedFaceSet.coordIndex.

  It's smart and ignores incorrect indexes (outside Vertices range),
  and incorrect faces triangles (see IndexedPolygonNormal).
  It's guaranteed to work Ok for convex faces, although for non-convex faces
  results are also acceptable (as results of IndexedPolygonNormal
  should be acceptable for even non-convex faces).

  Returns a list of normalized vectors. This has the same length
  as CoordIndex, and should be accessed in the same way.
  This way you (may) have different normal vector values for each
  vertex on each face, so it's most flexible.
  (For negative indexes in CoordIndex, corresponding value in result
  is undefined.)

  Remember it's your responsibility to free result of this function
  at some point.

  @param(FromCCW Specifies whether we should generate normals
    pointing from CCW (counter-clockwise) or CW.)

  @param(CreaseAngleRad Specifies in radians what is the acceptable
    angle for smoothing adjacent faces. More precisely, we calculate
    for each vertex it's neighbor faces normals. Then we divide these
    faces into groups, such that each group has faces that have normals
    within CreaseAngleRad range, and this group results in one smoothed
    normal. For example, it's possible for a vertex shared by 4 faces
    to be smoothed on first two faces and last two faces separately.

    Note that when creaseAngleRad >= Pi, you wil be better off
    using CreateSmoothNormals. This will work faster, and return shorter
    normals array (so it's also more memory-efficient).) }
function CreateNormals(CoordIndex: TDynLongintArray;
  vertices: TDynVector3SingleArray;
  creaseAngleRad: Single;
  FromCCW: boolean): TDynVector3SingleArray;

{ Calculate flat per-face normals for indexed faces.

  Note that the result is not a compatible replacement for CreateNormals,
  as it's length is the number of @italic(faces). For each face, a single
  normal is stored, as this is most sensible compact representation.
  Using something larger would be a waste of memory and time. }
function CreateFlatNormals(coordIndex: TDynLongintArray;
  vertices: TDynVector3SingleArray;
  FromCCW: boolean): TDynVector3SingleArray;

{ Calculate always smooth normals per-vertex, for VRML coordinate-based
  node. We use TVRMLGeometryNode.CoordPolygons for this, so the node class
  must implement it.

  Note that the result is not a compatible replacement for CreateNormals,
  as this generates Coordinates.Count normal vectors in result.
  You should access these normal vectors just like Node.Coordinates,
  i.e. they are indexed by Node.CoordIndex if Node.CoordIndex <> nil.

  If Node.Coordinates is @nil (which means that node is coordinate-based,
  but "coord" field is not present), we return @nil. }
function CreateSmoothNormalsCoordinateNode(
  Node: TVRMLGeometryNode;
  State: TVRMLGraphTraverseState;
  FromCCW: boolean): TDynVector3SingleArray;

implementation

uses VRMLFields;

{$define read_interface}
{$define read_implementation}

type
  TFace = record
    StartIndex: integer;
    IndicesCount: integer;
    Normal: TVector3Single
  end;
  PFace = ^TFace;

  TDynArrayItem_1 = TFace;
  PDynArrayItem_1 = PFace;
  {$define DYNARRAY_1_IS_STRUCT}
  {$I DynArray_1.inc}
  type TDynFaceArray = TDynArray_1;

function CreateNormals(CoordIndex: TDynLongintArray;
  vertices: TDynVector3SingleArray;
  CreaseAngleRad: Single;
  FromCCW: boolean): TDynVector3SingleArray;
var
  faces: TDynFaceArray; { lista faces }

  { Lista dlugosci vertices.Count ktorej kazdy element mowi do jakich
    faces nalezy ten vertex (to znaczy podaje indeksy do tablicy faces[]).

    Jezeli faces byly nieprawidlowe (w ktorym to przypadku staramy sie
    w calym tym module zachowac mozliwie sensownie) to dany vertex moze
    byc wiecej niz jeden raz na jednym faces - to nic, w tej tablicy
    bedzie odpowiednie face wymienione tylko raz. }
  verticesFaces: array of TDynIntegerArray;

  normals: TDynVector3SingleArray absolute result;

  CosCreaseAngle: Single;

  procedure CalculateFacesAndVerticesFaces;
  var thisFace: PFace;
      i, thisFaceNum: integer;
  begin
   i := 0;
   while i < CoordIndex.Count do
   begin
    thisFaceNum := faces.Length;
    faces.IncLength;
    thisFace := faces.Pointers[thisFaceNum];

    thisFace^.StartIndex := i;
    while (i < CoordIndex.Count) and (CoordIndex[i] >= 0) do
    begin
      { Two tests below secure us from invalid CoordIndex values:
        1. of course, each CoordIndex[] value must be within range.
        2. in a correct face, each vertex may occur at most once.

        We have to deal with VRML data supplied by user here,
        so we have to secure against invalid values here.

        Note that we cannot remove wrong indexes here
        (like CoordIndex.Delete(i, 1)). While tempting, removing
        bad indexes is not so easy: for example in IndexedFaceSet
        we would have to remove also appropriate textureCoord, normal
        and material indexes. Moreover, I decided that my engine doesn't
        ever change VRML data implicitly (even when this data is clearly
        incorrect...). So we cannot do such things. }

      if (CoordIndex[i] < Vertices.Count) and
         (VerticesFaces[CoordIndex[i]].IndexOf(thisFaceNum) = -1) then
        VerticesFaces[CoordIndex[i]].AppendItem(thisFaceNum);
      Inc(i);
    end;

    { licz thisFace.IndicesCount
      Skompletowalismy jedno face : to indeksy od StartIndex do i-1 }
    thisFace^.IndicesCount := i-thisFace^.StartIndex;

    { licz thisFace.Normal }
    thisFace^.Normal := IndexedPolygonNormal(
      @(CoordIndex.Items[thisFace^.StartIndex]),
      thisFace^.IndicesCount,
      Vertices.ItemsArray, Vertices.Count,
      Vector3Single(0, 0, 1));

    { przejdz do nastepnej sciany (omin ujemny indeks na ktorym stoimy;
      ew. przejdz z CoordIndex.Count do CoordIndex.Count+1, co niczemu nie szkodzi) }
    Inc(i);
   end;
  end;

  procedure SetNormal(vertexNum: integer; const face: TFace; const Normal: TVector3Single);
  { ustaw normal w tablicy normals dla sciany face i vertexu numer vertexNum
      (vertexNum to indeks do tablicy vertices, czyli to samo co elementy
      CoordIndex).
    Poniewaz staramy sie zachowywac sensownie nawet dla nieprawidlowych faces
      wiec zakladamy tu ze dany vertex moze byc w jednej scianie wiecej niz jeden
      raz i ustawiamy normal dla wszystkich wystapien tego vertexa w tej face.
    Na koncu upewnia sie Assertem ze taki vertex w ogole byl (choc raz) w tej face-
      -wiec zawsze badz pewien ze vertexNum rzeczywiscie nalezy do tej sciany ! }
  var i: integer;
      vertFound: boolean;
  begin
   vertFound := false;
   for i := face.StartIndex to face.StartIndex +face.IndicesCount -1 do
    if CoordIndex.Items[i] = vertexNum then
    begin
     vertFound := true; { vertFound := true, ale to nic, szukamy dalej }
     normals.Items[i] := Normal;
    end;
   Assert(vertFound, 'Internal error - NormalsCalculator.SetNormal failed');
  end;

  procedure CalculateVertexNormals(vertexNum: integer);
  var
    { ustalane na poczatku na verticesFaces[vertexNum] }
    thisVertexFaces: TDynIntegerArray;

    function FaceCanBeSmoothedWithFaces(faceNum: integer;
      faceNums: TDynIntegerArray): boolean;
    { czy sciana faceNum moze byc smooth razem ze wszystkimi scianami z faceNums ?
      To tutaj uwzgledniamy creaseAngleRad. faceNum  i faceNums[] to
      indeksy do tablicy thisVertexFaces. }
    var i: integer;
    begin
     for i := 0 to faceNums.Count-1 do
      { I want to check that
          AngleRadBetweenNormals(...) >= CreaseAngleRad
        so
          ArcCos(CosAngleRadBetweenNormals(...)) >= CreaseAngleRad
        so
          CosAngleBetweenNormals(...) < CosCreaseAngle }
      if CosAngleBetweenNormals(
        faces.Items[thisVertexFaces.Items[faceNum]].Normal,
        faces.Items[thisVertexFaces.Items[faceNums[i]]].Normal) <
        CosCreaseAngle then
       Exit(false);
     result := true;
    end;

  var i, j: integer;
      { aktualna grupa faces co do ktorej ustalilismy ze na tym vertexie
        maja wspolny normal. Indeksy wskazuja na indeksy w verticesFaces[vertexNum].Count }
      smoothFaces: TDynIntegerArray;
      { true jezeli dla jakiejs sciany (i dla vertexa vertexNum oczywiscie)
        juz zapisalismy normal. }
      handledFaces: TDynBooleanArray;
      Normal: TVector3Single;
  begin
   thisVertexFaces := verticesFaces[vertexNum];

   smoothFaces := nil;
   handledFaces := nil;
   try
    handledFaces := TDynBooleanArray.Create(thisVertexFaces.Count);
    handledFaces.SetAll(false);
    smoothFaces := TDynIntegerArray.Create;

    for i := 0 to thisVertexFaces.Count-1 do
     if not handledFaces[i] then
     begin

      { ustal smoothFaces }
      smoothFaces.SetLength(1);
      smoothFaces[0] := i;

      for j := i+1 to thisVertexFaces.Count-1 do
       if (not handledFaces[j]) and FaceCanBeSmoothedWithFaces(j, smoothFaces) then
        smoothFaces.AppendItem(j);

      { zaznacz handled na true scianom ze smoothFaces i wylicz ich Normal }
      FillChar(Normal, SizeOf(Normal), 0);
      for j := 0 to smoothFaces.Count-1 do
      begin
       handledFaces[smoothFaces[j]] := true;
       VectorAddTo1st(Normal, faces.Items[thisVertexFaces[smoothFaces[j]]].Normal);
      end;
      NormalizeTo1st(Normal);

      { uzyj wyliczonego normala }
      for j := 0 to smoothFaces.Count-1 do
       SetNormal(vertexNum, faces.Items[thisVertexFaces[smoothFaces[j]]], Normal);
     end;
   finally
    smoothFaces.Free;
    handledFaces.Free;
   end;
  end;

var i: integer;
begin
 CosCreaseAngle := Cos(CreaseAngleRad);

 SetLength(verticesFaces, vertices.Count);

 normals := nil;
 faces := nil;

 try
  try
   { zainicjuj verticesFaces i faces }

   for i := 0 to vertices.Count-1 do
    verticesFaces[i] := TDynIntegerArray.Create;
   faces := TDynFaceArray.Create;

   { przegladnij CoordIndex i skompletuj zawartosc tablic faces i verticesFaces }
   CalculateFacesAndVerticesFaces;

   { teraz zainicjuj normals, bo CoordIndex.Items.Length zostalo juz ustalone
     i w CoordIndex nie bedziemy wprowadzac wiecej zmian }
   normals := TDynVector3SingleArray.Create(CoordIndex.Length);

   { for each vertex, calculate all his normals (on all his faces) }
   for i := 0 to vertices.Count-1 do CalculateVertexNormals(i);

   if not FromCCW then Result.Negate;
  finally

   { free verticesFaces and faces }
   for i := 0 to vertices.Count-1 do verticesFaces[i].Free;
   faces.Free;
  end;

 except FreeAndNil(normals); raise end;
end;

function CreateFlatNormals(CoordIndex: TDynLongintArray;
  vertices: TDynVector3SingleArray;
  FromCCW: boolean): TDynVector3SingleArray;
var
  i, StartIndex: integer;
  FaceNumber: Integer;
begin
  { CoordIndex.Length is just a maximum length, we will shrink it later. }
  result := TDynVector3SingleArray.Create(CoordIndex.Length);
  try
    FaceNumber := 0;

    i := 0;
    while i < CoordIndex.Count do
    begin
      StartIndex := i;
      while (i < CoordIndex.Count) and (CoordIndex.Items[i] >= 0) do Inc(i);
      Result.Items[FaceNumber] := IndexedPolygonNormal(
        @(CoordIndex.Items[StartIndex]),
        i - startIndex,
        Vertices.ItemsArray, Vertices.Count,
        Vector3Single(0, 0, 0));
      Inc(FaceNumber);

      Inc(i);
    end;

    Result.Length := FaceNumber;

    if not FromCCW then result.Negate;
  except FreeAndNil(result); raise end;
end;

{ CreateSmoothNormalsCoordinateNode ------------------------------------------ }

type
  TCoordinateNormalsCalculator = class
  public
    Normals: TDynVector3SingleArray;
    CoordIndex: TDynLongIntArray;
    Coord: TDynVector3SingleArray;

    procedure Polygon(const Indexes: array of Cardinal);
  end;

procedure TCoordinateNormalsCalculator.Polygon(
  const Indexes: array of Cardinal);
var
  FaceNormal: TVector3Single;
  { DirectIndexes is LongInt, not Cardinal array, since we cannot
    guarantee that CoordIndex items are >= 0. }
  DirectIndexes: array of LongInt;
  I: Integer;
begin
  SetLength(DirectIndexes, Length(Indexes));
  if CoordIndex <> nil then
  begin
    for I := 0 to Length(Indexes) - 1 do
      DirectIndexes[I] := CoordIndex.Items[Indexes[I]];
  end else
  begin
    for I := 0 to Length(Indexes) - 1 do
      DirectIndexes[I] := Indexes[I];
  end;

  FaceNormal := IndexedPolygonNormal(
    PArray_LongInt(DirectIndexes), Length(DirectIndexes),
    Coord.ItemsArray, Coord.Count,
    Vector3Single(0, 0, 0));

  for I := 0 to Length(Indexes) - 1 do
    VectorAddTo1st(Normals.Items[DirectIndexes[I]], FaceNormal);
end;

function CreateSmoothNormalsCoordinateNode(
  Node: TVRMLGeometryNode;
  State: TVRMLGraphTraverseState;
  FromCCW: boolean): TDynVector3SingleArray;
var
  Calculator: TCoordinateNormalsCalculator;
  C: TMFVec3f;
begin
  C := Node.Coordinates(State);

  { Node coordinate-based, but specified with empty coord }
  if C = nil then Exit(nil);

  Result := TDynVector3SingleArray.Create(C.Count);
  try
    Result.FillChar(0);

    Calculator := TCoordinateNormalsCalculator.Create;
    try
      Calculator.Coord := C.Items;
      if Node.CoordIndex <> nil then
        Calculator.CoordIndex := Node.CoordIndex.Items else
        Calculator.CoordIndex := nil;
      Calculator.Normals := Result;
      Node.CoordPolygons(State, @Calculator.Polygon);
    finally FreeAndNil(Calculator) end;

    Result.Normalize;
    if not FromCCW then Result.Negate;

  except FreeAndNil(Result); raise end;
end;

end.
