{ Demo of TVRMLGLAnimation class. In other words, this loads and displays
  animations of "Kambi VRML game engine".

  If you're looking for example animation models,
  see inside kanim/ subdirectory of
  [http://vrmlengine.sourceforge.net/kanim_format.php].
  If you're looking for a real, full-featured program to read
  kanim animations, see
  [http://vrmlengine.sourceforge.net/view3dscene.php].
  This program is only a demo for a programmer to see how easy
  it's to load animations in your own programs using our engine.

  1. Run this passing one command-line parameter:
     name of *.kanim file that describes the animation.

     Example commands:
      ./demo_animation sphere.kanim
      ./demo_animation raptor.kanim
      ./demo_animation gus.kanim
      ./demo_animation cube_opening.kanim
      ./demo_animation gus3.kanim

  2. Alternatively, more "manual" method:
     Run this passing an even number of command-line parameters.
     Each parameters pair specifies scene filename, and position in time
     of this scene. Scenes must be specified in increasing order of time.
     Time is in seconds. Animation goes from 1st scene to the 2nd,
     then to the 3rd etc. to the last scene.

     Example command with two scenes:
       ./demo_animation sphere_1.wrl 0 sphere_2.wrl 1
     Example command with more scenes:
       ./demo_animation gus_1_final.wrl 0 \
                        gus_2_final.wrl 1 \
                        gus_3_final.wrl 1.5 --backwards

   Additional command-line options:
     --loop
     --backwards
     --no-loop
     --no-backwards
   For precise meaning, see TVRMLGLAnimation documentation.
   In short, --loop causes animation to loop and --backwards causes
   animation to go backward after going forward.
   If you load from *.kanim file, then the default loop/backwards
   settings are loaded from this file. Otherwise, the default is
   --loop --no-backwards.

  This is all implemented in TVRMLGLAnimation class, see docs of this class
  for precise description how things work.

  You can navigate in the scene using the standard arrow keys, escape exits.
  (for full list of supported keys --- see view3dscene documentation,
  [http://vrmlengine.sourceforge.net/view3dscene.php],
  at Examine / Walk navigation method).
  Space key restarts the animation (definitely useful if you passed
  --no-loop option).

  At the beginning there is some preprocessing time
  ("Preparing animation") when we create display lists,
  to make future animation run smoothly.
  That's done by TVRMLGLAnimation.PrepareResources.
}

program demo_animation;

uses VectorMath, VRMLNodes, VRMLOpenGLRenderer, GL, GLU, GLWindow,
  KambiClassUtils, KambiUtils, SysUtils, Classes, Object3DAsVRML,
  KambiGLUtils, VRMLGLScene, Cameras, VRMLGLAnimation,
  KambiFilesUtils, ParseParametersUnit, GLProgress, ProgressUnit, VRMLErrors,
  KambiSceneManager;

var
  Glw: TGLUIWindow;
  SceneManager: TKamSceneManager;
  Animation: TVRMLGLAnimation;

procedure KeyDown(Glwin: TGLWindow; Key: TKey; C: char);
begin
  if C = ' ' then
    Animation.ResetTime(0.0);
end;

procedure LoadAnimationFromCommandLine(Animation: TVRMLGLAnimation);
const
  { These are constants used only with "manual" method
    (even number of command-line params),
    in case of *.kanim file these informations are read from *.kanim file. }
  { This is the number of animation frames constructed per one unit of time.
    Increase this to get smoother animation. }
  ScenesPerTime = 50;
  { EqualityEpsilon used to marge nodes when creating animation.
    Larger values may speed up animation loading time and save memory use. }
  EqualityEpsilon = 0.001;
  RendererOptimization: TGLRendererOptimization = roSeparateShapesNoTransform;
var
  AnimRootNodes: TVRMLNodesList;
  AnimTimes: TDynSingleArray;
  I: Integer;
begin
  { parse parameters to AnimRootNodes and AnimTimes }
  if (Parameters.High = 0) or Odd(Parameters.High) then
    raise EInvalidParams.Create('You must supply even number of paramaters: ' +
      '2 parameters "<scene> <time>" for each frame');

  AnimRootNodes := nil;
  AnimTimes := nil;
  try
    AnimRootNodes := TVRMLNodesList.Create;
    AnimTimes := TDynSingleArray.Create;

    AnimRootNodes.Count := Parameters.High div 2;
    AnimTimes    .Count := Parameters.High div 2;

    for I := 0 to Parameters.High div 2 - 1 do
    begin
      AnimRootNodes[I] := LoadVRML(Parameters[(I+1) * 2 - 1], false);
      AnimTimes[I] := StrToFloat(Parameters[(I+1) * 2]);
    end;

    Animation.Optimization := RendererOptimization;
    Animation.Load(AnimRootNodes, true,
      AnimTimes, ScenesPerTime, EqualityEpsilon);
    Animation.TimeLoop := true;
    Animation.TimeBackwards := true;
  finally
    FreeAndNil(AnimRootNodes);
    FreeAndNil(AnimTimes);
  end;
end;

var
  WasParam_AnimTimeLoop: boolean = false;
  Param_AnimTimeLoop: boolean;
  WasParam_AnimTimeBackwards: boolean = false;
  Param_AnimTimeBackwards: boolean;

const
  Options: array[0..3] of TOption =
  (
    (Short:  #0; Long: 'loop'; Argument: oaNone),
    (Short:  #0; Long: 'backwards'; Argument: oaNone),
    (Short:  #0; Long: 'no-loop'; Argument: oaNone),
    (Short:  #0; Long: 'no-backwards'; Argument: oaNone)
  );

  procedure OptionProc(OptionNum: Integer; HasArgument: boolean;
    const Argument: string; const SeparateArgs: TSeparateArgs; Data: Pointer);
  begin
    case OptionNum of
      0: begin WasParam_AnimTimeLoop      := true; Param_AnimTimeLoop      := true; end;
      1: begin WasParam_AnimTimeBackwards := true; Param_AnimTimeBackwards := true; end;
      2: begin WasParam_AnimTimeLoop      := true; Param_AnimTimeLoop      := false; end;
      3: begin WasParam_AnimTimeBackwards := true; Param_AnimTimeBackwards := false; end;
      else raise EInternalError.Create('OptionProc');
    end;
  end;

begin
  Glw := TGLUIWindow.Create(Application);

  Glw.ParseParameters(StandardParseOptions);
  ParseParameters(Options, @OptionProc, nil);

  try
    VRMLWarning := @VRMLWarning_Write;

    Animation := TVRMLGLAnimation.Create(nil);

    if Parameters.High = 1 then
    begin
      { 1st method: load a file }
      Animation.LoadFromFile(Parameters[1], true, true);
    end else
    begin
      { 2nd method: even number of command-line params }
      LoadAnimationFromCommandLine(Animation);
    end;

    if WasParam_AnimTimeLoop then
      Animation.TimeLoop := Param_AnimTimeLoop;
    if WasParam_AnimTimeBackwards then
      Animation.TimeBackwards := Param_AnimTimeBackwards;

    { init SceneManager, with the Animation }
    SceneManager := TKamSceneManager.Create(Glw);
    Glw.Controls.Add(SceneManager);
    SceneManager.MainScene := Animation.FirstScene;
    SceneManager.Items.Add(Animation);

    GLProgressInterface.Window := Glw;
    Progress.UserInterface := GLProgressInterface;

    Glw.AutoRedisplay := true;
    Glw.OnKeyDown := @KeyDown;
    Glw.Caption := ProgramName;

    Glw.Init;

    Progress.Init(Animation.ScenesCount, 'Preparing animation');
    try
      Animation.PrepareResources([tgAll], [prRender, prBoundingBox], true);
    finally Progress.Fini end;

    Application.Run;
  finally Animation.Free end;
end.
