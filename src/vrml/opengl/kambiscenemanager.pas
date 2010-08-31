{
  Copyright 2009-2010 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Scene manager (TKamSceneManager) and viewport (TKamViewport) classes. }
unit KambiSceneManager;

interface

uses Classes, VectorMath, VRMLNodes, VRMLGLScene, VRMLScene, Cameras,
  VRMLGLHeadLight, GLShadowVolumeRenderer, GL, UIControls, Base3D,
  KeysMouse, VRMLTriangle, Boxes3D, BackgroundGL, KambiUtils, KambiClassUtils,
  GLShaders, GLImages, KambiTimeUtils;

{$define read_interface}

type
  TKamAbstractViewport = class;

  TRender3DEvent = procedure (Viewport: TKamAbstractViewport;
    TransparentGroup: TTransparentGroup; InShadow: boolean) of object;

  { Common abstract class for things that may act as a viewport:
    TKamSceneManager and TKamViewport. }
  TKamAbstractViewport = class(TUIControlPos)
  private
    FWidth, FHeight: Cardinal;
    FFullSize: boolean;
    FCamera: TCamera;
    FPaused: boolean;

    FShadowVolumesPossible: boolean;
    FShadowVolumes: boolean;
    FShadowVolumesDraw: boolean;

    FBackgroundWireframe: boolean;
    FOnRender3D: TRender3DEvent;
    FHeadlightFromViewport: boolean;
    FAlwaysApplyProjection: boolean;

    { If a texture rectangle for screen effects is ready, then
      ScreenEffectTexture is non-zero and ScreenEffectRTT.
      Also, ScreenEffectTextureWidth/Height indicate size of the texture,
      as well as ScreenEffectRTT.Width/Height. }
    ScreenEffectTexture: TGLuint;
    ScreenEffectTextureWidth: Cardinal;
    ScreenEffectTextureHeight: Cardinal;
    ScreenEffectRTT: TGLRenderToTexture;

    procedure ItemsAndCameraCursorChange(Sender: TObject);
  protected
    { These variables are writeable from overridden ApplyProjection. }
    FPerspectiveView: boolean;
    FPerspectiveViewAngles: TVector2Single;
    FOrthoViewDimensions: TVector4Single;
    FWalkProjectionNear: Single;
    FWalkProjectionFar : Single;

    ApplyProjectionNeeded: boolean;

    { Sets OpenGL projection matrix, based on scene manager MainScene's
      currently bound Viewpoint, NavigationInfo and used @link(Camera).
      Viewport's @link(Camera), if not assigned, is automatically created here,
      see @link(Camera) and CreateDefaultCamera.
      If scene manager's MainScene is not assigned, we use some default
      sensible perspective projection.

      Takes care of updating Camera.ProjectionMatrix,
      PerspectiveView, PerspectiveViewAngles, OrthoViewDimensions,
      WalkProjectionNear, WalkProjectionFar.

      This is automatically called at the beginning of our Render method,
      if it's needed.

      @seealso TVRMLGLScene.GLProjection }
    procedure ApplyProjection; virtual;

    { Render one pass, from current (saved in RenderState) camera view,
      for specific lights setup, for given TransparentGroup.

      If you want to add something 3D to your scene during rendering,
      this is the simplest method to override. (Or you can use OnRender3D
      event, which is called at the end of this method.)
      Just pass to OpenGL your 3D geometry here. }
    procedure Render3D(TransparentGroup: TTransparentGroup; InShadow: boolean); virtual;

    { Render 3D items that are never in shadows (are not shadow receivers).
      This will always be called once with tgOpaque, and once with tgTransparent
      argument, from RenderFromView. }
    procedure RenderNeverShadowed(TransparentGroup: TTransparentGroup); virtual;

    { Render shadow quads for all the things rendered by @link(Render).
      You can use here ShadowVolumeRenderer instance, which is guaranteed
      to be initialized with TGLShadowVolumeRenderer.InitFrustumAndLight,
      so you can do shadow volumes culling. }
    procedure RenderShadowVolume; virtual;

    { Render everything from current (in RenderState) camera view.
      Current RenderState.Target says to where we generate the image.
      Takes method must take care of making many rendering passes
      for shadow volumes, but doesn't take care of updating generated textures. }
    procedure RenderFromViewEverything; virtual;

    { Render the headlight. Called by RenderFromViewEverything,
      when camera matrix is set.
      Should enable or disable OpenGL GL_LIGHT0 for headlight.

      Implementation in this class uses headlight defined
      in the MainScene, following NavigationInfo.headlight and KambiHeadlight
      nodes. If MainScene is not assigned, this does nothing (doesn't touch
      GL_LIGHT0). }
    procedure RenderHeadLight; virtual;

    { Render the 3D part of scene. Called by RenderFromViewEverything at the end,
      when everything (clearing, background, headlight, loading camera
      matrix) is done and all that remains is to pass to OpenGL actual 3D world. }
    procedure RenderFromView3D; virtual;

    { Render everything (by RenderFromViewEverything) on the screen.
      Takes care to set RenderState (Target = rtScreen and camera as given),
      and takes care to apply glScissor if not FullSize,
      and calls RenderFromViewEverything.

      Takes care of using ScreenEffects. For this,
      before we render to the actual screen,
      we may render a couple times to a texture by a framebuffer. }
    procedure RenderOnScreen(ACamera: TCamera);

    { The background used during rendering.
      @nil if no background should be rendered.

      The default implementation in this class does what is usually
      most natural: return MainScene.Background, if MainScene assigned. }
    function Background: TBackgroundGL; virtual;

    { Detect position/direction of the main light that produces shadows.
      The default implementation in this class looks at
      MainScene.MainLightForShadows.

      @seealso TVRMLLightSet.MainLightForShadows
      @seealso TVRMLScene.MainLightForShadows }
    function MainLightForShadows(
      out AMainLightPosition: TVector4Single): boolean; virtual;

    procedure SetCamera(const Value: TCamera); virtual;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure SetContainer(const Value: IUIContainer); override;
    procedure SetShadowVolumesPossible(const Value: boolean); virtual;

    { Information about the 3D world.
      For scene maager, these methods simply return it's own properties.
      For TKamViewport, these methods refer to scene manager.
      @groupBegin }
    function GetItems: T3D; virtual; abstract;
    function GetMainScene: TVRMLGLScene; virtual; abstract;
    function GetShadowVolumeRenderer: TGLShadowVolumeRenderer; virtual; abstract;
    function GetMouseRayHit3D: T3D; virtual; abstract;
    function GetHeadlightCamera: TCamera; virtual; abstract;
    { @groupEnd }

    { Pass mouse move event to 3D world. }
    procedure MouseMove3D(const RayOrigin, RayDirection: TVector3Single); virtual; abstract;

    { Handle camera events.

      Scene manager implements collisions by looking at 3D scene,
      custom viewports implements collisions by calling their scene manager.

      @groupBegin }
    function CameraMoveAllowed(ACamera: TWalkCamera;
      const ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
      const BecauseOfGravity: boolean): boolean; virtual; abstract;
    procedure CameraGetHeight(ACamera: TWalkCamera;
      out IsAbove: boolean; out AboveHeight: Single;
      out AboveGround: P3DTriangle); virtual; abstract;
    procedure CameraVisibleChange(ACamera: TObject); virtual; abstract;
    { @groupEnd }

    function GetScreenEffects(const Index: Integer): TGLSLProgram; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Camera projection properties.

      When PerspectiveView is @true, then PerspectiveViewAngles
      specify angles of view (horizontal and vertical), in degrees.
      When PerspectiveView is @false, then OrthoViewDimensions
      specify dimensions of ortho window (in the order: -X, -Y, +X, +Y,
      just like X3D OrthoViewpoint.fieldOfView).

      Set by every ApplyProjection call.

      @groupBegin }
    property PerspectiveView: boolean read FPerspectiveView write FPerspectiveView;
    property PerspectiveViewAngles: TVector2Single read FPerspectiveViewAngles write FPerspectiveViewAngles;
    property OrthoViewDimensions: TVector4Single read FOrthoViewDimensions write FOrthoViewDimensions;
    { @groupEnd }

    { Projection near/far values, for Walk navigation.
      ApplyProjection calculates it.

      This is the best projection near/far for Walk mode
      (although GLProjection may use some other values for other modes
      (like Examine), it will always calculate values for Walk mode anyway.)

      WalkProjectionFar may be ZFarInfinity.

      @groupBegin }
    property WalkProjectionNear: Single read FWalkProjectionNear;
    property WalkProjectionFar : Single read FWalkProjectionFar ;
    { @groupEnd }

    procedure ContainerResize(const AContainerWidth, AContainerHeight: Cardinal); override;
    function PositionInside(const X, Y: Integer): boolean; override;
    function DrawStyle: TUIControlDrawStyle; override;

    function AllowSuspendForInput: boolean; override;
    function KeyDown(Key: TKey; C: char): boolean; override;
    function KeyUp(Key: TKey; C: char): boolean; override;
    function MouseDown(const Button: TMouseButton): boolean; override;
    function MouseUp(const Button: TMouseButton): boolean; override;
    function MouseMove(const OldX, OldY, NewX, NewY: Integer): boolean; override;
    procedure Idle(const CompSpeed: Single;
      const HandleMouseAndKeys: boolean;
      var LetOthersHandleMouseAndKeys: boolean); override;

    { Actual position and size of the viewport. Calculated looking
      at @link(FullSize) value, at the current container sizes
      (when @link(FullSize) is @false), and at the properties
      @link(Left), @link(Bottom), @link(Width), @link(Height)
      (when @link(FullSize) is true).

      @groupBegin }
    function CorrectLeft: Integer;
    function CorrectBottom: Integer;
    function CorrectWidth: Cardinal;
    function CorrectHeight: Cardinal;
    { @groupEnd }

    { Create default TCamera suitable for navigating in this scene.
      This is automatically used to initialize @link(Camera) property
      when @link(Camera) is @nil at ApplyProjection call.

      The implementation in base TKamSceneManager uses MainScene.CreateCamera
      (so it will follow your VRML/X3D scene Viewpoint, NavigationInfo and such).
      If MainScene is not assigned, we will just create a simple
      TExamineCamera.

      The implementation in TKamViewport simply calls
      SceneManager.CreateDefaultCamera. So by default all the viewport's
      cameras are created the same way, by refering to the scene manager.
      If you want you can override it to specialize CreateDefaultCamera
      for specific viewport classes. }
    function CreateDefaultCamera(AOwner: TComponent): TCamera; virtual; abstract;

    { Smoothly animate current @link(Camera) to a default camera settings.

      Default camera settings are determined by calling CreateDefaultCamera.
      See TCamera.AnimateTo for details what and how is animated.

      Current @link(Camera) is created by CreateDefaultCamera if not assigned
      yet at this point. (And the animation isn't done, since such camera
      already stands at the default position.) This makes this method
      consistent: after calling it, you always know that @link(Camera) is
      assigned and going to the default position. }
    procedure CameraAnimateToDefault(const Time: TKamTime);

    { Screen effects are shaders that post-process the rendered screen.
      If any screen effects are active, we will automatically render
      screen to a temporary texture rectangle, processing it with
      each shader.

      By default, screen effects come from GetMainScene.ScreenEffects,
      so the effects may be defined by VRML/X3D author using ScreenEffect
      nodes (see TODO docs).
      Descendants may override GetScreenEffects and ScreenEffectsCount,
      to add screen effects by code. Possibly each viewport may have it's
      own, different screen effects.

      @groupBegin }
    property ScreenEffects [Index: Integer]: TGLSLProgram read GetScreenEffects;
    function ScreenEffectsCount: Integer; virtual;
    { @groupEnd }

    procedure GLContextClose; override;
  published
    { Viewport dimensions where the 3D world will be drawn.
      When FullSize is @true (the default), the viewport always fills
      the whole container (OpenGL context area, like a window for TGLWindow),
      and the values of Left, Bottom, Width, Height are ignored here.

      @seealso CorrectLeft
      @seealso CorrectBottom
      @seealso CorrectWidth
      @seealso CorrectHeight

      @groupBegin }
    property FullSize: boolean read FFullSize write FFullSize default true;
    property Width: Cardinal read FWidth write FWidth default 0;
    property Height: Cardinal read FHeight write FHeight default 0;
    { @groupEnd }

    { Camera used to render.

      Cannot be @nil when rendering. If you don't assign anything here,
      we'll create a default camera object at the nearest ApplyProjection
      call (this is the first moment when we really must have some camera).
      This default camera will be created by CreateDefaultCamera.

      This camera @italic(should not) be inside some other container
      (like on TGLUIWindow.Controls or TKamOpenGLControl.Controls list).
      Scene manager / viewport will handle passing events to the camera on it's own,
      we will also pass our own Container to Camera.Container.
      This is desired, this way events are correctly passed
      and interpreted before passing them to 3D objects.
      And this way we avoid the question whether camera should be before
      or after the scene manager / viewport on the Controls list (as there's really
      no perfect ordering for them).

      Scene manager / viewport will "hijack" some Camera events:
      TCamera.OnVisibleChange, TWalkCamera.OnMoveAllowed,
      TWalkCamera.OnGetHeightAbove, TCamera.OnCursorChange.
      We will handle them in a proper way.

      @italic(For TKamViewport only:)
      The TKamViewport's camera is slightly less important than
      TKamSceneManager.Camera, because TKamSceneManager.Camera may be treated
      as a "central" camera. Viewport's camera may not (because you may
      have many viewports and they all deserve fair treatment).
      So e.g. headlight is done only from TKamSceneManager.Camera
      (for mirror textures, there must be one headlight for your 3D world).
      Also VRML/X3D ProximitySensors receive events only from
      TKamSceneManager.Camera.

      TODO: In the future it should be possible (even encouraged) to assign
      one of your custom viewport cameras also to TKamSceneManager.Camera.
      It should also be possible to share one camera instance among a couple
      of viewports.
      For now, it doesn't work (last viewport/scene manager will hijack some
      camera events making it not working in other ones).

      @seealso TKamSceneManager.OnCameraChanged }
    property Camera: TCamera read FCamera write SetCamera;

    { For scene manager: you can pause everything inside your 3D world,
      for viewport: you can make the camera of this viewpoint paused
      (not responsive).

      @italic(For scene manager:)

      "Paused" means that no events (key, mouse, idle) are passed to any
      @link(TKamSceneManager.Items) or the @link(Camera).
      This is suitable if you really want to totally, unconditionally,
      make your 3D world view temporary still (for example,
      useful when entering some modal dialog box and you want
      3D scene to behave as a still background).

      You can of course still directly change some scene property,
      and then 3D world will change.
      But no change will be initialized automatically by scene manager events.

      @italic(See also): For less drastic pausing methods,
      there are other methods of pausing / disabling
      some events processing for the 3D world:

      @unorderedList(
        @item(You can set TVRMLGLScene.TimePlaying or TVRMLGLAnimation.TimePlaying
          to @false. This is roughly equivalent to not running their Idle methods.
          This means that time will "stand still" for them,
          so their animations will not play. Although they may
          still react and change in response to mouse clicks / key presses,
          if TVRMLGLScene.ProcessEvents.)

        @item(You can set TVRMLGLScene.ProcessEvents to @false.
          This means that scene will not receive and process any
          key / mouse and other events (through VRML/X3D sensors).
          Some animations (not depending on VRML/X3D events processing)
          may still run, for example MovieTexture will still animate,
          if only TVRMLGLScene.TimePlaying.)

        @item(For cameras, you can set TCamera.IgnoreAllInputs to ignore
          key / mouse clicks.)
      ) }
    property Paused: boolean read FPaused write FPaused default false;

    { See Render3D method. }
    property OnRender3D: TRender3DEvent read FOnRender3D write FOnRender3D;

    { Should we make shadow volumes possible.
      This should indicate if OpenGL context was (possibly) initialized
      with stencil buffer. }
    property ShadowVolumesPossible: boolean read FShadowVolumesPossible write SetShadowVolumesPossible default false;

    { Should we render with shadow volumes.
      You can change this at any time, to switch rendering shadows on/off.

      This works only if ShadowVolumesPossible is @true.

      Note that the shadow volumes algorithm makes some requirements
      about the 3D model: it must be 2-manifold, that is have a correctly
      closed volume. Otherwise, rendering results may be bad. You can check
      Scene.BorderEdges.Count before using this: BorderEdges.Count = 0 means
      that model is Ok, correct manifold.

      For shadows to be actually used you still need a light source
      marked as the main shadows light (kambiShadows = kambiShadowsMain = TRUE),
      see [http://vrmlengine.sourceforge.net/kambi_vrml_extensions.php#section_ext_shadows]. }
    property ShadowVolumes: boolean read FShadowVolumes write FShadowVolumes default false;

    { Actually draw the shadow volumes to the color buffer, for debugging.
      If shadows are rendered (see ShadowVolumesPossible and ShadowVolumes),
      you can use this to actually see shadow volumes, for debug / demo
      purposes. Shadow volumes will be rendered on top of the scene,
      as yellow blended polygons. }
    property ShadowVolumesDraw: boolean read FShadowVolumesDraw write FShadowVolumesDraw default false;

    { If yes then the scene background will be rendered wireframe,
      over the background filled with glClearColor.

      There's a catch here: this works only if the background is actually
      internally rendered as a geometry. If the background is rendered
      by clearing the screen (this is an optimized case of sky color
      being just one simple color, and no textures),
      then it will just cover the screen as normal, like without wireframe.
      This is uncertain situation anyway (what should the wireframe
      look like in this case anyway?), so I don't consider it a bug.

      Useful especially for debugging when you want to see how your background
      geometry looks like. }
    property BackgroundWireframe: boolean
      read FBackgroundWireframe write FBackgroundWireframe default false;

    { When @true then headlight is always rendered from custom viewport's
      (TKamViewport) camera, not from central camera (the one in scene manager).
      This is meaningless in TKamSceneManager.

      By default this is @false, which means that when rendering
      custom viewport (TKamViewport) we render headlight from
      TKamViewport.SceneManager.Camera (not from current viewport's
      TKamViewport.Camera). On one hand, this is sensible: there is exactly one
      headlight in your 3D world, and it shines from a central camera
      in SceneManager.Camera. When SceneManager.Camera is @nil (which
      may happen if you set SceneManager.DefaultViewport := false and you
      didn't assign SceneManager.Camera explicitly) headlight is never done.
      This means that when observing 3D world from other cameras,
      you will see a light shining from SceneManager.Camera.
      This is also the only way to make headlight lighting correctly reflected
      in mirror textures (like GeneratedCubeMapTexture) --- since we render
      to one mirror texture, we need a knowledge of "cental" camera for this.

      When this is @true, then each viewport actually renders headlight
      from it's current camera. This means that actually each viewport
      has it's own, independent headlight (althoug they all follow VRML/X3D
      NavigationInfo.headlight and KambiNavigationInfo settings).
      This may allow you to light your view better (if you only use
      headlight to "just make the view brighter"), but it's not entirely
      correct (in particular, mirror reflections of the headlight are
      undefined then). }
    property HeadlightFromViewport: boolean
      read FHeadlightFromViewport write FHeadlightFromViewport default false;

    { If @false, then we can assume that we're the only thing controlling
      OpenGL projection matrix. This means that we're the only viewport,
      and you do not change OpenGL projection matrix yourself.

      By default for custom viewports this is @true,
      which is safer solution (we always apply
      OpenGL projection matrix in ApplyProjection method), but also may
      be slightly slower.

      Note that for TKamSceneManager, this is by default @false (that is,
      we assume that scene manager, if used for rendering at all
      (DefaultViewport = @true), is the only viewport). You should change
      AlwaysApplyProjection to @true for TKamSceneManager, if you have
      both custom viewports and DefaultViewport = @true }
    property AlwaysApplyProjection: boolean
      read FAlwaysApplyProjection write FAlwaysApplyProjection default true;
  end;

  TObjectsListItem_1 = TKamAbstractViewport;
  {$I objectslist_1.inc}
  TKamAbstractViewportsList = class(TObjectsList_1)
  public
    { Does any viewport on the list has shadow volumes all set up? }
    function UsesShadowVolumes: boolean;
  end;

  { Scene manager that knows about all 3D things inside your world.

    Single scenes/models (like TVRMLGLScene or TVRMLGLAnimation instances)
    can be rendered directly, but it's not always comfortable.
    Scenes have to assume that they are "one of the many" inside your 3D world,
    which means that multi-pass rendering techniques have to be implemented
    at a higher level. This concerns the need for multiple passes from
    the same camera (for shadow volumes) and multiple passes from different
    cameras (for generating textures for shadow maps, cube map environment etc.).

    Scene manager overcomes this limitation. A single SceneManager object
    knows about all 3D things in your world, and renders them all for you,
    taking care of doing multiple rendering passes for particular features.
    Naturally, it also serves as container for all your visible 3D scenes.

    @link(Items) property keeps a tree of T3D objects.
    All our 3D objects, like TVRMLScene (and so also TVRMLGLScene)
    and TVRMLAnimation (and so also TVRMLGLAnimation) descend from
    T3D, and you can add them to the scene manager.
    And naturally you can implement your own T3D descendants,
    representing any 3D (possibly dynamic, animated and even interactive) object.

    TKamSceneManager.Render can assume that it's the @italic(only) manager rendering
    to the screen (although you can safely render more 3D geometry *after*
    calling TKamSceneManager.Render). So it's Render method takes care of

    @unorderedList(
      @item(clearing the screen,)
      @item(rendering the background of the scene,)
      @item(rendering the headlight,)
      @item(rendering the scene from given camera,)
      @item(and making multiple passes for shadow volumes and generated textures.)
    )

    For some of these features, you'll have to set the @link(MainScene) property.

    This is a TUIControl descendant, which means it's adviced usage
    is to add this to TGLUIWindow.Controls or TKamOpenGLControl.Controls.
    This passes relevant TUIControl events to all the T3D objects inside.
    Note that even when you set DefaultViewport = @false
    (and use custom viewports, by TKamViewport class, to render your 3D world),
    you still should add scene manager to the controls list
    (this allows e.g. 3D items to receive Idle events). }
  TKamSceneManager = class(TKamAbstractViewport)
  private
    FMainScene: TVRMLGLScene;
    FItems: T3DList;
    FDefaultViewport: boolean;
    FViewports: TKamAbstractViewportsList;

    FOnCameraChanged: TNotifyEvent;
    FOnBoundViewpointChanged: TNotifyEvent;
    FCameraBox: TBox3D;
    FShadowVolumeRenderer: TGLShadowVolumeRenderer;

    FMouseRayHit: T3DCollision;

    FMouseRayHit3D: T3D;

    { calculated by every PrepareResources }
    ChosenViewport: TKamAbstractViewport;
    NeedsUpdateGeneratedTextures: boolean;

    { Call at the beginning of Draw (from both scene manager and custom viewport),
      to make sure UpdateGeneratedTextures was done before actual drawing. }
    procedure UpdateGeneratedTexturesIfNeeded;

    procedure SetMainScene(const Value: TVRMLGLScene);
    procedure SetDefaultViewport(const Value: boolean);

    procedure ItemsVisibleChange(Sender: T3D; Changes: TVisibleChanges);

    { scene callbacks }
    procedure SceneBoundViewpointChanged(Scene: TVRMLScene);
    procedure SceneBoundViewpointVectorsChanged(Scene: TVRMLScene);

    procedure SetMouseRayHit3D(const Value: T3D);
    property MouseRayHit3D: T3D read FMouseRayHit3D write SetMouseRayHit3D;
  protected
    procedure SetCamera(const Value: TCamera); override;

    { Triangles to ignore by all collision detection in scene manager.
      The default implementation in this class resturns always @false,
      so nothing is ignored. You can override it e.g. to ignore your "water"
      material, when you want player to dive under the water. }
    function CollisionIgnoreItem(const Sender: TObject;
      const Triangle: P3DTriangle): boolean; virtual;

    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    function CameraMoveAllowed(ACamera: TWalkCamera;
      const ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
      const BecauseOfGravity: boolean): boolean; override;
    procedure CameraGetHeight(ACamera: TWalkCamera;
      out IsAbove: boolean; out AboveHeight: Single;
      out AboveGround: P3DTriangle); override;
    procedure CameraVisibleChange(ACamera: TObject); override;

    function GetItems: T3D; override;
    function GetMainScene: TVRMLGLScene; override;
    function GetShadowVolumeRenderer: TGLShadowVolumeRenderer; override;
    function GetMouseRayHit3D: T3D; override;
    function GetHeadlightCamera: TCamera; override;
    procedure MouseMove3D(const RayOrigin, RayDirection: TVector3Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure GLContextInit; override;
    procedure GLContextClose; override;
    function PositionInside(const X, Y: Integer): boolean; override;

    { Prepare resources, to make various methods (like @link(Render))
      execute fast.

      If DisplayProgressTitle <> '', we will display progress bar during
      loading. This is especially useful for long precalculated animations
      (TVRMLGLAnimation with a lot of ScenesCount), they show nice
      linearly increasing progress bar. }
    procedure PrepareResources(const DisplayProgressTitle: string = '');

    procedure BeforeDraw; override;
    procedure Draw; override;

    { What changes happen when viewer camera changes.
      You may want to use it when calling Scene.ViewerChanges.

      Implementation in this class is correlated with RenderHeadlight. }
    function ViewerToChanges: TVisibleChanges; virtual;

    procedure Idle(const CompSpeed: Single;
      const HandleMouseAndKeys: boolean;
      var LetOthersHandleMouseAndKeys: boolean); override;

    function CreateDefaultCamera(AOwner: TComponent): TCamera; override;

    { If non-empty, then camera position will be limited to this box.

      When this property specifies an EmptyBox3D (the default value),
      camera position is limited to not fall because of gravity
      below minimal 3D world plane. That is, viewer can freely move
      around in 3D world, he/she only cannot fall below "minimal plane"
      when falling is caused by the gravity. "Minimal plane" is derived from
      GravityUp and Items.BoundingBox. }
    property CameraBox: TBox3D read FCameraBox write FCameraBox;

    { Renderer of shadow volumes. You can use this to optimize rendering
      of your shadow quads in RenderShadowVolume, and you can control
      it's statistics (TGLShadowVolumeRenderer.Count and related properties).

      This is internally initialized by scene manager. It's @nil when
      OpenGL context is not yet initialized (or scene manager is not
      added to @code(Controls) list yet). }
    property ShadowVolumeRenderer: TGLShadowVolumeRenderer
      read FShadowVolumeRenderer;

    { Current 3D objects under the mouse cursor.
      Updated in every mouse move. }
    property MouseRayHit: T3DCollision read FMouseRayHit;

    { List of viewports connected to this scene manager.
      This contains all TKamViewport instances that have
      TKamViewport.SceneManager set to us. Also it contains Self
      (this very scene manager) if and only if DefaultViewport = @true
      (because when DefaultViewport, scene manager acts as an
      additional viewport too).

      This list is read-only from the outside! It's automatically managed
      in this unit (when you change TKamViewport.SceneManager
      or TKamSceneManager.DefaultViewport, we automatically update this list
      as appropriate). }
    property Viewports: TKamAbstractViewportsList read FViewports;
  published
    { Tree of 3D objects within your world. This is the place where you should
      add your scenes to have them handled by scene manager.
      You may also set your main TVRMLGLScene (if you have any) as MainScene.

      T3DList is also T3D instance, so yes --- this may be a tree
      of T3D, not only a flat list.

      Note that scene manager "hijacks" T3D callbacks T3D.OnCursorChange and
      T3D.OnVisibleChange. }
    property Items: T3DList read FItems;

    { The main scene of your 3D world. It's not necessary to set this
      (after all, your 3D world doesn't even need to have any TVRMLGLScene
      instance). This @italic(must be) also added to our @link(Items)
      (otherwise things will work strangely).

      When set, this is used for a couple of things:

      @unorderedList(
        @item Decides what headlight is used (by TVRMLGLScene.Headlight).

        @item(Decides what background is rendered.
          Althuogh you can override this by overriding @link(Background)
          method.)

        @item(Decides if, and where, the main light casting shadows is.
          Although you can override this by overriding @link(MainLightForShadows)
          method.)

        @item Determines OpenGL projection for the scene, see ApplyProjection.

        @item(Synchronizes our @link(Camera) with VRML/X3D viewpoints.
          This means that @link(Camera) will be updated when VRML/X3D events
          change current Viewpoint, for example you can animate the camera
          by animating viewpoint (or it's transformation) or bind camera
          to a viewpoint.

          Note that scene manager "hijacks" some Scene events:
          TVRMLScene.OnBoundViewpointVectorsChanged and TVRMLScene.ViewpointStack.OnBoundChanged
          for this purpose. If you want to know when viewpoint changes,
          you can use scene manager's event OnBoundViewpointChanged.)
      )

      The above stuff is only sensible when done once per scene manager,
      that's why we need MainScene property to indicate this.
      (We cannot just use every 3D object from @link(Items) for this.)

      Freeing MainScene will automatically set this to @nil. }
    property MainScene: TVRMLGLScene read FMainScene write SetMainScene;

    { Called on any camera change. Exactly when TCamera generates it's
      OnVisibleChange event. }
    property OnCameraChanged: TNotifyEvent read FOnCameraChanged write FOnCameraChanged;

    { Called when bound Viewpoint node changes. This is called exactly when
      TVRMLScene.ViewpointStack.OnBoundChanged is called. }
    property OnBoundViewpointChanged: TNotifyEvent read FOnBoundViewpointChanged write FOnBoundViewpointChanged;

    { Should we render the 3D world in a default viewport that covers
      the whole window. This is usually what you want. For more complicated
      uses, you can turn this off, and use explicit TKamViewport
      (connected to this scene manager by TKamViewport.SceneManager property)
      for making your world visible. }
    property DefaultViewport: boolean
      read FDefaultViewport write SetDefaultViewport default true;

    property AlwaysApplyProjection default false;
  end;

  { Custom 2D viewport showing 3D world. This uses assigned SceneManager
    to show 3D world on the screen.

    For simple games, using this is not needed, because TKamSceneManager
    also acts as a viewport (when TKamSceneManager.DefaultViewport is @true,
    which is the default).
    Using custom viewports (implemented by this class)
    is useful when you want to have more than one viewport showing
    the same 3D world. Different viewports may have different cameras,
    but they always share the same 3D world (in scene manager).

    You can control the size of this viewport by FullSize, @link(Left),
    @link(Bottom), @link(Width), @link(Height) properties. For custom
    viewports, you often want to set FullSize = @false
    and control viewport's position and size explicitly.

    Example usages:
    in a typical 3D modeling programs, you like to have 4 viewports
    with 4 different cameras (front view, side view, top view,
    and free perspective view). See examples/vrml/multiple_viewports.lpr
    in engine sources for demo of this. Or when you make a split-screen game,
    played by 2 people on a single monitor.

    Viewports may be overlapping, that is one viewport may (partially)
    obscure another viewport. Just like with any other TUIControl,
    position of viewport on the Controls list
    (like TKamOpenGLControl.Controls or TGLUIWindow.Controls)
    is important: Controls are specified in the front-to-back order.
    That is, if the viewport X may obscure viewport Y,
    then X must be before Y on the Controls list.

    Example usage of overlapping viewports:
    imagine a space shooter, like Epic or Wing Commander.
    You can imagine that a camera is mounted on each rocket fired
    by the player.
    You can display in one viewport (with FullSize = @true) normal
    (first person) view from your space ship.
    And additionally you can place a small viewport
    (with FullSize = @false and small @link(Width) / @link(Height))
    in the upper-right corner that displays view from last fired rocket. }
  TKamViewport = class(TKamAbstractViewport)
  private
    FSceneManager: TKamSceneManager;
    procedure SetSceneManager(const Value: TKamSceneManager);
  protected
    function GetItems: T3D; override;
    function GetMainScene: TVRMLGLScene; override;
    function GetShadowVolumeRenderer: TGLShadowVolumeRenderer; override;
    function GetMouseRayHit3D: T3D; override;
    function GetHeadlightCamera: TCamera; override;
    procedure MouseMove3D(const RayOrigin, RayDirection: TVector3Single); override;

    function CameraMoveAllowed(ACamera: TWalkCamera;
      const ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
      const BecauseOfGravity: boolean): boolean; override;
    procedure CameraGetHeight(ACamera: TWalkCamera;
      out IsAbove: boolean; out AboveHeight: Single;
      out AboveGround: P3DTriangle); override;
    procedure CameraVisibleChange(ACamera: TObject); override;
  public
    destructor Destroy; override;

    procedure Draw; override;

    function CreateDefaultCamera(AOwner: TComponent): TCamera; override;
  published
    property SceneManager: TKamSceneManager read FSceneManager write SetSceneManager;
  end;

procedure Register;

{$undef read_interface}

implementation

uses SysUtils, RenderStateUnit, KambiGLUtils, ProgressUnit, RaysWindow, GLExt,
  KambiLog;

{$define read_implementation}
{$I objectslist_1.inc}

procedure Register;
begin
  RegisterComponents('Kambi', [TKamSceneManager]);
end;

{ TKamAbstractViewport ------------------------------------------------------- }

constructor TKamAbstractViewport.Create(AOwner: TComponent);
begin
  inherited;
  FFullSize := true;
  FAlwaysApplyProjection := true;
end;

destructor TKamAbstractViewport.Destroy;
begin
  { unregister self from Camera callbacs, etc.

    This includes setting FCamera to nil.
    Yes, this setting FCamera to nil is needed, it's not just paranoia.

    Consider e.g. when our Camera is owned by Self
    (e.g. because it was created in ApplyProjection by CreateDefaultCamera).
    This means that this camera will be freed in "inherited" destructor call
    below. Since we just did FCamera.RemoveFreeNotification, we would have
    no way to set FCamera to nil, and FCamera would then remain as invalid
    pointer.

    And when SceneManager is freed it sends a free notification
    (this is also done in "inherited" destructor) to TGLUIWindow instance,
    which causes removing us from TGLUIWindow.Controls list,
    which causes SetContainer(nil) call that tries to access Camera.

    This scenario would cause segfault, as FCamera pointer is invalid
    at this time. }
  Camera := nil;

  inherited;
end;

procedure TKamAbstractViewport.SetCamera(const Value: TCamera);
begin
  if FCamera <> Value then
  begin
    if FCamera <> nil then
    begin
      FCamera.OnVisibleChange := nil;
      FCamera.OnCursorChange := nil;
      if FCamera is TWalkCamera then
      begin
        TWalkCamera(FCamera).OnMoveAllowed := nil;
        TWalkCamera(FCamera).OnGetHeightAbove := nil;
      end;

      FCamera.RemoveFreeNotification(Self);
      FCamera.Container := nil;
    end;

    FCamera := Value;

    if FCamera <> nil then
    begin
      { Unconditionally change FCamera.OnVisibleChange callback,
        to override TGLUIWindow / TKamOpenGLControl that also try
        to "hijack" this camera's event. }
      FCamera.OnVisibleChange := @CameraVisibleChange;
      FCamera.OnCursorChange := @ItemsAndCameraCursorChange;
      if FCamera is TWalkCamera then
      begin
        TWalkCamera(FCamera).OnMoveAllowed := @CameraMoveAllowed;
        TWalkCamera(FCamera).OnGetHeightAbove := @CameraGetHeight;
      end;

      FCamera.FreeNotification(Self);
      FCamera.Container := Container;
      if ContainerSizeKnown then
        FCamera.ContainerResize(ContainerWidth, ContainerHeight);
    end;

    ApplyProjectionNeeded := true;
  end;
end;

procedure TKamAbstractViewport.SetContainer(const Value: IUIContainer);
begin
  inherited;

  { Keep Camera.Container always the same as our Container }
  if Camera <> nil then
    Camera.Container := Container;
end;

procedure TKamAbstractViewport.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;

  if Operation = opRemove then
  begin
    if AComponent = FCamera then
    begin
      { set to nil by SetCamera, to clean nicely }
      Camera := nil;
      { Need ApplyProjection, to create new default camera before rendering. }
      ApplyProjectionNeeded := true;
    end;
  end;
end;

procedure TKamAbstractViewport.ContainerResize(const AContainerWidth, AContainerHeight: Cardinal);
begin
  inherited;

  ApplyProjectionNeeded := true;

  if Camera <> nil then
    Camera.ContainerResize(AContainerWidth, AContainerHeight);
end;

function TKamAbstractViewport.KeyDown(Key: TKey; C: char): boolean;
begin
  Result := inherited;
  if Result or Paused then Exit;

  if Camera <> nil then
  begin
    Result := Camera.KeyDown(Key, C);
    if Result then Exit;
  end;

  Result := GetItems.KeyDown(Key, C);
end;

function TKamAbstractViewport.KeyUp(Key: TKey; C: char): boolean;
begin
  Result := inherited;
  if Result or Paused then Exit;

  if Camera <> nil then
  begin
    Result := Camera.KeyUp(Key, C);
    if Result then Exit;
  end;

  Result := GetItems.KeyUp(Key, C);
end;

function TKamAbstractViewport.MouseDown(const Button: TMouseButton): boolean;
begin
  Result := inherited;
  if Result or Paused then Exit;

  if Camera <> nil then
  begin
    Result := Camera.MouseDown(Button);
    if Result then Exit;
  end;

  Result := GetItems.MouseDown(Button);
end;

function TKamAbstractViewport.MouseUp(const Button: TMouseButton): boolean;
begin
  Result := inherited;
  if Result or Paused then Exit;

  if Camera <> nil then
  begin
    Result := Camera.MouseUp(Button);
    if Result then Exit;
  end;

  Result := GetItems.MouseUp(Button);
end;

function TKamAbstractViewport.MouseMove(const OldX, OldY, NewX, NewY: Integer): boolean;
var
  RayOrigin, RayDirection: TVector3Single;
begin
  Result := inherited;
  if (not Result) and (not Paused) and (Camera <> nil) then
  begin
    Result := Camera.MouseMove(OldX, OldY, NewX, NewY);
    if not Result then
    begin
      Camera.CustomRay(
        CorrectLeft, CorrectBottom, CorrectWidth, CorrectHeight, ContainerHeight,
        NewX, NewY, PerspectiveView, PerspectiveViewAngles, OrthoViewDimensions,
        RayOrigin, RayDirection);
      MouseMove3D(RayOrigin, RayDirection);
    end;
  end;

  { update the cursor, since 3D object the cursor possibly changed.

    Accidentaly, this also workaround the problem of TKamViewport:
    when the 3D object stayed the same but it's Cursor value changed,
    Items.OnCursorChange notify only TKamSceneManager (not custom viewport).
    But thanks to doing ItemsAndCameraCursorChange below, this isn't
    a problem for now, as we'll update cursor anyway, as long as it changes
    only during mouse move. }
  ItemsAndCameraCursorChange(Self);
end;

procedure TKamAbstractViewport.ItemsAndCameraCursorChange(Sender: TObject);
begin
  { We have to treat Camera.Cursor specially:
    - mcNone because of mouse look means result in unconditionally mcNone.
      Other Items.Cursor, MainScene.Cursor etc. is ignored then.
    - otherwise, Camera.Cursor is ignored, show 3D objects cursor. }
  if (Camera <> nil) and (Camera.Cursor = mcNone) then
  begin
    Cursor := mcNone;
    Exit;
  end;

  { We show mouse cursor from top-most 3D object.
    This is sensible, if multiple 3D scenes obscure each other at the same
    pixel --- the one "on the top" (visible by the player at that pixel)
    determines the mouse cursor. }

  if GetMouseRayHit3D <> nil then
  begin
    Cursor := GetMouseRayHit3D.Cursor;
  end else
    Cursor := mcDefault;
end;

procedure TKamAbstractViewport.Idle(const CompSpeed: Single;
  const HandleMouseAndKeys: boolean;
  var LetOthersHandleMouseAndKeys: boolean);
begin
  inherited;

  if Paused then
  begin
    LetOthersHandleMouseAndKeys := true;
    Exit;
  end;

  { As for LetOthersHandleMouseAndKeys: let Camera decide it.
    By default, camera has ExclusiveEvents = false and will let
    LetOthersHandleMouseAndKeys remain = true, that's Ok.

    Our Items do not have HandleMouseAndKeys or LetOthersHandleMouseAndKeys
    stuff, as it would not be controllable for them: 3D objects do not
    have strict front-to-back order, so we would not know in what order
    call their Idle methods, so we have to let many Items handle keys anyway.
    So, it's consistent to just treat 3D objects as "cannot definitely
    mark keys/mouse as handled". Besides, currently 3D objects do not
    get Pressed information at all. }

  if Camera <> nil then
  begin
    LetOthersHandleMouseAndKeys := not Camera.ExclusiveEvents;
    Camera.Idle(CompSpeed, HandleMouseAndKeys, LetOthersHandleMouseAndKeys);
  end else
    LetOthersHandleMouseAndKeys := true;
end;

function TKamAbstractViewport.AllowSuspendForInput: boolean;
begin
  Result := (Camera = nil) or Paused or Camera.AllowSuspendForInput;
end;

function TKamAbstractViewport.CorrectLeft: Integer;
begin
  if FullSize then Result := 0 else Result := Left;
end;

function TKamAbstractViewport.CorrectBottom: Integer;
begin
  if FullSize then Result := 0 else Result := Bottom;
end;

function TKamAbstractViewport.CorrectWidth: Cardinal;
begin
  if FullSize then Result := ContainerWidth else Result := Width;
end;

function TKamAbstractViewport.CorrectHeight: Cardinal;
begin
  if FullSize then Result := ContainerHeight else Result := Height;
end;

function TKamAbstractViewport.PositionInside(const X, Y: Integer): boolean;
begin
  Result :=
    FullSize or
    ( (X >= Left) and
      (X  < Left + Width) and
      (ContainerHeight - Y >= Bottom) and
      (ContainerHeight - Y  < Bottom + Height) );
end;

procedure TKamAbstractViewport.ApplyProjection;
var
  Box: TBox3D;

  procedure DefaultGLProjection;
  var
    ProjectionMatrix: TMatrix4f;
  begin
    FPerspectiveView := true;
    FPerspectiveViewAngles[1] := 45.0;
    FPerspectiveViewAngles[0] := AdjustViewAngleDegToAspectRatio(
      FPerspectiveViewAngles[1], CorrectWidth / CorrectHeight);

    glViewport(CorrectLeft, CorrectBottom, CorrectWidth, CorrectHeight);
    ProjectionGLPerspective(PerspectiveViewAngles[1], CorrectWidth / CorrectHeight,
      Box3DAvgSize(Box, 1.0) * 0.01,
      Box3DMaxSize(Box, 1.0) * 10.0);

    { update Camera.ProjectionMatrix }
    glGetFloatv(GL_PROJECTION_MATRIX, @ProjectionMatrix);
    Camera.ProjectionMatrix := ProjectionMatrix;
  end;

begin
  if Camera = nil then
    Camera := CreateDefaultCamera(Self);

  if AlwaysApplyProjection or ApplyProjectionNeeded then
  begin
    { We need to know container size now.
      This assertion can break only if you misuse UseControls property, setting it
      to false (disallowing ContainerResize), and then trying to use
      PrepareResources or Render (that call ApplyProjection). }
    Assert(ContainerSizeKnown, ClassName + ' did not receive ContainerResize event yet, cannnot apply OpenGL projection');

    Box := GetItems.BoundingBox;

    if GetMainScene <> nil then
      GetMainScene.GLProjection(Camera, Box,
        CorrectLeft, CorrectBottom, CorrectWidth, CorrectHeight, ShadowVolumesPossible,
        FPerspectiveView, FPerspectiveViewAngles, FOrthoViewDimensions,
        FWalkProjectionNear, FWalkProjectionFar) else
      DefaultGLProjection;

    ApplyProjectionNeeded := false;
  end;
end;

procedure TKamAbstractViewport.SetShadowVolumesPossible(const Value: boolean);
begin
  if ShadowVolumesPossible <> Value then
  begin
    FShadowVolumesPossible := Value;
    ApplyProjectionNeeded := true;
  end;
end;

function TKamAbstractViewport.Background: TBackgroundGL;
begin
  if GetMainScene <> nil then
    Result := GetMainScene.Background else
    Result := nil;
end;

function TKamAbstractViewport.MainLightForShadows(
  out AMainLightPosition: TVector4Single): boolean;
begin
  if GetMainScene <> nil then
    Result := GetMainScene.MainLightForShadows(AMainLightPosition) else
    Result := false;
end;

procedure TKamAbstractViewport.Render3D(TransparentGroup: TTransparentGroup; InShadow: boolean);
begin
  GetItems.Render(RenderState.CameraFrustum, TransparentGroup, InShadow);
  if Assigned(OnRender3D) then
    OnRender3D(Self, TransparentGroup, InShadow);
end;

procedure TKamAbstractViewport.RenderShadowVolume;
begin
  GetItems.RenderShadowVolume(GetShadowVolumeRenderer, true, IdentityMatrix4Single);
end;

procedure TKamAbstractViewport.RenderHeadLight;
var
  HC: TCamera;
begin
  if GetMainScene <> nil then
  begin
    if HeadlightFromViewport then
      HC := Camera else
      HC := GetHeadlightCamera;

    { GetHeadlightCamera (SceneManager.Camera) may be nil here, when
      rendering is done by a custom viewport and HeadlightFromViewport = false.
      So check HC <> nil.
      When nil we have to assume headlight doesn't shine.

      We don't want to use camera settings from current viewport
      (unless HeadlightFromViewport = true, which is a hack).
      This would mean that mirror textures (like GeneratedCubeMapTexture)
      will need to have different contents in different viewpoints,
      which isn't possible. We also want to use scene manager's camera,
      to have it tied with scene manager's ViewerToChanges implementation.

      So if you use custom viewports and want headlight Ok,
      be sure to explicitly set TKamSceneManager.Camera
      (probably, to one of your viewpoints' cameras).
      Or use a hacky HeadlightFromViewport. }

    if HC <> nil then
      TVRMLGLHeadlight.RenderOrDisable(GetMainScene.Headlight,
        0, (RenderState.Target = rtScreen) and (HC = Camera), HC);
  end;

  { if MainScene = nil, do not control GL_LIGHT0 here. }
end;

procedure TKamAbstractViewport.RenderNeverShadowed(TransparentGroup: TTransparentGroup);
begin
  { Nothing to do in this class }
end;

procedure TKamAbstractViewport.RenderFromView3D;

  procedure RenderNoShadows;
  begin
    { We must first render all non-transparent objects,
      then all transparent objects. Otherwise transparent objects
      (that must be rendered without updating depth buffer) could get brutally
      covered by non-transparent objects (that are in fact further away from
      the camera). }

    RenderNeverShadowed(tgOpaque);
    Render3D(tgOpaque, false);
    Render3D(tgTransparent, false);
    RenderNeverShadowed(tgTransparent);
  end;

  procedure RenderWithShadows(const MainLightPosition: TVector4Single);
  begin
    GetShadowVolumeRenderer.InitFrustumAndLight(RenderState.CameraFrustum, MainLightPosition);
    GetShadowVolumeRenderer.Render(@RenderNeverShadowed, @Render3D, @RenderShadowVolume, ShadowVolumesDraw);
  end;

var
  MainLightPosition: TVector4Single;
begin
  if ShadowVolumesPossible and
     ShadowVolumes and
     MainLightForShadows(MainLightPosition) then
    RenderWithShadows(MainLightPosition) else
    RenderNoShadows;
end;

procedure TKamAbstractViewport.RenderFromViewEverything;
var
  ClearBuffers: TGLbitfield;
  UsedBackground: TBackgroundGL;
  MainLightPosition: TVector4Single; { ignored }
begin
  ClearBuffers := GL_DEPTH_BUFFER_BIT;

  if RenderState.Target = rtVarianceShadowMap then
  begin
    { When rendering to VSM, we want to clear the screen to max depths (1, 1^2). }
    ClearBuffers := ClearBuffers or GL_COLOR_BUFFER_BIT;
    glPushAttrib(GL_COLOR_BUFFER_BIT);
    glClearColor(1.0, 1.0, 0.0, 1.0); // saved by GL_COLOR_BUFFER_BIT
  end else
  begin
    UsedBackground := Background;
    if UsedBackground <> nil then
    begin
      glLoadMatrix(RenderState.CameraRotationMatrix);

      if BackgroundWireframe then
      begin
        { Color buffer needs clear *now*, before drawing background. }
        glClear(GL_COLOR_BUFFER_BIT);
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
        try
          UsedBackground.Render;
        finally glPolygonMode(GL_FRONT_AND_BACK, GL_FILL); end;
      end else
        UsedBackground.Render;
    end else
      ClearBuffers := ClearBuffers or GL_COLOR_BUFFER_BIT;
  end;

  if ShadowVolumesPossible and
     ShadowVolumes and
     MainLightForShadows(MainLightPosition) then
    ClearBuffers := ClearBuffers or GL_STENCIL_BUFFER_BIT;

  glClear(ClearBuffers);

  if RenderState.Target = rtVarianceShadowMap then
    glPopAttrib;

  glLoadMatrix(RenderState.CameraMatrix);

  RenderHeadLight;

  RenderFromView3D;
end;

procedure RenderScreenEffect(ViewportPtr: Pointer);
var
  Viewport: TKamAbstractViewport absolute ViewportPtr;
begin
  with Viewport do
  begin
    glLoadIdentity();
    { Although shaders will typically ignore glColor, for consistency
      we want to have a fully determined state. That is, this must work
      reliably even if you comment out ScreenEffects[*].Enable/Disable
      commands below. }
    { TODO: for now only 1 effect }
    glColor3f(1, 1, 1);
    ScreenEffects[0].Enable;
      ScreenEffects[0].SetUniform('screen', 0);
      glBegin(GL_QUADS);
        glTexCoord2i(0, 0);
        glVertex2i(0, 0);
        glTexCoord2i(ScreenEffectTextureWidth, 0);
        glVertex2i(CorrectWidth, 0);
        glTexCoord2i(ScreenEffectTextureWidth, ScreenEffectTextureHeight);
        glVertex2i(CorrectWidth, CorrectHeight);
        glTexCoord2i(0, ScreenEffectTextureHeight);
        glVertex2i(0, CorrectHeight);
      glEnd();
    ScreenEffects[0].Disable;
  end;
end;

procedure TKamAbstractViewport.RenderOnScreen(ACamera: TCamera);
begin
  RenderState.Target := rtScreen;
  RenderState.CameraFromCameraObject(ACamera);

  if GL_ARB_texture_rectangle and (ScreenEffectsCount <> 0) then
  begin
    { We need a temporary texture rectangle, for screen effect. }
    if (ScreenEffectTexture = 0) or
       (ScreenEffectRTT = nil) or
       (ScreenEffectTextureWidth  <> CorrectWidth ) or
       (ScreenEffectTextureHeight <> CorrectHeight) then
    begin
      glFreeTexture(ScreenEffectTexture);
      FreeAndNil(ScreenEffectRTT);

      { create new texture rectangle. }
      glGenTextures(1, @ScreenEffectTexture);
      glBindTexture(GL_TEXTURE_RECTANGLE_ARB, ScreenEffectTexture);
      ScreenEffectTextureWidth := CorrectWidth;
      ScreenEffectTextureHeight := CorrectHeight;
      { TODO: or GL_LINEAR? Allow to config this and eventually change
        before each screen effect? }
      glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, KamGL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, KamGL_CLAMP_TO_EDGE);
      { We never load image contents, so we also do not have to care about
        pixel packing. }
      glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGB8,
        ScreenEffectTextureWidth,
        ScreenEffectTextureHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, nil);

      { create new TGLRenderToTexture (usually, framebuffer object) }
      ScreenEffectRTT := TGLRenderToTexture.Create(
        ScreenEffectTextureWidth, ScreenEffectTextureHeight);
      ScreenEffectRTT.SetTexture(ScreenEffectTexture, GL_TEXTURE_RECTANGLE_ARB);
      ScreenEffectRTT.CompleteTextureTarget := GL_TEXTURE_RECTANGLE_ARB;
      ScreenEffectRTT.GLContextInit;

      if Log then
        WritelnLog('Screen effects', Format('Created texture rectangle for screen effects, with size %d x %d',
          [ ScreenEffectTextureWidth,
            ScreenEffectTextureHeight ]));
    end;

    ScreenEffectRTT.RenderBegin;
    { We have to adjust glViewport }
    if not FullSize then
      glViewport(0, 0, CorrectWidth, CorrectHeight);
    RenderFromViewEverything;
    { Restore glViewport set by ApplyProjection }
    if not FullSize then
      glViewport(CorrectLeft, CorrectBottom, CorrectWidth, CorrectHeight);
    ScreenEffectRTT.RenderEnd;

    glPushAttrib(GL_ENABLE_BIT);
      glDisable(GL_LIGHTING);
      glDisable(GL_DEPTH_TEST);
      glDisable(GL_TEXTURE_2D);
      glBindTexture(GL_TEXTURE_RECTANGLE_ARB, ScreenEffectTexture);
      glEnable(GL_TEXTURE_RECTANGLE_ARB);
      { Note that there's no need to worry about CorrectLeft / CorrectBottom,
        here or inside RenderScreenEffect, because we're already within
        glViewport that takes care of this. }
      glProjectionPushPopOrtho2D(@RenderScreenEffect, Self, 0, CorrectWidth, 0, CorrectHeight);
      glDisable(GL_TEXTURE_RECTANGLE_ARB); // TODO: should be done by glPopAttrib, right? enable_bit contains it?
    glPopAttrib;
  end else
  begin
    { Rendering directly to the screen, when no screen effects are used. }
    if not FullSize then
    begin
      glPushAttrib(GL_SCISSOR_BIT);
        { Use Scissor to limit what glClear clears. }
        glScissor(Left, Bottom, Width, Height); // saved by GL_SCISSOR_BIT
        glEnable(GL_SCISSOR_TEST); // saved by GL_SCISSOR_BIT
    end;

    RenderFromViewEverything;

    if not FullSize then
      glPopAttrib;
  end;
end;

function TKamAbstractViewport.DrawStyle: TUIControlDrawStyle;
begin
  Result := ds3D;
end;

function TKamAbstractViewport.GetScreenEffects(const Index: Integer): TGLSLProgram;
begin
  Result := nil; { no Index is valid, since ScreenEffectsCount = 0 in this class }
  { TODO: use GetMainScene.ScreenEffects[Index] }
end;

function TKamAbstractViewport.ScreenEffectsCount: Integer;
begin
  Result := 0;
  { TODO: use GetMainScene.ScreenEffectsCount }
end;

procedure TKamAbstractViewport.GLContextClose;
begin
  glFreeTexture(ScreenEffectTexture);
  FreeAndNil(ScreenEffectRTT);
  inherited;
end;

procedure TKamAbstractViewport.CameraAnimateToDefault(const Time: TKamTime);
var
  DefCamera: TCamera;
begin
  if Camera = nil then
    Camera := CreateDefaultCamera(nil) else
  begin
    DefCamera := CreateDefaultCamera(nil);
    try
      Camera.AnimateTo(DefCamera, Time);
    finally FreeAndNil(DefCamera) end;
  end;
end;

{ TKamAbstractViewportsList -------------------------------------------------- }

function TKamAbstractViewportsList.UsesShadowVolumes: boolean;
var
  I: Integer;
  MainLightPosition: TVector4Single; { ignored }
  V: TKamAbstractViewport;
begin
  for I := 0 to High do
  begin
    V := Items[I];
    if V.ShadowVolumesPossible and
       V.ShadowVolumes and
       V.MainLightForShadows(MainLightPosition) then
      Exit(true);
  end;
  Result := false;
end;

{ TKamSceneManager ----------------------------------------------------------- }

constructor TKamSceneManager.Create(AOwner: TComponent);
begin
  inherited;

  FItems := T3DList.Create(Self);
  FItems.OnVisibleChangeHere := @ItemsVisibleChange;
  FItems.OnCursorChange := @ItemsAndCameraCursorChange;
  { Items is displayed and streamed with TKamSceneManager
    (and in the future this should allow design Items.List by IDE),
    so set some sensible Name. }
  FItems.Name := 'Items';

  FCameraBox := EmptyBox3D;

  FDefaultViewport := true;
  FAlwaysApplyProjection := false;

  FViewports := TKamAbstractViewportsList.Create;
  if DefaultViewport then FViewports.Add(Self);
end;

destructor TKamSceneManager.Destroy;
var
  I: Integer;
begin
  FreeAndNil(FMouseRayHit);

  { unregister self from MainScene callbacs,
    make MainScene.RemoveFreeNotification(Self)... this is all
    done by SetMainScene(nil) already. }
  MainScene := nil;

  { unregister free notification from MouseRayHit3D }
  MouseRayHit3D := nil;

  if FViewports <> nil then
  begin
    for I := 0 to FViewports.High do
      if FViewports[I] is TKamViewport then
      begin
        Assert(TKamViewport(FViewports[I]).SceneManager = Self);
        TKamViewport(FViewports[I]).SceneManager := nil;
      end;
    FreeAndNil(FViewports);
  end;

  inherited;
end;

procedure TKamSceneManager.ItemsVisibleChange(Sender: T3D; Changes: TVisibleChanges);
begin
  { pass visible change notification "upward" (as a TUIControl, to container) }
  VisibleChange;
  { pass visible change notification "downward", to all children T3D }
  Items.VisibleChangeNotification(Changes);
end;

procedure TKamSceneManager.GLContextInit;
begin
  inherited;

  { We actually need to do it only if ShadowVolumesPossible for any viewport.
    But we can as well do it always, it's harmless (just checks some GL
    extensions). (Otherwise we'd have to handle SetShadowVolumesPossible.) }
  if ShadowVolumeRenderer = nil then
  begin
    FShadowVolumeRenderer := TGLShadowVolumeRenderer.Create;
    ShadowVolumeRenderer.InitGLContext;
  end;
end;

procedure TKamSceneManager.GLContextClose;
begin
  Items.GLContextClose;

  FreeAndNil(FShadowVolumeRenderer);

  inherited;
end;

function TKamSceneManager.CreateDefaultCamera(AOwner: TComponent): TCamera;
var
  Box: TBox3D;
begin
  Box := Items.BoundingBox;
  if MainScene <> nil then
    Result := MainScene.CreateCamera(AOwner, Box) else
  begin
    Result := TExamineCamera.Create(AOwner);
    (Result as TExamineCamera).Init(Box,
      { CameraRadius = } Box3DAvgSize(Box, 1.0) * 0.005);
  end;
end;

procedure TKamSceneManager.SetMainScene(const Value: TVRMLGLScene);
begin
  if FMainScene <> Value then
  begin
    if FMainScene <> nil then
    begin
      { When FMainScene = FMouseRayHit3D, leave free notification for FMouseRayHit3D }
      if FMainScene <> FMouseRayHit3D then
        FMainScene.RemoveFreeNotification(Self);
      FMainScene.OnBoundViewpointVectorsChanged := nil;
      { this SetMainScene happen from MainScene destruction notification,
        when ViewpointStack is already freed. }
      if FMainScene.ViewpointStack <> nil then
        FMainScene.ViewpointStack.OnBoundChanged := nil;
    end;

    FMainScene := Value;

    if FMainScene <> nil then
    begin
      FMainScene.FreeNotification(Self);
      FMainScene.OnBoundViewpointVectorsChanged := @SceneBoundViewpointVectorsChanged;
      FMainScene.ViewpointStack.OnBoundChanged := @SceneBoundViewpointChanged;

      { Call initial ViewerChanged (this allows ProximitySensors to work
        as soon as ProcessEvents becomes true). }
      if Camera <> nil then
        MainScene.ViewerChanged(Camera, ViewerToChanges);
    end;

    ApplyProjectionNeeded := true;
  end;
end;

procedure TKamSceneManager.SetMouseRayHit3D(const Value: T3D);
begin
  if FMouseRayHit3D <> Value then
  begin
    { Always keep FreeNotification on FMouseRayHit3D.
      When it's destroyed, our FMouseRayHit3D must be freed too,
      it cannot be used in subsequent ItemsAndCameraCursorChange. }

    if FMouseRayHit3D <> nil then
    begin
      { When FMainScene = FMouseRayHit3D, leave free notification for FMouseRayHit3D }
      if FMainScene <> FMouseRayHit3D then
        FMouseRayHit3D.RemoveFreeNotification(Self);
    end;

    FMouseRayHit3D := Value;

    if FMouseRayHit3D <> nil then
      FMouseRayHit3D.FreeNotification(Self);
  end;
end;

procedure TKamSceneManager.SetCamera(const Value: TCamera);
begin
  if FCamera <> Value then
  begin
    inherited;

    if FCamera <> nil then
    begin
      { Call initial ViewerChanged (this allows ProximitySensors to work
        as soon as ProcessEvents becomes true). }
      if MainScene <> nil then
        MainScene.ViewerChanged(Camera, ViewerToChanges);
    end;

    { Changing camera changes also the view rapidly. }
    if MainScene <> nil then
      MainScene.ViewChangedSuddenly;
  end else
    inherited; { not really needed for now, but for safety --- always call inherited }
end;

procedure TKamSceneManager.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;

  if Operation = opRemove then
  begin
    { set to nil by methods (like SetMainScene), to clean nicely }
    if AComponent = FMainScene then
      MainScene := nil;

    if AComponent = FMouseRayHit3D then
    begin
      MouseRayHit3D := nil;
      { When FMouseRayHit3D is destroyed, our MouseRayHit must be freed too,
        it cannot be used it subsequent ItemsAndCameraCursorChange. }
      FreeAndNil(FMouseRayHit);
    end;

    { Maybe ApplyProjectionNeeded := true also for MainScene cleaning?
      But ApplyProjection doesn't set projection now, when MainScene is @nil. }
  end;
end;

function TKamSceneManager.PositionInside(const X, Y: Integer): boolean;
begin
  { When not DefaultViewport, then scene manager is not visible. }
  Result := DefaultViewport and (inherited PositionInside(X, Y));
end;

procedure TKamSceneManager.PrepareResources(const DisplayProgressTitle: string);
var
  Options: TPrepareResourcesOptions;
  TG: TTransparentGroups;
begin
  ChosenViewport := nil;
  NeedsUpdateGeneratedTextures := false;

  { This preparation is done only once, before rendering all viewports.
    No point in doing this when no viewport is configured.
    Also, we'll need to use one of viewport's projection here. }
  if Viewports.Count <> 0 then
  begin
    Options := [prRender, prBackground, prBoundingBox];
    { We never call tgAll from scene manager. Even for non-shadowed rendering
      (one pass), we still may have many Items, so we always call all tgOpaque
      before all tgTransparent. }
    TG := [tgOpaque, tgTransparent];

    if Viewports.UsesShadowVolumes then
      Options := Options + prShadowVolume;

    { We need one viewport, to setup it's projection and to setup it's camera.
      There really no perfect choice, although in practice any viewport
      should do just fine. For now: use the 1st one on the list.
      Maybe in the future we'll need more intelligent method of choosing. }
    ChosenViewport := Viewports[0];

    { Apply projection now, as TVRMLGLScene.GLProjection calculates
      BackgroundSkySphereRadius, which is used by MainScene.Background.
      Otherwise our preparations of "prBackground" here would be useless,
      as BackgroundSkySphereRadius will change later, and MainScene.Background
      will have to be recreated. }
    ChosenViewport.ApplyProjection;

    { RenderState.Camera* must be already set,
      since PrepareResources may do some operations on texture gen modes
      in WORLDSPACE*. }
    RenderState.CameraFromCameraObject(ChosenViewport.Camera);

    if DisplayProgressTitle <> '' then
    begin
      Progress.Init(Items.PrepareResourcesSteps, DisplayProgressTitle, true);
      try
        Items.PrepareResources(TG, Options, true);
      finally Progress.Fini end;
    end else
      Items.PrepareResources(TG, Options, false);

    NeedsUpdateGeneratedTextures := true;
  end;
end;

procedure TKamSceneManager.BeforeDraw;
begin
  inherited;
  PrepareResources;
end;

function TKamSceneManager.ViewerToChanges: TVisibleChanges;
var
  H: TVRMLGLHeadlight;
begin
  if MainScene <> nil then
    H := MainScene.Headlight { this may still return @nil if no headlight } else
    H := nil;

  if H <> nil then
    Result := [vcVisibleNonGeometry] else
    Result := [];
end;

procedure TKamSceneManager.UpdateGeneratedTexturesIfNeeded;
begin
  if NeedsUpdateGeneratedTextures then
  begin
    NeedsUpdateGeneratedTextures := false;

    { We depend here that right before Draw, BeforeDraw was called.
      We depend on BeforeDraw (actually PrepareResources) to set
      ChosenViewport and make ChosenViewport.ApplyProjection.

      This way below we can use sensible projection near/far calculated
      by previous ChosenViewport.ApplyProjection,
      and restore viewport used by previous ChosenViewport.ApplyProjection.

      This could be moved to PrepareResources without problems, but we want
      time needed to render textures be summed into "FPS frame time". }
    Items.UpdateGeneratedTextures(@RenderFromViewEverything,
      ChosenViewport.WalkProjectionNear,
      ChosenViewport.WalkProjectionFar,
      ChosenViewport.CorrectLeft,
      ChosenViewport.CorrectBottom,
      ChosenViewport.CorrectWidth,
      ChosenViewport.CorrectHeight);
  end;
end;

procedure TKamSceneManager.Draw;
begin
  UpdateGeneratedTexturesIfNeeded;

  inherited;
  if not DefaultViewport then Exit;
  ApplyProjection;
  RenderOnScreen(Camera);
end;

procedure TKamSceneManager.MouseMove3D(const RayOrigin, RayDirection: TVector3Single);
var
  Dummy: Single;
begin
  { We call here Items.RayCollision ourselves, to update FMouseRayHit
    (useful to e.g. update Cusdor based on it). To Items.MouseMove
    we can also pass this FMouseRay, so that they know collision
    result already. }

  FreeAndNil(FMouseRayHit);
  FMouseRayHit := Items.RayCollision(Dummy, RayOrigin, RayDirection,
    { Do not use CollisionIgnoreItem here,
      as this is not camera<->3d world collision? } nil);

  { calculate MouseRayHit3D }
  if MouseRayHit <> nil then
    MouseRayHit3D := MouseRayHit.Hierarchy.Last else
    MouseRayHit3D := nil;

  Items.MouseMove(RayOrigin, RayDirection, FMouseRayHit);
end;

procedure TKamSceneManager.Idle(const CompSpeed: Single;
  const HandleMouseAndKeys: boolean;
  var LetOthersHandleMouseAndKeys: boolean);
begin
  inherited;

  if not Paused then
    Items.Idle(CompSpeed);
end;

procedure TKamSceneManager.CameraVisibleChange(ACamera: TObject);
begin
  if (MainScene <> nil) and (ACamera = Camera) then
    { MainScene.ViewerChanged will cause MainScene.[On]VisibleChangeHere,
      that (assuming here that MainScene is also on Items) will cause
      ItemsVisibleChange that will cause our own VisibleChange.
      So this way MainScene.ViewerChanged will also cause our VisibleChange. }
    MainScene.ViewerChanged(Camera, ViewerToChanges) else
    VisibleChange;

  if Assigned(OnCameraChanged) then
    OnCameraChanged(ACamera);
end;

function TKamSceneManager.CollisionIgnoreItem(const Sender: TObject;
  const Triangle: P3DTriangle): boolean;
begin
  Result := false;
end;

function TKamSceneManager.CameraMoveAllowed(ACamera: TWalkCamera;
  const ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
  const BecauseOfGravity: boolean): boolean;
begin
  Result := Items.MoveAllowed(ACamera.Position, ProposedNewPos, NewPos,
    ACamera.CameraRadius, @CollisionIgnoreItem);

  if Result then
  begin
    if IsEmptyBox3D(FCameraBox) then
    begin
      { Don't let user to fall outside of the box because of gravity. }
      if BecauseOfGravity then
        Result := SimpleKeepAboveMinPlane(NewPos, Items.BoundingBox,
          ACamera.GravityUp);
    end else
      Result := Box3DPointInside(NewPos, FCameraBox);
  end;
end;

procedure TKamSceneManager.CameraGetHeight(ACamera: TWalkCamera;
  out IsAbove: boolean; out AboveHeight: Single;
  out AboveGround: P3DTriangle);
begin
  Items.GetHeightAbove(ACamera.Position, ACamera.GravityUp,
    @CollisionIgnoreItem,
    IsAbove, AboveHeight, AboveGround);
end;

procedure TKamSceneManager.SceneBoundViewpointChanged(Scene: TVRMLScene);
begin
  if Camera <> nil then
    Scene.CameraBindToViewpoint(Camera, false);

  { bound Viewpoint.fieldOfView changed, so update projection }
  ApplyProjectionNeeded := true;

  if Assigned(OnBoundViewpointChanged) then
    OnBoundViewpointChanged(Self);
end;

procedure TKamSceneManager.SceneBoundViewpointVectorsChanged(Scene: TVRMLScene);
begin
  if Camera <> nil then
    Scene.CameraBindToViewpoint(Camera, true);
end;

function TKamSceneManager.GetItems: T3D;
begin
  Result := Items;
end;

function TKamSceneManager.GetMainScene: TVRMLGLScene;
begin
  Result := MainScene;
end;

function TKamSceneManager.GetShadowVolumeRenderer: TGLShadowVolumeRenderer;
begin
  Result := ShadowVolumeRenderer;
end;

function TKamSceneManager.GetMouseRayHit3D: T3D;
begin
  Result := MouseRayHit3D;
end;

function TKamSceneManager.GetHeadlightCamera: TCamera;
begin
  Result := Camera;
end;

procedure TKamSceneManager.SetDefaultViewport(const Value: boolean);
begin
  if Value <> FDefaultViewport then
  begin
    FDefaultViewport := Value;
    if DefaultViewport then
      Viewports.Add(Self) else
      Viewports.Remove(Self);
  end;
end;

{ TKamViewport --------------------------------------------------------------- }

destructor TKamViewport.Destroy;
begin
  SceneManager := nil; { remove Self from SceneManager.Viewports }
  inherited;
end;

procedure TKamViewport.CameraVisibleChange(ACamera: TObject);
begin
  VisibleChange;
end;

function TKamViewport.CameraMoveAllowed(ACamera: TWalkCamera;
  const ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
  const BecauseOfGravity: boolean): boolean;
begin
  if SceneManager <> nil then
    Result := SceneManager.CameraMoveAllowed(
      ACamera, ProposedNewPos, NewPos, BecauseOfGravity) else
  begin
    Result := true;
    NewPos := ProposedNewPos;
  end;
end;

procedure TKamViewport.CameraGetHeight(ACamera: TWalkCamera;
  out IsAbove: boolean; out AboveHeight: Single;
  out AboveGround: P3DTriangle);
begin
  if SceneManager <> nil then
    SceneManager.CameraGetHeight(
      ACamera, IsAbove, AboveHeight, AboveGround) else
  begin
    IsAbove := false;
    AboveHeight := MaxSingle;
    AboveGround := nil;
  end;
end;

function TKamViewport.CreateDefaultCamera(AOwner: TComponent): TCamera;
begin
  Result := SceneManager.CreateDefaultCamera(AOwner);
end;

function TKamViewport.GetItems: T3D;
begin
  Result := SceneManager.Items;
end;

function TKamViewport.GetMainScene: TVRMLGLScene;
begin
  Result := SceneManager.MainScene;
end;

function TKamViewport.GetShadowVolumeRenderer: TGLShadowVolumeRenderer;
begin
  Result := SceneManager.ShadowVolumeRenderer;
end;

function TKamViewport.GetMouseRayHit3D: T3D;
begin
  Result := SceneManager.MouseRayHit3D;
end;

function TKamViewport.GetHeadlightCamera: TCamera;
begin
  Result := SceneManager.Camera;
end;

procedure TKamViewport.Draw;
begin
  SceneManager.UpdateGeneratedTexturesIfNeeded;

  inherited;
  ApplyProjection;
  RenderOnScreen(Camera);
end;

procedure TKamViewport.MouseMove3D(const RayOrigin, RayDirection: TVector3Single);
begin
  if SceneManager <> nil then
    SceneManager.MouseMove3D(RayOrigin, RayDirection);
end;

procedure TKamViewport.SetSceneManager(const Value: TKamSceneManager);
begin
  if Value <> FSceneManager then
  begin
    if SceneManager <> nil then
      SceneManager.Viewports.Remove(Self);
    FSceneManager := Value;
    if SceneManager <> nil then
      SceneManager.Viewports.Add(Self);
  end;
end;

end.
