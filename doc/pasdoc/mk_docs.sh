#!/bin/bash
set -eu

# Generates docs for all units in kambi_vrml_game_engine/src.
# $1 is format (allowed values as for pasdoc's --format option),
# docs will be placed in subdirectory $1 of current dir
# so $1 means also subdirectory name.
#
# If you will not supply argument $2,
# then documentation for almost every unit in kambi_vrml_game_engine/src
# (without automatically generated fonts units
# and without units that pasdoc can't correctly parse)
# will be generated.
#
# Else documentation for units $2...${$#} (all these arguments
# should be filenames of units relative to $VRMLENGINE_UNITS_PATH
# directory) will be generated.
# E.g.: ./mk_docs.sh html audio/alutils.pas
# This is useful for quickly checking generated documentation
# for some particular unit, because generating documentation
# for all units takes a while.

# "os-native path" in this file means "under Windows it must
# *not* be Cygwin's POSIX path, because I pass it to pasdoc as filename".

# TARGET_OS is windows lub unix.
# This says which subdirectories of sources are meaningfull
# (e.g. add base/unix/ or base/windows/ to include file path ?).
# Moreover pasdoc will be run with --define $TARGET_OS.
TARGET_OS=unix

VRMLENGINE_UNITS_PATH=../../src/

# Autodetect if we're under Cygwin
if uname | grep --quiet -i cygwin; then
  KAMBI_IS_CYGWIN='t'
else
  KAMBI_IS_CYGWIN=''
fi

PASDOC_FORMAT="$1"
shift 1

# calculate OUTPUT_PATH (os-native path)
OUTPUT_PATH=`pwd`/
if [ -n "$KAMBI_IS_CYGWIN" ]; then
  OUTPUT_PATH="`cygpath --windows \"$OUTPUT_PATH\"`"
fi

# calculate PASDOC_CACHE (os-native path)
# I use --cache-dir with pasdoc, as this greatly speeds up generation
# of these docs.
#
# (However, this presents possibe threat, because cache timestamp is based
# on unit source file timestamp. So when some unit myunit.pas will include
# myinclude.inc then cache will NOT be updated when myinclude.inc file
# changes. So I'll have to remember to call `make clean-cache' here before
# regenerating docs.)
PASDOC_CACHE="${OUTPUT_PATH}cache/"
mkdir -p "$PASDOC_CACHE"

# finish calculating OUTPUT_PATH
OUTPUT_PATH="$OUTPUT_PATH""$PASDOC_FORMAT"/
mkdir -p "$OUTPUT_PATH"

cd "$VRMLENGINE_UNITS_PATH"

# calculate TMP_PAS_LIST (os-native path)
TMP_PAS_LIST=/tmp/mk_docs_list
if [ -n "$KAMBI_IS_CYGWIN" ]; then
  TMP_PAS_LIST="`cygpath --windows \"$TMP_PAS_LIST\"`"
fi

# make sure we have clean way to create "$TMP_PAS_LIST"
rm -f "$TMP_PAS_LIST"

# Now generate $TMP_PAS_LIST contents -- those are units we want to
# be documented by pasdoc.

if (( $# == 0 )); then
  # We don't generate docs for a lot of automatically generated units
  # TTF_Xxx and BFNT_Xxx, docs for these units would be useless.
  # (all these units have the same structure, after all).
  #
  # Don't generate docs for automatically generated AllKambi*Units units,
  # they should not be used in any program (they are only to simplify
  # compilation).
  #
  # Don't generate docs for units created only for example programs.
  find .  \
    '(' -type d '(' -iname old -or \
                    -iname private \
                ')' -prune ')' -or \
    '(' -type f -iname '*.pas' \
            -not '(' \
              '(' -iwholename '*/imageslider_*.pas' ')' -or \
              '(' -iwholename '*/AllKambi*Units.pas' ')' -or \
              '(' -iwholename '*/opengl/x86_64/glext.pas' ')' -or \
              '(' -iwholename '*fonts/TTF_*.pas' ')' -or \
              '(' -iwholename '*fonts/BFNT_*.pas' ')' \
            ')' \
            -print ')' >> "$TMP_PAS_LIST"
else
  # Put all "$@" arguments in file "$TMP_PAS_LIST",
  # separated by newlines
  for FFF; do
    echo "$FFF" >> "$TMP_PAS_LIST"
  done
fi

PASDOC_INCLUDE_DIRS="\
  --include base/templates/\
  --include 3d/\
  --include 3d/opengl/\
  --include vrml/\
  --include vrml/opengl/\
  --include audio/\
  --include base/\
  --include base/$TARGET_OS/\
  --include fonts/
  --include fonts/$TARGET_OS/\
  --include images/\
  --include opengl/\
  --include opengl/$TARGET_OS/\
  --include glwindow/\
  --include glwindow/$TARGET_OS/\
  --include glwindow/gtk/\
  --include kambiscript/\
"

pasdoc \
   --format "$PASDOC_FORMAT" \
  $PASDOC_INCLUDE_DIRS --output "$OUTPUT_PATH" \
  --define "$TARGET_OS" \
  --define FPC --define VER2 --define VER2_0 --define VER2_0_4 \
  --write-uses-list --title "Kambi VRML game engine" \
  --source "$TMP_PAS_LIST" \
  --cache-dir "$PASDOC_CACHE" \
  --auto-abstract \
  --introduction=../doc/pasdoc/introduction.pasdoc \
  --auto-link \
  --auto-link-exclude=../doc/pasdoc/auto_link_exclude.txt \
  --external-class-hierarchy=../doc/pasdoc/external_class_hierarchy.txt

#  \
# --graphviz-classes --link-gv-classes jpg \
# --graphviz-uses    --link-gv-uses    jpg

# Useful to find new items for auto_link_exclude.txt:
# grep for "Automatically linked identifier", remove duplicates,
# and see which ones shouldn't be autolinked.
# --verbosity=3

# Classes graph is too large, dot answers with
#   dot: width (135399 >= 32768) is too large.
# and then segfaults.
#dot -Tjpg -o"$OUTPUT_PATH"GVClasses.jpg "$OUTPUT_PATH"GVClasses.dot

# Units graph is possible, but still very large for human eye
# and so practically useless for us now...
#dot -Tjpg -o"$OUTPUT_PATH"GVUses.jpg    "$OUTPUT_PATH"GVUses.dot

# clean after ourselves
rm -f "$TMP_PAS_LIST"
