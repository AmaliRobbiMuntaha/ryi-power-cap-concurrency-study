#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")"
gcc -O3 -pthread cpu_melter_bug.c -o cpu_melter_bug -lm
gcc -shared -fPIC -O2 -o libpct.so pct_wrapper.c -ldl
echo ">> Done"
