{ Compare sizes and RGB colors of two images.
  Designed to be a command-line tool usable from scripts, like

    if image_compare a.png b.png; then echo 'Yes'; else echo 'No'; file

  in bash (Unix etc.) scripts. Returns exit code 0 (and no output)
  if succcess (images are the same), or exit code 1 (and desciption
  of difference on error output) if images differ.

  The images are considered different if have different size,
  or if any component of any pixel differs > Tolerance (constant
  in this program).

  It doesn't handle images with different sizes, that is it simply
  detects them as "different", not bothering to check if maybe one
  image is a shifted, or subset, version of another. It also doesn't
  bother showing visual differences between images. See ImageMagick's
  "compare" tool for such fun (http://www.imagemagick.org/script/compare.php).
}
uses SysUtils, KambiUtils, VectorMath, Images;
const
  Tolerance = 5;
var
  Image1, Image2: TRGBImage;
  X, Y: Integer;
  Ptr1: PVector3Byte;
  Ptr2: PVector3Byte;
begin
  Parameters.CheckHigh(2);

  Image1 := nil;
  Image2 := nil;
  try
    Image1 := LoadImage(Parameters[1], [TRGBImage], []) as TRGBImage;
    Image2 := LoadImage(Parameters[2], [TRGBImage], []) as TRGBImage;

    if (Image1.Width <> Image2.Width) or
       (Image1.Height <> Image2.Height) then
    begin
      Writeln(ErrOutput, Format('Image sizes differ: %dx%d vs %dx%d',
        [Image1.Width, Image1.Height,
         Image2.Width, Image2.Height]));
      Halt(1);
    end else
    begin
      Ptr1 := Image1.RGBPixels;
      Ptr2 := Image2.RGBPixels;
      for X := 0 to Integer(Image1.Width) - 1 do
        for Y := 0 to Integer(Image1.Height) - 1 do
        begin
          if (Abs(Ptr1^[0] - Ptr2^[0]) > Tolerance) or
             (Abs(Ptr1^[1] - Ptr2^[1]) > Tolerance) or
             (Abs(Ptr1^[2] - Ptr2^[2]) > Tolerance) then
          begin
            Writeln(ErrOutput, Format('Image colors differ on pixel (%d,%d) (counted from the bottom-left)',
              [X, Y]));
            Halt(1);
          end;
          Inc(Ptr1);
          Inc(Ptr2);
        end;
    end;
  finally
    FreeAndNil(Image1);
    FreeAndNil(Image2);
  end;
end.
