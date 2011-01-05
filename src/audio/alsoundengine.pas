{
  Copyright 2010 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ OpenAL sound engine (TALSoundEngine). }
unit ALSoundEngine;

interface

uses SysUtils, Classes, KambiOpenAL, ALSoundAllocator, VectorMath, Cameras,
  KambiTimeUtils, KambiXMLConfig, Math, FGL;

type
  TALDistanceModel = (dmNone,
    dmInverseDistance , dmInverseDistanceClamped,
    dmLinearDistance  , dmLinearDistanceClamped,
    dmExponentDistance, dmExponentDistanceClamped);

const
  DefaultVolume = 1.0;
  DefaultDefaultRolloffFactor = 1.0;
  DefaultDefaultReferenceDistance = 1.0;
  DefaultDefaultMaxDistance = MaxSingle;
  DefaultDistanceModel = dmLinearDistanceClamped;

type
  EALBufferNotLoaded = class(Exception);

  TALBuffersCache = class
    FileName: string; //< Absolute (expanded) file name.
    Buffer: TALbuffer;
    Duration: TKamTime;
    References: Cardinal;
  end;
  TALBuffersCacheList = specialize TFPGObjectList<TALBuffersCache>;

  TALDeviceDescription = class
  private
    FName, FNiceName: string;
  public
    property Name: string read FName;
    property NiceName: string read FNiceName;
  end;
  TALDeviceDescriptionList = specialize TFPGObjectList<TALDeviceDescription>;

  { OpenAL sound engine. Takes care of all the 3D sound stuff,
    wrapping OpenAL is a nice and comfortable interface.

    There should always be only one instance of this class,
    in global SoundEngine variable. See docs at SoundEngine for more details.

    You can explicitly initialize OpenAL context by ALContextOpen,
    and explicitly close it by ALContextClose. If you did not call ALContextOpen
    explicitly (that is, ALInitialized is @false), then the first LoadBuffer
    will automatically do it for you. If you do not call ALContextClose
    explicitly, then at destructor we'll do it automatically. }
  TALSoundEngine = class(TALSoundAllocator)
  private
    FSoundInitializationReport: string;
    FDevice: string;
    FALActive: boolean;
    FALMajorVersion, FALMinorVersion: Integer;
    FEFXSupported: boolean;
    FVolume: Single;
    ALDevice: PALCdevice;
    ALContext: PALCcontext;
    FEnable: boolean;
    FALInitialized: boolean;
    FDefaultRolloffFactor: Single;
    FDefaultReferenceDistance: Single;
    FDefaultMaxDistance: Single;
    FDistanceModel: TALDistanceModel;
    BuffersCache: TALBuffersCacheList;
    FDevices: TALDeviceDescriptionList;

    { We record listener state regardless of ALActive. This way at the ALContextOpen
      call we can immediately set the good listener parameters. }
    ListenerPosition: TVector3Single;
    ListenerOrientation: TALTwoVectors3f;

    EnableSaveToConfig: boolean;

    { Check ALC errors. Requires valid ALDevice. }
    procedure CheckALC(const situation: string);

    procedure SetVolume(const Value: Single);
    procedure SetDistanceModel(const Value: TALDistanceModel);
    { Call alDistanceModel with parameter derived from current DistanceModel.
      Use only when ALActive. }
    procedure UpdateDistanceModel;
    procedure SetDevice(const Value: string);
    procedure SetEnable(const Value: boolean);
  public
    constructor Create;
    destructor Destroy; override;

    { Initialize OpenAL library, and output device and context.
      Sets ALInitialized, ALActive, SoundInitializationReport, EFXSupported,
      ALMajorVersion, ALMinorVersion.
      You can set @link(Device) before calling this.

      Note that we continue (without any exception) if the initialization
      failed for any reason (maybe OpenAL library is not available,
      or no sound output device is available).
      You can check things like ALActive and SoundInitializationReport,
      but generally this class
      will hide from you the fact that sound is not initialized. }
    procedure ALContextOpen; override;

    { Release OpenAL context and resources.

      ALInitialized and ALActive are set to @false. It's allowed and harmless
      to cal this when one of them is already @false. }
    procedure ALContextClose; override;

    { Do we have active OpenAL context. This is @true when you successfully
      called ALContextOpen (and you didn't call ALContextClose yet).
      This also implies that OpenAL library is loaded, that is ALInited = @true. }
    property ALActive: boolean read FALActive;

    { Did we attempt to initialize OpenAL context. This indicates that ALContextOpen
      was called, and not closed with ALContextClose yet. Contrary to ALActive,
      this @italic(doesn't care if ALContextOpen was a success). }
    property ALInitialized: boolean read FALInitialized;

    { Are OpenAL effects (EFX) extensions supported.
      Meaningful only when ALActive, that is it's initialized by ALContextOpen. }
    property EFXSupported: boolean read FEFXSupported;

    property SoundInitializationReport: string read FSoundInitializationReport;

    { Wrapper for alcGetString. }
    function GetContextString(Enum: TALCenum): string;

    { If ALActive, then will append some info about current OpenAL used. }
    procedure AppendALInformation(S: TStrings);
    function ALInformation: string;

    { Load a sound file into OpenAL buffer.

      Result is 0 only if we don't have a valid OpenAL context.
      Note that this method will automatically call ALContextOpen if it wasn't
      called yet. So result = zero means that ALContextOpen was called, but for some
      reason failed.

      The buffer should be released by FreeBuffer later when it's not needed.
      Although we will take care to always free remaining buffers
      before closing OpenAL context anyway. (And OpenAL would also free
      the buffer anyway at closing, although some OpenAL versions
      could write a warning about this.)

      We have a cache of sound files here. An absolute (expanded) filename
      will be recorded as being loaded to given buffer. Loading the same
      filename second time returns the same OpenAL buffer. The buffer
      is released only once you call FreeBuffer as many times as you called
      LoadBuffer for it.
      @groupBegin }
    function LoadBuffer(const FileName: string; out Duration: TKamTime): TALBuffer;
    function LoadBuffer(const FileName: string): TALBuffer;
    { @groupEnd }

    { Free a sound file buffer. Ignored when buffer is zero.
      Buffer is always set to zero after this.

      @raises(EALBufferNotLoaded When invalid (not zero,
        and not returned by LoadBuffer) buffer identifier is given.) }
    procedure FreeBuffer(var Buffer: TALBuffer);

    { Play a sound from given buffer.

      We use a smart OpenAL sound allocator, so the sound will be actually
      played only if resources allow. Use higher Importance to indicate
      sounds that are more important to play.

      We set the sound properties and start playing it.

      Both spatialized (3D) and not sounds are possible.
      When Spatial = @false, then Position is ignored
      (you can pass anything, like ZeroVector3Single).

      @returns(The allocated sound as TALSound.

        Returns @nil when there were no resources to play another sound
        (and it wasn't important enough to override another sound).
        Always returns @nil when ALBuffer is zero (indicating that buffer
        was not loaded).

        In simple cases you can just ignore the result of this method.
        In advanced cases, you can use it to observe and update the sound
        later.) }
    function PlaySound(const ALBuffer: TALBuffer;
      const Spatial, Looping: boolean; const Importance: Cardinal;
      const Gain, MinGain, MaxGain: Single;
      const Position: TVector3Single;
      const Pitch: Single = 1): TALSound;
    function PlaySound(const ALBuffer: TALBuffer;
      const Spatial, Looping: boolean; const Importance: Cardinal;
      const Gain, MinGain, MaxGain: Single;
      const Position: TVector3Single;
      const Pitch: Single;
      const ReferenceDistance: Single;
      const MaxDistance: Single): TALSound;

    { Parse parameters in @link(Parameters) and interprets and removes
      recognized options. Internally it uses ParseParameters with
      ParseOnlyKnownLongOptions = @true. Recognized options:

      @definitionList(
        @itemLabel @--audio-device DEVICE-NAME
        @item Set @link(Device) variable to given argument.

        @itemLabel @--print-audio-devices
        @item(
          Use ALC_ENUMERATION_EXT to print all available OpenAL audio devices
          to stdout (uses InfoWrite, so on Windows when program is GUI, it will
          make a dialog box).
          If this extension is not present, write something
          like "Enumerating audio devices not supported by your OpenAL".

          Then do ProgramBreak.)

        @itemLabel @--no-sound
        @item Disable any sound (sets @link(Enable) to @false).
      )

      More user-oriented documentation for the above options is here:
      [http://vrmlengine.sourceforge.net/openal_notes.php#section_options] }
    procedure ParseParameters;

    { Help string for options parsed by ParseParameters.

      Formatting is consistent with Kambi standards
      (see file @code(../base/README.kambi_command_line_params)).

      If PrintCurrentDeviceAsDefault then it will also say (near
      the help for option @--audio-device) that "defauls device is ..."
      and will give here current value of Device.
      This is usually useful, e.g. if you don't intend to modify directly
      Device (only indirectly via ParseParameters)
      then you should give here true. }
    function ParseParametersHelp(PrintCurrentDeviceAsDefault: boolean): string;

    { Set OpenAL listener position and orientation.
      @groupBegin }
    procedure UpdateListener(Camera: TCamera);
    procedure UpdateListener(const Position, Direction, Up: TVector3Single);
    { @groupEnd }

    { List of available OpenAL sound devices. Read-only.

      Use @code(Devices[].Name) as @link(Device) values.
      On some OpenAL implementations, some other @link(Device) values may
      be possible, e.g. old Loki implementation allowed some hints
      to be encoded in Lisp-like language inside the @link(Device) string. }
    property Devices: TALDeviceDescriptionList read FDevices;

    function DeviceNiceName: string;

    procedure LoadFromConfig(ConfigFile: TKamXMLConfig); override;
    procedure SaveToConfig(ConfigFile: TKamXMLConfig); override;
  published
    { Sound volume, affects all OpenAL sounds (effects and music).
      This must always be within 0..1 range.
      0.0 means that there are no effects (this case should be optimized). }
    property Volume: Single read FVolume write SetVolume
      default DefaultVolume;

    { Sound output device, used when initializing OpenAL context.

      You can change it even when OpenAL is already initialized.
      Then we'll close the old device (ALContextClose),
      change @link(Device) value, and initialize context again (ALContextOpen).
      Note that you will need to reload your buffers and sources again. }
    property Device: string read FDevice write SetDevice;

    { Enable sound.

      If @false, then ALContextOpen will not initialize any OpenAL device.
      This is useful if you simply want to disable any sound output
      (or OpenAL usage), even when OpenAL library is available.

      If the OpenAL context is already initialized when setting this,
      we will eventually close it. (More precisely, we will
      do ALContextClose and then ALContextOpen again. This behaves correctly.) }
    property Enable: boolean read FEnable write SetEnable default true;

    { How the sound is attenuated with the distance.
      These are used only for spatialized sounds created with PlaySound.
      The DefaultReferenceDistance and DefaultMaxDistance values
      are used only if you don't supply explicit values to PlaySound.

      The exact interpretation of these depends on current
      DistanceModel. See OpenAL specification for exact equations.
      In short:

      @unorderedList(
        @item(Smaller Rolloff Factor makes the attenuation weaker.
          In particular 0 turns off attenuation by distance.
          Default is 1.)
        @item(Reference Distance is the distance at which exactly sound
          gain is heard. Default is 1.)
        @item(Max Distance interpretation depends on the model.
          For "inverse clamped model", the gain is no longer scaled down
          after reaching this distance. For linear models, the gain
          reaches zero at this distance. Default is maximum float
          (I don't know the interpretation of this for linear model).)
      )

      Our default values follow OpenAL default values.
      @groupBegin }
    property DefaultRolloffFactor: Single
      read FDefaultRolloffFactor write FDefaultRolloffFactor default DefaultDefaultRolloffFactor;
    property DefaultReferenceDistance: Single
      read FDefaultReferenceDistance write FDefaultReferenceDistance default DefaultDefaultReferenceDistance;
    property DefaultMaxDistance: Single
      read FDefaultMaxDistance write FDefaultMaxDistance default DefaultDefaultMaxDistance;
    { @groupEnd }

    { How the sources are spatialized. For precise meaning, see OpenAL
      specification of alDistanceModel.

      Note that some models are actually available only since OpenAL 1.1
      version. Older OpenAL versions may (but don't have to) support them
      through extensions. We will internally do everything possible to
      request given model, but eventually may fallback on some other model.
      This probably will not be a problem in practice, as all modern OS
      versions (Linux distros, Windows OpenAL installers etc.) include OpenAL
      1.1.

      The default distance model, DefaultDistanceModel, is the linear model
      most conforming to VRML/X3D sound requirements. You can change it
      if you want (for example, OpenAL default is dmInverseDistanceClamped). }
    property DistanceModel: TALDistanceModel
      read FDistanceModel write SetDistanceModel default DefaultDistanceModel;
  end;

function GetSoundEngine: TALSoundEngine;
procedure SetSoundEngine(const Value: TALSoundEngine);

{ The global instance of TALSoundEngine.

  You can create and assign it explicitly. Or you can let the first access
  to SoundEngine automatically create it (on demand,
  e.g. when you open VRML/X3D file with a Sound node).
  If you want to assign it explicitly, be sure to do it before
  anything accesses the SoundEngine (like scene manager).
  Assigning explicitly may be useful when you want
  to assign a descendant of TALSoundEngine class.

  You can also destroy it explicitly (remember to set it to nil afterwards,
  usually use FreeAndNil). Or you can let this unit's finalization do it
  automatically. }
property SoundEngine: TALSoundEngine read GetSoundEngine write SetSoundEngine;

implementation

uses KambiUtils, KambiStringUtils, ALUtils, KambiLog,
  SoundFile, VorbisFile, EFX, ParseParametersUnit, StrUtils;

type
  { For alcGetError errors (ALC_xxx constants). }
  EALCError = class(EOpenALError)
  private
    FALCErrorNum: TALenum;
  public
    property ALCErrorNum: TALenum read FALCErrorNum;
    constructor Create(AALCErrorNum: TALenum; const AMessage: string);
  end;

constructor EALCError.Create(AALCErrorNum: TALenum; const AMessage: string);
begin
  FALCErrorNum := AALCErrorNum;
  inherited Create(AMessage);
end;

{ Check and use OpenAL enumeration extension.
  If OpenAL supports ALC_ENUMERATION_EXT, then we return @true
  and pDeviceList is initialized to the null-separated list of
  possible OpenAL devices. }
function EnumerationExtPresent(out pDeviceList: PChar): boolean;
begin
  Result := alcIsExtensionPresent(nil, 'ALC_ENUMERATION_EXT');
  if Result then
  begin
    pDeviceList := alcGetString(nil, ALC_DEVICE_SPECIFIER);
    Assert(pDeviceList <> nil);
  end;
end;

function EnumerationExtPresent: boolean;
begin
  Result := alcIsExtensionPresent(nil, 'ALC_ENUMERATION_EXT');
end;

{ TALSoundEngine ------------------------------------------------------------- }

constructor TALSoundEngine.Create;

  { Find available OpenAL devices, add them to FDevices.

    It tries to use ALC_ENUMERATION_EXT extension, available on all modern
    OpenAL implementations. If it fails, and we're dealing with
    OpenAL "sample implementation" (older OpenAL Unix implementation)
    then we return a hardcoded list of devices known to be supported
    by this implementation.
    This makes it working sensibly under all OpenAL implementations in use
    today.

    Also for every OpenAL implementation, we add an implicit
    OpenAL default device named '' (empty string). }
  procedure UpdateDevices;

    procedure Add(const AName, ANiceName: string);
    var
      D: TALDeviceDescription;
    begin
      D := TALDeviceDescription.Create;
      D.FName := AName;
      D.FNiceName := ANiceName;
      FDevices.Add(D);
    end;

    function SampleImpALCDeviceName(const ShortDeviceName: string): string;
    begin
      Result := '''(( devices ''(' + ShortDeviceName + ') ))';
    end;

  var
    pDeviceList: PChar;
  begin
    Add('', 'Default OpenAL device');

    if ALInited and EnumerationExtPresent(pDeviceList) then
    begin
      { parse pDeviceList }
      while pDeviceList^ <> #0 do
      begin
        { automatic conversion PChar -> AnsiString below }
        Add(pDeviceList, pDeviceList);

        { advance position of pDeviceList }
        pDeviceList := StrEnd(pDeviceList);
        Inc(pDeviceList);
      end;
    end else
    if ALInited and OpenALSampleImplementation then
    begin
      Add(SampleImpALCDeviceName('native'), 'Operating system native');
      Add(SampleImpALCDeviceName('sdl'), 'SDL (Simple DirectMedia Layer)');

      { aRts device is too unstable on my Linux:

        When trying to initialize <tt>arts</tt> backend
        I can bring the OpenAL library (and, consequently, whole program
        using it) to crash with message <i>can't create mcop
        directory</i>. Right after running konqueror, I get also
        crash with message <i>*** glibc detected *** double free or corruption (out):
        0x08538d88 ***</i>.

        This is so unstable, that I think that I do a service
        for users by *not* listing aRts in available OpenAL
        devices. It's listed on [http://vrmlengine.sourceforge.net/openal_notes.php]
        and that's enough.

      Add(SampleImpALCDeviceName('arts'), 'aRts (analog Real time synthesizer)');
      }

      Add(SampleImpALCDeviceName('esd'), 'Esound (Enlightened Sound Daemon)');
      Add(SampleImpALCDeviceName('alsa'), 'ALSA (Advanced Linux Sound Architecture)');
      Add(SampleImpALCDeviceName('waveout'), 'WAVE file output');
      Add(SampleImpALCDeviceName('null'), 'Null device (no output)');
    end;
  end;

begin
  inherited;
  FVolume := DefaultVolume;
  FDefaultRolloffFactor := DefaultDefaultRolloffFactor;
  FDefaultReferenceDistance := DefaultDefaultReferenceDistance;
  FDefaultMaxDistance := DefaultDefaultMaxDistance;
  FDistanceModel := DefaultDistanceModel;
  FEnable := true;
  EnableSaveToConfig := true;
  BuffersCache := TALBuffersCacheList.Create;

  FDevices := TALDeviceDescriptionList.Create;
  UpdateDevices;

  { Default OpenAL listener attributes }
  ListenerPosition := ZeroVector3Single;
  ListenerOrientation[0] := Vector3Single(0, 0, -1);
  ListenerOrientation[1] := Vector3Single(0, 1, 0);
end;

destructor TALSoundEngine.Destroy;
begin
  ALContextClose;
  FreeAndNil(BuffersCache);
  FreeAndNil(FDevices);
  inherited;
end;

procedure TALSoundEngine.CheckALC(const situation: string);
var
  err: TALenum;
  alcErrDescription: PChar;
  alcErrDescriptionStr: string;
begin
  err := alcGetError(ALDevice);
  if err <> ALC_NO_ERROR then
  begin
    { moznaby tu uproscic zapis eliminujac zmienne alcErrDescription i alcErrDescriptionStr
      i zamiast alcErrDescriptionStr uzyc po prostu alcGetString(ALDevice, err).
      Jedynym powodem dla ktorego jednak wprowadzam tu ta mala komplikacje jest fakt
      ze sytuacja ze alcGetError zwroci cos niespodziewanego (bledny kod bledu) niestety
      zdarza sie (implementacja Creative pod Windows nie jest doskonala...).
      W zwiazku z tym chcemy sie nia zajac. }
    alcErrDescription := alcGetString(ALDevice, err);
    if alcErrDescription = nil then
     alcErrDescriptionStr := Format('(alc does not recognize this error number : %d)', [err]) else
     alcErrDescriptionStr := alcErrDescription;

    raise EALCError.Create(err,
      'OpenAL error ALC_xxx at '+situation+' : '+alcErrDescriptionStr);
  end;
end;

function TALSoundEngine.GetContextString(Enum: TALCenum): string;
begin
  result := alcGetString(ALDevice, enum);
  try
    CheckALC('alcGetString');
    { Check also normal al error (alGetError instead
      of alcGetError). Seems that when Darwin (Mac OS X) Apple's OpenAL
      implementation fails to return some alcGetString
      it reports this by setting AL error (instead of ALC one)
      to "invalid value". Although (after fixes to detect OpenALSampleImplementation
      at runtime and change constants values) this shouldn't happen anymore
      it you pass normal consts to this function. }
    CheckAL('alcGetString');
  except
    on E: EALCError do result := '('+E.Message+')';
    on E: EALError do result := '('+E.Message+')';
  end;
end;

procedure TALSoundEngine.ALContextOpen;

  procedure ParseVersion(const Version: string; out Major, Minor: Integer);
  var
    DotP, SpaceP: Integer;
  begin
    { version unknown }
    Major := 0;
    Minor := 0;

    DotP := Pos('.', Version);
    if DotP <> 0 then
    try
      Major := StrToInt(Trim(Copy(Version, 1, DotP - 1)));
      SpaceP := PosEx(' ', Version, DotP + 1);
      if SpaceP <> 0 then
        Minor := StrToInt(Trim(Copy(Version, DotP + 1, SpaceP - DotP))) else
        Minor := StrToInt(Trim(SEnding(Version, DotP + 1)));
    except
      on EConvertError do
      begin
        Major := 0;
        Minor := 0;
      end;
    end;
  end;

  { Try to initialize OpenAL.
    Sets ALActive, EFXSupported.
    If not ALActive, then ALActivationErrorMessage contains error description. }
  procedure BeginAL(out ALActivationErrorMessage: string);
  begin
    { We don't do alcProcessContext/alcSuspendContext, no need
      (spec says that context is initially in processing state). }

    try
      FALActive := false;
      FEFXSupported := false;
      ALActivationErrorMessage := '';
      FALMajorVersion := 0;
      FALMinorVersion := 0;

      CheckALInited;

      ALDevice := alcOpenDevice(PCharOrNil(Device));
      if (ALDevice = nil) then
        raise EOpenALError.CreateFmt(
          'OpenAL''s audio device "%s" is not available', [Device]);

      ALContext := alcCreateContext(ALDevice, nil);
      CheckALC('initing OpenAL (alcCreateContext)');

      alcMakeContextCurrent(ALContext);
      CheckALC('initing OpenAL (alcMakeContextCurrent)');

      FALActive := true;
      FEFXSupported := Load_EFX(ALDevice);
      ParseVersion(alGetString(AL_VERSION), FALMajorVersion, FALMinorVersion);
    except
      on E: EOpenALError do
        ALActivationErrorMessage := E.Message;
    end;
  end;

var
  ALActivationErrorMessage: string;
begin
  Assert(not ALActive, 'OpenAL context is already active');
  Assert(not ALInitialized, 'OpenAL context initialization was already attempted');

  if not Enable then
    FSoundInitializationReport :=
      'Sound disabled (for example by the --no-sound command-line option)' else
  begin
    BeginAL(ALActivationErrorMessage);
    if not ALActive then
      FSoundInitializationReport :=
        'OpenAL initialization failed : ' +ALActivationErrorMessage +nl+
        'SOUND IS DISABLED' else
    begin
      FSoundInitializationReport :=
        'OpenAL initialized, sound enabled';

      try
        alListenerf(AL_GAIN, Volume);
        UpdateDistanceModel;
        inherited; { initialize sound allocator }
        CheckAL('initializing sounds (ALContextOpen)');
      except
        ALContextClose;
        raise;
      end;
    end;
  end;

  FALInitialized := true;
  if Log then
    WritelnLogMultiline('Sound initialization',
      SoundInitializationReport + nl + ALInformation);
end;

procedure TALSoundEngine.ALContextClose;

  procedure EndAL;
  begin
    FALActive := false;
    FEFXSupported := false;

    { CheckALC first, in case some error is "hanging" not caught yet. }
    CheckALC('right before closing OpenAL context');

    if ALContext <> nil then
    begin
      (* The OpenAL specification says

         "The correct way to destroy a context is to first release
         it using alcMakeCurrent with a NULL context. Applications
         should not attempt to destroy a current context – doing so
         will not work and will result in an ALC_INVALID_OPERATION error."

         (See [http://openal.org/openal_webstf/specs/oal11spec_html/oal11spec6.html])

         However, sample implementation (used on most Unixes,
         before OpenAL soft came) can hang
         on alcMakeContextCurrent(nil) call. Actually, it doesn't hang,
         but it stops for a *very* long time (even a couple of minutes).
         This is a known problem, see
         [http://opensource.creative.com/pipermail/openal-devel/2005-March/002823.html]
         and
         [http://lists.berlios.de/pipermail/warzone-dev/2005-August/000441.html].

         Tremulous code workarounds it like

           if( Q_stricmp((const char* )qalGetString( AL_VENDOR ), "J. Valenzuela" ) ) {
                   qalcMakeContextCurrent( NULL );
           }

         ... and this seems a good idea, we do it also here.
         Initially I wanted to do $ifdef UNIX, but checking for Sample implementation
         with alGetString(AL_VENDOR) is more elegant (i.e. affecting more precisely
         the problematic OpenAL implementations, e.g. allowing us to work
         correctly with OpenAL soft too). *)

      if not OpenALSampleImplementation then
        alcMakeContextCurrent(nil);

      alcDestroyContext(ALContext);
      ALContext := nil;
      CheckALC('closing OpenAL context');
    end;

    if ALDevice <> nil then
    begin
      alcCloseDevice(ALDevice);
      { w/g specyfikacji OpenAL generuje teraz error ALC_INVALID_DEVICE jesli
        device bylo nieprawidlowe; ale niby jak mam sprawdzic ten blad ?
        Przeciez zeby sprawdzic alcGetError potrzebuje miec valid device w reku,
        a po wywolaniu alcCloseDevice(device) device jest invalid (bez wzgledu
        na czy przed wywolaniem alcCloseDevice bylo valid) }
      ALDevice := nil;
    end;
  end;

var
  I: Integer;
begin
  if ALInitialized then
  begin
    FALInitialized := false;
    if ALActive then
    begin
      { release sound allocator first. This also stops all the sources,
        which is required before we try to release their buffers. }
      inherited;

      for I := 0 to BuffersCache.Count - 1 do
        alFreeBuffer(BuffersCache[I].Buffer);
      BuffersCache.Count := 0;

      EndAL;
    end;
  end;
end;

procedure TALSoundEngine.AppendALInformation(S: TStrings);
begin
  if ALActive then
  begin
    S.Append('');
    S.Append('Version : ' + alGetString(AL_VERSION));
    S.Append(Format('Version Parsed : major: %d, minor: %d', [FALMajorVersion, FALMinorVersion]));
    S.Append('Renderer : ' + alGetString(AL_RENDERER));
    S.Append('Vendor : ' + alGetString(AL_VENDOR));
    S.Append('Extensions : ' + alGetString(AL_EXTENSIONS));
    S.Append('');
    S.Append(Format('Allocated OpenAL sources: %d (min %d, max %d)',
      [ AllocatedSources.Count,
        MinAllocatedSources,
        MaxAllocatedSources ]));
    S.Append('');
    S.Append('OggVorbis handling method: ' + TSoundOggVorbis.VorbisMethod);
    S.Append('vorbisfile library available: ' + BoolToStr[VorbisFileInited]);
  end;
end;

function TALSoundEngine.ALInformation: string;
var
  S: TStringList;
begin
  S := TStringList.Create;
  try
    AppendALInformation(S);
    Result := S.Text;
  finally S.Free end;
end;

function TALSoundEngine.PlaySound(const ALBuffer: TALBuffer;
  const Spatial, Looping: boolean; const Importance: Cardinal;
  const Gain, MinGain, MaxGain: Single;
  const Position: TVector3Single;
  const Pitch, ReferenceDistance, MaxDistance: Single): TALSound;

const
  { For now, just always use CheckBufferLoaded. It doesn't seem to cause
    any slowdown for normal sound playing. }
  CheckBufferLoaded = true;
begin
  Result := nil;

  if ALActive and (ALBuffer <> 0) then
  begin
    Result := AllocateSound(Importance);
    if Result <> nil then
    begin
      Result.Buffer := ALBuffer;
      Result.Looping := Looping;
      Result.Gain := Gain;
      Result.MinGain := MinGain;
      Result.MaxGain := MaxGain;
      Result.Pitch := Pitch;

      if Spatial then
      begin
        { Set default attenuation by distance. }
        Result.RolloffFactor := DefaultRolloffFactor;
        Result.ReferenceDistance := ReferenceDistance;
        Result.MaxDistance := MaxDistance;

        Result.Relative := false;
        Result.Position := Position;
      end else
      begin
        { No attenuation by distance. }
        Result.RolloffFactor := 0;
        { ReferenceDistance, MaxDistance don't matter in this case }

        { Although AL_ROLLOFF_FACTOR := 0 turns off
          attenuation by distance, we still have to turn off
          any changes from player's orientation (so that the sound
          is not played on left or right side, but normally).
          That's why setting source position exactly on the player
          is needed here. }
        Result.Relative := true;
        Result.Position := ZeroVector3Single;
      end;

      if CheckBufferLoaded then
      begin
        { This is a workaround needed on Apple OpenAL implementation
          (although I think that at some time I experienced similar
          problems (that would be cured by this workaround) on Linux
          (Loki OpenAL implementation)).

          The problem: music on some
          levels doesn't play. This happens seemingly random: sometimes
          when you load a level music starts playing, sometimes it's
          silent. Then when you go to another level, then go back to the
          same level, music plays.

          Investigation: I found that sometimes changing the buffer
          of the sound doesn't work immediately. Simple
            Writeln(SoundInfos.Items[PlayedSound].Buffer, ' ',
              alGetSource1ui(FAllocatedSource.ALSource, AL_BUFFER));
          right after alCommonSourceSetup shows this (may output
          two different values). Then if you wait a little, OpenAL
          reports correct buffer. This probably means that OpenAL
          internally finishes some tasks related to loading buffer
          into source. Whatever it is, it seems that it doesn't
          occur (or rather, is not noticeable) on normal game sounds
          that are short --- but it's noticeable delay with larger
          sounds, like typical music.

          So the natural workaround below follows. For OpenAL implementations
          that immediately load the buffer, this will not cause any delay. }

        { We have to do CheckAL first, to catch evantual errors.
          Otherwise the loop would hang. }
        CheckAL('PlaySound');
        while ALBuffer <> alGetSource1ui(Result.ALSource, AL_BUFFER) do
          Delay(10);
      end;

      alSourcePlay(Result.ALSource);
    end;
  end;
end;

function TALSoundEngine.PlaySound(const ALBuffer: TALBuffer;
  const Spatial, Looping: boolean; const Importance: Cardinal;
  const Gain, MinGain, MaxGain: Single;
  const Position: TVector3Single;
  const Pitch: Single): TALSound;
begin
  Result := PlaySound(ALBuffer, Spatial, Looping, Importance,
    Gain, MinGain, MaxGain, Position, Pitch,
    { use default values for next parameters }
    DefaultReferenceDistance, DefaultMaxDistance);
end;

function TALSoundEngine.LoadBuffer(const FileName: string;
  out Duration: TKamTime): TALBuffer;
var
  I: Integer;
  Cache: TALBuffersCache;
  FullFileName: string;
begin
  if not ALInitialized then ALContextOpen;

  if not ALActive then Exit(0);

  FullFileName := ExpandFileName(FileName);

  { try to load from cache (Result and Duration) }
  for I := 0 to BuffersCache.Count - 1 do
    if BuffersCache[I].FileName = FullFileName then
    begin
      Inc(BuffersCache[I].References);
      if Log then
        WritelnLog('Sound', Format('Loaded "%s" from cache, now has %d references',
          [FullFileName, BuffersCache[I].References]));
      Duration := BuffersCache[I].Duration;
      Exit(BuffersCache[I].Buffer);
    end;

  { actually load, and add to cache }
  alCreateBuffers(1, @Result);
  try
    TALSoundFile.alBufferDataFromFile(Result, FileName, Duration);
  except alDeleteBuffers(1, @Result); raise end;

  Cache := TALBuffersCache.Create;
  Cache.FileName := FullFileName;
  Cache.Buffer := Result;
  Cache.Duration := Duration;
  Cache.References := 1;
  BuffersCache.Add(Cache);
end;

function TALSoundEngine.LoadBuffer(const FileName: string): TALBuffer;
var
  Dummy: TKamTime;
begin
  Result := LoadBuffer(FileName, Dummy);
end;

procedure TALSoundEngine.FreeBuffer(var Buffer: TALBuffer);
var
  I: Integer;
begin
  if Buffer = 0 then Exit;

  for I := 0 to BuffersCache.Count - 1 do
    if BuffersCache[I].Buffer = Buffer then
    begin
      Buffer := 0;
      Dec(BuffersCache[I].References);
      if BuffersCache[I].References = 0 then
      begin
        alFreeBuffer(BuffersCache[I].Buffer);
        BuffersCache.Delete(I);
      end;
      Exit;
    end;

  raise EALBufferNotLoaded.CreateFmt('OpenAL buffer %d not loaded', [Buffer]);
end;

procedure TALSoundEngine.SetVolume(const Value: Single);
begin
  if Value <> FVolume then
  begin
    FVolume := Value;
    if ALActive then
      alListenerf(AL_GAIN, Volume);
  end;
end;

procedure TALSoundEngine.UpdateDistanceModel;

  function AtLeast(AMajor, AMinor: Integer): boolean;
  begin
    Result :=
        (AMajor < FALMajorVersion) or
      ( (AMajor = FALMajorVersion) and (AMinor <= FALMinorVersion) );
  end;

const
  ALDistanceModelConsts: array [TALDistanceModel] of TALenum =
  ( AL_NONE,
    AL_INVERSE_DISTANCE, AL_INVERSE_DISTANCE_CLAMPED,
    AL_LINEAR_DISTANCE, AL_LINEAR_DISTANCE_CLAMPED,
    AL_EXPONENT_DISTANCE, AL_EXPONENT_DISTANCE_CLAMPED );
var
  Is11: boolean;
begin
  Is11 := AtLeast(1, 1);
  if (not Is11) and (DistanceModel in [dmLinearDistance, dmExponentDistance]) then
    alDistanceModel(AL_INVERSE_DISTANCE) else
  if (not Is11) and (DistanceModel in [dmLinearDistanceClamped, dmExponentDistanceClamped]) then
    alDistanceModel(AL_INVERSE_DISTANCE_CLAMPED) else
    alDistanceModel(ALDistanceModelConsts[DistanceModel]);
end;

procedure TALSoundEngine.SetDistanceModel(const Value: TALDistanceModel);
begin
  if Value <> FDistanceModel then
  begin
    FDistanceModel := Value;
    if ALActive then UpdateDistanceModel;
  end;
end;

procedure TALSoundEngine.SetDevice(const Value: string);
begin
  if Value <> FDevice then
  begin
    if ALInitialized then
    begin
      ALContextClose;
      OpenALRestart;
      FDevice := Value;
      ALContextOpen;
    end else
      FDevice := Value;
  end;
end;

procedure TALSoundEngine.SetEnable(const Value: boolean);
begin
  if Value <> FEnable then
  begin
    if ALInitialized then
    begin
      ALContextClose;
      FEnable := Value;
      ALContextOpen;
    end else
      FEnable := Value;
    EnableSaveToConfig := true; // caller will eventually change it to false
  end;
end;

procedure OptionProc(OptionNum: Integer; HasArgument: boolean;
  const Argument: string; const SeparateArgs: TSeparateArgs; Data: Pointer);
var
  Message, DefaultDeviceName: string;
  i: Integer;
  Engine: TALSoundEngine;
begin
  Engine := TALSoundEngine(Data);
  case OptionNum of
    0: Engine.Device := Argument;
    1: begin
         if not ALInited then
           Message := 'OpenAL is not available - cannot print available audio devices' else
         if not EnumerationExtPresent then
           Message := 'Your OpenAL implementation does not support getting the list '+
             'of available audio devices (ALC_ENUMERATION_EXT extension not present).' else
         begin
           DefaultDeviceName := alcGetString(nil, ALC_DEFAULT_DEVICE_SPECIFIER);

           Message := Format('%d available audio devices:', [Engine.Devices.Count]) + nl;
           for i := 0 to Engine.Devices.Count - 1 do
           begin
             Message += '  ' + Engine.Devices[i].NiceName;
             if Engine.Devices[i].Name <> Engine.Devices[i].NiceName then
               Message += ' (Real OpenAL name: "' + Engine.Devices[i].Name + '")';
             if Engine.Devices[i].Name = DefaultDeviceName then
               Message += ' (Equivalent to default device)';
             Message += nl;
           end;
         end;

         InfoWrite(Message);

         ProgramBreak;
       end;
    2: begin
         Engine.Enable := false;
         Engine.EnableSaveToConfig := false;
       end;
    else raise EInternalError.Create('OpenALOptionProc');
  end;
end;

procedure TALSoundEngine.ParseParameters;
const
  OpenALOptions: array [0..2] of TOption =
  ( (Short: #0; Long: 'audio-device'; Argument: oaRequired),
    (Short: #0; Long: 'print-audio-devices'; Argument: oaNone),
    (Short: #0; Long: 'no-sound'; Argument: oaNone)
  );
begin
  ParseParametersUnit.ParseParameters(OpenALOptions, @OptionProc, Self, true);
end;

function TALSoundEngine.ParseParametersHelp(PrintCurrentDeviceAsDefault: boolean): string;
begin
  Result :=
    '  --audio-device DEVICE-NAME' +nl+
    '                        Choose specific OpenAL audio device';
  if PrintCurrentDeviceAsDefault then
    Result += nl+
      '                        Default audio device for this OS is:' +nl+
      '                        '+ Iff(Device = '', '(OpenAL default device)', Device);
  Result += nl+
    '  --print-audio-devices' +nl+
    '                        Print available audio devices' +nl+
    '  --no-sound            Turn off sound';
end;

procedure TALSoundEngine.UpdateListener(Camera: TCamera);
begin
  Camera.GetView(ListenerPosition, ListenerOrientation[0], ListenerOrientation[1]);
  if ALActive then
  begin
    alListenerVector3f(AL_POSITION, ListenerPosition);
    alListenerfv(AL_ORIENTATION, @ListenerOrientation);
  end;
end;

procedure TALSoundEngine.UpdateListener(const Position, Direction, Up: TVector3Single);
begin
  ListenerPosition := Position;
  ListenerOrientation[0] := Direction;
  ListenerOrientation[1] := Up;
  if ALActive then
  begin
    alListenerVector3f(AL_POSITION, Position);
    alListenerOrientation(Direction, Up);
  end;
end;

function TALSoundEngine.DeviceNiceName: string;
var
  I: Integer;
begin
  for I := 0 to FDevices.Count - 1 do
    if FDevices[I].Name = Device then
      Exit(FDevices[I].NiceName);

  Result := 'Some OpenAL device'; // some default
end;

const
  DefaultAudioDevice = '';
  DefaultAudioEnable = true;

procedure TALSoundEngine.LoadFromConfig(ConfigFile: TKamXMLConfig);
begin
  inherited;
  Device := ConfigFile.GetValue('sound/device', DefaultAudioDevice);
  Enable := ConfigFile.GetValue('sound/enable', DefaultAudioEnable);
end;

procedure TALSoundEngine.SaveToConfig(ConfigFile: TKamXMLConfig);
begin
  inherited;
  ConfigFile.SetDeleteValue('sound/device', Device, DefaultAudioDevice);
  if EnableSaveToConfig then
    ConfigFile.SetDeleteValue('sound/enable', Enable, DefaultAudioEnable);
end;

{ globals -------------------------------------------------------------------- }

var
  FSoundEngine: TALSoundEngine;

function GetSoundEngine: TALSoundEngine;
begin
  if FSoundEngine = nil then
    FSoundEngine := TALSoundEngine.Create;
  Result := FSoundEngine;
end;

procedure SetSoundEngine(const Value: TALSoundEngine);
begin
  Assert(FSoundEngine = nil, 'SoundEngine is already assigned');
  FSoundEngine := Value;
end;

finalization
  FreeAndNil(FSoundEngine);
end.
