{
  Copyright 2003-2010 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ @abstract(A lot of operations on vectors and matrices.
  This includes operations on geometric objects (2D and 3D)
  that can be represented as some vectors, matrices and scalar values.
  Various collision-checking routines for these geometric objects.
  Also functions to operate on RGB colors (these are vectors too, after all).)

  Representation of geometric objects in this unit :

  @unorderedList(
    @item(
      @italic(Triangle) is a @code(TTriangle<point-type>) type.
      Where @code(<point-type>) is such suffix that vector type
      @code(TVector<point-type>) exists. For example, we have
      TVector3Single type that represents a point in 3D space,
      so you can use TTriangle3Single to represent triangle in 3D space.
      There are also 2D triangles like TTriangle2Single and TTriangle2Double.

      Triangle's three points must not be collinear,
      i.e. routines in this unit generally don't accept "degenerated" triangles
      that are not really triangles. So 3D triangle must unambiguously
      define some plane in the 3D space. The only function in this unit
      that is able to handle "degenerated" triangles is IsValidTriangle,
      which is exactly used to check whether the triangle is degenerated.

      Since every valid triangle unambiguously determines some plane in the
      3D space, it also determines it's normal vector. In this unit,
      when dealing with normal vectors, I use two names:
      @unorderedList(
        @itemSpacing Compact
        @item(@italic(@noAutoLink(TriangleNormal))
          means that this is the normalized (i.e. scaled to length 1.0)
          normal vector.)
        @item(@italic(@noAutoLink(TriangleDir))
          means that this is not necessarily normalized normal vector.)
      ))

    @item(
      @italic(Plane in 3D space) is a vector TVector4*. Such vector [A, B, C, D]
      defines a surface that consists of all points satisfying equation
      @code(A * x + B * y + C * z + D = 0). At least one of A, B, C must be
      different than zero.

      Vector [A, B, C] is called PlaneDir in many places.
      Or PlaneNormal when it's guaranteed (or required to be) normalized,
      i.e. scaled to have length 1.)

    @item(
      @italic(Line in 3D space) is represented by two 3D vectors:
      Line0 and LineVector. They determine a line consisting of all
      points that can be calculated as @code(Line0 + R * LineVector)
      where R is any real value.

      LineVector must not be a zero vector.)

    @item(
      @italic(Line in 2D space) is sometimes represented as 2D vectors
      Line0 and LineVector (analogously like line in 3D).

      And sometimes it's represented as a 3-items vector,
      like TVector3Single (for [A, B, C] line consists of all
      points satisfying @code(A * x + B * y + C = 0)).
      At least one of A, B must be different than zero.)

    @item(
      A @italic(tunnel) is an object that you get by moving a sphere
      along the line segment. In other words, this is like a cylinder,
      but ended with a hemispheres. The tunnel is represented in this
      unit as two points Tunnel1, Tunnel2 (this defines a line segment)
      and a TunnelRadius.)

    @item(
      A @italic(ray) is defined just like a line: two vectors Ray0 and RayVector,
      RayVector must be nonzero.
      Ray consists of all points @code(Line0 + R * LineVector)
      for R being any real value >= 0.)

    @item(
      A @italic(simple plane in 3D) is a plane parallel to one of
      the three basic planes. This is a plane defined by the equation
      @code(X = Const) or @code(Y = Count) or @code(Z = Const).
      Such plane is represented as PlaneConstCoord integer value equal
      to 0, 1 or 2 and PlaneConstValue.

      Note that you can always represent the same plane using a more
      general plane 3D equation, just take

@preformatted(
  Plane[0..2 / PlaneConstCoord] = 0,
  Plane[PlaneConstCoord] = -1,
  Plane[3] = PlaneConstValue.
)

      On such "simple plane" we can perform many calculations
      much faster.)

    @item(
      A @italic(line segment) (often referred to as just @italic(segment))
      is represented by two points Pos1 and Pos2.
      For some routines the order of points Pos1 and Pos2 is significant
      (but this is always explicitly stated in the interface, so don't worry).

      Sometimes line segment is also represented as
      Segment0 and SegmentVector, this consists of all points
      @code(Segment0 + SegmentVector * t) for t in [0..1].
      SegmentVector must not be a zero vector.

      Conversion between the two representations above is trivial,
      just take Pos1 = Segment0 and Pos2 = Segment0 + SegmentVector.)
  )

  In descriptions of geometric objects above, I often
  stated some requirements, e.g. the triangle must not be "degenerated"
  to a line segment, RayVector must not be a zero vector, etc.
  You should note that these requirements are generally @italic(not checked)
  by routines in this unit (for the sake of speed) and passing
  wrong values to many of the routines may lead to serious bugs
  --- maybe the function will raise some arithmetic exception,
  maybe it will return some nonsensible result. In other words: when
  calling these functions, always make sure that values you pass
  satisfy the requirements.

  (However, wrong input values should never lead to some serious
  bugs like access violations or range check errors ---
  in cases when it would be possible, we safeguard against this.
  That's because sometimes you simply cannot guarantee for 100%
  that input values are correct, because of floating-point precision
  problems -- see below.)

  As for floating-point precision:
  @unorderedList(
    @item(Well, floating-point inaccuracy is, as always, a problem.
      This unit always uses FloatsEqual
      and variables SingleEqualityEpsilon, DoubleEqualityEpsilon
      and ExtendedEpsilonEquality when comparison of floating-point
      values is needed. In some cases you may be able to adjust these
      variables to somewhat fine-tune the comparisons.)

    @item(For collision-detecting routines, the general strategy
      in case of uncertainty (when we're not sure whether there
      is a collision or the objects are just very very close to each other)
      is to say that there @italic(is a collision).

      This means that we may detect a collision when in fact the precise
      mathematical calculation says that there is no collision.

      This approach should be suitable for most use cases.)
  )

  A design question about this unit: Right now I must declare two variables
  to define a sphere (like @code(SphereCenter: vector; SphereRadius: scalar;))
  Why not wrap all the geometric objects (spheres, lines, rays, tunnels etc.)
  inside some records ? For example, define a sphere as
@longcode(#
  TSphere = record Center: vector; Radius: scalar; end;
#)

  The answer: this is not so good idea, because it would create
  a lot of such types into unit, and I would have to implement
  simple functions that construct and convert between these
  types. Consider e.g. when I have a tunnel (given
  as Tunnel1, Tunnel2 points and TunnelRadius vector)
  and I want to "extract" the properties of the sphere at the 1st end
  of this tunnel. Right now, it's simple: just consider
  Tunnel1 as a sphere center, and TunnelRadius is obviously a sphere radius.
  Computer doesn't have to actually do anything, you just have to think
  in a different way about Tunnel1 and TunnelRadius.
  But if I would have tunnel wrapped in a type like @code(TTunnel)
  and a sphere wrapped in a type like @code(TSphere), then I would
  have to actually implement this trivial conversion. And then doing
  such trivial conversion at run-time would take some time,
  because you have to copy 6 floating-point values.
  This would be a very serious waste of time at run-time.
  Well, on the other hand, routines could take less parameters
  (e.g. only 1 parameter @code(TTunnel), instead of three vector parameters),
  but (overall) we would still loose a lot of time.

  In many places where I have to return collision with
  a line segment, a line or a ray there are alternative versions
  that return just a scalar "T" instead of a calculated point.
  The actual collision point can be calculated then like
  @code(Ray0 + T * RayVector). Of course for rays you can be sure
  that T is >= 0, for line segments you can be sure that
  0 <= T <= 1. The "T" is often useful, because it allows
  you to easily calculate collision point, and also the distance
  to the collision (you can e.g. compare T1 and T2 to compare which
  collision is closer, and when your RayVector is normalized then
  the T gives you the exact distance). Thanks to this you can often
  entirely avoid calculating the actual collision point
  (@code(Ray0 + T * RayVector)).

  This unit compiles with FPC and Delphi. But it will miss
  most things when compiled with Delphi. Because it compiles with Delphi,
  Images unit (that depends on some simplest things from this unit)
  can be compiled with Delphi too.

  This unit, when compiled with FPC, will contain some stuff useful
  for integration with FPC's Matrix unit.
  The idea is to integrate in the future this unit with FPC's Matrix unit
  much more. For now, there are some "glueing" functions here like
  Vector_Get_Normalized that allow you to comfortably
  perform operations on Matrix unit object types.
  Most important is also the overload of ":=" operator that allows
  you to switch between VectorMath arrays and Matrix objects without
  any syntax obfuscation. Although note that this overload is a little
  dangerous, since now code like
  @preformatted(  V3 := VectorProduct(V1, V2);)
  compiles and works both when all three V1, V2 and V3 are TVector3Single arrays
  or TVector3_Single objects. However, for the case when they are all
  TVector3_Single objects, this is highly un-optimal, and
  @preformatted(  V3 := V1 >< V2;)
  is much faster, since it avoids the implicit convertions (unnecessary
  memory copying around).
}

unit VectorMath;

{$I kambiconf.inc}

{$ifdef FPC}
  {$define HAS_MATRIX_UNIT}
{$endif}

interface

uses SysUtils, KambiUtils {$ifdef HAS_MATRIX_UNIT}, Matrix{$endif};

{$define read_interface}

{$ifndef HAS_MATRIX_UNIT}
type    Tvector2_single_data   =array[0..1] of single;
        Tvector2_double_data   =array[0..1] of double;
        Tvector2_extended_data =array[0..1] of extended;

        Tvector3_single_data   =array[0..2] of single;
        Tvector3_double_data   =array[0..2] of double;
        Tvector3_extended_data =array[0..2] of extended;

        Tvector4_single_data   =array[0..3] of single;
        Tvector4_double_data   =array[0..3] of double;
        Tvector4_extended_data =array[0..3] of extended;

        Tmatrix2_single_data   =array[0..1] of Tvector2_single_data;
        Tmatrix2_double_data   =array[0..1] of Tvector2_double_data;
        Tmatrix2_extended_data =array[0..1] of Tvector2_extended_data;

        Tmatrix3_single_data   =array[0..2] of Tvector3_single_data;
        Tmatrix3_double_data   =array[0..2] of Tvector3_double_data;
        Tmatrix3_extended_data =array[0..2] of Tvector3_extended_data;

        Tmatrix4_single_data   =array[0..3] of Tvector4_single_data;
        Tmatrix4_double_data   =array[0..3] of Tvector4_double_data;
        Tmatrix4_extended_data =array[0..3] of Tvector4_extended_data;
{$endif}

{$ifdef HAS_MATRIX_UNIT}
{ Define pointer types for all Matrix unit types. }
type
  Pvector2_single   = ^Tvector2_single  ;
  Pvector2_double   = ^Tvector2_double  ;
  Pvector2_extended = ^Tvector2_extended;

  Pvector3_single   = ^Tvector3_single  ;
  Pvector3_double   = ^Tvector3_double  ;
  Pvector3_extended = ^Tvector3_extended;

  Pvector4_single   = ^Tvector4_single  ;
  Pvector4_double   = ^Tvector4_double  ;
  Pvector4_extended = ^Tvector4_extended;

  Pmatrix2_single   = ^Tmatrix2_single  ;
  Pmatrix2_double   = ^Tmatrix2_double  ;
  Pmatrix2_extended = ^Tmatrix2_extended;

  Pmatrix3_single   = ^Tmatrix3_single  ;
  Pmatrix3_double   = ^Tmatrix3_double  ;
  Pmatrix3_extended = ^Tmatrix3_extended;

  Pmatrix4_single   = ^Tmatrix4_single  ;
  Pmatrix4_double   = ^Tmatrix4_double  ;
  Pmatrix4_extended = ^Tmatrix4_extended;
{$endif}

{ Most types below are packed anyway, so the "packed" keyword below
  is often not needed (but it doesn't hurt).

  The fact that types
  below are packed is useful to easily map some of them to
  OpenGL, OpenAL types etc. It's also useful to be able to safely
  compare the types for exact equality by routines like CompareMem. }

type
  { }
  TVector2Single = Tvector2_single_data;              PVector2Single = ^TVector2Single;
  TVector2Double = Tvector2_double_data;              PVector2Double = ^TVector2Double;
  TVector2Extended = Tvector2_extended_data;          PVector2Extended = ^TVector2Extended;
  TVector2Byte = packed array [0..1] of Byte;         PVector2Byte = ^TVector2Byte;
  TVector2Word = packed array [0..1] of Word;         PVector2Word = ^TVector2Word;
  TVector2Longint = packed array [0..1] of Longint;   PVector2Longint = ^TVector2Longint;
  TVector2Pointer = packed array [0..1] of Pointer;   PVector2Pointer = ^TVector2Pointer;
  TVector2Cardinal = packed array [0..1] of Cardinal; PVector2Cardinal = ^TVector2Cardinal;
  TVector2Integer = packed array [0..1] of Integer;   PVector2Integer = ^TVector2Integer;

  TVector3Single = Tvector3_single_data;              PVector3Single = ^TVector3Single;
  TVector3Double = Tvector3_double_data;              PVector3Double = ^TVector3Double;
  TVector3Extended = Tvector3_extended_data;          PVector3Extended = ^TVector3Extended;
  TVector3Byte = packed array [0..2] of Byte;         PVector3Byte = ^TVector3Byte;
  TVector3Word = packed array [0..2] of Word;         PVector3Word = ^TVector3Word;
  TVector3Longint = packed array [0..2] of Longint;   PVector3Longint = ^TVector3Longint;
  TVector3Pointer = packed array [0..2] of Pointer;   PVector3Pointer = ^TVector3Pointer;
  TVector3Integer = packed array [0..2] of Integer;   PVector3Integer = ^TVector3Integer;
  TVector3Cardinal = packed array [0..2] of Cardinal; PVector3Cardinal = ^TVector3Cardinal;

  TVector4Single = Tvector4_single_data;              PVector4Single = ^TVector4Single;
  TVector4Double = Tvector4_double_data;              PVector4Double = ^TVector4Double;
  TVector4Extended = Tvector4_extended_data;          PVector4Extended = ^TVector4Extended;
  TVector4Byte = packed array [0..3] of Byte;         PVector4Byte = ^TVector4Byte;
  TVector4Word = packed array [0..3] of Word;         PVector4Word = ^TVector4Word;
  TVector4Longint = packed array [0..3] of Longint;   PVector4Longint = ^TVector4Longint;
  TVector4Pointer = packed array [0..3] of Pointer;   PVector4Pointer = ^TVector4Pointer;
  TVector4Cardinal = packed array [0..3] of Cardinal; PVector4Cardinal = ^TVector4Cardinal;
  TVector4Integer = packed array [0..3] of Integer;   PVector4Integer = ^TVector4Integer;

  TTriangle2Single = packed array[0..2]of TVector2Single;     PTriangle2Single = ^TTriangle2Single;
  TTriangle2Double = packed array[0..2]of TVector2Double;     PTriangle2Double = ^TTriangle2Double;
  TTriangle2Extended = packed array[0..2]of TVector2Extended; PTriangle2Extended = ^TTriangle2Extended;

  TTriangle3Single = packed array[0..2]of TVector3Single;     PTriangle3Single = ^TTriangle3Single;
  TTriangle3Double = packed array[0..2]of TVector3Double;     PTriangle3Double = ^TTriangle3Double;
  TTriangle3Extended = packed array[0..2]of TVector3Extended; PTriangle3Extended = ^TTriangle3Extended;

  TTriangle4Single = packed array[0..2]of TVector4Single;     PTriangle4Single = ^TTriangle4Single;

  { Matrices types.

    The indexing rules of these types are the same as indexing rules
    for matrix types of OpenGL. I.e. the 1st index specifies the column
    (where the leftmost column is numbered zero), 2nd index specifies the row
    (where the uppermost row is numbered zero).

    @bold(Note that this is different than how FPC Matrix unit
    treats matrices ! If you want to pass matrices between Matrix unit
    and this unit, you must transpose them !)

    As you can see, matrices below are not declared explicitly
    as 2-dimensional arrays (like @code(array [0..3, 0..3] of Single)),
    but they are 1-dimensional arrays of vectors.
    This is sometimes useful and comfortable.

    @groupBegin }
  TMatrix2Single = Tmatrix2_single_data;                   PMatrix2Single = ^TMatrix2Single;
  TMatrix2Double = Tmatrix2_double_data;                   PMatrix2Double = ^TMatrix2Double;
  TMatrix2Longint = packed array[0..1]of TVector2Longint;  PMatrix2Longint = ^TMatrix2Longint;

  TMatrix3Single = Tmatrix3_single_data;                   PMatrix3Single = ^TMatrix3Single;
  TMatrix3Double = Tmatrix3_double_data;                   PMatrix3Double = ^TMatrix3Double;
  TMatrix3Longint = packed array[0..2]of TVector3Longint;  PMatrix3Longint = ^TMatrix3Longint;

  TMatrix4Single = Tmatrix4_single_data;                   PMatrix4Single = ^TMatrix4Single;
  TMatrix4Double = Tmatrix4_double_data;                   PMatrix4Double = ^TMatrix4Double;
  TMatrix4Longint = packed array[0..3]of TVector4Longint;  PMatrix4Longint = ^TMatrix4Longint;
  { @groupEnd }

  { The "infinite" arrays, useful for some type-casting hacks }

  { }
  TArray_Vector2Byte = packed array[0..MaxInt div SizeOf(TVector2Byte)-1]of TVector2Byte;
  PArray_Vector2Byte = ^TArray_Vector2Byte;
  TArray_Vector3Byte = packed array[0..MaxInt div SizeOf(TVector3Byte)-1]of TVector3Byte;
  PArray_Vector3Byte = ^TArray_Vector3Byte;
  TArray_Vector4Byte = packed array[0..MaxInt div SizeOf(TVector4Byte)-1]of TVector4Byte;
  PArray_Vector4Byte = ^TArray_Vector4Byte;
  TArray_Vector2Cardinal = packed array[0..MaxInt div SizeOf(TVector2Cardinal)-1]of TVector2Cardinal;
  PArray_Vector2Cardinal = ^TArray_Vector2Cardinal;
  TArray_Vector2Extended = packed array[0..MaxInt div SizeOf(TVector2Extended)-1]of TVector2Extended;
  PArray_Vector2Extended = ^TArray_Vector2Extended;

  { Dynamic arrays (using my TDynArray template),
    and some more "infinite" arrays defined by the way. }

  { }
  TDynVector4SingleArray = class;

  TDynArrayItem_1 = TVector3Single;
  PDynArrayItem_1 = PVector3Single;
  {$define DYNARRAY_1_IS_STRUCT}
  {$I dynarray_1.inc}
  TArray_Vector3Single = TInfiniteArray_1;
  PArray_Vector3Single = PInfiniteArray_1;
  TDynVector3SingleArray = class(TDynArray_1)
  public
    procedure AssignNegated(Source: TDynVector3SingleArray);
    { Negate all items. }
    procedure Negate;
    { Normalize all items. Zero vectors are left as zero. }
    procedure Normalize;
    { Multiply each item, component-wise, with V. }
    procedure MultiplyComponents(const V: TVector3Single);

    { Assign linear interpolation between two other vector arrays.
      We take ACount items, from V1[Index1 ... Index1 + ACount - 1] and
      V2[Index2 ... Index2 + ACount - 1], and interpolate between them
      like normal Lerp functions.

      It's Ok for both V1 and V2 to be the same objects.
      But their ranges should not overlap, for future optimizations
      (although it's Ok for current implementation). }
    procedure AssignLerp(const Fraction: Single;
      V1, V2: TDynVector3SingleArray; Index1, Index2, ACount: Integer);

    { Convert to TDynVector4SingleArray, with 4th vector component in
      new array set to constant W. }
    function ToVector4Single(const W: Single): TDynVector4SingleArray;

    { When two vertexes on the list are closer than MergeDistance,
      set them truly (exactly) equal.
      Returns how many vertex positions were changed. }
    function MergeCloseVertexes(MergeDistance: Single): Cardinal;
  end;

  TDynArrayItem_2 = TVector2Single;
  PDynArrayItem_2 = PVector2Single;
  {$define DYNARRAY_2_IS_STRUCT}
  {$I dynarray_2.inc}
  TArray_Vector2Single = TInfiniteArray_2;
  PArray_Vector2Single = PInfiniteArray_2;
  TDynVector2SingleArray = class(TDynArray_2)
  public
    { Calculate minimum and maximum values for both dimensions of
      this set of points. Returns @false when Count = 0. }
    function MinMax(out Min, Max: TVector2Single): boolean;

    { Assign linear interpolation between two other vector arrays.
      @seealso TDynVector3SingleArray.AssignLerp }
    procedure AssignLerp(const Fraction: Single;
      V1, V2: TDynVector2SingleArray; Index1, Index2, ACount: Integer);
  end;

  TDynArrayItem_5 = TVector4Single;
  PDynArrayItem_5 = PVector4Single;
  {$define DYNARRAY_5_IS_STRUCT}
  {$I dynarray_5.inc}
  TArray_Vector4Single = TInfiniteArray_5;
  PArray_Vector4Single = PInfiniteArray_5;
  TDynVector4SingleArray = class(TDynArray_5);

  TDynArrayItem_3 = TVector3Cardinal;
  PDynArrayItem_3 = PVector3Cardinal;
  {$define DYNARRAY_3_IS_STRUCT}
  {$I dynarray_3.inc}
  TArray_Vector3Cardinal = TInfiniteArray_3;
  PArray_Vector3Cardinal = PInfiniteArray_3;
  TDynVector3CardinalArray = TDynArray_3;

  TDynArrayItem_6 = TVector2Double;
  PDynArrayItem_6 = PVector2Double;
  {$define DYNARRAY_6_IS_STRUCT}
  {$I dynarray_6.inc}
  TArray_Vector2Double = TInfiniteArray_6;
  PArray_Vector2Double = PInfiniteArray_6;
  TDynVector2DoubleArray = class(TDynArray_6)
  public
    function ToVector2Single: TDynVector2SingleArray;
  end;

  TDynArrayItem_7 = TVector3Double;
  PDynArrayItem_7 = PVector3Double;
  {$define DYNARRAY_7_IS_STRUCT}
  {$I dynarray_7.inc}
  TArray_Vector3Double = TInfiniteArray_7;
  PArray_Vector3Double = PInfiniteArray_7;
  TDynVector3DoubleArray = class(TDynArray_7)
  public
    function ToVector3Single: TDynVector3SingleArray;
  end;

  TDynArrayItem_8 = TVector4Double;
  PDynArrayItem_8 = PVector4Double;
  {$define DYNARRAY_8_IS_STRUCT}
  {$I dynarray_8.inc}
  TArray_Vector4Double = TInfiniteArray_8;
  PArray_Vector4Double = PInfiniteArray_8;
  TDynVector4DoubleArray = class(TDynArray_8)
  public
    function ToVector4Single: TDynVector4SingleArray;
  end;

  TDynArrayItem_9 = TMatrix3Single;
  PDynArrayItem_9 = PMatrix3Single;
  {$define DYNARRAY_9_IS_STRUCT}
  {$I dynarray_9.inc}
  TArray_Matrix3Single = TInfiniteArray_9;
  PArray_Matrix3Single = PInfiniteArray_9;
  TDynMatrix3SingleArray = TDynArray_9;

  TDynArrayItem_10 = TMatrix3Double;
  PDynArrayItem_10 = PMatrix3Double;
  {$define DYNARRAY_10_IS_STRUCT}
  {$I dynarray_10.inc}
  TArray_Matrix3Double = TInfiniteArray_10;
  PArray_Matrix3Double = PInfiniteArray_10;
  TDynMatrix3DoubleArray = class(TDynArray_10)
  public
    function ToMatrix3Single: TDynMatrix3SingleArray;
  end;

  TDynArrayItem_11 = TMatrix4Single;
  PDynArrayItem_11 = PMatrix4Single;
  {$define DYNARRAY_11_IS_STRUCT}
  {$I dynarray_11.inc}
  TArray_Matrix4Single = TInfiniteArray_11;
  PArray_Matrix4Single = PInfiniteArray_11;
  TDynMatrix4SingleArray = TDynArray_11;

  TDynArrayItem_12 = TMatrix4Double;
  PDynArrayItem_12 = PMatrix4Double;
  {$define DYNARRAY_12_IS_STRUCT}
  {$I dynarray_12.inc}
  TArray_Matrix4Double = TInfiniteArray_12;
  PArray_Matrix4Double = PInfiniteArray_12;
  TDynMatrix4DoubleArray = class(TDynArray_12)
  public
    function ToMatrix4Single: TDynMatrix4SingleArray;
  end;

  { Exceptions }

  { }
  EVectorMathInvalidOp = class(Exception);

  TGetVertexFromIndexFunc = function (Index: integer): TVector3Single of object;

const
  ZeroVector2Single: TVector2Single = (0, 0);
  ZeroVector2Double: TVector2Double = (0, 0);

  ZeroVector3Single: TVector3Single = (0, 0, 0);
  ZeroVector3Double: TVector3Double = (0, 0, 0);

  ZeroVector4Single: TVector4Single = (0, 0, 0, 0);
  ZeroVector4Double: TVector4Double = (0, 0, 0, 0);

  ZeroMatrix2Single: TMatrix2Single =   ((0, 0), (0, 0));
  ZeroMatrix2Double: TMatrix2Double =   ((0, 0), (0, 0));
  ZeroMatrix2Longint: TMatrix2Longint = ((0, 0), (0, 0));

  ZeroMatrix3Single: TMatrix3Single =   ((0, 0, 0), (0, 0, 0), (0, 0, 0));
  ZeroMatrix3Double: TMatrix3Double =   ((0, 0, 0), (0, 0, 0), (0, 0, 0));
  ZeroMatrix3Longint: TMatrix3Longint = ((0, 0, 0), (0, 0, 0), (0, 0, 0));

  ZeroMatrix4Single: TMatrix4Single =   ((0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0));
  ZeroMatrix4Double: TMatrix4Double =   ((0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0));
  ZeroMatrix4Longint: TMatrix4Longint = ((0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0));

  IdentityMatrix2Single: TMatrix2Single =   ((1, 0), (0, 1));
  IdentityMatrix2Double: TMatrix2Double =   ((1, 0), (0, 1));
  IdentityMatrix2Longint: TMatrix2Longint = ((1, 0), (0, 1));

  IdentityMatrix3Single: TMatrix3Single =   ((1, 0, 0), (0, 1, 0), (0, 0, 1));
  IdentityMatrix3Double: TMatrix3Double =   ((1, 0, 0), (0, 1, 0), (0, 0, 1));
  IdentityMatrix3Longint: TMatrix3Longint = ((1, 0, 0), (0, 1, 0), (0, 0, 1));

  IdentityMatrix4Single: TMatrix4Single =   ((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1));
  IdentityMatrix4Double: TMatrix4Double =   ((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1));
  IdentityMatrix4Longint: TMatrix4Longint = ((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1));

  UnitVector3Single: array[0..2]of TVector3Single = ((1, 0, 0), (0, 1, 0), (0, 0, 1));
  UnitVector3Double: array[0..2]of TVector3Double = ((1, 0, 0), (0, 1, 0), (0, 0, 1));
  UnitVector4Single: array[0..3]of TVector4Single = ((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1));
  UnitVector4Double: array[0..3]of TVector4Double = ((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1));

  { Some colors.
    3-item colors are in RGB format,
    4-item colors have additional 4th component always at maximum
    (1.0 for floats, 255 for bytes etc.)

    @groupBegin }
  Black3Byte  : TVector3Byte = (  0,   0,   0);
  Red3Byte    : TVector3Byte = (255,   0,   0);
  Green3Byte  : TVector3Byte = (  0, 255,   0);
  Blue3Byte   : TVector3Byte = (  0,   0, 255);
  White3Byte  : TVector3Byte = (255, 255, 255);

  Black4Byte  : TVector4Byte = (  0,   0,   0, 255);
  Red4Byte    : TVector4Byte = (255,   0,   0, 255);
  Green4Byte  : TVector4Byte = (  0, 255,   0, 255);
  Blue4Byte   : TVector4Byte = (  0,   0, 255, 255);
  White4Byte  : TVector4Byte = (255, 255, 255, 255);
  { @groupEnd }

  { Standard 16 colors.
    @groupBegin }
  Black3Single        : TVector3Single = (   0,    0,    0);
  Blue3Single         : TVector3Single = (   0,    0,  0.6);
  Green3Single        : TVector3Single = (   0,  0.6,    0);
  Cyan3Single         : TVector3Single = (   0,  0.6,  0.6);
  Red3Single          : TVector3Single = ( 0.6,    0,    0);
  Magenta3Single      : TVector3Single = ( 0.6,    0,  0.6);
  Brown3Single        : TVector3Single = ( 0.6,  0.3,    0);
  LightGray3Single    : TVector3Single = ( 0.6,  0.6,  0.6);
  DarkGray3Single     : TVector3Single = ( 0.3,  0.3,  0.3);
  LightBlue3Single    : TVector3Single = ( 0.3,  0.3,    1);
  LightGreen3Single   : TVector3Single = ( 0.3,    1,  0.3);
  LightCyan3Single    : TVector3Single = ( 0.3,    1,    1);
  LightRed3Single     : TVector3Single = (   1,  0.3,  0.3);
  LightMagenta3Single : TVector3Single = (   1,  0.3,    1);
  Yellow3Single       : TVector3Single = (   1,    1,  0.3);
  White3Single        : TVector3Single = (   1,    1,    1);
  { @groupEnd }

  { Some additional colors.
    @groupBegin }
  Gray3Single         : TVector3Single = ( 0.5,  0.5,  0.5);
  DarkGreen3Single    : TVector3Single = (   0,  0.3,    0);
  DarkBrown3Single    : TVector3Single = (0.63, 0.15,    0);
  Orange3Single       : TVector3Single = (   1,  0.5,    0);
  { @groupEnd }

  { 4-components versions of 3Single colors above.
    Just for your comfort (and some small speed gain sometimes),
    as opposed to calling Vector4Single(Xxx3Single) all the time.

    @groupBegin }
  Black4Single        : TVector4Single = (   0,    0,    0, 1);
  Blue4Single         : TVector4Single = (   0,    0,  0.6, 1);
  Green4Single        : TVector4Single = (   0,  0.6,    0, 1);
  Cyan4Single         : TVector4Single = (   0,  0.6,  0.6, 1);
  Red4Single          : TVector4Single = ( 0.6,    0,    0, 1);
  Magenta4Single      : TVector4Single = ( 0.6,    0,  0.6, 1);
  Brown4Single        : TVector4Single = ( 0.6,  0.3,    0, 1);
  LightGray4Single    : TVector4Single = ( 0.6,  0.6,  0.6, 1);
  DarkGray4Single     : TVector4Single = ( 0.3,  0.3,  0.3, 1);
  LightBlue4Single    : TVector4Single = ( 0.3,  0.3,    1, 1);
  LightGreen4Single   : TVector4Single = ( 0.3,    1,  0.3, 1);
  LightCyan4Single    : TVector4Single = ( 0.3,    1,    1, 1);
  LightRed4Single     : TVector4Single = (   1,  0.3,  0.3, 1);
  LightMagenta4Single : TVector4Single = (   1,  0.3,    1, 1);
  Yellow4Single       : TVector4Single = (   1,    1,  0.3, 1);
  White4Single        : TVector4Single = (   1,    1,    1, 1);
  { @groupEnd }

{ ---------------------------------------------------------------------------- }
{ @section(FloatsEqual and related things) }

var
  { Values that differ less than given *EqualityEpsilon are assumed
    as equal by FloatsEqual (and so by all other routines in this unit).

    Note that initial *EqualityEpsilon values are quite large,
    if you compare them with the epsilons used by KambiUtils.SameValue
    or Math.SameValue. Well, unfortunately they have to be so large,
    to always detect collisions.

    You can change the variables below (but always keep them >= 0).

    Exact 0 always means that exact comparison will be used.

    @groupBegin }
    SingleEqualityEpsilon: Single   = 1e-7;
    DoubleEqualityEpsilon: Double   = 1e-12;
  ExtendedEqualityEpsilon: Extended = 1e-16;
  { @groupEnd }

{ Compare two float values, with some epsilon.
  When two float values differ by less than given epsilon, they are
  considered equal.

  @groupBegin }
function FloatsEqual(const f1, f2: Single): boolean; overload;
function FloatsEqual(const f1, f2: Double): boolean; overload;
{$ifndef EXTENDED_EQUALS_DOUBLE}
function FloatsEqual(const f1, f2: Extended): boolean; overload;
{$endif}
function FloatsEqual(const f1, f2, EqEpsilon: Single): boolean; overload;
function FloatsEqual(const f1, f2, EqEpsilon: Double): boolean; overload;
{$ifndef EXTENDED_EQUALS_DOUBLE}
function FloatsEqual(const f1, f2, EqEpsilon: Extended): boolean; overload;
{$endif}
{ @groupEnd }

{ Compare float value with zero, with some epsilon.
  This is somewhat optimized version of doing FloatsEqual(F1, 0).

  This is named Zero, not IsZero --- to not collide with IsZero function
  in Math unit (that has the same purpose, but uses different epsilons
  by default).

  @groupBegin }
function Zero(const f1: Single): boolean; overload;
function Zero(const f1: Double): boolean; overload;
{$ifndef EXTENDED_EQUALS_DOUBLE}
function Zero(const f1: Extended): boolean; overload;
{$endif}
function Zero(const f1, EqEpsilon: Single  ): boolean; overload;
function Zero(const f1, EqEpsilon: Double  ): boolean; overload;
{$ifndef EXTENDED_EQUALS_DOUBLE}
function Zero(const f1, EqEpsilon: Extended): boolean; overload;
{$endif}

{ konstruktory i konwertery typow ------------------------------------------------ }

function Vector2Cardinal(const x, y: Cardinal): TVector2Cardinal;
function Vector2Integer(const x, y: Integer): TVector2Integer;

function Vector2Single(const x, y: Single): TVector2Single; overload;
function Vector2Single(const V: TVector2Double): TVector2Single; overload;

function Vector2Double(const x, y: Double): TVector2Double;

function Vector3Single(const x, y: Single; const z: Single = 0.0): TVector3Single; overload;
function Vector3Single(const v3: TVector3Double): TVector3Single; overload;
function Vector3Single(const v3: TVector3Byte): TVector3Single; overload;
function Vector3Single(const v2: TVector2Single; const z: Single = 0.0): TVector3Single; overload;

function Vector3Longint(const p0, p1, p2: Longint): TVector3Longint;

function Vector3Double(const x, y: Double; const z: Double = 0.0): TVector3Double; overload;
function Vector3Double(const v: TVector3Single): TVector3Double; overload;

function Vector4Single(const x, y: Single;
  const z: Single = 0; const w: Single = 1): TVector4Single; overload;
function Vector4Single(const v3: TVector3Single;
  const w: Single = 1): TVector4Single; overload;
function Vector4Single(const ub: TVector4Byte): TVector4Single; overload;
function Vector4Single(const v: TVector4Double): TVector4Single; overload;

function Vector4Double(const x, y, z ,w: Double): TVector4Double; overload;
function Vector4Double(const v: TVector4Single): TVector4Double; overload;

{ konwersja skladowa Single->Byte w ponizszych funkcjach jest zawsze
  robiona na zasadzie skalowania
    0.0 i mniej -> Low(Byte) = 0,
    1.0 i wiecej -> High(Byte) 255,
    pomiedzy 0.0, 1.0 -> liniowo pomiedzy Low a High (Byte). }
function Vector3Byte(x, y, z: Byte): TVector3Byte; overload;
function Vector3Byte(const v: TVector3Single): TVector3Byte; overload;
function Vector3Byte(const v: TVector3Double): TVector3Byte; overload;

function Vector4Byte(x, y, z, w: Byte): TVector4Byte; overload;
function Vector4Byte(const f4: TVector4Single): TVector4Byte; overload;
function Vector4Byte(const f3: TVector3Byte; w: Byte): TVector4Byte; overload;

{ ma inna nazwe bo konwersja z wektora 4Single (x, y, z, w) daje
  (x/w, y/w, z/w), wiec uwazaj - paremetr musi miec w <> 0 ! }
function Vector3SinglePoint(const v: TVector4Single): TVector3Single;
{ ta wersja po prostu obcina 4 element }
function Vector3SingleCut(const v: TVector4Single): TVector3Single;

{ Normal3Single zwraca jak Vector3Single ale od razu normalizuje wartosci x, y, z }
function Normal3Single(const x, y: Single; const z: Single = 0.0): TVector3Single; overload;

function Triangle3Single(const T: TTriangle3Double): TTriangle3Single; overload;
function Triangle3Single(const p0, p1, p2: TVector3Single): TTriangle3Single; overload;
function Triangle3Double(const T: TTriangle3Single): TTriangle3Double; overload;
function Triangle3Double(const p0, p1, p2: TVector3Double): TTriangle3Double; overload;

function Vector3SingleFromStr(const s: string): TVector3Single;
function Vector3DoubleFromStr(const s: string): TVector3Double;
function Vector3ExtendedFromStr(const s: string): TVector3Extended;
function Vector4SingleFromStr(const s: string): TVector4Single;

{ Convert between single and double precision matrices.
  @groupBegin }
function Matrix2Double(const M: TMatrix2Single): TMatrix2Double;
function Matrix2Single(const M: TMatrix2Double): TMatrix2Single;
function Matrix3Double(const M: TMatrix3Single): TMatrix3Double;
function Matrix3Single(const M: TMatrix3Double): TMatrix3Single;
function Matrix4Double(const M: TMatrix4Single): TMatrix4Double;
function Matrix4Single(const M: TMatrix4Double): TMatrix4Single;
{ @groupEnd }

{$ifdef FPC_OBJFPC}
{ Overload := operator to allow convertion between
  Matrix unit objects and this unit's arrays easy. }
operator := (const V: TVector2_Single): TVector2Single;
operator := (const V: TVector3_Single): TVector3Single;
operator := (const V: TVector4_Single): TVector4Single;
operator := (const V: TVector2Single): TVector2_Single;
operator := (const V: TVector3Single): TVector3_Single;
operator := (const V: TVector4Single): TVector4_Single;
{$endif}

{ prosta matematyka na wektorach  ---------------------------------------------- }

procedure SwapValues(var V1, V2: TVector2Single); overload;
procedure SwapValues(var V1, V2: TVector2Double); overload;
procedure SwapValues(var V1, V2: TVector3Single); overload;
procedure SwapValues(var V1, V2: TVector3Double); overload;
procedure SwapValues(var V1, V2: TVector4Single); overload;
procedure SwapValues(var V1, V2: TVector4Double); overload;

function VectorAverage(const V: TVector3Single): Single; overload;
function VectorAverage(const V: TVector3Double): Double; overload;

{ Linear interpolation between two vector values.
  Returns (1-A) * V1 + A * V2 (well, calculated a little differently for speed).
  So A = 0 gives V1, A = 1 gives V2, and values between and around are
  interpolated.

  @groupBegin }
function Lerp(const a: Single; const V1, V2: TVector2Byte): TVector2Byte; overload;
function Lerp(const a: Single; const V1, V2: TVector3Byte): TVector3Byte; overload;
function Lerp(const a: Single; const V1, V2: TVector4Byte): TVector4Byte; overload;
function Lerp(const a: Single; const V1, V2: TVector2Integer): TVector2Single; overload;
function Lerp(const a: Single; const V1, V2: TVector2Single): TVector2Single; overload;
function Lerp(const a: Single; const V1, V2: TVector3Single): TVector3Single; overload;
function Lerp(const a: Single; const V1, V2: TVector4Single): TVector4Single; overload;
function Lerp(const a: Double; const V1, V2: TVector2Double): TVector2Double; overload;
function Lerp(const a: Double; const V1, V2: TVector3Double): TVector3Double; overload;
function Lerp(const a: Double; const V1, V2: TVector4Double): TVector4Double; overload;

{$ifdef FPC}
function Lerp(const a: Single; const M1, M2: TMatrix3Single): TMatrix3Single; overload;
function Lerp(const a: Single; const M1, M2: TMatrix4Single): TMatrix4Single; overload;
function Lerp(const a: Double; const M1, M2: TMatrix3Double): TMatrix3Double; overload;
function Lerp(const a: Double; const M1, M2: TMatrix4Double): TMatrix4Double; overload;
{$endif FPC}
{ @groupEnd }

{$ifdef HAS_MATRIX_UNIT}
function Vector_Init_Lerp(const A: Single; const V1, V2: TVector3_Single): TVector3_Single; overload;
function Vector_Init_Lerp(const A: Single; const V1, V2: TVector4_Single): TVector4_Single; overload;
function Vector_Init_Lerp(const A: Double; const V1, V2: TVector3_Double): TVector3_Double; overload;
function Vector_Init_Lerp(const A: Double; const V1, V2: TVector4_Double): TVector4_Double; overload;
{$endif}

{ zwraca (1-v2part) * v1 + v2part * v2 czyli cos jak srednia wazona z dwoch wektorow.
  v2part musi byc z przedzialu <0, 1>.
  Mozna o tym myslec jako : wez Segment z punktu v1 do v2, punkt 0 to v1 potem
  rosnie do v2 gdzie staje sie = 1, niniejsza funkcja zwraca punkt na tym odcinku
  wielkosci v2part. }
function Mix2Vectors(const v1, v2: TVector3Single;
  const v2part: Single = 0.5): TVector3Single; overload;
function Mix2Vectors(const v1, v2: TVector2Single;
  const v2part: Single = 0.5): TVector2Single; overload;
procedure Mix2VectorsTo1st(var v1: TVector3Single; const v2: TVector3Single;
  const v2part: Single); overload;
procedure Mix2VectorsTo1st(var v1: TVector2Single; const v2: TVector2Single;
  const v2part: Single); overload;

{ Normalizuj wektor v wg. pierwszych trzech wspolrzednych (argument to
  np. TVector3Single lub TVector4Single. Jesli TVector4Single, to wartosc
  v[3] nie zostanie naruszona).

  Jesli argument to wektor zerowy (ktorego nie mozna znormalizowac)
  to nie zrobi nic (wersja funkcyjna "Normalized" zwroci swoj argument
  nienaruszony) }
procedure NormalizeTo1st3Singlev(vv: PVector3Single);
procedure NormalizeTo1st3Bytev(vv: PVector3Byte);
{$ifndef DELPHI}
procedure NormalizeTo1st(var v: TVector3Single); overload;
procedure NormalizeTo1st(var v: TVector3Double); overload;

function Normalized(const v: TVector3Single): TVector3Single; overload;
function Normalized(const v: TVector3Double): TVector3Double; overload;

{$ifdef HAS_MATRIX_UNIT}
function Vector_Get_Normalized(const V: TVector3_Single): TVector3_Single; overload;
function Vector_Get_Normalized(const V: TVector3_Double): TVector3_Double; overload;

procedure Vector_Normalize(var V: TVector3_Single); overload;
procedure Vector_Normalize(var V: TVector3_Double); overload;
{$endif HAS_MATRIX_UNIT}

{ This normalizes Plane by scaling all *four* coordinates of Plane
  so that length of plane vector (taken from 1st *three* coordinates)
  is one.

  Also, contrary to normal NormalizeTo1st on 3-component vectors,
  this will fail with some awful error (like floating point overflow)
  in case length of plane vector is zero. That's because we know
  that plane vector *must* be always non-zero. }
procedure NormalizePlaneTo1st(var v: TVector4Single); overload;
procedure NormalizePlaneTo1st(var v: TVector4Double); overload;

function ZeroVector(const v: TVector3Single): boolean; overload;
function ZeroVector(const v: TVector3Double): boolean; overload;
function ZeroVector(const v: TVector4Single): boolean; overload;
function ZeroVector(const v: TVector4Double): boolean; overload;

function ZeroVector(const v: TVector4Cardinal): boolean; overload;

function PerfectlyZeroVector(const v: TVector3Single): boolean; overload;
function PerfectlyZeroVector(const v: TVector3Double): boolean; overload;
function PerfectlyZeroVector(const v: TVector4Single): boolean; overload;
function PerfectlyZeroVector(const v: TVector4Double): boolean; overload;

{ Subtract two vectors.

  Versions *To1st place result back into the 1st vector,
  like "-=" operator. Are @italic(very very slightly) faster.

  @groupBegin }
function VectorSubtract(const v1, v2: TVector2Single): TVector2Single; overload;
function VectorSubtract(const v1, v2: TVector2Double): TVector2Double; overload;
function VectorSubtract(const v1, v2: TVector3Single): TVector3Single; overload;
function VectorSubtract(const v1, v2: TVector3Double): TVector3Double; overload;
function VectorSubtract(const v1, v2: TVector4Single): TVector4Single; overload;
function VectorSubtract(const v1, v2: TVector4Double): TVector4Double; overload;
procedure VectorSubtractTo1st(var v1: TVector2Single; const v2: TVector2Single); overload;
procedure VectorSubtractTo1st(var v1: TVector2Double; const v2: TVector2Double); overload;
procedure VectorSubtractTo1st(var v1: TVector3Single; const v2: TVector3Single); overload;
procedure VectorSubtractTo1st(var v1: TVector3Double; const v2: TVector3Double); overload;
procedure VectorSubtractTo1st(var v1: TVector4Single; const v2: TVector4Single); overload;
procedure VectorSubtractTo1st(var v1: TVector4Double; const v2: TVector4Double); overload;
{ @groupEnd }

{ Add two vectors.

  Versions *To1st place result back into the 1st vector,
  like "+=" operator. Are @italic(very very slightly) faster.

  @groupBegin }
function VectorAdd(const v1, v2: TVector2Single): TVector2Single; overload;
function VectorAdd(const v1, v2: TVector2Double): TVector2Double; overload;
function VectorAdd(const v1, v2: TVector3Single): TVector3Single; overload;
function VectorAdd(const v1, v2: TVector3Double): TVector3Double; overload;
function VectorAdd(const v1, v2: TVector4Single): TVector4Single; overload;
function VectorAdd(const v1, v2: TVector4Double): TVector4Double; overload;
procedure VectorAddTo1st(var v1: TVector2Single; const v2: TVector2Single); overload;
procedure VectorAddTo1st(var v1: TVector2Double; const v2: TVector2Double); overload;
procedure VectorAddTo1st(var v1: TVector3Single; const v2: TVector3Single); overload;
procedure VectorAddTo1st(var v1: TVector3Double; const v2: TVector3Double); overload;
procedure VectorAddTo1st(var v1: TVector4Single; const v2: TVector4Single); overload;
procedure VectorAddTo1st(var v1: TVector4Double; const v2: TVector4Double); overload;
{ @groupEnd }

{ Scale vector (aka multiply by scalar).

  Versions *To1st scale place result back into the 1st vector,
  like "*=" operator. Are @italic(very very slightly) faster.

  @groupBegin }
function VectorScale(const v1: TVector2Single; const Scalar: Single): TVector2Single; overload;
function VectorScale(const v1: TVector2Double; const Scalar: Double): TVector2Double; overload;
function VectorScale(const v1: TVector3Single; const Scalar: Single): TVector3Single; overload;
function VectorScale(const v1: TVector3Double; const Scalar: Double): TVector3Double; overload;
function VectorScale(const v1: TVector4Single; const Scalar: Single): TVector4Single; overload;
function VectorScale(const v1: TVector4Double; const Scalar: Double): TVector4Double; overload;
procedure VectorScaleTo1st(var v1: TVector2Single; const Scalar: Single); overload;
procedure VectorScaleTo1st(var v1: TVector2Double; const Scalar: Double); overload;
procedure VectorScaleTo1st(var v1: TVector3Single; const Scalar: Single); overload;
procedure VectorScaleTo1st(var v1: TVector3Double; const Scalar: Double); overload;
procedure VectorScaleTo1st(var v1: TVector4Single; const Scalar: Single); overload;
procedure VectorScaleTo1st(var v1: TVector4Double; const Scalar: Double); overload;
{ @groupEnd }

{ Negate vector (return -V).

  Versions *To1st scale place result back into the 1st vector.
  Are @italic(very very slightly) faster.

  @groupBegin }
function VectorNegate(const v: TVector2Single): TVector2Single; overload;
function VectorNegate(const v: TVector2Double): TVector2Double; overload;
function VectorNegate(const v: TVector3Single): TVector3Single; overload;
function VectorNegate(const v: TVector3Double): TVector3Double; overload;
function VectorNegate(const v: TVector4Single): TVector4Single; overload;
function VectorNegate(const v: TVector4Double): TVector4Double; overload;
procedure VectorNegateTo1st(var v: TVector2Single); overload;
procedure VectorNegateTo1st(var v: TVector2Double); overload;
procedure VectorNegateTo1st(var v: TVector3Single); overload;
procedure VectorNegateTo1st(var v: TVector3Double); overload;
procedure VectorNegateTo1st(var v: TVector4Single); overload;
procedure VectorNegateTo1st(var v: TVector4Double); overload;
{ @groupEnd }

{ przeskaluj wektor tak zeby mial zadana dlugosc.
  (tak, Normalized moznaby wyrazic jako VectorAdjustToLength(,1)).
  VecLen may be negative, then we will additionally negate the
  direction of the vector. }
function VectorAdjustToLength(const v: TVector3Single; VecLen: Single): TVector3Single; overload;
function VectorAdjustToLength(const v: TVector3Double; VecLen: Double): TVector3Double; overload;
procedure VectorAdjustToLengthTo1st(var v: TVector3Single; VecLen: Single); overload;
procedure VectorAdjustToLengthTo1st(var v: TVector3Double; VecLen: Double); overload;

{ Note that this costs you one Sqrt calculation
  (contrary to VectorLenSqr). }
function VectorLen(const v: TVector2Single): Single; overload;
function VectorLen(const v: TVector2Double): Double; overload;
function VectorLen(const v: TVector3Single): Single; overload;
function VectorLen(const v: TVector3Double): Double; overload;
function VectorLen(const v: TVector3Byte): Single; overload;
function VectorLen(const v: TVector4Single): Single; overload;
function VectorLen(const v: TVector4Double): Double; overload;

{ This returns Sqr(VectorLen(v)). As everyone knows,
  VectorLen is implemented as Sqrt(VectorLenSqr(v)).
  Calculating VectorLenSqr is very quick but calculating VectorLen
  (in a general situation) always requires calculating Sqrt,
  so it's slow.

  So use VectorLenSqr instead of VectorLen whenever possible.
  E.g. if you want to know is vector longer than given X,
  compare VectorLenSqr(V) > Sqr(X) instead of VectorLen(V) > X
  (Note that this is equivalent as long as X >= 0.
  When X < 0 "VectorLen(V) > X" is always true,
  but "VectorLenSqr(V) > Sqr(X)" not necessarily. But this is not a problem
  usually.) This is because Sqr is lighting-fast (it's just miltiplication)
  while Sqrt is not.

  Also note that when you have a vector with discrete values
  (like TVector3Byte), VectorLenSqr is able to simply return integer
  value, while VectorLen must return floating-point value. }
function VectorLenSqr(const v: TVector2Single): Single; overload;
function VectorLenSqr(const v: TVector2Double): Double; overload;
function VectorLenSqr(const v: TVector3Single): Single; overload;
function VectorLenSqr(const v: TVector3Double): Double; overload;
function VectorLenSqr(const v: TVector3Byte): Integer; overload;
function VectorLenSqr(const v: TVector4Single): Single; overload;
function VectorLenSqr(const v: TVector4Double): Double; overload;

{ iloczyn wektorowy dwoch wektorow, czyli wektor prostopadly do nich obu.
  Zgodnie z def., vector product dla wektorow rownoleglych (czyli
  v1 = v2 * jakis skalar) to (0, 0, 0), jezeli v1 lub v2 to wektory
  zerowe to wynik to takze wektor zerowy (co zreszta wynika juz z
  poprzedniej uwagi, przeciez wektor zerowy jest rownolegly do kazdego
  innego wektora).

  To zadanie ma dwa rozwiazania (o ile v1 i v2 nie sa rownolegle),
  niniejsza funkcja zwraca jedno z nich, drugie z nich to wektor przeciwny
  do pierwszego rozwiazania .

  Ktore zwraca ? Zgodnie z def. zwraca takie rozw. ze v1, v2, result maja
  sie do siebie tak jak wektory osiowe X, Y, Z w ukladzie przestrzeni.

  Wynika z tego np. ze wektor normalny trojkata (p0, p1, p2) zdefiniowany jako
  N := VectorProduct(p1-p0, p1-p2) bedzie wektorem normalnym wychodzacym
  ze strony CCW trojkata o ile masz uklad prawoskretny.
  Jezeli ustawiles w OpenGL'u glFrontFace(GL_CW)
  (domyslnie jest GL_CCW) to musisz jako wektory normalne podawac
  VectorNegate(N), albo po prostu brac N := VectorProduct(p1-p2, p1-p0) }
function VectorProduct(const v1, v2: TVector3Double): TVector3Double; overload;
function VectorProduct(const v1, v2: TVector3Single): TVector3Single; overload;

{ Dot product (aka scalar product) of two vectors.

  Overloaded versions that take as one argument 3-component vector and
  as the second argument 4-component vector: they simply behave like
  the missing 4th component would be equal 1.0. This is useful when
  V1 is a 3D point and V2 is something like plane equation.

  @groupBegin }
function VectorDotProduct(const v1, v2: TVector2Single): Single; overload;
function VectorDotProduct(const v1, v2: TVector2Double): Double; overload;

function VectorDotProduct(const v1, v2: TVector3Single): Single; overload;
function VectorDotProduct(const v1, v2: TVector3Double): Double; overload;

function VectorDotProduct(const v1, v2: TVector4Single): Single; overload;
function VectorDotProduct(const v1, v2: TVector4Double): Double; overload;

function VectorDotProduct(const v1: TVector3Single; const v2: TVector4Single): Single; overload;
function VectorDotProduct(const v1: TVector3Double; const v2: TVector4Double): Double; overload;
{ @groupEnd }

{ Multiplies two vectors component-wise.

  That is, Result[I] := V1[I] * V2[I] for each I.

  @groupBegin }
function VectorMultiplyComponents(const v1, v2: TVector3Single): TVector3Single; overload;
function VectorMultiplyComponents(const v1, v2: TVector3Double): TVector3Double; overload;
procedure VectorMultiplyComponentsTo1st(var v1: TVector3Single; const v2: TVector3Single); overload;
procedure VectorMultiplyComponentsTo1st(var v1: TVector3Double; const v2: TVector3Double); overload;
{ @groupEnd }

{ kazda skladowa zostanie podniesiona do potegi Exp.
  Warunki jak dla Math.Power(), tzn. jesli ktoras skladowa <0 i Exp <> 0 to
  wyjatek EInvalidArgument (wersja To1st zostawi swoj argument w niezdef. stanie) }
function VectorExpComponents(const v: TVector3Single; const Exp: Single): TVector3Single; overload;
function VectorExpComponents(const v: TVector3Double; const Exp: Double): TVector3Double; overload;
procedure VectorExpComponentsTo1st(var v: TVector3Single; const Exp: Single); overload;
procedure VectorExpComponentsTo1st(var v: TVector3Double; const Exp: Double); overload;

{ zwraca cosinus kata pomiedzy wektorami. EVectorMathInvalidOp if v1 or v2
  = (0, 0, 0).

  Speed note: this costs you one Sqrt.
  Better use CosAngleBetweenNormals when possible, this avoids Sqrt
  (but assumes that arguments have length = 1). }
function CosAngleBetweenVectors(const v1, v2: TVector3Single): Single; overload;
function CosAngleBetweenVectors(const v1, v2: TVector3Double): Double; overload;
function CosAngleBetweenNormals(const v1, v2: TVector3Single): Single; overload;
function CosAngleBetweenNormals(const v1, v2: TVector3Double): Double; overload;

{ zwraca kat pomiedzy wektorami w radianach. Zawsze zwraca Pi>= kat >=0.
  EVectorMathInvalidOp if v1 or v2 = (0, 0, 0).

  Speed note: this costs you one ArcCos, and one Sqrt.
  Better use AngleRadBetweenNormals when possible, this avoids Sqrt
  (but assumes that arguments have length = 1). }
function AngleRadBetweenVectors(const v1, v2: TVector3Single): Single; overload;
function AngleRadBetweenVectors(const v1, v2: TVector3Double): Double; overload;
function AngleRadBetweenNormals(const v1, v2: TVector3Single): Single; overload;
function AngleRadBetweenNormals(const v1, v2: TVector3Double): Double; overload;

{ obroc punkt pt o angleDeg stopni wokol osi wyznaczonej przez wektor axisVec
  zaczepiony w punkcie (0, 0, 0). Zwroc wynik.
  Moglbys ten sam wynik uzyskac robiac
    result := Vector3SinglePoint( MatrixMultPoint(
      RotationMatrixDeg(angleDeg, axisVec), Vector4Single(pt) ) )
  ,MatrixMultPoint i RotationMatrix sa zdefiniowane nizej w tym module.
  Ta procedura zrobi to po prostu nieco szybciej.
  Ale na pewno wynik bedzie ten sam - w szczegolnosci, obroty beda
  w ta sama strone, a wiec tez zgodnie z kierunkiem obrotow OpenGLa. }
function RotatePointAroundAxisDeg(angleDeg: Single; const pt: TVector3Single; const axisVec: TVector3Single): TVector3Single; overload;
function RotatePointAroundAxisDeg(angleDeg: Double; const pt: TVector3Double; const axisVec: TVector3Double): TVector3Double; overload;
function RotatePointAroundAxisRad(angleRad: Single; const pt: TVector3Single; const axisVec: TVector3Single): TVector3Single; overload;
function RotatePointAroundAxisRad(angleRad: Double; const pt: TVector3Double; const axisVec: TVector3Double): TVector3Double; overload;

{ ktora wspolrzedna (0, 1, 2) (i ew. 3 dla wersji z TVector4*) jest najwieksza ?
  Gdy sa dwie lub trzy lub cztery najwieksze wspolrzedne to wybieramy tak
  ze 0-wa ma pierwszenstwo nad 1-sza a ta ma pierwszenstwo nad 2-ga a ta nad 3-cia. }
function MaxVectorCoord(const v: TVector3Single): integer; overload;
function MaxVectorCoord(const v: TVector3Double): integer; overload;
function MaxVectorCoord(const v: TVector4Single): integer; overload;
function MaxVectorCoord(const v: TVector4Double): integer; overload;
function MaxAbsVectorCoord(const v: TVector3Single): integer; overload;
function MaxAbsVectorCoord(const v: TVector3Double): integer; overload;

procedure SortAbsVectorCoord(const v: TVector3Single; out Max, Middle, Min: Integer); overload;
procedure SortAbsVectorCoord(const v: TVector3Double; out Max, Middle, Min: Integer); overload;

{ PlaneDirInDirection - taka banalna procedurka - dla zadanego
  Plane (albo jako PlaneDir albo jako czworka Plane, ale to bez znaczenia
  bo i tak Plane[3] jest bez znaczenia) zwroci PlaneDir albo -PlaneDir,
  w zaleznosci od tego w ktora strone Plane wskazuje Direction - to znaczy
  patrzac na Plane jako na podzial przestrzeni na dwie polprzestrzenie,
  zwroci taki wektor ze bedzie normalny do plaszczyzny i bedzie wskazywal
  w ta sama polprzestrzen co Direction.

  Jezeli Direction jest rownolegle do Plane (czyli prostopadle do PlaneDir)
  to zwroci PlaneDir (wtedy powinno byc ci obojetne w ktora strone
  normal zwroci).

  Zwraca dokladnie PlaneDir lub -PlaneDir, wiec jezeli np. Plane byl
  znormalizowany to zwrocony PlaneDir lub -PlaneDir tez bedzie.

  PlaneDirNotInDirection dziala jak PlaneDirInDirection(Plane, -Direction).

  To jedna z tych funkcji ktorych implementacja jest w dwoch linijkach a komentarz
  jest duzo dluzszy...  }
function PlaneDirInDirection(const Plane: TVector4Single; const Direction: TVector3Single): TVector3Single; overload;
function PlaneDirInDirection(const PlaneDir, Direction: TVector3Single): TVector3Single; overload;
function PlaneDirInDirection(const Plane: TVector4Double; const Direction: TVector3Double): TVector3Double; overload;
function PlaneDirInDirection(const PlaneDir, Direction: TVector3Double): TVector3Double; overload;
function PlaneDirNotInDirection(const Plane: TVector4Single; const Direction: TVector3Single): TVector3Single; overload;
function PlaneDirNotInDirection(const PlaneDir, Direction: TVector3Single): TVector3Single; overload;
function PlaneDirNotInDirection(const Plane: TVector4Double; const Direction: TVector3Double): TVector3Double; overload;
function PlaneDirNotInDirection(const PlaneDir, Direction: TVector3Double): TVector3Double; overload;

type
  EPlanesParallel = class(Exception);

{ If planes are parallel, exception EPlanesParalell is raised. }
procedure TwoPlanesIntersectionLine(const Plane0, Plane1: TVector4Single;
  out Line0, LineVector: TVector3Single); overload;
procedure TwoPlanesIntersectionLine(const Plane0, Plane1: TVector4Double;
  out Line0, LineVector: TVector3Double); overload;

type
  ELinesParallel = class(Exception);

{ Intersection of two 2D lines.
  @raises ELinesParallel if lines parallel
  @groupBegin }
function Lines2DIntersection(const Line0, Line1: TVector3Single): TVector2Single; overload;
function Lines2DIntersection(const Line0, Line1: TVector3Double): TVector2Double; overload;
{ @groupEnd }

{ This takes three plane equations (these planes MUST have exactly
  one common point, otherwise this function can fail with some
  undefined error) and returns their intersection point. }
function ThreePlanesIntersectionPoint(
  const Plane0, Plane1, Plane2: TVector4Single): TVector3Single; overload;
function ThreePlanesIntersectionPoint(
  const Plane0, Plane1, Plane2: TVector4Double): TVector3Double; overload;

{ Move a plane by a specifed vector.
  The first three plane numbers (plane normal vector) don't change
  (so, in particular, if you used the plane to define the half-space,
  the half-space gets moved as it should).

  PlaneAntiMove work like PlaneMove, but they translate by negated Move
  So it's like PlaneAntiMove(Plane, V) := PlaneMove(Plane, -V),
  but (very slightly) faster.

  This works Ok with invalid planes (1st three components = 0),
  that is after the move the plane remains invalid (1st three components
  remain = 0).

  @groupBegin }
function PlaneMove(const Plane: TVector4Single;
  const Move: TVector3Single): TVector4Single; overload;
function PlaneMove(const Plane: TVector4Double;
  const Move: TVector3Double): TVector4Double; overload;

procedure PlaneMoveTo1st(var Plane: TVector4Single; const Move: TVector3Single); overload;
procedure PlaneMoveTo1st(var Plane: TVector4Double; const Move: TVector3Double); overload;

function PlaneAntiMove(const Plane: TVector4Single;
  const Move: TVector3Single): TVector4Single; overload;
function PlaneAntiMove(const Plane: TVector4Double;
  const Move: TVector3Double): TVector4Double; overload;
{ @groupEnd }

{ zwraca true gdy oba wektory wskazuja na ta sama strone Plane.
  Gdy jeden z wektorow jest rownolegly do Plane zawsze zwraca true.
  Plane mozesz podac jako 4 lub 3 liczby (kierunek plane) - przeciez 4 liczba
  i tak nie bedzie uzywana. }
function VectorsSamePlaneDirections(const v1, v2: TVector3Single; const Plane: TVector4Single): boolean; overload;
function VectorsSamePlaneDirections(const v1, v2: TVector3Double; const Plane: TVector4Double): boolean; overload;
function VectorsSamePlaneDirections(const v1, v2: TVector3Single; const PlaneDir: TVector3Single): boolean; overload;
function VectorsSamePlaneDirections(const v1, v2: TVector3Double; const PlaneDir: TVector3Double): boolean; overload;

{ zwraca true wtt. gdy oba punkty leza po tej samej stronie Plane lub
  gdy jeden z punktow lezy na Plane. }
function PointsSamePlaneSides(const p1, p2: TVector3Single; const Plane: TVector4Single): boolean; overload;
function PointsSamePlaneSides(const p1, p2: TVector3Double; const Plane: TVector4Double): boolean; overload;

function PointsDistance(const v1, v2: TVector3Single): Single; overload;
function PointsDistance(const v1, v2: TVector3Double): Double; overload;
function PointsDistanceSqr(const v1, v2: TVector3Single): Single; overload;
function PointsDistanceSqr(const v1, v2: TVector3Double): Double; overload;
function PointsDistanceSqr(const v1, v2: TVector2Single): Single; overload;
function PointsDistanceSqr(const v1, v2: TVector2Double): Double; overload;

{ Distance between 3D points projected on Z = 0 plane (i.e. Z coord
  of points is just ignored.)
  @groupBegin }
function PointsDistanceXYSqr(const v1, v2: TVector3Single): Single; overload;
function PointsDistanceXYSqr(const v1, v2: TVector3Double): Double; overload;
{ @groupEnd }

{ Compare two vectors, with epsilon to tolerate slightly different floats.
  Uses singleEqualityEpsilon, DoubleEqualityEpsilon just like FloatsEqual.

  Note that the case when EqualityEpsilon (or SingleEqualityEpsilon
  or DoubleEqualityEpsilon) is exactly 0 is optimized here
  (i.e. we compare using direct CompareMem routines).

  @seealso VectorsPerfectlyEqual

  @groupBegin }
function VectorsEqual(const v1, v2: TVector2Single): boolean; overload;
function VectorsEqual(const v1, v2: TVector2Double): boolean; overload;
function VectorsEqual(const v1, v2: TVector2Single; const EqualityEpsilon: Single): boolean; overload;
function VectorsEqual(const v1, v2: TVector2Double; const EqualityEpsilon: Double): boolean; overload;
function VectorsEqual(const v1, v2: TVector3Single): boolean; overload;
function VectorsEqual(const v1, v2: TVector3Double): boolean; overload;
function VectorsEqual(const v1, v2: TVector3Single; const EqualityEpsilon: Single): boolean; overload;
function VectorsEqual(const v1, v2: TVector3Double; const EqualityEpsilon: Double): boolean; overload;
function VectorsEqual(const v1, v2: TVector4Single): boolean; overload;
function VectorsEqual(const v1, v2: TVector4Double): boolean; overload;
function VectorsEqual(const v1, v2: TVector4Single; const EqualityEpsilon: Single): boolean; overload;
function VectorsEqual(const v1, v2: TVector4Double; const EqualityEpsilon: Double): boolean; overload;
{ @groupEnd }

{ Compare two vectors using perfect comparison, that is using the "=" operator
  to compare floats.
  @seealso VectorsEqual
  @groupBegin }
function VectorsPerfectlyEqual(const v1, v2: TVector2Single): boolean; overload; {$ifdef SUPPORTS_INLINE} inline; {$endif}
function VectorsPerfectlyEqual(const v1, v2: TVector2Double): boolean; overload; {$ifdef SUPPORTS_INLINE} inline; {$endif}
function VectorsPerfectlyEqual(const v1, v2: TVector3Single): boolean; overload; {$ifdef SUPPORTS_INLINE} inline; {$endif}
function VectorsPerfectlyEqual(const v1, v2: TVector3Double): boolean; overload; {$ifdef SUPPORTS_INLINE} inline; {$endif}
function VectorsPerfectlyEqual(const v1, v2: TVector4Single): boolean; overload; {$ifdef SUPPORTS_INLINE} inline; {$endif}
function VectorsPerfectlyEqual(const v1, v2: TVector4Double): boolean; overload; {$ifdef SUPPORTS_INLINE} inline; {$endif}
{ @groupEnd }

function MatricesEqual(const M1, M2: TMatrix3Single; const EqualityEpsilon: Single): boolean; overload;
function MatricesEqual(const M1, M2: TMatrix3Double; const EqualityEpsilon: Double): boolean; overload;
function MatricesEqual(const M1, M2: TMatrix4Single; const EqualityEpsilon: Single): boolean; overload;
function MatricesEqual(const M1, M2: TMatrix4Double; const EqualityEpsilon: Double): boolean; overload;

function MatricesPerfectlyEqual(const M1, M2: TMatrix3Single): boolean; overload;
function MatricesPerfectlyEqual(const M1, M2: TMatrix3Double): boolean; overload;
function MatricesPerfectlyEqual(const M1, M2: TMatrix4Single): boolean; overload;
function MatricesPerfectlyEqual(const M1, M2: TMatrix4Double): boolean; overload;

function VectorsPerp(const v1, v2: TVector3Single): boolean; overload;
function VectorsPerp(const v1, v2: TVector3Double): boolean; overload;

{ Are the two vectors parallel (one is a scaled version of another).
  In particular, if one of the vectors is zero, then this is @true.
  @groupBegin }
function VectorsParallel(const v1, v2: TVector3Single): boolean; overload;
function VectorsParallel(const v1, v2: TVector3Double): boolean; overload;
{ @groupEnd }

{ spraw zeby miedzy wektorem v1 a v2 byl kat angle poprzez ew. zmiane
  wektora v1. Wektory v1 i v2 NIE MOGA BYC ROWNOLEGLE, czyli musza
  definiowac 1-znacznie plaszczyzne w przestrzeni. Wektor v1 zostanie
  dostosowany aby kat byl odpowiedni w taki sposob ze wektory v1 i v2
  ciagle beda definiowaly ta sama plaszczyzne. Jeszcze jedno : kierunek
  kata zalezy oczywiscie od kolejnosci wektorow, wszystko przez to
  ze dla kazdego punktu plaszczyny mozna wyznaczyc dwa wektory do niej
  prostopadle wychodzace z tego punktu. Robione jest tak zeby wektor v1
  po obrocie o kat AngleDeg wokol VectorProduct(v1, v2) byl na miejscu
  wektora v2.

  Wiec jezeli zamieniasz wektory kolejnoscia w parametrach (v1 z v2)
  to zamieniasz jednoczesnie kierunek kata wobec tego juz NIE POWINIENES
  negowac wektora aby zachowac taka sama zaleznosc miedzy wektorami.
  Innymi slowy, polecenia
    (v1, v2, 90) i
    (v2, v1, 90) daja taka sama zaleznosc miedzy dwoma wektorami,
    mimo ze wydaje sie ze razem ze zmiana kolejnosci wektorow powinno
    sie zmienic kat na przeciwny.
  Dlugosc wektora v1 jest zachowywana. }
procedure MakeVectorsAngleDegOnTheirPlane(var v1: TVector3Single;
  const v2: TVector3Single; AngleDeg: Single); overload;
procedure MakeVectorsAngleDegOnTheirPlane(var v1: TVector3Double;
  const v2: TVector3Double; AngleDeg: Double); overload;
procedure MakeVectorsAngleRadOnTheirPlane(var v1: TVector3Single;
  const v2: TVector3Single; AngleRad: Single); overload;
procedure MakeVectorsAngleRadOnTheirPlane(var v1: TVector3Double;
  const v2: TVector3Double; AngleRad: Double); overload;

{ This is a shortcut (that may be calculated faster)
  for MakeVectorsAngleDefOnTheirPlane(v1, v2, 90). }
procedure MakeVectorsOrthoOnTheirPlane(var v1: TVector3Single;
  const v2: TVector3Single); overload;
procedure MakeVectorsOrthoOnTheirPlane(var v1: TVector3Double;
  const v2: TVector3Double); overload;

{ Return, deterministically, some vector orthogonal to V.
  When V is non-zero, then the result is non-zero.

  This uses a simple trick to make an orthogonal vector:
  if you take @code(Result := (V[1], -V[0], 0)) then the dot product
  between the Result and V is zero, so they are orthogonal.
  There's also a small check needed to use a similar but different version
  when the only non-zero component of V is V[2].

  @groupBegin }
function AnyOrthogonalVector(const v: TVector3Single): TVector3Single; overload;
function AnyOrthogonalVector(const v: TVector3Double): TVector3Double; overload;
{ @groupEnd }

function IsLineParallelToPlane(const lineVector: TVector3Single; const plane: TVector4Single): boolean; overload;
function IsLineParallelToPlane(const lineVector: TVector3Double; const plane: TVector4Double): boolean; overload;

function IsLineParallelToSimplePlane(const lineVector: TVector3Single;
  const PlaneConstCoord: integer): boolean; overload;
function IsLineParallelToSimplePlane(const lineVector: TVector3Double;
  const PlaneConstCoord: integer): boolean; overload;

{ Assuming that Vector1 and Vector2 are parallel,
  do they point in the same direction?

  This assumes that both vectors are non-zero.
  If one of the vectors is zero, the result is undefined --- false or true.
  (but the function will surely not raise some floating point error etc.) }
function AreParallelVectorsSameDirection(
  const Vector1, Vector2: TVector3Single): boolean; overload;
function AreParallelVectorsSameDirection(
  const Vector1, Vector2: TVector3Double): boolean; overload;

{ Orthogonally project a point on a plane, that is find a closest
  point to Point lying on a Plane.
  @groupBegin }
function PointOnPlaneClosestToPoint(const plane: TVector4Single; const point: TVector3Single): TVector3Single; overload;
function PointOnPlaneClosestToPoint(const plane: TVector4Double; const point: TVector3Double): TVector3Double; overload;
{ @groupEnd }

function PointToPlaneDistanceSqr(const Point: TVector3Single;
  const Plane: TVector4Single): Single; overload;
function PointToPlaneDistanceSqr(const Point: TVector3Double;
  const Plane: TVector4Double): Double; overload;

{ Distance from a point to a plane (with already normalized direction).

  Note: distance of the plane from origin point (0,0,0) may be simply
  obtained by Abs(Plane[3]) when Plane is Normalized.
  @groupBegin }
function PointToNormalizedPlaneDistance(const Point: TVector3Single;
  const Plane: TVector4Single): Single; overload;
function PointToNormalizedPlaneDistance(const Point: TVector3Double;
  const Plane: TVector4Double): Double; overload;
{ @groupEnd }

{ Distance from a point to a plane.

  Note that calculating this costs you one Sqrt
  (contrary to PointToPlaneDistanceSqr or
  PointToNormalizedPlaneDistance).

  @groupBegin }
function PointToPlaneDistance(const Point: TVector3Single;
  const Plane: TVector4Single): Single; overload;
function PointToPlaneDistance(const Point: TVector3Double;
  const Plane: TVector4Double): Double; overload;
{ @groupEnd }

function PointToSimplePlaneDistance(const point: TVector3Single;
  const PlaneConstCoord: integer; const PlaneConstValue: Single): Single; overload;
function PointToSimplePlaneDistance(const point: TVector3Double;
  const PlaneConstCoord: integer; const PlaneConstValue: Double): Double; overload;

function PointOnLineClosestToPoint(const line0, lineVector, point: TVector3Single): TVector3Single; overload;
function PointOnLineClosestToPoint(const line0, lineVector, point: TVector3Double): TVector3Double; overload;

function PointToLineDistanceSqr(const point, line0, lineVector: TVector3Single): Single; overload;
function PointToLineDistanceSqr(const point, line0, lineVector: TVector3Double): Double; overload;

{ zwraca false i nie modyfikuje intersection (ani t) jezeli linia rownolegla
  z plane (zwroc uwage gdy linia jest zawarta w plane (a wiec de facto
  JEST collision tylko ze na calej dlugosci linii) to odpowiada false).
  Wpp. zwraca Intersection (lub t takie ze Intersection moze byc obliczone
  jako Line0 + LineVector*t). Ta ostatnia metoda pozwala nam w szczegolnosci
  miec z tego wprost implementacje TryRayPlaneIntersection i
  TryRaySegmentDirIntersection (ktore polegaja tylko na nalozeniu pewnych
  ograniczen na t). }
function TryPlaneLineIntersection(out intersection: TVector3Single;
  const plane: TVector4Single; const line0, lineVector: TVector3Single): boolean; overload;
function TryPlaneLineIntersection(out intersection: TVector3Double;
  const plane: TVector4Double; const line0, lineVector: TVector3Double): boolean; overload;
function TryPlaneLineIntersection(out t: Single;
  const plane: TVector4Single; const line0, lineVector: TVector3Single): boolean; overload;
function TryPlaneLineIntersection(out t: Double;
  const plane: TVector4Double; const line0, lineVector: TVector3Double): boolean; overload;

{ zwraca false i nie modyfikuje intersection jezeli ray rownolegly z plane
  lub ray nie moze trafic w plane (bo musialby byc skierowany w przeciwna
  strone) }
function TrySimplePlaneRayIntersection(out Intersection: TVector3Single;
  const PlaneConstCoord: integer; const PlaneConstValue: Single;
  const Ray0, RayVector: TVector3Single): boolean; overload;
function TrySimplePlaneRayIntersection(out Intersection: TVector3Double;
  const PlaneConstCoord: integer; const PlaneConstValue: Double;
  const Ray0, RayVector: TVector3Double): boolean; overload;
function TrySimplePlaneRayIntersection(out Intersection: TVector3Single; out T: Single;
  const PlaneConstCoord: integer; const PlaneConstValue: Single;
  const Ray0, RayVector: TVector3Single): boolean; overload;
function TrySimplePlaneRayIntersection(out Intersection: TVector3Double; out T: Double;
  const PlaneConstCoord: integer; const PlaneConstValue: Double;
  const Ray0, RayVector: TVector3Double): boolean; overload;
function TrySimplePlaneRayIntersection(out T: Single;
  const PlaneConstCoord: integer; const PlaneConstValue: Single;
  const Ray0, RayVector: TVector3Single): boolean; overload;
function TrySimplePlaneRayIntersection(out T: Double;
  const PlaneConstCoord: integer; const PlaneConstValue: Double;
  const Ray0, RayVector: TVector3Double): boolean; overload;

{ zwraca false i nie modyfikuje intersection jezeli Segment rownolegly z plane
  lub Segment nie moze trafic w plane (bo musialby byc dluzszy w jedna lub
  druga strone) }
function TrySimplePlaneSegmentDirIntersection(var Intersection: TVector3Single;
  const PlaneConstCoord: integer; const PlaneConstValue: Single;
  const Segment0, SegmentVector: TVector3Single): boolean; overload;
function TrySimplePlaneSegmentDirIntersection(var Intersection: TVector3Double;
  const PlaneConstCoord: integer; const PlaneConstValue: Double;
  const Segment0, SegmentVector: TVector3Double): boolean; overload;
function TrySimplePlaneSegmentDirIntersection(var Intersection: TVector3Single; var T: Single;
  const PlaneConstCoord: integer; const PlaneConstValue: Single;
  const Segment0, SegmentVector: TVector3Single): boolean; overload;
function TrySimplePlaneSegmentDirIntersection(var Intersection: TVector3Double; var T: Double;
  const PlaneConstCoord: integer; const PlaneConstValue: Double;
  const Segment0, SegmentVector: TVector3Double): boolean; overload;
function TrySimplePlaneSegmentDirIntersection(var T: Single;
  const PlaneConstCoord: integer; const PlaneConstValue: Single;
  const Segment0, SegmentVector: TVector3Single): boolean; overload;
function TrySimplePlaneSegmentDirIntersection(var T: Double;
  const PlaneConstCoord: integer; const PlaneConstValue: Double;
  const Segment0, SegmentVector: TVector3Double): boolean; overload;

function TrySimplePlaneSegmentIntersection(
  out Intersection: TVector3Single;
  const PlaneConstCoord: integer; const PlaneConstValue: Single;
  const Pos1, Pos2: TVector3Single): boolean; overload;
function TrySimplePlaneSegmentIntersection(
  out Intersection: TVector3Double;
  const PlaneConstCoord: integer; const PlaneConstValue: Double;
  const Pos1, Pos2: TVector3Double): boolean; overload;
function TrySimplePlaneSegmentIntersection(
  out Intersection: TVector3Single; out T: Single;
  const PlaneConstCoord: integer; const PlaneConstValue: Single;
  const Pos1, Pos2: TVector3Single): boolean; overload;
function TrySimplePlaneSegmentIntersection(
  out Intersection: TVector3Double; out T: Double;
  const PlaneConstCoord: integer; const PlaneConstValue: Double;
  const Pos1, Pos2: TVector3Double): boolean; overload;
function TrySimplePlaneSegmentIntersection(
  out T: Single;
  const PlaneConstCoord: integer; const PlaneConstValue: Single;
  const Pos1, Pos2: TVector3Single): boolean; overload;
function TrySimplePlaneSegmentIntersection(
  out T: Double;
  const PlaneConstCoord: integer; const PlaneConstValue: Double;
  const Pos1, Pos2: TVector3Double): boolean; overload;

{ zwraca false i nie modyfikuje Intersection ani T jezeli ray rownolegly do plane
  lub jezeli ray jest w zla strone (to znaczy, gdyby rayVector
  byl =VectorNegate(RayVector) to wtedy byloby przeciecie).
  Oprocz / zamiast Intersection moze tez zwrocic T >= 0 takie ze
  Intersection = Ray0 + RayVector * T. Tak naprawde wersje zwracajace Intersection
  uzywaja zaimplementowanej wersji ktora zwraca T i potem obliczaja Intersection
  z powyzszej zaleznosci. }
function TryPlaneRayIntersection(out Intersection: TVector3Single;
  const Plane: TVector4Single; const Ray0, RayVector: TVector3Single): boolean; overload;
function TryPlaneRayIntersection(out Intersection: TVector3Double;
  const Plane: TVector4Double; const Ray0, RayVector: TVector3Double): boolean; overload;
function TryPlaneRayIntersection(out Intersection: TVector3Single; out T: Single;
  const Plane: TVector4Single; const Ray0, RayVector: TVector3Single): boolean; overload;
function TryPlaneRayIntersection(out Intersection: TVector3Double; out T: Double;
  const Plane: TVector4Double; const Ray0, RayVector: TVector3Double): boolean; overload;

function TryPlaneSegmentDirIntersection(out Intersection: TVector3Single;
  const Plane: TVector4Single; const Segment0, SegmentVector: TVector3Single): boolean; overload;
function TryPlaneSegmentDirIntersection(out Intersection: TVector3Double;
  const Plane: TVector4Double; const Segment0, SegmentVector: TVector3Double): boolean; overload;
function TryPlaneSegmentDirIntersection(out Intersection: TVector3Single; out T: Single;
  const Plane: TVector4Single; const Segment0, SegmentVector: TVector3Single): boolean; overload;
function TryPlaneSegmentDirIntersection(out Intersection: TVector3Double; out T: Double;
  const Plane: TVector4Double; const Segment0, SegmentVector: TVector3Double): boolean; overload;

function IsPointOnSegmentLineWithinSegment(const intersection, pos1, pos2: TVector3Single): boolean; overload;
function IsPointOnSegmentLineWithinSegment(const intersection, pos1, pos2: TVector3Double): boolean; overload;

{ w nazwie jest podkleslone _Different_ Points zebys pamietal zeby zapewnic
  ze p1 i p2 to rozne punkty - inaczej nie bedzie mozna wyznaczyc prostej ! }
function LineOfTwoDifferentPoints2d(const p1, p2: TVector2Single): TVector3Single; overload;
function LineOfTwoDifferentPoints2d(const p1, p2: TVector2Double): TVector3Double; overload;

function PointToSegmentDistanceSqr(const point, pos1, pos2: TVector3Single): Single; overload;
function PointToSegmentDistanceSqr(const point, pos1, pos2: TVector3Double): Double; overload;

function IsTunnelSphereCollision(const Tunnel1, Tunnel2: TVector3Single;
  const TunnelRadius: Single; const SphereCenter: TVector3Single;
  const SphereRadius: Single): boolean; overload;
function IsTunnelSphereCollision(const Tunnel1, Tunnel2: TVector3Double;
  const TunnelRadius: Double; const SphereCenter: TVector3Double;
  const SphereRadius: Double): boolean; overload;

function IsSpheresCollision(const Sphere1Center: TVector3Single; const Sphere1Radius: Single;
  const Sphere2Center: TVector3Single; const Sphere2Radius: Single): boolean; overload;
function IsSpheresCollision(const Sphere1Center: TVector3Double; const Sphere1Radius: Double;
  const Sphere2Center: TVector3Double; const Sphere2Radius: Double): boolean; overload;

function IsSegmentSphereCollision(const pos1, pos2, SphereCenter: TVector3Single;
  const SphereRadius: Single): boolean; overload;
function IsSegmentSphereCollision(const pos1, pos2, SphereCenter: TVector3Double;
  const SphereRadius: Double): boolean; overload;

{ cos do trojkatow TTriangle** ------------------------------------------------- }

{ ta funkcja radzi sobie ze zdegenerowanymi trojkatami, tzn.trojkatami
  ktore tak naprawde sa punktem lub odcinkiem. Zwraca false jezeli
  trojkaty sa wlasnie tak zdegenerowane; wpp. trojkat wyznacza 1-znacznie
  plaszczyzne wiec jest dobrym trojkatem wiec odpowiada true. }
function IsValidTriangle(const Tri: TTriangle3Single): boolean; overload;
function IsValidTriangle(const Tri: TTriangle3Double): boolean; overload;

{ liczy wektor normalny trojkata jako (Tri[2]-Tri[1]) x (Tri[0]-Tri[1])
  a wiec zwraca ten sposrod wektorow normalnych ktory wychodzi z CCW trojkata
  dla ukladu prawostronnego. Wersja "Dir" nie normalizuje ! (i dziala
  przez to nieco szybciej)

  Jako wyjatek, definiujemy tez co ta procedura robi dla zdegenerowanych
  trojkatow : mianowicie zwraca wektor zerowy. }
function TriangleDir(const Tri: TTriangle3Single): TVector3Single; overload;
function TriangleDir(const Tri: TTriangle3Double): TVector3Double; overload;
function TriangleDir(const p0, p1, p2: TVector3Single): TVector3Single; overload;
function TriangleDir(const p0, p1, p2: TVector3Double): TVector3Double; overload;
function TriangleNormal(const Tri: TTriangle3Single): TVector3Single; overload;
function TriangleNormal(const Tri: TTriangle3Double): TVector3Double; overload;
function TriangleNormal(const p0, p1, p2: TVector3Single): TVector3Single; overload;
function TriangleNormal(const p0, p1, p2: TVector3Double): TVector3Double; overload;

{ Transform triangle by 4x4 matrix. This simply transforms each triangle point.

  @raises(ETransformedResultInvalid Raised when matrix
  will transform some point to a direction (vector with 4th component
  equal zero). In this case we just cannot interpret the result as a 3D point.)

  @groupBegin }
function TriangleTransform(const Tri: TTriangle3Single; const M: TMatrix4Single): TTriangle3Single; overload;
function TriangleTransform(const Tri: TTriangle3Double; const M: TMatrix4Double): TTriangle3Double; overload;
{ @groupEnd }

{ VerticesStride = 0 oznacza VerticesStride = SizeOf(TVector3Single).
  Liczy normal trojkata VerticesArray[Indexes[0]], VerticesArray[Indexes[1]],
  VerticesArray[Indexes[2]] gdzie kolejne elementy z VerticesArray sa
  wyciagane przy pomocy Stride. }
function IndexedTriangleNormal(const Indexes: TVector3Cardinal;
  VerticesArray: PVector3Single; VerticesStride: integer): TVector3Single;

{ Surface area of 3D triangle.
  This works for degenerated (equal to line segment or even single point)
  triangles too: returns 0 for them.

  @groupBegin }
function TriangleArea(const Tri: TTriangle3Single): Single; overload;
function TriangleArea(const Tri: TTriangle3Double): Double; overload;
function TriangleAreaSqr(const Tri: TTriangle3Single): Single; overload;
function TriangleAreaSqr(const Tri: TTriangle3Double): Double; overload;
{ @groupEnd }

{ oblicz plane of triangle. Wiadomo ze to zadanie ma niesk wiele rozw
  bo kazdy plane ma niesk wiele reprezentacji jako Ax+By+Cz+D = 0.
  TrianglePlane znajduje po prostu jakies rozwiazanie,

  It's guaranteed that the direction of this plane (i.e. first 3 items
  of returned vector) will be in the same direction as calcualted by
  TriangleDir, which means that it points outward from CCW side of
  the triangle (assuming right-handed coord system).

  TriangleNormPlane zwraca taki plane ze jego pierwsze trzy pozycje tworza
  wektor znormalizowany, tj. dlugosci 1. W ten sposob TrianglePlane
  liczy przy okazji TriangleNormal.

  For three points that do not define a plane, a plane with first three
  components = 0 is returned. In fact, the 4th component will be zero too
  in this case (for now), but depend on it. }
function TrianglePlane(const Tri: TTriangle3Single): TVector4Single; overload;
function TrianglePlane(const Tri: TTriangle3Double): TVector4Double; overload;
function TrianglePlane(const p0, p1, p2: TVector3Single): TVector4Single; overload;
function TrianglePlane(const p0, p1, p2: TVector3Double): TVector4Double; overload;
function TriangleNormPlane(const Tri: TTriangle3Single): TVector4Single; overload;
function TriangleNormPlane(const Tri: TTriangle3Double): TVector4Double; overload;

function IsPointWithinTriangle2d(const P: TVector2Single; const Tri: TTriangle2Single): boolean; overload;
function IsPointWithinTriangle2d(const P: TVector2Double; const Tri: TTriangle2Double): boolean; overload;

{ Zalozmy ze wiadomo ze punkt P lezy na plaszczyznie trojkata T.
  Pytamy czy P jest w srodku samego trojkata ?
  Mozesz podac TriDir jesli je znasz, to przyspieszy dzialanie
  (nie potrzebujemy TriPlane, tzn. czwartego wspolczynnika). }
function IsPointOnTrianglePlaneWithinTriangle(const P: TVector3Single;
  const Tri: TTriangle3Single; const TriDir: TVector3Single): boolean; overload;
function IsPointOnTrianglePlaneWithinTriangle(const P: TVector3Double;
  const Tri: TTriangle3Double; const TriDir: TVector3Double): boolean; overload;

{ sprawdzanie kolizji z trojkatem. Mozesz podac razem z trojkatem jego TriPlane,
  jeslu juz go masz wyliczonego. }
function IsTriangleSegmentCollision(const Tri: TTriangle3Single;
  const TriPlane: TVector4Single;
  const pos1, pos2: TVector3Single): boolean; overload;
function IsTriangleSegmentCollision(const Tri: TTriangle3Double;
  const TriPlane: TVector4Double;
  const pos1, pos2: TVector3Double): boolean; overload;
function IsTriangleSegmentCollision(const Tri: TTriangle3Single;
  const pos1, pos2: TVector3Single): boolean; overload;
function IsTriangleSegmentCollision(const Tri: TTriangle3Double;
  const pos1, pos2: TVector3Double): boolean; overload;

function IsTriangleSphereCollision(const Tri: TTriangle3Single;
  const TriPlane: TVector4Single;
  const SphereCenter: TVector3Single; SphereRadius: Single): boolean; overload;
function IsTriangleSphereCollision(const Tri: TTriangle3Double;
  const TriPlane: TVector4Double;
  const SphereCenter: TVector3Double; SphereRadius: Double): boolean; overload;
function IsTriangleSphereCollision(const Tri: TTriangle3Single;
  const SphereCenter: TVector3Single; SphereRadius: Single): boolean; overload;
function IsTriangleSphereCollision(const Tri: TTriangle3Double;
  const SphereCenter: TVector3Double; SphereRadius: Double): boolean; overload;

{ przeciecie promienia z odcinkiem. Mozesz podac TriPlane jesli masz juz
  wyliczone; zwraca false i nie modyfikuje Intersection jezeli nie ma
  przeciecia, wpp. zwraca true i ustawia Intersection. }
function TryTriangleSegmentCollision(var Intersection: TVector3Single;
  const Tri: TTriangle3Single; const TriPlane: TVector4Single;
  const Pos1, Pos2: TVector3Single): boolean; overload;
function TryTriangleSegmentCollision(var Intersection: TVector3Double;
  const Tri: TTriangle3Double; const TriPlane: TVector4Double;
  const Pos1, Pos2: TVector3Double): boolean; overload;

{ przeciecie promienia z odcinkiemDir. Mozesz podac TriPlane jesli masz juz
  wyliczone; zwraca false i nie modyfikuje Intersection (ani T) jezeli nie ma
  przeciecia, wpp. zwraca true i ustawia Intersection (i T). }
function TryTriangleSegmentDirCollision(var Intersection: TVector3Single;
  const Tri: TTriangle3Single; const TriPlane: TVector4Single;
  const Segment0, SegmentVector: TVector3Single): boolean; overload;
function TryTriangleSegmentDirCollision(var Intersection: TVector3Double;
  const Tri: TTriangle3Double; const TriPlane: TVector4Double;
  const Segment0, SegmentVector: TVector3Double): boolean; overload;
function TryTriangleSegmentDirCollision(var Intersection: TVector3Single; var T: Single;
  const Tri: TTriangle3Single; const TriPlane: TVector4Single;
  const Segment0, SegmentVector: TVector3Single): boolean; overload;
function TryTriangleSegmentDirCollision(var Intersection: TVector3Double; var T: Double;
  const Tri: TTriangle3Double; const TriPlane: TVector4Double;
  const Segment0, SegmentVector: TVector3Double): boolean; overload;

{ przeciecie promienia z trojkatem. Mozesz podac TriPlane jesli masz juz
  wyliczone zwraca false i nie modyfikuje Intersection jezeli nie ma
  przeciecia, wpp. zwraca true i ustawia Intersection. }
function TryTriangleRayCollision(var Intersection: TVector3Single;
  const Tri: TTriangle3Single; const TriPlane: TVector4Single;
  const Ray0, RayVector: TVector3Single): boolean; overload;
function TryTriangleRayCollision(var Intersection: TVector3Double;
  const Tri: TTriangle3Double; const TriPlane: TVector4Double;
  const Ray0, RayVector: TVector3Double): boolean; overload;
function TryTriangleRayCollision(var Intersection: TVector3Single; var T: Single;
  const Tri: TTriangle3Single; const TriPlane: TVector4Single;
  const Ray0, RayVector: TVector3Single): boolean; overload;
function TryTriangleRayCollision(var Intersection: TVector3Double; var T: Double;
  const Tri: TTriangle3Double; const TriPlane: TVector4Double;
  const Ray0, RayVector: TVector3Double): boolean; overload;

{ Calculates normalized normal vector for polygon composed from
  indexed vertices. Polygon is defines as vertices
  Verts[Indices[0]], Verts[Indices[1]] ... Verts[Indices[IndicesCount-1]].
  Returns normal pointing from CCW.

  It's secured against invalid indexes on Indices list (that's the only
  reason why it takes VertsCount parameter, after all): they are ignored.

  If the polygon is degenerated, that is it doesn't determine a plane in
  3D space (this includes, but is not limited, to cases when there are
  less than 3 valid points, like when IndicesCount < 3)
  then it returns ResultForIncorrectPoly.

  @groupBegin }
function IndexedPolygonNormal(
  Indices: PArray_Longint; IndicesCount: integer;
  Verts: PArray_Vector3Single; const VertsCount: Integer;
  const ResultForIncorrectPoly: TVector3Single): TVector3Single; overload;
function IndexedPolygonNormal(
  Indices: PArray_Longint; IndicesCount: integer;
  Verts: PVector3Single; const VertsCount: Integer; const VertsStride: PtrUInt;
  const ResultForIncorrectPoly: TVector3Single): TVector3Single; overload;
{ @groupEnd }

{ Surface area of indexed convex polygon.
  Polygon is defines as vertices
  Verts[Indices[0]], Verts[Indices[1]] ... Verts[Indices[IndicesCount-1]].

  It's secured against invalid indexes on Indices list (that's the only
  reason why it takes VertsCount parameter, after all): they are ignored.

  @groupBegin }
function IndexedConvexPolygonArea(
  Indices: PArray_Longint; IndicesCount: integer;
  Verts: PArray_Vector3Single; const VertsCount: Integer): Single; overload;
function IndexedConvexPolygonArea(
  Indices: PArray_Longint; IndicesCount: integer;
  Verts: PVector3Single; const VertsCount: Integer; const VertsStride: PtrUInt): Single; overload;
{ @groupEnd }

{ dla zadanego polygonu 2d, ktory nie musi byc convex i moze byc kawalkami
  zdegenerowany (= niektore trojki jego wierzcholkow daja zdegenerowane
  trojkaty, moze sie tak zdarzyc np. gdy sa wielokrotne wierzcholki albo
  gdy trzy kolejne wierzcholki sa wspolliniowe (czyli srodkowy jest zbedny)):
    IsPolygon2dCCW obliczy czy polygon jest CCW (widziany na plaszczyznie
      kartezjanskiej, z +X w prawo i +Y w gore). Zwroci > 0 jesli polygon
      jest CCW, <0 jesli jest CW i 0 jesli polygon ma pole = 0 i tym
      samym nie ma zdefiniowanej orientacji.
    Polygon2dArea obliczy pole wielokata.
  Sa wersje z parametrami array of TVector2Single, zwracam wiec uwage ze mozna
  tutaj bez problemu podac jako parametr TTriangle2Single. }
function IsPolygon2dCCW(Verts: PArray_Vector2Single; const VertsCount: Integer): Single; overload;
function IsPolygon2dCCW(const Verts: array of TVector2Single): Single; overload;
function Polygon2dArea(Verts: PArray_Vector2Single; const VertsCount: Integer): Single; overload;
function Polygon2dArea(const Verts: array of TVector2Single): Single; overload;

{ losowy punkt na trojkacie generowany ze stala gestoscia na pole,
  tzn. gestosc = 1/PoleTrojkata }
function SampleTrianglePoint(const Tri: TTriangle3Single): TVector3Single;

{ pare funkcji *To*Str --------------------------------------------------------

  Funckje ToNiceStr uzywaja FloatToNiceStr ktore robi
  Format('%'+FloatNiceFormat, [f]) a wiec zmieniajac FloatNiceFormat
  mozesz kontrolowac z jaka dokladnoscia floaty beda wypisywane.
  Chcac zachowac pewien luz nie zamierzam okreslac dokladnie w interfejsie
  tego modulu w jaki sposob te funkcje wypisuja dany typ. Funkcje ktore
  moga zwracac string z newline'ami mozesz rozpoznac po parametrze
  "LineIndent" - takie funkcje nie umieszczaja nigdy nl na samym koncu i
  poczatku stringa !

  Funkcja FloatToRawStr wypisuje dokladna wartosc floata, uzywajac notacji
  wykladniczej jesli trzeba. Funkcje ToRawStr uzywaja FloatToRawStr
  i wypisuja po prostu ciag liczb rozdzielonych spacjami.
  W ten sposob sa one dobre jesli chcesz
  zapisac dokladna wartosc wektora czy czegos w pliku.
}

var FloatNiceFormat: string = 'f';

function FloatToNiceStr(f: Single): string; overload;
function FloatToNiceStr(f: Double): string; overload;
function VectorToNiceStr(const v: array of Byte): string; overload;
function VectorToNiceStr(const v: array of Single): string; overload;
function VectorToNiceStr(const v: array of Double): string; overload;
function MatrixToNiceStr(const v: TMatrix4Single; const LineIndent: string): string; overload;
function MatrixToNiceStr(const v: TMatrix4Double; const LineIndent: string): string; overload;
function TriangleToNiceStr(const t: TTriangle2Single): string; overload;
function TriangleToNiceStr(const t: TTriangle2Double): string; overload;
function TriangleToNiceStr(const t: TTriangle3Single): string; overload;
function TriangleToNiceStr(const t: TTriangle3Double): string; overload;

function FloatToRawStr(f: Single): string; overload;
function FloatToRawStr(f: Double): string; overload;
function VectorToRawStr(const v: array of Single): string; overload;
function VectorToRawStr(const v: array of Double): string; overload;
function MatrixToRawStr(const v: TMatrix4Single; const LineIndent: string): string; overload;
function MatrixToRawStr(const v: TMatrix4Double; const LineIndent: string): string; overload;
function TriangleToRawStr(const t: TTriangle3Single): string; overload;
function TriangleToRawStr(const t: TTriangle3Double): string; overload;

{ troche matematyki na macierzach ----------------------------------------------- }

function MatrixAdd(const m1, m2: TMatrix3Single): TMatrix3Single; overload;
function MatrixAdd(const m1, m2: TMatrix4Single): TMatrix4Single; overload;
function MatrixAdd(const m1, m2: TMatrix3Double): TMatrix3Double; overload;
function MatrixAdd(const m1, m2: TMatrix4Double): TMatrix4Double; overload;

procedure MatrixAddTo1st(var m1: TMatrix3Single; const m2: TMatrix3Single); overload;
procedure MatrixAddTo1st(var m1: TMatrix4Single; const m2: TMatrix4Single); overload;
procedure MatrixAddTo1st(var m1: TMatrix3Double; const m2: TMatrix3Double); overload;
procedure MatrixAddTo1st(var m1: TMatrix4Double; const m2: TMatrix4Double); overload;

function MatrixSubtract(const m1, m2: TMatrix3Single): TMatrix3Single; overload;
function MatrixSubtract(const m1, m2: TMatrix4Single): TMatrix4Single; overload;
function MatrixSubtract(const m1, m2: TMatrix3Double): TMatrix3Double; overload;
function MatrixSubtract(const m1, m2: TMatrix4Double): TMatrix4Double; overload;

procedure MatrixSubtractTo1st(var m1: TMatrix3Single; const m2: TMatrix3Single); overload;
procedure MatrixSubtractTo1st(var m1: TMatrix4Single; const m2: TMatrix4Single); overload;
procedure MatrixSubtractTo1st(var m1: TMatrix3Double; const m2: TMatrix3Double); overload;
procedure MatrixSubtractTo1st(var m1: TMatrix4Double; const m2: TMatrix4Double); overload;

function MatrixNegate(const m1: TMatrix3Single): TMatrix3Single; overload;
function MatrixNegate(const m1: TMatrix4Single): TMatrix4Single; overload;
function MatrixNegate(const m1: TMatrix3Double): TMatrix3Double; overload;
function MatrixNegate(const m1: TMatrix4Double): TMatrix4Double; overload;

function MatrixMultScalar(const m: TMatrix3Single; const s: Single): TMatrix3Single; overload;
function MatrixMultScalar(const m: TMatrix4Single; const s: Single): TMatrix4Single; overload;
function MatrixMultScalar(const m: TMatrix3Double; const s: Double): TMatrix3Double; overload;
function MatrixMultScalar(const m: TMatrix4Double; const s: Double): TMatrix4Double; overload;

type
  ETransformedResultInvalid = class(EVectorMathInvalidOp);

{ Transform a 3D point with 4x4 matrix.

  This works by temporarily converting point to 4-component vector
  (4th component is 1). After multiplying matrix * vector we divide
  by 4th component. So this works Ok for all matrices,
  even with last row different than identity (0, 0, 0, 1).
  E.g. this works for projection matrices too.

  @raises(ETransformedResultInvalid This is raised when matrix
  will transform point to a direction (vector with 4th component
  equal zero). In this case we just cannot interpret the result as a 3D point.)

  @groupBegin }
function MatrixMultPoint(const m: TMatrix4Single; const pt: TVector3Single): TVector3Single; overload;
function MatrixMultPoint(const m: TMatrix4Double; const pt: TVector3Double): TVector3Double; overload;
{ @groupEnd }

{ Transform a 3D direction with 4x4 matrix.

  This works by temporarily converting direction to 4-component vector
  (4th component is 0). After multiplying matrix * vector we check
  is the 4th component still 0 (eventually raising ETransformedResultInvalid).

  @raises(ETransformedResultInvalid This is raised when matrix
  will transform direction to a point (vector with 4th component
  nonzero). In this case we just cannot interpret the result as a 3D direction.)

  @groupBegin }
function MatrixMultDirection(const m: TMatrix4Single;
  const Dir: TVector3Single): TVector3Single; overload;
function MatrixMultDirection(const m: TMatrix4Double;
  const Dir: TVector3Double): TVector3Double; overload;
{ @groupEnd }

function MatrixMultVector(const m: TMatrix3Single; const v: TVector3Single): TVector3Single; overload;
function MatrixMultVector(const m: TMatrix4Single; const v: TVector4Single): TVector4Single; overload;
function MatrixMultVector(const m: TMatrix3Double; const v: TVector3Double): TVector3Double; overload;
function MatrixMultVector(const m: TMatrix4Double; const v: TVector4Double): TVector4Double; overload;

function MatrixMult(const m1, m2: TMatrix3Single): TMatrix3Single; overload;
function MatrixMult(const m1, m2: TMatrix4Single): TMatrix4Single; overload;
function MatrixMult(const m1, m2: TMatrix3Double): TMatrix3Double; overload;
function MatrixMult(const m1, m2: TMatrix4Double): TMatrix4Double; overload;

function MatrixRow(const m: TMatrix2Single; const Row: Integer): TVector2Single; overload;
function MatrixRow(const m: TMatrix3Single; const Row: Integer): TVector3Single; overload;
function MatrixRow(const m: TMatrix4Single; const Row: Integer): TVector4Single; overload;
function MatrixRow(const m: TMatrix2Double; const Row: Integer): TVector2Double; overload;
function MatrixRow(const m: TMatrix3Double; const Row: Integer): TVector3Double; overload;
function MatrixRow(const m: TMatrix4Double; const Row: Integer): TVector4Double; overload;

{$ifdef HAS_MATRIX_UNIT}
function MatrixDeterminant(const M: TMatrix2Single): Single; overload;
function MatrixDeterminant(const M: TMatrix2Double): Double; overload;
function MatrixDeterminant(const M: TMatrix3Single): Single; overload;
function MatrixDeterminant(const M: TMatrix3Double): Double; overload;
function MatrixDeterminant(const M: TMatrix4Single): Single; overload;
function MatrixDeterminant(const M: TMatrix4Double): Double; overload;

{ Inverse the matrix.

  They do division by Determinant internally, so will raise exception
  from this float division if the matrix is not reversible.

  @groupBegin }
function MatrixInverse(const M: TMatrix2Single; const Determinant: Single): TMatrix2Single; overload;
function MatrixInverse(const M: TMatrix2Double; const Determinant: Double): TMatrix2Double; overload;
function MatrixInverse(const M: TMatrix3Single; const Determinant: Single): TMatrix3Single; overload;
function MatrixInverse(const M: TMatrix3Double; const Determinant: Double): TMatrix3Double; overload;
function MatrixInverse(const M: TMatrix4Single; const Determinant: Single): TMatrix4Single; overload;
function MatrixInverse(const M: TMatrix4Double; const Determinant: Double): TMatrix4Double; overload;
{ @groupEnd }

{ Inverse the matrix, trying harder (but possibly slower).

  Basically, they internally calculate determinant and then calculate
  inverse using this determinant. Return @false if the determinant is zero.

  The main feature is that Single precision versions actually internally
  calculate everything (determinant and inverse) in Double precision.
  This gives better accuracy, and safety from matrices with very very small
  (but not zero) determinants.

  This is quite important for many matrices. For example, a 4x4 matrix
  with scaling = 1/200 (which can be easily found in practice,
  see e.g. castle/data/levels/gate/gate_processed.wrl) already
  has determinant = 1/8 000 000, which will not pass Zero test
  (with SingleEqualityEpsilon). But it's possible to calculate it
  (even on Single precision, although safer in Double precision).

  @groupBegin }
function TryMatrixInverse(const M: TMatrix2Single; out MInverse: TMatrix2Single): boolean; overload;
function TryMatrixInverse(const M: TMatrix2Double; out MInverse: TMatrix2Double): boolean; overload;
function TryMatrixInverse(const M: TMatrix3Single; out MInverse: TMatrix3Single): boolean; overload;
function TryMatrixInverse(const M: TMatrix3Double; out MInverse: TMatrix3Double): boolean; overload;
function TryMatrixInverse(const M: TMatrix4Single; out MInverse: TMatrix4Single): boolean; overload;
function TryMatrixInverse(const M: TMatrix4Double; out MInverse: TMatrix4Double): boolean; overload;
{ @groupEnd }
{$endif HAS_MATRIX_UNIT}

{ Multiply vector by a transposition of the same vector.
  For 3d vectors, this results in a 3x3 matrix.
  To put this inside a 4x4 matrix,
  we fill the last row and column just like for an identity matrix.

  This is useful for calculating rotation matrix. }
function VectorMultTransposedSameVector(const v: TVector3Single): TMatrix4Single;

const
  { Special value that you can pass to FrustumProjMatrix and
    PerspectiveProjMatrix as ZFar, with intention to set far plane at infinity.

    If would be "cooler" to define ZFarInfinity as Math.Infinity,
    but operating on Math.Infinity requires unnecessary turning
    off of compiler checks. The point was only to have some special ZFar
    value, so 0 is as good as Infinity. }
  ZFarInfinity = 0.0;

{ Functions to create common 4x4 matrices used in 3D graphics.

  These functions generate the same matrices that are made by corresponding
  OpenGL (gl or glu) functions. So rotations will be generated in the same
  fashion, etc. For exact specification of what matrices they create see
  OpenGL specification for routines glTranslate, glScale, glRotate,
  glOrtho, glFrustum, gluPerspective.

  For frustum and pespective projection matrices, we have a special bonus
  here: you can pass as ZFar the special value ZFarInfinity.
  Then you get perspective projection matrix withour far clipping plane,
  which is very useful for z-fail shadow volumes technique.

  Functions named Matrices below generate both normal and inverted matrices.
  For example, function RotationMatrices returns two matrices that you
  could calculate separately by

@longCode(#
        Matrix: = RotationMatrix( Angle, Axis);
InvertedMatrix: = RotationMatrix(-Angle, Axis);
#)

  This is useful sometimes, and generating them both at the same time
  allows for some speedup (for example, calling RotationMatrix twice will
  calculate sincos of Angle twice).

  Note that inverse of scaling matrix will not exist if the
  ScaleFactor has one of the components zero !
  Depending on InvertedMatrixIdentityIfNotExists, this will
  (if @false) raise division by zero exception or (if @true) cause
  the matrix to be set to identity.

  Note that rotation matrix (both normal and inverse) is always defined,
  for Axis = zero both normal and inverse matrices are set to identity.

  @groupBegin }
function TranslationMatrix(const X, Y, Z: Single): TMatrix4Single; overload;
function TranslationMatrix(const X, Y, Z: Double): TMatrix4Single; overload;
function TranslationMatrix(const Transl: TVector3Single): TMatrix4Single; overload;
function TranslationMatrix(const Transl: TVector3Double): TMatrix4Single; overload;

procedure TranslationMatrices(const X, Y, Z: Single; out Matrix, InvertedMatrix: TMatrix4Single); overload;
procedure TranslationMatrices(const X, Y, Z: Double; out Matrix, InvertedMatrix: TMatrix4Single); overload;
procedure TranslationMatrices(const Transl: TVector3Single; out Matrix, InvertedMatrix: TMatrix4Single); overload;
procedure TranslationMatrices(const Transl: TVector3Double; out Matrix, InvertedMatrix: TMatrix4Single); overload;

function ScalingMatrix(const ScaleFactor: TVector3Single): TMatrix4Single;

procedure ScalingMatrices(const ScaleFactor: TVector3Single;
  InvertedMatrixIdentityIfNotExists: boolean;
  out Matrix, InvertedMatrix: TMatrix4Single);

function RotationMatrixRad(const AngleRad: Single; const Axis: TVector3Single): TMatrix4Single; overload;
function RotationMatrixDeg(const AngleDeg: Single; const Axis: TVector3Single): TMatrix4Single; overload;
function RotationMatrixRad(const AngleRad: Single; const AxisX, AxisY, AxisZ: Single): TMatrix4Single; overload;
function RotationMatrixDeg(const AngleDeg: Single; const AxisX, AxisY, AxisZ: Single): TMatrix4Single; overload;

procedure RotationMatricesRad(const AngleRad: Single; const Axis: TVector3Single;
  out Matrix, InvertedMatrix: TMatrix4Single);

function OrthoProjMatrix(const left, right, bottom, top, zNear, zFar: Single): TMatrix4Single;
function Ortho2dProjMatrix(const left, right, bottom, top: Single): TMatrix4Single;
function FrustumProjMatrix(const left, right, bottom, top, zNear, zFar: Single): TMatrix4Single;
function PerspectiveProjMatrixDeg(const fovyDeg, aspect, zNear, zFar: Single): TMatrix4Single;
function PerspectiveProjMatrixRad(const fovyRad, aspect, zNear, zFar: Single): TMatrix4Single;
{ @groupEnd }

{ Multiply matrix M by translation matrix.

  This is equivalent to M := MultMatrix(M, TranslationMatrix(Transl)),
  but it works much faster since TranslationMatrix is a very simple matrix
  and multiplication by it may be much optimized.

  An additional speedup comes from the fact that the result is placed
  back in M (so on places where M doesn't change (and there's a lot
  of them for multiplication with translation matrix) there's no useless
  copying).

  MultMatricesTranslation is analogous to calculating both
  TranslationMatrix(Transl) and it's inverse, and then
@longCode(#
  M := MultMatrix(M, translation);
  MInvert := MultMatrix(inverted translation, MInvert);
#)

  The idea is that if M represented some translation, and MInvert it's
  inverse, then after MultMatricesTranslation this will still hold.

  @groupBegin }
procedure MultMatrixTranslation(var M: TMatrix4Single; const Transl: TVector3Single); overload;
procedure MultMatrixTranslation(var M: TMatrix4Double; const Transl: TVector3Double); overload;
procedure MultMatricesTranslation(var M, MInvert: TMatrix4Single; const Transl: TVector3Single); overload;
procedure MultMatricesTranslation(var M, MInvert: TMatrix4Double; const Transl: TVector3Double); overload;
{ @groupEnd }

function MatrixDet4x4(const mat: TMatrix4Single): Single;
function MatrixDet3x3(const a1, a2, a3, b1, b2, b3, c1, c2, c3: Single): Single;
function MatrixDet2x2(const a, b, c, d: Single): Single;

{ TransformTo/FromCoords zamieniaja uklad wspolrzednych - punkty przemnozone
  przez te macierze beda mogly byc podawane w innym ukladzie wspolrzednych
  i mnozenie przez ta macierz bedzie je tlumaczylo na nasz uklad wspolrzednych.

  Parametry New/Old X/Y/Z/Origin podaja jak sie ma nowy uklad wspolrzednych
  (punktow mnozonych przez ta macierz) do oryginalnego ukladu wspolrzednych
  (tzn. tego w ktorym bedziemy dostawac wyniki mnozenia <ta macierz> * <punkt>.

  Roznica miedzy To a From polega na tym jak podajemy parametry :
  @unorderedList(
    @item(
      W wersji To parametry New* podaja jak wyglada nowy uklad wsporzednych
      widziany w punktu widzenia starego. Tzn. to co w starym (oryginalnym)
      ukladzie wspolrzednych jest widoczne jako NewOrigin bedzie w nowym
      ukladzie widoczne (0, 0, 0). To co w oryginalnym ukladzie jest NewY
      bedzie w nowym ukldzie (1, 0, 0) itd. (NewZ bedzie (0, 0, 1) wiec mozesz
      zauwazyc ze te procedury sa zupelnie nieczule na to z jakim ukladem
      (prawo- czy lewo- skretnym) masz do czynienia).)

    @item(
      W wersji From parametry Old* mowia na odwrot: jak jest widziany stary
      (oryginalny) uklad z punktu widzenia starego : to co w oryginalnym
      ukldzie jest punktem (0, 0, 0) bedzie musialo byc w nowym ukladzie wyrazone
      jako OldOrigin itd.

      Wersje From pozwalaja w naturalny sposob implementowac funkcje w rodzaju
      LookAtMatrix (bo w nich tez podajac np. pozycje kamery podajemy tak
      naprawde ze ma byc zrobiona taka transformacja zeby punkt = pozycja kamery
      stal sie punktem 0, 0, 0 w oryginalnym ukladzie).)
  )

  W kwestii opcjonalnego [NoScale] w nazwie : TAK, dlugosci wektorow
  Old/NewX/Y/Z sa wazne - one beda odpowiadac wektorom
  (1, 0, 0), (0, 1, 0) i (0, 0, 1)
  a wiec wektorom jednostkowym. W ten sposob mozna wiec zrobic skalowanie.

  Uzyj wersji NoScale aby wektory Old/NewX/Y/Z byly automatycznie
  normalizowane, w ten sposob nie bedzie skalowania. Speed remark:
  note that NoScale versions call three times Normalized, so they
  do 3 times Sqrt. Versions without "NoScale" don't do this, so they are
  faster. }
function TransformToCoordsMatrix(const NewOrigin,
  NewX, NewY, NewZ: TVector3Single): TMatrix4Single; overload;
function TransformToCoordsMatrix(const NewOrigin,
  NewX, NewY, NewZ: TVector3Double): TMatrix4Single; overload;
function TransformToCoordsNoScaleMatrix(const NewOrigin,
  NewX, NewY, NewZ: TVector3Single): TMatrix4Single; overload;
function TransformToCoordsNoScaleMatrix(const NewOrigin,
  NewX, NewY, NewZ: TVector3Double): TMatrix4Single; overload;

function TransformFromCoordsMatrix(const OldOrigin,
  OldX, OldY, OldZ: TVector3Single): TMatrix4Single; overload;
function TransformFromCoordsMatrix(const OldOrigin,
  OldX, OldY, OldZ: TVector3Double): TMatrix4Single; overload;
function TransformFromCoordsNoScaleMatrix(const OldOrigin,
  OldX, OldY, OldZ: TVector3Single): TMatrix4Single; overload;
function TransformFromCoordsNoScaleMatrix(const OldOrigin,
  OldX, OldY, OldZ: TVector3Double): TMatrix4Single; overload;

{ LookAt/Dir dzialaja zgodnie z prawoskretnym ukladem wspolrz.
  Transformuja scene tak zeby kamera z punktu (0, 0, 0) patrzaca w kierunku
  (0, 0, -1) i o pionie (0, 1, 0) widziala taka scene jakby stala w miejscu
  Eye sceny, patrzyla na punkt Center sceny (lub wzdluz kierunku Dir)
  i miala wektor pionu Up.

  Podobnie jak w gluLookAt i jak w wielu moich funkcjach tak i tutaj nie
  musisz podawac up prostopadlego do Dir (albo do Center-Eye).
  W razie potrzeby funkcja sobie wewnetrznie poprawi Up.

  Dlugosci Dir i Up nie maja znaczenia (podobnie jak odleglosc Center-Eye). }
function LookAtMatrix(const Eye, Center, Up: TVector3Single): TMatrix4Single; overload;
function LookAtMatrix(const Eye, Center, Up: TVector3Double): TMatrix4Single; overload;
function LookDirMatrix(const Eye, Dir, Up: TVector3Single): TMatrix4Single; overload;
function LookDirMatrix(const Eye, Dir, Up: TVector3Double): TMatrix4Single; overload;

{$endif not DELPHI}

{ ---------------------------------------------------------------------------- }
{ @section(Grayscale convertion stuff) }

const
  { Weights to change RGB color to grayscale.

    Explanation: Grayscale color is just a color with red = green = blue.
    So the simplest convertion of RGB to grayscale is just to set
    all three R, G, B components to the average (R + G + B) / 3.
    But, since human eye is most sensitive to green, then to red,
    and least sensitive to blue, it's better to calculate this
    with some non-uniform weights. GrayscaleValuesXxx constants specify
    these weights.

    Taken from libpng manual (so there for further references).

    For GrayscaleByte, they should be used like

  @longCode(#
    (R * GrayscaleValuesByte[0] +
     G * GrayscaleValuesByte[1] +
     G * GrayscaleValuesByte[2]) div 256
  #)

    GrayscaleValuesByte[] are declared as Word type to force implicit convertion
    in above expression from Byte to Word, since you have to use Word range
    to temporarily hold Byte * Byte multiplication in expression above.

    @groupBegin }
  GrayscaleValuesFloat: array [0..2] of Float = (0.212671, 0.715160, 0.072169);
  GrayscaleValuesByte: array [0..2] of Word = (54, 183, 19);
  { @groupEnd }

{ Calculate color intensity, as for converting color to grayscale. }
function GrayscaleValue(const v: TVector3Single): Single; overload;
function GrayscaleValue(const v: TVector3Double): Double; overload;
function GrayscaleValue(const v: TVector3Byte): Byte; overload;

procedure Grayscale3SinglevTo1st(v: PVector3Single);
procedure Grayscale3BytevTo1st(v: PVector3Byte);

procedure GrayscaleTo1st(var v: TVector3Byte); overload;

function Grayscale(const v: TVector3Single): TVector3Single; overload;
function Grayscale(const v: TVector4Single): Tvector4Single; overload;
function Grayscale(const v: TVector3Byte): TVector3Byte; overload;

{ color changing ------------------------------------------------------------ }

type
  { These types are used in many places, look at
    TVRMLOpenGLRenderer.Attrib_ColorModulatorSingle/Byte,
    TVRMLLightSetGL.ColorModulatorSingle,
    TVRMLGLScene.Attrib_ColorModulatorSingle/Byte,
    TBackgroundGL (AColorModulatorSingle/Byte params for constructor),
    Images.ImageModulate }
  TColorModulatorSingleFunc = function (const Color: TVector3Single): TVector3Single;
  TColorModulatorByteFunc = function (const Color: TVector3Byte): TVector3Byte;

{ below are some functions that can be used as above
  TColorModulatorSingleFunc or TColorModulatorByteFunc values. }

function ColorNegativeSingle(const Color: TVector3Single): TVector3Single;
function ColorNegativeByte(const Color: TVector3Byte): TVector3Byte;

{ This is the same as Grayscale }
function ColorGrayscaleSingle(const Color: TVector3Single): TVector3Single;
function ColorGrayscaleByte(const Color: TVector3Byte): TVector3Byte;

{ This the same as Grayscale and then invert colors
  (i.e., Red := 1.0-Red, Green := 1.0-Green etc.) }
function ColorGrayscaleNegativeSingle(const Color: TVector3Single): TVector3Single;
function ColorGrayscaleNegativeByte(const Color: TVector3Byte): TVector3Byte;

{$ifdef FPC}

{ Color*Convert is like converting color to grayscale,
  and then setting value of given channel (Red/Green/Blue)
  to that grayscale value. Two other channels are set to 0. }
function ColorRedConvertSingle(const Color: TVector3Single): TVector3Single;
function ColorRedConvertByte(const Color: TVector3Byte): TVector3Byte;

function ColorGreenConvertSingle(const Color: TVector3Single): TVector3Single;
function ColorGreenConvertByte(const Color: TVector3Byte): TVector3Byte;

function ColorBlueConvertSingle(const Color: TVector3Single): TVector3Single;
function ColorBlueConvertByte(const Color: TVector3Byte): TVector3Byte;

{ Color*Strip simply sets color values for two other channels to 0.
  (so, note that it's something entirely different than
  ImageConvertToChannelTo1st: here we preserve original channel values,
  and remove values on two other channels). }
function ColorRedStripSingle(const Color: TVector3Single): TVector3Single;
function ColorRedStripByte(const Color: TVector3Byte): TVector3Byte;

function ColorGreenStripSingle(const Color: TVector3Single): TVector3Single;
function ColorGreenStripByte(const Color: TVector3Byte): TVector3Byte;

function ColorBlueStripSingle(const Color: TVector3Single): TVector3Single;
function ColorBlueStripByte(const Color: TVector3Byte): TVector3Byte;

{$endif FPC}

{$I vectormath_operators.inc}

{$undef read_interface}

implementation

uses Math, KambiStringUtils;

{$define read_implementation}
{$I dynarray_1.inc}
{$I dynarray_2.inc}
{$I dynarray_3.inc}
{$I dynarray_5.inc}
{$I dynarray_6.inc}
{$I dynarray_7.inc}
{$I dynarray_8.inc}
{$I dynarray_9.inc}
{$I dynarray_10.inc}
{$I dynarray_11.inc}
{$I dynarray_12.inc}

{$I vectormath_operators.inc}

{ TDynVector3SingleArray ----------------------------------------------------- }

procedure TDynVector3SingleArray.AssignNegated(Source: TDynVector3SingleArray);
begin
  Assign(Source);
  Negate;
end;

procedure TDynVector3SingleArray.Negate;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    VectorNegateTo1st(Items[I]);
end;

procedure TDynVector3SingleArray.Normalize;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    NormalizeTo1st(Items[I]);
end;

procedure TDynVector3SingleArray.MultiplyComponents(const V: TVector3Single);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    VectorMultiplyComponentsTo1st(Items[I], V);
end;

procedure TDynVector3SingleArray.AssignLerp(const Fraction: Single;
  V1, V2: TDynVector3SingleArray; Index1, Index2, ACount: Integer);
var
  I: Integer;
begin
  Count := ACount;
  for I := 0 to Count - 1 do
    Items[I] := Lerp(Fraction, V1.Items[Index1 + I], V2.Items[Index2 + I]);
end;

function TDynVector3SingleArray.ToVector4Single(const W: Single): TDynVector4SingleArray;
var
  I: Integer;
begin
  Result := TDynVector4SingleArray.Create(Count);
  for I := 0 to High do
    Result.Items[I] := Vector4Single(Items[I], W);
end;

function TDynVector3SingleArray.MergeCloseVertexes(MergeDistance: Single): Cardinal;
var
  V1, V2: PVector3Single;
  I, J: Integer;
begin
  MergeDistance := Sqr(MergeDistance);
  Result := 0;

  V1 := PVector3Single(Items);
  for I := 0 to High do
  begin
    { Find vertexes closer to Items[I], and merge them.

      Note that this is not optimal: we could avoid processing
      here Items[I] that were detected previously (and possibly merged)
      as being equal to some previous items. But in practice this seems
      not needed, as there are not many merged vertices in typical situation,
      so time saving would be minimal (and small temporary memory cost
      introduced). }

    V2 := PVector3Single(Pointers[I + 1]);
    for J := I + 1 to High do
    begin
      if PointsDistanceSqr(V1^, V2^) < MergeDistance then
        { We do the VectorsPerfectlyEqual comparison only to get nice Result.
          But this *is* an important value for the user, so it's worth it. }
        if not VectorsPerfectlyEqual(V1^, V2^) then
        begin
          V2^ := V1^;
          Inc(Result);
        end;
      Inc(V2);
    end;

    Inc(V1);
  end;
end;

{ TDynVector2SingleArray ----------------------------------------------------- }

function TDynVector2SingleArray.MinMax(out Min, Max: TVector2Single): boolean;
var
  I: Integer;
begin
  Result := Count > 0;
  if Result then
  begin
    Min := Items[0];
    Max := Items[0];
    for I := 1 to High do
    begin
      if Items[I][0] < Min[0] then Min[0] := Items[I][0] else
      if Items[I][0] > Max[0] then Max[0] := Items[I][0];

      if Items[I][1] < Min[1] then Min[1] := Items[I][1] else
      if Items[I][1] > Max[1] then Max[1] := Items[I][1];
    end;
  end;
end;

procedure TDynVector2SingleArray.AssignLerp(const Fraction: Single;
  V1, V2: TDynVector2SingleArray; Index1, Index2, ACount: Integer);
var
  I: Integer;
begin
  Count := ACount;
  for I := 0 to Count - 1 do
    Items[I] := Lerp(Fraction, V1.Items[Index1 + I], V2.Items[Index2 + I]);
end;

{ TDyn*Double ---------------------------------------------------------------- }

function TDynVector2DoubleArray.ToVector2Single: TDynVector2SingleArray;
var
  I: Integer;
  Source: PDouble;
  Dest: PSingle;
begin
  Result := TDynVector2SingleArray.Create(Count);
  Source := PDouble(ItemsArray);
  Dest := PSingle(Result.ItemsArray);
  for I := 0 to Count * 2 - 1 do
  begin
    Dest^ := Source^;
    Inc(Source);
    Inc(Dest);
  end;
end;

function TDynVector3DoubleArray.ToVector3Single: TDynVector3SingleArray;
var
  I: Integer;
  Source: PDouble;
  Dest: PSingle;
begin
  Result := TDynVector3SingleArray.Create(Count);
  Source := PDouble(ItemsArray);
  Dest := PSingle(Result.ItemsArray);
  for I := 0 to Count * 3 - 1 do
  begin
    Dest^ := Source^;
    Inc(Source);
    Inc(Dest);
  end;
end;

function TDynVector4DoubleArray.ToVector4Single: TDynVector4SingleArray;
var
  I: Integer;
  Source: PDouble;
  Dest: PSingle;
begin
  Result := TDynVector4SingleArray.Create(Count);
  Source := PDouble(ItemsArray);
  Dest := PSingle(Result.ItemsArray);
  for I := 0 to Count * 4 - 1 do
  begin
    Dest^ := Source^;
    Inc(Source);
    Inc(Dest);
  end;
end;

function TDynMatrix3DoubleArray.ToMatrix3Single: TDynMatrix3SingleArray;
var
  I: Integer;
  Source: PDouble;
  Dest: PSingle;
begin
  Result := TDynMatrix3SingleArray.Create(Count);
  Source := PDouble(ItemsArray);
  Dest := PSingle(Result.ItemsArray);
  for I := 0 to Count * 3 * 3 - 1 do
  begin
    Dest^ := Source^;
    Inc(Source);
    Inc(Dest);
  end;
end;

function TDynMatrix4DoubleArray.ToMatrix4Single: TDynMatrix4SingleArray;
var
  I: Integer;
  Source: PDouble;
  Dest: PSingle;
begin
  Result := TDynMatrix4SingleArray.Create(Count);
  Source := PDouble(ItemsArray);
  Dest := PSingle(Result.ItemsArray);
  for I := 0 to Count * 4 * 4 - 1 do
  begin
    Dest^ := Source^;
    Inc(Source);
    Inc(Dest);
  end;
end;

{ FloatsEqual ------------------------------------------------------------- }

function FloatsEqual(const f1, f2: Single): boolean;
begin
  if SingleEqualityEpsilon = 0 then
    Result := f1 = f2 else
    Result := Abs(f1-f2) < SingleEqualityEpsilon;
end;

function FloatsEqual(const f1, f2: Double): boolean;
begin
  if DoubleEqualityEpsilon = 0 then
    Result := f1 = f2 else
    Result := Abs(f1-f2) < DoubleEqualityEpsilon;
end;

{$ifndef EXTENDED_EQUALS_DOUBLE}
function FloatsEqual(const f1, f2: Extended): boolean;
begin
  if ExtendedEqualityEpsilon = 0 then
    Result := f1 = f2 else
    Result := Abs(f1-f2) < ExtendedEqualityEpsilon
end;
{$endif}

function FloatsEqual(const f1, f2, EqEpsilon: Single): boolean;
begin
  if EqEpsilon = 0 then
    Result := f1 = f2 else
    Result := Abs(f1-f2) < EqEpsilon
end;

function FloatsEqual(const f1, f2, EqEpsilon: Double): boolean;
begin
  if EqEpsilon = 0 then
    Result := f1 = f2 else
    Result := Abs(f1-f2) < EqEpsilon
end;

{$ifndef EXTENDED_EQUALS_DOUBLE}
function FloatsEqual(const f1, f2, EqEpsilon: Extended): boolean;
begin
  if EqEpsilon = 0 then
    Result := f1 = f2 else
    Result := Abs(f1-f2) < EqEpsilon
end;
{$endif}

function Zero(const f1: Single  ): boolean;
begin
  if SingleEqualityEpsilon = 0 then
    Result := f1 = 0 else
    Result := Abs(f1)<  SingleEqualityEpsilon
end;

function Zero(const f1: Double  ): boolean;
begin
  if DoubleEqualityEpsilon = 0 then
    Result := f1 = 0 else
    Result := Abs(f1)<  DoubleEqualityEpsilon
end;

{$ifndef EXTENDED_EQUALS_DOUBLE}
function Zero(const f1: Extended): boolean;
begin
  if ExtendedEqualityEpsilon = 0 then
    Result := f1 = 0 else
    Result := Abs(f1) < ExtendedEqualityEpsilon
end;
{$endif}

function Zero(const f1, EqEpsilon: Single  ): boolean;
begin
  if EqEpsilon = 0 then
    Result := f1 = 0 else
    result := Abs(f1) < EqEpsilon
end;

function Zero(const f1, EqEpsilon: Double  ): boolean;
begin
  if EqEpsilon = 0 then
    Result := f1 = 0 else
    Result := Abs(f1) < EqEpsilon
end;

{$ifndef EXTENDED_EQUALS_DOUBLE}
function Zero(const f1, EqEpsilon: Extended): boolean;
begin
  if EqEpsilon = 0 then
    Result := f1 = 0 else
    Result := Abs(f1) < EqEpsilon
end;
{$endif}

{ konstruktory typow --------------------------------------------------------- }

function Vector2Integer(const x, y: Integer): TVector2Integer;
begin result[0] := x; result[1] := y end;

function Vector2Cardinal(const x, y: Cardinal): TVector2Cardinal;
begin result[0] := x; result[1] := y end;

function Vector2Single(const x, y: Single): TVector2Single;
begin result[0] := x; result[1] := y end;

function Vector2Single(const V: TVector2Double): TVector2Single;
begin
  Result[0] := V[0];
  Result[1] := V[1];
end;

function Vector2Double(const x, y: Double): TVector2Double;
begin result[0] := x; result[1] := y end;

function Vector4Single(const x, y: Single; const z: Single{=0}; const w: Single{=1}): TVector4Single;
begin
 result[0] := x; result[1] := y; result[2] := z; result[3] := w;
end;

function Vector4Single(const v3: TVector3Single; const w: Single{=1}): TVector4Single;
begin
 move(v3, result, SizeOf(TVector3Single)); result[3] := w;
end;

function Vector4Single(const ub: TVector4Byte): TVector4Single;
begin
 result[0] := ub[0]/255;
 result[1] := ub[1]/255;
 result[2] := ub[2]/255;
 result[3] := ub[3]/255;
end;

function Vector4Single(const v: TVector4Double): TVector4Single;
begin
 result[0] := v[0];
 result[1] := v[1];
 result[2] := v[2];
 result[3] := v[3];
end;

function Vector4Double(const x, y, z, w: Double): TVector4Double;
begin
 result[0] := x;
 result[1] := y;
 result[2] := z;
 result[3] := w;
end;

function Vector4Double(const v: TVector4Single): TVector4Double;
begin
 result[0] := v[0];
 result[1] := v[1];
 result[2] := v[2];
 result[3] := v[3];
end;

function Vector3Single(const x, y: Single; const z: Single{=0.0}): TVector3Single;
begin
 result[0] := x; result[1] := y; result[2] := z;
end;

function Vector3Double(const x, y: Double; const z: Double{=0.0}): TVector3Double;
begin
 result[0] := x; result[1] := y; result[2] := z;
end;

function Vector3Single(const v3: TVector3Double): TVector3Single;
begin
 result[0] := v3[0]; result[1] := v3[1]; result[2] := v3[2];
end;

function Vector3Single(const v3: TVector3Byte): TVector3Single;
begin
 result[0] := v3[0]/255;
 result[1] := v3[1]/255;
 result[2] := v3[2]/255;
end;

function Vector3Single(const v2: TVector2Single; const z: Single): TVector3Single;
begin
 move(v2, result, SizeOf(v2));
 result[2] := z;
end;

function Vector3Double(const v: TVector3Single): TVector3Double;
begin
 result[0] := v[0]; result[1] := v[1]; result[2] := v[2];
end;

function Vector3Byte(x, y, z: Byte): TVector3Byte;
begin
 result[0] := x; result[1] := y; result[2] := z;
end;

function Vector3Byte(const v: TVector3Single): TVector3Byte;
begin
 result[0] := Clamped(Round(v[0]*255), Low(Byte), High(Byte));
 result[1] := Clamped(Round(v[1]*255), Low(Byte), High(Byte));
 result[2] := Clamped(Round(v[2]*255), Low(Byte), High(Byte));
end;

function Vector3Byte(const v: TVector3Double): TVector3Byte;
begin
 result[0] := Clamped(Round(v[0]*255), Low(Byte), High(Byte));
 result[1] := Clamped(Round(v[1]*255), Low(Byte), High(Byte));
 result[2] := Clamped(Round(v[2]*255), Low(Byte), High(Byte));
end;

function Vector3Longint(const p0, p1, p2: Longint): TVector3Longint;
begin
 result[0] := p0;
 result[1] := p1;
 result[2] := p2;
end;

function Vector4Byte(x, y, z, w: Byte): TVector4Byte;
begin
 result[0] := x; result[1] := y; result[2] := z; result[3] := w;
end;

function Vector4Byte(const f4: TVector4Single): TVector4Byte;
begin
 result[0] := Round(f4[0]*255);
 result[1] := Round(f4[1]*255);
 result[2] := Round(f4[2]*255);
 result[3] := Round(f4[3]*255);
end;

function Vector4Byte(const f3: TVector3Byte; w: Byte): TVector4Byte;
begin
 result[0] := f3[0];
 result[1] := f3[1];
 result[2] := f3[2];
 result[3] := w;
end;

function Vector3SinglePoint(const v: TVector4Single): TVector3Single;
begin
 result[0] := v[0]/v[3];
 result[1] := v[1]/v[3];
 result[2] := v[2]/v[3];
end;

function Vector3SingleCut(const v: TVector4Single): TVector3Single;
begin
 move(v, result, SizeOf(result));
end;

function Normal3Single(const x, y: Single; const z: Single{=0}): TVector3Single;
begin
 result[0] := x; result[1] := y; result[2] := z;
 NormalizeTo1st3Singlev(@result);
end;

function Triangle3Single(const T: TTriangle3Double): TTriangle3Single;
begin
 result[0] := Vector3Single(T[0]);
 result[1] := Vector3Single(T[1]);
 result[2] := Vector3Single(T[2]);
end;

function Triangle3Single(const p0, p1, p2: TVector3Single): TTriangle3Single;
begin
 result[0] := p0;
 result[1] := p1;
 result[2] := p2;
end;

function Triangle3Double(const T: TTriangle3Single): TTriangle3Double;
begin
 result[0] := Vector3Double(T[0]);
 result[1] := Vector3Double(T[1]);
 result[2] := Vector3Double(T[2]);
end;

function Triangle3Double(const p0, p1, p2: TVector3Double): TTriangle3Double;
begin
 result[0] := p0;
 result[1] := p1;
 result[2] := p2;
end;

function Vector3SingleFromStr(const s: string): TVector3Single; {$I VectorMath_Vector3FromStr.inc}
function Vector3DoubleFromStr(const s: string): TVector3Double; {$I VectorMath_Vector3FromStr.inc}
function Vector3ExtendedFromStr(const s: string): TVector3Extended; {$I VectorMath_Vector3FromStr.inc}

function Vector4SingleFromStr(const S: string): TVector4Single;
var
  SPosition: Integer;
begin
 SPosition := 1;
 Result[0] := StrToFloat(NextToken(S, SPosition));
 Result[1] := StrToFloat(NextToken(S, SPosition));
 Result[2] := StrToFloat(NextToken(S, SPosition));
 Result[3] := StrToFloat(NextToken(S, SPosition));
 Check(NextToken(s, SPosition) = '',
   'Expected end of string in Vector4SingleFromStr');
end;

{$ifndef DELPHI}
function Matrix2Double(const M: TMatrix2Single): TMatrix2Double;
begin
  Result[0][0] := M[0][0];
  Result[0][1] := M[0][1];

  Result[1][0] := M[1][0];
  Result[1][1] := M[1][1];
end;

function Matrix2Single(const M: TMatrix2Double): TMatrix2Single;
begin
  Result[0][0] := M[0][0];
  Result[0][1] := M[0][1];

  Result[1][0] := M[1][0];
  Result[1][1] := M[1][1];
end;

function Matrix3Double(const M: TMatrix3Single): TMatrix3Double;
begin
  Result[0][0] := M[0][0];
  Result[0][1] := M[0][1];
  Result[0][2] := M[0][2];

  Result[1][0] := M[1][0];
  Result[1][1] := M[1][1];
  Result[1][2] := M[1][2];

  Result[2][0] := M[2][0];
  Result[2][1] := M[2][1];
  Result[2][2] := M[2][2];
end;

function Matrix3Single(const M: TMatrix3Double): TMatrix3Single;
begin
  Result[0][0] := M[0][0];
  Result[0][1] := M[0][1];
  Result[0][2] := M[0][2];

  Result[1][0] := M[1][0];
  Result[1][1] := M[1][1];
  Result[1][2] := M[1][2];

  Result[2][0] := M[2][0];
  Result[2][1] := M[2][1];
  Result[2][2] := M[2][2];
end;

function Matrix4Double(const M: TMatrix4Single): TMatrix4Double;
begin
  Result[0][0] := M[0][0];
  Result[0][1] := M[0][1];
  Result[0][2] := M[0][2];
  Result[0][3] := M[0][3];

  Result[1][0] := M[1][0];
  Result[1][1] := M[1][1];
  Result[1][2] := M[1][2];
  Result[1][3] := M[1][3];

  Result[2][0] := M[2][0];
  Result[2][1] := M[2][1];
  Result[2][2] := M[2][2];
  Result[2][3] := M[2][3];

  Result[3][0] := M[3][0];
  Result[3][1] := M[3][1];
  Result[3][2] := M[3][2];
  Result[3][3] := M[3][3];
end;

function Matrix4Single(const M: TMatrix4Double): TMatrix4Single;
begin
  Result[0][0] := M[0][0];
  Result[0][1] := M[0][1];
  Result[0][2] := M[0][2];
  Result[0][3] := M[0][3];

  Result[1][0] := M[1][0];
  Result[1][1] := M[1][1];
  Result[1][2] := M[1][2];
  Result[1][3] := M[1][3];

  Result[2][0] := M[2][0];
  Result[2][1] := M[2][1];
  Result[2][2] := M[2][2];
  Result[2][3] := M[2][3];

  Result[3][0] := M[3][0];
  Result[3][1] := M[3][1];
  Result[3][2] := M[3][2];
  Result[3][3] := M[3][3];
end;
{$endif not DELPHI}

{ some math on vectors ------------------------------------------------------- }

function Lerp(const a: Single; const V1, V2: TVector2Byte): TVector2Byte;
begin
  Result[0] := Clamped(Round(V1[0] + A * (V2[0] - V1[0])), 0, High(Byte));
  Result[1] := Clamped(Round(V1[1] + A * (V2[1] - V1[1])), 0, High(Byte));
end;

function Lerp(const a: Single; const V1, V2: TVector3Byte): TVector3Byte;
begin
  Result[0] := Clamped(Round(V1[0] + A * (V2[0] - V1[0])), 0, High(Byte));
  Result[1] := Clamped(Round(V1[1] + A * (V2[1] - V1[1])), 0, High(Byte));
  Result[2] := Clamped(Round(V1[2] + A * (V2[2] - V1[2])), 0, High(Byte));
end;

function Lerp(const a: Single; const V1, V2: TVector4Byte): TVector4Byte;
begin
  Result[0] := Clamped(Round(V1[0] + A * (V2[0] - V1[0])), 0, High(Byte));
  Result[1] := Clamped(Round(V1[1] + A * (V2[1] - V1[1])), 0, High(Byte));
  Result[2] := Clamped(Round(V1[2] + A * (V2[2] - V1[2])), 0, High(Byte));
  Result[3] := Clamped(Round(V1[3] + A * (V2[3] - V1[3])), 0, High(Byte));
end;

function Lerp(const a: Single; const V1, V2: TVector2Integer): TVector2Single;
begin
 result[0] := V1[0] + a*(V2[0]-V1[0]);
 result[1] := V1[1] + a*(V2[1]-V1[1]);
end;

function Lerp(const a: Single; const V1, V2: TVector2Single): TVector2Single;
begin
 result[0] := V1[0] + a*(V2[0]-V1[0]);
 result[1] := V1[1] + a*(V2[1]-V1[1]);
end;

function Lerp(const a: Single; const V1, V2: TVector3Single): TVector3Single;
begin
 result[0] := V1[0] + a*(V2[0]-V1[0]);
 result[1] := V1[1] + a*(V2[1]-V1[1]);
 result[2] := V1[2] + a*(V2[2]-V1[2]);
end;

function Lerp(const a: Single; const V1, V2: TVector4Single): TVector4Single;
begin
 result[0] := V1[0] + a*(V2[0]-V1[0]);
 result[1] := V1[1] + a*(V2[1]-V1[1]);
 result[2] := V1[2] + a*(V2[2]-V1[2]);
 result[3] := V1[3] + a*(V2[3]-V1[3]);
end;

function Lerp(const a: Double; const V1, V2: TVector2Double): TVector2Double;
begin
 result[0] := V1[0] + a*(V2[0]-V1[0]);
 result[1] := V1[1] + a*(V2[1]-V1[1]);
end;

function Lerp(const a: Double; const V1, V2: TVector3Double): TVector3Double;
begin
 result[0] := V1[0] + a*(V2[0]-V1[0]);
 result[1] := V1[1] + a*(V2[1]-V1[1]);
 result[2] := V1[2] + a*(V2[2]-V1[2]);
end;

function Lerp(const a: Double; const V1, V2: TVector4Double): TVector4Double;
begin
 result[0] := V1[0] + a*(V2[0]-V1[0]);
 result[1] := V1[1] + a*(V2[1]-V1[1]);
 result[2] := V1[2] + a*(V2[2]-V1[2]);
 result[3] := V1[3] + a*(V2[3]-V1[3]);
end;

{$ifdef HAS_MATRIX_UNIT}
function Vector_Init_Lerp(const A: Single; const V1, V2: TVector3_Single): TVector3_Single;
begin
  Result.Data[0] := V1.Data[0] + A * (V2.Data[0] - V1.Data[0]);
  Result.Data[1] := V1.Data[1] + A * (V2.Data[1] - V1.Data[1]);
  Result.Data[2] := V1.Data[2] + A * (V2.Data[2] - V1.Data[2]);
end;

function Vector_Init_Lerp(const A: Single; const V1, V2: TVector4_Single): TVector4_Single;
begin
  Result.Data[0] := V1.Data[0] + A * (V2.Data[0] - V1.Data[0]);
  Result.Data[1] := V1.Data[1] + A * (V2.Data[1] - V1.Data[1]);
  Result.Data[2] := V1.Data[2] + A * (V2.Data[2] - V1.Data[2]);
  Result.Data[3] := V1.Data[3] + A * (V2.Data[3] - V1.Data[3]);
end;

function Vector_Init_Lerp(const A: Double; const V1, V2: TVector3_Double): TVector3_Double;
begin
  Result.Data[0] := V1.Data[0] + A * (V2.Data[0] - V1.Data[0]);
  Result.Data[1] := V1.Data[1] + A * (V2.Data[1] - V1.Data[1]);
  Result.Data[2] := V1.Data[2] + A * (V2.Data[2] - V1.Data[2]);
end;

function Vector_Init_Lerp(const A: Double; const V1, V2: TVector4_Double): TVector4_Double;
begin
  Result.Data[0] := V1.Data[0] + A * (V2.Data[0] - V1.Data[0]);
  Result.Data[1] := V1.Data[1] + A * (V2.Data[1] - V1.Data[1]);
  Result.Data[2] := V1.Data[2] + A * (V2.Data[2] - V1.Data[2]);
  Result.Data[3] := V1.Data[3] + A * (V2.Data[3] - V1.Data[3]);
end;
{$endif HAS_MATRIX_UNIT}

function Mix2Vectors(const v1, v2: TVector3Single; const v2part: Single): TVector3Single;
var v1part: Single;
begin
 v1part := 1.0-v2part;
 result[0] := v1part*v1[0] + v2part*v2[0];
 result[1] := v1part*v1[1] + v2part*v2[1];
 result[2] := v1part*v1[2] + v2part*v2[2];
end;

function Mix2Vectors(const v1, v2: TVector2Single; const v2part: Single): TVector2Single;
var v1part: Single;
begin
 v1part := 1.0-v2part;
 result[0] := v1part*v1[0] + v2part*v2[0];
 result[1] := v1part*v1[1] + v2part*v2[1];
end;

procedure Mix2VectorsTo1st(var v1: TVector3Single; const v2: TVector3Single;
  const v2part: Single);
var v1part: Single;
begin
 v1part := 1.0-v2part;
 v1[0] := v1[0]*v1part + v2[0]*v2part;
 v1[1] := v1[1]*v1part + v2[1]*v2part;
 v1[2] := v1[2]*v1part + v2[2]*v2part;
end;

procedure Mix2VectorsTo1st(var v1: TVector2Single; const v2: TVector2Single;
  const v2part: Single);
var v1part: Single;
begin
 v1part := 1.0-v2part;
 v1[0] := v1[0]*v1part + v2[0]*v2part;
 v1[1] := v1[1]*v1part + v2[1]*v2part;
end;

procedure NormalizeTo1st3Singlev(vv: PVector3Single);
var dlug: Single;
begin
 dlug := Sqrt(
   Sqr(vv^[0]) +
   Sqr(vv^[1]) +
   Sqr(vv^[2]));
 if dlug = 0 then exit;
 vv^[0] := vv^[0] / dlug;
 vv^[1] := vv^[1] / dlug;
 vv^[2] := vv^[2] / dlug;
end;

procedure NormalizeTo1st3Bytev(vv: PVector3Byte);
var dlug: integer;
begin
 dlug := Round( Sqrt(
   Sqr(Integer(vv^[0])) +
   Sqr(Integer(vv^[1])) +
   Sqr(Integer(vv^[2]))) );
 if dlug = 0 then exit;
 vv^[0] := vv^[0] div dlug;
 vv^[1] := vv^[1] div dlug;
 vv^[2] := vv^[2] div dlug;
end;

function ZeroVector(const v: TVector4Cardinal): boolean;
begin
 result := IsMemCharFilled(v, SizeOf(v), #0);
end;

{$ifndef DELPHI}

function VectorLen(const v: TVector3Byte): Single;
begin result := Sqrt(VectorLenSqr(v)) end;

function VectorLenSqr(const v: TVector3Byte): Integer;
begin
 result := Sqr(Integer(v[0])) + Sqr(Integer(v[1])) + Sqr(Integer(v[2]));
end;

{$define TYPE_SCALAR := Single}
{$define TYPE_VECTOR2 := TVector2Single}
{$define TYPE_VECTOR3 := TVector3Single}
{$define TYPE_VECTOR4 := TVector4Single}
{$define TYPE_TRIANGLE2 := TTriangle2Single}
{$define TYPE_TRIANGLE3 := TTriangle3Single}
{$define TYPE_MATRIX2 := TMatrix2Single}
{$define TYPE_MATRIX3 := TMatrix3Single}
{$define TYPE_MATRIX4 := TMatrix4Single}
{$define SCALAR_EQUALITY_EPSILON := SingleEqualityEpsilon}
{$define UNIT_VECTOR3 := UnitVector3Single}
{$define IDENTITY_MATRIX := IdentityMatrix4Single}
{$define TYPE_MATRIX2_OBJECT := TMatrix2_Single}
{$define TYPE_MATRIX3_OBJECT := TMatrix3_Single}
{$define TYPE_MATRIX4_OBJECT := TMatrix4_Single}
{$define TYPE_VECTOR2_OBJECT := TVector2_Single}
{$define TYPE_VECTOR3_OBJECT := TVector3_Single}
{$define TYPE_VECTOR4_OBJECT := TVector4_Single}
{$I vectormath_dualimplementation_beforeinlines.inc}

{$define TYPE_SCALAR := Double}
{$define TYPE_VECTOR2 := TVector2Double}
{$define TYPE_VECTOR3 := TVector3Double}
{$define TYPE_VECTOR4 := TVector4Double}
{$define TYPE_TRIANGLE2 := TTriangle2Double}
{$define TYPE_TRIANGLE3 := TTriangle3Double}
{$define TYPE_MATRIX2 := TMatrix2Double}
{$define TYPE_MATRIX3 := TMatrix3Double}
{$define TYPE_MATRIX4 := TMatrix4Double}
{$define SCALAR_EQUALITY_EPSILON := DoubleEqualityEpsilon}
{$define UNIT_VECTOR3 := UnitVector3Double}
{$define IDENTITY_MATRIX := IdentityMatrix4Double}
{$define TYPE_MATRIX2_OBJECT := TMatrix2_Double}
{$define TYPE_MATRIX3_OBJECT := TMatrix3_Double}
{$define TYPE_MATRIX4_OBJECT := TMatrix4_Double}
{$define TYPE_VECTOR2_OBJECT := TVector2_Double}
{$define TYPE_VECTOR3_OBJECT := TVector3_Double}
{$define TYPE_VECTOR4_OBJECT := TVector4_Double}
{$I vectormath_dualimplementation_beforeinlines.inc}

{$I vectormathinlines.inc}

{$define TYPE_SCALAR := Single}
{$define TYPE_VECTOR2 := TVector2Single}
{$define TYPE_VECTOR3 := TVector3Single}
{$define TYPE_VECTOR4 := TVector4Single}
{$define PTR_TYPE_VECTOR2 := PVector2Single}
{$define PTR_TYPE_VECTOR3 := PVector3Single}
{$define PTR_TYPE_VECTOR4 := PVector4Single}
{$define TYPE_TRIANGLE2 := TTriangle2Single}
{$define TYPE_TRIANGLE3 := TTriangle3Single}
{$define TYPE_MATRIX2 := TMatrix2Single}
{$define TYPE_MATRIX3 := TMatrix3Single}
{$define TYPE_MATRIX4 := TMatrix4Single}
{$define SCALAR_EQUALITY_EPSILON := SingleEqualityEpsilon}
{$define UNIT_VECTOR3 := UnitVector3Single}
{$define IDENTITY_MATRIX := IdentityMatrix4Single}
{$define TYPE_MATRIX2_OBJECT := TMatrix2_Single}
{$define TYPE_MATRIX3_OBJECT := TMatrix3_Single}
{$define TYPE_MATRIX4_OBJECT := TMatrix4_Single}
{$define TYPE_VECTOR2_OBJECT := TVector2_Single}
{$define TYPE_VECTOR3_OBJECT := TVector3_Single}
{$define TYPE_VECTOR4_OBJECT := TVector4_Single}
{$I vectormath_dualimplementation.inc}

{$define TYPE_SCALAR := Double}
{$define TYPE_VECTOR2 := TVector2Double}
{$define TYPE_VECTOR3 := TVector3Double}
{$define TYPE_VECTOR4 := TVector4Double}
{$define PTR_TYPE_VECTOR2 := PVector2Double}
{$define PTR_TYPE_VECTOR3 := PVector3Double}
{$define PTR_TYPE_VECTOR4 := PVector4Double}
{$define TYPE_TRIANGLE2 := TTriangle2Double}
{$define TYPE_TRIANGLE3 := TTriangle3Double}
{$define TYPE_MATRIX2 := TMatrix2Double}
{$define TYPE_MATRIX3 := TMatrix3Double}
{$define TYPE_MATRIX4 := TMatrix4Double}
{$define SCALAR_EQUALITY_EPSILON := DoubleEqualityEpsilon}
{$define UNIT_VECTOR3 := UnitVector3Double}
{$define IDENTITY_MATRIX := IdentityMatrix4Double}
{$define TYPE_MATRIX2_OBJECT := TMatrix2_Double}
{$define TYPE_MATRIX3_OBJECT := TMatrix3_Double}
{$define TYPE_MATRIX4_OBJECT := TMatrix4_Double}
{$define TYPE_VECTOR2_OBJECT := TVector2_Double}
{$define TYPE_VECTOR3_OBJECT := TVector3_Double}
{$define TYPE_VECTOR4_OBJECT := TVector4_Double}
{$I vectormath_dualimplementation.inc}

function IndexedTriangleNormal(const Indexes: TVector3Cardinal;
  VerticesArray: PVector3Single; VerticesStride: integer): TVector3Single;
var Tri: TTriangle3Single;
    i: integer;
begin
 if VerticesStride = 0 then VerticesStride := SizeOf(TVector3Single);
 for i := 0 to 2 do
  Tri[i] := PVector3Single(PointerAdd(VerticesArray, VerticesStride*Integer(Indexes[i])))^;
 result := TriangleNormal(Tri);
end;

function IndexedPolygonNormal(
  Indices: PArray_Longint; IndicesCount: integer;
  Verts: PArray_Vector3Single; const VertsCount: Integer;
  const ResultForIncorrectPoly: TVector3Single): TVector3Single;
begin
  Result := IndexedPolygonNormal(
    Indices, IndicesCount,
    PVector3Single(Verts), VertsCount, SizeOf(TVector3Single),
    ResultForIncorrectPoly);
end;

function IndexedPolygonNormal(
  Indices: PArray_Longint; IndicesCount: integer;
  Verts: PVector3Single; const VertsCount: Integer; const VertsStride: PtrUInt;
  const ResultForIncorrectPoly: TVector3Single): TVector3Single;
var Tri: TTriangle3Single;
    i: integer;
begin
  { We calculate normal vector as an average of normal vectors of
    polygon's triangles. Not taking into account invalid Indices
    (pointing beyond the VertsCount range) and degenerated triangles.

    This isn't the fastest method possible, but it's safest.
    It works Ok even if the polygon isn't precisely planar, or has
    some degenerate triangles. }

  Result := ZeroVector3Single;

  I := 0;

  { Verts_Indices_I = Verts[Indices[I]], but takes into account
    that Verts is an array with VertsStride. }
  {$define Verts_Indices_I :=
    PVector3Single(PtrUInt(Verts) + PtrUInt(Indices^[I]) * VertsStride)^}

  while (I < IndicesCount) and (Indices^[I] >= VertsCount) do Inc(I);
  { This secures us against polygons with no valid Indices[].
    (including case when IndicesCount = 0). }
  if I >= IndicesCount then
    Exit(ResultForIncorrectPoly);
  Tri[0] := Verts_Indices_I;

  repeat Inc(I) until (I >= IndicesCount) or (Indices^[I] < VertsCount);
  if I >= IndicesCount then
    Exit(ResultForIncorrectPoly);
  Tri[1] := Verts_Indices_I;

  repeat Inc(I) until (I >= IndicesCount) or (Indices^[I] < VertsCount);
  if I >= IndicesCount then
    Exit(ResultForIncorrectPoly);
  Tri[2] := Verts_Indices_I;

  if IsValidTriangle(Tri) then
    VectorAddTo1st(result, TriangleNormal(Tri) );

  repeat
    { find next valid point, which makes another triangle of polygon }

    repeat Inc(I) until (I >= IndicesCount) or (Indices^[I] < VertsCount);
    if I >= IndicesCount then
      Break;
    Tri[1] := Tri[2];
    Tri[2] := Verts_Indices_I;

    if IsValidTriangle(Tri) then
      VectorAddTo1st(result, TriangleNormal(Tri) );
  until false;

  { result to teraz suma ilus wektorow. Kazdy skladowy wektor
      ma w niej rowny udzial bo je normalizowalem.
    Jezeli Normal = (0, 0, 0) to znaczy ze wszystkie trojkaty polygonu byly
      zdegenerowane, wiec nie jestesmy w stanie wyliczyc zadnego sensownego
      wektora normalnego. }
  if ZeroVector(Result) then
    Result := ResultForIncorrectPoly else
    NormalizeTo1st(Result);
end;

function IndexedConvexPolygonArea(
  Indices: PArray_Longint; IndicesCount: integer;
  Verts: PArray_Vector3Single; const VertsCount: Integer): Single;
begin
  Result := IndexedConvexPolygonArea(
    Indices, IndicesCount,
    PVector3Single(Verts), VertsCount, SizeOf(TVector3Single));
end;

function IndexedConvexPolygonArea(
  Indices: PArray_Longint; IndicesCount: integer;
  Verts: PVector3Single; const VertsCount: Integer; const VertsStride: PtrUInt): Single;
var
  Tri: TTriangle3Single;
  i: integer;
begin
  { We calculate area as a sum of areas of
    polygon's triangles. Not taking into account invalid Indices
    (pointing beyond the VertsCount range). }

  Result := 0;

  I := 0;

  { Verts_Indices_I = Verts[Indices[I]], but takes into account
    that Verts is an array with VertsStride. }
  {$define Verts_Indices_I :=
    PVector3Single(PtrUInt(Verts) + PtrUInt(Indices^[I]) * VertsStride)^}

  while (I < IndicesCount) and (Indices^[I] >= VertsCount) do Inc(I);
  { This secures us against polygons with no valid Indices[].
    (including case when IndicesCount = 0). }
  if I >= IndicesCount then
    Exit;
  Tri[0] := Verts_Indices_I;

  repeat Inc(I) until (I >= IndicesCount) or (Indices^[I] < VertsCount);
  if I >= IndicesCount then
    Exit;
  Tri[1] := Verts_Indices_I;

  repeat Inc(I) until (I >= IndicesCount) or (Indices^[I] < VertsCount);
  if I >= IndicesCount then
    Exit;
  Tri[2] := Verts_Indices_I;

  Result += TriangleArea(Tri);

  repeat
    { find next valid point, which makes another triangle of polygon }

    repeat Inc(I) until (I >= IndicesCount) or (Indices^[I] < VertsCount);
    if I >= IndicesCount then
      Break;
    Tri[1] := Tri[2];
    Tri[2] := Verts_Indices_I;

    Result += TriangleArea(Tri);
  until false;
end;

function IsPolygon2dCCW(Verts: PArray_Vector2Single; const VertsCount: Integer): Single;
{ licz pole polygonu CCW.

  Implementacja na podstawie "Graphic Gems II", gem I.1
  W Graphic Gems pisza ze to jest formula na polygon CCW (na plaszczyznie
  kartezjanskiej, z +X w prawo i +Y w gore) i nie podaja tego Abs() na koncu.
  Widac jednak ze jesli podamy zamiast wielokata CCW ten sam wielokat ale
  z wierzcholkami w odwrotnej kolejnosci to procedura policzy dokladnie to samo
  ale skosy dodatnie zostana teraz policzone jako ujemne a ujemne jako dodatnie.
  Czyli dostaniemy ujemne pole.

  Mozna wiec wykorzystac powyzszy fakt aby testowac czy polygon jest CCW :
  brac liczona tu wartosc i jesli >0 to CCW, <0 to CW
  (jesli =0 to nie wiadomo no i polygony o polu = 0 rzeczywiscie nie maja
  jednoznacznej orientacji). Moznaby pomyslec ze mozna znalezc prostsze
  testy na to czy polygon jest CCW - mozna przeciez testowac tylko wyciety
  z polygonu trojkat. Ale uwaga - wtedy trzebaby uwazac i koniecznie
  wybrac z polygonu niezdegenerowany trojkat (o niezerowym polu),
  no chyba ze caly polygon mialby zerowe pole. Tak jak jest nie trzeba
  sie tym przejmowac i jest prosto.

  W ten sposob ponizsza procedura jednoczesnie liczy pole polygonu
  (Polygon2dArea jest zaimplementowane jako proste Abs() z wyniku tej
  funkcji. }
var i: Integer;
begin
 result := 0.0;
 if VertsCount = 0 then Exit;

 { licze i = 0..VertsCount-2, potem osobno przypadek gdy i = VertsCount-1.
   Moglbym ujac je razem, dajac zamiast "Verts[i+1, 1]"
   "Verts[(i+1)mod VertsCount, 1]" ale szkoda byloby dawac tu "mod" na potrzebe
   tylko jednego przypadku. Tak jest optymalniej czasowo. }
 for i := 0 to VertsCount-2 do
  result += Verts^[i, 0] * Verts^[i+1, 1] -
            Verts^[i, 1] * Verts^[i+1, 0];
 result += Verts^[VertsCount-1, 0] * Verts^[0, 1] -
           Verts^[VertsCount-1, 1] * Verts^[0, 0];

 result /= 2;
end;

function IsPolygon2dCCW(const Verts: array of TVector2Single): Single;
begin
 result := IsPolygon2dCCW(@Verts, High(Verts)+1);
end;

function Polygon2dArea(Verts: PArray_Vector2Single; const VertsCount: Integer): Single;
{ opieramy sie tutaj na WEWNETRZNEJ IMPLEMENTACJI funkcji IsPolygonCCW:
  mianowicie wiemy ze, przynajmniej teraz, funkcja ta zwraca pole
  polygonu CCW lub -pole polygonu CW. }
begin
 result := Abs(IsPolygon2dCCW(Verts, VertsCount));
end;

function Polygon2dArea(const Verts: array of TVector2Single): Single;
begin
 result := Polygon2dArea(@Verts, High(Verts)+1);
end;

function SampleTrianglePoint(const Tri: TTriangle3Single): TVector3Single;
var r1Sqrt, r2: Single;
begin
 { na podstawie GlobalIllumComp, punkt (17) }
 r1Sqrt := Sqrt(Random);
 r2 := Random;
 result := VectorScale(Tri[0], 1-r1Sqrt);
 VectorAddTo1st(result, VectorScale(Tri[1], (1-r2)*r1Sqrt));
 VectorAddTo1st(result, VectorScale(Tri[2], r2*r1Sqrt));
end;

function VectorToNiceStr(const v: array of Byte): string; overload;
var i: Integer;
begin
 result := '(';
 for i := 0 to High(v)-1 do result := result +IntToStr(v[i]) +', ';
 if High(v) >= 0 then result := result +IntToStr(v[High(v)]) +')';
end;

{ math with matrices ---------------------------------------------------------- }

function VectorMultTransposedSameVector(const v: TVector3Single): TMatrix4Single;
begin
  (* Naive version:

  for i := 0 to 2 do { i = column, j = row }
    for j := 0 to 2 do
      result[i, j] := v[i]*v[j];

  Expanded and optimized version below. *)

  result[0, 0] := sqr(v[0]);
  result[1, 1] := sqr(v[1]);
  result[2, 2] := sqr(v[2]);

  result[0, 1] := v[0]*v[1]; result[1, 0] := result[0, 1];
  result[0, 2] := v[0]*v[2]; result[2, 0] := result[0, 2];
  result[1, 2] := v[1]*v[2]; result[2, 1] := result[1, 2];

  { Fill the last row and column like an identity matrix }
  Result[3, 0] := 0;
  Result[3, 1] := 0;
  Result[3, 2] := 0;

  Result[0, 3] := 0;
  Result[1, 3] := 0;
  Result[2, 3] := 0;

  Result[3, 3] := 1;
end;

function ScalingMatrix(const ScaleFactor: TVector3Single): TMatrix4Single;
begin
 result := IdentityMatrix4Single;
 result[0, 0] := ScaleFactor[0];
 result[1, 1] := ScaleFactor[1];
 result[2, 2] := ScaleFactor[2];
end;

procedure ScalingMatrices(const ScaleFactor: TVector3Single;
  InvertedMatrixIdentityIfNotExists: boolean;
  out Matrix, InvertedMatrix: TMatrix4Single);
begin
  Matrix := IdentityMatrix4Single;
  Matrix[0, 0] := ScaleFactor[0];
  Matrix[1, 1] := ScaleFactor[1];
  Matrix[2, 2] := ScaleFactor[2];

  InvertedMatrix := IdentityMatrix4Single;
  if not
    (InvertedMatrixIdentityIfNotExists and
      ( Zero(ScaleFactor[0]) or
        Zero(ScaleFactor[1]) or
        Zero(ScaleFactor[2]) )) then
  begin
    InvertedMatrix[0, 0] := 1 / ScaleFactor[0];
    InvertedMatrix[1, 1] := 1 / ScaleFactor[1];
    InvertedMatrix[2, 2] := 1 / ScaleFactor[2];
  end;
end;

function RotationMatrixRad(const AngleRad: Single;
  const Axis: TVector3Single): TMatrix4Single;
var
  NormAxis: TVector3Single;
  AngleSin, AngleCos: Float;
  S, C: Single;
begin
  NormAxis := Normalized(Axis);

  SinCos(AngleRad, AngleSin, AngleCos);
  { convert Float to Single once }
  S := AngleSin;
  C := AngleCos;

  Result := VectorMultTransposedSameVector(NormAxis);

  { We do not touch the last column and row of Result in the following code,
    treating Result like a 3x3 matrix. The last column and row are already Ok. }

  { Expanded Result := Result + (IdentityMatrix3Single - Result) * AngleCos; }
  Result[0, 0] += (1 - Result[0, 0]) * C;
  Result[1, 0] +=    - Result[1, 0]  * C;
  Result[2, 0] +=    - Result[2, 0]  * C;

  Result[0, 1] +=    - Result[0, 1]  * C;
  Result[1, 1] += (1 - Result[1, 1]) * C;
  Result[2, 1] +=    - Result[2, 1]  * C;

  Result[0, 2] +=    - Result[0, 2]  * C;
  Result[1, 2] +=    - Result[1, 2]  * C;
  Result[2, 2] += (1 - Result[2, 2]) * C;

  NormAxis[0] *= S;
  NormAxis[1] *= S;
  NormAxis[2] *= S;

  { Add M3 (from OpenGL matrix equations) }
  Result[1, 0] += -NormAxis[2];
  Result[2, 0] +=  NormAxis[1];

  Result[0, 1] +=  NormAxis[2];
  Result[2, 1] += -NormAxis[0];

  Result[0, 2] += -NormAxis[1];
  Result[1, 2] +=  NormAxis[0];
end;

procedure RotationMatricesRad(const AngleRad: Single;
  const Axis: TVector3Single;
  out Matrix, InvertedMatrix: TMatrix4Single);
var
  NormAxis: TVector3Single;
  V: Single;
  AngleSin, AngleCos: Float;
  S, C: Single;
begin
  NormAxis := Normalized(Axis);

  SinCos(AngleRad, AngleSin, AngleCos);
  { convert Float to Single once }
  S := AngleSin;
  C := AngleCos;

  Matrix := VectorMultTransposedSameVector(NormAxis);

  { We do not touch the last column and row of Matrix in the following code,
    treating Matrix like a 3x3 matrix. The last column and row are already Ok. }

  { Expanded Matrix := Matrix + (IdentityMatrix3Single - Matrix) * AngleCos; }
  Matrix[0, 0] += (1 - Matrix[0, 0]) * C;
  Matrix[1, 0] +=    - Matrix[1, 0]  * C;
  Matrix[2, 0] +=    - Matrix[2, 0]  * C;

  Matrix[0, 1] +=    - Matrix[0, 1]  * C;
  Matrix[1, 1] += (1 - Matrix[1, 1]) * C;
  Matrix[2, 1] +=    - Matrix[2, 1]  * C;

  Matrix[0, 2] +=    - Matrix[0, 2]  * C;
  Matrix[1, 2] +=    - Matrix[1, 2]  * C;
  Matrix[2, 2] += (1 - Matrix[2, 2]) * C;

  { Up to this point, calculated Matrix is also good for InvertedMatrix }
  InvertedMatrix := Matrix;

  NormAxis[0] *= S;
  NormAxis[1] *= S;
  NormAxis[2] *= S;

  { Now add M3 to Matrix, and subtract M3 from InvertedMatrix.
    That's because for the inverted rotation, AngleSin is negated,
    so the M3 should be subtracted. }
  V := -NormAxis[2]; Matrix[1, 0] += V; InvertedMatrix[1, 0] -= V;
  V :=  NormAxis[1]; Matrix[2, 0] += V; InvertedMatrix[2, 0] -= V;

  V :=  NormAxis[2]; Matrix[0, 1] += V; InvertedMatrix[0, 1] -= V;
  V := -NormAxis[0]; Matrix[2, 1] += V; InvertedMatrix[2, 1] -= V;

  V := -NormAxis[1]; Matrix[0, 2] += V; InvertedMatrix[0, 2] -= V;
  V :=  NormAxis[0]; Matrix[1, 2] += V; InvertedMatrix[1, 2] -= V;
end;

function RotationMatrixDeg(const AngleDeg: Single; const Axis: TVector3Single): TMatrix4Single;
begin
  result := RotationMatrixRad(DegToRad(AngleDeg), Axis);
end;

function RotationMatrixDeg(const AngleDeg: Single;
  const AxisX, AxisY, AxisZ: Single): TMatrix4Single;
begin
  result := RotationMatrixRad(DegToRad(AngleDeg), Vector3Single(AxisX, AxisY, AxisZ));
end;

function RotationMatrixRad(const AngleRad: Single;
  const AxisX, AxisY, AxisZ: Single): TMatrix4Single;
begin
  result := RotationMatrixRad(AngleRad, Vector3Single(AxisX, AxisY, AxisZ));
end;

function OrthoProjMatrix(const Left, Right, Bottom, Top, ZNear, ZFar: Single): TMatrix4Single;
var Width, Height, Depth: Single;
begin
 Width := Right - Left;
 Height := Top - Bottom;
 Depth := ZFar - ZNear;

 result := ZeroMatrix4Single;
 result[0, 0] := 2 / Width;
 result[1, 1] := 2 / Height;
 result[2, 2] := - 2 / Depth; { tutaj - bo nasze Z-y sa ujemne w glab ekranu }
 result[3, 0] := - (Right + Left) / Width;
 result[3, 1] := - (Top + Bottom) / Height;
 result[3, 2] := - (ZFar + ZNear) / Depth;
 result[3, 3] := 1;
end;

function Ortho2dProjMatrix(const Left, Right, Bottom, Top: Single): TMatrix4Single;
var Width, Height: Single;
begin
 {wersja prosta : result := OrthoProjMatrix(Left, Right, Bottom, Top, -1, 1);}
 {wersja zoptymalizowana :}
 Width := Right - Left;
 Height := Top - Bottom;
 {Depth := ZFar - ZNear = (1 - (-1)) = 2}

 Result := ZeroMatrix4Single;
 Result[0, 0] := 2 / Width;
 Result[1, 1] := 2 / Height;
 Result[2, 2] := {-2 / Depth = -2 / 2} -1;
 Result[3, 0] := - (Right + Left) / Width;
 Result[3, 1] := - (Top + Bottom) / Height;
 Result[3, 2] := {- (ZFar + ZNear) / Depth = 0 / 2} 0;
 Result[3, 3] := 1;
end;

function FrustumProjMatrix(const Left, Right, Bottom, Top, ZNear, ZFar: Single): TMatrix4Single;

{ This is of course based on "OpenGL Programming Guide",
  Appendix G "... and Transformation Matrices".
  ZFarInfinity version based on various sources, pretty much every
  article about shadow volumes mentions z-fail and this trick. }

var
  Width, Height, Depth, ZNear2: Single;
begin
  Width := Right - Left;
  Height := Top - Bottom;
  ZNear2 := ZNear * 2;

  Result := ZeroMatrix4Single;
  Result[0, 0] := ZNear2         / Width;
  Result[2, 0] := (Right + Left) / Width;
  Result[1, 1] := ZNear2         / Height;
  Result[2, 1] := (Top + Bottom) / Height;
  if ZFar <> ZFarInfinity then
  begin
    Depth := ZFar - ZNear;
    Result[2, 2] := - (ZFar + ZNear) / Depth;
    Result[3, 2] := - ZNear2 * ZFar  / Depth;
  end else
  begin
    Result[2, 2] := -1;
    Result[3, 2] := -ZNear2;
  end;
  Result[2, 3] := -1;
end;

function PerspectiveProjMatrixDeg(const FovyDeg, Aspect, ZNear, ZFar: Single): TMatrix4Single;
begin
  Result := PerspectiveProjMatrixRad(DegToRad(FovyDeg), Aspect, ZNear, ZFar);
end;

function PerspectiveProjMatrixRad(const FovyRad, Aspect, ZNear, ZFar: Single): TMatrix4Single;
{ Based on various sources, e.g. sample implementation of
  glu by SGI in Mesa3d sources. }
var
  Depth, ZNear2, Cotangent: Single;
begin
  ZNear2 := ZNear * 2;
  Cotangent := KamCoTan(FovyRad / 2);

  Result := ZeroMatrix4Single;
  Result[0, 0] := Cotangent / Aspect;
  Result[1, 1] := Cotangent;
  if ZFar <> ZFarInfinity then
  begin
    Depth := ZFar - ZNear;
    Result[2, 2] := - (ZFar + ZNear) / Depth;
    Result[3, 2] := - ZNear2 * ZFar  / Depth;
  end else
  begin
    Result[2, 2] := -1;
    Result[3, 2] := -ZNear2;
  end;

  Result[2, 3] := -1;
end;

{ kod dla MatrixDet* przerobiony z vect.c z mgflib }

function MatrixDet4x4(const mat: TMatrix4Single): Single;
var a1, a2, a3, a4, b1, b2, b3, b4, c1, c2, c3, c4, d1, d2, d3, d4: Single;
begin
 a1 := mat[0][0]; b1 := mat[0][1];
 c1 := mat[0][2]; d1 := mat[0][3];

 a2 := mat[1][0]; b2 := mat[1][1];
 c2 := mat[1][2]; d2 := mat[1][3];

 a3 := mat[2][0]; b3 := mat[2][1];
 c3 := mat[2][2]; d3 := mat[2][3];

 a4 := mat[3][0]; b4 := mat[3][1];
 c4 := mat[3][2]; d4 := mat[3][3];

 result := a1 * MatrixDet3x3 (b2, b3, b4, c2, c3, c4, d2, d3, d4) -
           b1 * MatrixDet3x3 (a2, a3, a4, c2, c3, c4, d2, d3, d4) +
           c1 * MatrixDet3x3 (a2, a3, a4, b2, b3, b4, d2, d3, d4) -
           d1 * MatrixDet3x3 (a2, a3, a4, b2, b3, b4, c2, c3, c4);
end;


function MatrixDet3x3(const a1, a2, a3, b1, b2, b3, c1, c2, c3: Single): Single;
begin
 result := a1 * MatrixDet2x2 (b2, b3, c2, c3)
         - b1 * MatrixDet2x2 (a2, a3, c2, c3)
         + c1 * MatrixDet2x2 (a2, a3, b2, b3);
end;

function MatrixDet2x2(const a, b, c, d: Single): Single;
begin
 result := a * d - b * c;
end;

{$ifdef HAS_MATRIX_UNIT}
function TryMatrixInverse(const M: TMatrix2Single; out MInverse: TMatrix2Single): boolean;
var
  D: Double;
  MD, MDInverse: TMatrix2Double;
begin
  MD := Matrix2Double(M);
  D := MatrixDeterminant(MD);
  Result := not Zero(D);
  if Result then
  begin
    MDInverse := MatrixInverse(MD, D);
    MInverse := Matrix2Single(MDInverse);
  end;
end;

function TryMatrixInverse(const M: TMatrix2Double; out MInverse: TMatrix2Double): boolean;
var
  D: Double;
begin
  D := MatrixDeterminant(M);
  Result := not Zero(D);
  if Result then
    MInverse := MatrixInverse(M, D);
end;

function TryMatrixInverse(const M: TMatrix3Single; out MInverse: TMatrix3Single): boolean;
var
  D: Double;
  MD, MDInverse: TMatrix3Double;
begin
  MD := Matrix3Double(M);
  D := MatrixDeterminant(MD);
  Result := not Zero(D);
  if Result then
  begin
    MDInverse := MatrixInverse(MD, D);
    MInverse := Matrix3Single(MDInverse);
  end;
end;

function TryMatrixInverse(const M: TMatrix3Double; out MInverse: TMatrix3Double): boolean;
var
  D: Double;
begin
  D := MatrixDeterminant(M);
  Result := not Zero(D);
  if Result then
    MInverse := MatrixInverse(M, D);
end;

function TryMatrixInverse(const M: TMatrix4Single; out MInverse: TMatrix4Single): boolean;
var
  D: Double;
  MD, MDInverse: TMatrix4Double;
begin
  MD := Matrix4Double(M);
  D := MatrixDeterminant(MD);
  Result := not Zero(D);
  if Result then
  begin
    MDInverse := MatrixInverse(MD, D);
    MInverse := Matrix4Single(MDInverse);
  end;
end;

function TryMatrixInverse(const M: TMatrix4Double; out MInverse: TMatrix4Double): boolean;
var
  D: Double;
begin
  D := MatrixDeterminant(M);
  Result := not Zero(D);
  if Result then
    MInverse := MatrixInverse(M, D);
end;
{$endif HAS_MATRIX_UNIT}
{$endif not DELPHI}

{ Grayscale ------------------------------------------------------------------ }

function GrayscaleValue(const v: TVector3Single): Single;
begin
 result := GrayscaleValuesFloat[0]*v[0]+
           GrayscaleValuesFloat[1]*v[1]+
           GrayscaleValuesFloat[2]*v[2];
end;

function GrayscaleValue(const v: TVector3Double): Double;
begin
 result := GrayscaleValuesFloat[0]*v[0]+
           GrayscaleValuesFloat[1]*v[1]+
           GrayscaleValuesFloat[2]*v[2];
end;

function GrayscaleValue(const v: TVector3Byte): Byte;
begin
 result := (GrayscaleValuesByte[0]*v[0]+
            GrayscaleValuesByte[1]*v[1]+
            GrayscaleValuesByte[2]*v[2]) div 256;
end;

procedure Grayscale3SinglevTo1st(v: PVector3Single);
begin
 v^[0] := GrayscaleValue(v^);
 v^[1] := v^[0];
 v^[2] := v^[0];
end;

procedure Grayscale3BytevTo1st(v: PVector3Byte);
begin
 v^[0] := GrayscaleValue(v^);
 v^[1] := v^[0];
 v^[2] := v^[0];
end;

procedure GrayscaleTo1st(var v: TVector3Byte);
begin
 v[0] := GrayscaleValue(v);
 v[1] := v[0];
 v[2] := v[0];
end;

function Grayscale(const v: TVector3Single): TVector3Single;
begin
 result := v;
 Grayscale3SinglevTo1st(@result);
end;

function Grayscale(const v: TVector4Single): TVector4Single;
begin
 result := v;
 Grayscale3SinglevTo1st(@result);
end;

function Grayscale(const v: TVector3Byte): TVector3Byte;
begin
 result := v;
 Grayscale3BytevTo1st(@result);
end;

{ color changing ------------------------------------------------------------ }

function ColorNegativeSingle(const Color: TVector3Single): TVector3Single;
begin
  Result[0] := 1 - Color[0];
  Result[1] := 1 - Color[1];
  Result[2] := 1 - Color[2];
end;

function ColorNegativeByte(const Color: TVector3Byte): TVector3Byte;
begin
  Result[0] := 255 - Color[0];
  Result[1] := 255 - Color[1];
  Result[2] := 255 - Color[2];
end;

function ColorGrayscaleSingle(const Color: TVector3Single): TVector3Single;
begin Result := Grayscale(Color) end;

function ColorGrayscaleByte(const Color: TVector3Byte): TVector3Byte;
begin Result := Grayscale(Color) end;

function ColorGrayscaleNegativeSingle(const Color: TVector3Single): TVector3Single;
begin
 Result[0] := 1-GrayscaleValue(Color);
 Result[1] := Result[0];
 Result[2] := Result[0];
end;

function ColorGrayscaleNegativeByte(const Color: TVector3Byte): TVector3Byte;
begin
 Result[0] := 255-GrayscaleValue(Color);
 Result[1] := Result[0];
 Result[2] := Result[0];
end;

{$ifdef FPC}

{$define COL_MOD_CONVERT:=
var i: integer;
begin
 for i := 0 to 2 do
  if i = COL_MOD_CONVERT_NUM then
   Result[i] := GrayscaleValue(Color) else
   Result[i] := 0;
end;}

{$define COL_MOD_CONVERT_NUM := 0}
function ColorRedConvertSingle(const Color: TVector3Single): TVector3Single; COL_MOD_CONVERT
function ColorRedConvertByte(const Color: TVector3Byte): TVector3Byte; COL_MOD_CONVERT

{$define COL_MOD_CONVERT_NUM := 1}
function ColorGreenConvertSingle(const Color: TVector3Single): TVector3Single; COL_MOD_CONVERT
function ColorGreenConvertByte(const Color: TVector3Byte): TVector3Byte; COL_MOD_CONVERT

{$define COL_MOD_CONVERT_NUM := 2}
function ColorBlueConvertSingle(const Color: TVector3Single): TVector3Single; COL_MOD_CONVERT
function ColorBlueConvertByte(const Color: TVector3Byte): TVector3Byte; COL_MOD_CONVERT

{$define COL_MOD_STRIP:=
var i: integer;
begin
 for i := 0 to 2 do
  if i = COL_MOD_STRIP_NUM then
   Result[i] := Color[i] else
   Result[i] := 0;
end;}

{$define COL_MOD_STRIP_NUM := 0}
function ColorRedStripSingle(const Color: TVector3Single): TVector3Single; COL_MOD_STRIP
function ColorRedStripByte(const Color: TVector3Byte): TVector3Byte; COL_MOD_STRIP

{$define COL_MOD_STRIP_NUM := 1}
function ColorGreenStripSingle(const Color: TVector3Single): TVector3Single; COL_MOD_STRIP
function ColorGreenStripByte(const Color: TVector3Byte): TVector3Byte; COL_MOD_STRIP

{$define COL_MOD_STRIP_NUM := 2}
function ColorBlueStripSingle(const Color: TVector3Single): TVector3Single; COL_MOD_STRIP
function ColorBlueStripByte(const Color: TVector3Byte): TVector3Byte; COL_MOD_STRIP

{$endif FPC}

end.
