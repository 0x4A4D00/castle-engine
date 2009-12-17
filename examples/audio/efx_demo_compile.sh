#!/bin/bash
set -eu

# Hack to allow calling this script from it's dir.
if [ -f efx_demo.pasprogram ]; then
  cd ../../
fi

# Call this from ../../ (or just use `make examples').

fpc -dRELEASE @kambi.cfg examples/audio/efx_demo.pasprogram
