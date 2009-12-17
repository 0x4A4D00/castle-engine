#!/bin/bash
set -eu

# Hack to allow calling this script from it's dir.
if [ -f simplest_vrml_browser.pasprogram ]; then
  cd ../../../
fi

# Call this from ../../../ (or just use `make examples').

fpc -dRELEASE @kambi.cfg vrml/opengl/examples/simplest_vrml_browser.pasprogram
