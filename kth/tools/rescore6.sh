#!/bin/sh
WOWDEV_ROOT="${WOWDEV_ROOT:-$(d="$(cd "$(dirname "$0")" && pwd)"; while [ "$d" != / ] && [ ! -d "$d/foreverdump" ]; do d="$(dirname "$d")"; done; echo "$d")}"  # portable root (handoff)
# forever.6 backtest variants on runs 16-18 (real boards + real meter snapshots). Thresholds via KTH_CFG only.
cd $WOWDEV_ROOT/kth
run_v() { name=$1; cfg=$2
  for r in 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg; do
    run=$(echo $r | grep -o 'run[0-9]*')
    KTH_CFG="$cfg" lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua tests/results/$run.$name.json port >/dev/null || echo "FAIL $name $r"
  done; }
run_v f6a-grp60      "grpSharePct=60,weakLinkMin=999"
run_v f6b-grp63      "weakLinkMin=999"
run_v f6c-grp70      "grpSharePct=70,weakLinkMin=999"
run_v f6d-weak2      "weakLinkMin=2"
run_v f6e-weak1-nocap "teamMax=99"
run_v port6          ""
