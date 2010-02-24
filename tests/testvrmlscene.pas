unit TestVRMLScene;

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry;

type
  TTestVRMLScene = class(TTestCase)
  published
    procedure TestBorderManifoldEdges;
    procedure TestIterator;
    { $define ITERATOR_SPEED_TEST}
    {$ifdef ITERATOR_SPEED_TEST}
    procedure TestIteratorSpeed;
    {$endif ITERATOR_SPEED_TEST}
  end;

implementation

uses VRMLNodes, VRMLScene, Object3DAsVRML, VectorMath, VRMLShape,
  KambiTimeUtils, KambiStringUtils;

procedure TTestVRMLScene.TestBorderManifoldEdges;
var
  Scene: TVRMLScene;
begin
  Scene := TVRMLScene.Create(nil);
  try
    Scene.Load('model_manifold.wrl');
    Assert(Scene.BorderEdges.Count = 0);
  finally FreeAndNil(Scene) end;
end;

{$ifdef ITERATOR_SPEED_TEST}
procedure TTestVRMLScene.TestIteratorSpeed;

  procedure CheckIteratorSpeed(const FileName: string);
  var
    Scene: TVRMLScene;
    List: TVRMLShapesList;
    SI: TVRMLShapeTreeIterator;
    OnlyActive: boolean;
    I: Integer;
    Test: Integer;
  const
    TestCount = 1000;
  begin
    Scene := TVRMLScene.Create(LoadAsVRML(FileName), true);
    try
      for OnlyActive := false to true do
      begin
        ProcessTimerBegin;
        for Test := 0 to TestCount - 1 do
        begin
          List := TVRMLShapesList.Create(Scene.Shapes, OnlyActive);
          for I := 0 to List.Count - 1 do
            { Just do anything that requires access to List[I] }
            PointerToStr(List[I].Geometry);
          FreeAndNil(List);
        end;
        Writeln('TVRMLShapesList traverse: ', ProcessTimerEnd:1:2);

        ProcessTimerBegin;
        for Test := 0 to TestCount - 1 do
        begin
          SI := TVRMLShapeTreeIterator.Create(Scene.Shapes, OnlyActive);
          while SI.GetNext do
            PointerToStr(SI.Current.Geometry);
          FreeAndNil(SI);
        end;
        Writeln('TVRMLShapeTreeIterator: ', ProcessTimerEnd:1:2);

      end;
    finally FreeAndNil(Scene) end;
  end;

begin
  CheckIteratorSpeed('../../kambi_vrml_test_suite/x3d/deranged_house_final.x3dv');
  CheckIteratorSpeed('../../kambi_vrml_test_suite/x3d/anchor_test.x3dv');
  CheckIteratorSpeed('../../kambi_vrml_test_suite/x3d/switches_and_transforms.x3dv');
  CheckIteratorSpeed('../../kambi_vrml_test_suite/x3d/key_sensor.x3dv');

  CheckIteratorSpeed('switches_and_transforms_2.x3dv');
  CheckIteratorSpeed('key_sensor_2.x3dv');

  CheckIteratorSpeed('/home/michalis/sources/rrtankticks2/rrtankticks3/rrtt.wrl');
end;
{$endif ITERATOR_SPEED_TEST}

procedure TTestVRMLScene.TestIterator;

  procedure CheckIterator(const FileName: string);
  var
    Scene: TVRMLScene;
    List: TVRMLShapesList;
    SI: TVRMLShapeTreeIterator;
    OnlyActive: boolean;
    I: Integer;
  begin
    Scene := TVRMLScene.Create(nil);
    try
      Scene.Load(FileName);
      for OnlyActive := false to true do
      begin
        { Compare the simple iterator implementation (that just calls
          Traverse and gathers results to the list) with actual sophisticated
          implementation in TVRMLShapeTreeIterator. }
        List := TVRMLShapesList.Create(Scene.Shapes, OnlyActive);
        SI := TVRMLShapeTreeIterator.Create(Scene.Shapes, OnlyActive);
        for I := 0 to List.Count - 1 do
        begin
          Check(SI.GetNext, 'SI.GetNext');
          Check(SI.Current = List[I], 'SI.Current');
        end;
        Check(not SI.GetNext, 'not SI.GetNext');

//        writeln('done for ', FileName, ' active: ', OnlyActive, ' count is ', List.Count);

        FreeAndNil(List);
        FreeAndNil(SI);
      end;
    finally FreeAndNil(Scene) end;
  end;


begin
  CheckIterator('../../kambi_vrml_test_suite/x3d/deranged_house_final.x3dv');
  CheckIterator('../../kambi_vrml_test_suite/x3d/anchor_test.x3dv');
  CheckIterator('../../kambi_vrml_test_suite/x3d/switches_and_transforms.x3dv');
  CheckIterator('../../kambi_vrml_test_suite/x3d/key_sensor.x3dv');

  CheckIterator('switches_and_transforms_2.x3dv');
  CheckIterator('key_sensor_2.x3dv');
end;

initialization
  RegisterTest(TTestVRMLScene);
end.
