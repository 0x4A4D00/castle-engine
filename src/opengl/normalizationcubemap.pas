{
  Copyright 2007-2011 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ OpenGL trick: cube map texture to normalize vectors. }
unit NormalizationCubeMap;

interface

uses GL, GLU, GLExt, KambiGLUtils;

{ Generate new OpenGL texture number and set it's 6
  GL_TEXTURE_CUBE_MAP_*_ARB targets to cube map used to normalize vectors.
  After this call, returned texture is currently bound. }
function MakeNormalizationCubeMap: TGLuint;

implementation

uses SysUtils, KambiUtils, Images, VectorMath;

{ $define DEBUG_SAVE_NORMAL_IMAGES}

function MakeNormalizationCubeMap: TGLuint;

  procedure FillNormalized(out NormalAsColor: TVector3Byte; V: TVector3Single);
  begin
    NormalizeTo1st(V);
    { clamping just for safety, these are floating point vals after all }
    NormalAsColor[0] := Clamped( Trunc((V[0] + 1) / 2 * High(Byte)), Low(Byte), High(Byte));
    NormalAsColor[1] := Clamped( Trunc((V[1] + 1) / 2 * High(Byte)), Low(Byte), High(Byte));
    NormalAsColor[2] := Clamped( Trunc((V[2] + 1) / 2 * High(Byte)), Low(Byte), High(Byte));
  end;

var
  Image: TRGBImage;
  S, T, Size, Size1: Cardinal;
begin
  glGenTextures(1, @Result);
  glBindTexture(GL_TEXTURE_CUBE_MAP_ARB, Result);

  glTexParameteri(GL_TEXTURE_CUBE_MAP_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_CUBE_MAP_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

  glTexParameteri(GL_TEXTURE_CUBE_MAP_ARB, GL_TEXTURE_WRAP_S, KamGL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_CUBE_MAP_ARB, GL_TEXTURE_WRAP_T, KamGL_CLAMP_TO_EDGE);

  { We will access this using 3D texture coordinates.
    But, as far as I understand the specs of ARB_texture_cube_map,
    wrapping modes will work on only s,t coordinates, i.e. after the 3D
    vector will be mapped to one of six faces. So GL_TEXTURE_WRAP_R, like
      glTexParameteri(GL_TEXTURE_CUBE_MAP_ARB, GL_TEXTURE_WRAP_R, KamGL_CLAMP_TO_EDGE);
    is meaningless.

    (I write about this because
    http://www.paulsprojects.net/tutorials/simplebump/simplebump.html
    does this.) }

  { Make sure we don't use too large size.
    ARB_texture_cube_map requires that it's >= 16.
    On kocury GeForce FX 5200 it's 4096. }
  Size := Min(32, glGetInteger(GL_MAX_CUBE_MAP_TEXTURE_SIZE_ARB));
  Size1 := Size - 1;

  Image := TRGBImage.Create(Size, Size);
  try
    for S := 0 to Size1 do
      for T := 0 to Size1 do
        FillNormalized( Image.PixelPtr(S, T)^,
          Vector3Single(
            1,
            - ((T / Size1) * 2 - 1),
            - ((S / Size1) * 2 - 1)));

    glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X_ARB, 0, 3,
      Image.Width, Image.Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image.RawPixels);

    {$ifdef DEBUG_SAVE_NORMAL_IMAGES}
    SaveImage(Image, '/tmp/normal_POSITIVE_X.png');
    {$endif}

    for S := 0 to Size1 do
      for T := 0 to Size1 do
        FillNormalized( Image.PixelPtr(S, T)^,
          Vector3Single(
            - 1,
            - ((T / Size1) * 2 - 1),
               (S / Size1) * 2 - 1));

    glTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_X_ARB, 0, 3,
      Image.Width, Image.Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image.RawPixels);

    {$ifdef DEBUG_SAVE_NORMAL_IMAGES}
    SaveImage(Image, '/tmp/normal_NEGATIVE_X.png');
    {$endif}

    for S := 0 to Size1 do
      for T := 0 to Size1 do
        FillNormalized( Image.PixelPtr(S, T)^,
          Vector3Single(
            (S / Size1) * 2 - 1,
            1,
            (T / Size1) * 2 - 1));

    glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_Y_ARB, 0, 3,
      Image.Width, Image.Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image.RawPixels);

    {$ifdef DEBUG_SAVE_NORMAL_IMAGES}
    SaveImage(Image, '/tmp/normal_POSITIVE_Y.png');
    {$endif}

    for S := 0 to Size1 do
      for T := 0 to Size1 do
        FillNormalized( Image.PixelPtr(S, T)^,
          Vector3Single(
              (S / Size1) * 2 - 1,
            - 1,
            - ((T / Size1) * 2 - 1)));

    glTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_Y_ARB, 0, 3,
      Image.Width, Image.Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image.RawPixels);

    {$ifdef DEBUG_SAVE_NORMAL_IMAGES}
    SaveImage(Image, '/tmp/normal_NEGATIVE_Y.png');
    {$endif}

    for S := 0 to Size1 do
      for T := 0 to Size1 do
        FillNormalized( Image.PixelPtr(S, T)^,
          Vector3Single(
               (S / Size1) * 2 - 1,
            - ((T / Size1) * 2 - 1),
            1));

    glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_Z_ARB, 0, 3,
      Image.Width, Image.Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image.RawPixels);

    {$ifdef DEBUG_SAVE_NORMAL_IMAGES}
    SaveImage(Image, '/tmp/normal_POSITIVE_Z.png');
    {$endif}

    for S := 0 to Size1 do
      for T := 0 to Size1 do
        FillNormalized( Image.PixelPtr(S, T)^,
          Vector3Single(
            - ((S / Size1) * 2 - 1),
            - ((T / Size1) * 2 - 1),
            - 1));

    glTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_Z_ARB, 0, 3,
      Image.Width, Image.Height, 0, GL_RGB, GL_UNSIGNED_BYTE, Image.RawPixels);

    {$ifdef DEBUG_SAVE_NORMAL_IMAGES}
    SaveImage(Image, '/tmp/normal_NEGATIVE_Z.png');
    {$endif}

  finally FreeAndNil(Image) end;
end;

end.
