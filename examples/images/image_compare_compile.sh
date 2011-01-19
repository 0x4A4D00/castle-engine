#!/bin/bash
set -eu

# Call this script from it's own directory,
# or from base kambi_vrml_game_engine directory.
# Or just do "make examples" in base kambi_vrml_game_engine directory.

# Allow calling this script from it's dir.
if [ -f image_compare.lpr ]; then cd ../../; fi

fpc -dRELEASE @kambi.cfg examples/images/image_compare.lpr
