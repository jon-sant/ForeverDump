#!/bin/sh
WOWDEV_ROOT="${WOWDEV_ROOT:-$(d="$(cd "$(dirname "$0")" && pwd)"; while [ "$d" != / ] && [ ! -d "$d/foreverdump" ]; do d="$(dirname "$d")"; done; echo "$d")}"  # portable root (handoff)
# forever.5: replay runs 16-18 (real boards + real meter snapshots) through the original K.T.H., forever.3 and forever.5
# usage: tools/rescore5.sh <forever.3 tree> <original tree>
cd $WOWDEV_ROOT/kth
F3=${1:-/tmp/kth_f3}; ORIG=${2:-/tmp/kth_orig}
for r in 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg; do
  run=$(echo $r | grep -o 'run[0-9]*')
  lua5.1 tests/replay_score.lua $ORIG/KTH.toc tests/replay/$r.lua tests/results/$run.orig.json original-mn >/dev/null
  lua5.1 tests/replay_score.lua $F3/KTH.toc tests/replay/$r.lua tests/results/$run.port3.json port >/dev/null
  lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua tests/results/$run.port5.json port >/dev/null
  KTH_NO_METER=1 lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua tests/results/$run.port5-nometer.json port >/dev/null
done
