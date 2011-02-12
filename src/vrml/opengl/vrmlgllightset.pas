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

{ VRML lights OpenGL rendering. }
unit VRMLGLLightSet;

interface

uses VectorMath, GL, GLU, KambiGLUtils, VRMLNodes, VRMLLightSet;

type
  { Modify light's properties of the light right before it's rendered.
    Currently, you can modify only the "on" state.

    By default, LightOn is the value of Light.LightNode.FdOn field.
    You can change it if you want. }
  TVRMLLightRenderEvent = procedure (const Light: TActiveLight;
    var LightOn: boolean) of object;

  { Render many light sets (TDynActiveLightArray) and avoid
    to configure the same light many times.

    The idea is that calling @link(Render) is just like doing glLightsFromVRML,
    that is it sets up given OpenGL lights. But this class remembers what
    VRML light was set on what OpenGL light, and assumes that VRML lights
    don't change during TVRMLGLLightsCachingRenderer execution. So OpenGL
    light will not be configured again, if it's already configured
    correctly.

    Note that LightRenderEvent event for this must be deterministic,
    based purely on light properties. For example, it's Ok to
    make LightRenderEvent that turns off lights that have kambiShadows = TRUE.
    It is @italic(not Ok) to make LightRenderEvent that sets LightOn to
    random boolean value. IOW, caching here assumes that for the same Light
    values, LightRenderEvent will set LightOn the same. }
  TVRMLGLLightsCachingRenderer = class
  private
    FGLLightNum1, FGLLightNum2: Integer;
    FLightRenderEvent: TVRMLLightRenderEvent;
    LightsKnown: boolean;
    function NeedRenderLight(Index: Integer; Light: PActiveLight): boolean;
  public
    { Statistics of how many OpenGL light setups were done
      (Statistics[true]) vs how many were avoided (Statistics[false]).
      This allows you to decide is using TVRMLGLLightsCachingRenderer
      class sensible (as opposed to directly rendering with glLightsFromVRML
      calls). }
    Statistics: array [boolean] of Cardinal;

    LightsDone: array of PActiveLight;

    constructor Create(const AGLLightNum1, AGLLightNum2: Integer;
      const ALightRenderEvent: TVRMLLightRenderEvent);

    { Render lights. Lights (TDynActiveLightArray) may be @nil,
      it's equal to passing an empty array of lights.

      Returns LightsEnabled, a number of enabled lights, including GLLightNum1
      (in other words, it assumes that first GLLightNum1 lights are already
      reserved and enabled by caller). }
    procedure Render(Lights: TDynActiveLightArray; out LightsEnabled: Cardinal);

    property GLLightNum1: Integer read FGLLightNum1;
    property GLLightNum2: Integer read FGLLightNum2;
    property LightRenderEvent: TVRMLLightRenderEvent read FLightRenderEvent;
  end;

  { Load VRML/X3D lights from a file, and render them to OpenGL.
    This allows you to load lights from a VRML/X3D file,
    and use these lights with any 3D objects (for example,
    maybe you want to share the same lights across many TVRMLGLScene
    or other 3D objects you render with OpenGL). }
  TVRMLGLLightSet = class(TVRMLLightSet)
  public
    { Set up OpenGL lights properties to correspond to given VRML/X3D lights.
      Reads LightsEnabled, to know how many lights are already allocated.
      Increases LightsEnabled for our lights. }
    procedure Render(var LightsEnabled: Cardinal);

(* TODO:
    { Disable all the OpenGL lights (in glLightNum1 .. glLightNum2 range). }
    procedure TurnLightsOff;

    { Disable all the lights not supposed to shine in the shadow,
      for shadow volumes.

      Simply disables lights with @code(kambiShadows) field set to @true.
      See [http://vrmlengine.sourceforge.net/kambi_vrml_extensions.php#ext_shadows]
      for more info.

      Lights with kambiShadows = FALSE are ignored:
      they are left untouched by this method (they are
      neither disabled, nor enabled --- usually you should enable them
      as needed by RenderLights). }
    procedure TurnLightsOffForShadows;
*)
  end;

implementation

uses SysUtils, KambiUtils, Math;

{ Set and enable OpenGL light properties based on VRML/X3D light.

  Requires that current OpenGL matrix is modelview.
  Always preserves the matrix value (by using up to one modelview
  matrix stack slot).

  We do not examine Light.LightNode.FdOn.Value here.

  We make no assumptions about the previous state of this OpenGL light.
  We simply always set all the parameters to fully define the required
  light behavior. Some light parameters may not be set, but only because
  they are not used --- for example, if a light is not a spot light,
  then we set GL_SPOT_CUTOFF to 180 (indicates that light has no spot),
  but don't necessarily set GL_SPOT_DIRECTION or GL_SPOT_EXPONENT
  (as OpenGL will not use them anyway). }
procedure glLightFromVRMLLight(glLightNum: Integer; const Light: TActiveLight);

  { SetupXxx light : setup glLight properties GL_POSITION, GL_SPOT_* }
  procedure SetupDirectionalLight(LightNode: TVRMLDirectionalLightNode);
  begin
    glLightv(glLightNum, GL_POSITION, Vector4Single(VectorNegate(LightNode.FdDirection.Value), 0));
    glLighti(glLightNum, GL_SPOT_CUTOFF, 180);
  end;

  procedure SetupPointLight(LightNode: TVRMLPointLightNode);
  begin
    glLightv(glLightNum, GL_POSITION, Vector4Single(LightNode.FdLocation.Value, 1));
    glLighti(glLightNum, GL_SPOT_CUTOFF, 180);
  end;

  procedure SetupSpotLight_1(LightNode: TNodeSpotLight_1);
  begin
    glLightv(glLightNum, GL_POSITION, Vector4Single(LightNode.FdLocation.Value, 1));

    glLightv(glLightNum, GL_SPOT_DIRECTION, LightNode.FdDirection.Value);
    glLightf(glLightNum, GL_SPOT_EXPONENT, LightNode.SpotExp);
    glLightf(glLightNum, GL_SPOT_CUTOFF,
      { Clamp to 90 for safety, see VRML 2.0 version for comments }
      Min(90, RadToDeg(LightNode.FdCutOffAngle.Value)));
  end;

  procedure SetupSpotLight_2(LightNode: TNodeSpotLight_2);
  begin
    glLightv(glLightNum, GL_POSITION, Vector4Single(LightNode.FdLocation.Value, 1));

    glLightv(glLightNum, GL_SPOT_DIRECTION, LightNode.FdDirection.Value);

    { There is no way to translate beamWidth to OpenGL's GL_SPOT_EXPONENT.
      In OpenGL spotlight, there is *no* way to specify that light
      is uniform (maximum) within beamWidth, and that light amount
      falls linearly from beamWidth to cutOffAngle.
      In OpenGL, light intensity drops off by
      cosinus(of the angle)^GL_SPOT_EXPONENT.

      No sensible way to even approximate VRML behavior ?

      We can accurately express one specific case (that is
      actually the default, in you will not give beamWidth
      value in VRML 2.0): if beamWidth >= cutOffAngle, the light
      is maximum within full cutOffAngle. This is easy to
      do, just set spot_exponent to 0, then
      cosinus(of the angle)^GL_SPOT_EXPONENT is always 1.

      For other values of beamWidth, I just set spot_exponent
      to some arbitrary value and hope that result will look sensible...

      TODO: some VRML 2.0 extension to allow specifying
      exponent directly would be useful to give user actual
      control over this. Probably just add dropOffRate field
      (like in VRML 1.0) with def value like -1 and say that
      "dropOffRate < 0 means that we should try to approx
      beamWidth, otherwise dropOffRate is used".

      Looking at how other VRML implementations handle this:
      - Seems that most of them ignore the issue, leaving spot exponent
        always 0 and ignoring beamWidth entirely.
      - One implementation
        [http://arteclab.artec.uni-bremen.de/courses/mixed-reality/material/ARToolkit/ARToolKit2.52vrml/lib/libvrml/libvrml97gl/src/vrml97gl/old_ViewerOpenGL.cpp]
        does exactly like me --- checks beamWidth < cutOffAngle
        and sets spot_exponent to 0 or 1.
      - FreeWRL
        [http://search.cpan.org/src/LUKKA/FreeWRL-0.14/VRMLRend.pm]
        uses more intelligent approach setting
        GL_SPOT_EXPONENT to 0.5/ (beamWidth + 0.1).
        Which gives
          beamWidth = 0 => GL_SPOT_EXPONENT = 5
          beamWidth = Pi/4 => GL_SPOT_EXPONENT =~ 0.5 / 0.9 =~ 1/2
          beamWidth = Pi/2 => GL_SPOT_EXPONENT =~ 0.5 / 1.67 =~ 1/3
        Honestly I don't see how it's much better than our atbitrary way... }
    if LightNode.FdBeamWidth.Value >= LightNode.FdCutOffAngle.Value then
      glLightf(glLightNum, GL_SPOT_EXPONENT, 0) else
      glLightf(glLightNum, GL_SPOT_EXPONENT, 1
        { 0.5 / (LightNode.FdBeamWidth.Value + 0.1) });

    glLightf(glLightNum, GL_SPOT_CUTOFF,
      { Clamp to 90, to protect against user inputting invalid value in VRML,
        or just thing like 1.5708, which may be recalculated by
        RadToDeg to 90.0002104591, so > 90, and OpenGL raises "invalid value"
        error then... }
      Min(90, RadToDeg(LightNode.FdCutOffAngle.Value)));
  end;

var
  SetNoAttenuation: boolean;
  Attenuat: TVector3Single;
  Color3, AmbientColor3: TVector3f;
  Color4, AmbientColor4: TVector4f;
begin
  glLightNum += GL_LIGHT0;

  glPushMatrix;
  try
    glMultMatrix(Light.Transform);

    if Light.LightNode is TVRMLDirectionalLightNode then
      SetupDirectionalLight(TVRMLDirectionalLightNode(Light.LightNode)) else
    if Light.LightNode is TVRMLPointLightNode then
      SetupPointLight(TVRMLPointLightNode(Light.LightNode)) else
    if Light.LightNode is TNodeSpotLight_1 then
      SetupSpotLight_1(TNodeSpotLight_1(Light.LightNode)) else
    if Light.LightNode is TNodeSpotLight_2 then
      SetupSpotLight_2(TNodeSpotLight_2(Light.LightNode)) else
      raise EInternalError.Create('Unknown light node class');

    { setup attenuation for OpenGL light }
    SetNoAttenuation := true;

    if (Light.LightNode is TVRMLPositionalLightNode) then
    begin
      Attenuat := TVRMLPositionalLightNode(Light.LightNode).FdAttenuation.Value;
      if not ZeroVector(Attenuat) then
      begin
        SetNoAttenuation := false;
        glLightf(glLightNum, GL_CONSTANT_ATTENUATION, Attenuat[0]);
        glLightf(glLightNum, GL_LINEAR_ATTENUATION, Attenuat[1]);
        glLightf(glLightNum, GL_QUADRATIC_ATTENUATION, Attenuat[2]);
      end;
    end;

    if SetNoAttenuation then
    begin
      { lights with no Attenuation field or with Attenuation = (0, 0, 0)
         get default Attenuation = (1, 0, 0) }
      glLightf(glLightNum, GL_CONSTANT_ATTENUATION, 1);
      glLightf(glLightNum, GL_LINEAR_ATTENUATION, 0);
      glLightf(glLightNum, GL_QUADRATIC_ATTENUATION, 0);
    end;
  finally glPopMatrix end;

  { calculate Color4 = light color * light intensity }
  Color3 := VectorScale(Light.LightNode.FdColor.Value,
    Light.LightNode.FdIntensity.Value);
  Color4 := Vector4Single(Color3, 1);

  { calculate AmbientColor4 = light color * light ambient intensity }
  if Light.LightNode.FdAmbientIntensity.Value < 0 then
    AmbientColor4 := Color4 else
  begin
    AmbientColor3 := VectorScale(Light.LightNode.FdColor.Value,
      Light.LightNode.FdAmbientIntensity.Value);
    AmbientColor4 := Vector4Single(AmbientColor3, 1);
  end;

  glLightv(glLightNum, GL_AMBIENT, AmbientColor4);
  glLightv(glLightNum, GL_DIFFUSE, Color4);
  glLightv(glLightNum, GL_SPECULAR, Color4);

  glEnable(glLightNum);
end;

procedure RenderLights(
  const Cache: TVRMLGLLightsCachingRenderer;
  const Lights: TDynActiveLightArray;
  const GLLightNum1, GLLightNum2: Integer;
  const LightRenderEvent: TVRMLLightRenderEvent;
  out LightsEnabled: Cardinal);
var
  I: Integer;
  Light: PActiveLight;
  LightOn: boolean;
begin
  LightsEnabled := GLLightNum1;
  if LightsEnabled > GLLightNum2 then Exit;

  for I := 0 to Lights.Count - 1 do
  begin
    Light := Lights.Pointers[I];

    LightOn := Light^.LightNode.FdOn.Value;
    if Assigned(LightRenderEvent) then
      LightRenderEvent(Light^, LightOn);

    if LightOn then
    begin
      if (Cache = nil) or Cache.NeedRenderLight(I, Light) then
        glLightFromVRMLLight(LightsEnabled, Light^);
      Inc(LightsEnabled);
      if LightsEnabled > GLLightNum2 then Exit;
    end;
  end;

  if LightsEnabled <= GLLightNum2 then
    for I := LightsEnabled to GLLightNum2 do
      if (Cache = nil) or Cache.NeedRenderLight(I - GLLightNum1, nil) then
        glDisable(GL_LIGHT0 + I);
end;

{ TVRMLGLLightsCachingRenderer ----------------------------------------------- }

constructor TVRMLGLLightsCachingRenderer.Create(
  const AGLLightNum1, AGLLightNum2: Integer;
  const ALightRenderEvent: TVRMLLightRenderEvent);
begin
  inherited Create;
  FGLLightNum1 := AGLLightNum1;
  FGLLightNum2 := AGLLightNum2;
  FLightRenderEvent := ALightRenderEvent;

  LightsKnown := false;
  { avoid range error when GLLightNum2 < GLLightNum1 }
  if GLLightNum2 >= GLLightNum1 then
    SetLength(LightsDone, GLLightNum2 - GLLightNum1 + 1);
end;

function TVRMLGLLightsCachingRenderer.NeedRenderLight(Index: Integer; Light: PActiveLight): boolean;
begin
  Result := not (
    LightsKnown and
    ( { Light Index is currently disabled, and we want it disabled: Ok. }
      ( (LightsDone[Index] = nil) and
        (Light = nil) )
      or
      { Light Index is currently enabled, and we want it enabled,
        with the same LightNode and Transform: Ok.
        (Other TActiveLight record properties are calculated from
        LightNode and Transform, so no need to compare them). }
      ( (LightsDone[Index] <> nil) and
        (Light <> nil) and
        (LightsDone[Index]^.LightNode = Light^.LightNode) and
        (MatricesPerfectlyEqual(
          LightsDone[Index]^.Transform, Light^.Transform)) )
    ));
  if Result then
    { Update LightsDone[Index], if change required. }
    LightsDone[Index] := Light;
  Inc(Statistics[Result]);
end;

procedure TVRMLGLLightsCachingRenderer.Render(Lights: TDynActiveLightArray;
  out LightsEnabled: Cardinal);
begin
  RenderLights(Self, Lights, GLLightNum1, GLLightNum2,
    LightRenderEvent, LightsEnabled);
  LightsKnown := true;
end;

{ TVRMLGLLightSet ------------------------------------------------------------ }

procedure TVRMLGLLightSet.Render(var LightsEnabled: Cardinal);
var
  LightsEnabledBefore: Cardinal;
begin
  LightsEnabledBefore := LightsEnabled;
  RenderLights(nil, Lights, LightsEnabledBefore, GLMaxLights - 1,
    nil, LightsEnabled);
end;

(* TODO: replace everywhere uses of this with proper implementation
procedure TVRMLGLLightSet.TurnLightsOff;
var
  I: Integer;
begin
  for I := GLLightNum1 to Integer(GLMaxLights) - 1 do
    glDisable(GL_LIGHT0 + I);
end;

procedure TVRMLGLLightSet.TurnLightsOffForShadows;
var
  MyLightNum, GLLightNum: Integer;
  L: PActiveLight;
begin
  L := Lights.Pointers[0];
  for MyLightNum := 0 to Lights.Count - 1 do
  begin
    GLLightNum := MyLightNum + GLLightNum1;

    if L^.LightNode.FdKambiShadows.Value then
    begin
      if GLLightNum < GLMaxLights then
        glDisable(GL_LIGHT0 + GLLightNum);
    end;

    Inc(L);
  end;
end;
*)

end.
