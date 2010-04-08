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

{ Generates light map.

  See lets_take_a_walk game
  ([http://vrmlengine.sourceforge.net/lets_take_a_walk.php])
  for example how to use this program.
  lets_take_a_walk sources contain an example model and script
  used with this program.
}

program gen_light_map;

uses SysUtils, KambiUtils, VectorMath, VRMLNodes, VRMLLightSet, VRMLScene,
  VRMLLightMap, Images, ProgressUnit, ProgressConsole, KambiTimeUtils;

function ReadParametersVectorTo1st(i: Integer): TVector3Single;
begin
 result[0] := StrToFloat(Parameters[i]);
 result[1] := StrToFloat(Parameters[i+1]);
 result[2] := StrToFloat(Parameters[i+2]);
end;

var
  LightSet: TVRMLLightSet;
  Scene: TVRMLScene;
  Image: TImage;

  SceneFileName, OutImageFileName: string;
  ImageSizeX, ImageSizeY: Integer;

  Quad: TQuad3Single;
  RenderDir: TVector3Single;

  i: Integer;

begin
 { parse params }
 Parameters.CheckHigh(4 + 3*5);
 SceneFileName := Parameters[1];
 OutImageFileName := Parameters[2];
 ImageSizeX := StrToInt(Parameters[3]);
 ImageSizeY := StrToInt(Parameters[4]);
 for i := 0 to 3 do Quad[i] := ReadParametersVectorTo1st(5 + i*3);
 RenderDir := ReadParametersVectorTo1st(5 + 4*3);

 Image := nil;

 try

  { prepare Image (Image contents are not initialized - they may contain
    trash, we will render every pixel of this image so there is no point
    in clearing image at the beginning) }
  Image := ImageClassBestForSavingToFormat(OutImageFilename).
    Create(ImageSizeX, ImageSizeY);

  { calculate Scene and LightSet (from the same RootNode) }
  Write('Loading scene... ');
  Scene := TVRMLScene.Create(nil);
  Scene.Load(SceneFileName, true);
  LightSet := TVRMLLightSet.Create(Scene.RootNode, false);
  Writeln('done.');
  if LightSet.Lights.Count = 0 then
   Writeln('WARNING: scene has no lights defined (everything will be black)');

  { calculate SceneOctree }
  Progress.UserInterface := ProgressConsoleInterface;
  Scene.TriangleOctreeProgressTitle := 'Building octree';
  Scene.Spatial := [ssVisibleTriangles];

  { render to Image }
  ProcessTimerBegin;
  QuadLightMapTo1st(Image, LightSet.Lights, Scene.OctreeVisibleTriangles, Quad,
    RenderDir, 'Rendering');
  Writeln(Format('Rendering done in %f seconds.', [ProcessTimerEnd]));

  SaveImage(Image, OutImageFilename);
 finally
  LightSet.Free;
  Scene.Free;
  Image.Free;
 end;
end.