#!/bin/sh
# Full v2.2.4 converter pass over run 5 (outputs under real/2026-10-08-run5/out/). Run from the repo root.
set -e
R=real/2026-10-08-run5
SV=$R/sv/ForeverDump.lua
LOG=$R/WoWCombatLog.txt
F="python3 tools/fdump.py"
$F all $SV -o $R/out
$F coverage $SV --file $LOG -o $R/out/coverage
$F inference $SV --file $LOG -o $R/out/inference
$F knowledge $SV --file $LOG -o $R/out/knowledge
$F verify-live $SV --file $LOG -o $R/out/verify-live
$F analyze $SV --file $LOG --taint $R/taint.log --label run5 \
  --history run3=real/2026-10-07-run3/sv/ForeverDump.lua::real/2026-10-07-run3/WoWCombatLog.txt \
  --history run4=real/2026-10-07-run4/sv/ForeverDump.lua::real/2026-10-07-run4/WoWCombatLog.txt \
  -o $R/out/analysis
$F guide $SV --file $LOG -o $R/out/guide --analysis $R/out/analysis/analysis.json
