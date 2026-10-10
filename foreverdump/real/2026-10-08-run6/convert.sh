#!/bin/sh
# Full v2.2.7 converter pass over run 6 (first in-game capture with v2.2.6). Run from the repo root.
set -e
R=real/2026-10-08-run6
SV=$R/sv/ForeverDump.lua
LOG=$R/WoWCombatLog.txt
F="python3 tools/fdump.py"
$F errors $SV --json $R/out/errors.json > $R/out/errors.txt
$F taint $R/taint.log -o $R/out/taint
$F replay $SV --file $LOG -o $R/out/replay
$F coverage $SV --file $LOG -o $R/out/coverage
$F inference $SV --file $LOG -o $R/out/inference
$F tokens $SV -o $R/out/tokens
$F perf $SV -o $R/out/perf
$F size $SV > $R/out/size.txt
$F analyze $SV --file $LOG --taint $R/taint.log --label run6 \
  --history run5=real/2026-10-08-run5/sv/ForeverDump.lua::real/2026-10-08-run5/WoWCombatLog.txt \
  -o $R/out/analysis
