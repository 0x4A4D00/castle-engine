{
  Copyright 2009 Michalis Kamburelis.
  Parts based on white dune (GPL >= 2):
  Stephen F. White, J. "MUFTI" Scheurich, others.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software.

  Although most of the "Kambi VRML game engine" is available on terms
  of LGPL (see COPYING.txt in this distribution for detailed info), this unit
  is an exception (as it uses white dune strict GPL >= 2 code).
  You can redistribute and/or modify *this unit, NURBS.pas*
  only under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  If the engine is compiled with KAMBI_VRMLENGINE_LGPL symbol
  (see ../base/kambiconf.inc), this unit will not be linked in.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Common utilities for NURBS curves and surfaces. }
unit NURBS;

interface

uses SysUtils, KambiUtils, VectorMath, Matrix;

{ Calculate the actual tessellation, that is the number of tessellation
  points. This follows X3D spec for "an implementation subdividing
  the surface into an equal number of subdivision steps".
  Give value of tessellation field, and count of controlPoints.

  Returned value is for sure > 0 (never exactly 0). }
function ActualTessellation(const Tessellation: Integer;
  const Dimension: Cardinal): Cardinal;

{ Return point on NURBS curve.

  Requires:
  @unorderedList(
    @item PointsCount > 0 (not exactly 0).
    @item Order >= 2 (X3D and VRML 97 spec require this too).
    @item Knot must have exactly PointsCount + Order items.
  )

  Weight will be used only if it has the same length as PointsCount.
  Otherwise, weight = 1.0 (that is, defining non-rational curve) will be used
  (this follows X3D spec).

  Tangent, if non-nil, will be set to the direction at given point of the
  curve, pointing from the smaller to larger knot values.
  It will be normalized. This can be directly useful to generate
  orientations by X3D NurbsOrientationInterpolator node.

  @groupBegin }
function NurbsCurvePoint(const Points: PVector3Single;
  const PointsCount: Cardinal; const U: Single;
  const Order: Cardinal;
  Knot, Weight: TDynDoubleArray;
  Tangent: PVector3_Single): TVector3_Single;
function NurbsCurvePoint(const Points: TDynVector3SingleArray;
  const U: Single;
  const Order: Cardinal;
  Knot, Weight: TDynDoubleArray;
  Tangent: PVector3_Single): TVector3_Single;
{ @groupEnd }

{ Return point on NURBS surface.

  Requires:
  @unorderedList(
    @item UDimension, VDimension > 0 (not exactly 0).
    @item Points.Count must match UDimension * VDimension.
    @item Order >= 2 (X3D and VRML 97 spec require this too).
    @item Each xKnot must have exactly xDimension + Order items.
  )

  Weight will be used only if it has the same length as PointsCount.
  Otherwise, weight = 1.0 (that is, defining non-rational curve) will be used
  (this follows X3D spec).

  Normal, if non-nil, will be set to the normal at given point of the
  surface. It will be normalized. You can use this to pass these normals
  to rendering. Or to generate normals for X3D NurbsSurfaceInterpolator node. }
function NurbsSurfacePoint(const Points: TDynVector3SingleArray;
  const UDimension, VDimension: Cardinal;
  const U, V: Single;
  const UOrder, VOrder: Cardinal;
  UKnot, VKnot, Weight: TDynDoubleArray;
  Normal: PVector3_Single): TVector3_Single;

type
  { Naming notes: what precisely is called a "uniform" knot vector seems
    to differ in literature / software.
    Blender calls nkPeriodicUniform as "Uniform",
    and nkEndpointUniform as "Endpoint".
    http://en.wiki.mcneel.com/default.aspx/McNeel/NURBSDoc.html
    calls nkEndpointUniform as "Uniform".
    "An introduction to NURBS: with historical perspective"
    (by David F. Rogers) calls nkEndpointUniform "open uniform" and
    nkPeriodicUniform "periodic uniform". }

  { Type of NURBS knot vector to generate. }
  TNurbsKnotKind = (
    { All knot values are evenly spaced, all knots are single.
      This is good for periodic curves. }
    nkPeriodicUniform,
    { Starting and ending knots have Order multiplicity, rest is evenly spaced.
      The curve hits endpoints. }
    nkEndpointUniform);

{ Calculate a default knot, if Knot doesn't already have required number of items.
  After this, it's guaranteed that Knot.Count is Dimension + Order
  (just as required by NurbsCurvePoint, NurbsSurfacePoint). }
procedure NurbsKnotIfNeeded(Knot: TDynDoubleArray;
  const Dimension, Order: Cardinal; const Kind: TNurbsKnotKind);

implementation

{ findSpan and basisFuns is rewritten from white dune's C source code
  (almost identical methods of NodeNurbsCurve and NodeNurbsSurface).
  Also NurbsCurvePoint is based on NodeNurbsCurve::curvePoint.
  Also NurbsSurfacePoint is based on NodeNurbsSurface::surfacePoint.
  Also NurbsUniformKnotIfNeeded is based on NodeNurbsSurface::linearUknot.

  White dune:
  - http://vrml.cip.ica.uni-stuttgart.de/dune/
  - J. "MUFTI" Scheurich, Stephen F. White
  - GPL >= 2, so we're free to copy
  - findSpan and basisFuns were methods in NodeNurbsCurve
    (src/NodeNurbsCurve.cpp) and NodeNurbsSurface.
    *Almost* exactly identical, the only difference: NodeNurbsSurface
    had these two additional lines (safety check, included in my version):
      if ((right[r+1] + left[j-r]) == 0)
          return;
}
function findSpan(const dimension, order: LongInt;
  const u: Single; Knot: TDynDoubleArray): LongInt;
var
  low, mid, high, oldLow, oldMid, oldHigh, n: LongInt;
begin
  n := dimension + order - 1;

  if u >= Knot[n] then
  begin
    Result := n - order;
    Exit;
  end;

  low := order - 1;
  high := n - order + 1;

  mid := (low + high) div 2;

  oldLow := low;
  oldHigh := high;
  oldMid := mid;
  while (u < Knot[mid]) or (u >= Knot[mid+1]) do
  begin
    if u < Knot[mid] then
      high := mid else
      low := mid;

    mid := (low+high) div 2;

    // emergency abort of loop, otherwise a endless loop can occure
    if (low = oldLow) and (high = oldHigh) and (mid = oldMid) then
      break;

    oldLow := low;
    oldHigh := high;
    oldMid := mid;
  end;
  Result := mid;
end;

procedure basisFuns(const span: LongInt; const u: Single; const order: LongInt;
  Knot, basis, deriv: TDynDoubleArray);
var
  left, right: TDynDoubleArray;
  j, r: LongInt;
  saved, dsaved, temp: Single;
begin
  left := TDynDoubleArray.Create(order);
  right := TDynDoubleArray.Create(order);

  basis[0] := 1.0;
  for j := 1 to  order - 1 do
  begin
    left[j] := u - Knot[span+1-j];
    right[j] := Knot[span+j]-u;
    saved := 0.0;
    dsaved := 0.0;
    for r := 0 to j - 1 do
    begin
      if (right[r+1] + left[j-r]) = 0 then
        Exit;
      temp := basis[r] / (right[r+1] + left[j-r]);
      basis[r] := saved + right[r+1] * temp;
      deriv[r] := dsaved - j * temp;
      saved := left[j-r] * temp;
      dsaved := j * temp;
    end;
    basis[j] := saved;
    deriv[j] := dsaved;
  end;

  FreeAndNil(left);
  FreeAndNil(right);
end;

function ActualTessellation(const Tessellation: Integer;
  const Dimension: Cardinal): Cardinal;
begin
  if Tessellation > 0 then
    Result := Tessellation else
  if Tessellation = 0 then
    Result := 2 * Dimension else
    Result := Cardinal(-Tessellation) * Dimension;
  Inc(Result);
end;

function NurbsCurvePoint(const Points: PVector3Single;
  const PointsCount: Cardinal; const U: Single;
  const Order: Cardinal;
  Knot, Weight: TDynDoubleArray;
  Tangent: PVector3_Single): TVector3_Single;
var
  i: Integer;
  w, duw: Single;
  span: LongInt;
  basis, deriv: TDynDoubleArray;
  UseWeight: boolean;
  du: TVector3_Single;
  index: Cardinal;
begin
  UseWeight := Cardinal(Weight.Count) = PointsCount;

  basis := TDynDoubleArray.Create(order);
  deriv := TDynDoubleArray.Create(order);

  span := findSpan(PointsCount, order, u, Knot);

  basisFuns(span, u, order, Knot, basis, deriv);

  Result.Init_Zero;
  du.Init_Zero;

  w := 0.0;
  duw := 0.0;

  for i := 0 to order-1 do
  begin
    index := span-order+1+i;
    Result += Points[index] * basis[i];
    du += Points[index] * deriv[i];
    if UseWeight then
    begin
      w += weight[index] * basis[i];
      duw += weight[index] * deriv[i];
    end else
    begin
      w += basis[i];
      duw += deriv[i];
    end;
  end;

  Result /= w;

  if Tangent <> nil then
  begin
    Tangent^ := (du - Result * duw) / w;
    Vector_Normalize(Tangent^);
  end;

  FreeAndNil(basis);
  FreeAndNil(deriv);
end;

function NurbsCurvePoint(const Points: TDynVector3SingleArray;
  const U: Single;
  const Order: Cardinal;
  Knot, Weight: TDynDoubleArray;
  Tangent: PVector3_Single): TVector3_Single;
begin
  Result := NurbsCurvePoint(Points.Items, Points.Count, U, Order, Knot, Weight,
    Tangent);
end;

function NurbsSurfacePoint(const Points: TDynVector3SingleArray;
  const UDimension, VDimension: Cardinal;
  const U, V: Single;
  const UOrder, VOrder: Cardinal;
  UKnot, VKnot, Weight: TDynDoubleArray;
  Normal: PVector3_Single): TVector3_Single;
var
  uBasis, vBasis, uDeriv, vDeriv: TDynDoubleArray;
  uSpan, vSpan: LongInt;
  I, J: LongInt;
  uBase, vBase, index: Cardinal;
  du, dv, un, vn: TVector3_Single;
  w, duw, dvw: Single;
  gain, dugain, dvgain: Single;
  P: TVector3_Single;
  UseWeight: boolean;
begin
  UseWeight := Weight.Count = Points.Count;

  uBasis := TDynDoubleArray.Create(UOrder);
  vBasis := TDynDoubleArray.Create(VOrder);
  uDeriv := TDynDoubleArray.Create(UOrder);
  vDeriv := TDynDoubleArray.Create(VOrder);

  uSpan := findSpan(uDimension, uOrder, u, uKnot);
  vSpan := findSpan(vDimension, vOrder, v, vKnot);

  basisFuns(uSpan, u, uOrder, uKnot, uBasis, uDeriv);
  basisFuns(vSpan, v, vOrder, vKnot, vBasis, vDeriv);

  uBase := uSpan-uOrder+1;
  vBase := vSpan-vOrder+1;

  index := vBase*uDimension + uBase;
  Result.Init_Zero;
  du.Init_Zero;
  dv.Init_Zero;

  w := 0.0;
  duw := 0.0;
  dvw := 0.0;

  for j := 0 to vOrder -1 do
  begin
    for i := 0 to uOrder - 1 do
    begin
      gain := uBasis[i] * vBasis[j];
      dugain := uDeriv[i] * vBasis[j];
      dvgain := uBasis[i] * vDeriv[j];

      P := Points.Items[index];

      Result += P * gain;

      du += P * dugain;
      dv += P * dvgain;
      if UseWeight then
      begin
        w += weight[index] * gain;
        duw += weight[index] * dugain;
        dvw += weight[index] * dvgain;
      end else
      begin
        w += gain;
        duw += dugain;
        dvw += dvgain;
      end;
      Inc(index);
    end;
    index += uDimension - uOrder;
  end;

  Result /= w;

  if Normal <> nil then
  begin
    un := (du - Result * duw) / w;
    vn := (dv - Result * dvw) / w;
    normal^ := un >< vn;
    Vector_Normalize(normal^);
  end;

  FreeAndNil(uBasis);
  FreeAndNil(vBasis);
  FreeAndNil(uDeriv);
  FreeAndNil(vDeriv);
end;

procedure NurbsKnotIfNeeded(Knot: TDynDoubleArray;
  const Dimension, Order: Cardinal; const Kind: TNurbsKnotKind);
var
  I: Integer;
begin
  if Cardinal(Knot.Count) <> Dimension + Order then
  begin
    Knot.Count := Dimension + Order;

    case Kind of
      nkPeriodicUniform:
        begin
          for I := 0 to Knot.Count - 1 do
            Knot.Items[I] := I;
        end;
      nkEndpointUniform:
        begin
          for I := 0 to Order - 1 do
          begin
            Knot.Items[I] := 0;
            Knot.Items[Cardinal(I) + Dimension] := Dimension - Order + 1;
          end;
          for I := 0 to Dimension - Order - 1 do
            Knot.Items[Cardinal(I) + Order] := I + 1;
          for I := 0 to Order + Dimension - 1 do
            Knot.Items[I] /= Dimension - Order + 1;
        end;
      else raise EInternalError.Create('NurbsKnotIfNeeded 594');
    end;
  end;
end;

end.
