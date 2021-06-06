{%MainUnit castlesoundengine.pas}
{
  Copyright 2010-2021 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{$ifdef read_interface}

//type // allow type declaration to continue

  { Sound buffer represents contents of a sound file, like Wav or OggVorbis,
    that (may be) played.

    It can be only allocated by @link(TSoundEngine.LoadBuffer)
    and freed by @link(TSoundEngine.FreeBuffer).
    You should first stop all the sound sources using this buffer before freeing it
    (with OpenAL, not doing it may cause a warning: OpenAL error at alDeleteBuffers).
    @bold(Do not create or free TSoundBuffer instances yourself.) }
  TSoundBuffer = class
  private
    FURL: string;
    FSoundLoading: TSoundLoading;
    References: Cardinal;
    Backend: TSoundBufferBackend;
    BackendIsOpen: Boolean;
    procedure ContextOpen(const ExceptionOnError: boolean);
    procedure ContextClose;
  public
    constructor Create(const SoundEngineBackend: TSoundEngineBackend;
      const SoundLoading: TSoundLoading);
    destructor Destroy; override;

    { Duration of the sound, in seconds. -1 if not loaded yet. }
    function Duration: TFloatTime;

    { Absolute sound file URL.
      Never empty (do not create TSoundBuffer instances for invalid / empty URL,
      like the ones that can be created by TRepoSoundEngine for not defined sounds.) }
    property URL: string read FURL;

    { Data format (bits per sample, stereo or mono) of the loaded sound file.
      Typical applications don't need this value, this is just an information
      about the loaded sound file.
      Undefined if backend is not loaded. }
    function DataFormat: TSoundDataFormat;

    { Frequency (sample rate) of the loaded sound file.
      Typical applications don't need this value, this is just an information
      about the loaded sound file.
      Undefined if backend is not loaded. }
    function Frequency: LongWord;
  end;

{$endif read_interface}

{$ifdef read_implementation}

{ TSoundBuffer --------------------------------------------------------------- }

constructor TSoundBuffer.Create(const SoundEngineBackend: TSoundEngineBackend;
  const SoundLoading: TSoundLoading);
begin
  inherited Create;
  FSoundLoading := SoundLoading;
  Backend := SoundEngineBackend.CreateBuffer(SoundLoading);
end;

function TSoundBuffer.DataFormat: TSoundDataFormat;
begin
  if BackendIsOpen then
    Result := Backend.DataFormat
  else
    Result := Default(TSoundDataFormat);
end;

function TSoundBuffer.Frequency: LongWord;
begin
  if BackendIsOpen then
    Result := Backend.Frequency
  else
    Result := 0;
end;

function TSoundBuffer.Duration: TFloatTime;
begin
  if BackendIsOpen then
    Result := Backend.Duration
  else
    Result := -1;
end;

procedure TSoundBuffer.ContextOpen(const ExceptionOnError: boolean);

  procedure OpenCore;
  begin
    FURL := URL;
    Backend.ContextOpen(URL);
    BackendIsOpen := true;
  end;

begin
  if BackendIsOpen then
    Exit; // do not initialize already-initialized

  if ExceptionOnError then
  begin
    OpenCore;
  end else
  try
    OpenCore;
  except
    on E: Exception do
    begin
      WritelnWarning('Sound', Format('Sound file "%s" cannot be loaded: %s',
        [URIDisplay(URL), E.Message]));
    end;
  end;
end;

procedure TSoundBuffer.ContextClose;
begin
  if BackendIsOpen then
  begin
    Backend.ContextClose;
    BackendIsOpen := false;
  end;
end;

var
  ValidSoundBufferFree: Cardinal;

destructor TSoundBuffer.Destroy;
begin
  if ValidSoundBufferFree = 0 then
    raise EInvalidSoundBufferFree.Create('Do not free TSoundBuffer instance directly, use SoundEngine.FreeBuffer');
  ContextClose;
  FreeAndNil(Backend);
  inherited;
end;

{$endif read_implementation}