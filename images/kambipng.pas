(*
  @abstract(Bindings to libpng.)

  Png.pas from FPC packages/extra/libpng/png.pp modified by Kambi.

  Detailed list of my modifications:

  @unorderedList(
    @item(
      Made compileable with Delphi (under Delphi use "{$ALIGN 4}" instead of
      "{$PACKRECORDS C}", "pointer" instead of "jmp_buf"))
    @item(Use KambiZlib instead of Zlib module.)
    @item(Added PngLibraryName, PNG_LIBPNG_VER_* constants)
    @item(
      Added ALL other constants (missing in FPC Png -- lost during h2pas
      processing ?))
    @item(
      Removed external variables (compileable only under FPC+Linux and when
      LibPng file exists; useless anyway --- probably, they we're useful in
      older libpng versions))
    @item(
      Work with win32 libpng version with stdcalls
      (changed "cdecl" to "{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif}"))
    @item(
      Changed all functions from declared as "external" to functions' pointers
      (variables) to use TDynLib from KambiUtils (to easily find if some functions
      are missing in libpng.(so|dll)))
    @item(
      png_read_destroy, png_write_destroy_info, png_write_destroy,
      png_set_sCAL_s commented out --- they are not present in many libpng so/dll
      versions. First three are obsolete.)
    @item(dword is LongWord, so it doesn't require Types unit under Delphi)
    @item(
      If libgpng is not installed on system (PngLibraryName not found),
      there is no exception at initialization.
      Instead it merely sets KambiPngInited to false.
      This way programs that use this unit do NOT require libpng to be
      installed on target system. Libpng must be present only if program
      at runtime will really need it, e.g. Images.LoadPNG will raise an
      exception if libpng is not installed.)
  )

  Some comments:
  @unorderedList(
    @item(
      works with either libpng.so (Unix) or libpng12.dll (Windows).
      Some things are prepared to support cygpng2.dll from cygwin,
      but they doesn't work with my version of Cygwin.)

    @item(
      can work with (hopefully) all compatible versions of libpng,
      @orderedList(
        @item(
          not only with ones that have version equal to defined here
          constants PNG_LIBPNG_VER_xxx - look at functions
          SO_PNG_LIBPNG_VER_xxx in KambiPngUtils and use them !)

        @item(
          it links with file 'libpng.so', NOT with 'libpng.so.2' or 'libpng.so.3'
          so it can work with ANY of these libraries. Zrobione po mailu
          od Szymona - myslalem ze to bylo zrobione juz wczesniej
          bo przeciez wszedzie robilem "exported 'libpng.so';" ale okazalo
          sie ze Linuxowe 'ld' najwyrazniej w czasie linkowania programu
          schodzilo z symbolic linka 'libpng.so' do 'libpng.so.2' lub '.3'
          w zaleznosci od tego jak mialem akurat skonfigurowany system.
          Po prostu 'ld' zakladalo ze tak naprawde nie chce sie linkowac
          z 'libpng.so' tylko z wersja libpng.so.2 lub 3. To zapewne
          ma zabezpieczac programiste - bo niby wraz ze zmiana major number
          biblioteki jej API powinno byc niekompatybilne - ale w przypadku
          png jest wystarczajaco kompatybilne dla nas !

          Nie bylem w stanie powiedziec tego 'ld' wiec musialem ladowac funkcje
          z libpng bezposrednio kodem w initialization.)
      )
    )
  )
*)

unit KambiPng;

{$I kambiconf.inc}
{$I pngconf.inc}

interface

uses KambiZlib;

{ Automatically converted by H2Pas 0.99.15 from png.h }
{ The following command line parameters were used:
    png.h
}

{$ifndef FPC}
  {$ALIGN 4}
{$else}
  {$PACKRECORDS C}
{$endif}

{ Following consts added by Kambi.
  Unfortunately, they are specific to dll version !! Very bad - I'd like
  to have rather application that can run with every version that is compatible
  instead of ONLY this version ! So - I use my functions (defined in
  KambiPngUtils unit) SO_PNG_LIBPNG_VER_STRING, SO_PNG_VER_MAJOR etc.
  that return the REAL .so (or .dll) version number
  (using png_access_version_number). This version can be then passed to
  png_create_write_struct to ensure that libpng will not return with error :
  "png.h and png.c versions not compatible".

  However - we should
  be aware that using an uncompatible libpng version will probably lead
  w najlepszym wypadku do acess violation - bo tak naprawde, moze doprowadzic
  do wszystkiego ! Nie widze tutaj jednak rozwiazania; rezerwuje sobie
  w kazdym razie prawo do zatrzymania programu (no, rzucenia wyjatku)
  podczas wywolania
  jednej z powyzszych funkcji SO_PNG_xxx jezeli wykryje ze wersja libpng
  jest BARDZO rozna od mojej wersji. }
const
  {$ifdef PNG_GNUWIN32} { libpng distributed by gnuwin32.sourceforge.net }
  PngLibraryName = 'libpng12.dll';
  PNG_LIBPNG_VER_STRING = '1.2.5';
  PNG_LIBPNG_VER_MAJOR   = 1;
  PNG_LIBPNG_VER_MINOR   = 2;
  PNG_LIBPNG_VER_RELEASE = 5;
  {$endif}

  {$ifdef PNG_VB} { libpng_vb version }
  PngLibraryName='libpng_vb.dll';
  PNG_LIBPNG_VER_STRING = '1.2.1';
  PNG_LIBPNG_VER_MAJOR   = 1;
  PNG_LIBPNG_VER_MINOR   = 2;
  PNG_LIBPNG_VER_RELEASE = 1;
  {$endif}

  {$ifdef PNG_CYGWIN} { cygwin dll version }
  PngLibraryName = 'cygpng2.dll';
  PNG_LIBPNG_VER_STRING = '1.0.11';
  PNG_LIBPNG_VER_MAJOR   = 1;
  PNG_LIBPNG_VER_MINOR   = 0;
  PNG_LIBPNG_VER_RELEASE = 11;
  {$endif}

  {$ifdef UNIX}
  PngLibraryName =
    {$ifdef DARWIN} 'libpng.dylib' { TODO--confirm this works under Darwin }
    {$else} 'libpng.so'
    {$endif};
  PNG_LIBPNG_VER_STRING = '1.0.12';
  { These should match the first 3 components of PNG_LIBPNG_VER_STRING: }
  PNG_LIBPNG_VER_MAJOR  = 1;
  PNG_LIBPNG_VER_MINOR  = 0;
  PNG_LIBPNG_VER_RELEASE= 12;
  {$endif}

{ ALL consts below added by Kambi. }

const
{ Supported compression types for text in PNG files (tEXt, and zTXt).
 * The values of the PNG_TEXT_COMPRESSION_ defines should NOT be changed. }
  PNG_TEXT_COMPRESSION_NONE_WR = -3;
  PNG_TEXT_COMPRESSION_zTXt_WR = -2;
  PNG_TEXT_COMPRESSION_NONE = -1;
  PNG_TEXT_COMPRESSION_zTXt = 0;
  PNG_ITXT_COMPRESSION_NONE = 1;
  PNG_ITXT_COMPRESSION_zTXt = 2;
  PNG_TEXT_COMPRESSION_LAST = 3;  { Not a valid value }

{ Maximum positive integer used in PNG is (2^31)-1 }
  PNG_MAX_UINT = High(LongWord);

{ These describe the color_type field in png_info. }
{ color type masks }
  PNG_COLOR_MASK_PALETTE = 1;
  PNG_COLOR_MASK_COLOR = 2;
  PNG_COLOR_MASK_ALPHA = 4;

{ color types.  Note that not all combinations are legal }
  PNG_COLOR_TYPE_GRAY = 0;
  PNG_COLOR_TYPE_PALETTE = (PNG_COLOR_MASK_COLOR or PNG_COLOR_MASK_PALETTE);
  PNG_COLOR_TYPE_RGB = (PNG_COLOR_MASK_COLOR);
  PNG_COLOR_TYPE_RGB_ALPHA = (PNG_COLOR_MASK_COLOR or PNG_COLOR_MASK_ALPHA);
  PNG_COLOR_TYPE_GRAY_ALPHA = (PNG_COLOR_MASK_ALPHA);
{ aliases }
  PNG_COLOR_TYPE_RGBA = PNG_COLOR_TYPE_RGB_ALPHA;
  PNG_COLOR_TYPE_GA = PNG_COLOR_TYPE_GRAY_ALPHA;

{ This is for compression type. PNG 1.0-1.2 only define the single type. }
  PNG_COMPRESSION_TYPE_BASE = 0 { Deflate method 8, 32K window };
  PNG_COMPRESSION_TYPE_DEFAULT = PNG_COMPRESSION_TYPE_BASE;

{ This is for filter type. PNG 1.0-1.2 only define the single type. }
  PNG_FILTER_TYPE_BASE = 0 { Single row per-byte filtering };
  PNG_INTRAPIXEL_DIFFERENCING = 64 { Used only in MNG datastreams };
  PNG_FILTER_TYPE_DEFAULT = PNG_FILTER_TYPE_BASE;

{ These are for the interlacing type.  These values should NOT be changed. }
  PNG_INTERLACE_NONE = 0 { Non-interlaced image };
  PNG_INTERLACE_ADAM7 = 1 { Adam7 interlacing };
  PNG_INTERLACE_LAST = 2 { Not a valid value };

{ These are for the oFFs chunk.  These values should NOT be changed. }
  PNG_OFFSET_PIXEL = 0 { Offset in pixels };
  PNG_OFFSET_MICROMETER = 1 { Offset in micrometers (1/10^6 meter) };
  PNG_OFFSET_LAST = 2 { Not a valid value };

{ These are for the pCAL chunk.  These values should NOT be changed. }
  PNG_EQUATION_LINEAR = 0 { Linear transformation };
  PNG_EQUATION_BASE_E = 1 { Exponential base e transform };
  PNG_EQUATION_ARBITRARY = 2 { Arbitrary base exponential transform };
  PNG_EQUATION_HYPERBOLIC = 3 { Hyperbolic sine transformation };
  PNG_EQUATION_LAST = 4 { Not a valid value };

{ These are for the sCAL chunk.  These values should NOT be changed. }
  PNG_SCALE_UNKNOWN = 0 { unknown unit (image scale) };
  PNG_SCALE_METER = 1 { meters per pixel };
  PNG_SCALE_RADIAN = 2 { radians per pixel };
  PNG_SCALE_LAST = 3 { Not a valid value };

{ These are for the pHYs chunk.  These values should NOT be changed. }
  PNG_RESOLUTION_UNKNOWN = 0 { pixels/unknown unit (aspect ratio) };
  PNG_RESOLUTION_METER = 1 { pixels/meter };
  PNG_RESOLUTION_LAST = 2 { Not a valid value };

{ These are for the sRGB chunk.  These values should NOT be changed. }
  PNG_sRGB_INTENT_PERCEPTUAL =0;
  PNG_sRGB_INTENT_RELATIVE   =1;
  PNG_sRGB_INTENT_SATURATION =2;
  PNG_sRGB_INTENT_ABSOLUTE   =3;
  PNG_sRGB_INTENT_LAST = 4 { Not a valid value };

{ This is for text chunks }
  PNG_KEYWORD_MAX_LENGTH = 79;

{ Maximum number of entries in PLTE/sPLT/tRNS arrays }
  PNG_MAX_PALETTE_LENGTH = 256;

{ These determine if an ancillary chunk's data has been successfully read
 * from the PNG header, or if the application has filled in the corresponding
 * data in the info_struct to be written into the output file.  The values
 * of the PNG_INFO_<chunk> defines should NOT be changed.
 }
  PNG_INFO_gAMA = $0001;
  PNG_INFO_sBIT = $0002;
  PNG_INFO_cHRM = $0004;
  PNG_INFO_PLTE = $0008;
  PNG_INFO_tRNS = $0010;
  PNG_INFO_bKGD = $0020;
  PNG_INFO_hIST = $0040;
  PNG_INFO_pHYs = $0080;
  PNG_INFO_oFFs = $0100;
  PNG_INFO_tIME = $0200;
  PNG_INFO_pCAL = $0400;
  PNG_INFO_sRGB = $0800   { GR-P, 0.96a };
  PNG_INFO_iCCP = $1000   { ESR, 1.0.6 };
  PNG_INFO_sPLT = $2000   { ESR, 1.0.6 };
  PNG_INFO_sCAL = $4000   { ESR, 1.0.6 };
  PNG_INFO_IDAT = $8000   { ESR, 1.0.6 };

{ Transform masks for the high-level interface }
  PNG_TRANSFORM_IDENTITY = $0000    { read and write };
  PNG_TRANSFORM_STRIP_16 = $0001    { read only };
  PNG_TRANSFORM_STRIP_ALPHA = $0002    { read only };
  PNG_TRANSFORM_PACKING = $0004    { read and write };
  PNG_TRANSFORM_PACKSWAP = $0008    { read and write };
  PNG_TRANSFORM_EXPAND = $0010    { read only };
  PNG_TRANSFORM_INVERT_MONO = $0020    { read and write };
  PNG_TRANSFORM_SHIFT = $0040    { read and write };
  PNG_TRANSFORM_BGR = $0080    { read and write };
  PNG_TRANSFORM_SWAP_ALPHA = $0100    { read and write };
  PNG_TRANSFORM_SWAP_ENDIAN = $0200    { read and write };
  PNG_TRANSFORM_INVERT_ALPHA = $0400    { read and write };
  PNG_TRANSFORM_STRIP_FILLER = $0800    { WRITE only };

{ Flags for MNG supported features }
  PNG_FLAG_MNG_EMPTY_PLTE = $01;
  PNG_FLAG_MNG_FILTER_64 = $04;
  PNG_ALL_MNG_FEATURES = $05;

{ png_set_filler : Add a filler byte to 24-bit RGB images. }
{ The values of the PNG_FILLER_ defines should NOT be changed }
  PNG_FILLER_BEFORE =0;
  PNG_FILLER_AFTER =1;

{ png_set_background : Handle alpha and tRNS by replacing with a background color. }
  PNG_BACKGROUND_GAMMA_UNKNOWN =0;
  PNG_BACKGROUND_GAMMA_SCREEN  =1;
  PNG_BACKGROUND_GAMMA_FILE    =2;
  PNG_BACKGROUND_GAMMA_UNIQUE  =3;

{ Values for png_set_crc_action() to say how to handle CRC errors in
 * ancillary and critical chunks, and whether to use the data contained
 * therein.  Note that it is impossible to "discard" data in a critical
 * chunk.  For versions prior to 0.90, the action was always error/quit,
 * whereas in version 0.90 and later, the action for CRC errors in ancillary
 * chunks is warn/discard.  These values should NOT be changed.
 *
 *      value                       action:critical     action:ancillary
 }
  PNG_CRC_DEFAULT = 0  { error/quit          warn/discard data };
  PNG_CRC_ERROR_QUIT = 1  { error/quit          error/quit        };
  PNG_CRC_WARN_DISCARD = 2  { (INVALID)           warn/discard data };
  PNG_CRC_WARN_USE = 3  { warn/use data       warn/use data     };
  PNG_CRC_QUIET_USE = 4  { quiet/use data      quiet/use data    };
  PNG_CRC_NO_CHANGE = 5  { use current value   use current value };

{ Flags for png_set_filter() to say which filters to use.  The flags
 * are chosen so that they don't conflict with real filter types
 * below, in case they are supplied instead of the #defined constants.
 * These values should NOT be changed.
 }
  PNG_NO_FILTERS = $00;
  PNG_FILTER_NONE = $08;
  PNG_FILTER_SUB = $10;
  PNG_FILTER_UP = $20;
  PNG_FILTER_AVG = $40;
  PNG_FILTER_PAETH = $80;
  PNG_ALL_FILTERS = (PNG_FILTER_NONE or PNG_FILTER_SUB or PNG_FILTER_UP or
                         PNG_FILTER_AVG or PNG_FILTER_PAETH);

{ Filter values (not flags) - used in pngwrite.c, pngwutil.c for now.
 * These defines should NOT be changed.
 }
  PNG_FILTER_VALUE_NONE  =0;
  PNG_FILTER_VALUE_SUB   =1;
  PNG_FILTER_VALUE_UP    =2;
  PNG_FILTER_VALUE_AVG   =3;
  PNG_FILTER_VALUE_PAETH =4;
  PNG_FILTER_VALUE_LAST  =5;

{ Heuristic used for row filter selection.  These defines should NOT be
 * changed.
 }
  PNG_FILTER_HEURISTIC_DEFAULT = 0  { Currently "UNWEIGHTED" };
  PNG_FILTER_HEURISTIC_UNWEIGHTED = 1  { Used by libpng < 0.95 };
  PNG_FILTER_HEURISTIC_WEIGHTED = 2  { Experimental feature };
  PNG_FILTER_HEURISTIC_LAST = 3  { Not a valid value };

type
   { @noAutoLinkHere }
   size_t = longint;
   { @noAutoLinkHere }
   time_t = longint;
   { @noAutoLinkHere }
   int = longint;
   z_stream = TZStream;
   { @noAutoLinkHere }
   voidp = pointer;

   png_uint_32 = LongWord;
   png_int_32 = longint;
   png_uint_16 = word;
   png_int_16 = smallint;
   png_byte = byte;
   ppng_uint_32 = ^png_uint_32;
   ppng_int_32 = ^png_int_32;
   ppng_uint_16 = ^png_uint_16;
   ppng_int_16 = ^png_int_16;
   ppng_byte = ^png_byte;
   pppng_uint_32 = ^ppng_uint_32;
   pppng_int_32 = ^ppng_int_32;
   pppng_uint_16 = ^ppng_uint_16;
   pppng_int_16 = ^ppng_int_16;
   pppng_byte = ^ppng_byte;
   png_size_t = size_t;
   png_fixed_point = png_int_32;
   ppng_fixed_point = ^png_fixed_point;
   pppng_fixed_point = ^ppng_fixed_point;
   png_voidp = pointer;
   png_bytep = Ppng_byte;
   ppng_bytep = ^png_bytep;
   png_uint_32p = Ppng_uint_32;
   png_int_32p = Ppng_int_32;
   png_uint_16p = Ppng_uint_16;
   ppng_uint_16p = ^png_uint_16p;
   png_int_16p = Ppng_int_16;
(* Const before type ignored *)
   png_const_charp = Pchar;
   png_charp = Pchar;
   ppng_charp = ^png_charp;
   png_fixed_point_p = Ppng_fixed_point;
   TFile = Pointer;
   png_FILE_p = ^FILE;
   png_doublep = Pdouble;
   png_bytepp = PPpng_byte;
   png_uint_32pp = PPpng_uint_32;
   png_int_32pp = PPpng_int_32;
   png_uint_16pp = PPpng_uint_16;
   png_int_16pp = PPpng_int_16;
 (* Const before type ignored *)
   png_const_charpp = PPchar;
   png_charpp = PPchar;
   ppng_charpp = ^png_charpp;
   png_fixed_point_pp = PPpng_fixed_point;
   PPDouble = ^PDouble;
   png_doublepp = PPdouble;
   PPPChar = ^PPCHar;
   png_charppp = PPPchar;
   Pcharf = Pchar;
   PPcharf = ^Pcharf;
   png_zcharp = Pcharf;
   png_zcharpp = PPcharf;
   png_zstreamp = Pzstream;

{
Commented out by Kambi:

var
  png_libpng_ver : array[0..11] of char;   cvar; external;
  png_pass_start : array[0..6] of longint; cvar; external;
  png_pass_inc : array[0..6] of longint;   cvar; external;
  png_pass_ystart : array[0..6] of longint;cvar; external;
  png_pass_yinc : array[0..6] of longint;  cvar; external;
  png_pass_mask : array[0..6] of longint;  cvar; external;
  png_pass_dsp_mask : array[0..6] of longint; cvar; external;
}

Type
  png_color = record
       red : png_byte;
       green : png_byte;
       blue : png_byte;
    end;
  ppng_color = ^png_color;
  pppng_color = ^ppng_color;

  png_color_struct = png_color;
  png_colorp = Ppng_color;
  ppng_colorp = ^png_colorp;
  png_colorpp = PPpng_color;
  png_color_16 = record
       index : png_byte;
       red : png_uint_16;
       green : png_uint_16;
       blue : png_uint_16;
       gray : png_uint_16;
    end;
  ppng_color_16 = ^png_color_16 ;
  pppng_color_16 = ^ppng_color_16 ;
  png_color_16_struct = png_color_16;
  png_color_16p = Ppng_color_16;
  ppng_color_16p = ^png_color_16p;
  png_color_16pp = PPpng_color_16;
  png_color_8 = record
       red : png_byte;
       green : png_byte;
       blue : png_byte;
       gray : png_byte;
       alpha : png_byte;
    end;
  ppng_color_8 = ^png_color_8;
  pppng_color_8 = ^ppng_color_8;
  png_color_8_struct = png_color_8;
  png_color_8p = Ppng_color_8;
  ppng_color_8p = ^png_color_8p;
  png_color_8pp = PPpng_color_8;
  png_sPLT_entry = record
       red : png_uint_16;
       green : png_uint_16;
       blue : png_uint_16;
       alpha : png_uint_16;
       frequency : png_uint_16;
    end;
  ppng_sPLT_entry = ^png_sPLT_entry;
  pppng_sPLT_entry = ^ppng_sPLT_entry;
  png_sPLT_entry_struct = png_sPLT_entry;
  png_sPLT_entryp = Ppng_sPLT_entry;
  png_sPLT_entrypp = PPpng_sPLT_entry;
  png_sPLT_t = record
       name : png_charp;
       depth : png_byte;
       entries : png_sPLT_entryp;
       nentries : png_int_32;
    end;
  ppng_sPLT_t = ^png_sPLT_t;
  pppng_sPLT_t = ^ppng_sPLT_t;
  png_sPLT_struct = png_sPLT_t;
  png_sPLT_tp = Ppng_sPLT_t;
  png_sPLT_tpp = PPpng_sPLT_t;
  png_text = record
       compression : longint;
       key : png_charp;
       text : png_charp;
       text_length : png_size_t;
    end;
  ppng_text = ^png_text;
  pppng_text = ^ppng_text;

  png_text_struct = png_text;
  png_textp = Ppng_text;
  ppng_textp = ^png_textp;
  png_textpp = PPpng_text;
  png_time = record
       year : png_uint_16;
       month : png_byte;
       day : png_byte;
       hour : png_byte;
       minute : png_byte;
       second : png_byte;
    end;
  ppng_time = ^png_time;
  pppng_time = ^ppng_time;

  png_time_struct = png_time;
  png_timep = Ppng_time;
  PPNG_TIMEP = ^PNG_TIMEP;
  png_timepp = PPpng_time;
  png_unknown_chunk = record
       name : array[0..4] of png_byte;
       data : Ppng_byte;
       size : png_size_t;
       location : png_byte;
    end;
  ppng_unknown_chunk = ^png_unknown_chunk;
  pppng_unknown_chunk = ^ppng_unknown_chunk;

  png_unknown_chunk_t = png_unknown_chunk;
  png_unknown_chunkp = Ppng_unknown_chunk;
  png_unknown_chunkpp = PPpng_unknown_chunk;
  png_info = record
       width : png_uint_32;
       height : png_uint_32;
       valid : png_uint_32;
       rowbytes : png_uint_32;
       palette : png_colorp;
       num_palette : png_uint_16;
       num_trans : png_uint_16;
       bit_depth : png_byte;
       color_type : png_byte;
       compression_type : png_byte;
       filter_type : png_byte;
       interlace_type : png_byte;
       channels : png_byte;
       pixel_depth : png_byte;
       spare_byte : png_byte;
       signature : array[0..7] of png_byte;
       gamma : double;
       srgb_intent : png_byte;
       num_text : longint;
       max_text : longint;
       text : png_textp;
       mod_time : png_time;
       sig_bit : png_color_8;
       trans : png_bytep;
       trans_values : png_color_16;
       background : png_color_16;
       x_offset : png_int_32;
       y_offset : png_int_32;
       offset_unit_type : png_byte;
       x_pixels_per_unit : png_uint_32;
       y_pixels_per_unit : png_uint_32;
       phys_unit_type : png_byte;
       hist : png_uint_16p;
       x_white : double;
       y_white : double;
       x_red : double;
       y_red : double;
       x_green : double;
       y_green : double;
       x_blue : double;
       y_blue : double;
       pcal_purpose : png_charp;
       pcal_X0 : png_int_32;
       pcal_X1 : png_int_32;
       pcal_units : png_charp;
       pcal_params : png_charpp;
       pcal_type : png_byte;
       pcal_nparams : png_byte;
       free_me : png_uint_32;
       unknown_chunks : png_unknown_chunkp;
       unknown_chunks_num : png_size_t;
       iccp_name : png_charp;
       iccp_profile : png_charp;
       iccp_proflen : png_uint_32;
       iccp_compression : png_byte;
       splt_palettes : png_sPLT_tp;
       splt_palettes_num : png_uint_32;
       scal_unit : png_byte;
       scal_pixel_width : double;
       scal_pixel_height : double;
       scal_s_width : png_charp;
       scal_s_height : png_charp;
       row_pointers : png_bytepp;
       int_gamma : png_fixed_point;
       int_x_white : png_fixed_point;
       int_y_white : png_fixed_point;
       int_x_red : png_fixed_point;
       int_y_red : png_fixed_point;
       int_x_green : png_fixed_point;
       int_y_green : png_fixed_point;
       int_x_blue : png_fixed_point;
       int_y_blue : png_fixed_point;
    end;
  ppng_info = ^png_info;
  pppng_info = ^ppng_info;

  png_info_struct = png_info;
  png_infop = Ppng_info;
  png_infopp = PPpng_info;
  png_row_info = record
       width : png_uint_32;
       rowbytes : png_uint_32;
       color_type : png_byte;
       bit_depth : png_byte;
       channels : png_byte;
       pixel_depth : png_byte;
    end;
  ppng_row_info = ^png_row_info;
  pppng_row_info = ^ppng_row_info;

  png_row_info_struct = png_row_info;
  png_row_infop = Ppng_row_info;
  png_row_infopp = PPpng_row_info;
//  png_struct_def = png_struct;
  png_structp = ^png_struct;

png_error_ptr = Procedure(Arg1 : png_structp; Arg2 : png_const_charp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_rw_ptr = Procedure(Arg1 : png_structp; Arg2 : png_bytep; Arg3 : png_size_t);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_flush_ptr = procedure (Arg1 : png_structp) ;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_read_status_ptr = procedure (Arg1 : png_structp; Arg2 : png_uint_32; Arg3: int);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_write_status_ptr = Procedure (Arg1 : png_structp; Arg2: png_uint_32;Arg3 : int) ;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_progressive_info_ptr = Procedure (Arg1 : png_structp; Arg2 : png_infop) ;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_progressive_end_ptr = Procedure (Arg1 : png_structp; Arg2 : png_infop) ;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_progressive_row_ptr = Procedure (Arg1 : png_structp; Arg2 : png_bytep; Arg3 : png_uint_32; Arg4 : int) ;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_user_transform_ptr = Procedure (Arg1 : png_structp; Arg2 : png_row_infop; Arg3 : png_bytep) ;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_user_chunk_ptr = Function (Arg1 : png_structp; Arg2 : png_unknown_chunkp): longint;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_unknown_chunk_ptr = Procedure (Arg1 : png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_malloc_ptr = Function (Arg1 : png_structp; Arg2 : png_size_t) : png_voidp ;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
png_free_ptr = Procedure (Arg1 : png_structp; Arg2 : png_voidp) ; {$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};

   png_struct_def = record
        jmpbuf : {$ifdef DELPHI} pointer {$else} jmp_buf {$endif};
        error_fn : png_error_ptr;
        warning_fn : png_error_ptr;
        error_ptr : png_voidp;
        write_data_fn : png_rw_ptr;
        read_data_fn : png_rw_ptr;
        io_ptr : png_voidp;
        read_user_transform_fn : png_user_transform_ptr;
        write_user_transform_fn : png_user_transform_ptr;
        user_transform_ptr : png_voidp;
        user_transform_depth : png_byte;
        user_transform_channels : png_byte;
        mode : png_uint_32;
        flags : png_uint_32;
        transformations : png_uint_32;
        zstream : z_stream;
        zbuf : png_bytep;
        zbuf_size : png_size_t;
        zlib_level : longint;
        zlib_method : longint;
        zlib_window_bits : longint;
        zlib_mem_level : longint;
        zlib_strategy : longint;
        width : png_uint_32;
        height : png_uint_32;
        num_rows : png_uint_32;
        usr_width : png_uint_32;
        rowbytes : png_uint_32;
        irowbytes : png_uint_32;
        iwidth : png_uint_32;
        row_number : png_uint_32;
        prev_row : png_bytep;
        row_buf : png_bytep;
        sub_row : png_bytep;
        up_row : png_bytep;
        avg_row : png_bytep;
        paeth_row : png_bytep;
        row_info : png_row_info;
        idat_size : png_uint_32;
        crc : png_uint_32;
        palette : png_colorp;
        num_palette : png_uint_16;
        num_trans : png_uint_16;
        chunk_name : array[0..4] of png_byte;
        compression : png_byte;
        filter : png_byte;
        interlaced : png_byte;
        pass : png_byte;
        do_filter : png_byte;
        color_type : png_byte;
        bit_depth : png_byte;
        usr_bit_depth : png_byte;
        pixel_depth : png_byte;
        channels : png_byte;
        usr_channels : png_byte;
        sig_bytes : png_byte;
        filler : png_uint_16;
        background_gamma_type : png_byte;
        background_gamma : double;
        background : png_color_16;
        background_1 : png_color_16;
        output_flush_fn : png_flush_ptr;
        flush_dist : png_uint_32;
        flush_rows : png_uint_32;
        gamma_shift : longint;
        gamma : double;
        screen_gamma : double;
        gamma_table : png_bytep;
        gamma_from_1 : png_bytep;
        gamma_to_1 : png_bytep;
        gamma_16_table : png_uint_16pp;
        gamma_16_from_1 : png_uint_16pp;
        gamma_16_to_1 : png_uint_16pp;
        sig_bit : png_color_8;
        shift : png_color_8;
        trans : png_bytep;
        trans_values : png_color_16;
        read_row_fn : png_read_status_ptr;
        write_row_fn : png_write_status_ptr;
        info_fn : png_progressive_info_ptr;
        row_fn : png_progressive_row_ptr;
        end_fn : png_progressive_end_ptr;
        save_buffer_ptr : png_bytep;
        save_buffer : png_bytep;
        current_buffer_ptr : png_bytep;
        current_buffer : png_bytep;
        push_length : png_uint_32;
        skip_length : png_uint_32;
        save_buffer_size : png_size_t;
        save_buffer_max : png_size_t;
        buffer_size : png_size_t;
        current_buffer_size : png_size_t;
        process_mode : longint;
        cur_palette : longint;
        current_text_size : png_size_t;
        current_text_left : png_size_t;
        current_text : png_charp;
        current_text_ptr : png_charp;
        palette_lookup : png_bytep;
        dither_index : png_bytep;
        hist : png_uint_16p;
        heuristic_method : png_byte;
        num_prev_filters : png_byte;
        prev_filters : png_bytep;
        filter_weights : png_uint_16p;
        inv_filter_weights : png_uint_16p;
        filter_costs : png_uint_16p;
        inv_filter_costs : png_uint_16p;
        time_buffer : png_charp;
        free_me : png_uint_32;
        user_chunk_ptr : png_voidp;
        read_user_chunk_fn : png_user_chunk_ptr;
        num_chunk_list : longint;
        chunk_list : png_bytep;
        rgb_to_gray_status : png_byte;
        rgb_to_gray_red_coeff : png_uint_16;
        rgb_to_gray_green_coeff : png_uint_16;
        rgb_to_gray_blue_coeff : png_uint_16;
        empty_plte_permitted : png_byte;
        int_gamma : png_fixed_point;
     end;
   ppng_struct_def = ^png_struct_def;
   pppng_struct_def = ^ppng_struct_def;
   png_struct = png_struct_def;
   ppng_struct = ^png_struct;
   pppng_struct = ^ppng_struct;

   version_1_0_8 = png_structp;
   png_structpp = PPpng_struct;

var
  png_access_version_number: function: png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_sig_bytes: procedure(png_ptr: png_structp; num_bytes: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_sig_cmp: function(sig: png_bytep; start: png_size_t; num_to_check: png_size_t): longint;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_check_sig: function(sig: png_bytep; num: longint): longint;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_create_read_struct: function(user_png_ver: png_const_charp; error_ptr: png_voidp; error_fn: png_error_ptr; warn_fn: png_error_ptr): png_structp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_create_write_struct: function(user_png_ver: png_const_charp; error_ptr: png_voidp; error_fn: png_error_ptr; warn_fn: png_error_ptr): png_structp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_compression_buffer_size: function(png_ptr: png_structp): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_compression_buffer_size: procedure(png_ptr: png_structp; size: png_uint_32);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_reset_zstream: function(png_ptr: png_structp): longint;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_chunk: procedure(png_ptr: png_structp; chunk_name: png_bytep; data: png_bytep; length: png_size_t);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_chunk_start: procedure(png_ptr: png_structp; chunk_name: png_bytep; length: png_uint_32);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_chunk_data: procedure(png_ptr: png_structp; data: png_bytep; length: png_size_t);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_chunk_end: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_create_info_struct: function(png_ptr: png_structp): png_infop;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_info_init: procedure(info_ptr: png_infop);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_info_before_PLTE: procedure(png_ptr: png_structp; info_ptr: png_infop);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_info: procedure(png_ptr: png_structp; info_ptr: png_infop);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_read_info: procedure(png_ptr: png_structp; info_ptr: png_infop);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_convert_to_rfc1123: function(png_ptr: png_structp; ptime: png_timep): png_charp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_convert_from_struct_tm: procedure(ptime: png_timep; ttime: Pointer);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_convert_from_time_t: procedure(ptime: png_timep; ttime: time_t);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_expand: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_gray_1_2_4_to_8: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_palette_to_rgb: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_tRNS_to_alpha: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_bgr: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_gray_to_rgb: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_rgb_to_gray: procedure(png_ptr: png_structp; error_action: longint; red: double; green: double);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_rgb_to_gray_fixed: procedure(png_ptr: png_structp; error_action: longint; red: png_fixed_point; green: png_fixed_point);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_rgb_to_gray_status: function(png_ptr: png_structp): png_byte;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_build_grayscale_palette: procedure(bit_depth: longint; palette: png_colorp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_strip_alpha: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_swap_alpha: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_invert_alpha: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_filler: procedure(png_ptr: png_structp; filler: png_uint_32; flags: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_swap: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_packing: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_packswap: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_shift: procedure(png_ptr: png_structp; true_bits: png_color_8p);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_interlace_handling: function(png_ptr: png_structp): longint;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_invert_mono: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_background: procedure(png_ptr: png_structp; background_color: png_color_16p; background_gamma_code: longint; need_expand: longint; background_gamma: double);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_strip_16: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_dither: procedure(png_ptr: png_structp; palette: png_colorp; num_palette: longint; maximum_colors: longint; histogram: png_uint_16p;
            full_dither: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_gamma: procedure(png_ptr: png_structp; screen_gamma: double; default_file_gamma: double);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_permit_empty_plte: procedure(png_ptr: png_structp; empty_plte_permitted: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_flush: procedure(png_ptr: png_structp; nrows: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_flush: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_start_read_image: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_read_update_info: procedure(png_ptr: png_structp; info_ptr: png_infop);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_read_rows: procedure(png_ptr: png_structp; row: png_bytepp; display_row: png_bytepp; num_rows: png_uint_32);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_read_row: procedure(png_ptr: png_structp; row: png_bytep; display_row: png_bytep);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_read_image: procedure(png_ptr: png_structp; image: png_bytepp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_row: procedure(png_ptr: png_structp; row: png_bytep);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_rows: procedure(png_ptr: png_structp; row: png_bytepp; num_rows: png_uint_32);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_image: procedure(png_ptr: png_structp; image: png_bytepp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_end: procedure(png_ptr: png_structp; info_ptr: png_infop);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_read_end: procedure(png_ptr: png_structp; info_ptr: png_infop);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_destroy_info_struct: procedure(png_ptr: png_structp; info_ptr_ptr: png_infopp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_destroy_read_struct: procedure(png_ptr_ptr: png_structpp; info_ptr_ptr: png_infopp; end_info_ptr_ptr: png_infopp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
(* Commented out by Kambi,
   this is obsolete and not present in libpng so/dll:
  png_read_destroy: procedure(png_ptr: png_structp; info_ptr: png_infop; end_info_ptr: png_infop);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
*)
  png_destroy_write_struct: procedure(png_ptr_ptr: png_structpp; info_ptr_ptr: png_infopp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
(* Commented out by Kambi,
   those are obsolete and not present in libpng so/dll:

  png_write_destroy_info: procedure(info_ptr: png_infop);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_destroy: procedure(png_ptr: png_structp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
*)
  png_set_crc_action: procedure(png_ptr: png_structp; crit_action: longint; ancil_action: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_filter: procedure(png_ptr: png_structp; method: longint; filters: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_filter_heuristics: procedure(png_ptr: png_structp; heuristic_method: longint; num_weights: longint; filter_weights: png_doublep; filter_costs: png_doublep);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_compression_level: procedure(png_ptr: png_structp; level: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_compression_mem_level: procedure(png_ptr: png_structp; mem_level: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_compression_strategy: procedure(png_ptr: png_structp; strategy: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_compression_window_bits: procedure(png_ptr: png_structp; window_bits: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_compression_method: procedure(png_ptr: png_structp; method: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_init_io: procedure(png_ptr: png_structp; fp: png_FILE_p);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_error_fn: procedure(png_ptr: png_structp; error_ptr: png_voidp; error_fn: png_error_ptr; warning_fn: png_error_ptr);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_error_ptr: function(png_ptr: png_structp): png_voidp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_write_fn: procedure(png_ptr: png_structp; io_ptr: png_voidp; write_data_fn: png_rw_ptr; output_flush_fn: png_flush_ptr);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_read_fn: procedure(png_ptr: png_structp; io_ptr: png_voidp; read_data_fn: png_rw_ptr);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_io_ptr: function(png_ptr: png_structp): png_voidp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_read_status_fn: procedure(png_ptr: png_structp; read_row_fn: png_read_status_ptr);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_write_status_fn: procedure(png_ptr: png_structp; write_row_fn: png_write_status_ptr);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_read_user_transform_fn: procedure(png_ptr: png_structp; read_user_transform_fn: png_user_transform_ptr);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_write_user_transform_fn: procedure(png_ptr: png_structp; write_user_transform_fn: png_user_transform_ptr);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_user_transform_info: procedure(png_ptr: png_structp; user_transform_ptr: png_voidp; user_transform_depth: longint; user_transform_channels: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_user_transform_ptr: function(png_ptr: png_structp): png_voidp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_read_user_chunk_fn: procedure(png_ptr: png_structp; user_chunk_ptr: png_voidp; read_user_chunk_fn: png_user_chunk_ptr);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_user_chunk_ptr: function(png_ptr: png_structp): png_voidp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_progressive_read_fn: procedure(png_ptr: png_structp; progressive_ptr: png_voidp; info_fn: png_progressive_info_ptr; row_fn: png_progressive_row_ptr; end_fn: png_progressive_end_ptr);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_progressive_ptr: function(png_ptr: png_structp): png_voidp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_process_data: procedure(png_ptr: png_structp; info_ptr: png_infop; buffer: png_bytep; buffer_size: png_size_t);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_progressive_combine_row: procedure(png_ptr: png_structp; old_row: png_bytep; new_row: png_bytep);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_malloc: function(png_ptr: png_structp; size: png_uint_32): png_voidp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_free: procedure(png_ptr: png_structp; ptr: png_voidp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_free_data: procedure(png_ptr: png_structp; info_ptr: png_infop; free_me: png_uint_32; num: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_data_freer: procedure(png_ptr: png_structp; info_ptr: png_infop; freer: longint; mask: png_uint_32);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_memcpy_check: function(png_ptr: png_structp; s1: png_voidp; s2: png_voidp; size: png_uint_32): png_voidp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_memset_check: function(png_ptr: png_structp; s1: png_voidp; value: longint; size: png_uint_32): png_voidp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_error: procedure(png_ptr: png_structp; error: png_const_charp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_chunk_error: procedure(png_ptr: png_structp; error: png_const_charp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_warning: procedure(png_ptr: png_structp; message: png_const_charp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_chunk_warning: procedure(png_ptr: png_structp; message: png_const_charp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_valid: function(png_ptr: png_structp; info_ptr: png_infop; flag: png_uint_32): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_rowbytes: function(png_ptr: png_structp; info_ptr: png_infop): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_rows: function(png_ptr: png_structp; info_ptr: png_infop): png_bytepp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_rows: procedure(png_ptr: png_structp; info_ptr: png_infop; row_pointers: png_bytepp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_channels: function(png_ptr: png_structp; info_ptr: png_infop): png_byte;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_image_width: function(png_ptr: png_structp; info_ptr: png_infop): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_image_height: function(png_ptr: png_structp; info_ptr: png_infop): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_bit_depth: function(png_ptr: png_structp; info_ptr: png_infop): png_byte;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_color_type: function(png_ptr: png_structp; info_ptr: png_infop): png_byte;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_filter_type: function(png_ptr: png_structp; info_ptr: png_infop): png_byte;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_interlace_type: function(png_ptr: png_structp; info_ptr: png_infop): png_byte;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_compression_type: function(png_ptr: png_structp; info_ptr: png_infop): png_byte;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_pixels_per_meter: function(png_ptr: png_structp; info_ptr: png_infop): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_x_pixels_per_meter: function(png_ptr: png_structp; info_ptr: png_infop): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_y_pixels_per_meter: function(png_ptr: png_structp; info_ptr: png_infop): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_pixel_aspect_ratio: function(png_ptr: png_structp; info_ptr: png_infop): double;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_x_offset_pixels: function(png_ptr: png_structp; info_ptr: png_infop): png_int_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_y_offset_pixels: function(png_ptr: png_structp; info_ptr: png_infop): png_int_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_x_offset_microns: function(png_ptr: png_structp; info_ptr: png_infop): png_int_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_y_offset_microns: function(png_ptr: png_structp; info_ptr: png_infop): png_int_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_signature: function(png_ptr: png_structp; info_ptr: png_infop): png_bytep;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_bKGD: function(png_ptr: png_structp; info_ptr: png_infop; background: Ppng_color_16p): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_bKGD: procedure(png_ptr: png_structp; info_ptr: png_infop; background: png_color_16p);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_cHRM: function(png_ptr: png_structp; info_ptr: png_infop; white_x: Pdouble; white_y: Pdouble; red_x: Pdouble;
           red_y: Pdouble; green_x: Pdouble; green_y: Pdouble; blue_x: Pdouble; blue_y: Pdouble): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_cHRM_fixed: function(png_ptr: png_structp; info_ptr: png_infop; int_white_x: Ppng_fixed_point; int_white_y: Ppng_fixed_point; int_red_x: Ppng_fixed_point;
           int_red_y: Ppng_fixed_point; int_green_x: Ppng_fixed_point; int_green_y: Ppng_fixed_point; int_blue_x: Ppng_fixed_point; int_blue_y: Ppng_fixed_point): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_cHRM: procedure(png_ptr: png_structp; info_ptr: png_infop; white_x: double; white_y: double; red_x: double;
            red_y: double; green_x: double; green_y: double; blue_x: double; blue_y: double);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_cHRM_fixed: procedure(png_ptr: png_structp; info_ptr: png_infop; int_white_x: png_fixed_point; int_white_y: png_fixed_point; int_red_x: png_fixed_point;
            int_red_y: png_fixed_point; int_green_x: png_fixed_point; int_green_y: png_fixed_point; int_blue_x: png_fixed_point; int_blue_y: png_fixed_point);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_gAMA: function(png_ptr: png_structp; info_ptr: png_infop; file_gamma: Pdouble): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_gAMA_fixed: function(png_ptr: png_structp; info_ptr: png_infop; int_file_gamma: Ppng_fixed_point): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_gAMA: procedure(png_ptr: png_structp; info_ptr: png_infop; file_gamma: double);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_gAMA_fixed: procedure(png_ptr: png_structp; info_ptr: png_infop; int_file_gamma: png_fixed_point);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_hIST: function(png_ptr: png_structp; info_ptr: png_infop; hist: Ppng_uint_16p): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_hIST: procedure(png_ptr: png_structp; info_ptr: png_infop; hist: png_uint_16p);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_IHDR: function(png_ptr: png_structp; info_ptr: png_infop; width: Ppng_uint_32; height: Ppng_uint_32; bit_depth: Plongint;
           color_type: Plongint; interlace_type: Plongint; compression_type: Plongint; filter_type: Plongint): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_IHDR: procedure(png_ptr: png_structp; info_ptr: png_infop; width: png_uint_32; height: png_uint_32; bit_depth: longint;
            color_type: longint; interlace_type: longint; compression_type: longint; filter_type: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_oFFs: function(png_ptr: png_structp; info_ptr: png_infop; offset_x: Ppng_int_32; offset_y: Ppng_int_32; unit_type: Plongint): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_oFFs: procedure(png_ptr: png_structp; info_ptr: png_infop; offset_x: png_int_32; offset_y: png_int_32; unit_type: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_pCAL: function(png_ptr: png_structp; info_ptr: png_infop; purpose: Ppng_charp; X0: Ppng_int_32; X1: Ppng_int_32;
           atype: Plongint; nparams: Plongint; units: Ppng_charp; params: Ppng_charpp): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_pCAL: procedure(png_ptr: png_structp; info_ptr: png_infop; purpose: png_charp; X0: png_int_32; X1: png_int_32;
            atype: longint; nparams: longint; units: png_charp; params: png_charpp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_pHYs: function(png_ptr: png_structp; info_ptr: png_infop; res_x: Ppng_uint_32; res_y: Ppng_uint_32; unit_type: Plongint): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_pHYs: procedure(png_ptr: png_structp; info_ptr: png_infop; res_x: png_uint_32; res_y: png_uint_32; unit_type: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_PLTE: function(png_ptr: png_structp; info_ptr: png_infop; palette: Ppng_colorp; num_palette: Plongint): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_PLTE: procedure(png_ptr: png_structp; info_ptr: png_infop; palette: png_colorp; num_palette: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_sBIT: function(png_ptr: png_structp; info_ptr: png_infop; sig_bit: Ppng_color_8p): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_sBIT: procedure(png_ptr: png_structp; info_ptr: png_infop; sig_bit: png_color_8p);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_sRGB: function(png_ptr: png_structp; info_ptr: png_infop; intent: Plongint): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_sRGB: procedure(png_ptr: png_structp; info_ptr: png_infop; intent: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_sRGB_gAMA_and_cHRM: procedure(png_ptr: png_structp; info_ptr: png_infop; intent: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_iCCP: function(png_ptr: png_structp; info_ptr: png_infop; name: png_charpp; compression_type: Plongint; profile: png_charpp;
           proflen: Ppng_uint_32): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_iCCP: procedure(png_ptr: png_structp; info_ptr: png_infop; name: png_charp; compression_type: longint; profile: png_charp;
            proflen: png_uint_32);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_sPLT: function(png_ptr: png_structp; info_ptr: png_infop; entries: png_sPLT_tpp): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_sPLT: procedure(png_ptr: png_structp; info_ptr: png_infop; entries: png_sPLT_tp; nentries: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_text: function(png_ptr: png_structp; info_ptr: png_infop; text_ptr: Ppng_textp; num_text: Plongint): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_text: procedure(png_ptr: png_structp; info_ptr: png_infop; text_ptr: png_textp; num_text: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_tIME: function(png_ptr: png_structp; info_ptr: png_infop; mod_time: Ppng_timep): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_tIME: procedure(png_ptr: png_structp; info_ptr: png_infop; mod_time: png_timep);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_tRNS: function(png_ptr: png_structp; info_ptr: png_infop; trans: Ppng_bytep; num_trans: Plongint; trans_values: Ppng_color_16p): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_tRNS: procedure(png_ptr: png_structp; info_ptr: png_infop; trans: png_bytep; num_trans: longint; trans_values: png_color_16p);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_sCAL: function(png_ptr: png_structp; info_ptr: png_infop; aunit: Plongint; width: Pdouble; height: Pdouble): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_sCAL: procedure(png_ptr: png_structp; info_ptr: png_infop; aunit: longint; width: double; height: double);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
(* Commented out by Kambi, not present in some libpng so/dll
  png_set_sCAL_s: procedure(png_ptr: png_structp; info_ptr: png_infop; aunit: longint; swidth: png_charp; sheight: png_charp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
*)
  png_set_keep_unknown_chunks: procedure(png_ptr: png_structp; keep: longint; chunk_list: png_bytep; num_chunks: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_unknown_chunks: procedure(png_ptr: png_structp; info_ptr: png_infop; unknowns: png_unknown_chunkp; num_unknowns: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_unknown_chunk_location: procedure(png_ptr: png_structp; info_ptr: png_infop; chunk: longint; location: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_unknown_chunks: function(png_ptr: png_structp; info_ptr: png_infop; entries: png_unknown_chunkpp): png_uint_32;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_set_invalid: procedure(png_ptr: png_structp; info_ptr: png_infop; mask: longint);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_read_png: procedure(png_ptr: png_structp; info_ptr: png_infop; transforms: longint; params: voidp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_write_png: procedure(png_ptr: png_structp; info_ptr: png_infop; transforms: longint; params: voidp);{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_header_ver: function(png_ptr: png_structp): png_charp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};
  png_get_header_version: function(png_ptr: png_structp): png_charp;{$ifndef LIBPNG_CDECL} stdcall {$else} cdecl {$endif};

{ This returns true if libpng was available and all png_xxx functions
  in this unit are inited to non-nil values, so you can just use libpng.

  It returns false if libpng library was not available (or maybe the required
  version was not available). Then all png_xxx functions in this unit are nil
  and you can't use them. }
function KambiPngInited: boolean;

implementation

uses SysUtils, KambiUtils;

var
  PngLibrary: TDynLib;
  FKambiPngInited: boolean;

function KambiPngInited: boolean;
begin
 Result := FKambiPngInited;
end;

initialization
 PngLibrary := TDynLib.Load(PngLibraryName, false);
 FKambiPngInited := PngLibrary <> nil;

 if FKambiPngInited then
 begin
  (* Note: at first I wrote it like
       {$ifdef FPC_OBJFPC} Pointer {$else} @ {$endif} (xxx)
     but unfortunately stupid Delphi doesn't get @(xxx) construct.
     I must use @xxx construct. *)
 
  {$ifdef FPC_OBJFPC} Pointer(png_access_version_number) {$else} @png_access_version_number {$endif} := PngLibrary.Symbol('png_access_version_number');
  {$ifdef FPC_OBJFPC} Pointer(png_set_sig_bytes) {$else} @png_set_sig_bytes {$endif} := PngLibrary.Symbol('png_set_sig_bytes');
  {$ifdef FPC_OBJFPC} Pointer(png_sig_cmp) {$else} @png_sig_cmp {$endif} := PngLibrary.Symbol('png_sig_cmp');
  {$ifdef FPC_OBJFPC} Pointer(png_check_sig) {$else} @png_check_sig {$endif} := PngLibrary.Symbol('png_check_sig');
  {$ifdef FPC_OBJFPC} Pointer(png_create_read_struct) {$else} @png_create_read_struct {$endif} := PngLibrary.Symbol('png_create_read_struct');
  {$ifdef FPC_OBJFPC} Pointer(png_create_write_struct) {$else} @png_create_write_struct {$endif} := PngLibrary.Symbol('png_create_write_struct');
  {$ifdef FPC_OBJFPC} Pointer(png_get_compression_buffer_size) {$else} @png_get_compression_buffer_size {$endif} := PngLibrary.Symbol('png_get_compression_buffer_size');
  {$ifdef FPC_OBJFPC} Pointer(png_set_compression_buffer_size) {$else} @png_set_compression_buffer_size {$endif} := PngLibrary.Symbol('png_set_compression_buffer_size');
  {$ifdef FPC_OBJFPC} Pointer(png_reset_zstream) {$else} @png_reset_zstream {$endif} := PngLibrary.Symbol('png_reset_zstream');
  {$ifdef FPC_OBJFPC} Pointer(png_write_chunk) {$else} @png_write_chunk {$endif} := PngLibrary.Symbol('png_write_chunk');
  {$ifdef FPC_OBJFPC} Pointer(png_write_chunk_start) {$else} @png_write_chunk_start {$endif} := PngLibrary.Symbol('png_write_chunk_start');
  {$ifdef FPC_OBJFPC} Pointer(png_write_chunk_data) {$else} @png_write_chunk_data {$endif} := PngLibrary.Symbol('png_write_chunk_data');
  {$ifdef FPC_OBJFPC} Pointer(png_write_chunk_end) {$else} @png_write_chunk_end {$endif} := PngLibrary.Symbol('png_write_chunk_end');
  {$ifdef FPC_OBJFPC} Pointer(png_create_info_struct) {$else} @png_create_info_struct {$endif} := PngLibrary.Symbol('png_create_info_struct');
  {$ifdef FPC_OBJFPC} Pointer(png_info_init) {$else} @png_info_init {$endif} := PngLibrary.Symbol('png_info_init');
  {$ifdef FPC_OBJFPC} Pointer(png_write_info_before_PLTE) {$else} @png_write_info_before_PLTE {$endif} := PngLibrary.Symbol('png_write_info_before_PLTE');
  {$ifdef FPC_OBJFPC} Pointer(png_write_info) {$else} @png_write_info {$endif} := PngLibrary.Symbol('png_write_info');
  {$ifdef FPC_OBJFPC} Pointer(png_read_info) {$else} @png_read_info {$endif} := PngLibrary.Symbol('png_read_info');
  {$ifdef FPC_OBJFPC} Pointer(png_convert_to_rfc1123) {$else} @png_convert_to_rfc1123 {$endif} := PngLibrary.Symbol('png_convert_to_rfc1123');
  {$ifdef FPC_OBJFPC} Pointer(png_convert_from_struct_tm) {$else} @png_convert_from_struct_tm {$endif} := PngLibrary.Symbol('png_convert_from_struct_tm');
  {$ifdef FPC_OBJFPC} Pointer(png_convert_from_time_t) {$else} @png_convert_from_time_t {$endif} := PngLibrary.Symbol('png_convert_from_time_t');
  {$ifdef FPC_OBJFPC} Pointer(png_set_expand) {$else} @png_set_expand {$endif} := PngLibrary.Symbol('png_set_expand');
  {$ifdef FPC_OBJFPC} Pointer(png_set_gray_1_2_4_to_8) {$else} @png_set_gray_1_2_4_to_8 {$endif} := PngLibrary.Symbol('png_set_gray_1_2_4_to_8');
  {$ifdef FPC_OBJFPC} Pointer(png_set_palette_to_rgb) {$else} @png_set_palette_to_rgb {$endif} := PngLibrary.Symbol('png_set_palette_to_rgb');
  {$ifdef FPC_OBJFPC} Pointer(png_set_tRNS_to_alpha) {$else} @png_set_tRNS_to_alpha {$endif} := PngLibrary.Symbol('png_set_tRNS_to_alpha');
  {$ifdef FPC_OBJFPC} Pointer(png_set_bgr) {$else} @png_set_bgr {$endif} := PngLibrary.Symbol('png_set_bgr');
  {$ifdef FPC_OBJFPC} Pointer(png_set_gray_to_rgb) {$else} @png_set_gray_to_rgb {$endif} := PngLibrary.Symbol('png_set_gray_to_rgb');
  {$ifdef FPC_OBJFPC} Pointer(png_set_rgb_to_gray) {$else} @png_set_rgb_to_gray {$endif} := PngLibrary.Symbol('png_set_rgb_to_gray');
  {$ifdef FPC_OBJFPC} Pointer(png_set_rgb_to_gray_fixed) {$else} @png_set_rgb_to_gray_fixed {$endif} := PngLibrary.Symbol('png_set_rgb_to_gray_fixed');
  {$ifdef FPC_OBJFPC} Pointer(png_get_rgb_to_gray_status) {$else} @png_get_rgb_to_gray_status {$endif} := PngLibrary.Symbol('png_get_rgb_to_gray_status');
  {$ifdef FPC_OBJFPC} Pointer(png_build_grayscale_palette) {$else} @png_build_grayscale_palette {$endif} := PngLibrary.Symbol('png_build_grayscale_palette');
  {$ifdef FPC_OBJFPC} Pointer(png_set_strip_alpha) {$else} @png_set_strip_alpha {$endif} := PngLibrary.Symbol('png_set_strip_alpha');
  {$ifdef FPC_OBJFPC} Pointer(png_set_swap_alpha) {$else} @png_set_swap_alpha {$endif} := PngLibrary.Symbol('png_set_swap_alpha');
  {$ifdef FPC_OBJFPC} Pointer(png_set_invert_alpha) {$else} @png_set_invert_alpha {$endif} := PngLibrary.Symbol('png_set_invert_alpha');
  {$ifdef FPC_OBJFPC} Pointer(png_set_filler) {$else} @png_set_filler {$endif} := PngLibrary.Symbol('png_set_filler');
  {$ifdef FPC_OBJFPC} Pointer(png_set_swap) {$else} @png_set_swap {$endif} := PngLibrary.Symbol('png_set_swap');
  {$ifdef FPC_OBJFPC} Pointer(png_set_packing) {$else} @png_set_packing {$endif} := PngLibrary.Symbol('png_set_packing');
  {$ifdef FPC_OBJFPC} Pointer(png_set_packswap) {$else} @png_set_packswap {$endif} := PngLibrary.Symbol('png_set_packswap');
  {$ifdef FPC_OBJFPC} Pointer(png_set_shift) {$else} @png_set_shift {$endif} := PngLibrary.Symbol('png_set_shift');
  {$ifdef FPC_OBJFPC} Pointer(png_set_interlace_handling) {$else} @png_set_interlace_handling {$endif} := PngLibrary.Symbol('png_set_interlace_handling');
  {$ifdef FPC_OBJFPC} Pointer(png_set_invert_mono) {$else} @png_set_invert_mono {$endif} := PngLibrary.Symbol('png_set_invert_mono');
  {$ifdef FPC_OBJFPC} Pointer(png_set_background) {$else} @png_set_background {$endif} := PngLibrary.Symbol('png_set_background');
  {$ifdef FPC_OBJFPC} Pointer(png_set_strip_16) {$else} @png_set_strip_16 {$endif} := PngLibrary.Symbol('png_set_strip_16');
  {$ifdef FPC_OBJFPC} Pointer(png_set_dither) {$else} @png_set_dither {$endif} := PngLibrary.Symbol('png_set_dither');
  {$ifdef FPC_OBJFPC} Pointer(png_set_gamma) {$else} @png_set_gamma {$endif} := PngLibrary.Symbol('png_set_gamma');
  {$ifdef FPC_OBJFPC} Pointer(png_permit_empty_plte) {$else} @png_permit_empty_plte {$endif} := PngLibrary.Symbol('png_permit_empty_plte');
  {$ifdef FPC_OBJFPC} Pointer(png_set_flush) {$else} @png_set_flush {$endif} := PngLibrary.Symbol('png_set_flush');
  {$ifdef FPC_OBJFPC} Pointer(png_write_flush) {$else} @png_write_flush {$endif} := PngLibrary.Symbol('png_write_flush');
  {$ifdef FPC_OBJFPC} Pointer(png_start_read_image) {$else} @png_start_read_image {$endif} := PngLibrary.Symbol('png_start_read_image');
  {$ifdef FPC_OBJFPC} Pointer(png_read_update_info) {$else} @png_read_update_info {$endif} := PngLibrary.Symbol('png_read_update_info');
  {$ifdef FPC_OBJFPC} Pointer(png_read_rows) {$else} @png_read_rows {$endif} := PngLibrary.Symbol('png_read_rows');
  {$ifdef FPC_OBJFPC} Pointer(png_read_row) {$else} @png_read_row {$endif} := PngLibrary.Symbol('png_read_row');
  {$ifdef FPC_OBJFPC} Pointer(png_read_image) {$else} @png_read_image {$endif} := PngLibrary.Symbol('png_read_image');
  {$ifdef FPC_OBJFPC} Pointer(png_write_row) {$else} @png_write_row {$endif} := PngLibrary.Symbol('png_write_row');
  {$ifdef FPC_OBJFPC} Pointer(png_write_rows) {$else} @png_write_rows {$endif} := PngLibrary.Symbol('png_write_rows');
  {$ifdef FPC_OBJFPC} Pointer(png_write_image) {$else} @png_write_image {$endif} := PngLibrary.Symbol('png_write_image');
  {$ifdef FPC_OBJFPC} Pointer(png_write_end) {$else} @png_write_end {$endif} := PngLibrary.Symbol('png_write_end');
  {$ifdef FPC_OBJFPC} Pointer(png_read_end) {$else} @png_read_end {$endif} := PngLibrary.Symbol('png_read_end');
  {$ifdef FPC_OBJFPC} Pointer(png_destroy_info_struct) {$else} @png_destroy_info_struct {$endif} := PngLibrary.Symbol('png_destroy_info_struct');
  {$ifdef FPC_OBJFPC} Pointer(png_destroy_read_struct) {$else} @png_destroy_read_struct {$endif} := PngLibrary.Symbol('png_destroy_read_struct');
// {$ifdef FPC_OBJFPC} Pointer(png_read_destroy) {$else} @png_read_destroy {$endif} := PngLibrary.Symbol('png_read_destroy');
  {$ifdef FPC_OBJFPC} Pointer(png_destroy_write_struct) {$else} @png_destroy_write_struct {$endif} := PngLibrary.Symbol('png_destroy_write_struct');
// {$ifdef FPC_OBJFPC} Pointer(png_write_destroy_info) {$else} @png_write_destroy_info {$endif} := PngLibrary.Symbol('png_write_destroy_info');
// {$ifdef FPC_OBJFPC} Pointer(png_write_destroy) {$else} @png_write_destroy {$endif} := PngLibrary.Symbol('png_write_destroy');
  {$ifdef FPC_OBJFPC} Pointer(png_set_crc_action) {$else} @png_set_crc_action {$endif} := PngLibrary.Symbol('png_set_crc_action');
  {$ifdef FPC_OBJFPC} Pointer(png_set_filter) {$else} @png_set_filter {$endif} := PngLibrary.Symbol('png_set_filter');
  {$ifdef FPC_OBJFPC} Pointer(png_set_filter_heuristics) {$else} @png_set_filter_heuristics {$endif} := PngLibrary.Symbol('png_set_filter_heuristics');
  {$ifdef FPC_OBJFPC} Pointer(png_set_compression_level) {$else} @png_set_compression_level {$endif} := PngLibrary.Symbol('png_set_compression_level');
  {$ifdef FPC_OBJFPC} Pointer(png_set_compression_mem_level) {$else} @png_set_compression_mem_level {$endif} := PngLibrary.Symbol('png_set_compression_mem_level');
  {$ifdef FPC_OBJFPC} Pointer(png_set_compression_strategy) {$else} @png_set_compression_strategy {$endif} := PngLibrary.Symbol('png_set_compression_strategy');
  {$ifdef FPC_OBJFPC} Pointer(png_set_compression_window_bits) {$else} @png_set_compression_window_bits {$endif} := PngLibrary.Symbol('png_set_compression_window_bits');
  {$ifdef FPC_OBJFPC} Pointer(png_set_compression_method) {$else} @png_set_compression_method {$endif} := PngLibrary.Symbol('png_set_compression_method');
  {$ifdef FPC_OBJFPC} Pointer(png_init_io) {$else} @png_init_io {$endif} := PngLibrary.Symbol('png_init_io');
  {$ifdef FPC_OBJFPC} Pointer(png_set_error_fn) {$else} @png_set_error_fn {$endif} := PngLibrary.Symbol('png_set_error_fn');
  {$ifdef FPC_OBJFPC} Pointer(png_get_error_ptr) {$else} @png_get_error_ptr {$endif} := PngLibrary.Symbol('png_get_error_ptr');
  {$ifdef FPC_OBJFPC} Pointer(png_set_write_fn) {$else} @png_set_write_fn {$endif} := PngLibrary.Symbol('png_set_write_fn');
  {$ifdef FPC_OBJFPC} Pointer(png_set_read_fn) {$else} @png_set_read_fn {$endif} := PngLibrary.Symbol('png_set_read_fn');
  {$ifdef FPC_OBJFPC} Pointer(png_get_io_ptr) {$else} @png_get_io_ptr {$endif} := PngLibrary.Symbol('png_get_io_ptr');
  {$ifdef FPC_OBJFPC} Pointer(png_set_read_status_fn) {$else} @png_set_read_status_fn {$endif} := PngLibrary.Symbol('png_set_read_status_fn');
  {$ifdef FPC_OBJFPC} Pointer(png_set_write_status_fn) {$else} @png_set_write_status_fn {$endif} := PngLibrary.Symbol('png_set_write_status_fn');
  {$ifdef FPC_OBJFPC} Pointer(png_set_read_user_transform_fn) {$else} @png_set_read_user_transform_fn {$endif} := PngLibrary.Symbol('png_set_read_user_transform_fn');
  {$ifdef FPC_OBJFPC} Pointer(png_set_write_user_transform_fn) {$else} @png_set_write_user_transform_fn {$endif} := PngLibrary.Symbol('png_set_write_user_transform_fn');
  {$ifdef FPC_OBJFPC} Pointer(png_set_user_transform_info) {$else} @png_set_user_transform_info {$endif} := PngLibrary.Symbol('png_set_user_transform_info');
  {$ifdef FPC_OBJFPC} Pointer(png_get_user_transform_ptr) {$else} @png_get_user_transform_ptr {$endif} := PngLibrary.Symbol('png_get_user_transform_ptr');
  {$ifdef FPC_OBJFPC} Pointer(png_set_read_user_chunk_fn) {$else} @png_set_read_user_chunk_fn {$endif} := PngLibrary.Symbol('png_set_read_user_chunk_fn');
  {$ifdef FPC_OBJFPC} Pointer(png_get_user_chunk_ptr) {$else} @png_get_user_chunk_ptr {$endif} := PngLibrary.Symbol('png_get_user_chunk_ptr');
  {$ifdef FPC_OBJFPC} Pointer(png_set_progressive_read_fn) {$else} @png_set_progressive_read_fn {$endif} := PngLibrary.Symbol('png_set_progressive_read_fn');
  {$ifdef FPC_OBJFPC} Pointer(png_get_progressive_ptr) {$else} @png_get_progressive_ptr {$endif} := PngLibrary.Symbol('png_get_progressive_ptr');
  {$ifdef FPC_OBJFPC} Pointer(png_process_data) {$else} @png_process_data {$endif} := PngLibrary.Symbol('png_process_data');
  {$ifdef FPC_OBJFPC} Pointer(png_progressive_combine_row) {$else} @png_progressive_combine_row {$endif} := PngLibrary.Symbol('png_progressive_combine_row');
  {$ifdef FPC_OBJFPC} Pointer(png_malloc) {$else} @png_malloc {$endif} := PngLibrary.Symbol('png_malloc');
  {$ifdef FPC_OBJFPC} Pointer(png_free) {$else} @png_free {$endif} := PngLibrary.Symbol('png_free');
  {$ifdef FPC_OBJFPC} Pointer(png_free_data) {$else} @png_free_data {$endif} := PngLibrary.Symbol('png_free_data');
  {$ifdef FPC_OBJFPC} Pointer(png_data_freer) {$else} @png_data_freer {$endif} := PngLibrary.Symbol('png_data_freer');
  {$ifdef FPC_OBJFPC} Pointer(png_memcpy_check) {$else} @png_memcpy_check {$endif} := PngLibrary.Symbol('png_memcpy_check');
  {$ifdef FPC_OBJFPC} Pointer(png_memset_check) {$else} @png_memset_check {$endif} := PngLibrary.Symbol('png_memset_check');
  {$ifdef FPC_OBJFPC} Pointer(png_error) {$else} @png_error {$endif} := PngLibrary.Symbol('png_error');
  {$ifdef FPC_OBJFPC} Pointer(png_chunk_error) {$else} @png_chunk_error {$endif} := PngLibrary.Symbol('png_chunk_error');
  {$ifdef FPC_OBJFPC} Pointer(png_warning) {$else} @png_warning {$endif} := PngLibrary.Symbol('png_warning');
  {$ifdef FPC_OBJFPC} Pointer(png_chunk_warning) {$else} @png_chunk_warning {$endif} := PngLibrary.Symbol('png_chunk_warning');
  {$ifdef FPC_OBJFPC} Pointer(png_get_valid) {$else} @png_get_valid {$endif} := PngLibrary.Symbol('png_get_valid');
  {$ifdef FPC_OBJFPC} Pointer(png_get_rowbytes) {$else} @png_get_rowbytes {$endif} := PngLibrary.Symbol('png_get_rowbytes');
  {$ifdef FPC_OBJFPC} Pointer(png_get_rows) {$else} @png_get_rows {$endif} := PngLibrary.Symbol('png_get_rows');
  {$ifdef FPC_OBJFPC} Pointer(png_set_rows) {$else} @png_set_rows {$endif} := PngLibrary.Symbol('png_set_rows');
  {$ifdef FPC_OBJFPC} Pointer(png_get_channels) {$else} @png_get_channels {$endif} := PngLibrary.Symbol('png_get_channels');
  {$ifdef FPC_OBJFPC} Pointer(png_get_image_width) {$else} @png_get_image_width {$endif} := PngLibrary.Symbol('png_get_image_width');
  {$ifdef FPC_OBJFPC} Pointer(png_get_image_height) {$else} @png_get_image_height {$endif} := PngLibrary.Symbol('png_get_image_height');
  {$ifdef FPC_OBJFPC} Pointer(png_get_bit_depth) {$else} @png_get_bit_depth {$endif} := PngLibrary.Symbol('png_get_bit_depth');
  {$ifdef FPC_OBJFPC} Pointer(png_get_color_type) {$else} @png_get_color_type {$endif} := PngLibrary.Symbol('png_get_color_type');
  {$ifdef FPC_OBJFPC} Pointer(png_get_filter_type) {$else} @png_get_filter_type {$endif} := PngLibrary.Symbol('png_get_filter_type');
  {$ifdef FPC_OBJFPC} Pointer(png_get_interlace_type) {$else} @png_get_interlace_type {$endif} := PngLibrary.Symbol('png_get_interlace_type');
  {$ifdef FPC_OBJFPC} Pointer(png_get_compression_type) {$else} @png_get_compression_type {$endif} := PngLibrary.Symbol('png_get_compression_type');
  {$ifdef FPC_OBJFPC} Pointer(png_get_pixels_per_meter) {$else} @png_get_pixels_per_meter {$endif} := PngLibrary.Symbol('png_get_pixels_per_meter');
  {$ifdef FPC_OBJFPC} Pointer(png_get_x_pixels_per_meter) {$else} @png_get_x_pixels_per_meter {$endif} := PngLibrary.Symbol('png_get_x_pixels_per_meter');
  {$ifdef FPC_OBJFPC} Pointer(png_get_y_pixels_per_meter) {$else} @png_get_y_pixels_per_meter {$endif} := PngLibrary.Symbol('png_get_y_pixels_per_meter');
  {$ifdef FPC_OBJFPC} Pointer(png_get_pixel_aspect_ratio) {$else} @png_get_pixel_aspect_ratio {$endif} := PngLibrary.Symbol('png_get_pixel_aspect_ratio');
  {$ifdef FPC_OBJFPC} Pointer(png_get_x_offset_pixels) {$else} @png_get_x_offset_pixels {$endif} := PngLibrary.Symbol('png_get_x_offset_pixels');
  {$ifdef FPC_OBJFPC} Pointer(png_get_y_offset_pixels) {$else} @png_get_y_offset_pixels {$endif} := PngLibrary.Symbol('png_get_y_offset_pixels');
  {$ifdef FPC_OBJFPC} Pointer(png_get_x_offset_microns) {$else} @png_get_x_offset_microns {$endif} := PngLibrary.Symbol('png_get_x_offset_microns');
  {$ifdef FPC_OBJFPC} Pointer(png_get_y_offset_microns) {$else} @png_get_y_offset_microns {$endif} := PngLibrary.Symbol('png_get_y_offset_microns');
  {$ifdef FPC_OBJFPC} Pointer(png_get_signature) {$else} @png_get_signature {$endif} := PngLibrary.Symbol('png_get_signature');
  {$ifdef FPC_OBJFPC} Pointer(png_get_bKGD) {$else} @png_get_bKGD {$endif} := PngLibrary.Symbol('png_get_bKGD');
  {$ifdef FPC_OBJFPC} Pointer(png_set_bKGD) {$else} @png_set_bKGD {$endif} := PngLibrary.Symbol('png_set_bKGD');
  {$ifdef FPC_OBJFPC} Pointer(png_get_cHRM) {$else} @png_get_cHRM {$endif} := PngLibrary.Symbol('png_get_cHRM');
  {$ifdef FPC_OBJFPC} Pointer(png_get_cHRM_fixed) {$else} @png_get_cHRM_fixed {$endif} := PngLibrary.Symbol('png_get_cHRM_fixed');
  {$ifdef FPC_OBJFPC} Pointer(png_set_cHRM) {$else} @png_set_cHRM {$endif} := PngLibrary.Symbol('png_set_cHRM');
  {$ifdef FPC_OBJFPC} Pointer(png_set_cHRM_fixed) {$else} @png_set_cHRM_fixed {$endif} := PngLibrary.Symbol('png_set_cHRM_fixed');
  {$ifdef FPC_OBJFPC} Pointer(png_get_gAMA) {$else} @png_get_gAMA {$endif} := PngLibrary.Symbol('png_get_gAMA');
  {$ifdef FPC_OBJFPC} Pointer(png_get_gAMA_fixed) {$else} @png_get_gAMA_fixed {$endif} := PngLibrary.Symbol('png_get_gAMA_fixed');
  {$ifdef FPC_OBJFPC} Pointer(png_set_gAMA) {$else} @png_set_gAMA {$endif} := PngLibrary.Symbol('png_set_gAMA');
  {$ifdef FPC_OBJFPC} Pointer(png_set_gAMA_fixed) {$else} @png_set_gAMA_fixed {$endif} := PngLibrary.Symbol('png_set_gAMA_fixed');
  {$ifdef FPC_OBJFPC} Pointer(png_get_hIST) {$else} @png_get_hIST {$endif} := PngLibrary.Symbol('png_get_hIST');
  {$ifdef FPC_OBJFPC} Pointer(png_set_hIST) {$else} @png_set_hIST {$endif} := PngLibrary.Symbol('png_set_hIST');
  {$ifdef FPC_OBJFPC} Pointer(png_get_IHDR) {$else} @png_get_IHDR {$endif} := PngLibrary.Symbol('png_get_IHDR');
  {$ifdef FPC_OBJFPC} Pointer(png_set_IHDR) {$else} @png_set_IHDR {$endif} := PngLibrary.Symbol('png_set_IHDR');
  {$ifdef FPC_OBJFPC} Pointer(png_get_oFFs) {$else} @png_get_oFFs {$endif} := PngLibrary.Symbol('png_get_oFFs');
  {$ifdef FPC_OBJFPC} Pointer(png_set_oFFs) {$else} @png_set_oFFs {$endif} := PngLibrary.Symbol('png_set_oFFs');
  {$ifdef FPC_OBJFPC} Pointer(png_get_pCAL) {$else} @png_get_pCAL {$endif} := PngLibrary.Symbol('png_get_pCAL');
  {$ifdef FPC_OBJFPC} Pointer(png_set_pCAL) {$else} @png_set_pCAL {$endif} := PngLibrary.Symbol('png_set_pCAL');
  {$ifdef FPC_OBJFPC} Pointer(png_get_pHYs) {$else} @png_get_pHYs {$endif} := PngLibrary.Symbol('png_get_pHYs');
  {$ifdef FPC_OBJFPC} Pointer(png_set_pHYs) {$else} @png_set_pHYs {$endif} := PngLibrary.Symbol('png_set_pHYs');
  {$ifdef FPC_OBJFPC} Pointer(png_get_PLTE) {$else} @png_get_PLTE {$endif} := PngLibrary.Symbol('png_get_PLTE');
  {$ifdef FPC_OBJFPC} Pointer(png_set_PLTE) {$else} @png_set_PLTE {$endif} := PngLibrary.Symbol('png_set_PLTE');
  {$ifdef FPC_OBJFPC} Pointer(png_get_sBIT) {$else} @png_get_sBIT {$endif} := PngLibrary.Symbol('png_get_sBIT');
  {$ifdef FPC_OBJFPC} Pointer(png_set_sBIT) {$else} @png_set_sBIT {$endif} := PngLibrary.Symbol('png_set_sBIT');
  {$ifdef FPC_OBJFPC} Pointer(png_get_sRGB) {$else} @png_get_sRGB {$endif} := PngLibrary.Symbol('png_get_sRGB');
  {$ifdef FPC_OBJFPC} Pointer(png_set_sRGB) {$else} @png_set_sRGB {$endif} := PngLibrary.Symbol('png_set_sRGB');
  {$ifdef FPC_OBJFPC} Pointer(png_set_sRGB_gAMA_and_cHRM) {$else} @png_set_sRGB_gAMA_and_cHRM {$endif} := PngLibrary.Symbol('png_set_sRGB_gAMA_and_cHRM');
  {$ifdef FPC_OBJFPC} Pointer(png_get_iCCP) {$else} @png_get_iCCP {$endif} := PngLibrary.Symbol('png_get_iCCP');
  {$ifdef FPC_OBJFPC} Pointer(png_set_iCCP) {$else} @png_set_iCCP {$endif} := PngLibrary.Symbol('png_set_iCCP');
  {$ifdef FPC_OBJFPC} Pointer(png_get_sPLT) {$else} @png_get_sPLT {$endif} := PngLibrary.Symbol('png_get_sPLT');
  {$ifdef FPC_OBJFPC} Pointer(png_set_sPLT) {$else} @png_set_sPLT {$endif} := PngLibrary.Symbol('png_set_sPLT');
  {$ifdef FPC_OBJFPC} Pointer(png_get_text) {$else} @png_get_text {$endif} := PngLibrary.Symbol('png_get_text');
  {$ifdef FPC_OBJFPC} Pointer(png_set_text) {$else} @png_set_text {$endif} := PngLibrary.Symbol('png_set_text');
  {$ifdef FPC_OBJFPC} Pointer(png_get_tIME) {$else} @png_get_tIME {$endif} := PngLibrary.Symbol('png_get_tIME');
  {$ifdef FPC_OBJFPC} Pointer(png_set_tIME) {$else} @png_set_tIME {$endif} := PngLibrary.Symbol('png_set_tIME');
  {$ifdef FPC_OBJFPC} Pointer(png_get_tRNS) {$else} @png_get_tRNS {$endif} := PngLibrary.Symbol('png_get_tRNS');
  {$ifdef FPC_OBJFPC} Pointer(png_set_tRNS) {$else} @png_set_tRNS {$endif} := PngLibrary.Symbol('png_set_tRNS');
  {$ifdef FPC_OBJFPC} Pointer(png_get_sCAL) {$else} @png_get_sCAL {$endif} := PngLibrary.Symbol('png_get_sCAL');
  {$ifdef FPC_OBJFPC} Pointer(png_set_sCAL) {$else} @png_set_sCAL {$endif} := PngLibrary.Symbol('png_set_sCAL');
// {$ifdef FPC_OBJFPC} Pointer(png_set_sCAL_s) {$else} @png_set_sCAL_s {$endif} := PngLibrary.Symbol('png_set_sCAL_s');
  {$ifdef FPC_OBJFPC} Pointer(png_set_keep_unknown_chunks) {$else} @png_set_keep_unknown_chunks {$endif} := PngLibrary.Symbol('png_set_keep_unknown_chunks');
  {$ifdef FPC_OBJFPC} Pointer(png_set_unknown_chunks) {$else} @png_set_unknown_chunks {$endif} := PngLibrary.Symbol('png_set_unknown_chunks');
  {$ifdef FPC_OBJFPC} Pointer(png_set_unknown_chunk_location) {$else} @png_set_unknown_chunk_location {$endif} := PngLibrary.Symbol('png_set_unknown_chunk_location');
  {$ifdef FPC_OBJFPC} Pointer(png_get_unknown_chunks) {$else} @png_get_unknown_chunks {$endif} := PngLibrary.Symbol('png_get_unknown_chunks');
  {$ifdef FPC_OBJFPC} Pointer(png_set_invalid) {$else} @png_set_invalid {$endif} := PngLibrary.Symbol('png_set_invalid');
  {$ifdef FPC_OBJFPC} Pointer(png_read_png) {$else} @png_read_png {$endif} := PngLibrary.Symbol('png_read_png');
  {$ifdef FPC_OBJFPC} Pointer(png_write_png) {$else} @png_write_png {$endif} := PngLibrary.Symbol('png_write_png');
  {$ifdef FPC_OBJFPC} Pointer(png_get_header_ver) {$else} @png_get_header_ver {$endif} := PngLibrary.Symbol('png_get_header_ver');
  {$ifdef FPC_OBJFPC} Pointer(png_get_header_version) {$else} @png_get_header_version {$endif} := PngLibrary.Symbol('png_get_header_version');
 end;
finalization
 FKambiPngInited := false;
 FreeAndNil(PngLibrary);
end.
