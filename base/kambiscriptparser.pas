{
  Copyright 2001-2008 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "Kambi VRML game engine"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

(*
  @abstract(Parser for KambiScript language, see
  [http://vrmlengine.sourceforge.net/kambi_script.php].)

  Can parse whole program in KambiScript language, is also prepared
  to parse only a single expression (usefull for cases when I need
  to input only a mathematical expression, like for glplotter function
  expression).
*)

unit KambiScriptParser;

interface

uses KambiScript, KambiScriptLexer, Math;

type
  { Reexported in this unit, so that the identifier EKamScriptSyntaxError
    will be visible when using this unit. }
  EKamScriptSyntaxError = KambiScriptLexer.EKamScriptSyntaxError;

{ Creates and returns instance of TKamScriptExpression,
  that represents parsed tree of expression in S.

  @param(Variables contains a list of named values you want
    to allow in this expression.

    Important: They will all have
    OwnedByParentExpression set to @false, and you will have to
    free them yourself.
    That's because given expression may use the same variable more than once
    (so freeing it twice would cause bugs), or not use it at all
    (so it will be automatically freed at all).

    So setting OwnedByParentExpression and freeing it yourself
    is the only sensible thing to do.)

  @raises(EKamScriptSyntaxError in case of error when parsing expression.) }
function ParseFloatExpression(const S: string;
  const Variables: array of TKamScriptValue): TKamScriptExpression;

{ Parse constant float expression.
  This can be used as a great replacement for StrToFloat.
  Takes a string with any constant mathematical expression,
  according to KambiScript syntax, parses it and calculates.

  @raises(EKamScriptSyntaxError in case of error when parsing expression.) }
function ParseConstantFloatExpression(const S: string): Float;

{ Parse KambiScript program.

  Variable list works like for ParseFloatExpression, see there for
  description.

  @raises(EKamScriptSyntaxError in case of error when parsing expression.)

  @groupBegin }
function ParseProgram(const S: string;
  const Variables: array of TKamScriptValue): TKamScriptProgram; overload;
function ParseProgram(const S: string;
  const Variables: TKamScriptValuesList): TKamScriptProgram; overload;
{ @groupEnd }

implementation

uses SysUtils, KambiScriptMathFunctions;

function Expression(
  const Lexer: TKamScriptLexer;
  const Variables: array of TKamScriptValue): TKamScriptExpression; forward;

function NonAssignmentExpression(
  const Lexer: TKamScriptLexer;
  const AllowFullExpressionInFactor: boolean;
  const Variables: array of TKamScriptValue): TKamScriptExpression;

  function BinaryOper(tok: TToken): TKamScriptFunctionClass;
  begin
    case tok of
      tokPlus: Result := TKamScriptAdd;
      tokMinus: Result := TKamScriptSubtract;

      tokMultiply: Result := TKamScriptMultiply;
      tokDivide: Result := TKamScriptDivide;
      tokPower: Result := TKamScriptPower;
      tokModulo: Result := TKamScriptModulo;

      tokGreater: Result := TKamScriptGreater;
      tokLesser: Result := TKamScriptLesser;
      tokGreaterEqual: Result := TKamScriptGreaterEq;
      tokLesserEqual: Result := TKamScriptLesserEq;
      tokEqual: Result := TKamScriptEqual;
      tokNotEqual: Result := TKamScriptNotEqual;

      else raise EKamScriptParserError.Create(Lexer,
        'internal error : token not a binary operator');
    end
  end;

const
  SErrWrongFactor = 'wrong factor (expected identifier, constant, "-", "(" or function name)';
  SErrOperRelacExpected = 'comparison operator (>, <, >=, <=, = or <>) expected';

  FactorOperator = [tokMultiply, tokDivide, tokPower, tokModulo];
  TermOperator = [tokPlus, tokMinus];
  ComparisonOperator = [tokGreater, tokLesser, tokGreaterEqual, tokLesserEqual, tokEqual, tokNotEqual];

  function Operand: TKamScriptValue;
  var
    I: Integer;
  begin
    Lexer.CheckTokenIs(tokIdentifier);

    Result := nil;
    for I := 0 to Length(Variables) - 1 do
      if SameText(Variables[I].Name, Lexer.TokenString) then
      begin
        Result := Variables[I];
        Break;
      end;

    if Result = nil then
      raise EKamScriptParserError.CreateFmt(Lexer, 'Undefined identifier "%s"',
        [Lexer.TokenString]);

    Lexer.NextToken;
  end;

  { Returns either Expression or NonAssignmentExpression, depending on
    AllowFullExpressionInFactor value. }
  function ExpressionInsideFactor: TKamScriptExpression;
  begin
    if AllowFullExpressionInFactor then
      Result := Expression(Lexer, Variables) else
      Result := NonAssignmentExpression(Lexer,
        AllowFullExpressionInFactor, Variables);
  end;

  function Factor: TKamScriptExpression;
  var
    FC: TKamScriptFunctionClass;
    FParams: TKamScriptExpressionsList;
  begin
    Result := nil;
    try
      case Lexer.Token of
        tokIdentifier: Result := Operand;
        tokConst: begin
            Result := TKamScriptFloat.Create(Lexer.TokenFloat);
            Lexer.NextToken;
          end;
        tokMinus: begin
            Lexer.NextToken;
            Result := TKamScriptNegate.Create([Factor()])
          end;
        tokLParen: begin
            Lexer.NextToken;
            Result := ExpressionInsideFactor;
            Lexer.CheckTokenIs(tokRParen);
            Lexer.NextToken;
          end;
        tokFuncName: begin
            FC := Lexer.TokenFunctionClass;
            Lexer.NextToken;
            FParams := TKamScriptExpressionsList.Create;
            try
              if Lexer.Token = tokLParen then
              repeat
                Lexer.NextToken; { pomin ostatni "," lub "(" }
                FParams.Add(ExpressionInsideFactor);
              until Lexer.Token <> tokComma;
              Lexer.CheckTokenIs(tokRParen);
              Lexer.NextToken;
              Result := FC.Create(FParams);
            finally FParams.Free end;
          end;
        else raise EKamScriptParserError.Create(Lexer, SErrWrongFactor +
          ', but got "' + Lexer.TokenDescription + '"');
      end;
    except Result.FreeByParentExpression; raise end;
  end;

  function Term: TKamScriptExpression;
  var
    FC: TKamScriptFunctionClass;
  begin
    Result := nil;
    try
      Result := Factor;
      while Lexer.Token in FactorOperator do
      begin
        FC := BinaryOper(Lexer.Token);
        Lexer.NextToken;
        Result := FC.Create([Result, Factor]);
      end;
    except Result.FreeByParentExpression; raise end;
  end;

  function ComparisonArgument: TKamScriptExpression;
  var
    FC: TKamScriptFunctionClass;
  begin
    Result := nil;
    try
      Result := Term;
      while Lexer.Token in TermOperator do
      begin
        FC := BinaryOper(Lexer.Token);
        Lexer.NextToken;
        Result := FC.Create([Result, Term]);
      end;
    except Result.FreeByParentExpression; raise end;
  end;

var
  FC: TKamScriptFunctionClass;
begin
  Result := nil;
  try
    Result := ComparisonArgument;
    while Lexer.Token in ComparisonOperator do
    begin
      FC := BinaryOper(Lexer.Token);
      Lexer.NextToken;
      Result := FC.Create([Result, ComparisonArgument]);
    end;
  except Result.FreeByParentExpression; raise end;
end;

type
  TKamScriptValuesArray = array of TKamScriptValue;

function VariablesListToArray(
  const Variables: TKamScriptValuesList): TKamScriptValuesArray;
var
  I: Integer;
begin
  SetLength(Result, Variables.Count);
  for I := 0 to Variables.High do
    Result[I] := Variables[I];
end;

function Expression(
  const Lexer: TKamScriptLexer;
  const Variables: TKamScriptValuesList): TKamScriptExpression;
begin
  Result := Expression(Lexer, VariablesListToArray(Variables));
end;

function Expression(
  const Lexer: TKamScriptLexer;
  const Variables: array of TKamScriptValue): TKamScriptExpression;

  function PossiblyAssignmentExpression: TKamScriptExpression;
  { How to parse this?

    Straighforward approach is to try parsing
    Operand, then check is it followed by ":=".
    In case of parsing errors (we can catch them by EKamScriptParserError),
    or something else than ":=", we rollback and parse NonAssignmentExpression.

    The trouble with this approach: "rollback". This is uneasy,
    as you have to carefully remember all tokens eaten during
    Operand parsing, and unget them to lexer (or otherwise reparse them).

    Simpler and faster approach used: just always parse an
    NonAssignmentExpression. This uses the fact that Operand is
    also a valid NonAssignmentExpression, and NonAssignmentExpression
    will not eat anything after ":=" (following the grammar, ":="
    cannot occur within NonAssignmentExpression without parenthesis).
    After parsing NonAssignmentExpression, we can check for ":=". }
  var
    Operand, AssignedValue: TKamScriptExpression;
  begin
    Result := NonAssignmentExpression(Lexer, true, Variables);
    try
      if Lexer.Token = tokAssignment then
      begin
        Lexer.NextToken;

        AssignedValue := PossiblyAssignmentExpression();

        Operand := Result;
        { set Result to nil, in case of exception from TKamScriptAssignment
          constructor. }
        Result := nil;

        { TKamScriptAssignment in constructor checks that
          Operand is actually a simple writeable operand. }
        Result := TKamScriptAssignment.Create([Operand, AssignedValue]);
      end;
    except Result.FreeByParentExpression; raise end;
  end;

var
  SequenceArgs: TKamScriptExpressionsList;
begin
  Result := nil;
  try
    Result := PossiblyAssignmentExpression;

    if Lexer.Token = tokSemicolon then
    begin
      SequenceArgs := TKamScriptExpressionsList.Create;
      try
        try
          SequenceArgs.Add(Result);
          Result := nil;

          while Lexer.Token = tokSemicolon do
          begin
            Lexer.NextToken;
            SequenceArgs.Add(PossiblyAssignmentExpression);
          end;
        except SequenceArgs.FreeContentsByParentExpression; raise end;

        Result := TKamScriptSequence.Create(SequenceArgs);
      finally FreeAndNil(SequenceArgs) end;
    end;
  except Result.FreeByParentExpression; raise end;
end;

function AProgram(
  const Lexer: TKamScriptLexer;
  const GlobalVariables: array of TKamScriptValue): TKamScriptProgram;

  function AFunction: TKamScriptFunctionDefinition;
  var
    BodyVariables: TKamScriptValuesList;
    Parameter: TKamScriptValue;
  begin
    Result := TKamScriptFunctionDefinition.Create;
    try
      Lexer.CheckTokenIs(tokIdentifier);
      Result.Name := Lexer.TokenString;
      Lexer.NextToken;

      BodyVariables := TKamScriptValuesList.Create;
      try
        Lexer.CheckTokenIs(tokLParen);
        Lexer.NextToken;

        if Lexer.Token <> tokRParen then
        begin
          repeat
            Lexer.CheckTokenIs(tokIdentifier);
            Parameter := TKamScriptFloat.Create;
            Parameter.Name := Lexer.TokenString;
            Parameter.OwnedByParentExpression := false;
            Result.Parameters.Add(Parameter);
            BodyVariables.Add(Parameter);
            Lexer.NextToken;

            if Lexer.Token = tokRParen then
              Break else
              begin
                Lexer.CheckTokenIs(tokComma);
                Lexer.NextToken;
              end;
          until false;
        end;

        Lexer.NextToken; { eat ")" }

        { We first added parameters, then added GlobalVariables,
          so when resolving, parameter names will hide global
          variable names, just like they should in normal language. }
        BodyVariables.AddArray(GlobalVariables);

        Result.Body := Expression(Lexer, BodyVariables);
      finally FreeAndNil(BodyVariables); end;
    except FreeAndNil(Result); raise end;
  end;

begin
  Result := TKamScriptProgram.Create;
  try
    while Lexer.Token = tokFunctionKeyword do
    begin
      Lexer.NextToken;
      Result.Functions.Add(AFunction);
    end;
  except FreeAndNil(Result); raise end;
end;

{ ParseFloatExpression ------------------------------------------------------- }

function ParseFloatExpression(const S: string;
  const Variables: array of TKamScriptValue): TKamScriptExpression;
var
  Lexer: TKamScriptLexer;
  I: Integer;
begin
  for I := 0 to Length(Variables) - 1 do
    Variables[I].OwnedByParentExpression := false;

  Lexer := TKamScriptLexer.Create(s);
  try
    Result := nil;
    try
      try
        Result := NonAssignmentExpression(Lexer, false, Variables);
        Lexer.CheckTokenIs(tokEnd);
      except
        { Change EKamScriptFunctionArgumentsError (raised when
          creating functions) to EKamScriptParserError.
          This allows the caller to catch only EKamScriptSyntaxError,
          and adds position information to error message. }
        on E: EKamScriptFunctionArgumentsError do
          raise EKamScriptParserError.Create(Lexer, E.Message);
      end;
    except Result.FreeByParentExpression; raise end;
  finally Lexer.Free end;
end;

{ ParseConstantFloatExpression ----------------------------------------------- }

function ParseConstantFloatExpression(const S: string): Float;
var
  Expr: TKamScriptExpression;
begin
  try
    Expr := ParseFloatExpression(s, []);
  except
    on E: EKamScriptSyntaxError do
    begin
      E.Message := 'Error when parsing constant expression: ' + E.Message;
      raise;
    end;
  end;

  try
    Result := (Expr.Execute as TKamScriptFloat).Value;
  finally Expr.Free end;
end;

{ ParseProgram --------------------------------------------------------------- }

function ParseProgram(const S: string;
  const Variables: TKamScriptValuesList): TKamScriptProgram;
begin
  Result := ParseProgram(S, VariablesListToArray(Variables));
end;

function ParseProgram(const S: string;
  const Variables: array of TKamScriptValue): TKamScriptProgram;
var
  Lexer: TKamScriptLexer;
  I: Integer;
begin
  for I := 0 to Length(Variables) - 1 do
    Variables[I].OwnedByParentExpression := false;

  Lexer := TKamScriptLexer.Create(s);
  try
    Result := nil;
    try
      try
        Result := AProgram(Lexer, Variables);
        Lexer.CheckTokenIs(tokEnd);
      except
        { Change EKamScriptFunctionArgumentsError (raised when
          creating functions) to EKamScriptParserError.
          This allows the caller to catch only EKamScriptSyntaxError,
          and adds position information to error message. }
        on E: EKamScriptFunctionArgumentsError do
          raise EKamScriptParserError.Create(Lexer, E.Message);
      end;
    except Result.Free; raise end;
  finally Lexer.Free end;
end;

end.
