#!/bin/sh
WOWDEV_ROOT="${WOWDEV_ROOT:-$(d="$(cd "$(dirname "$0")" && pwd)"; while [ "$d" != / ] && [ ! -d "$d/foreverdump" ]; do d="$(dirname "$d")"; done; echo "$d")}"  # portable root (handoff)
# forever.12: settings variants (KTH_SETTINGS = saved GUI values) on runs 16-19; port12 = defaults.
cd $WOWDEV_ROOT/kth
export FORE_DOCS=$WOWDEV_ROOT/foreverdump/ref/wusf/Interface/AddOns
run_v() { name=$1; st=$2
  for r in 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg 2026-10-10-run19-bg; do
    run=$(echo $r | grep -o 'run[0-9]*')
    KTH_SETTINGS="$st" lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua tests/results/$run.$name.json port >/dev/null || echo "FAIL $name $r"
  done; }
run_v port12          ""
run_v f12-explicit    "removeSharePct=35,meterMinHeal=1000,healsNeeded=2,elimEnabled=1,formTieEnabled=1,healerSharePct=60"
run_v f12-remove50    "removeSharePct=50"
run_v f12-remove80    "removeSharePct=80"
run_v f12-min3000     "meterMinHeal=3000"
run_v f12-min500      "meterMinHeal=500"
run_v f12-heals1      "healsNeeded=1"
run_v f12-heals4      "healsNeeded=4"
run_v f12-noelim      "elimEnabled=0"
run_v f12-noform      "formTieEnabled=0"
