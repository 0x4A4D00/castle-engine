{
  Copyright 2009 Michalis Kamburelis.

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

  ----------------------------------------------------------------------------
}

{ Doing Fourier transforms (DFT and inverse) on images of TRGBImage class.
  Uses FFTW library through fftw_s unit provided with FPC.

  Note that this compiles only with FPC > 2.2.x (previous fftw unit
  contained bugs, like missing fftw_getmem/freemem in the interface,
  and unneeded linking to libraries like gcc). }
unit ImagesFftw;

interface

uses Fftw_s, Images;

type
  { Image expressed as three arrays of complex values.
    This is how FFTW views an image. }
  TImageComplex = array [0..2] of Pcomplex_single;

  TImageFftw = class
  private
    FImage: TRGBImage;
    FImageF, FImageComplex: TImageComplex;
    function GetImageF(Color: Integer): Pcomplex_single;
    FSize: Cardinal;
    PlanDFT, PlanIDFT: array [0..2] of fftw_plan_single;

    { Convert real values of image encoded in Complex
      into normal RGB image in Img. Apply scaling Scale by the way. }
    procedure ComplexToRGB(Complex: TImageComplex;
      Img: TRGBImage; const Scale: Single);
  public
    constructor Create(AImage: TRGBImage);
    destructor Destroy; override;

    { Image in the spatial domain.

      You can freely modify and change it whenever you like,
      the only requirement is that it's size (width and height)
      must stay the same. And it must always be assigned (non-nil). }
    property Image: TRGBImage read FImage write FImage;

    property Size: Cardinal read FSize;

    { Image in the frequency domain. Contents filled by the DFT call.

      Actually we have three images, for red, green and blue components.

      You can modify it between DFT and IDFT (that's actually the very
      purpose of this class, otherwise there's no point in doing
      DFT followed by IDFT just to get the same image...). }
    property ImageF[Color: Integer]: Pcomplex_single read GetImageF;

    { Fill TRGBImage showing the ImageF modulus contents.
      This actually shows the image in frequency domain, so is generally
      useful only for testing (you usually do not want to look
      at image in frequency domain, unless you understand what
      the frequency domain represents.) }
    procedure ImageFModulusAsRGB(Img: TRGBImage; const Scale: Single);

    { Perform DFT: from Image contents, make ImageF. }
    procedure DFT;

    { Perform IDFT: from ImageF, fill Image contents.

      At this point, we also take care of scaling, to make the result
      actually match the input: we divide each component by
      the number of Image pixels. }
    procedure IDFT;
  end;

{ Basic functions to operate on complex numbers.
  FFTW library unfortunately uses different complex type than
  UComplex standard unit (no surprise, they cannot depend on each other...),
  so unfortunately we have to write out own routines. }

{ }
function CNormalized(const Z: complex_single): complex_single;
function CMod(const Z: complex_single): Single;
function CNorm(const Z: complex_single): Single;

implementation

uses VectorMath, KambiUtils;

constructor TImageFftw.Create(AImage: TRGBImage);
var
  Color: Integer;
begin
  inherited Create;

  FImage := AImage;
  FSize := FImage.Width * FImage.Height;

  for Color := 0 to 2 do
  begin
    fftw_getmem(FImageComplex[Color], Size * SizeOf(complex_single));
    fftw_getmem(FImageF      [Color], Size * SizeOf(complex_single));

    { Make FFTW plans, since pointers FImageComplex and FImageF
      (for this Color index) are now constant. }

    PlanDFT[Color] := fftw_plan_dft_2d(Image.Height, Image.Width,
      FImageComplex[Color], FImageF[Color],
      fftw_forward, [fftw_estimate]);
    PlanIDFT[Color] := fftw_plan_dft_2d(Image.Height, Image.Width,
      FImageF[Color], FImageComplex[Color],
      fftw_backward, [fftw_estimate]);
  end;
end;

destructor TImageFftw.Destroy;
var
  Color: Integer;
begin
  for Color := 0 to 2 do
  begin
    fftw_destroy_plan(PlanDFT[Color]);
    fftw_destroy_plan(PlanIDFT[Color]);

    fftw_freemem(FImageComplex[Color]);
    fftw_freemem(FImageF      [Color]);
  end;
  inherited;
end;

function TImageFftw.GetImageF(Color: Integer): Pcomplex_single;
begin
  Result := FImageF[Color];
end;

procedure TImageFftw.DFT;
var
  Ptr: PVector3Byte;
  ImgComplexPtr: TImageComplex;
  Color, I: Integer;
begin
  { Copy Image to ImageComplex }

  Ptr := Image.RGBPixels;
  ImgComplexPtr := FImageComplex;

  for I := 0 to Size - 1 do
  begin
    for Color := 0 to 2 do
    begin
      ImgComplexPtr[Color]^.Re := Ptr^[Color];
      ImgComplexPtr[Color]^.Im := 0;
      Inc(ImgComplexPtr[Color]);
    end;

    Inc(Ptr);
  end;

  { Execute plans to convert ImageComplex to ImageF }
  for Color := 0 to 2 do
    fftw_execute(PlanDFT[Color]);
end;

procedure TImageFftw.ComplexToRGB(Complex: TImageComplex;
  Img: TRGBImage; const Scale: Single);
var
  Ptr: PVector3Byte;
  Color, I: Integer;
begin
  Ptr := Img.RGBPixels;

  for I := 0 to Size - 1 do
  begin
    for Color := 0 to 2 do
    begin
      Ptr^[Color] := Clamped(Round(Complex[Color]^.Re * Scale),
        Low(Byte), High(Byte));
      Inc(Complex[Color]);
    end;

    Inc(Ptr);
  end;
end;

procedure TImageFftw.ImageFModulusAsRGB(Img: TRGBImage; const Scale: Single);
var
  Ptr: PVector3Byte;
  Color, I: Integer;
  Complex: TImageComplex;
begin
  Ptr := Img.RGBPixels;
  Complex := FImageF;

  for I := 0 to Size - 1 do
  begin
    for Color := 0 to 2 do
    begin
      Ptr^[Color] := Clamped(Round(CMod(Complex[Color]^) * Scale),
        Low(Byte), High(Byte));
      Inc(Complex[Color]);
    end;

    Inc(Ptr);
  end;
end;

procedure TImageFftw.IDFT;
var
  Color: Integer;
begin
  { Execute plans to convert ImageF to ImageComplex }
  for Color := 0 to 2 do
    fftw_execute(PlanIDFT[Color]);

  { Copy ImageComplex to Image, also normalizing (dividing by Size)
    by the way. }
  ComplexToRGB(FImageComplex, Image, 1 / Size);
end;

{ Complex functions ---------------------------------------------------------- }

function CNormalized(const Z: complex_single): complex_single;
var
  M: Single;
begin
  M := CMod(Z);
  Result.Re := Z.Re / M;
  Result.Im := Z.Im / M;
end;

function CMod(const Z: complex_single): Single;
begin
  Result := Sqrt(Sqr(Z.Re) + Sqr(Z.Im));
end;

function CNorm(const Z: complex_single): Single;
begin
  Result := Sqr(Z.Re) + Sqr(Z.Im);
end;

end.
