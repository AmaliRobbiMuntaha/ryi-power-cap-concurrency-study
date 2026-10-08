#!/bin/bash
set -euo pipefail

mkdir -p bin_svcomp
gcc -O3 -pthread cpu_melter_bug.c -o cpu_melter_bug -lm

echo ">> Compiling libpct.so (PCT Scheduler)"
gcc -shared -fPIC -O2 -o libpct.so pct_wrapper.c -ldl

echo ">> Done! The binary file is saved in the bin_svcomp/ folder."
