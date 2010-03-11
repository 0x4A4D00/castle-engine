{
  Copyright 2009-2010 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Rendering elevations (terrains) in OpenGL. }
unit RenderElevations;

interface

uses Elevations;

{ Drawing of TElevation (relies only on TElevation.Height method).

  When LayersCount > 1, this draws elevation with layers
  (ultra-simplified geometry clipmaps).

  BaseSize * 2 is the size of the first (most detailed) square layer around
  the (MiddleX, MiddleY). Eeach successive layer has the same subdivision
  (although with middle square removed, as it's already done by
  previous layer) and 2 times larger size. }
procedure DrawElevation(Elevation: TElevation;
  const Subdivision: Cardinal;
  MiddleX, MiddleY: Single; BaseSize: Single;
  const LayersCount: Cardinal);

{ Specialized drawing for TElevationGrid, that displays only the
  precise grid points. }
procedure DrawGrid(Grid: TElevationGrid);

procedure RenderElevationsInitGL;
procedure RenderElevationsCloseGL;

implementation

uses GL, GLU, GLExt, VectorMath, KambiGLUtils, KambiUtils, SysUtils;

var
  ElevationVbo: TGLuint;
  ElevationIndexVbo: TGLuint;

procedure RenderElevationsInitGL;
begin
  if not GL_ARB_vertex_buffer_object then
    raise Exception.Create('ARB_vertex_buffer_object is required');
  glGenBuffersARB(1, @ElevationVbo);
  glGenBuffersARB(1, @ElevationIndexVbo);
end;

procedure RenderElevationsCloseGL;
begin
  glDeleteBuffersARB(1, @ElevationVbo);
  glDeleteBuffersARB(1, @ElevationIndexVbo);
end;

function ColorFromHeight(const H: Single): TVector3Single;
begin
  { Colors strategy from http://www.ii.uni.wroc.pl/~anl/dyd/PGK/pracownia.html }
  if      (H < 0  )  then Result := Vector3Single(0,       0,         1) { blue }
  else if (H < 500)  then Result := Vector3Single(0,       H/500,     0) { green }
  else if (H < 1000) then Result := Vector3Single(H/500-1, 1,         0) { yellow }
  else if (H < 1500) then Result := Vector3Single(1,       H/500-2.0, 0) { red }
  else Result := Vector3Single(1, 1, 1);                                 { white }
end;

type
  TElevationPoint = packed record
    Position, Normal, Color: TVector3Single;
  end;
  PElevationPoint = ^TElevationPoint;

var
  { Array for elevation points and indexes.

    Initially, when still using OpenGL immediate mode, this was useful to
    calculate all elevation points *once* before passing them to OpenGL
    (otherwise quad strips would calculate all twice).
    Then it was also useful to calculate normal vectors based on positions.

    Finally, now this is just send into OpenGL VBO. }
  Points: array of TElevationPoint;
  PointsIndex: array of TGLuint;
  TrisIndex: array of TGLuint;

{ Calculate shift between A and B addresses (in bytes), and cast to Pointer.
  This is simply Result := A - B, except we do some typecasting. }
function Offset(var A, B): Pointer;
begin
  { additional PtrUInt typecast before Pointer, to avoid warning. }
  Result := Pointer(PtrUInt( PtrUInt(@A) - PtrUInt(@B) ));
end;

procedure DrawElevationLayer(Elevation: TElevation; const Subdivision: Cardinal;
  const X1, Y1, X2, Y2: Single; Hole, BorderTriangles: boolean);
var
  CountSteps, CountSteps1, CountStepsQ: Cardinal;

  procedure CalculatePositionColor(var P: TElevationPoint; const I, J: Cardinal);
  var
    HForColor: Single;
  begin
    { set XY to cover (X1, Y1) ... (X2, Y2) rectangle with our elevation }
    P.Position[0] := (X2 - X1) * I / (CountSteps-1) + X1;
    P.Position[1] := (Y2 - Y1) * J / (CountSteps-1) + Y1;

    P.Position[2] := Elevation.Height(P.Position[0], P.Position[1]);

    HForColor := P.Position[2];
    { scale height down by Amplitude, to keep nice colors regardless of Amplitude }
    if Elevation is TElevationNoise then
      HForColor /= TElevationNoise(Elevation).Amplitude;
    { some hacks to hit interesting colors }
    HForColor := HForColor  * 2000 - 1000;
    P.Color := ColorFromHeight(HForColor);
  end;

  procedure CalculateNormal(const I, J: Cardinal);
  var
    P, PX, PY: PElevationPoint;
  begin
    P  := @(Points[ I      * CountSteps1 + J]);
    PX := @(Points[(I + 1) * CountSteps1 + J]);
    PY := @(Points[ I      * CountSteps1 + J + 1]);

    { TODO: this is actually normal vector of 1 of the four faces around this
      vertex. Optimally, we should calculate normals on all faces,
      and for vertex normal take average. }
    P^.Normal := (PX^.Position - P^.Position) ><
                 (PY^.Position - P^.Position);
  end;

var
  I, J: Cardinal;
  P: PElevationPoint;
  Index: PGLuint;
begin
  { CountSteps-1 squares (edges) along the way,
    CountSteps points along the way.
    Calculate positions for CountSteps + 1 points
    (+ 1 additional for normal calculation).
    We want CountSteps-1 to be divisible by 4, for Hole rendering. }
  CountSteps := 1 shl Subdivision + 1;
  CountSteps1 := CountSteps + 1;
  { Quarter of CountSteps for sQuares }
  CountStepsQ := 1 shl (Subdivision - 2);

  { We will render CountSteps^2 points, but we want to calculate
    (CountSteps + 1)^2 points : to be able to calculate normal vectors.
    Normals for the last row and last column will not be calculated,
    and will not be used. }
  SetLength(Points, Sqr(CountSteps1));

  if Hole then
  begin
    { calculate Points and Colors }
    for I := 0 to CountStepsQ + 1 do
    begin
      P := @(Points[I * CountSteps1]);
      for J := 0 to CountSteps do
      begin
        { calculate P^, which is Points.Items[I * CountSteps1 + J] }
        CalculatePositionColor(P^, I, J);
        Inc(P);
      end;
    end;

    for I := CountStepsQ + 2 to CountStepsQ * 3 - 1 do
    begin
      P := @(Points[I * CountSteps1]);
      for J := 0 to CountStepsQ + 1 do
      begin
        { calculate P^, which is Points.Items[I * CountSteps1 + J] }
        CalculatePositionColor(P^, I, J);
        Inc(P);
      end;

      P := @(Points[I * CountSteps1 + CountStepsQ * 3]);
      for J := CountStepsQ * 3 to CountSteps do
      begin
        { calculate P^, which is Points.Items[I * CountSteps1 + J] }
        CalculatePositionColor(P^, I, J);
        Inc(P);
      end;
    end;

    for I := CountStepsQ * 3 to CountSteps do
    begin
      P := @(Points[I * CountSteps1]);
      for J := 0 to CountSteps do
      begin
        { calculate P^, which is Points.Items[I * CountSteps1 + J] }
        CalculatePositionColor(P^, I, J);
        Inc(P);
      end;
    end;

    { calculate Normals }
    for I := 0 to CountStepsQ do
      for J := 0 to CountSteps - 1 do
        CalculateNormal(I, J);

    for I := CountStepsQ + 1 to CountStepsQ * 3 - 1 do
    begin
      for J := 0 to CountStepsQ do
        CalculateNormal(I, J);
      for J := CountStepsQ * 3 to CountSteps - 1 do
        CalculateNormal(I, J);
    end;

    for I := CountStepsQ * 3 to CountSteps - 1 do
      for J := 0 to CountSteps - 1 do
        CalculateNormal(I, J);
  end else
  begin
    { calculate Points and Colors }
    P := PElevationPoint(Points);
    for I := 0 to CountSteps do
      for J := 0 to CountSteps do
      begin
        { calculate P^, which is Points.Items[I * CountSteps1 + J] }
        CalculatePositionColor(P^, I, J);
        Inc(P);
      end;

    { calculate Normals }
    for I := 0 to CountSteps - 1 do
      for J := 0 to CountSteps - 1 do
        CalculateNormal(I, J);
  end;

  { calculate PointsIndex }
  SetLength(PointsIndex, (CountSteps - 1) * CountSteps * 2);
  Index := PGLuint(PointsIndex);
  for I := 1 to CountSteps - 1 do
    for J := 0 to CountSteps - 1 do
    begin
      Index^ := (I - 1) * CountSteps1 + J; Inc(Index);
      Index^ :=  I      * CountSteps1 + J; Inc(Index);
    end;

  { load Points into VBO, render }

  glBindBufferARB(GL_ARRAY_BUFFER_ARB, ElevationVbo);
  glBufferDataARB(GL_ARRAY_BUFFER_ARB, Length(Points) * SizeOf(TElevationPoint),
    Pointer(Points), GL_STREAM_DRAW_ARB);

  glEnableClientState(GL_VERTEX_ARRAY);
  glVertexPointer(3, GL_FLOAT, SizeOf(TElevationPoint), Offset(Points[0].Position, Points[0]));

  glEnableClientState(GL_NORMAL_ARRAY);
  glNormalPointer(GL_FLOAT, SizeOf(TElevationPoint), Offset(Points[0].Normal, Points[0]));

  glEnableClientState(GL_COLOR_ARRAY);
  glColorPointer(3, GL_FLOAT, SizeOf(TElevationPoint), Offset(Points[0].Color, Points[0]));

  glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, ElevationIndexVbo);
  glBufferDataARB(GL_ELEMENT_ARRAY_BUFFER_ARB, Length(PointsIndex) * SizeOf(TGLuint),
    Pointer(PointsIndex), GL_STREAM_DRAW_ARB);

  Assert(CountStepsQ * 4 - 1 = CountSteps - 2);

  if Hole then
  begin
    for I := 0 to CountStepsQ - 1 do
      glDrawElements(GL_QUAD_STRIP, CountSteps * 2, GL_UNSIGNED_INT,
        Pointer(CountSteps * 2 * I * SizeOf(TGLuint)));

    for I := CountStepsQ to CountStepsQ * 3 - 1  do
    begin
      glDrawElements(GL_QUAD_STRIP, (CountStepsQ+1) * 2, GL_UNSIGNED_INT,
        Pointer(CountSteps * 2 * I * SizeOf(TGLuint)));
      glDrawElements(GL_QUAD_STRIP, (CountStepsQ+1) * 2, GL_UNSIGNED_INT,
        Pointer((CountSteps * 2 * I + CountStepsQ*3*2) * SizeOf(TGLuint)));
    end;

    for I := CountStepsQ * 3 to CountStepsQ * 4 - 1 do
      glDrawElements(GL_QUAD_STRIP, CountSteps * 2, GL_UNSIGNED_INT,
        Pointer(CountSteps * 2 * I * SizeOf(TGLuint)));
  end else
  begin
    for I := 0 to CountSteps - 2 do
      glDrawElements(GL_QUAD_STRIP, CountSteps * 2, GL_UNSIGNED_INT,
        Pointer(CountSteps * 2 * I * SizeOf(TGLuint)));
  end;

  if BorderTriangles then
  begin
    SetLength(TrisIndex, ((CountSteps - 1) div 2) * 3 * 4);
    Index := PGLuint(TrisIndex);
    for I := 0 to (CountSteps - 1) div 2 - 1 do
    begin
      Index^ := I*2;     Inc(Index);
      Index^ := I*2 + 1; Inc(Index);
      Index^ := I*2 + 2; Inc(Index);

      Index^ := (CountSteps-1)*CountSteps1 + I*2;     Inc(Index);
      Index^ := (CountSteps-1)*CountSteps1 + I*2 + 1; Inc(Index);
      Index^ := (CountSteps-1)*CountSteps1 + I*2 + 2; Inc(Index);

      Index^ := (I*2    )*CountSteps1; Inc(Index);
      Index^ := (I*2 + 1)*CountSteps1; Inc(Index);
      Index^ := (I*2 + 2)*CountSteps1; Inc(Index);

      Index^ := CountSteps-1 + (I*2    )*CountSteps1; Inc(Index);
      Index^ := CountSteps-1 + (I*2 + 1)*CountSteps1; Inc(Index);
      Index^ := CountSteps-1 + (I*2 + 2)*CountSteps1; Inc(Index);
    end;

    glBufferDataARB(GL_ELEMENT_ARRAY_BUFFER_ARB, Length(TrisIndex) * SizeOf(TGLuint),
      Pointer(TrisIndex), GL_STREAM_DRAW_ARB);
    glDrawElements(GL_TRIANGLES, Length(TrisIndex), GL_UNSIGNED_INT, nil);
  end;

  glDisableClientState(GL_VERTEX_ARRAY);
  glDisableClientState(GL_NORMAL_ARRAY);
  glDisableClientState(GL_COLOR_ARRAY);
  glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);
  glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
end;

procedure DrawElevation(Elevation: TElevation;
  const Subdivision: Cardinal;
  MiddleX, MiddleY: Single; BaseSize: Single;
  const LayersCount: Cardinal);
const
  RoundGridCell = 0.5;
var
  Layer: Cardinal;
  X1, Y1, X2, Y2: Single;
begin
  { to somewhat cure the effect of terrain "flowing" (because every small
    change of Middle point shifts all the points), round middle to
    some cell size. }
  MiddleX := Round(MiddleX / RoundGridCell) * RoundGridCell;
  MiddleY := Round(MiddleY / RoundGridCell) * RoundGridCell;
  X1 := MiddleX - BaseSize;
  Y1 := MiddleY - BaseSize;
  X2 := MiddleX + BaseSize;
  Y2 := MiddleY + BaseSize;
  for Layer := 0 to LayersCount - 1 do
  begin
    DrawElevationLayer(Elevation, Subdivision, X1, Y1, X2, Y2,
      Layer <> 0, Layer < LayersCount - 1);
    X1 -= BaseSize;
    Y1 -= BaseSize;
    X2 += BaseSize;
    Y2 += BaseSize;
    BaseSize *= 2;
  end;
end;

procedure DrawGrid(Grid: TElevationGrid);
const
  { to scale coords to nicely fit in similar box like DrawElevation }
  ScaleSize = 100.0;
  ScaleHeight = 0.01;

  procedure Vertex(I, J: Cardinal);
  var
    HForColor: Single;
  begin
    HForColor := Grid.GridHeight(I, J);
    glColorv(ColorFromHeight(HForColor));
    glVertexv(Vector3Single(
      ScaleSize * (I / Grid.GridSizeX),
      ScaleSize * (J / Grid.GridSizeY),
      HForColor * ScaleHeight));
  end;

const
  Step = 10;
var
  I, J: Cardinal;
begin
  I := Step;
  while I < Grid.GridSizeX do
  begin
    glBegin(GL_QUAD_STRIP);
      J := 0;
      while J < Grid.GridSizeY do
      begin
        Vertex(I - Step, J);
        Vertex(I       , J);
        Inc(J, Step);
      end;
    glEnd();
    Inc(I, Step);
  end;
end;

end.
