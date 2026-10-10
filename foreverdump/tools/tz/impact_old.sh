#!/bin/sh
WOWDEV_ROOT="${WOWDEV_ROOT:-$(d="$(cd "$(dirname "$0")" && pwd)"; while [ "$d" != / ] && [ ! -d "$d/foreverdump" ]; do d="$(dirname "$d")"; done; echo "$d")}"  # portable root (handoff)
OUT=${OUT:-/tmp/tzimpact_old}; FD=$WOWDEV_ROOT/foreverdump; K=$WOWDEV_ROOT/kth; E="python3 $FD/tools/tz/oldemu.py"
R19=$FD/real/2026-10-10-run19-bg; R20=$FD/real/2026-10-10-run20-dungeon
for tz in America/New_York UTC Asia/Kolkata; do
  o=$OUT/$(echo $tz | tr / _); mkdir -p $o/replay; cd $FD
  TZ=$tz $E fd tools.fdump.aurapresence $R19/sv/ForeverDump.lua $R19/WoWCombatLog.txt $R19/out/truth.json --json $o/ap19.json >/dev/null || echo "FAIL ap19 $tz"
  TZ=$tz $E fd tools.fdump.aurapresence $R20/sv/ForeverDump.lua $R20/WoWCombatLog.txt $R20/out/aurapresence/truth.json --json $o/ap20.json >/dev/null || echo "FAIL ap20 $tz"
  TZ=$tz $E fd tools.fdump.pvescript $R20/sv/ForeverDump.lua $R20/WoWCombatLog.txt --mine Player-4618-00EB40D8 --json $o/pve20.json >/dev/null || echo "FAIL pve $tz"
  cd $K/tools
  TZ=$tz $E kth export_replay.py $o/replay 2026-10-09-run10-bg 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg 2026-10-10-run19-bg >$o/export.log 2>&1 || echo "FAIL export $tz"
done
