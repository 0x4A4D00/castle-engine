{
  Copyright 2007-2008 Michalis Kamburelis.

  This file is part of test_kambi_units.

  test_kambi_units is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  test_kambi_units is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with test_kambi_units; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit TestKambiScript;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry;

type
  TTestKambiScript = class(TTestCase)
  published
    procedure Test1;
    procedure TestCodeCreatedExprs;
    procedure TestInheritsFrom;
    procedure TestFloatPrograms;
    procedure TestVariousTypesPrograms;
    procedure TestArrays;
  end;

implementation

uses VectorMath, KambiScript, KambiScriptLexer, KambiScriptParser,
  KambiStringUtils, KambiScriptCoreFunctions, KambiClassUtils,
  KambiScriptArrays;

procedure TTestKambiScript.Test1;

  procedure WritelnLexer(const s: string);
  var
    Lexer: TKamScriptLexer;
  begin
    Lexer := TKamScriptLexer.Create(s);
    repeat
      Writeln(Lexer.TokenDescription);
      Lexer.NextToken;
    until Lexer.token = tokEnd;
    Lexer.Free;
  end;

begin
{ Interactive test:
  WritelnLexer('-10 * Pi');
}
  Assert(FloatsEqual(ParseConstantFloatExpression('-10 * Pi'), -10 * Pi));
end;

procedure TTestKambiScript.TestCodeCreatedExprs;
var
  Expr: TKamScriptExpression;
  MyVariable: TKamScriptFloat;
begin
  Expr := TKamScriptAdd.Create([
      TKamScriptSin.Create([TKamScriptFloat.Create(false, 3)]),
      TKamScriptFloat.Create(false, 10),
      TKamScriptFloat.Create(false, 1)
    ]);
  try
    Assert((Expr.Execute as TKamScriptFloat).Value = sin(3) + 10 + 1);
  finally FreeAndNil(Expr) end;

  MyVariable := TKamScriptFloat.Create(false, 3);
  Expr := TKamScriptAdd.Create([
      TKamScriptSin.Create([MyVariable]),
      TKamScriptFloat.Create(false, 10),
      TKamScriptFloat.Create(false, 1)
    ]);
  try
    Assert((Expr.Execute as TKamScriptFloat).Value = sin(3) + 10 + 1);

    MyVariable.Value := 4;
    Assert((Expr.Execute as TKamScriptFloat).Value = sin(4) + 10 + 1);

    MyVariable.Value := 5;
    Assert((Expr.Execute as TKamScriptFloat).Value = sin(5) + 10 + 1);
  finally FreeAndNil(Expr) end;
end;

procedure TTestKambiScript.TestInheritsFrom;
begin
  Assert(TKamScriptFloat.InheritsFrom(TKamScriptFloat));
  Assert(TKamScriptValue.InheritsFrom(TKamScriptValue));
  Assert(TKamScriptFloat.InheritsFrom(TKamScriptValue));
  Assert(not TKamScriptValue.InheritsFrom(TKamScriptFloat));
end;

procedure TTestKambiScript.TestFloatPrograms;
var
  Vars: array [0..3] of TKamScriptFloat;
  VarsAsValue: array [Low(Vars)..High(Vars)] of TKamScriptValue absolute Vars;
  Prog: TKamScriptProgram;
  I: Integer;
begin
  for I := 0 to High(Vars) do
  begin
    Vars[I] := TKamScriptFloat.Create(true);
    Vars[I].Value := I;
    Vars[I].Name := 'x' + IntToStr(I);
  end;

  try
    Prog := ParseProgram(FileToString('test_script.kscript'), VarsAsValue);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);

    Assert(Vars[0].Value = 0);
    Assert(Vars[1].Value = 3);
    Assert(Vars[2].Value = 100 + 100 + 2 * 3);
    Assert(Vars[3].Value = 666);
  finally
    for I := 0 to High(Vars) do FreeAndNil(Vars[I]);
  end;
end;

procedure TTestKambiScript.TestVariousTypesPrograms;
var
  Prog: TKamScriptProgram;

  procedure ExecuteExpectError;
  begin
    try
      Prog.ExecuteFunction('main', []);
      Assert(false, 'should not get here');
    except
      on EKamScriptError do ;
    end;
  end;

var
  Vars: TKamScriptValuesList;
begin
  Vars := TKamScriptValuesList.Create;
  try
    Vars.Add(TKamScriptInteger.Create(true, 23));
    Vars.Add(TKamScriptFloat.Create(true, 3.14));
    Vars.Add(TKamScriptBoolean.Create(true, false));
    Vars.Add(TKamScriptString.Create(true, 'foo'));

    Vars[0].Name := 'my_int';
    Vars[1].Name := 'my_float';
    Vars[2].Name := 'my_bool';
    Vars[3].Name := 'my_string';

    Prog := ParseProgram('function main() 666', Vars);
    { return any dummy value }
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);

    Assert((Vars[0] as TKamScriptInteger).Value = 23);
    Assert((Vars[1] as TKamScriptFloat).Value = 3.14);
    Assert((Vars[2] as TKamScriptBoolean).Value = false);
    Assert((Vars[3] as TKamScriptString).Value = 'foo');

    Prog := ParseProgram(FileToString('test_script2.kscript'), Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);

    Assert((Vars[0] as TKamScriptInteger).Value = 23 + 12);
    Assert((Vars[1] as TKamScriptFloat).Value = Sqrt(3.14 + 2.0));
    Assert((Vars[2] as TKamScriptBoolean).Value = true);
    Assert((Vars[3] as TKamScriptString).Value = 'barfooxyz');

    { should raise EKamScriptError }

    Prog := ParseProgram('function main() my_int := 123.0', Vars);
    ExecuteExpectError;
    FreeAndNil(Prog);

    Prog := ParseProgram('function main() my_int := string(123.0)', Vars);
    ExecuteExpectError;
    FreeAndNil(Prog);

    { test int() }

    Prog := ParseProgram('function main() my_int := int(3.14)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[0] as TKamScriptInteger).Value = 3);

    Prog := ParseProgram('function main() my_int := int(-3.14)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[0] as TKamScriptInteger).Value = -3);

    Prog := ParseProgram('function main() my_int := int(666)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[0] as TKamScriptInteger).Value = 666);

    Prog := ParseProgram('function main() my_int := int(''44'')', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);

    Assert((Vars[0] as TKamScriptInteger).Value = 44);
    Prog := ParseProgram('function main() my_int := int(''blah'')', Vars);
    ExecuteExpectError;
    FreeAndNil(Prog);

    Prog := ParseProgram('function main() my_int := int(false)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[0] as TKamScriptInteger).Value = 0);

    Prog := ParseProgram('function main() my_int := int(true)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[0] as TKamScriptInteger).Value = 1);

    Prog := ParseProgram('function main() my_int := int(5 < 6)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[0] as TKamScriptInteger).Value = 1);

    { test float() }

    Prog := ParseProgram('function main() my_float := float(3.14)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[1] as TKamScriptFloat).Value = 3.14);

    Prog := ParseProgram('function main() my_float := float(-3.14)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[1] as TKamScriptFloat).Value = -3.14);

    Prog := ParseProgram('function main() my_float := float(666)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[1] as TKamScriptFloat).Value = 666);

    Prog := ParseProgram('function main() my_float := 123', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[1] as TKamScriptFloat).Value = 123);

    Prog := ParseProgram('function main() my_float := float(''44.456'')', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[1] as TKamScriptFloat).Value = 44.456);

    Prog := ParseProgram('function main() my_float := float(false)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[1] as TKamScriptFloat).Value = 0);

    Prog := ParseProgram('function main() my_float := float(true)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[1] as TKamScriptFloat).Value = 1);

    Prog := ParseProgram('function main() my_float := float(0 <> 0)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[1] as TKamScriptFloat).Value = 0);

    { test bool() }

    Prog := ParseProgram('function main() my_bool := bool(3.14)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[2] as TKamScriptBoolean).Value = true);

    Prog := ParseProgram('function main() my_bool := bool(0.0)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[2] as TKamScriptBoolean).Value = false);

    Prog := ParseProgram('function main() my_bool := bool(0)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[2] as TKamScriptBoolean).Value = false);

    Prog := ParseProgram('function main() my_bool := bool(''44.456'')', Vars);
    ExecuteExpectError;
    FreeAndNil(Prog);

    Prog := ParseProgram('function main() my_bool := bool(''faLSE'')', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[2] as TKamScriptBoolean).Value = false);

    Prog := ParseProgram('function main() my_bool := bool(''true'')', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[2] as TKamScriptBoolean).Value = true);

    Prog := ParseProgram('function main() my_bool := bool(false)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[2] as TKamScriptBoolean).Value = false);

    Prog := ParseProgram('function main() my_bool := bool(true)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[2] as TKamScriptBoolean).Value = true);

    Prog := ParseProgram('function main() my_bool := bool(0 <> 0)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[2] as TKamScriptBoolean).Value = false);

    { test string() }

    Prog := ParseProgram('function main() my_string := string(3.14)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[3] as TKamScriptString).Value = '3.14');

    Prog := ParseProgram('function main() my_string := string(0.0)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[3] as TKamScriptString).Value = '0');

    Prog := ParseProgram('function main() my_string := string(0)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[3] as TKamScriptString).Value = '0');

    Prog := ParseProgram('function main() my_string := string(''44.456hoho'')', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[3] as TKamScriptString).Value = '44.456hoho');

    Prog := ParseProgram('function main() my_string := string(true)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[3] as TKamScriptString).Value = 'true');

    Prog := ParseProgram('function main() my_string := string(false)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[3] as TKamScriptString).Value = 'false');

    Prog := ParseProgram('function main() my_string := string(0 <> 0)', Vars);
    Prog.ExecuteFunction('main', []);
    FreeAndNil(Prog);
    Assert((Vars[3] as TKamScriptString).Value = 'false');

    { test if() }

    Prog := ParseProgram(FileToString('test_script3.kscript'), Vars);
    Prog.ExecuteFunction('main', []);
    Assert((Vars[0] as TKamScriptInteger).Value = 12);
    Assert((Vars[1] as TKamScriptFloat).Value = 0);
    Assert((Vars[2] as TKamScriptBoolean).Value = true);

    Prog.ExecuteFunction('main_alt', []);
    Assert((Vars[0] as TKamScriptInteger).Value = 44);
    Assert((Vars[1] as TKamScriptFloat).Value = 13);
    Assert((Vars[2] as TKamScriptBoolean).Value = false);

    { test while() }

    Prog.ExecuteFunction('main_alt_while', []);
    Assert((Vars[0] as TKamScriptInteger).Value = 13);
    Assert((Vars[3] as TKamScriptString).Value = 'foo 1 2 3 4 5 6 7 8 9 10 11 12');

    { test for() }

    Prog.ExecuteFunction('main_alt_for', []);
    Assert((Vars[3] as TKamScriptString).Value = 'xxxxxxxxxxxfooxxxxxxxxxxx');

    FreeAndNil(Prog);

    { test not Writeable }
    Vars[0].Writeable := false;
    try
      Prog := ParseProgram('function main() my_int := 123', Vars);
      Assert(false, 'should not get here');
    except
      on EKamScriptError do ;
    end;
    FreeAndNil(Prog);

    { test "if" with missing else is catched correctly }
    Prog := ParseProgram('function main() if(true, 123)', []);
    ExecuteExpectError;
    FreeAndNil(Prog);
  finally
    FreeWithContentsAndNil(Vars);
  end;
end;

procedure TTestKambiScript.TestArrays;
var
  Prog: TKamScriptProgram;

  procedure ExecuteExpectError(const FuncName: string);
  begin
    try
      Prog.ExecuteFunction(FuncName, []);
      Assert(false, 'should not get here');
    except
      on EKamScriptError do ;
    end;
  end;

var
  Vars: TKamScriptValuesList;
begin
  Vars := TKamScriptValuesList.Create;
  try
    Vars.Add(TKamScriptInteger.Create(true, 23));
    Vars.Add(TKamScriptFloat.Create(true, 3.14));
    Vars.Add(TKamScriptBoolean.Create(true, false));
    Vars.Add(TKamScriptString.Create(true, 'foo'));
    Vars.Add(TKamScriptLongIntArray.Create(true));

    Vars[0].Name := 'my_int';
    Vars[1].Name := 'my_float';
    Vars[2].Name := 'my_bool';
    Vars[3].Name := 'my_string';
    Vars[4].Name := 'a_int';

    Prog := ParseProgram(FileToString('test_script_array.kscript'), Vars);

    Prog.ExecuteFunction('main', []);
    Assert(TKamScriptInteger(Vars[0]).Value = 1 + 4 + 9 + 1 + 1 + 1);

    Prog.ExecuteFunction('main_array_d_test', []);
    Assert(TKamScriptFloat(Vars[1]).Value = 3.0);

    ExecuteExpectError('main_test_invalid_index_get');
    ExecuteExpectError('main_test_invalid_index_get_2');
    ExecuteExpectError('main_test_invalid_index_set');

    FreeAndNil(Prog);
  finally
    FreeWithContentsAndNil(Vars);
  end;
end;

initialization
  RegisterTest(TTestKambiScript);
end.
