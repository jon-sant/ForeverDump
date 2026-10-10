#!/bin/sh
WOWDEV_ROOT="${WOWDEV_ROOT:-$(d="$(cd "$(dirname "$0")" && pwd)"; while [ "$d" != / ] && [ ! -d "$d/foreverdump" ]; do d="$(dirname "$d")"; done; echo "$d")}"  # portable root (handoff)
# forever.11: settings variants (KTH_SETTINGS = the user's saved GUI values) on runs 16-19.
cd $WOWDEV_ROOT/kth
export FORE_DOCS=$WOWDEV_ROOT/foreverdump/ref/wusf/Interface/AddOns
run_v() { name=$1; st=$2
  for r in 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg 2026-10-10-run19-bg; do
    run=$(echo $r | grep -o 'run[0-9]*')
    KTH_SETTINGS="$st" lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua tests/results/$run.$name.json port >/dev/null || echo "FAIL $name $r"
  done; }
run_v port11          ""
run_v f11-g60-debugon  "healerSharePct=60,debug=1"
run_v f11-debugoff     "debug=0"
run_v f11-allov60      "healerSharePct=60,ov.PRIEST=60,ov.PALADIN=60,ov.DRUID=60,ov.SHAMAN=60,ov.PRIEST:Holy=60,ov.DRUID:Restoration=60"
run_v f11-g50          "healerSharePct=50"
run_v f11-g70          "healerSharePct=70"
run_v f11-priest80     "ov.PRIEST=80"
