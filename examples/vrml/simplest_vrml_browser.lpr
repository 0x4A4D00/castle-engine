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

{ This opens VRML/X3D file, renders it, allows to move in the scene
  (with navigation adjusted to NavigationInfo.type, see view3dscene docs
  for keys/mouse to control Walk/Examine navigation
  [http://vrmlengine.sourceforge.net/view3dscene.php]) and makes
  events working.

  Run with $1 command-line option as 3D model filename. For example,
    ./simplest_vrml_browser ../../../kambi_vrml_test_suite/x3d/fog_animate_transform.x3dv
  (get kambi_vrml_test_suite from
  [http://vrmlengine.sourceforge.net/kambi_vrml_test_suite.php]).

  This program is a minimal VRML browser, passing all user interactions
  to the Scene (so that they can be processed by VRML events).

  To extend this into your own game:

  1. Look at all the window methods and callbacks of TGLWindow,
     which is an ancestor of TGLUIWindow, which is an ancestor of
     TGLWindowVRMLBrowser (that you have inside BrowserWindow variable).
     For example: assigning your own handlers for BrowserWindow.OnKeyDown
     or BrowserWindow.OnIdle is often useful.

  2. Look at TKamSceneManager methods and properties (you have TKamSceneManager
     instance inside BrowserWindow.SceneManager variable of this program).

  3. Look at TVRMLGLScene (and it's parent, TVRMLScene) methods and properties
     (you have TVRMLGLScene instance inside BrowserWindow.Scene
     variable of this program; the same thing is also available in
     BrowserWindow.SceneManager.MainScene).

  4. Finally, often it's more comfortable to just create your own
     TKamSceneManager and TVRMLGLScene instances explicitly, using TGLUIWindow
     (instead of TGLWindowVRMLBrowser). This way you get a little more control
     and understanding of our scene manager, which is really the core
     of our engine since version 2.0. It's quite easy, see
     scene_manager_demos.lpr example.
}

program simplest_vrml_browser;

{$apptype CONSOLE}

uses KambiUtils, GLWindow, GLWindowVRMLBrowser, ProgressUnit, ProgressConsole,
  VRMLScene, VRMLErrors;

var
  BrowserWindow: TGLWindowVRMLBrowser;

begin
  Parameters.CheckHigh(1);

  VRMLWarning := @VRMLWarning_Write;
  Progress.UserInterface := ProgressConsoleInterface;

  BrowserWindow := TGLWindowVRMLBrowser.Create(Application);

  BrowserWindow.Load(Parameters[1]);
  Writeln(BrowserWindow.Scene.Info(true, true, false));
  BrowserWindow.Scene.Spatial := [ssRendering, ssDynamicCollisions];
  BrowserWindow.Scene.ProcessEvents := true;

  BrowserWindow.InitAndRun;
end.
