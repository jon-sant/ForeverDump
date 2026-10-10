#!/bin/sh
WOWDEV_ROOT="${WOWDEV_ROOT:-$(d="$(cd "$(dirname "$0")" && pwd)"; while [ "$d" != / ] && [ ! -d "$d/foreverdump" ]; do d="$(dirname "$d")"; done; echo "$d")}"  # portable root (handoff)
# forever.10 variants on runs 16-19 (truth v2). Thresholds/switches via KTH_CFG only.
cd $WOWDEV_ROOT/kth
run_v() { name=$1; cfg=$2
  for r in 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg 2026-10-10-run19-bg; do
    run=$(echo $r | grep -o 'run[0-9]*')
    KTH_CFG="$cfg" lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua tests/results/$run.$name.json port >/dev/null || echo "FAIL $name $r"
  done; }
run_v f10-off     "kWeak=0,elim=0,formTie=0,linkNet=0"
run_v f10-noelim  "elim=0"
run_v f10-noform  "formTie=0"
run_v f10-net2    "linkNet=2"
run_v f10-k60    "kSharePct=60"
run_v port10      ""
