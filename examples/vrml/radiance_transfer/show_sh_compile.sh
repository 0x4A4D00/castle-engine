#!/bin/bash
set -eu

# Hack to allow calling this script from it's dir.
if [ -f show_sh.pasprogram ]; then
  cd ../../../
fi

# Call this from ../../../ (or just use `make examples').

fpc -dRELEASE @kambi.cfg examples/vrml/radiance_transfer/show_sh.pasprogram
