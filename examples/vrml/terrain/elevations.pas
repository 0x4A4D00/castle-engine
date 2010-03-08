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

{ Elevation (terrain) implementations. }
unit Elevations;

interface

uses SysUtils, Classes, KambiScript, Images;

type
  { Elevation (height for each X, Y) data. }
  TElevation = class
  public
    function Height(const X, Y: Single): Single; virtual; abstract;
  end;

  { Elevation (height for each X, Y) data taken from intensities in an image.

    The image covers (0, 0) ... (1, 1) area in XY plane (it is repeated
    infinitely if you ask for Height outside of this range).
    Image color (converted to grayscale) acts as height (scaled by
    ImageHeightScale).

    When image is not loaded, this always returns height = 0. }
  TElevationImage = class(TElevation)
  private
    { FImage = nil and FImageFileName = '' when not loaded. }
    FImage: TGrayscaleImage;
    FImageFileName: string;
    FImageHeightScale: Single;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadImage(const AImageFileName: string);
    procedure ClearImage;
    property ImageFileName: string read FImageFileName;

    property ImageHeightScale: Single
      read FImageHeightScale write FImageHeightScale default 1.0;

    function Height(const X, Y: Single): Single; override;
  end;

  { Elevation (height for each X, Y) data calculated from KambiScript
    expression. At construction, pass FunctionExpression,
    that is KambiScript language expression calculating height
    based on X, Y.

    This descends from TElevationImage, so you add an image to
    your function result. }
  TElevationKamScript = class(TElevationImage)
  private
    FXVariable, FYVariable: TKamScriptFloat;
    FFunction: TKamScriptExpression;
  public
    constructor Create(const FunctionExpression: string);
    destructor Destroy; override;
    function Height(const X, Y: Single): Single; override;
  end;

  TNoiseInterpolation = (niNone, niLinear, niCosine);
  TNoise2DMethod = function (const X, Y: Single; const Seed: Cardinal): Single;

  { Procedural terrain: elevation data from a procedural noise.

    "Synthesized noise" means it's not simply something random.
    We take the noise (integer noise, i.e. hash), smooth it
    (how well, and how fast --- see @link(Interpolation) and @link(Blur)),
    and add several
    functions ("octaves") of such noise (with varying frequency and amplitude)
    together. This is the kind of noise used to synthesize textures,
    terrains and all other procedural stuff.

    For more info about math inside:

    @unorderedList(
      @item([http://en.wikipedia.org/wiki/Fractional_Brownian_motion].
        This is the idea of summing up octaves of noise.
        Ken Musgrave's dissertation has a lot of info and interesting references:
        [http://www.kenmusgrave.com/dissertation.html])

      @item(Blender's source code is informative, interesting file
        is blender/source/blender/blenlib/intern/noise.c)

      @item(
        The simplest practical introduction to the idea I found is on
        [http://freespace.virgin.net/hugo.elias/models/m_perlin.htm].
        It describes how to get nice noise very easily, and my approach follows
        theirs.

        The article isn't perfect, for starters --- it doesn't actually
        describe Perlin noise as far as I understand :) (Perlin noise
        is "gradient noise" with some implementation hints; article describes
        "value noise"; the idea of cubic interpolation doesn't come from
        Perlin, AFAIK. Things specific about Perlin noise:
        [http://web.archive.org/web/20070706003038/http://www.cs.cmu.edu/~mzucker/code/perlin-noise-math-faq.html],
        [http://www.noisemachine.com/talk1/index.html].)
    )

    This descends from TElevationImage, so you add an image to
    your function result. }
  TElevationNoise = class(TElevationImage)
  private
    FOctaves: Single;
    FSmoothness: Single;
    FAmplitude: Single;
    FFrequency: Single;
    FInterpolation: TNoiseInterpolation;
    NoiseMethod: TNoise2DMethod;
    FBlur: boolean;
    FSeed: Cardinal;
    procedure SetInterpolation(const Value: TNoiseInterpolation);
    procedure SetBlur(const Value: boolean);
    procedure UpdateNoiseMethod;
  public
    constructor Create;
    function Height(const X, Y: Single): Single; override;

    { Number of noise functions to sum.
      This linearly affects the time for Height call, so don't make
      it too much. Usually ~a few are Ok.

      (The fact that it's a float is just a simple trick to allow smooth
      transitions from x to x+1. In fact, it's executed like
      Trunc(Octaves) * some noises + Frac(Octaves) * some last noise.) }
    property Octaves: Single read FOctaves write FOctaves default 4.0;

    { How noise amplitude changes, when frequency doubles.
      When we double frequency, amplitude is divided by this.
      Smaller values <=> larger frequency noise
      is more visible, so terrain is less smooth (more noisy).

      This is elsewhere called fractal increment, fractal dimension parameter,
      "H", spectral exponent (see e.g. Blender sources, Musgrave's dissertation).
      Do not confuse this with "lacunarity" (how frequency changes in each octave),
      that is simply hardcoded to 2.0 in our code currently.
      In [http://freespace.virgin.net/hugo.elias/models/m_perlin.htm],
      the inverse of this 1/Smoothness is called "Persistence".

      I decided to call it "Smoothness", since this is the practical
      intuitive meaning.

      Value equal 1.0 means that amplitude doesn't change at all,
      each noise frequency is visible the same, so in effect you will
      just see a lot of noise. And values < 1.0 are really nonsense,
      they make more frequency noise even more visible, which means that
      the terrain is dominated by noise. }
    property Smoothness: Single read FSmoothness write FSmoothness default 2.0;

    { Amplitude and frequency of the first noise octave.
      Amplitude scales the height of the result, and Frequency scales
      the size of the bumps.
      @groupBegin }
    property Amplitude: Single read FAmplitude write FAmplitude default 1.0;
    property Frequency: Single read FFrequency write FFrequency default 1.0;
    { @groupEnd }

    { How integer noise is interpolated to get smooth float noise.

      Setting this to niNone turns off interpolation, which means that
      your terrain is a sum of a couple of blocky noises --- ugly.

      Using niLinear (means "bilinear", since this is 2D case)
      is also usually bad. Unless you use octaves of really high frequencies,
      usually sharp edges  / flat in-betweens will be visible.

      Using niCosine in right now the best.

      TODO: one day cubic interpolation (using Catmull-Rom splines,
      which are special case of cubic Hermite spline, see
      http://en.wikipedia.org/wiki/Cubic_Hermite_spline,
      http://en.wikipedia.org/wiki/Bicubic_interpolation)
      should be implemented. I was planning it, but eventually cosine
      version turned out good and fast enough. }
    property Interpolation: TNoiseInterpolation
      read FInterpolation write SetInterpolation default niCosine;

    { Resulting noise octaves may be blurred. This helps to remove
      the inherent vertical/horizontal directionality in our 2D noise
      (it also makes it more smooth, since that's what blurring is about;
      you may want to increase Frequency * 2 to balance this).

      This is independent from @link(Interpolation). Although the need
      for Blur is most obvious in poor/none interpolation methods
      (none, linear), it also helps for the nicer interpolation methods
      (cosine, cubic).

      Note about [http://freespace.virgin.net/hugo.elias/models/m_perlin.htm]:
      this "blurring" is called "smoothing" there.
      I call it blurring, as it seems more precise to me. }
    property Blur: boolean read FBlur write SetBlur default false;

    { Determines the random seeds used when generating the terrain. }
    property Seed: Cardinal read FSeed write FSeed default 0;
  end;

  { Elevation data from a grid of values with specified width * height.
    Used when your underlying data is a simple 2D array of
    GridSizeX * GridSizeY heights.
    The idea is that on such elevation, there are special grid points
    where the height data is accurate. Everything else is an interpolation
    derived from this data. }
  TElevationGrid = class(TElevation)
  public
    { Get height of the elevation at specified 2D point.

      This is implemented in TElevationGrid class, using
      the data returned by GridHeight. For float X in 0..1 range,
      we return grid values for grid points 0..GridSizeX - 1.
      Outside 0..1 range, we clamp (that is, take nearest value
      from 0..1 range) --- this way the elevation seemingly continues
      into the infinity.

      In comparison to GridHeight, it's (very slightly) slower,
      and it doesn't really present any more interesting information
      (in contrast to typical procedural terrain, where there can be always
      more and more detail at each level). }
    function Height(const X, Y: Single): Single; override;

    { GridSizeX, GridSizeY specify grid dimensions.
      Use GridHeight(0..GridSizeX - 1, 0..GridSizeY - 1) to get height
      at particular grid point.
      @groupBegin }
    function GridHeight(const X, Y: Cardinal): Single; virtual; abstract;
    function GridSizeX: Cardinal; virtual; abstract;
    function GridSizeY: Cardinal; virtual; abstract;
    { @groupEnd }
  end;

  TElevationSRTM = class(TElevationGrid)
  private
    FData: array [0..1200, 0..1200] of SmallInt;
  public
    constructor CreateFromFile(const FileName: string);

    function GridHeight(const X, Y: Cardinal): Single; override;
    function GridSizeX: Cardinal; override;
    function GridSizeY: Cardinal; override;
  end;

implementation

uses KambiUtils, KambiScriptParser, Noise, Math;

{ TElevationImage ------------------------------------------------------------ }

constructor TElevationImage.Create;
begin
  inherited;
  FImageHeightScale := 1.0;
end;

destructor TElevationImage.Destroy;
begin
  ClearImage;
  inherited;
end;

procedure TElevationImage.LoadImage(const AImageFileName: string);
var
  NewImage: TGrayscaleImage;
begin
  NewImage := Images.LoadImage(AImageFileName, [TGrayscaleImage], []) as TGrayscaleImage;

  FreeAndNil(FImage);
  FImage := NewImage;
  FImageFileName := AImageFileName;
end;

procedure TElevationImage.ClearImage;
begin
  FreeAndNil(FImage);
  FImageFileName := '';
end;

function TElevationImage.Height(const X, Y: Single): Single;
var
  PX, PY: Integer;
begin
  if FImage <> nil then
  begin
    PX := Floor(X * FImage.Width) mod FImage.Width;
    PY := Floor(Y * FImage.Height) mod FImage.Height;
    if PX < 0 then PX += FImage.Width;
    if PY < 0 then PY += FImage.Height;
    Result := (FImage.PixelPtr(PX, PY)^ / High(Byte)) * ImageHeightScale;
  end else
    Result := 0;
end;

{ TElevationKamScript -------------------------------------------------------- }

constructor TElevationKamScript.Create(const FunctionExpression: string);
begin
  inherited Create;

  FXVariable := TKamScriptFloat.Create(false);
  FXVariable.Name := 'x';
  FXVariable.OwnedByParentExpression := false;

  FYVariable := TKamScriptFloat.Create(false);
  FYVariable.Name := 'y';
  FYVariable.OwnedByParentExpression := false;

  FFunction := ParseFloatExpression(FunctionExpression, [FXVariable, FYVariable]);
end;

destructor TElevationKamScript.Destroy;
begin
  FFunction.FreeByParentExpression;
  FFunction := nil;

  FreeAndNil(FXVariable);
  FreeAndNil(FYVariable);

  inherited;
end;

function TElevationKamScript.Height(const X, Y: Single): Single;
begin
  Result := inherited;
  FXVariable.Value := X;
  FYVariable.Value := Y;
  Result += (FFunction.Execute as TKamScriptFloat).Value;
end;

{ TElevationNoise ------------------------------------------------------------ }

constructor TElevationNoise.Create;
begin
  inherited Create;
  FOctaves := 4.0;
  FSmoothness := 2.0;
  FAmplitude := 1.0;
  FFrequency := 1.0;
  FInterpolation := niCosine;
  FBlur := false;
  UpdateNoiseMethod;
end;

procedure TElevationNoise.UpdateNoiseMethod;
begin
  if Blur then
    case Interpolation of
      niNone: NoiseMethod := @BlurredInterpolatedNoise2D_None;
      niLinear: NoiseMethod := @BlurredInterpolatedNoise2D_Linear;
      niCosine: NoiseMethod := @BlurredInterpolatedNoise2D_Cosine;
      else raise EInternalError.Create('TElevationNoise.UpdateNoiseMethod(Interpolation?)');
    end else
    case Interpolation of
      niNone: NoiseMethod := @InterpolatedNoise2D_None;
      niLinear: NoiseMethod := @InterpolatedNoise2D_Linear;
      niCosine: NoiseMethod := @InterpolatedNoise2D_Cosine;
      else raise EInternalError.Create('TElevationNoise.UpdateNoiseMethod(Interpolation?)');
    end
end;

procedure TElevationNoise.SetInterpolation(const Value: TNoiseInterpolation);
begin
  FInterpolation := Value;
  UpdateNoiseMethod;
end;

procedure TElevationNoise.SetBlur(const Value: boolean);
begin
  FBlur := Value;
  UpdateNoiseMethod;
end;

function TElevationNoise.Height(const X, Y: Single): Single;
var
  A, F: Single;
  I: Cardinal;
begin
  Result := inherited;
  A := Amplitude;
  F := Frequency;
  for I := 1 to Trunc(Octaves) do
  begin
    Result += NoiseMethod(X * F, Y * F, I + Seed) * A;
    F *= 2;
    A /= Smoothness;
  end;
  Result += Frac(Octaves) * NoiseMethod(X * F, Y * F, Trunc(Octaves) + 1 + Seed) * A;
end;

{ TElevationGrid ------------------------------------------------------------- }

function TElevationGrid.Height(const X, Y: Single): Single;
begin
  { TODO: for now, just take the nearest point, no bilinear filtering. }
  Result := GridHeight(
    Clamped(Round(X * (GridSizeX - 1)), 0, GridSizeX - 1),
    Clamped(Round(Y * (GridSizeY - 1)), 0, GridSizeY - 1));
end;

{ TElevationSRTM ------------------------------------------------------------- }

constructor TElevationSRTM.CreateFromFile(const FileName: string);
var
  Stream: TFileStream;
  P: PSmallInt;
  I: Cardinal;
  LastCorrectHeight: SmallInt;
begin
  inherited Create;

  Stream := TFileStream.Create(FileName, fmOpenRead);
  try
    Stream.ReadBuffer(FData, SizeOf(FData));
  finally FreeAndNil(Stream) end;

  LastCorrectHeight := 0; { any sensible value }
  P := @(FData[0, 0]);
  for I := 1 to 1201 * 1201 do
  begin
    {$ifdef ENDIAN_LITTLE}
    P^ := Swap(P^);
    {$endif ENDIAN_LITTLE}

    { Fix unknown data by setting to last correct seen value.
      Since we scan data cell-by-cell, in a row, this is in practice
      somewhat excusable approach. Of course, we could do something much better
      (filling unknown values by interpolating values from around). }
    if P^ = Low(SmallInt) then
      P^ := LastCorrectHeight else
      LastCorrectHeight := P^;

    Inc(P);
  end;
end;

function TElevationSRTM.GridHeight(const X, Y: Cardinal): Single;
begin
  Result := FData[X, Y];
end;

function TElevationSRTM.GridSizeX: Cardinal;
begin
  Result := 1201;
end;

function TElevationSRTM.GridSizeY: Cardinal;
begin
  Result := 1201;
end;

end.
