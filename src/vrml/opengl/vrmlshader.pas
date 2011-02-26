{
  Copyright 2010-2011 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Setting up OpenGL shading (TVRMLShader).

  Internal for VRMLGLRenderer. @exclude }
unit VRMLShader;

interface

uses VectorMath, GLShaders, FGL {$ifdef VER2_2}, FGLObjectList22 {$endif},
  VRMLShadowMaps, VRMLTime, VRMLFields, VRMLNodes, KambiUtils;

type
  { Uniform value type, for TUniform. }
  TUniformType = (utLongInt, utSingle);

  { Uniform value to set after binding shader. }
  TUniform = class
    Name: string;
    AType: TUniformType;
    Value: record
      case Integer of
        utLongInt: (LongInt: LongInt);
        utSingle: (Single: Single);
    end;
  end;
  TUniformsList = specialize TFPGObjectList<TUniform>;

  TTextureType = (tt2D, tt2DShadow, ttCubeMap, tt3D, ttShader);

  TTexGenerationComponent = (tgEye, tgObject);
  TTexGenerationComplete = (tgSphere, tgNormal, tgReflection);
  TTexComponent = 0..3;

  TFogType = (ftLinear, ftExp);

  TShaderCodeHash = QWord;

  { GLSL program integrated with VRML/X3D and TVRMLShader.
    Allows to bind uniform values from VRML/X3D fields,
    and to observe VRML/X3D events and automatically update uniform values.
    Also allows to initialize and check program by TVRMLShader.LinkProgram,
    and get a hash of it by TVRMLShader.CodeHash. }
  TVRMLShaderProgram = class(TGLSLProgram)
  private
    { Events where we registered our EventReceive method. }
    EventsObserved: TVRMLEventsList;

    { Set uniform variable from VRML/X3D field value.
      Uniform name is contained in UniformName. UniformValue indicates
      uniform type and new value (UniformValue.Name is not used).

      This ignores SFNode / MFNode fields (these will be set elsewhere). }
    procedure SetUniformFromField(const UniformName: string;
      const UniformValue: TVRMLField; const EnableDisable: boolean);

    procedure EventReceive(Event: TVRMLEvent; Value: TVRMLField;
      const Time: TVRMLTime);

    { Set uniform shader variable from VRML/X3D field (exposed or not).
      We also start observing an exposed field or eventIn,
      and will automatically update uniform value when we receive an event. }
    procedure BindUniform(const FieldOrEvent: TVRMLInterfaceDeclaration;
      const EnableDisable: boolean);
  protected
    { Nodes that have interface declarations with textures for this shader. }
    UniformsNodes: TVRMLNodesList;
  public
    constructor Create;
    destructor Destroy; override;

    { Set and observe uniform variables from given Node.InterfaceDeclarations.

      Non-texture fields are set immediately.
      Non-texture fields are events are then observed by this shader,
      and automatically updated when changed.

      Texture fields have to be updated by descendant (like TVRMLGLSLProgram),
      using the UniformsNodes list. These methods add nodes to this list.
      @groupBegin }
    procedure BindUniforms(const Node: TVRMLNode; const EnableDisable: boolean);
    procedure BindUniforms(const Nodes: TVRMLNodesList; const EnableDisable: boolean);
    { @groupEnd }
  end;

  TVRMLShader = class;

  TLightShader = class
  private
    Number: Cardinal;
    Node: TNodeX3DLightNode;
    MaterialSpecularColor: TVector3Single;
    Shader: TVRMLShader;
    { Code calculated (on demand, when method called) using above vars. }
    FCode: TDynStringArray;
  public
    destructor Destroy; override;
    function Code: TDynStringArray;
  end;

  TLightShaders = class(specialize TFPGObjectList<TLightShader>)
  private
    function Find(const Node: TNodeX3DLightNode; out Shader: TLightShader): boolean;
  end;

  TTextureShader = class
  private
    TextureUnit: Cardinal;
    TextureType: TTextureType;
    Node: TNodeX3DTextureNode;
    ShadowMapSize: Cardinal;
    ShadowLight: TNodeX3DLightNode;
    ShadowVisualizeDepth: boolean;
    Shader: TVRMLShader;
  public
    procedure Enable(var TextureApply, TextureColorDeclare,
      TextureCoordInitialize, TextureCoordMatrix, TextureUniformsDeclare: string);
  end;

  TTextureShaders = specialize TFPGObjectList<TTextureShader>;

  { Create appropriate shader and at the same time set OpenGL parameters
    for fixed-function rendering. Once everything is set up,
    you can create TVRMLShaderProgram instance
    and initialize it by LinkProgram here, then enable it if you want.
    Or you can simply allow the fixed-function pipeline to work.

    This is used internally by TVRMLGLRenderer. It isn't supposed to be used
    directly by other code. }
  TVRMLShader = class
  private
    Uniforms: TUniformsList;
    { If non-nil, the list of effect nodes that determine uniforms of our program. }
    UniformsNodes: TVRMLNodesList;
    TextureCoordGen, ClipPlane, FragmentEnd: string;
    FPercentageCloserFiltering: TPercentageCloserFiltering;
    Source: array [TShaderType] of TDynStringArray;
    PlugIdentifiers: Cardinal;
    LightShaders: TLightShaders;
    TextureShaders: TTextureShaders;
    FCodeHash: TShaderCodeHash;
    CodeHashCalculated: boolean;
    SelectedNode: TNodeComposedShader;
    WarnMissingPlugs: boolean;
    FShapeRequiresShaders: boolean;

    { We have to optimize the most often case of TVRMLShader usage,
      when the shader is not needed or is already prepared.

      - Enabling shader features should not do anything time-consuming,
        as it's done every frame. This means that we cannot construct
        complete shader source code on the fly, as this would mean
        slowdown at every frame for every shape.
        So enabling a feature merely records the demand for this feature.

      - It must also set ShapeRequiresShaders := true, if needed.
      - It must change the result of CodeHash.
      - Actually adding this feature to shader source may be done at LinkProgram.
    }
    AppearanceEffects: TMFNode;
    GroupEffects: TVRMLNodesList;

    procedure EnableEffects(Effects: TMFNode;
      const Code: TDynStringArray = nil;
      const ForwardDeclareInFinalShader: boolean = false);
    procedure EnableEffects(Effects: TVRMLNodesList;
      const Code: TDynStringArray = nil;
      const ForwardDeclareInFinalShader: boolean = false);

    { Special form of Plug. It inserts the PlugValue source code directly
      at the position of given plug comment (no function call
      or anything is added). It also assumes that PlugName occurs only once
      in the Code, for speed. }
    procedure PlugDirectly(Code: TDynStringArray;
      const CodeIndex: Cardinal;
      const PlugName, PlugValue: string;
      const InsertAtBeginIfNotFound: boolean);
  public
    constructor Create;
    destructor Destroy; override;

    { Detect defined PLUG_xxx functions within PlugValue,
      insert calls to them into given Code,
      insert forward declarations of their calls into Code too
      (this allows to work with separate compilation units, and also makes
      procedure declaration order less important),
      insert the PlugValue (which should be variable and functions declarations)
      into code of final shader (determined by EffectPartType).

      When Code = nil then we assume code of final shader.
      So we insert a call to plugged_x function, and PlugValue (defining this
      plugged_x function) into the same final shader source
      (determined by EffectPartType).

      ForwardDeclareInFinalShader should be used only when Code is not nil.
      It means that forward declarations for Code[0] will be inserted
      into final shader code, not into Code[0]. This is useful if your
      Code[0] is special, and it will be pasted directly (not as plug)
      into final shader code.

      Inserts calls right before the magic @code(/* PLUG ...*/) comments,
      this way many Plug calls that defined the same PLUG_xxx function
      will be called in the same order. }
    procedure Plug(const EffectPartType: TShaderType; PlugValue: string;
      Code: TDynStringArray = nil;
      const ForwardDeclareInFinalShader: boolean = false);

    { Add fragment and vertex shader code, link.
      @raises EGLSLError In case of troubles with linking. }
    procedure LinkProgram(AProgram: TVRMLShaderProgram);

    { Calculate the hash of all the current TVRMLShader settings,
      that is the hash of GLSL program code initialized by this shader
      LinkProgram. You should use this only when the GLSL program source
      is completely initialized (all TVRMLShader settings are set).

      It can be used to decide when the shader GLSL program needs
      to be regenerated, shared etc. }
    function CodeHash: TShaderCodeHash;

    procedure AddUniform(Uniform: TUniform);

    procedure EnableTexture(const TextureUnit: Cardinal;
      const TextureType: TTextureType; const Node: TNodeX3DTextureNode;
      const ShadowMapSize: Cardinal = 0;
      const ShadowLight: TNodeX3DLightNode = nil;
      const ShadowVisualizeDepth: boolean = false);
    procedure EnableTexGen(const TextureUnit: Cardinal;
      const Generation: TTexGenerationComponent; const Component: TTexComponent);
    procedure EnableTexGen(const TextureUnit: Cardinal;
      const Generation: TTexGenerationComplete);
    procedure DisableTexGen(const TextureUnit: Cardinal);
    procedure EnableClipPlane(const ClipPlaneIndex: Cardinal);
    procedure DisableClipPlane(const ClipPlaneIndex: Cardinal);
    procedure EnableAlphaTest;
    procedure EnableBumpMapping(const NormalMapTextureUnit: Cardinal);
    procedure EnableLight(const Number: Cardinal; Node: TNodeX3DLightNode;
      const MaterialSpecularColor: TVector3Single);
    procedure EnableFog(const FogType: TFogType);
    function EnableCustomShaderCode(Shaders: TMFNodeShaders;
      out Node: TNodeComposedShader): boolean;
    procedure EnableAppearanceEffects(Effects: TMFNode);
    procedure EnableGroupEffects(Effects: TVRMLNodesList);

    property PercentageCloserFiltering: TPercentageCloserFiltering
      read FPercentageCloserFiltering write FPercentageCloserFiltering;

    property ShapeRequiresShaders: boolean read FShapeRequiresShaders
      write FShapeRequiresShaders;
  end;

implementation

uses SysUtils, GL, GLExt, KambiStringUtils, KambiGLUtils,
  VRMLErrors, KambiLog, StrUtils, Base3D;

{ TODO: a way to turn off using fixed-function pipeline completely
  will be needed some day. Currently, some functions here call
  fixed-function glEnable... stuff.

  TODO: caching shader programs, using the same program if all settings
  are the same, will be needed some day. TShapeCache is not a good place
  for this, as the conditions for two shapes to share arrays/vbos
  are smaller/different (for example, two different geometry nodes
  can definitely share the same shader).

  Maybe caching should be done in this unit, or maybe in TVRMLGLRenderer
  in some TShapeShaderCache or such.

  TODO: a way to turn on/off per-pixel shading should be available.

  TODO: some day, avoid using predefined OpenGL state variables.
  Use only shader uniforms. Right now, we allow some state to be assigned
  using direct normal OpenGL fixed-function functions in VRMLGLRenderer,
  and our shaders just use it.
}

{ String helpers ------------------------------------------------------------- }

function MoveToOpeningParen(const S: string; var P: Integer): boolean;
begin
  Result := true;
  repeat
    Inc(P);

    if P > Length(S) then
    begin
      VRMLWarning(vwIgnorable, 'PLUG declaration unexpected end (no opening parenthesis "(")');
      Exit(false);
    end;

    if (S[P] <> '(') and
       not (S[P] in WhiteSpaces) then
    begin
      VRMLWarning(vwIgnorable, Format('PLUG declaration unexpected character "%s" (expected opening parenthesis "(")',
        [S[P]]));
      Exit(false);
    end;
  until S[P] = '(';
 end;

function MoveToMatchingParen(const S: string; var P: Integer): boolean;
var
  ParenLevel: Cardinal;
begin
  Result := true;
  ParenLevel := 1;

  repeat
    Inc(P);
    if P > Length(S) then
    begin
      VRMLWarning(vwIgnorable, 'PLUG declaration unexpected end (no closing parenthesis ")")');
      Exit(false);
    end;

    if S[P] = '(' then
      Inc(ParenLevel) else
    if S[P] = ')' then
      Dec(ParenLevel);
  until ParenLevel = 0;
end;

{ TLightShader --------------------------------------------------------------- }

destructor TLightShader.Destroy;
begin
  FreeAndNil(FCode);
  inherited;
end;

function TLightShader.Code: TDynStringArray;
var
  Defines: string;
begin
  if FCode = nil then
  begin
    FCode := TDynStringArray.Create;

    Defines := '';
    if Node <> nil then
    begin
      Defines += '#define LIGHT_TYPE_KNOWN' + NL;
      if Node is TVRMLPositionalLightNode then
      begin
        Defines += '#define LIGHT_TYPE_POSITIONAL' + NL;
        if (Node is TNodeSpotLight_1) or
           (Node is TNodeSpotLight_2) then
          Defines += '#define LIGHT_TYPE_SPOT' + NL;
      end;
      if Node.FdAmbientIntensity.Value <> 0 then
        Defines += '#define LIGHT_HAS_AMBIENT' + NL;
      if not PerfectlyZeroVector(MaterialSpecularColor) then
        Defines += '#define LIGHT_HAS_SPECULAR' + NL;
    end else
    begin
      Defines += '#define LIGHT_HAS_AMBIENT' + NL;
      Defines += '#define LIGHT_HAS_SPECULAR' + NL;
    end;

    FCode.Add(Defines + StringReplace({$I template_add_light.glsl.inc},
      'light_number', IntToStr(Number), [rfReplaceAll]));

    if Node <> nil then
      Shader.EnableEffects(Node.FdEffects, FCode);
  end;

  Result := FCode;
end;

{ TLightShaders -------------------------------------------------------------- }

function TLightShaders.Find(const Node: TNodeX3DLightNode; out Shader: TLightShader): boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].Node = Node then
    begin
      Shader := Items[I];
      Exit(true);
    end;
  Shader := nil;
  Result := false;
end;

{ TVRMLShaderProgram ------------------------------------------------------- }

constructor TVRMLShaderProgram.Create;
begin
  inherited;
  EventsObserved := TVRMLEventsList.Create;
  UniformsNodes := TVRMLNodesList.Create;
end;

destructor TVRMLShaderProgram.Destroy;
var
  I: Integer;
begin
  if EventsObserved <> nil then
  begin
    for I := 0 to EventsObserved.Count - 1 do
      EventsObserved[I].OnReceive.Remove(@EventReceive);
    FreeAndNil(EventsObserved);
  end;
  FreeAndNil(UniformsNodes);
  inherited;
end;

procedure TVRMLShaderProgram.BindUniform(const FieldOrEvent: TVRMLInterfaceDeclaration;
  const EnableDisable: boolean);
var
  UniformField: TVRMLField;
  UniformEvent, ObservedEvent: TVRMLEvent;
begin
  UniformField := FieldOrEvent.Field;
  UniformEvent := FieldOrEvent.Event;

  { Set initial value for this GLSL uniform variable,
    from VRML field or exposedField }

  if UniformField <> nil then
  begin
    { Ok, we have a field with a value (interface declarations with
      fields inside ComposedShader / Effect always have a value).
      So set GLSL uniform variable from this field. }
    SetUniformFromField(UniformField.Name, UniformField, EnableDisable);
  end;

  { Allow future changing of this GLSL uniform variable,
    from VRML eventIn or exposedField }

  { calculate ObservedEvent }
  ObservedEvent := nil;
  if (UniformField <> nil) and UniformField.Exposed then
    ObservedEvent := UniformField.ExposedEvents[false] else
  if (UniformEvent <> nil) and UniformEvent.InEvent then
    ObservedEvent := UniformEvent;

  if ObservedEvent <> nil then
  begin
    ObservedEvent.OnReceive.Add(@EventReceive);
    EventsObserved.Add(ObservedEvent);
  end;
end;

procedure TVRMLShaderProgram.SetUniformFromField(
  const UniformName: string; const UniformValue: TVRMLField;
  const EnableDisable: boolean);
var
  TempF: TDynSingleArray;
  TempVec2f: TDynVector2SingleArray;
  TempVec3f: TDynVector3SingleArray;
  TempVec4f: TDynVector4SingleArray;
  TempMat3f: TDynMatrix3SingleArray;
  TempMat4f: TDynMatrix4SingleArray;
begin
  { program must be active to set uniform values. }
  if EnableDisable then
    Enable;

  if UniformValue is TSFBool then
    SetUniform(UniformName, TSFBool(UniformValue).Value) else
  if UniformValue is TSFLong then
    { Handling of SFLong also takes care of SFInt32. }
    SetUniform(UniformName, TSFLong(UniformValue).Value) else
  if UniformValue is TSFVec2f then
    SetUniform(UniformName, TSFVec2f(UniformValue).Value) else
  { Check TSFColor first, otherwise TSFVec3f would also catch and handle
    TSFColor. And we don't want this: for GLSL, color is passed
    as vec4 (so says the spec, I guess that the reason is that for GLSL most
    input/output colors are vec4). }
  if UniformValue is TSFColor then
    SetUniform(UniformName, Vector4Single(TSFColor(UniformValue).Value, 1.0)) else
  if UniformValue is TSFVec3f then
    SetUniform(UniformName, TSFVec3f(UniformValue).Value) else
  if UniformValue is TSFVec4f then
    SetUniform(UniformName, TSFVec4f(UniformValue).Value) else
  if UniformValue is TSFRotation then
    SetUniform(UniformName, TSFRotation(UniformValue).Value) else
  if UniformValue is TSFMatrix3f then
    SetUniform(UniformName, TSFMatrix3f(UniformValue).Value) else
  if UniformValue is TSFMatrix4f then
    SetUniform(UniformName, TSFMatrix4f(UniformValue).Value) else
  if UniformValue is TSFFloat then
    SetUniform(UniformName, TSFFloat(UniformValue).Value) else
  if UniformValue is TSFDouble then
    { SFDouble also takes care of SFTime }
    SetUniform(UniformName, TSFDouble(UniformValue).Value) else

  { Double-precision vector and matrix types.

    Note that X3D spec specifies only mapping for SF/MFVec3d, 4d
    (not specifying any mapping for SF/MFVec2d, and all matrix types).
    And it specifies that they map to types float3, float4 ---
    which are not valid types in GLSL?

    So I simply ignore non-sensible specification, and take
    the reasonable approach: support all double-precision vectors and matrices,
    just like single-precision. }
  if UniformValue is TSFVec2d then
    SetUniform(UniformName, Vector2Single(TSFVec2d(UniformValue).Value)) else
  if UniformValue is TSFVec3d then
    SetUniform(UniformName, Vector3Single(TSFVec3d(UniformValue).Value)) else
  if UniformValue is TSFVec4d then
    SetUniform(UniformName, Vector4Single(TSFVec4d(UniformValue).Value)) else
  if UniformValue is TSFMatrix3d then
    SetUniform(UniformName, Matrix3Single(TSFMatrix3d(UniformValue).Value)) else
  if UniformValue is TSFMatrix4d then
    SetUniform(UniformName, Matrix4Single(TSFMatrix4d(UniformValue).Value)) else

  { Now repeat this for array types }
  if UniformValue is TMFBool then
    SetUniform(UniformName, TMFBool(UniformValue).Items) else
  if UniformValue is TMFLong then
    SetUniform(UniformName, TMFLong(UniformValue).Items) else
  if UniformValue is TMFVec2f then
    SetUniform(UniformName, TMFVec2f(UniformValue).Items) else
  if UniformValue is TMFColor then
  begin
    TempVec4f := TMFColor(UniformValue).Items.ToVector4Single(1.0);
    try
      SetUniform(UniformName, TempVec4f);
    finally FreeAndNil(TempVec4f) end;
  end else
  if UniformValue is TMFVec3f then
    SetUniform(UniformName, TMFVec3f(UniformValue).Items) else
  if UniformValue is TMFVec4f then
    SetUniform(UniformName, TMFVec4f(UniformValue).Items) else
  if UniformValue is TMFRotation then
    SetUniform(UniformName, TMFRotation(UniformValue).Items) else
  if UniformValue is TMFMatrix3f then
    SetUniform(UniformName, TMFMatrix3f(UniformValue).Items) else
  if UniformValue is TMFMatrix4f then
    SetUniform(UniformName, TMFMatrix4f(UniformValue).Items) else
  if UniformValue is TMFFloat then
    SetUniform(UniformName, TMFFloat(UniformValue).Items) else
  if UniformValue is TMFDouble then
  begin
    TempF := TMFDouble(UniformValue).Items.ToSingle;
    try
      SetUniform(UniformName, TempF);
    finally FreeAndNil(TempF) end;
  end else
  if UniformValue is TMFVec2d then
  begin
    TempVec2f := TMFVec2d(UniformValue).Items.ToVector2Single;
    try
      SetUniform(UniformName, TempVec2f);
    finally FreeAndNil(TempVec2f) end;
  end else
  if UniformValue is TMFVec3d then
  begin
    TempVec3f := TMFVec3d(UniformValue).Items.ToVector3Single;
    try
      SetUniform(UniformName, TempVec3f);
    finally FreeAndNil(TempVec3f) end;
  end else
  if UniformValue is TMFVec4d then
  begin
    TempVec4f := TMFVec4d(UniformValue).Items.ToVector4Single;
    try
      SetUniform(UniformName, TempVec4f);
    finally FreeAndNil(TempVec4f) end;
  end else
  if UniformValue is TMFMatrix3d then
  begin
    TempMat3f := TMFMatrix3d(UniformValue).Items.ToMatrix3Single;
    try
      SetUniform(UniformName, TempMat3f);
    finally FreeAndNil(TempMat3f) end;
  end else
  if UniformValue is TMFMatrix4d then
  begin
    TempMat4f := TMFMatrix4d(UniformValue).Items.ToMatrix4Single;
    try
      SetUniform(UniformName, TempMat4f);
    finally FreeAndNil(TempMat4f) end;
  end else
  if (UniformValue is TSFNode) or
     (UniformValue is TMFNode) then
  begin
    { Nothing to do, these will be set by TGLSLRenderer.Enable }
  end else
    { TODO: other field types, full list is in X3D spec in
      "OpenGL shading language (GLSL) binding".
      Remaining:
      SF/MFImage }
    VRMLWarning(vwSerious, 'Setting uniform GLSL variable from X3D field type "' + UniformValue.VRMLTypeName + '" not supported');

  if EnableDisable then
    { TODO: this should restore previously bound program }
    Disable;
end;

procedure TVRMLShaderProgram.EventReceive(
  Event: TVRMLEvent; Value: TVRMLField; const Time: TVRMLTime);
var
  UniformName: string;
  EventsEngine: TVRMLEventsEngine;
begin
  if Event.ParentExposedField = nil then
    UniformName := Event.Name else
    UniformName := Event.ParentExposedField.Name;

  SetUniformFromField(UniformName, Value, true);

  { Although ExposedEvents implementation already sends notification
    about changes to EventsEngine, we can also get here
    by eventIn invocation (which doesn't trigger
    EventsEngine.ChangedField, since it doesn't change a field...).
    So we should explicitly do VisibleChangeHere here, to make sure
    it gets called when uniform changed. }
  if Event.ParentNode <> nil then
  begin
    EventsEngine := (Event.ParentNode as TVRMLNode).EventsEngine;
    if EventsEngine <> nil then
      EventsEngine.VisibleChangeHere([vcVisibleGeometry, vcVisibleNonGeometry]);
  end;
end;

procedure TVRMLShaderProgram.BindUniforms(const Node: TVRMLNode;
  const EnableDisable: boolean);
var
  I: Integer;
begin
  Assert(Node.HasInterfaceDeclarations <> []);
  Assert(Node.InterfaceDeclarations <> nil);
  for I := 0 to Node.InterfaceDeclarations.Count - 1 do
    BindUniform(Node.InterfaceDeclarations[I], EnableDisable);
  UniformsNodes.Add(Node);
end;

procedure TVRMLShaderProgram.BindUniforms(const Nodes: TVRMLNodesList;
  const EnableDisable: boolean);
var
  I: Integer;
begin
  for I := 0 to Nodes.Count - 1 do
    BindUniforms(Nodes[I], EnableDisable);
end;

{ TTextureShader ------------------------------------------------------------- }

procedure TTextureShader.Enable(var TextureApply, TextureColorDeclare,
  TextureCoordInitialize, TextureCoordMatrix, TextureUniformsDeclare: string);
const
  OpenGLTextureType: array [TTextureType] of string =
  ('sampler2D', 'sampler2DShadow', 'samplerCube', 'sampler3D', '');
var
  Uniform: TUniform;
  TextureSampleCall, TexCoordName: string;
  ShadowLightShader: TLightShader;
  Code: TDynStringArray;
  I: Integer;
begin
  if TextureType <> ttShader then
  begin
    Uniform := TUniform.Create;
    Uniform.Name := Format('texture_%d', [TextureUnit]);
    Uniform.AType := utLongInt;
    Uniform.Value.LongInt := TextureUnit;

    Shader.AddUniform(Uniform);
  end;

  TexCoordName := Format('gl_TexCoord[%d]', [TextureUnit]);

  TextureCoordInitialize += Format('%s = gl_MultiTexCoord%d;' + NL,
    [TexCoordName, TextureUnit]);
  TextureCoordMatrix += Format('%s = gl_TextureMatrix[%d] * %0:s;' + NL,
    [TexCoordName, TextureUnit]);

  if (TextureType = tt2DShadow) and
      ShadowVisualizeDepth then
  begin
    { visualizing depth map requires a little different approach:
      - we use shadow_depth() instead of shadow() function
      - we *set* gl_FragColor, not modulate it, to ignore previous textures
      - we call "return" after, to ignore following textures
      - the sampler is sampler2D, not sampler2DShadow
      - also, we use gl_FragColor (while we should use fragment_color otherwise),
        because we don't care about previous texture operations and
        we want to return immediately. }
    TextureSampleCall := 'vec4(vec3(shadow_depth(%s, %s)), gl_FragColor.a)';
    TextureApply += Format('gl_FragColor = ' + TextureSampleCall + ';' + NL +
      'return;',
      [Uniform.Name, TexCoordName]);
    TextureUniformsDeclare += Format('uniform sampler2D %s;' + NL,
      [Uniform.Name]);
  end else
  begin
    if (TextureType = tt2DShadow) and
       (ShadowLight <> nil) and
       Shader.LightShaders.Find(ShadowLight, ShadowLightShader) then
    begin
      Shader.Plug(stFragment,
        Format('uniform %s %s;',
        [OpenGLTextureType[TextureType], Uniform.Name]) +NL+
        'float shadow(sampler2DShadow shadowMap, vec4 shadowMapCoord, const in float size);' +NL+
        'void PLUG_light_scale(inout float scale, const in vec3 normal_eye, const in vec3 light_dir, const in gl_LightSourceParameters light_source, const in gl_LightProducts light_products, const in gl_MaterialParameters material)' +NL+
        '{' +NL+
        Format('  scale *= shadow(%s, gl_TexCoord[%d], %d.0);',
        [Uniform.Name, TextureUnit, ShadowMapSize]) +NL+
        '}',
        ShadowLightShader.Code);
    end else
    begin
      if TextureColorDeclare = '' then
        TextureColorDeclare := 'vec4 texture_color;' + NL;
      case TextureType of
        tt2D      : TextureSampleCall := 'texture2D(%s, %s.st)';
        tt2DShadow: TextureSampleCall := 'vec4(vec3(shadow(%s, %s, ' +IntToStr(ShadowMapSize) + '.0)), fragment_color.a)';
        ttCubeMap : TextureSampleCall := 'textureCube(%s, %s.xyz)';
        { For 3D textures, remember we may get 4D tex coords
          through TextureCoordinate4D, so we have to use texture3DProj }
        tt3D      : TextureSampleCall := 'texture3DProj(%s, %s)';
        ttShader  : TextureSampleCall := 'vec4(1.0, 0.0, 1.0, 1.0)';
        else raise EInternalError.Create('TVRMLShader.EnableTexture:TextureType?');
      end;

      Code := TDynStringArray.Create;
      try
        if TextureType <> ttShader then
          Code.Add(Format('texture_color = ' + TextureSampleCall + ';' +NL+
            '/* PLUG: texture_color (texture_color, %0:s, %1:s) */' +NL,
            [Uniform.Name, TexCoordName])) else
          Code.Add(Format('texture_color = ' + TextureSampleCall + ';' +NL+
            '/* PLUG: texture_color (texture_color, %0:s) */' +NL,
            [TexCoordName]));

        Shader.EnableEffects(Node.FdEffects, Code, true);

        { Use generated Code. Code[0] for texture is a little special,
          we add it to TextureApply that will be directly placed within
          the source. }
        TextureApply += Code[0];
        { Don't add to empty Source[stFragment], in case ComposedShader
          doesn't want any fragment shader }
        if Shader.Source[stFragment].Count <> 0 then
          for I := 1 to Code.Count - 1 do
            Shader.Source[stFragment].Add(Code[I]);
      finally FreeAndNil(Code) end;

      { TODO: always modulate mode for now }
      TextureApply += 'fragment_color *= texture_color;' + NL;

      if TextureType <> ttShader then
        TextureUniformsDeclare += Format('uniform %s %s;' + NL,
          [OpenGLTextureType[TextureType], Uniform.Name]);
    end;
  end;
end;

{ TVRMLShader ---------------------------------------------------------------- }

function InsertIntoString(const Base: string; const P: Integer; const S: string): string;
begin
  Result := Copy(Base, 1, P - 1) + S + SEnding(Base, P);
end;

constructor TVRMLShader.Create;
var
  SourceType: TShaderType;
begin
  inherited;

  for SourceType := Low(SourceType) to High(SourceType) do
    Source[SourceType] := TDynStringArray.Create;
  Source[stVertex].Add({$I template.vs.inc});
  Source[stFragment].Add({$I template.fs.inc});

  LightShaders := TLightShaders.Create;
  TextureShaders := TTextureShaders.Create;
  WarnMissingPlugs := true;
end;

destructor TVRMLShader.Destroy;
var
  SourceType: TShaderType;
begin
  FreeAndNil(Uniforms);
  FreeAndNil(UniformsNodes);
  FreeAndNil(LightShaders);
  FreeAndNil(TextureShaders);
  for SourceType := Low(SourceType) to High(SourceType) do
    FreeAndNil(Source[SourceType]);
  inherited;
end;

procedure TVRMLShader.Plug(const EffectPartType: TShaderType; PlugValue: string;
  Code: TDynStringArray; const ForwardDeclareInFinalShader: boolean);
const
  PlugPrefix = 'PLUG_';

  { Find PLUG_xxx function inside PlugValue.
    Returns xxx (the part after PLUG_),
    and DeclaredParameters (or this plug function). Or '' if not found. }
  function FindPlugName(const PlugValue: string;
    out DeclaredParameters: string): string;
  const
    IdentifierChars = ['0'..'9', 'a'..'z', 'A'..'Z', '_'];
  var
    P, PBegin, DPBegin, DPEnd: Integer;
  begin
    Result := ''; { assume failure }
    P := Pos(PlugPrefix, PlugValue);
    if P <> 0 then
    begin
      { There must be whitespace before PLUG_ }
      if (P > 1) and (not (PlugValue[P - 1] in WhiteSpaces)) then Exit;
      P += Length(PlugPrefix);
      PBegin := P;
      { There must be at least one identifier char after PLUG_ }
      if (P > Length(PlugValue)) or
         (not (PlugValue[P] in IdentifierChars)) then Exit;
      repeat
        Inc(P);
      until (P > Length(PlugValue)) or (not (PlugValue[P] in IdentifierChars));
      { There must be a whitespace or ( after PLUG_xxx }
      if (P > Length(PlugValue)) or (not (PlugValue[P] in (WhiteSpaces + ['(']))) then
        Exit;

      Result := CopyPos(PlugValue, PBegin, P - 1);

      DPBegin := P - 1;
      if not MoveToOpeningParen(PlugValue, DPBegin) then Exit('');
      DPEnd := DPBegin;
      if not MoveToMatchingParen(PlugValue, DPEnd) then Exit('');

      DeclaredParameters := CopyPos(PlugValue, DPBegin, DPEnd);
    end;
  end;

  procedure InsertIntoCode(const CodeIndex, P: Integer; const S: string);
  begin
    Code[CodeIndex] := InsertIntoString(Code[CodeIndex], P, S);
  end;

  function FindPlugOccurence(const CommentBegin, Code: string;
    const CodeSearchBegin: Integer; out PBegin, PEnd: Integer): boolean;
  begin
    Result := false;
    PBegin := PosEx(CommentBegin, Code, CodeSearchBegin);
    if PBegin <> 0 then
    begin
      PEnd := PosEx('*/', Code, PBegin + Length(CommentBegin));
      Result :=  PEnd <> 0;
      if not Result then
        VRMLWarning(vwIgnorable, Format('Plug comment "%s" not properly closed, treating like not declared',
          [CommentBegin]));
    end;
  end;

var
  PBegin, PEnd, CodeSearchBegin, CodeIndex: Integer;
  Parameter, PlugName, ProcedureName, CommentBegin, PlugDeclaredParameters,
    PlugForwardDeclaration: string;
  CodeForPlugValue: TDynStringArray;
  AnyOccurences, AnyOccurencesInThisCodeIndex: boolean;
begin
  CodeForPlugValue := Source[EffectPartType];

  if Code = nil then
    Code := CodeForPlugValue;

  repeat
    PlugName := FindPlugName(PlugValue, PlugDeclaredParameters);
    if PlugName = '' then Break;

    { When using vertex_object_space_change plug, we need to do something
      special: use VERTEX_OBJECT_SPACE_CHANGED, otherwise standard
      ftransform() will ignore vertex object space change. }
    if (PlugName = 'vertex_object_space_change') and
       (Code = Source[stVertex]) then
      PlugDirectly(Source[stVertex], 0, '/* PLUG-DECLARATIONS */',
        '#define VERTEX_OBJECT_SPACE_CHANGED', false);

    CommentBegin := '/* PLUG: ' + PlugName + ' ';

    ProcedureName := 'plugged_' + IntToStr(PlugIdentifiers);
    StringReplaceAllTo1st(PlugValue, 'PLUG_' + PlugName, ProcedureName, false);
    Inc(PlugIdentifiers);

    PlugForwardDeclaration := 'void ' + ProcedureName + PlugDeclaredParameters + ';' + NL;

    AnyOccurences := false;
    for CodeIndex := 0 to Code.Count - 1 do
    begin
      CodeSearchBegin := 1;
      AnyOccurencesInThisCodeIndex := false;
      while FindPlugOccurence(CommentBegin, Code[CodeIndex], CodeSearchBegin, PBegin, PEnd) do
      begin
        Parameter := Trim(CopyPos(Code[CodeIndex], PBegin + Length(CommentBegin), PEnd - 1));
        InsertIntoCode(CodeIndex, PBegin, ProcedureName + Parameter + ';' + NL);

        { do not find again the same plug comment by FindPlugOccurence }
        CodeSearchBegin := PEnd;

        AnyOccurencesInThisCodeIndex := true;
        AnyOccurences := true;
      end;

      if AnyOccurencesInThisCodeIndex then
      begin
        { added "plugged_x" function must be forward declared first.
          Otherwise it could be defined after it is needed, or inside different
          compilation unit. }
        if ForwardDeclareInFinalShader and (CodeIndex = 0) then
          PlugDirectly(CodeForPlugValue, CodeIndex, '/* PLUG-DECLARATIONS */', PlugForwardDeclaration, true) else
          PlugDirectly(Code            , CodeIndex, '/* PLUG-DECLARATIONS */', PlugForwardDeclaration, true);
      end;
    end;

    if (not AnyOccurences) and WarnMissingPlugs then
      VRMLWarning(vwIgnorable, Format('Plug name "%s" not declared', [PlugName]));
  until false;

  { regardless if any (and how many) plug points were found,
    always insert PlugValue into CodeForPlugValue }
  CodeForPlugValue.Add(PlugValue);
end;

procedure TVRMLShader.PlugDirectly(Code: TDynStringArray;
  const CodeIndex: Cardinal;
  const PlugName, PlugValue: string;
  const InsertAtBeginIfNotFound: boolean);
var
  P: Integer;
  Done:  boolean;
begin
  Done := false;

  if CodeIndex < Code.Count then
  begin
    P := Pos(PlugName, Code[CodeIndex]);
    if P <> 0 then
    begin
      Code[CodeIndex] := InsertIntoString(Code[CodeIndex], P, PlugValue + NL);
      Done := true;
    end else
    if InsertAtBeginIfNotFound then
    begin
      Code[CodeIndex] := PlugValue + NL + Code[CodeIndex];
      Done := true;
    end;
  end;

  if (not Done) and WarnMissingPlugs then
    VRMLWarning(vwIgnorable, Format('Plug point "%s" not found', [PlugName]));
end;

procedure TVRMLShader.LinkProgram(AProgram: TVRMLShaderProgram);
var
  TextureApply, TextureColorDeclare, TextureCoordInitialize,
    TextureCoordMatrix, TextureUniformsDeclare: string;

  procedure EnableTextures;
  var
    I: Integer;
  begin
    TextureApply := '';
    TextureColorDeclare := '';
    TextureCoordInitialize := '';
    TextureCoordMatrix := '';
    TextureUniformsDeclare := '';

    for I := 0 to TextureShaders.Count - 1 do
      TextureShaders[I].Enable(TextureApply, TextureColorDeclare,
        TextureCoordInitialize, TextureCoordMatrix, TextureUniformsDeclare);
  end;

  { Applies effects from various strings here.
    This also finalizes applying textures. }
  procedure EnableInternalEffects;
  const
    PCFDefine: array [TPercentageCloserFiltering] of string =
    ( '', '#define PCF4', '#define PCF4_BILINEAR', '#define PCF16' );
  begin
    PlugDirectly(Source[stVertex], 0, '/* PLUG: vertex_eye_space',
      TextureCoordInitialize + TextureCoordGen + TextureCoordMatrix + ClipPlane, false);
    PlugDirectly(Source[stFragment], 0, '/* PLUG: texture_apply',
      TextureColorDeclare + TextureApply, false);
    PlugDirectly(Source[stFragment], 0, '/* PLUG: fragment_end', FragmentEnd, false);

    { TODO: Using true as last param here would be better
      (composed_shader_using_plugs.x3dv should not need /* PLUG-DECLARATIONS */),
      but it could also add unneeded stuff --- if ComposedShader is not prepared,
      then it could make it break (e.g. adding stuff before #version and such).
      This waits for fixing ComposedShader: normal textures should not be
      passed then at all, so our texture_0 should not even exist
      and TextureUniformsDeclare should be empty?
      This would also fix "missing texture_0" warnings on normal shaders/
      demos. }
    PlugDirectly(Source[stFragment], 0, '/* PLUG-DECLARATIONS */',
      TextureUniformsDeclare, false);

    { Don't add to empty Source[stFragment], in case ComposedShader
      doesn't want any fragment shader }
    if Source[stFragment].Count <> 0 then
      Source[stFragment].Add(PCFDefine[PercentageCloserFiltering] + NL +
        {$I shadow_map_common.fs.inc});
  end;

  procedure EnableLights;
  var
    I, J: Integer;
    LightShaderBack, LightShaderFront: string;
  begin
    { If we have no fragment shader (means that we used ComposedShader node
      without fragment shader) then don't add light sources code.
      Otherwise we would create a fragment shader without any main() inside. }
    if Source[stFragment].Count = 0 then Exit;

    for I := 0 to LightShaders.Count - 1 do
    begin
      LightShaderBack  := LightShaders[I].Code[0];
      LightShaderFront := LightShaderBack;

      LightShaderBack := StringReplace(LightShaderBack,
        'gl_SideLightProduct', 'gl_BackLightProduct' , [rfReplaceAll]);
      LightShaderFront := StringReplace(LightShaderFront,
        'gl_SideLightProduct', 'gl_FrontLightProduct', [rfReplaceAll]);

      LightShaderBack := StringReplace(LightShaderBack,
        'add_light_contribution_side', 'add_light_contribution_back' , [rfReplaceAll]);
      LightShaderFront := StringReplace(LightShaderFront,
        'add_light_contribution_side', 'add_light_contribution_front', [rfReplaceAll]);

      Plug(stFragment, LightShaderBack);
      Plug(stFragment, LightShaderFront);

      for J := 1 to LightShaders[I].Code.Count - 1 do
        Source[stFragment].Add(LightShaders[I].Code[J]);
    end;
  end;

  procedure SetupUniformsOnce;
  var
    I: Integer;
  begin
    AProgram.Enable;

    if Uniforms <> nil then
      for I := 0 to Uniforms.Count - 1 do
        case Uniforms[I].AType of
          utLongInt: AProgram.SetUniform(Uniforms[I].Name, Uniforms[I].Value.LongInt);
          utSingle : AProgram.SetUniform(Uniforms[I].Name, Uniforms[I].Value.Single );
          else raise EInternalError.Create('TVRMLShader.SetupUniformsOnce:Uniforms[I].Type?');
        end;

    if UniformsNodes <> nil then
      AProgram.BindUniforms(UniformsNodes, false);

    AProgram.Disable;
  end;

var
  I: Integer;
begin
  EnableTextures;
  EnableInternalEffects;
  EnableLights;
  if AppearanceEffects <> nil then
    EnableEffects(AppearanceEffects);
  if GroupEffects <> nil then
    EnableEffects(GroupEffects);

  if Log and LogShaders then
  begin
    for I := 0 to Source[stVertex].Count - 1 do
      WritelnLogMultiline(Format('Generated GLSL vertex shader[%d]', [I]),
        Source[stVertex][I]);
    for I := 0 to Source[stFragment].Count - 1 do
      WritelnLogMultiline(Format('Generated GLSL fragment shader[%d]', [I]),
        Source[stFragment][I]);
  end;

  try
    if (Source[stVertex].Count = 0) and
       (Source[stFragment].Count = 0) then
      raise EGLSLError.Create('No vertex and no fragment shader for GLSL program');

    for I := 0 to Source[stVertex].Count - 1 do
      AProgram.AttachVertexShader(Source[stVertex][I]);
    for I := 0 to Source[stFragment].Count - 1 do
      AProgram.AttachFragmentShader(Source[stFragment][I]);
    AProgram.Link(true);

    if SelectedNode <> nil then
      SelectedNode.EventIsValid.Send(true);
  except
    if SelectedNode <> nil then
      SelectedNode.EventIsValid.Send(false);
    raise;
  end;

  { X3D spec "OpenGL shading language (GLSL) binding" says
    "If the name is not available as a uniform variable in the
    provided shader source, the values of the node shall be ignored"
    (although it says when talking about "Vertex attributes",
    seems they mixed attributes and uniforms meaning in spec?).

    So we do not allow EGLSLUniformNotFound to be raised.
    Also type errors, when variable exists in shader but has different type,
    will be send to DataWarning. }
  AProgram.UniformNotFoundAction := uaWarning;
  AProgram.UniformTypeMismatchAction := utWarning;

  { set uniforms that will not need to be updated at each SetupUniforms call }
  SetupUniformsOnce;
end;

function TVRMLShader.CodeHash: TShaderCodeHash;

  {$include norqcheckbegin.inc}

  function CodeHashCalculate: TShaderCodeHash;
  type
    TShaderCodeHashRec = packed record Sum, XorValue: LongWord; end;

    procedure AddString(const S: AnsiString; var Res: TShaderCodeHashRec);
    var
      PS: PLongWord;
      Last: LongWord;
      I: Integer;
    begin
      PS := PLongWord(S);


      for I := 1 to Length(S) div 4 do
      begin
        Res.Sum := Res.Sum + PS^;
        Res.XorValue := Res.XorValue xor PS^;
        Inc(PS);
      end;

      if Length(S) mod 4 = 0 then
      begin
        Last := 0;
        Move(S[(Length(S) div 4) * 4 + 1], Last, Length(S) mod 4);
        Res.Sum := Res.Sum + Last;
        Res.XorValue := Res.XorValue xor Last;
      end;
    end;

    procedure AddPointerHash(Ptr: Pointer; var Res: TShaderCodeHashRec);
    begin
      { This will cut the pointer on non-32bit processors.
        But that's not a problem --- we just want it for hash,
        taking the least significant 32 bits from pointer is OK for this. }
      Res.Sum += LongWord(PtrUInt(Ptr));
      Res.XorValue := Res.XorValue xor LongWord(PtrUInt(Ptr));
    end;

    procedure AddEffectsHash(Nodes: TVRMLNodesList; var Res: TShaderCodeHashRec);
    var
      I: Integer;
    begin
      for I := 0 to Nodes.Count - 1 do
        if (Nodes[I] is TNodeEffect) and
           TNodeEffect(Nodes[I]).FdEnabled.Value then
          AddPointerHash(Nodes[I], Res);
    end;

  var
    Res: TShaderCodeHashRec absolute Result;
    I: Integer;
  begin
    Res.Sum := 0;
    Res.XorValue := 0;
    for I := 0 to Source[stVertex].Count - 1 do
      AddString(Source[stVertex][I], Res);
    for I := 0 to Source[stFragment].Count - 1 do
      AddString(Source[stFragment][I], Res);

    { Add to hash things that affect generated shader code,
      but are applied after CodeHash is calculated (like in LinkProgram). }
    Res.Sum += LightShaders.Count;
    Res.Sum += TextureShaders.Count;
    Res.Sum += Ord(PercentageCloserFiltering);
    if AppearanceEffects <> nil then
      AddEffectsHash(AppearanceEffects.Items, Res);
    if GroupEffects <> nil then
      AddEffectsHash(GroupEffects, Res);
  end;

  {$include norqcheckend.inc}

begin
  if not CodeHashCalculated then
  begin
    FCodeHash := CodeHashCalculate;
    CodeHashCalculated := true;
  end;
  Result := FCodeHash;
end;

procedure TVRMLShader.AddUniform(Uniform: TUniform);
begin
  if Uniforms = nil then
    Uniforms := TUniformsList.Create;
  Uniforms.Add(Uniform);
end;

procedure TVRMLShader.EnableTexture(const TextureUnit: Cardinal;
  const TextureType: TTextureType;
  const Node: TNodeX3DTextureNode;
  const ShadowMapSize: Cardinal;
  const ShadowLight: TNodeX3DLightNode;
  const ShadowVisualizeDepth: boolean);
var
  TextureShader: TTextureShader;
begin
  { Enable for fixed-function pipeline }
  if GLUseMultiTexturing then
    glActiveTextureARB(GL_TEXTURE0 + TextureUnit);
  case TextureType of
    tt2D, tt2DShadow:
      begin
        glEnable(GL_TEXTURE_2D);
        if GL_ARB_texture_cube_map then glDisable(GL_TEXTURE_CUBE_MAP_ARB);
        if GL_EXT_texture3D        then glDisable(GL_TEXTURE_3D_EXT);
      end;
    ttCubeMap:
      begin
        glDisable(GL_TEXTURE_2D);
        if GL_ARB_texture_cube_map then glEnable(GL_TEXTURE_CUBE_MAP_ARB);
        if GL_EXT_texture3D        then glDisable(GL_TEXTURE_3D_EXT);
      end;
    tt3D:
      begin
        glDisable(GL_TEXTURE_2D);
        if GL_ARB_texture_cube_map then glDisable(GL_TEXTURE_CUBE_MAP_ARB);
        if GL_EXT_texture3D        then glEnable(GL_TEXTURE_3D_EXT);
      end;
    ttShader:
      begin
        glDisable(GL_TEXTURE_2D);
        if GL_ARB_texture_cube_map then glDisable(GL_TEXTURE_CUBE_MAP_ARB);
        if GL_EXT_texture3D        then glDisable(GL_TEXTURE_3D_EXT);
      end;
    else raise EInternalError.Create('TextureEnableDisable?');
  end;

  { Enable for shader pipeline }

  TextureShader := TTextureShader.Create;
  TextureShader.TextureUnit := TextureUnit;
  TextureShader.TextureType := TextureType;
  TextureShader.Node := Node;
  TextureShader.ShadowMapSize := ShadowMapSize;
  TextureShader.ShadowLight := ShadowLight;
  TextureShader.ShadowVisualizeDepth := ShadowVisualizeDepth;
  TextureShader.Shader := Self;

  TextureShaders.Add(TextureShader);

  if (TextureType in [ttShader, tt2DShadow]) or
     (Node.FdEffects.Count <> 0) then
    ShapeRequiresShaders := true;
end;

procedure TVRMLShader.EnableTexGen(const TextureUnit: Cardinal;
  const Generation: TTexGenerationComplete);
begin
  { Enable for fixed-function pipeline }
  if GLUseMultiTexturing then
    glActiveTextureARB(GL_TEXTURE0 + TextureUnit);
  { glEnable(GL_TEXTURE_GEN_*) below }

  { Enable for shader pipeline }
  case Generation of
    tgSphere:
      begin
        glEnable(GL_TEXTURE_GEN_S);
        glEnable(GL_TEXTURE_GEN_T);
        TextureCoordGen += Format(
          { Sphere mapping in GLSL adapted from
            http://www.ozone3d.net/tutorials/glsl_texturing_p04.php#part_41
            by Jerome Guinot aka 'JeGX', many thanks! }
          'vec3 r = reflect( normalize(vec3(vertex_eye)), normal_eye );' + NL +
	  'float m = 2.0 * sqrt( r.x*r.x + r.y*r.y + (r.z+1.0)*(r.z+1.0) );' + NL +
          '/* Using 1.0 / 2.0 instead of 0.5 to workaround fglrx bugs */' + NL +
	  'gl_TexCoord[%d].st = r.xy / m + vec2(1.0, 1.0) / 2.0;',
          [TextureUnit]);
      end;
    tgNormal:
      begin
        glEnable(GL_TEXTURE_GEN_S);
        glEnable(GL_TEXTURE_GEN_T);
        glEnable(GL_TEXTURE_GEN_R);
        TextureCoordGen += Format('gl_TexCoord[%d].xyz = normal_eye;' + NL,
          [TextureUnit]);
      end;
    tgReflection:
      begin
        glEnable(GL_TEXTURE_GEN_S);
        glEnable(GL_TEXTURE_GEN_T);
        glEnable(GL_TEXTURE_GEN_R);
        { Negate reflect result --- just like for demo_models/water/water_reflections_normalmap.fs }
        TextureCoordGen += Format('gl_TexCoord[%d].xyz = -reflect(-vec3(vertex_eye), normal_eye);' + NL,
          [TextureUnit]);
      end;
    else raise EInternalError.Create('TVRMLShader.EnableTexGen:Generation?');
  end;
end;

procedure TVRMLShader.EnableTexGen(const TextureUnit: Cardinal;
  const Generation: TTexGenerationComponent; const Component: TTexComponent);
const
  PlaneComponentNames: array [TTexComponent] of char = ('S', 'T', 'R', 'Q');
  { Note: R changes to p ! }
  VectorComponentNames: array [TTexComponent] of char = ('s', 't', 'p', 'q');
var
  PlaneName, CoordSource: string;
begin
  { Enable for fixed-function pipeline }
  if GLUseMultiTexturing then
    glActiveTextureARB(GL_TEXTURE0 + TextureUnit);
  case Component of
    0: glEnable(GL_TEXTURE_GEN_S);
    1: glEnable(GL_TEXTURE_GEN_T);
    2: glEnable(GL_TEXTURE_GEN_R);
    3: glEnable(GL_TEXTURE_GEN_Q);
    else raise EInternalError.Create('TVRMLShader.EnableTexGen:Component?');
  end;

  { Enable for shader pipeline.
    See helpful info about simulating glTexGen in GLSL in:
    http://www.mail-archive.com/osg-users@lists.openscenegraph.org/msg14238.html }

  case Generation of
    tgEye   : begin PlaneName := 'gl_EyePlane'   ; CoordSource := 'vertex_eye'; end;
    tgObject: begin PlaneName := 'gl_ObjectPlane'; CoordSource := 'gl_Vertex' ; end;
    else raise EInternalError.Create('TVRMLShader.EnableTexGen:Generation?');
  end;

  TextureCoordGen += Format('gl_TexCoord[%d].%s = dot(%s, %s%s[%0:d]);' + NL,
    [TextureUnit, VectorComponentNames[Component],
     CoordSource, PlaneName, PlaneComponentNames[Component]]);
end;

procedure TVRMLShader.DisableTexGen(const TextureUnit: Cardinal);
begin
  { Disable for fixed-function pipeline }
  if GLUseMultiTexturing then
    glActiveTextureARB(GL_TEXTURE0 + TextureUnit);
  glDisable(GL_TEXTURE_GEN_S);
  glDisable(GL_TEXTURE_GEN_T);
  glDisable(GL_TEXTURE_GEN_R);
  glDisable(GL_TEXTURE_GEN_Q);
end;

procedure TVRMLShader.EnableClipPlane(const ClipPlaneIndex: Cardinal);
begin
  glEnable(GL_CLIP_PLANE0 + ClipPlaneIndex);
  if ClipPlane = '' then
    ClipPlane := 'gl_ClipVertex = vertex_eye;';
end;

procedure TVRMLShader.DisableClipPlane(const ClipPlaneIndex: Cardinal);
begin
  glDisable(GL_CLIP_PLANE0 + ClipPlaneIndex);
end;

procedure TVRMLShader.EnableAlphaTest;
begin
  { Enable for fixed-function pipeline }
  glEnable(GL_ALPHA_TEST);

  { Enable for shader pipeline. We know alpha comparison is always < 0.5 }
  FragmentEnd +=
    '/* Do the trick with 1.0 / 2.0, instead of comparing with 0.5, to avoid fglrx bugs */' + NL +
    'if (2.0 * gl_FragColor.a < 1.0)' + NL +
    '  discard;' + NL;
end;

procedure TVRMLShader.EnableBumpMapping(const NormalMapTextureUnit: Cardinal);
var
  Uniform: TUniform;
begin
  Plug(stVertex,
    'attribute mat3 tangent_to_object_space;' +NL+
    'varying mat3 tangent_to_eye_space;' +NL+
    NL+
    'void PLUG_vertex_eye_space(const in vec4 vertex_eye, const in vec3 normal_eye)' +NL+
    '{' +NL+
    '  tangent_to_eye_space = gl_NormalMatrix * tangent_to_object_space;' +NL+
    '}');

  Plug(stFragment,
    'varying mat3 tangent_to_eye_space;' +NL+
    'uniform sampler2D tex_normal_map;' +NL+
    NL+
    'void PLUG_fragment_normal_eye(inout vec3 normal_eye_fragment)' +NL+
    '{' +NL+
    '  /* Read normal from the texture, this is the very idea of bump mapping.' +NL+
    '     Unpack normals, they are in texture in [0..1] range and I want in [-1..1].' +NL+
    '     Our normal map is always indexed using gl_TexCoord[0] (this way' +NL+
    '     we depend on already correct gl_TexCoord[0], multiplied by TextureTransform' +NL+
    '     and such). */' +NL+
    '  normal_eye_fragment = normalize(tangent_to_eye_space * (' +NL+
    '    texture2D(tex_normal_map, gl_TexCoord[0].st).xyz * 2.0 - vec3(1.0)));' +NL+
    '}');

  Uniform := TUniform.Create;
  Uniform.Name := 'tex_normal_map';
  Uniform.AType := utLongInt;
  Uniform.Value.LongInt := NormalMapTextureUnit;

  AddUniform(Uniform);

  ShapeRequiresShaders := true;
end;

procedure TVRMLShader.EnableLight(const Number: Cardinal; Node: TNodeX3DLightNode;
  const MaterialSpecularColor: TVector3Single);
var
  LightShader: TLightShader;
begin
  LightShader := TLightShader.Create;
  LightShader.Number := Number;
  LightShader.Node := Node;
  LightShader.MaterialSpecularColor := MaterialSpecularColor;
  LightShader.Shader := Self;

  LightShaders.Add(LightShader);

  { Mark ShapeRequiresShaders now, don't depend on EnableEffects call doing it,
    as EnableEffects will be done from LinkProgram when it's too late
    to set ShapeRequiresShaders. }
  if (Node <> nil) and
     (Node.FdEffects.Count <> 0) then
    ShapeRequiresShaders := true;
end;

procedure TVRMLShader.EnableEffects(Effects: TMFNode;
  const Code: TDynStringArray;
  const ForwardDeclareInFinalShader: boolean);
begin
  EnableEffects(Effects.Items, Code, ForwardDeclareInFinalShader);
end;

procedure TVRMLShader.EnableEffects(Effects: TVRMLNodesList;
  const Code: TDynStringArray;
  const ForwardDeclareInFinalShader: boolean);

  procedure EnableEffect(Effect: TNodeEffect);

    procedure EnableEffectPart(Part: TNodeEffectPart);
    var
      Contents: string;
      PartType: TShaderType;
    begin
      Contents := Part.LoadContents;
      if (Contents <> '') and Part.FdType.GetValue(PartType) then
      begin
        Plug(PartType, Contents, Code, ForwardDeclareInFinalShader);
        ShapeRequiresShaders := true;
      end;
    end;

  var
    I: Integer;
  begin
    if not Effect.FdEnabled.Value then Exit;

    if Effect.FdLanguage.Value <> 'GLSL' then
    begin
      VRMLWarning(vwIgnorable, Format('Unknown shading language "%s" for Effect node',
        [Effect.FdLanguage.Value]));
      Exit;
    end;

    for I := 0 to Effect.FdParts.Count - 1 do
      if Effect.FdParts[I] is TNodeEffectPart then
        EnableEffectPart(TNodeEffectPart(Effect.FdParts[I]));

    if UniformsNodes = nil then
      UniformsNodes := TVRMLNodesList.Create;
    UniformsNodes.Add(Effect);
  end;

var
  I: Integer;
begin
  for I := 0 to Effects.Count - 1 do
    if Effects[I] is TNodeEffect then
      EnableEffect(TNodeEffect(Effects[I]));
end;

procedure TVRMLShader.EnableFog(const FogType: TFogType);
var
  FogFactor: string;
begin
  Plug(stVertex,
    'void PLUG_vertex_eye_space(const in vec4 vertex_eye, const in vec3 normal_eye)' +NL+
    '{' +NL+
    '  gl_FogFragCoord = vertex_eye.z;' +NL+
    '}');

  case FogType of
    ftLinear: FogFactor := '(gl_Fog.end - gl_FogFragCoord) * gl_Fog.scale';
    ftExp   : FogFactor := 'exp(-gl_Fog.density * gl_FogFragCoord)';
    else raise EInternalError.Create('TVRMLShader.EnableFog:FogType?');
  end;

  Plug(stFragment,
    'void PLUG_fog_apply(inout vec4 fragment_color, const vec3 normal_eye_fragment)' +NL+
    '{' +NL+
    '  fragment_color.rgb = mix(fragment_color.rgb, gl_Fog.color.rgb,' +NL+
    '    clamp(1.0 - ' + FogFactor + ', 0.0, 1.0));' +NL+
    '}');
end;

function TVRMLShader.EnableCustomShaderCode(Shaders: TMFNodeShaders;
  out Node: TNodeComposedShader): boolean;
var
  I, J: Integer;
  Part: TNodeShaderPart;
  PartSource: String;
  PartType, SourceType: TShaderType;
begin
  Result := false;
  for I := 0 to Shaders.Count - 1 do
  begin
    Node := Shaders.GLSLShader(I);
    if Node <> nil then
    begin
      Result := true;

      { Clear whole Source }
      for SourceType := Low(SourceType) to High(SourceType) do
        Source[SourceType].Count := 0;

      { Iterate over Node.FdParts, looking for vertex shaders
        and fragment shaders. }
      for J := 0 to Node.FdParts.Count - 1 do
        if Node.FdParts[J] is TNodeShaderPart then
        begin
          Part := TNodeShaderPart(Node.FdParts[J]);
          PartSource := Part.LoadContents;
          if (PartSource <> '') and Part.FdType.GetValue(PartType) then
            Source[PartType].Add(PartSource);
        end;

      Node.EventIsSelected.Send(true);

      if UniformsNodes = nil then
        UniformsNodes := TVRMLNodesList.Create;
      UniformsNodes.Add(Node);

      { For sending isValid to this node later }
      SelectedNode := Node;

      { Ignore missing plugs, as iur plugs are (probably) not found there }
      WarnMissingPlugs := false;

      ShapeRequiresShaders := true;

      Break;
    end else
    if Shaders[I] is TNodeX3DShaderNode then
      TNodeX3DShaderNode(Shaders[I]).EventIsSelected.Send(false);
  end;
end;

procedure TVRMLShader.EnableAppearanceEffects(Effects: TMFNode);
begin
  AppearanceEffects := Effects;
  { Mark ShapeRequiresShaders now, don't depend on EnableEffects call doing it,
    as EnableEffects will be done from LinkProgram when it's too late
    to set ShapeRequiresShaders. }
  if AppearanceEffects.Count <> 0 then
    ShapeRequiresShaders := true;
end;

procedure TVRMLShader.EnableGroupEffects(Effects: TVRMLNodesList);
begin
  GroupEffects := Effects;
  if GroupEffects.Count <> 0 then
    ShapeRequiresShaders := true;
end;

end.
