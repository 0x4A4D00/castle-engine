#!/bin/bash
set -eu

SF_USERNAME="$1"
SF_PATH="$2"

ssh "$SF_USERNAME",vrmlengine@shell.sourceforge.net create

ssh "$SF_USERNAME",vrmlengine@shell.sourceforge.net <<EOF
cd "$SF_PATH"
rm -Rf old/ new/ html/
tar xzvf html.tar.gz
EOF
