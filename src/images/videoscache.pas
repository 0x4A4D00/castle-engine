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

{ A cache for loading both videos and images (TImagesVideosCache). }
unit VideosCache;

interface

uses KambiUtils, ImagesCache, Videos;

{$define read_interface}

type
  { Internal for TVideosCache }
  TCachedVideo = record
    References: Cardinal;
    FileName: string;
    Video: TVideo;
  end;
  PCachedVideo = ^TCachedVideo;

  TDynArrayItem_1 = TCachedVideo;
  PDynArrayItem_1 = PCachedVideo;
  {$define DYNARRAY_1_IS_STRUCT}
  {$define DYNARRAY_1_IS_INIT_FINI_TYPE}
  {$I dynarray_1.inc}
  TDynCachedVideoArray = TDynArray_1;

  { A cache of loaded videos.

    The idea is that instead of creating TVideo instance and calling
    TVideo.LoadFromFile, you instead call
    @code(Video := Cache.Video_IncReference(...)).
    Later, instead of freeing this video, call
    @code(Video_DecReference(Video)). From your point of view, things
    will work the same. But if you expect to load many videos from the
    same FileName, then you will get a great speed and memory saving,
    because video will only be actually loaded once. This may happen
    e.g. if you have a VRML / X3D file with lots of MovieTexture nodes
    with the same urls.

    Notes:

    @unorderedList(
      @item(All passed here FileNames must be absolute, already expanded paths.
        In the future it's expected that this (just like TVideo.LoadFromFile,
        actually) will be extended to load videos from URLs.)

      @item(Note that in case of problems with loading,
        Video_IncReference may raise an exception, just like normal
        TVideo.LoadFromFile. In this case it's guaranteed that no reference will
        be incremented, of course. If Video_IncReference returns
        in a normal way, then it will return something non-@nil for sure.)

      @item(Video_DecReference alwas sets Video to @nil, like FreeAndNil.)

      @item(As TVideo also uses TImagesCache internally to load single
        images, and this class descends from TImagesCache, so we naturally
        set Self as TVideo.Cache. This way you also get images sharing,
        useful for example if your videos came from images sequence
        shared by other videos.)

      @item(All videos handled here are always loaded.
        So Video_IncReference always returns TVideo with TVideo.Loaded = @true.
        And you are forbidden from closing this video by TVideo.Close
        yourself.)
    )

    Note that before destroying this object you must free all videos,
    i.e. call Video_DecReference for all videos allocated by
    Video_IncReference. @italic(This class is not a lousy way
    of avoiding memory leaks) --- it would be a bad idea, because it would
    cause sloppy programming, where memory is unnecessarily allocated for
    a long time. In fact, this class asserts in destructor that no videos
    are in cache anymore, so if you compiled with assertions enabled,
    this class does the job of memory-leak detector. }
  TImagesVideosCache = class(TImagesCache)
  private
    CachedVideos: TDynCachedVideoArray;
  public
    constructor Create;
    destructor Destroy; override;

    function Video_IncReference(const FileName: string): TVideo;
    procedure Video_DecReference(var Video: TVideo);
  end;

{$undef read_interface}

implementation

uses SysUtils, KambiStringUtils;

{$define read_implementation}
{$I dynarray_1.inc}

{ $define DEBUG_CACHE}

constructor TImagesVideosCache.Create;
begin
  inherited;
  CachedVideos := TDynCachedVideoArray.Create;
end;

destructor TImagesVideosCache.Destroy;
begin
  if CachedVideos <> nil then
  begin
    Assert(CachedVideos.Count = 0, ' Some references to videos still exist ' +
      'when freeing TImagesVideosCache');
    FreeAndNil(CachedVideos);
  end;
  inherited;
end;

function TImagesVideosCache.Video_IncReference(const FileName: string): TVideo;
var
  I: Integer;
  C: PCachedVideo;
begin
  C := @CachedVideos.Items[0];
  for I := 0 to CachedVideos.High do
  begin
    if C^.FileName = FileName then
    begin
      Inc(C^.References);

      {$ifdef DEBUG_CACHE}
      Writeln('++ : video ', FileName, ' : ', C^.References);
      {$endif}

      Exit(C^.Video);
    end;
    Inc(C);
  end;

  { Initialize Result first, before calling CachedVideos.Add.
    That's because in case TVideo.LoadFromFile raises exception,
    we don't want to add video to cache (because caller would have
    no way to call Video_DecReference later). }

  Result := TVideo.Create;
  try
    Result.Cache := Self;
    Result.LoadFromFile(FileName);
  except
    FreeAndNil(Result);
    raise;
  end;

  C := CachedVideos.Add;
  C^.References := 1;
  C^.FileName := FileName;
  C^.Video := Result;

  {$ifdef DEBUG_CACHE}
  Writeln('++ : video ', FileName, ' : ', 1);
  {$endif}
end;

procedure TImagesVideosCache.Video_DecReference(var Video: TVideo);
var
  I: Integer;
  C: PCachedVideo;
begin
  C := @CachedVideos.Items[0];
  for I := 0 to CachedVideos.High do
  begin
    if C^.Video = Video then
    begin
      {$ifdef DEBUG_CACHE}
      Writeln('-- : video ', C^.FileName, ' : ', C^.References - 1);
      {$endif}

      Video := nil;

      if C^.References = 1 then
      begin
        FreeAndNil(C^.Video);
        CachedVideos.Delete(I, 1);
      end else
        Dec(C^.References);

      Exit;
    end;
    Inc(C);
  end;

  raise EInternalError.CreateFmt(
    'TImagesVideosCache.Video_DecReference: no reference found for video %s',
    [PointerToStr(Video)]);
end;

end.
