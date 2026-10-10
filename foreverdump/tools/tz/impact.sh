#!/bin/sh
WOWDEV_ROOT="${WOWDEV_ROOT:-$(d="$(cd "$(dirname "$0")" && pwd)"; while [ "$d" != / ] && [ ! -d "$d/foreverdump" ]; do d="$(dirname "$d")"; done; echo "$d")}"  # portable root (handoff)
# Time audit 2026-10-10: rerun every time-sensitive scorer under several TZ values; write per-TZ outputs to $OUT.
OUT=${OUT:-/tmp/tzimpact}; FD=$WOWDEV_ROOT/foreverdump; K=$WOWDEV_ROOT/kth
R19=$FD/real/2026-10-10-run19-bg; R20=$FD/real/2026-10-10-run20-dungeon
for tz in America/New_York UTC Asia/Kolkata Pacific/Chatham America/Los_Angeles Pacific/Kiritimati; do
  o=$OUT/$(echo $tz | tr / _); mkdir -p $o/replay
  cd $FD
  TZ=$tz python3 -m tools.fdump.aurapresence $R19/sv/ForeverDump.lua $R19/WoWCombatLog.txt $R19/out/truth.json --json $o/ap19.json >/dev/null || echo "FAIL ap19 $tz"
  TZ=$tz python3 -m tools.fdump.aurapresence $R20/sv/ForeverDump.lua $R20/WoWCombatLog.txt $R20/out/aurapresence/truth.json --json $o/ap20.json >/dev/null || echo "FAIL ap20 $tz"
  TZ=$tz python3 -m tools.fdump.pvescript $R20/sv/ForeverDump.lua $R20/WoWCombatLog.txt --mine Player-4618-00EB40D8 --json $o/pve20.json >/dev/null || echo "FAIL pve $tz"
  cd $K/tools
  TZ=$tz python3 export_replay.py $o/replay 2026-10-09-run10-bg 2026-10-09-run11-bg 2026-10-09-run12-bg 2026-10-09-run13-bg 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg 2026-10-10-run19-bg >$o/export.log 2>&1 || echo "FAIL export $tz"
done
