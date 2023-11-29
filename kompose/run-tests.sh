#!/usr/bin/env bash

set -euo pipefail;

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"
cd $SCRIPT_DIR

git checkout -- tests/results
for file in $(ls tests/a??-*.ncl); do
    echo "testing <$file> ..." 1>&2

    d=$(dirname $file)
    f=$(basename $file)
    mkdir -p "$d/results"
    ./render.sh $file > "$d/results/$f.yaml"
    #if [[ -n "$(git status --porcelain -- tests/results)" ]]; then
    #    echo "********* failed! **********"
    #    git diff -- tests/results
    #    exit 1
    #fi
    git diff -- tests/results
done
