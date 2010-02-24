{
  Copyright 2008-2010 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}
unit Videos;

interface

uses SysUtils, Images, ImagesCache;

type
  EInvalidFadeFrames = class(Exception);

  { Video.

    It can load movie from a sequence of image files.
    With the help of ffmpeg, it can also load any normal movie file format,
    like avi (compressed by anything ffmpeg can handle), OggTheora and
    many others. ffmpeg really handles probably everything you will
    ever want.

    Video is stored simply as a sequence of loaded images in memory.
    This is not good for a real movies, so don't even try to open
    any real, 2 hour, full dvd resolution movie --- loading will
    take hours and you will clog your memory. This class is @italic(not)
    supposed to be used in a real movie player.

    However, this simple storage is perfect to load a short movie
    for some effect in a game, for example a simple movie with flames
    or smoke to be shown as texture in your 3D game.
    Memory and loading time is acceptable then,
    and you want to prepare all your textures before the game starts anyway
    (for a 3D game, there's no time to decode some movie format while
    playing...).

    See example program
    @code(kambi_vrml_game_engine/examples/glwindow/simple_video_image_viewer.pasprogram)
    in our engine for example of a simple movie player implemented on top
    of this class.

    Note that some properties and methods of this class may look familiar
    to properties of TVRMLGLAnimation. And indeed they are familiar
    and work in an analogous way. Since both of these classes implement
    some sort of animation loading and playing, it's most sensible that
    some ideas find use in both of them. For example the idea of
    LoadFromFile / checking Loaded / Close. For example the idea that
    the programmer interface is mainly through ImageFromTime
    (like TVRMLGLAnimation.SceneFromTime). For example the way
    TimeLoop and TimeBackwards properties work. }
  TVideo = class
  private
    FItems: array of TImage;
    function GetItems(Index: Integer): TImage;
  private
    FCache: TImagesCache;
    FLoaded: boolean;
    FTimeLoop: boolean;
    FTimeBackwards: boolean;
    FFramesPerSecond: Single;
  public
    constructor Create;
    destructor Destroy; override;

    { Loaded video properties.
      Use these only when @link(Loaded) is @true.

      Time is supposed to be in seconds. (Actually, we don't care;
      but when the movie file says to play "25 frames per second", then
      we will make 25 frames per this Time unit. So you probably
      want to count the Time in seconds too.)

      @link(Count) is always >= 1 when the video is loaded.
      That is, we don't allow videos with zero frames (I don't
      know if any movie format allows this.)

      @groupBegin }
    function Count: Integer;
    property Items [Index: Integer]: TImage read GetItems;
    function Width: Cardinal;
    function Height: Cardinal;
    function IndexFromTime(const Time: Single): Integer;
    function ImageFromTime(const Time: Single): TImage;
    { @groupEnd }

    { Duration of the video. In seconds (or, more precisely, in the
      same time units as for ImageFromTime and other methods).

      Note that this doesn't count the "backwards" running time,
      so it ignores TimeBackwards and TimeLoop values.

      Use this only when @link(Loaded). }
    function TimeDuration: Single;

    { Number of frames per second for this video.

      For formats with varying frame-rate (although we do not support
      any such format right now), this will be just average frame-rate.
      The idea is that this property is just to show the user, so (s)he
      can judge the quality of the video. }
    property FramesPerSecond: Single read FFramesPerSecond;

    { Loads video from file.

      Supported video formats:

      @unorderedList(

        @item(We recognize video filenames by extension, and then try
          to load them through ffmpeg. So ffmpeg must be available
          on $PATH for this. See view3dscene docs for some links.

          Internally, for now we just use ffmpeg to decompose the video to
          single images, and then proceed to load this image sequence.
          So this takes some time and drains memory for longer movies,
          and it's not supposed to be really used to load longer movies.

          Of course, this may get improved (and some simple video formats
          may be handled without ffmpeg dependency) in the future,
          if the need arises. For now, it's enough for me --- all I want
          is to load some simple texture movies (like smoke or fire
          or dense fog animations) to use as billboards in games.
          For such short movies, loading time and memory use are acceptable.)

        @item(We can also load a sequence of images with a filename
          like image%d.png.

          More precisely: we use FormatIndexedName to
          recognize filename with %d pattern. If it contains %d pattern,
          then we try to load image sequence starting from counter 1.
          If not, we just load a single image (and treat it as a movie with only
          one frame).

          Note that this allows you to have alpha channel for the video.
          Since we just load the sequence of images, they can have
          alpha channel just like any still image (e.g. PNG) can have it.
          So your animated texture of fire / smoke
          etc. will be rendered will all the features of alpha channel
          (blending or alha testing, depending on alpha channel type).
          I don't know if any video file format supports any kind of
          alpha channel, so using image sequence may be actually your
          only choice for videos with alpha channel.)
      )

      We load images using the @link(Cache), you must assign it before using
      this method. }
    procedure LoadFromFile(const FileName: string);

    { Save video to file (or image sequence).

      Handled formats: just like LoadFromFile. Also, just like LoadFromFile,
      we need ffmpeg on $PATH to save to any single-file movie format. }
    procedure SaveToFile(const FileName: string);

    { This releases all resources allocared by Load (or LoadFromFile).
      @link(Loaded) property changes to @false after calling this.

      It's safe to call this even if @link(Loaded) is already @false --- then
      this will do nothing. }
    procedure Close;

    property Loaded: boolean read FLoaded;

    { Cache used to load images. You @bold(must) assign the cache
      before loading anything, and the Cache instance must remain constant
      between loading and closing the video file. }
    property Cache: TImagesCache read FCache write FCache;

    { @abstract(Should the video be played in a loop?)

      If yes, then IndexFromTime and ImageFromTime will return information
      that causes the video to be played in an infinite loop.
      This cooperates with TimeBackwards:
      If TimeBackwards is also @true, then each loop step will play
      video once forward, and once backward --- infinitely.

      It's Ok to change the value of this property at any time
      (even when video is not yet loaded), since this doesn't really
      cause any internal recalculation. It only affects what
      *FromTime methods return. }
    property TimeLoop: boolean read FTimeLoop write FTimeLoop default false;

    { @abstract(Should the video be played backwards after playing forward?)

      This cooperates with TimeLoop. If this is @true and TimeLoop = @false,
      video will be played once forward, once backward, and then stop.
      If this is @true and TimeLoop = also @true, then the video
      will be played forward, then backward, infinitely.

      It's Ok to change the value of this property at any time
      (even when video is not yet loaded), since this doesn't really
      cause any internal recalculation. It only affects what
      *FromTime methods return. }
    property TimeBackwards: boolean
      read FTimeBackwards write FTimeBackwards default false;

    { Mix the video with itself played backwards,
      to force the video to play seamless in a loop.

      This edits the loaded video, such that every frame becomes a mix
      between itself and the corresponding frame from the second half
      of the video. This forces any
      movie to become seamless when played in a loop.

      After this, the movie frames count is halved and TimeBackwards
      is set to @true. This is to conserve memory (and running time of
      this function), since there's no point in keeping both halves of the
      movie anymore --- they are identical (except reversed in time)
      after such operation.

      @italic(Unfortunately, this doesn't look perfect, human eye can easily
      notice the extreme time points (in the middle and at the end),
      when objects in the video reverse their directions etc.
      So the video is seamless, and it's a better trick than just setting
      TimeBackwards := true, but it still doesn't really look good.)

      If ProgressTitle <> '' this will call Progress.Init/Step/Fini
      from ProgressUnit to indicate progress of operation. }
    procedure MixWithSelfBackwards(const ProgressTitle: string);

    { Edit the video beginning to fade with the video ending,
      thus forcing the video to play seamless in a loop.

      The idea is to take out last FadeFrames from the video
      (FadeFrames must be >= 0 and <= Count div 2). And then mix
      the beginning of the video, such that the beginning FadeFrames
      frames gradually fade from the original end of video to original
      begin of the video.

      Video must be loaded when using this.

      If ProgressTitle <> '' this will call Progress.Init/Step/Fini
      from ProgressUnit to indicate progress of operation.

      @raises(EInvalidFadeFrames When FadeFrames is wrong.) }
    procedure FadeWithSelf(FadeFrames: Cardinal;
      const ProgressTitle: string);

    { Similar to IndexFromTime, this is a class method that calculates
      frame index using the same algorithm. (Actually, IndexFromTime
      just calls this, but this is implementation detail...).

      The idea is that you can reuse the same algorithm in cases when
      you somehow have the video data but do not have an instance
      of TVideo class.

      In particular, this public for TGLVideo.IndexFromTime,
      TGLVideo.GLTextureFromTime methods. }
    class function FrameIndexFromTime(const Time: Single;
      const ACount: Integer;
      const AFramesPerSecond: Single;
      const ATimeLoop, ATimeBackwards: boolean): Integer;

    { Alpha channel type of loaded video.
      See TImage.AlphaChannelType for precise meaning of this.

      Currently based on the first video image, so it's fast although
      in some cases possibly inaccurate. }
    function AlphaChannelType(
      const AlphaTolerance: Byte;
      const WrongPixelsTolerance: Single): TAlphaChannelType;

    { Alpha channel type of loaded video, possibly overridden by
      DetectAlphaChannel.

      See AlphaChannelType, TImage.AlphaChannelType,
      TImage.AlphaChannelTypeOverride. }
    function AlphaChannelTypeOverride(
      const DetectAlphaChannel: TDetectAlphaChannel;
      const AlphaTolerance: Byte;
      const WrongPixelsTolerance: Single): TAlphaChannelType;
  end;

{ Does filename extension Ext looks like a video file extension
  that can be handled (encoded or decoded) by ffmpeg?

  Ext is an extension with leading dot, just like returned
  by ExtractFileExt.

  FfmpegOutput = @true means that you want to encode this video
  (use this as output of ffmpeg). FfmpegOutput = @false means you
  want to decode the video, that is use this as an input to ffmpeg. }
function FfmpegVideoFileExtension(const Ext: string;
  FfmpegOutput: boolean): boolean;

implementation

uses KambiUtils, Math, KambiStringUtils, DataErrors,
  KambiFilesUtils, EnumerateFiles, ProgressUnit;

{ TVideo --------------------------------------------------------------------- }

constructor TVideo.Create;
begin
  inherited;
  FLoaded := false;
  { This is just constant for now }
  FFramesPerSecond := 25.0;
end;

destructor TVideo.Destroy;
begin
  Close;
  inherited;
end;

function TVideo.Count: Integer;
begin
  Assert(Loaded);
  Result := High(FItems) + 1;
end;

function TVideo.GetItems(Index: Integer): TImage;
begin
  Assert(Loaded);
  Result := FItems[Index];
end;

class function TVideo.FrameIndexFromTime(const Time: Single;
  const ACount: Integer;
  const AFramesPerSecond: Single;
  const ATimeLoop, ATimeBackwards: boolean): Integer;
var
  DivResult: SmallInt;
  ModResult: Word;
begin
  Result := Floor(Time * AFramesPerSecond);

  DivUnsignedMod(Result, ACount, DivResult, ModResult);

  if ATimeLoop then
  begin
    if ATimeBackwards and Odd(DivResult) then
      Result := ACount - 1 - ModResult else
      Result := ModResult;
  end else
  begin
    if ATimeBackwards then
    begin
      if (DivResult < 0) or (DivResult > 1) then
        Result := 0 else
      if DivResult = 1 then
        Result := ACount - 1 - ModResult;
        { else DivResult = 0, so Result is already correct }
    end else
    begin
      if DivResult < 0 then
        Result := 0 else
      if DivResult > 0 then
        Result := ACount - 1;
    end;
  end;
end;

function TVideo.IndexFromTime(const Time: Single): Integer;
begin
  Assert(Loaded);
  Result := FrameIndexFromTime(Time, Count, FramesPerSecond,
    TimeLoop, TimeBackwards);
end;

function TVideo.ImageFromTime(const Time: Single): TImage;
begin
  Result := FItems[IndexFromTime(Time)];
end;

function TVideo.TimeDuration: Single;
begin
  { Use Count, not High(FItems) (Count = High(FItems) + 1).
    Reason: we want the last frame to be treated as well as the others. }
  Result := Count / FramesPerSecond;
end;

procedure TVideo.Close;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    Cache.LoadImage_DecReference(FItems[I]);
  SetLength(FItems, 0);
  FLoaded := false;
end;

procedure TVideo.LoadFromFile(const FileName: string);

  procedure LoadFromImages(const FileName: string;
    RemoveLoadedTempImages: boolean);
  var
    Index, ReplacementsDone: Cardinal;
    S: string;
    NewItem: TImage;
  begin
    FormatIndexedName(FileName, 0, ReplacementsDone);
    if ReplacementsDone > 0 then
    begin
      Index := 1;
      S := FormatIndexedName(FileName, Index);
      while FileExists(S) do
      begin
        { Remember that Cache.LoadImage_IncReference may raise an exception
          for invalid / not existing / not readable image filenames.
          So don't increase FItems before NewItem is successfully loaded. }
        NewItem := Cache.LoadImage_IncReference(
          { Cache.LoadImage_IncReference requires absolute expanded filename }
          ExpandFileName(S));
        SetLength(FItems, Length(FItems) + 1);
        FItems[High(FItems)] := NewItem;

        if RemoveLoadedTempImages then
        begin
          if not DeleteFile(S) then
            DataWarning(Format('Cannot delete temporary file "%s"', [S]));
        end;

        Inc(Index);
        S := FormatIndexedName(FileName, Index);
      end;
      if Length(FItems) = 0 then
        raise Exception.CreateFmt('First video image "%s" not found, cannot load the video',
          [S]);
    end else
    begin
      NewItem := Cache.LoadImage_IncReference(
        { Cache.LoadImage_IncReference requires absolute expanded filename }
        ExpandFileName(FileName));
      SetLength(FItems, 1);
      FItems[0] := NewItem;

      if RemoveLoadedTempImages then
      begin
        if not DeleteFile(FileName) then
          DataWarning(Format('Cannot delete temporary file "%s"', [FileName]));
      end;
    end;
  end;

  procedure LoadFromFfmpeg(const FileName: string);
  var
    TemporaryImagesPrefix, TemporaryImagesPattern: string;
    FileRec: TSearchRec;
    SearchError: Integer;
    Executable: string;
  begin
    Executable := FileSearch(
      {$ifdef MSWINDOWS} 'ffmpeg.exe' {$endif}
      {$ifdef UNIX} 'ffmpeg' {$endif}
      , GetEnvironmentVariable('PATH'));

    if Executable = '' then
    begin
      raise Exception.Create('You must have "ffmpeg" program from ' +
        '[http://ffmpeg.mplayerhq.hu/] installed and available on $PATH to be able to ' +
        'load movie files');
    end else
    begin
      { initialize TemporaryImagesPrefix, TemporaryImagesPattern }

      TemporaryImagesPrefix := GetTempFileName('', ProgramName) + '_' +
        { Although GetTempFileName should add some randomization here,
          there's no guarentee. And we really need randomization ---
          we load ffmpeg output using image %d pattern, so we don't want to
          accidentaly pick up other images in the temporary directory. }
        IntToStr(Random(MaxInt)) + '_';

      { Check is it really Ok. }
      SearchError := FindFirst(TemporaryImagesPrefix + '*', faReallyAnyFile,
        FileRec);
      try
        if SearchError = 0 then
          raise Exception.CreateFmt('Failed to generate unique temporary file prefix "%s": filename "%s" already exists',
            [TemporaryImagesPrefix, FileRec.Name]);
      finally FindClose(FileRec) end;

      TemporaryImagesPattern := TemporaryImagesPrefix + '%d.png';

      { ffmpeg call will output some things on stdout anyway.
        So it's Ok that we also output something, stdout is required
        by ffmpeg anyway... }

      Writeln(Output, 'FFMpeg found, executing...');
      Writeln(Output, Executable + ' -i "' + FileName +
        '" -y -sameq -f image2 "' + TemporaryImagesPattern + '"');

      ExecuteProcess(Executable,
        [ '-i', FileName, '-y', '-sameq', '-f', 'image2', TemporaryImagesPattern ]);

      LoadFromImages(TemporaryImagesPattern, true);
    end;
  end;

begin
  Close;

  if FfmpegVideoFileExtension(ExtractFileExt(FileName), true) then
    LoadFromFfmpeg(FileName) else
    LoadFromImages(FileName, false);

  FLoaded := true;
end;

procedure TVideo.SaveToFile(const FileName: string);

  procedure SaveToImages(const FileName: string);
  var
    Index, ReplacementsDone: Cardinal;
    S: string;
  begin
    FormatIndexedName(FileName, 0, ReplacementsDone);
    if ReplacementsDone > 0 then
    begin
      { Note that Index is 1-based, that's how %d works for LoadFromFile
        and ffmpeg, so also here. }
      for Index := 1 to Count do
      begin
        S := FormatIndexedName(FileName, Index);
        SaveImage(FItems[Index - 1], S);
      end;
    end else
    begin
      { single image file --- suitable only if video has exactly one frame }
      if Count <> 1 then
        raise Exception.CreateFmt('Single image filename detected ("%s"), but saved video doesn''t have exactly one frame (it has %d frames). Cannot save',
          [FileName, Count]);

      SaveImage(FItems[0], FileName);
    end;
  end;

  procedure RemoveTemporaryImages(const FileName: string);
  var
    Index, ReplacementsDone: Cardinal;
    S: string;
  begin
    Write(Output, 'Removing temporary image files "', FileName, '" ...');
    FormatIndexedName(FileName, 0, ReplacementsDone);
    if ReplacementsDone > 0 then
    begin
      for Index := 1 to Count do
      begin
        S := FormatIndexedName(FileName, Index);
        if not DeleteFile(S) then
          DataWarning(Format('Cannot delete temporary file "%s"', [S]));
      end;
    end else
    begin
      if not DeleteFile(FileName) then
        DataWarning(Format('Cannot delete temporary file "%s"', [FileName]));
    end;
    Writeln('done.');
  end;

  procedure SaveToFfmpeg(const FileName: string);
  var
    TemporaryImagesPrefix, TemporaryImagesPattern: string;
    FileRec: TSearchRec;
    SearchError: Integer;
    Executable: string;
  begin
    Executable := FileSearch(
      {$ifdef MSWINDOWS} 'ffmpeg.exe' {$endif}
      {$ifdef UNIX} 'ffmpeg' {$endif}
      , GetEnvironmentVariable('PATH'));

    if Executable = '' then
    begin
      raise Exception.Create('You must have "ffmpeg" program from ' +
        '[http://ffmpeg.mplayerhq.hu/] installed and available on $PATH to be able to ' +
        'save movie files');
    end else
    begin
      { initialize TemporaryImagesPrefix, TemporaryImagesPattern }

      TemporaryImagesPrefix := GetTempFileName('', ProgramName) + '_' +
        { Although GetTempFileName should add some randomization here,
          there's no guarentee. And we really need randomization ---
          we pass to ffmpeg input using image %d pattern, so we don't want to
          accidentaly pick up other images in the temporary directory. }
        IntToStr(Random(MaxInt)) + '_';

      { Check is it really Ok. }
      SearchError := FindFirst(TemporaryImagesPrefix + '*', faReallyAnyFile,
        FileRec);
      try
        if SearchError = 0 then
          raise Exception.CreateFmt('Failed to generate unique temporary file prefix "%s": filename "%s" already exists',
            [TemporaryImagesPrefix, FileRec.Name]);
      finally FindClose(FileRec) end;

      TemporaryImagesPattern := TemporaryImagesPrefix + '%d.png';

      SaveToImages(TemporaryImagesPattern);

      { ffmpeg call will output some things on stdout anyway.
        So it's Ok that we also output something, stdout is required
        by ffmpeg anyway... }

      Writeln(Output, 'FFMpeg found, executing...');
      Writeln(Output, Executable + ' -f image2 -i "' + TemporaryImagesPattern +
        '" -y -sameq "' + FileName + '"');

      ExecuteProcess(Executable,
        ['-f', 'image2', '-i', TemporaryImagesPattern, '-y', '-sameq', FileName]);

      RemoveTemporaryImages(TemporaryImagesPattern);
    end;
  end;

begin
  Assert(Loaded);

  if FfmpegVideoFileExtension(ExtractFileExt(FileName), false) then
    SaveToFfmpeg(FileName) else
    SaveToImages(FileName);
end;

function TVideo.Width: Cardinal;
begin
  Assert(Loaded);
  Result := Items[0].Width;
end;

function TVideo.Height: Cardinal;
begin
  Assert(Loaded);
  Result := Items[0].Height;
end;

procedure TVideo.MixWithSelfBackwards(const ProgressTitle: string);
var
  I, NewCount: Integer;
begin
  Assert(Loaded);

  { TODO: this is not good for the cache, if the image is referenced
    more than one time than you will modify all occurences.
    Some MakeUnique method for TImagesCache needed.
    Also, simple_video_image_viewer.pasprogram should use it too
    before editing. }

  if ProgressTitle <> '' then
    Progress.Init((Count div 2) * 2, ProgressTitle);
  try

    for I := 0 to Count div 2 do
    begin
      Items[I].LerpWith(0.5, Items[Count - 1 - I]);
      if ProgressTitle <> '' then Progress.Step;
    end;

    { shrink count to half }
    NewCount := (Count div 2) + (Count mod 2);
    for I := NewCount to Count - 1 do
    begin
      Cache.LoadImage_DecReference(FItems[I]);
      if ProgressTitle <> '' then Progress.Step;
    end;
    SetLength(FItems, NewCount);

    TimeBackwards := true;
  finally
    if ProgressTitle <> '' then Progress.Fini;
  end;
end;

procedure TVideo.FadeWithSelf(FadeFrames: Cardinal;
  const ProgressTitle: string);
var
  I, NewCount: Integer;
begin
  Assert(Loaded);

  if FadeFrames > Cardinal(Count) div 2 then
    raise EInvalidFadeFrames.CreateFmt('FadeFrames for FadeWithSelf too large: are %d, but frames count div 2 = %s',
      [FadeFrames, Count div 2]);

  if ProgressTitle <> '' then
    Progress.Init(FadeFrames * 2, ProgressTitle);
  try
    for I := 0 to FadeFrames - 1 do
    begin
      Items[I].LerpWith(1 - I / FadeFrames, Items[Count - FadeFrames + I]);
      if ProgressTitle <> '' then Progress.Step;
    end;

    NewCount := Count - FadeFrames;
    for I := NewCount to Count - 1 do
    begin
      Cache.LoadImage_DecReference(FItems[I]);
      if ProgressTitle <> '' then Progress.Step;
    end;
    SetLength(FItems, NewCount);

  finally
    if ProgressTitle <> '' then Progress.Fini;
  end;
end;

function TVideo.AlphaChannelType(
  const AlphaTolerance: Byte;
  const WrongPixelsTolerance: Single): TAlphaChannelType;
begin
  Assert(Loaded);
  Result := Items[0].AlphaChannelType(AlphaTolerance, WrongPixelsTolerance);
end;

function TVideo.AlphaChannelTypeOverride(
  const DetectAlphaChannel: TDetectAlphaChannel;
  const AlphaTolerance: Byte;
  const WrongPixelsTolerance: Single): TAlphaChannelType;
begin
  Assert(Loaded);
  Result := Items[0].AlphaChannelTypeOverride(DetectAlphaChannel,
    AlphaTolerance, WrongPixelsTolerance);
end;

{ non-object routines -------------------------------------------------------- }

function FfmpegVideoFileExtension(const Ext: string;
  FfmpegOutput: boolean): boolean;
begin
  { For now we ignore FfmpegOutput, all formats below are good
    for both input and output. (Actually, file extension specifies only
    "container" data type, not actual encoding, so there's no guarentee,
    but potentially it's all possible.) See "ffmpeg -formats". }
  Result :=
    SameText(Ext, '.avi') or
    SameText(Ext, '.mpg') or
    SameText(Ext, '.dvd') or
    SameText(Ext, '.ogg') or
    SameText(Ext, '.mov') or
    SameText(Ext, '.flv') or
    SameText(Ext, '.swf');
end;

end.
