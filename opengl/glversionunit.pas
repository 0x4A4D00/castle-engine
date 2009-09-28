{
  Copyright 2001-2008 Michalis Kamburelis.

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

{ Implements GLVersion, GLUVersion and related stuff handy for checking
  OpenGL version information, detect Mesa/other vendors etc.

  As you see, this unit doesn't use GL bindings itself.
  That's so that it may be used with various OpenGL bindings,
  like my old OpenGLh or FPC's GL, GLU, GLExt.
  So you must manually initialize GLVersion from some othe unit.
  As far as my engine is concerned, this will happen automatically
  by LoadAllExtensions call. Which is done by GLWindow on Init,
  or TKamOpenGLControl on GL context initialization.
}
unit GLVersionUnit;

{$include openglmac.inc}

interface

type
  { This is used to store OpenGL libraries (core OpenGL or GLU)
    version information.

    As obtained from glGetString(GL_VERSION)
    or gluGetString(GLU_VERSION), also by glGetString(GL_VENDOR).

    This is usually created by KambiGLUtils.LoadAllExtensions. }
  TGenericGLVersion = class
  public
    constructor Create(const VersionString: string);
  public
    { Required (i.e. every OpenGL implemenetation has them)
      major and minor numbers.
      @groupBegin }
    Major: Integer;
    Minor: Integer;
    { @groupEnd }

    { Release is the optional release number (check ReleaseExists first).
      @groupBegin }
    ReleaseExists: boolean;
    Release: Integer;
    { @groupEnd }

    { VendorVersion is whatever vendor-specific information was placed
      inside VersionString, after the
      major_number.minor_number.release_number. It never has any whitespace
      at the beginning (we trim it when initializing). }
    VendorVersion: string;

    function AtLeast(AMajor, AMinor: Integer): boolean;
  end;

  TGLVersion = class(TGenericGLVersion)
  private
    FVendor: string;
    FRenderer: string;
    FIsVendorATI: boolean;
    FIsFglrx: boolean;
    FVendorNVidia: boolean;
    FBuggyPointSetAttrib: boolean;
    FBuggyDrawOddWidth: boolean;
    FBuggyGenerateMipmap: boolean;
  public
    constructor Create(const VersionString, AVendor, ARenderer: string);
  public
    { @abstract(Are we using Mesa (http://mesa3d.org/)?)

      Detected using VendorSpecific information
      (extracted by base TGenericGLVersion), this allows us to detect
      Mesa and Mesa version.
      @groupBegin }
    IsMesa: boolean;
    MesaMajor: Integer;
    MesaMinor: Integer;
    MesaRelease: Integer;
    { @groupEnd }

    { This is just glGetString(GL_VENDOR). }
    property Vendor: string read FVendor;

    { This is just glGetString(GL_RENDERER). }
    property Renderer: string read FRenderer;

    { Is the Vendor ATI? In other words, is it an ATI GPU with ATI drivers. }
    property IsVendorATI: boolean read FIsVendorATI;

    { Is the Vendor ATI and we're on Linux? }
    property IsFglrx: boolean read FIsFglrx;

    { Detect NVidia GPU. }
    property VendorNVidia: boolean read FVendorNVidia;

    { Detect Mesa DRI Intel with buggy GL_POINT_SET flag for glPushAttrib.

      Observed on Ubuntu 8.10 on computer "domek".
      It seems a bug in upstream Mesa 7.2, as it's reproducible with
      version from http://mesa3d.org/.
      Seemingly reproducible only with "DRI Intel"
      (not reproducible on "chantal" with upstream Mesa 7.2).

      Reported to Ubuntu as
      https://bugs.launchpad.net/ubuntu/+source/mesa/+bug/312830,
      let them report upstream if needed.
      For now this is @true just always when IsMesa is detected
      and Renderer indicates "Mesa DRI Intel...".
      Avoiding GL_POINT_SET doesn't hurt us much. Feel free to investigate
      various Mesa versions and report to me which version does / does not
      need BuggyPointSetAttrib = @true. }
    property BuggyPointSetAttrib: boolean read FBuggyPointSetAttrib;

    { Detect fglrx (ATI Radeon on Linux) with buggy drawing of images
      with odd width.

      I observe this under Debian testing after upgrading fglrx
      from 8-12-4 to 9-2-2. I know the bug wasn't present in 8-12-4
      (and some other < 8-12-4 that I previously used), and it is in 9-2-2.

      I also see this on Mac OS X with the same GPU (driver GL_VERSION:
      2.0 ATI-1.4.56, GL_RENDERER: ATI Radeon X1600 OpenGL Engine).
      Although it's less common on Mac OS X, but can be seen with
      kambi_vrml_test_suite/x3d/kambi_extensions/rendered_texture.x3dv:
      open it, then make some operation that saves screen,
      e.g. open dialog by Ctrl+O.

      Precisely, the problem is for images with size like 819 x 614.
      Drawing them by glDrawPixels (including the case when you put
      this in display list) requires glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
      (as our TRGBImage is not aligned). And on GPUs with
      BuggyDrawOddWidth, such glDrawPixels will simply draw a random
      mess of colors on the screen, like some memory garbage.
      (Note that the image is actually correct, even capturing it
      by glReadPixels works Ok; only drawing of it fails.)

      As far as I tested, this doesn't seem related to
      actual GL_UNPACK_ALIGNMENT (glPixelStorei(GL_UNPACK_ALIGNMENT, 4)
      may also produce the bug, e.g. when used with ImageDrawPart
      trying to draw subimage with odd width). }
    property BuggyDrawOddWidth: boolean read FBuggyDrawOddWidth;

    { Detect Mesa with crashing glGenerateMipmapEXT.

      This was observed with software (no direct) rendering with
      7.0.2 (segfaults) and 7.2.? (makes X crashing; sweet).
      With Mesa 7.5.1 (but tested only with radeon and radeonhd,
      so possibly it's not really related to Mesa version! Reports welcome)
      no problems. }
    property BuggyGenerateMipmap: boolean read FBuggyGenerateMipmap;

  end;

var
  { Core OpenGL version information.
    This is usually created by KambiGLUtils.LoadAllExtensions. }
  GLVersion: TGLVersion;

  { GLU version information.
    This is usually created by KambiGLUtils.LoadAllExtensions. }
  GLUVersion: TGenericGLVersion;

implementation

uses SysUtils, KambiStringUtils, KambiUtils;

{ TGenericGLVersion ---------------------------------------------------------- }

type
  EInvalidGLVersionString = class(Exception);

procedure ParseWhiteSpaces(const S: string; var I: Integer);
begin
  while SCharIs(S, I, WhiteSpaces) do Inc(I);
end;

constructor TGenericGLVersion.Create(const VersionString: string);
const
  Digits = ['0'..'9'];
var
  NumberBegin, I: Integer;
begin
  inherited Create;

  try
    I := 1;

    { Note: we allow some whitespace that is not allowed by OpenGL/GLU
      spec. That's because we try hard to work correctly even with
      broken GL_VERSION / GLU_VERSION strings. }

    { Whitespace }
    ParseWhiteSpaces(VersionString, I);

    { Major number }
    if not SCharIs(VersionString, I, Digits) then
      raise EInvalidGLVersionString.Create('Major version number not found');
    NumberBegin := I;
    while SCharIs(VersionString, I, Digits) do Inc(I);
    Major := StrToInt(CopyPos(VersionString, NumberBegin, I - 1));

    { Whitespace }
    ParseWhiteSpaces(VersionString, I);

    { Dot }
    if not SCharIs(VersionString, I, '.') then
      raise EInvalidGLVersionString.Create(
        'The dot "." separator major and minor version number not found');
    Inc(I);

    { Whitespace }
    ParseWhiteSpaces(VersionString, I);

    { Minor number }
    if not SCharIs(VersionString, I, Digits) then
      raise EInvalidGLVersionString.Create('Minor version number not found');
    NumberBegin := I;
    while SCharIs(VersionString, I, Digits) do Inc(I);
    Minor := StrToInt(CopyPos(VersionString, NumberBegin, I - 1));

    ReleaseExists := SCharIs(VersionString, I, '.');

    if ReleaseExists then
    begin
      { Dot }
      Inc(I);

      { Release number }
      if not SCharIs(VersionString, I, Digits) then
      raise EInvalidGLVersionString.Create(
        'Release version number not found, ' +
        'although there was a dot after minor number');
      NumberBegin := I;
      while SCharIs(VersionString, I, Digits) do Inc(I);
      Release := StrToInt(CopyPos(VersionString, NumberBegin, I - 1));
    end;

    { Whitespace }
    ParseWhiteSpaces(VersionString, I);

    VendorVersion := SEnding(VersionString, I);
  except
    { In case of any error here: silence it.
      So actually EInvalidGLVersionString is not useful.
      We want our program to work even with broken GL_VERSION or GLU_VERSION
      strings.

      Class constructor always starts with Major and Minor initialized
      to 0, ReleaseExists initialized to false, and VendorVersion to ''.
      If we have here an exception, only part of them may be initialized. }
  end;
end;

function TGenericGLVersion.AtLeast(AMajor, AMinor: Integer): boolean;
begin
  Result := (AMajor < Major) or
    ( (AMajor = Major) and (AMinor <= Minor) );
end;

{ TGLVersion ----------------------------------------------------------------- }

constructor TGLVersion.Create(const VersionString, AVendor, ARenderer: string);

  { Parse Mesa version, starting from S[I] (where I should
    be the index in S right after the word "Mesa"). }
  procedure ParseMesaVersion(const S: string; var I: Integer);
  const
    Digits = ['0'..'9'];
  var
    NumberBegin: Integer;
  begin
    { Whitespace }
    ParseWhiteSpaces(S, I);

    { Mesa major number }
    if not SCharIs(S, I, Digits) then
      raise EInvalidGLVersionString.Create('Mesa major version number not found');
    NumberBegin := I;
    while SCharIs(S, I, Digits) do Inc(I);
    MesaMajor := StrToInt(CopyPos(S, NumberBegin, I - 1));

    { Whitespace }
    ParseWhiteSpaces(S, I);

    { Dot }
    if not SCharIs(S, I, '.') then
      raise EInvalidGLVersionString.Create(
        'The dot "." separator between Mesa major and minor version number not found');
    Inc(I);

    { Whitespace }
    ParseWhiteSpaces(S, I);

    { Mesa minor number }
    if not SCharIs(S, I, Digits) then
      raise EInvalidGLVersionString.Create('Mesa minor version number not found');
    NumberBegin := I;
    while SCharIs(S, I, Digits) do Inc(I);
    MesaMinor := StrToInt(CopyPos(S, NumberBegin, I - 1));

    { Whitespace }
    ParseWhiteSpaces(S, I);

    { Dot }
    if SCharIs(S, I, '.') then
    begin
      Inc(I);

      { Whitespace }
      ParseWhiteSpaces(S, I);

      { Mesa release number }
      if not SCharIs(S, I, Digits) then
        raise EInvalidGLVersionString.Create('Mesa release version number not found');
      NumberBegin := I;
      while SCharIs(S, I, Digits) do Inc(I);
      MesaRelease := StrToInt(CopyPos(S, NumberBegin, I - 1));
    end else
    begin
      { Some older Mesa versions (like 5.1) and newer (7.2) really
        don't have release number inside a version string.
        Seems like they don't have
        release number at all, and assuming "0" seems sensible following
        version names on WWW. So the missing dot "."
        separator between Mesa minor and release version number should
        be ignored. }
      MesaRelease := 0;
    end;
  end;

  function MesaVersionAtLeast(VerMaj, VerMin, VerRel: Integer): boolean;
  begin
    Result :=
        (MesaMajor > VerMaj) or
      ( (MesaMajor = VerMaj) and (

        (MesaMinor > VerMin) or
      ( (MesaMinor = VerMin) and (

         MesaRelease >= VerRel
      ))));
  end;

var
  VendorName, S: string;
  MesaStartIndex, I: Integer;
begin
  inherited Create(VersionString);

  try
    I := 1;
    while SCharIs(VendorVersion, I, AllChars - WhiteSpaces) do Inc(I);

    VendorName := CopyPos(VendorVersion, 1, I - 1);
    IsMesa := SameText(VendorName, 'Mesa');
    if IsMesa then
      ParseMesaVersion(VendorVersion, I) else
    begin
      { I'm seeing also things like GL_VERSION = 1.4 (2.1 Mesa 7.0.4)
        (Debian testing (lenny) on 2008-12-31).
        So "Mesa" may be within parenthesis, preceeded by another version
        number. }
      if SCharIs(VendorVersion, 1, '(') and
         (VendorVersion[Length(VendorVersion)] = ')') then
      begin
        S := Copy(VendorVersion, 2, Length(VendorVersion) - 2);
        I := 1;

        { omit preceeding version number }
        while SCharIs(S, I, AllChars - WhiteSpaces) do Inc(I);

        { omit whitespace }
        ParseWhiteSpaces(S, I);

        { read "Mesa" (hopefully) string }
        MesaStartIndex := I;
        while SCharIs(S, I, AllChars - WhiteSpaces) do Inc(I);

        VendorName := CopyPos(S, MesaStartIndex, I - 1);
        IsMesa := SameText(VendorName, 'Mesa');
        if IsMesa then
          ParseMesaVersion(S, I);
      end;
    end;

  except
    { Just like in TGenericGLVersion: in case of trouble (broken GL_VERSION
      string) ignore the problem. }
  end;

  FVendor := AVendor;
  FRenderer := ARenderer;

  { Actually seen possible values here: 'NVIDIA Corporation'. }
  FVendorNVidia := IsPrefix('NVIDIA', Vendor);

  { Although "ATI Technologies Inc." is usually found,
    according to http://delphi3d.net/hardware/listreports.php
    also just "ATI" is possible. }
  FIsVendorATI := (Vendor = 'ATI Technologies Inc.') or (Vendor = 'ATI');
  FIsFglrx := {$ifdef LINUX} IsVendorATI {$else} false {$endif};

  FBuggyPointSetAttrib := IsMesa and IsPrefix('Mesa DRI Intel', Renderer);

  { Initially, I wanted t set this when fglrx is detected with version 9.x.
    But I really don't see anything clearly indicating fglrx version,
    maybe the last number in GL_VERSION4? But it's 8494 for 9.2 version...
    As a completely blind and probably incorrect guess,
    I assumed that Release >= 8490 indicates 9.x, and used

      IsFglrx and ReleaseExists and (Release >= 8490)

    Later: I'll just do this do every ATI, since Mac OS X GPU has the same
    problem on rendered_texture.x3dv test. }
  FBuggyDrawOddWidth := IsVendorATI;

  FBuggyGenerateMipmap := IsMesa and (not MesaVersionAtLeast(7, 5, 0));
end;

finalization
  FreeAndNil(GLVersion);
  FreeAndNil(GLUVersion);
end.
