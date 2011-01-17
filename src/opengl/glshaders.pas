{
  Copyright 2007-2010 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ OpenGL shaders (GLSL through the TGLSLProgram,
  ARB assembly through TARBProgram descendants).

  Some common notes for all classes defined here:

  @unorderedList(
    @item(
      Creating/destroying the class instance immediately creates/destroys
      appropriate program. So be sure to create/destroy these classes only
      when you have OpenGL context available (for example, create in TGLWindow.OnInit
      and destroy in TGLWindow.OnClose).)

    @item(
      Upon creation, these classes check current OpenGL context abilities.
      Currently three support levels are possible for all programs:
      no support at all (old OpenGL), support through ARB extensions,
      or support built-in (newer OpenGL versions, >= 2.0).

      All three cases are automatically handled inside, so usually you
      do not have to care about these details. Note that "none" support
      (on older OpenGL version with no appropriate ARB extensions)
      means that shaders are not really initialized at all.))
}
unit GLShaders;

interface

uses SysUtils, Classes, GL, GLU, GLExt, KambiGLUtils, KambiUtils, VectorMath;

type
  TGLSupport = (gsNone, gsARBExtension, gsStandard);

  { Abstract class for both ARB vertex and fragment programs. }
  TARBProgram = class
  private
    Target: TGLenum;
    FSupport: TGLSupport;
    ProgId: TGLuint;
  public
    destructor Destroy; override;

    { Bind and load program contents. }
    procedure Load(const S: string);

    { Bind and enable this program. }
    procedure Enable;

    { Bind and disable this program. }
    procedure Disable;

    property Support: TGLSupport read FSupport;

    { Returns multiline debug info about current program.
      Things like how it's supported (not at all ? ARB extension ?
      standard ?), how much of GL limit is used (number of instructions,
      temporaries etc.), whether program fits within native limits etc. }
    function DebugInfo: string; virtual;
  end;

  { Easily handle ARB vertex program. }
  TARBVertexProgram = class(TARBProgram)
  public
    constructor Create;
    function DebugInfo: string; override;

    { @abstract(What support do we get from current OpenGL context ?)
      This is much like @link(Support), but it's a class function. }
    class function ClassSupport: TGLSupport;
  end;

  { Easily handle ARB fragment program. }
  TARBFragmentProgram = class(TARBProgram)
  public
    constructor Create;
    function DebugInfo: string; override;

    { @abstract(What support do we get from current OpenGL context ?)
      This is much like @link(Support), but it's a class function. }
    class function ClassSupport: TGLSupport;
  end;

  { Common class for exceptions related to GLSL programs. }
  EGLSLError = class(Exception);

  EGLSLShaderCompileError = class(EGLSLError);
  EGLSLProgramLinkError = class(EGLSLError);
  EGLSLRunningInSoftware = class(EGLSLError);
  EGLSLUniformNotFound = class(EGLSLError);
  EGLSLAttributeNotFound = class(EGLSLError);

  TDynGLuintArray = TDynCardinalArray;

  { Attribute of GLSL program. May be created only by
    TGLSLProgram.CreateAttribute, see there for comments. }
  TGLSLAttribute = class
  private
    FName: string;
    FSupport: TGLSupport;
    Location: TGLint;
  public
    property Name: string read FName;
    property Support: TGLSupport read FSupport;

    procedure SetValue(const Value: TVector4Integer);
    procedure SetValue(const Value: TVector4Byte);
    procedure SetValue(const Value: TGLfloat);
    procedure SetValue(const Value: TVector2Single);
    procedure SetValue(const Value: TVector3Single);
    procedure SetValue(const Value: TVector4Single);
    procedure SetValue(const Value: TGLdouble);
    procedure SetValue(const Value: TVector2Double);
    procedure SetValue(const Value: TVector3Double);
    procedure SetValue(const Value: TVector4Double);
    procedure SetValue(const Value: TMatrix3Single);
    procedure SetValue(const Value: TMatrix4Single);
  end;

  { What to do when GLSL uniform variable is set (TGLSLProgram.SetUniform)
    but doesn't exist in the shader. }
  TUniformNotFoundAction = (
    { Report that uniform variable not found to DataWarning. }
    uaWarning,
    { Report that uniform variable not found by raising EGLSLUniformNotFound. }
    uaException,
    { Ignore the fact that uniform variable doesn't exist in the GLSL shader.
      Do not warn anywhere. }
    uaIgnore);

  { What to do when GLSL uniform variable is set (by TGLSLProgram.SetUniform)
    to the type that doesn't match type declared in GLSL shader. }
  TUniformTypeMismatchAction = (
    { Do not catch uniform type mismatch, leaving it to OpenGL.
      This will cause OpenGL error "invalid operation" (possibly resulting
      in an exception in some later code that checks OpenGL errors). }
    utGLError,
    { Report type mismatch to DataWarning, and allow shader to execute as usual.
      This causes a little slowdown when setting uniform value
      (we have to actually check OpenGL error state to detect it
      and remove the error), but it's the safest. }
    utWarning);

  { Easily handle program in GLSL (OpenGL Shading Language). }
  TGLSLProgram = class
  private
    FSupport: TGLSupport;

    { Actually, this should be TGLhandleARB for gsARBExtension version.
      But TGLhandleARB = TGLuint in practice, so this is not a problem. }
    ProgramId: TGLuint;
    ShaderIds: TDynGLuintArray;

    FUniformNotFoundAction: TUniformNotFoundAction;
    FUniformTypeMismatchAction: TUniformTypeMismatchAction;
    procedure UniformNotFound(const Name: string);
    procedure SetUniformEnd(const UniformName: string);

    procedure AttachShader(AType: TGLenum; const S: string);

    { Wrapper over glGetAttribLocationARB (use only if gsARBExtension) }
    function GetAttribLocationARB(const Name: string): TGLint;

    { Wrapper over glGetAttribLocation (use only if gsStandard) }
    function GetAttribLocation(const Name: string): TGLint;
  public
    constructor Create;
    destructor Destroy; override;

    property Support: TGLSupport read FSupport;

    { Create shader from given string, compile it and attach to current program.

      You can attach more than one vertex or fragment shader, just
      make sure that only one main() function is among vertex shaders and
      only one among fragment shaders (otherwise Link error will be raised).

      If you want to explicitly get rid of old shaders, use DetachAllShaders.

      @raises(EGLSLShaderCompileError If the shader source code cannot be compiled,
        exception message contains precise description from OpenGL where
        the error is.)

      @groupBegin }
    procedure AttachVertexShader(const S: string);
    procedure AttachFragmentShader(const S: string);
    { @groupEnd }

    procedure DetachAllShaders;

    { Link the program, this should be done after attaching all shaders
      and before actually using the program.

      @raises(EGLSLProgramLinkError If the program cannot be linked,
        exception message contains precise description from OpenGL where
        the error is.)

      @raises(EGLSLRunningInSoftware If the program will be linked
        successfully, but RequireRunningInHardware = @true and the program
        will be detected to be running in software.) }
    procedure Link(RequireRunningInHardware: boolean);

    { Enable (use) this program. }
    procedure Enable;

    { Disable this program (use the fixed function pipeline). }
    procedure Disable;

    { Override this to set uniform values, in particular to
      bind the textures used by this shader, right after each @link(Enable)
      call.

      This is automatically called after every @link(Enable) by VRML renderer
      (when it renders shapes) or scene manager (when it renders screen effects).
      If you use this TGLSLProgram directly (if you call @link(Enable)
      yourself), then it's your responsibility to call this method
      explicitly, if you want shaders using it to work.

      You can set any uniform values, and generally do
      anything you want to be done each time this shader is enabled.
      In particular, you can bind textures and set corresponding uniform
      variables of them. Increase BoundTextureUnits appropriately.

      Returns @false is some texture couldn't be bound. }
    function SetupUniforms(var BoundTextureUnits: Cardinal): boolean; virtual;

    { Returns multiline debug info about current program.
      Things like how it's supported (not at all ? ARB extension ?
      standard ?), names of active uniform and attribute variables etc.

      fglrx (Radeon closed-source OpenGL drivers) are buggy (that's not
      news, I know...) and they report GL_INVALID_ENUM on some queries
      here. We detect this, and still produce nice debug message, without
      raising any exception (after all, we have to workaround fglrx bugs,
      and try to run our program anyway...). What's important for caller
      is that we have to check first whether there are any OpenGL errors
      pending, and raise exceptions on them.

      @raises EOpenGLError If any OpenGL error will be detected. }
    function DebugInfo: string;

    { This is program info log, given to you from OpenGL after the program
      is linked. }
    function ProgramInfoLog: string;

    { After the program is linked, you can check this.

      Note that this is necessarily implemented in quite hacky way (by
      looking at ProgramInfoLog), there is no way currently (AFAIK ?)
      to get this information cleanly from OpenGL.
      In case of doubts, we try to "trust" OpenGL to execute shader in hardware.
      Return @false only when we see clear indication in ProgramInfoLog that
      it'll run in software. }
    function RunningInHardware: boolean;

    { @abstract(What support do we get from current OpenGL context ?)
      This is much like @link(Support), but it's a class function. }
    class function ClassSupport: TGLSupport;

    { What to do when GLSL uniform variable is set (SetUniform)
      but doesn't exist in the shader.
      Note that OpenGL aggresively removes
      unused code and variables from the shader when compiling/linking,
      so this also happens for "declared but detected to not used" variables.

      @seealso TUniformNotFoundAction }
    property UniformNotFoundAction: TUniformNotFoundAction
      read FUniformNotFoundAction write FUniformNotFoundAction
      default uaException;

    { What to do when GLSL uniform variable is set (SetUniform)
      but is declared with an incompatible type in the shader source.
      @seealso TUniformTypeMismatchAction }
    property UniformTypeMismatchAction: TUniformTypeMismatchAction
      read FUniformTypeMismatchAction write FUniformTypeMismatchAction
      default utGLError;

    { Set appropriate uniform variable value.
      The used type must match the type of this variable in GLSL program.

      OpenGL forces some constraints on using this:

      @unorderedList(
        @item(This should be used only after linking, and re-linking clears
          (sets to zero) all uniform variables values.)

        @item(This can be used only when the program is currently used.
          So call @link(Enable) before doing SetUniform calls.

          This is required by OpenGL glUniform*
          commands. glGetUniformLocation take ProgramId as parameter, so they
          can operate on any program. But glUniform* operate only on
          active program.)

        @item(Only @italic(active) uniforms variables may be set.
          @italic(Active) means, quoting OpenGL manpages,
          a variable that is determined during the link operation
          that it may be accessed during program execution.
          In other words, when linking GLSL program, unused variables
          may be eliminated, and you cannot set them by SetUniform.

          Call DebugInfo to see what uniform variables are considered
          active for your shader.)
      )

      @raises(EGLSLUniformNotFound If the variable is not found within
        the program and UniformNotFoundAction = uaException (default).

        Note that this is only one of the many things that can
        go wrong. And on most cases we don't raise any error,
        instead OpenGL sets it's error state and you probably want to
        call CheckGLErrors from time to time to catch them.)

      @groupBegin }
    procedure SetUniform(const Name: string; const Value: boolean);
    procedure SetUniform(const Name: string; const Value: TGLint);
    procedure SetUniform(const Name: string; const Value: TVector2Integer);
    procedure SetUniform(const Name: string; const Value: TVector3Integer);
    procedure SetUniform(const Name: string; const Value: TVector4Integer);
    procedure SetUniform(const Name: string; const Value: TGLfloat);
    procedure SetUniform(const Name: string; const Value: TVector2Single);
    procedure SetUniform(const Name: string; const Value: TVector3Single);
    procedure SetUniform(const Name: string; const Value: TVector4Single);
    procedure SetUniform(const Name: string; const Value: TMatrix2Single);
    procedure SetUniform(const Name: string; const Value: TMatrix3Single);
    procedure SetUniform(const Name: string; const Value: TMatrix4Single);

    procedure SetUniform(const Name: string; const Value: TDynBooleanArray);
    procedure SetUniform(const Name: string; const Value: TDynLongIntArray);
    procedure SetUniform(const Name: string; const Value: TDynSingleArray);
    procedure SetUniform(const Name: string; const Value: TDynVector2SingleArray);
    procedure SetUniform(const Name: string; const Value: TDynVector3SingleArray);
    procedure SetUniform(const Name: string; const Value: TDynVector4SingleArray);
    procedure SetUniform(const Name: string; const Value: TDynMatrix3SingleArray);
    procedure SetUniform(const Name: string; const Value: TDynMatrix4SingleArray);
    { @groupEnd }

    { Load and enable vertex attribute data.
      This calls glVertexAttribPointer and enables it by
      glEnableVertexAttribArray (or ARB extension equivalents),
      see OpenGL reference for details.

      The attribute name is automatically resolved to a "location".
      We add LocationOffset (useful if you want to load matrix attributes,
      when you have to load matrix columns separately, with
      LocationOffset = column index).

      @raises(EGLSLAttributeNotFound If the variable is not found within
        the program.)

      @returns(Attribute location (with LocationOffset already applied).
        You can use it with DisableVertexAttribArray.) }
    function VertexAttribPointer(const Name: string; LocationOffset: TGLint;
      Size: TGLint; AType: TGLenum; Normalized: TGLboolean; Stride: TGLsizei;
      Ptr: Pointer): TGLint;

    class procedure DisableVertexAttribArray(Location: TGLint);

    { Set attribute variable value.
      The used type must match the type of this variable in GLSL program.

      OpenGL forces some constraints on using this, see SetUniform.
      In short: use this only after linking and using the program.
      And note that attributes declared but not actually used in shader code
      may be eliminated, use DebugInfo to see which attributes are actually
      used (@italic(active) in OpenGL terminology).

      A faster (but somewhat less comfortable) way to set shader attributes is
      to use CreateAttribute.

      @raises(EGLSLAttributeNotFound If the variable is not found within
        the program.

        Note that this is only one of the many things that can
        go wrong. And on most cases we don't raise any error,
        instead OpenGL sets it's error state and you probably want to
        call CheckGLErrors from time to time to catch them.)

      @groupBegin }
    procedure SetAttribute(const Name: string; const Value: TVector4Integer);
    procedure SetAttribute(const Name: string; const Value: TVector4Byte);
    procedure SetAttribute(const Name: string; const Value: TGLfloat);
    procedure SetAttribute(const Name: string; const Value: TVector2Single);
    procedure SetAttribute(const Name: string; const Value: TVector3Single);
    procedure SetAttribute(const Name: string; const Value: TVector4Single);
    procedure SetAttribute(const Name: string; const Value: TGLdouble);
    procedure SetAttribute(const Name: string; const Value: TVector2Double);
    procedure SetAttribute(const Name: string; const Value: TVector3Double);
    procedure SetAttribute(const Name: string; const Value: TVector4Double);
    procedure SetAttribute(const Name: string; const Value: TMatrix3Single);
    procedure SetAttribute(const Name: string; const Value: TMatrix4Single);
    { @groupEnd }

    { Create an attribute instance, this way you can assign multiple times
      to this attribute.

      Calling SetAttribute(Name, ...) with the same Name many times is not
      efficient, as the mapping between string (Name) and some memory location
      (done by glGetAttribLocation) must be done at each SetAttribute call.
      So it's more efficient to CreateAttribute and then call SetValue on
      the created instance many times. When doing CreateAttribute,
      glGetAttribLocation is called once, and then each SetValue does
      only simple glVertexAttrib.

      Note that this TGLSLAttribute instance is usable only as long as the
      program is not relinked. So call this only when shader program is linked,
      and free TGLSLAttribute when relinking (or just destroying TGLSLProgram).

      And call it's SetValue only when TGLSLProgram is actually in use.

      @raises(EGLSLAttributeNotFound If the variable Name not found within
        the program.) }
    function CreateAttribute(const Name: string): TGLSLAttribute;
  end;

const
  GLSupportNames: array [TGLSupport] of string =
  ( 'None', 'ARB Extension', 'Standard' );

implementation

uses KambiStringUtils, DataErrors, KambiLog;

{ Comfortable shortcut for glGetProgramivARB that always returns 1 value. }
function glGetProgramiARB(target: TGLenum; pname: TGLenum): TGLint;
begin
  glGetProgramivARB(target, pname, @Result);
end;

{ Wrapper around glGetShaderInfoLog.
  Based on Dean Ellis BasicShader.dpr, but somewhat fixed ? <> 0 not > 1. }
function GetShaderInfoLog(ShaderId: TGLuint): String;
var
  Len, Len2: TGLint;
begin
  glGetShaderiv(ShaderId, GL_INFO_LOG_LENGTH, @Len);

  if Len <> 0 then
  begin
    SetLength(Result, Len);
    glGetShaderInfoLog(ShaderId, Len, @Len2, PChar(Result));
    StringReplaceAllTo1st(Result, #0, NL);
  end else
    Result := '';
end;

{ Wrapper around glGetProgramInfoLog. }
function GetProgramInfoLog(ProgramId: TGLuint): String;
var
  Len, Len2: TGLint;
begin
  glGetProgramiv(ProgramId, GL_INFO_LOG_LENGTH, @Len);

  if Len <> 0 then
  begin
    SetLength(Result, Len);
    glGetProgramInfoLog(ProgramId, Len, @Len2, PChar(Result));
    StringReplaceAllTo1st(Result, #0, NL);
  end else
    Result := '';
end;

{ Wrapper around glGetInfoLogARB (this is for both shaders and programs). }
function GetInfoLogARB(ObjectId: TGLuint): String;
var
  Len, Len2: TGLint;
begin
  glGetObjectParameterivARB(ObjectId, GL_OBJECT_INFO_LOG_LENGTH_ARB, @Len);

  if Len <> 0 then
  begin
    SetLength(Result, Len);
    glGetInfoLogARB(ObjectId, Len, @Len2, PChar(Result));
    StringReplaceAllTo1st(Result, #0, NL);
  end else
    Result := '';
end;

{ TARBProgram ---------------------------------------------------------------- }

destructor TARBProgram.Destroy;
begin
  glDeleteProgramsARB(1, @ProgId);
  inherited;
end;

procedure TARBProgram.Load(const S: string);
begin
  case Support of
    gsARBExtension:
      begin
        glBindProgramARB(Target, ProgId);
        glProgramStringARB(Target,
          GL_PROGRAM_FORMAT_ASCII_ARB, Length(S), PCharOrNil(S));
      end;
    gsStandard: { TODO };
  end;
end;

function TARBProgram.DebugInfo: string;
begin
  Result := 'support: ' + GLSupportNames[Support];

  case Support of
    gsARBExtension:
      begin
        Result += NL + Format(
          'Number of instructions: %d / %d' +NL+
          'Number of temporaries: %d / %d' +NL+
          'Number of program parameter bindings: %d / %d',
          [ glGetProgramiARB(Target, GL_PROGRAM_INSTRUCTIONS_ARB),
            glGetProgramiARB(Target, GL_MAX_PROGRAM_INSTRUCTIONS_ARB),
            glGetProgramiARB(Target, GL_PROGRAM_TEMPORARIES_ARB),
            glGetProgramiARB(Target, GL_MAX_PROGRAM_TEMPORARIES_ARB),
            glGetProgramiARB(Target, GL_PROGRAM_PARAMETERS_ARB),
            glGetProgramiARB(Target, GL_MAX_PROGRAM_PARAMETERS_ARB) ]);

        if glGetProgramiARB(Target, GL_PROGRAM_UNDER_NATIVE_LIMITS_ARB) <> 0 then
          Result += NL + 'Program fits within native limits, OK.' else
          Result += NL + 'Program doesn''t fit within native limits, performance/quality will suffer!';
      end;
    gsStandard: { TODO };
  end;
end;

procedure TARBProgram.Enable;
begin
  case Support of
    gsARBExtension:
      begin
        glBindProgramARB(Target, ProgId);
        glEnable(Target);
      end;
    gsStandard: { TODO };
  end;
end;

procedure TARBProgram.Disable;
begin
  case Support of
    gsARBExtension:
      begin
        glBindProgramARB(Target, ProgId);
        glDisable(Target);
      end;
    gsStandard: { TODO };
  end;
end;

{ TARBVertexProgram ---------------------------------------------------------- }

constructor TARBVertexProgram.Create;
begin
  inherited;

  Target := GL_VERTEX_PROGRAM_ARB;

  FSupport := ClassSupport;

  case Support of
    gsARBExtension: glGenProgramsARB(1, @ProgId);
    gsStandard: { TODO };
  end;
end;

function TARBVertexProgram.DebugInfo: string;
begin
  Result := 'Vertex program ' + inherited;
end;

class function TARBVertexProgram.ClassSupport: TGLSupport;
begin
  { TODO: gsStandard not implemented now }

  { if GL_version_2_0 then
    Result := gsStandard else }
  if Load_GL_ARB_vertex_program then
    Result := gsARBExtension else
    Result := gsNone;
end;

{ TARBFragmentProgram ---------------------------------------------------------- }

constructor TARBFragmentProgram.Create;
begin
  inherited;

  Target := GL_FRAGMENT_PROGRAM_ARB;

  FSupport := ClassSupport;

  case Support of
    gsARBExtension: glGenProgramsARB(1, @ProgId);
    gsStandard: { TODO };
  end;
end;

function TARBFragmentProgram.DebugInfo: string;
begin
  Result := 'Fragment program ' + inherited;
end;

class function TARBFragmentProgram.ClassSupport: TGLSupport;
begin
  { TODO: gsStandard not implemented now }

  { if GL_version_2_0 then
    Result := gsStandard else }
  if Load_GL_ARB_fragment_program then
    Result := gsARBExtension else
    Result := gsNone;
end;

{ TGLSLAttribute ------------------------------------------------------------- }

procedure TGLSLAttribute.SetValue(const Value: TVector4Integer);
begin
  case Support of
    gsARBExtension: glVertexAttrib4ivARB(Location, @Value);
    gsStandard    : glVertexAttrib4iv   (Location, @Value);
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TVector4Byte);
begin
  case Support of
    gsARBExtension: glVertexAttrib4ubvARB(Location, @Value);
    gsStandard    : glVertexAttrib4ubv   (Location, @Value);
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TGLfloat);
begin
  case Support of
    gsARBExtension: glVertexAttrib1fARB(Location, Value);
    gsStandard    : glVertexAttrib1f   (Location, Value);
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TVector2Single);
begin
  case Support of
    gsARBExtension: glVertexAttrib2fvARB(Location, @Value);
    gsStandard    : glVertexAttrib2fv   (Location, @Value);
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TVector3Single);
begin
  case Support of
    gsARBExtension: glVertexAttrib3fvARB(Location, @Value);
    gsStandard    : glVertexAttrib3fv   (Location, @Value);
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TVector4Single);
begin
  case Support of
    gsARBExtension: glVertexAttrib4fvARB(Location, @Value);
    gsStandard    : glVertexAttrib4fv   (Location, @Value);
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TGLdouble);
begin
  case Support of
    gsARBExtension: glVertexAttrib1dARB(Location, Value);
    gsStandard    : glVertexAttrib1d   (Location, Value);
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TVector2Double);
begin
  case Support of
    gsARBExtension: glVertexAttrib2dvARB(Location, @Value);
    gsStandard    : glVertexAttrib2dv   (Location, @Value);
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TVector3Double);
begin
  case Support of
    gsARBExtension: glVertexAttrib3dvARB(Location, @Value);
    gsStandard    : glVertexAttrib3dv   (Location, @Value);
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TVector4Double);
begin
  case Support of
    gsARBExtension: glVertexAttrib4dvARB(Location, @Value);
    gsStandard    : glVertexAttrib4dv   (Location, @Value);
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TMatrix3Single);
begin
  case Support of
    gsARBExtension:
      begin
        glVertexAttrib3fvARB(Location    , @Value[0]);
        glVertexAttrib3fvARB(Location + 1, @Value[1]);
        glVertexAttrib3fvARB(Location + 2, @Value[2]);
      end;
    gsStandard    :
      begin
        glVertexAttrib3fv   (Location    , @Value[0]);
        glVertexAttrib3fv   (Location + 1, @Value[1]);
        glVertexAttrib3fv   (Location + 2, @Value[2]);
      end;
  end;
end;

procedure TGLSLAttribute.SetValue(const Value: TMatrix4Single);
begin
  case Support of
    gsARBExtension:
      begin
        glVertexAttrib4fvARB(Location    , @Value[0]);
        glVertexAttrib4fvARB(Location + 1, @Value[1]);
        glVertexAttrib4fvARB(Location + 2, @Value[2]);
        glVertexAttrib4fvARB(Location + 3, @Value[3]);
      end;
    gsStandard    :
      begin
        glVertexAttrib4fv   (Location    , @Value[0]);
        glVertexAttrib4fv   (Location + 1, @Value[1]);
        glVertexAttrib4fv   (Location + 2, @Value[2]);
        glVertexAttrib4fv   (Location + 3, @Value[3]);
      end;
  end;
end;

{ TGLSLProgram --------------------------------------------------------------- }

constructor TGLSLProgram.Create;
begin
  inherited;

  FSupport := ClassSupport;

  case Support of
    gsARBExtension: ProgramId := glCreateProgramObjectARB();
    gsStandard    : ProgramId := glCreateProgram         ();
  end;

  { ProgramId = 0 means that an error occurred. Citing GL documentation:

    gsARBExtension: ARB_shader_objects spec says about
      CreateProgramObjectARB(void): "If the program object
      is created successfully, a handle that can be used to reference it is
      returned .... If the creation failed the handle returned will be 0."

    gsStandard: glCreateProgram docs say
      "This function returns 0 if an error occurs creating the program object."

    Looking at glGetError, I don't see any error code there.
    So I guess that this is just like glGenLists: when zero is returned,
    I have to raise error that simply creating GLSL program failed.
  }

  if ProgramId = 0 then
    raise EGLSLError.Create('Creation of GLSL program failed');

  ShaderIds := TDynGLuintArray.Create;

  FUniformNotFoundAction := uaException;
  FUniformTypeMismatchAction := utGLError;
end;

destructor TGLSLProgram.Destroy;
begin
  { make sure all shaders are detached and deleted, to free all resources }

  { Destructor may be called if exception raised from constructor,
    so better check that ShaderIds was created. }
  if ShaderIds <> nil then
    DetachAllShaders;

  case Support of
    gsARBExtension: glDeleteObjectARB(ProgramId);
    gsStandard    : glDeleteProgram  (ProgramId);
  end;

  FreeAndNil(ShaderIds);

  inherited;
end;

class function TGLSLProgram.ClassSupport: TGLSupport;
begin
  if GL_version_2_0 then
    Result := gsStandard else
  if Load_GL_ARB_shader_objects and
     Load_GL_ARB_vertex_shader and
     Load_GL_ARB_fragment_shader and
     Load_GL_ARB_shading_language_100 then
    Result := gsARBExtension else
    Result := gsNone;
end;

function TGLSLProgram.ProgramInfoLog: string;
begin
  case Support of
    gsARBExtension: Result := GetInfoLogARB(ProgramId);
    gsStandard    : Result := GetProgramInfoLog(ProgramId);
    else Result := '';
  end;
end;

function TGLSLProgram.DebugInfo: string;

  function GLShaderVariableTypeName(AType: TGLenum): string;
  begin
    case AType of
      GL_FLOAT: Result := 'FLOAT';
      GL_FLOAT_VEC2: Result := 'FLOAT_VEC2';
      GL_FLOAT_VEC3: Result := 'FLOAT_VEC3';
      GL_FLOAT_VEC4: Result := 'FLOAT_VEC4';
      GL_INT: Result := 'INT';
      GL_INT_VEC2: Result := 'INT_VEC2';
      GL_INT_VEC3: Result := 'INT_VEC3';
      GL_INT_VEC4: Result := 'INT_VEC4';
      GL_BOOL: Result := 'BOOL';
      GL_BOOL_VEC2: Result := 'BOOL_VEC2';
      GL_BOOL_VEC3: Result := 'BOOL_VEC3';
      GL_BOOL_VEC4: Result := 'BOOL_VEC4';
      GL_FLOAT_MAT2: Result := 'FLOAT_MAT2';
      GL_FLOAT_MAT3: Result := 'FLOAT_MAT3';
      GL_FLOAT_MAT4: Result := 'FLOAT_MAT4';
      { These are only for GL >= 2.1, will be uncommented when GLExt
        binding will be updated to GL 2.1. }
      //GL_FLOAT_MAT2x3: Result := 'FLOAT_MAT2x3';
      //GL_FLOAT_MAT2x4: Result := 'FLOAT_MAT2x4';
      //GL_FLOAT_MAT3x2: Result := 'FLOAT_MAT3x2';
      //GL_FLOAT_MAT3x4: Result := 'FLOAT_MAT3x4';
      //GL_FLOAT_MAT4x2: Result := 'FLOAT_MAT4x2';
      //GL_FLOAT_MAT4x3: Result := 'FLOAT_MAT4x3';
      GL_SAMPLER_1D: Result := 'SAMPLER_1D';
      GL_SAMPLER_2D: Result := 'SAMPLER_2D';
      GL_SAMPLER_3D: Result := 'SAMPLER_3D';
      GL_SAMPLER_CUBE: Result := 'SAMPLER_CUBE';
      GL_SAMPLER_1D_SHADOW: Result := 'SAMPLER_1D_SHADOW';
      GL_SAMPLER_2D_SHADOW: Result := 'SAMPLER_2D_SHADOW';
      else Result := Format('Unrecognized uniform type "%d"', [AType]);
    end;
  end;

  const
    SCannotGetCount = '  Cannot get variables count (probably buggy fglrx ('+
      'Radeon closed-source drivers) or Mesa)';

  { Fills the UniformNames with the names (and properties)
    of all active uniform variables available by the program.
    The program must be previously linked to use this.

    Quoting OpenGL manpage about what is @italic(active) uniform variable:
    A uniform variable (either built-in or user-defined) is
    considered active if it is determined during the link operation
    that it may be accessed during program execution.

    You may want to clear UniformNames before calling this, as this doesn't
    clear them automatically, it only appends new names.

    GetActiveUniforms was planned once to be public, but actually
    I think it fits better in DebugInfo }
  procedure GetActiveUniforms(UniformNames: TStringList);
  var
    I: Integer;
    UniformsCount, UniformMaxLength: TGLuint;
    ReturnedLength: TGLsizei;
    Size: TGLint;
    AType: TGLEnum;
    Name: string;
    ErrorCode: TGLenum;
  begin
    case Support of
      gsARBExtension:
        begin
          glGetProgramivARB(ProgramId, GL_OBJECT_ACTIVE_UNIFORMS_ARB, @UniformsCount);

          ErrorCode := glGetError();
          if ErrorCode = GL_INVALID_ENUM then
          begin
            UniformNames.Append(SCannotGetCount);
            Exit;
          end else
          if ErrorCode <> GL_NO_ERROR then
            raise EOpenGLError.Create(ErrorCode, 'GetActiveUniforms');

          glGetProgramivARB(ProgramId, GL_OBJECT_ACTIVE_UNIFORM_MAX_LENGTH_ARB, @UniformMaxLength);

          for I := 0 to UniformsCount - 1 do
          begin
            SetLength(Name, UniformMaxLength);
            glGetActiveUniformARB(ProgramId, I, UniformMaxLength, @ReturnedLength,
              @Size, @AType, PCharOrNil(Name));

            SetLength(Name, ReturnedLength);
            UniformNames.Append(Format('  Name: %s, type: %s, size: %d',
              [Name, GLShaderVariableTypeName(AType), Size]));
          end;
        end;

      gsStandard    :
        begin
          glGetProgramiv(ProgramId, GL_ACTIVE_UNIFORMS, @UniformsCount);

          ErrorCode := glGetError();
          if ErrorCode = GL_INVALID_ENUM then
          begin
            UniformNames.Append(SCannotGetCount);
            Exit;
          end else
          if ErrorCode <> GL_NO_ERROR then
            raise EOpenGLError.Create(ErrorCode, 'GetActiveUniforms');

          glGetProgramiv(ProgramId, GL_ACTIVE_UNIFORM_MAX_LENGTH, @UniformMaxLength);

          for I := 0 to UniformsCount - 1 do
          begin
            SetLength(Name, UniformMaxLength);
            glGetActiveUniform(ProgramId, I, UniformMaxLength, @ReturnedLength,
              @Size, @AType, PCharOrNil(Name));
            SetLength(Name, ReturnedLength);
            UniformNames.Append(Format('  Name: %s, type: %s, size: %d',
              [Name, GLShaderVariableTypeName(AType), Size]));
          end;
        end;
    end;
  end;

  procedure GetActiveAttribs(AttribNames: TStringList);
  var
    I: Integer;
    AttribsCount, AttribMaxLength: TGLuint;
    ReturnedLength: TGLsizei;
    Size: TGLint;
    AType: TGLEnum;
    Name: string;
    ErrorCode: TGLenum;
  begin
    case Support of
      gsARBExtension:
        begin
          glGetProgramivARB(ProgramId, GL_OBJECT_ACTIVE_ATTRIBUTES_ARB, @AttribsCount);

          ErrorCode := glGetError();
          if ErrorCode = GL_INVALID_ENUM then
          begin
            AttribNames.Append(SCannotGetCount);
            Exit;
          end else
          if ErrorCode <> GL_NO_ERROR then
            raise EOpenGLError.Create(ErrorCode, 'GetActiveAttribs');

          glGetProgramivARB(ProgramId, GL_OBJECT_ACTIVE_ATTRIBUTE_MAX_LENGTH_ARB, @AttribMaxLength);

          for I := 0 to AttribsCount - 1 do
          begin
            SetLength(Name, AttribMaxLength);
            glGetActiveAttribARB(ProgramId, I, AttribMaxLength, @ReturnedLength,
              @Size, @AType, PCharOrNil(Name));
            SetLength(Name, ReturnedLength);
            AttribNames.Append(Format('  Name: %s, type: %s, size: %d',
              [Name, GLShaderVariableTypeName(AType), Size]));
          end;
        end;

      gsStandard    :
        begin
          glGetProgramiv(ProgramId, GL_ACTIVE_ATTRIBUTES, @AttribsCount);

          ErrorCode := glGetError();
          if ErrorCode = GL_INVALID_ENUM then
          begin
            AttribNames.Append(SCannotGetCount);
            Exit;
          end else
          if ErrorCode <> GL_NO_ERROR then
            raise EOpenGLError.Create(ErrorCode, 'GetActiveAttribs');

          glGetProgramiv(ProgramId, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, @AttribMaxLength);

          for I := 0 to AttribsCount - 1 do
          begin
            SetLength(Name, AttribMaxLength);
            glGetActiveAttrib(ProgramId, I, AttribMaxLength, @ReturnedLength,
              @Size, @AType, PCharOrNil(Name));
            SetLength(Name, ReturnedLength);
            AttribNames.Append(Format('  Name: %s, type: %s, size: %d',
              [Name, GLShaderVariableTypeName(AType), Size]));
          end;
        end;
    end;
  end;

  function ShaderInfoLog(ShaderId: TGLuint): string;
  begin
    case Support of
      gsARBExtension: Result := GetInfoLogARB(ShaderId);
      gsStandard    : Result := GetShaderInfoLog(ShaderId);
    end;
  end;

var
  S: TStringList;
  I: Integer;
begin
  Result := 'GLSL program support: ' + GLSupportNames[Support];

  CheckGLErrors('Check at the beginning of TGLSLProgram.DebugInfo');

  S := TStringList.Create;
  try
    GetActiveUniforms(S);
    Result += NL + 'Active uniforms:' + NL + S.Text;

    S.Clear;
    GetActiveAttribs(S);
    Result += NL + 'Active attribs:' + NL + S.Text;
  finally FreeAndNil(S) end;

  for I := 0 to ShaderIds.Count - 1 do
  begin
    Result += NL + Format('Shader number %d (OpenGL id %d) log:',
      [I, ShaderIds.Items[I]]) + NL +
      ShaderInfoLog(ShaderIds.Items[I]);
  end;

  Result += NL + 'Program info log:' + NL + ProgramInfoLog;

  Result += NL + 'Program detected as running in hardware: ' +
    BoolToStr[RunningInHardware];
end;

procedure TGLSLProgram.AttachShader(AType: TGLenum; const S: string);

  function CreateShaderARB(const S: string): TGLuint;
  var
    SrcPtr: PChar;
    SrcLength: Cardinal;
    Compiled: TGLint;
  begin
    Result := glCreateShaderObjectARB(AType);
    SrcPtr := PChar(S);
    SrcLength := Length(S);
    glShaderSourceARB(Result, 1, @SrcPtr, @SrcLength);
    glCompileShaderARB(Result);
    glGetObjectParameterivARB(Result, GL_OBJECT_COMPILE_STATUS_ARB, @Compiled);
    if Compiled <> 1 then
      raise EGLSLShaderCompileError.CreateFmt('Shader not compiled:' + NL + '%s',
        [GetInfoLogARB(Result)]);
  end;

  { Based on Dean Ellis BasicShader.dpr }
  function CreateShader(const S: string): TGLuint;
  var
    SrcPtr: PChar;
    SrcLength: Cardinal;
    Compiled: TGLint;
  begin
    Result := glCreateShader(AType);
    SrcPtr := PChar(S);
    SrcLength := Length(S);
    glShaderSource(Result, 1, @SrcPtr, @SrcLength);
    glCompileShader(Result);
    glGetShaderiv(Result, GL_COMPILE_STATUS, @Compiled);
    { Although I generally avoid creating multiline exception messages,
      ShaderGetInfoLog naturally comes out multiline (it contains a
      couple of error messages) and it's best presented with line breaks.
      So a line break right before ShaderGetInfoLog contents looks good. }
    if Compiled <> GL_TRUE then
      raise EGLSLShaderCompileError.CreateFmt('Shader not compiled:' + NL + '%s',
        [GetShaderInfoLog(Result)]);
  end;

var
  ShaderId: TGLuint;
begin
  case Support of
    gsARBExtension:
      begin
        ShaderId := CreateShaderARB(S);
        glAttachObjectARB(ProgramId, ShaderId);
        ShaderIds.Add(ShaderId);
      end;
    gsStandard:
      begin
        ShaderId := CreateShader(S);
        glAttachShader(ProgramId, ShaderId);
        ShaderIds.Add(ShaderId);
      end;
  end;
end;

procedure TGLSLProgram.AttachVertexShader(const S: string);
begin
  case Support of
    gsARBExtension: AttachShader(GL_VERTEX_SHADER_ARB, S);
    gsStandard    : AttachShader(GL_VERTEX_SHADER    , S);
  end;
end;

procedure TGLSLProgram.AttachFragmentShader(const S: string);
begin
  case Support of
    gsARBExtension: AttachShader(GL_FRAGMENT_SHADER_ARB, S);
    gsStandard    : AttachShader(GL_FRAGMENT_SHADER    , S);
  end;
end;

procedure TGLSLProgram.DetachAllShaders;
var
  I: Integer;
begin
  case Support of
    gsARBExtension:
      for I := 0 to ShaderIds.Count - 1 do
      begin
        glDetachObjectARB(ProgramId, ShaderIds.Items[I]);
        glDeleteObjectARB(ShaderIds.Items[I]);
      end;
    gsStandard    :
      for I := 0 to ShaderIds.Count - 1 do
      begin
        glDetachShader   (ProgramId, ShaderIds.Items[I]);
        glDeleteShader   (ShaderIds.Items[I]);
      end;
  end;
  ShaderIds.Count := 0;
end;

procedure TGLSLProgram.Link(RequireRunningInHardware: boolean);
var
  Linked: TGLuint;
begin
  case Support of
    gsARBExtension:
      begin
        glLinkProgramARB(ProgramId);
        glGetObjectParameterivARB(ProgramId, GL_OBJECT_LINK_STATUS_ARB, @Linked);
        if Linked <> 1 then
          raise EGLSLProgramLinkError.Create('GLSL program not linked' + NL +
            GetInfoLogARB(ProgramId));
      end;
    gsStandard:
      begin
        glLinkProgram(ProgramId);
        glGetProgramiv(ProgramId, GL_LINK_STATUS, @Linked);
        if Linked <> GL_TRUE then
          raise EGLSLProgramLinkError.Create('GLSL program not linked' + NL +
            GetProgramInfoLog(ProgramId));
      end;
  end;

  if RequireRunningInHardware and (not RunningInHardware) then
    raise EGLSLRunningInSoftware.CreateFmt(
      'GLSL shader linked but rejected, as it seems it will run in software.' +
      'Program info log is "%s"', [ProgramInfoLog]);

  if Log then
    WritelnLogMultiline('GLSL', 'GLSL program successfully linked. Information:' + NL + DebugInfo);
end;

function TGLSLProgram.RunningInHardware: boolean;
begin
  { This is good at least for capturing shaders running in software on
      Radeon X300/X550/X1050 Series (crypto on ii.324), Linux fglrx. }

  Result := Pos('shader will run in software due to the', ProgramInfoLog) = 0;
end;

procedure TGLSLProgram.Enable;
begin
  case Support of
    gsARBExtension: glUseProgramObjectARB(ProgramId);
    gsStandard    : glUseProgram         (ProgramId);
  end;
end;

procedure TGLSLProgram.Disable;
begin
  case Support of
    gsARBExtension: glUseProgramObjectARB(0);
    gsStandard    : glUseProgram         (0);
  end;
end;

function TGLSLProgram.SetupUniforms(var BoundTextureUnits: Cardinal): boolean;
begin
  Result := true;
end;

procedure TGLSLProgram.UniformNotFound(const Name: string);
var
  S: string;
begin
  S := Format('Uniform variable "%s" not found (or not used) in the shader source code', [Name]);
  case UniformNotFoundAction of
    uaWarning: DataWarning(S);
    uaException: raise EGLSLUniformNotFound.Create(S);
    uaIgnore: ;
    else raise EInternalError.Create('UniformNotFoundAction? in TGLSLProgram.UniformNotFound');
  end;
end;

{ Wrapper over glGetUniformLocationARB (use only if gsARBExtension) }
{$define GetLocationCheckARB :=

  Location := glGetUniformLocationARB(ProgramId, PCharOrNil(Name));
  if Location = -1 then
  begin
    UniformNotFound(Name);
    Exit;
  end;

  if UniformTypeMismatchAction = utWarning then
    CheckGLErrors('Cleaning GL errors before setting GLSL uniform:');
}

{ Wrapper over glGetUniformLocation (use only if gsStandard) }
{$define GetLocationCheck :=
  Location := glGetUniformLocation   (ProgramId, PCharOrNil(Name));
  if Location = -1 then
  begin
    UniformNotFound(Name);
    Exit;
  end;

  if UniformTypeMismatchAction = utWarning then
    CheckGLErrors('Cleaning GL errors before setting GLSL uniform:');
}

procedure TGLSLProgram.SetUniformEnd(const UniformName: string);
var
  ErrorCode: TGLenum;
begin
  if UniformTypeMismatchAction = utWarning then
  begin
    { Invalid glUniform call, that specifies wrong uniform variable type,
      may cause OpenGL error "invalid operation". We want to catch it,
      and convert into appropriate nice warning.
      We cleaned GL error at the beginning of SetUniform
      (at the end of macro glGetUniformLocation*), so if there's an error
      now --- we know it's because of glUniform.

      Note: we could do here CheckGLErrors and catch EOpenGLError,
      but it's simpler and more efficient to just check it directly. }

    ErrorCode := glGetError();
    if ErrorCode <> GL_NO_ERROR then
      DataWarning(Format('Error when setting GLSL uniform variable "%s" (check that the type of the variable in shader source code matches): OpenGL error (%d): %s',
        [UniformName, ErrorCode,  gluErrorString(ErrorCode)]));
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: boolean);
var
  Location: TGLint;
begin
  { GLSL "bool" types are set using the "i" version. From manpage:

    "Either the i or the f variants
     may be used to provide values for uniform variables of type
     bool, bvec2, bvec3, bvec4, or arrays of these. The uniform
     variable will be set to false if the input value is 0 or 0.0f,
     and it will be set to true otherwise.
    "

    Which means that I can simply call glUniform1i, with Ord(Value). }

  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform1iARB(Location, Ord(Value)); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform1i   (Location, Ord(Value)); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TGLint);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform1iARB(Location, Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform1i   (Location, Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TVector2Integer);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform2ivARB(Location, 1, @Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform2iv   (Location, 1, @Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TVector3Integer);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform3ivARB(Location, 1, @Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform3iv   (Location, 1, @Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TVector4Integer);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform4ivARB(Location, 1, @Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform4iv   (Location, 1, @Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TGLfloat);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform1fARB(Location, Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform1f   (Location, Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TVector2Single);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform2fvARB(Location, 1, @Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform2fv   (Location, 1, @Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TVector3Single);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform3fvARB(Location, 1, @Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform3fv   (Location, 1, @Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TVector4Single);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform4fvARB(Location, 1, @Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform4fv   (Location, 1, @Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TMatrix2Single);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniformMatrix2fvARB(Location, 1, GL_FALSE, @Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniformMatrix2fv   (Location, 1, GL_FALSE, @Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TMatrix3Single);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniformMatrix3fvARB(Location, 1, GL_FALSE, @Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniformMatrix3fv   (Location, 1, GL_FALSE, @Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TMatrix4Single);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniformMatrix4fvARB(Location, 1, GL_FALSE, @Value); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniformMatrix4fv   (Location, 1, GL_FALSE, @Value); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TDynBooleanArray);
var
  Location: TGLint;
  Ints: TDynLongIntArray;
begin
  { We cannot pass Value.ItemsArray, as Pascal booleans do not have 4 bytes
    (well, actually I could change this by compiler directive or
    by using LongBool for TDynBooleanArray --- but for TDynBooleanArray
    this would enlarge it 4 times, not nice).

    Unfortunately, there's no glUniform*ub (unsigned byte) or such function.

    So convert to longints. }
  Ints := Value.ToLongInt;
  try
    case Support of
      gsARBExtension: begin GetLocationCheckARB glUniform1ivARB(Location, Value.Count, PGLint(Ints.ItemsArray)); SetUniformEnd(Name); end;
      gsStandard    : begin GetLocationCheck    glUniform1iv   (Location, Value.Count, PGLint(Ints.ItemsArray)); SetUniformEnd(Name); end;
    end;
  finally FreeAndNil(Ints) end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TDynLongIntArray);
var
  Location: TGLint;
begin
  Assert(SizeOf(LongInt) = SizeOf(TGLint));
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform1ivARB(Location, Value.Count, PGLint(Value.ItemsArray)); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform1iv   (Location, Value.Count, PGLint(Value.ItemsArray)); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TDynSingleArray);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform1fvARB(Location, Value.Count, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform1fv   (Location, Value.Count, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TDynVector2SingleArray);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform2fvARB(Location, Value.Count, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform2fv   (Location, Value.Count, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TDynVector3SingleArray);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform3fvARB(Location, Value.Count, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform3fv   (Location, Value.Count, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TDynVector4SingleArray);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniform4fvARB(Location, Value.Count, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniform4fv   (Location, Value.Count, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TDynMatrix3SingleArray);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniformMatrix3fvARB(Location, Value.Count, GL_FALSE, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniformMatrix3fv   (Location, Value.Count, GL_FALSE, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
  end;
end;

procedure TGLSLProgram.SetUniform(const Name: string; const Value: TDynMatrix4SingleArray);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension: begin GetLocationCheckARB glUniformMatrix4fvARB(Location, Value.Count, GL_FALSE, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
    gsStandard    : begin GetLocationCheck    glUniformMatrix4fv   (Location, Value.Count, GL_FALSE, PGLfloat(Value.ItemsArray)); SetUniformEnd(Name); end;
  end;
end;

function TGLSLProgram.GetAttribLocationARB(const Name: string): TGLint;
begin
  Result := glGetAttribLocationARB(ProgramId, PCharOrNil(Name));
  if Result = -1 then
    raise EGLSLAttributeNotFound.CreateFmt('Attribute variable "%s" not found', [Name]);
end;

function TGLSLProgram.GetAttribLocation(const Name: string): TGLint;
begin
  Result := glGetAttribLocation   (ProgramId, PCharOrNil(Name));
  if Result = -1 then
    raise EGLSLAttributeNotFound.CreateFmt('Attribute variable "%s" not found', [Name]);
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TVector4Integer);
begin
  case Support of
    gsARBExtension: glVertexAttrib4ivARB(GetAttribLocationARB(Name), @Value);
    gsStandard    : glVertexAttrib4iv   (GetAttribLocation   (Name), @Value);
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TVector4Byte);
begin
  case Support of
    gsARBExtension: glVertexAttrib4ubvARB(GetAttribLocationARB(Name), @Value);
    gsStandard    : glVertexAttrib4ubv   (GetAttribLocation   (Name), @Value);
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TGLfloat);
begin
  case Support of
    gsARBExtension: glVertexAttrib1fARB(GetAttribLocationARB(Name), Value);
    gsStandard    : glVertexAttrib1f   (GetAttribLocation   (Name), Value);
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TVector2Single);
begin
  case Support of
    gsARBExtension: glVertexAttrib2fvARB(GetAttribLocationARB(Name), @Value);
    gsStandard    : glVertexAttrib2fv   (GetAttribLocation   (Name), @Value);
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TVector3Single);
begin
  case Support of
    gsARBExtension: glVertexAttrib3fvARB(GetAttribLocationARB(Name), @Value);
    gsStandard    : glVertexAttrib3fv   (GetAttribLocation   (Name), @Value);
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TVector4Single);
begin
  case Support of
    gsARBExtension: glVertexAttrib4fvARB(GetAttribLocationARB(Name), @Value);
    gsStandard    : glVertexAttrib4fv   (GetAttribLocation   (Name), @Value);
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TGLdouble);
begin
  case Support of
    gsARBExtension: glVertexAttrib1dARB(GetAttribLocationARB(Name), Value);
    gsStandard    : glVertexAttrib1d   (GetAttribLocation   (Name), Value);
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TVector2Double);
begin
  case Support of
    gsARBExtension: glVertexAttrib2dvARB(GetAttribLocationARB(Name), @Value);
    gsStandard    : glVertexAttrib2dv   (GetAttribLocation   (Name), @Value);
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TVector3Double);
begin
  case Support of
    gsARBExtension: glVertexAttrib3dvARB(GetAttribLocationARB(Name), @Value);
    gsStandard    : glVertexAttrib3dv   (GetAttribLocation   (Name), @Value);
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TVector4Double);
begin
  case Support of
    gsARBExtension: glVertexAttrib4dvARB(GetAttribLocationARB(Name), @Value);
    gsStandard    : glVertexAttrib4dv   (GetAttribLocation   (Name), @Value);
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TMatrix3Single);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension:
      begin
        Location := GetAttribLocationARB(Name);
        glVertexAttrib3fvARB(Location    , @Value[0]);
        glVertexAttrib3fvARB(Location + 1, @Value[1]);
        glVertexAttrib3fvARB(Location + 2, @Value[2]);
      end;
    gsStandard    :
      begin
        Location := GetAttribLocation   (Name);
        glVertexAttrib3fv   (Location    , @Value[0]);
        glVertexAttrib3fv   (Location + 1, @Value[1]);
        glVertexAttrib3fv   (Location + 2, @Value[2]);
      end;
  end;
end;

procedure TGLSLProgram.SetAttribute(const Name: string; const Value: TMatrix4Single);
var
  Location: TGLint;
begin
  case Support of
    gsARBExtension:
      begin
        Location := GetAttribLocationARB(Name);
        glVertexAttrib4fvARB(Location    , @Value[0]);
        glVertexAttrib4fvARB(Location + 1, @Value[1]);
        glVertexAttrib4fvARB(Location + 2, @Value[2]);
        glVertexAttrib4fvARB(Location + 3, @Value[3]);
      end;
    gsStandard    :
      begin
        Location := GetAttribLocation   (Name);
        glVertexAttrib4fv   (Location    , @Value[0]);
        glVertexAttrib4fv   (Location + 1, @Value[1]);
        glVertexAttrib4fv   (Location + 2, @Value[2]);
        glVertexAttrib4fv   (Location + 3, @Value[3]);
      end;
  end;
end;

function TGLSLProgram.CreateAttribute(const Name: string): TGLSLAttribute;
begin
  Result := TGLSLAttribute.Create;
  try
    Result.FName := Name;
    Result.FSupport := Support;
    case Support of
      gsARBExtension: Result.Location := GetAttribLocationARB(Name);
      gsStandard    : Result.Location := GetAttribLocation   (Name);
    end;
  except FreeAndNil(Result); raise end;
end;

function TGLSLProgram.VertexAttribPointer(const Name: string;
  LocationOffset: TGLint;
  Size: TGLint; AType: TGLenum; Normalized: TGLboolean; Stride: TGLsizei;
  Ptr: Pointer): TGLint;
begin
  case Support of
    gsARBExtension:
      begin
        Result := GetAttribLocationARB(Name) + LocationOffset;
        glEnableVertexAttribArrayARB(Result);
        glVertexAttribPointerARB(Result, Size, AType, Normalized, Stride, Ptr);
      end;
    gsStandard    :
      begin
        Result := GetAttribLocation   (Name) + LocationOffset;
        glEnableVertexAttribArray   (Result);
        glVertexAttribPointer   (Result, Size, AType, Normalized, Stride, Ptr);
      end;
  end;
end;

class procedure TGLSLProgram.DisableVertexAttribArray(Location: TGLint);
begin
  case ClassSupport of
    gsARBExtension: glDisableVertexAttribArrayARB(Location);
    gsStandard    : glDisableVertexAttribArray   (Location);
  end;
end;

end.
