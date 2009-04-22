{ -*- compile-command: "./compile_console.sh" -*- }
{
  Copyright 2004-2005,2008 Michalis Kamburelis.

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

unit TestKambiStringUtils;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry;

type
  TTestKambiStringUtils= class(TTestCase)
  published
    procedure TestIntToStrPoz;
    procedure TestDeFormat;
    procedure TestSReplacePercent;
    procedure TestIntToStr2;
    procedure TestIntToStrThousandSep;
    procedure TestCompressWhiteSpace;
    procedure TestFormatIndexedName;
    procedure TestIntToStr64;
  end;

implementation

uses KambiUtils, KambiStringUtils;

procedure TTestKambiStringUtils.TestIntToStrPoz;
var i: Integer;
    l: Integer;
    s1, s2: string;
begin
 for i := 1 to 100 do
 begin
  { przetestowalbym tez na ujemnych ale Format('%x', [l]) z FPC nie dziala
    na nich tak jak trzeba. Ech. No to dobrze ze zrobilem wlasne IntToStr16. }
  l := Random(High(Integer)){ - High(Integer) div 2};
  s1 := IntToStr16(l);
  s2 := Format('%x', [l]);
  Assert(s1 = s2);
 end;
 Assert(IntToStr16(-17) = '-11');
end;

procedure TTestKambiStringUtils.TestDeFormat;
var
  s, S2: string;
  i: integer;
  f: float;
begin
  DeFormat('123FOO98.2e1 '#9'123ioioio-x    /'+nl, '%dfoo%f %s /',
    [@i, @f, @s], true);
  Assert(i = 123);
  Assert(f = 98.2e1);
  Assert(s = '123ioioio-x');

  { %% test }
  DeFormat('%d%%456foobar %', '%%d%%%%%d%s %%',
    [@i, @s], true);
  Assert(i = 456);
  Assert(s = 'foobar');

  { Test RelatedWhitespaceChecking }
  try
    DeFormat('123  foo', '%d %s %s', [@i, @S, @S2], true, true);
    raise Exception.Create('"DeFormat(123  foo)" with relaxed should fail');
  except
    on EDeformatError do ;
  end;
  DeFormat('123  foo', '%d %s %s', [@i, @S, @S2], true, false);
  Assert(I = 123);
  Assert(S = '');
  Assert(S2 = 'foo');

  { Test %s at the end of data can be '' }
  DeFormat('123 ', '%d %s', [@i, @s], true, true);
  Assert(I = 123);
  Assert(S = '');

  { Similar as above, but last 2 args different.
    Result should be the same. }
  DeFormat('123 ', '%d %s', [@i, @s], false, false);
  Assert(I = 123);
  Assert(S = '');
end;

procedure TTestKambiStringUtils.TestSReplacePercent;
const
  Replaces: array[0..1]of TPercentReplace =
  ((c:'k'; s:'kot'), (c:'p'; s:'pies'));
begin
 Assert( SPercentReplace('bla%kkk%jk%pies', Replaces, false, '%', false)
   = 'blakotkk%jkpiesies');
 try
  SPercentReplace('bla%kkk%jk%pies', Replaces, true, '%', false);
  raise Exception.Create('Last SPercentReplace SHOULD raise exception');
 except on E: EUnknownPercentFormat do Assert(e.Message = 'Unknown format pattern in format "bla%kkk%jk%pies", wrong sequence is : "%j"'); end;

 Assert( SPercentReplace('bla%kkk%Kk%pies', Replaces, true, '%', true) = 'blakotkkkotkpiesies');
 try
  SPercentReplace('bla%kkk%Kk%pies', Replaces, true, '%', false);
  raise Exception.Create('Last SPercentReplace SHOULD raise exception');
 except on E: EUnknownPercentFormat do Assert(e.Message = 'Unknown format pattern in format "bla%kkk%Kk%pies", wrong sequence is : "%K"'); end;

 Assert( SPercentReplace('bla%k%%', Replaces, false, '%', false) = 'blakot%');
 Assert( SPercentReplace('bla%k%%', Replaces, true, '%', false) = 'blakot%');

 Assert( SPercentReplace('foo%', Replaces, false, '%', false) = 'foo%');
 try
  Assert( SPercentReplace('foo%', Replaces, true, '%', false) = 'foo%');
  raise Exception.Create('Last SPercentReplace SHOULD raise exception');
 except on E: EUnknownPercentFormat do Assert(e.Message = 'Unknown format pattern in format "foo%", wrong sequence is : % at the end of the format string'); end;
end;

procedure TTestKambiStringUtils.TestIntToStr2;
var i, Value, MinLength: Integer;
begin
 Assert(IntToStr2(2) = '10');
 Assert(IntToStr2(0) = '0');
 Assert(IntToStr2(2, 4) = '0010');
 Assert(IntToStr2(-2, 4) = '-0010');
 Assert(IntToStr2(0, 4) = '0000');

 Assert(IntToStr2(2, 4, '_', 'M', '+') = '__M_');
 Assert(IntToStr2(-2, 4, '_', 'M', '+') = '+__M_');
 Assert(IntToStr2(0, 4, '_', 'M', '+') = '____');

 for i := 1 to 100 do
 begin
  Value := Integer(Random(10000)) - 10000 div 2;
  MinLength := Random(5);
  Assert(IntToStrPoz(Value, 2, MinLength) = IntToStr2(Value, MinLength));
 end;
end;

procedure TTestKambiStringUtils.TestIntToStrThousandSep;

  procedure Test(const Value: Int64; const GoodResult: string);
  var Res: string;
  begin
   Res := IntToStrThousandSep(Value);
   {Writeln('"', SReadableForm(Res), '" (should be "' +SReadableForm(GoodResult)+ '")');}
   Assert(Res = GoodResult);
  end;

begin
 Test(123, '123');
 Test(1234, '1' +ThousandSeparator+ '234');
 Test(12345, '12' +ThousandSeparator+ '345');
 Test(123456, '123' +ThousandSeparator+ '456');
 Test(7123456, '7' +ThousandSeparator+ '123' +ThousandSeparator+ '456');
end;

procedure TTestKambiStringUtils.TestCompressWhiteSpace;
begin
  Assert(SCompressWhiteSpace('') = '');
  Assert(SCompressWhiteSpace('a') = 'a');
  Assert(SCompressWhiteSpace(' ') = ' ');
  Assert(SCompressWhiteSpace('     ') = ' ');
  Assert(SCompressWhiteSpace(' blah blah ') = ' blah blah ');
  Assert(SCompressWhiteSpace('   blah  ' + CharTab + 'blah ' + NL) = ' blah blah ');
end;

procedure TTestKambiStringUtils.TestFormatIndexedName;
var
  ReplacementsDone: Cardinal;
begin
  Assert(FormatIndexedName('', 0, ReplacementsDone) = '');
  Assert(FormatIndexedName('a', 0, ReplacementsDone) = 'a');
  Assert(FormatIndexedName('a%', 0, ReplacementsDone) = 'a%');
  Assert(FormatIndexedName('%a%', 66, ReplacementsDone) = '%a%');
  Assert(FormatIndexedName('%d%', 66, ReplacementsDone) = '66%');
  Assert(FormatIndexedName('%%%', 66, ReplacementsDone) = '%%');
  Assert(FormatIndexedName('%%number%d%d.again%d', 66, ReplacementsDone) = '%number6666.again66');
  Assert(FormatIndexedName('%%number%0d%2d.again%4d', 66, ReplacementsDone) = '%number6666.again0066');
end;

procedure TTestKambiStringUtils.TestIntToStr64;
const
  A1: QWord = $ABCDEF123;
  A2: Int64 = $ABCDEF123;
  A3: Int64 = -$ABCDEF123;
  A4: QWord = $0123456789ABCDEF;
var
  A5, A6: QWord;
begin
  Assert(IntToStr16(A1) = 'ABCDEF123');
  Assert(IntToStr16(A2) = 'ABCDEF123');
  Assert(IntToStr16(A3) = '-ABCDEF123');

  Assert(IntToStr16(A4) = '123456789ABCDEF');

  { I want A5 = $EFCDAB8967452301, but I can't write it easily,
    FPC 2.2.2 says "Error: range check error while evaluating constants". }
  A5 := $FCDAB8967452301;
  A5 := A5 or ($E shl (7*8 + 4));
  Assert(IntToStr16(A5) = 'EFCDAB8967452301');

  { I want A6 = $FFEE000000000000, but I can't write it easily,
    FPC 2.2.2 says "Error: range check error while evaluating constants". }
  A6 := $FEE000000000000;
  A6 := A6 or ($F shl (7*8 + 4));
  Assert(IntToStr16(A6) = 'FFEE000000000000');
end;

initialization
  RegisterTest(TTestKambiStringUtils);
end.
