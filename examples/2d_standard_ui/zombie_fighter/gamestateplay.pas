{
  Copyright 2016-2016 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Game state where you actually play a game. }
unit GameStatePlay;

interface

uses Classes, CastleControls, CastleUIState, CastleOnScreenMenu,
  CastleSceneManager, CastleSceneCore, CastleScene,
  CastleCameras, CastleKeysMouse;

type
  TStatePlay = class(TUIState)
  strict private
    SimpleBackground: TCastleSimpleBackground;
    SceneManager: TCastleSceneManager;
    Scene: TCastleScene;
    ViewportRect: TCastleRectangleControl;
    Viewport: TCastleViewport;
    ButtonBack: TCastleButton;
    procedure BackClick(Sender: TObject);
  public
    procedure Start; override;
    function Press(const Event: TInputPressRelease): boolean; override;
  end;

var
  StatePlay: TStatePlay;

implementation

uses CastleVectors, CastleColors, CastleWindow, CastleUIControls,
  CastleFilesUtils, CastleUtils,
  GameStateMainMenu, GameStateAskDialog;

{ TStatePlay ------------------------------------------------------------- }

procedure TStatePlay.Start;
begin
  inherited;

  SimpleBackground := TCastleSimpleBackground.Create(FreeAtStop);
  SimpleBackground.Color := Black;
  InsertFront(SimpleBackground);

  Scene := TCastleScene.Create(FreeAtStop);
  Scene.Load(ApplicationData('level1.x3d'));
  Scene.Spatial := [ssRendering, ssDynamicCollisions];
  Scene.ProcessEvents := true;

  SceneManager := TCastleSceneManager.Create(FreeAtStop);
  SceneManager.FullSize := false;
  SceneManager.Left := 10;
  SceneManager.Bottom := 10;
  SceneManager.Width := 800;
  SceneManager.Height := 748;
  SceneManager.Items.Add(Scene);
  SceneManager.MainScene := Scene;
  (SceneManager.RequiredCamera as TUniversalCamera).NavigationType := ntWalk;
  (SceneManager.RequiredCamera as TUniversalCamera).Walk.MoveSpeed := 10;
  InsertFront(SceneManager);

  { otherwise, inputs are only passed
    when mouse cursor is over the SceneManager. }
  StateContainer.ForceCaptureInput := SceneManager;

  ViewportRect := TCastleRectangleControl.Create(FreeAtStop);
  ViewportRect.FullSize := false;
  ViewportRect.Left := 820;
  ViewportRect.Bottom := 10;
  ViewportRect.Width := 256;
  ViewportRect.Height := 256;
  ViewportRect.Color := Silver;
  InsertFront(ViewportRect);

  Viewport := TCastleViewport.Create(FreeAtStop);
  Viewport.FullSize := false;
  Viewport.Left := 10;
  Viewport.Bottom := 10;
  Viewport.Width := 236;
  Viewport.Height := 236;
  Viewport.SceneManager := SceneManager;
  Viewport.Transparent := true;
  (Viewport.RequiredCamera as TUniversalCamera).NavigationType := ntNone;
  (Viewport.RequiredCamera as TUniversalCamera).SetView(
    Vector3Single(5, 92.00, 0.99),
    Vector3Single(0, -1, 0),
    Vector3Single(0, 0, 1));
  ViewportRect.InsertFront(Viewport);

  ButtonBack := TCastleButton.Create(FreeAtStop);
  ButtonBack.Caption := 'Back to Main Menu';
  ButtonBack.OnClick := @BackClick;
  ButtonBack.Anchor(vpTop, -10);
  ButtonBack.Anchor(hpRight, -10);
  InsertFront(ButtonBack);
end;

procedure TStatePlay.BackClick(Sender: TObject);
begin
  TUIState.Current := StateMainMenu;
end;

function TStatePlay.Press(const Event: TInputPressRelease): boolean;
begin
  Result := inherited;
  if Result then Exit;

  if Event.IsMouseButton(mbLeft) then
  begin
    TUIState.Push(StateAskDialog);
  end;
end;

end.