#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"
export NICKEL_IMPORT_PATH=$SCRIPT_DIR


file="$1"

cat << EOF | kp export --format yaml
(import "module.ncl").render_all (import "$file")
EOF
