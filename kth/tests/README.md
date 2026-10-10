# Tests
- `load_smoke.lua <KTH.toc>`: loads the addon in ForeverDump's Forever mock (needs /workspace/foreverdump/tests/wowenv.lua)
  and reports errors, Blizzard chat lines and restricted event registrations. baseline: 1 (CLEU); port: 0.
- `replay_score.lua <KTH.toc> <replay/run.lua> <out.json> [port|original-mn]`: replays a captured BG (+ its .dm.lua meter snapshots when present) through K.T.H.'s own
  nameplate verdict; unit model per the baseline diag.
- `../tools/score.py orig port strictD8`: precision / recall / time-to-identify vs combat-log truth → results/SCORES.md.
- `replay/*.lua|*.truth.json`: exported by tools/export_replay.py from the raw ForeverDump captures + combat logs.

## forever.3
- `sh tests/regress/run_regress.sh`: R1 /kthg /hhtd /hhtdg open with no error and no Blizzard chat line (Forever API
  strictness); R2 duplicate first names joined exactly (name + realm = surname); R3 mouse-over plays the announcer
  sound and clicking plays target-lock; R4/R5 every real replay: alert on every healer-verdict hover, icon == verdict;
  R6 static Forever API scan; R7 arena / open world / party (enemy class secret and clear; Pve off); R8 replay
  provenance (forever.4).
  Results: `tests/results/REGRESS-forever.4.txt` (all ok) and `REGRESS-against-forever.2.txt` (R1-R5 and R7 fail on
  forever.2, matching the field report).
- `tests/regress/dupfirst_stream.lua` is a SYNTHETIC unit-test fixture, not a capture.
- `python3 tools/score.py` writes `tests/results/SCORES.md` (orig / port2 / port3).
- The harness loads the ForeverDump mock from `/workspace/foreverdump/tests/wowenv.lua`, and paths are those of the build box.

## forever.4 (test data cleanup)
- Replays carry only real data. Run 16 was re-exported with real full names from its own FD SV (`tools/realnames.py`,
  31/31). Runs 17/18 were already real. Runs 10-13 are board-less (no names, no classes, no scoreboard in the harness)
  and are excluded from scores and from R4/R5. `tests/replay/realnames-report.json` shows how each name was found.
- `python3 tests/replay_provenance_test.py` (R8) fails on the placeholder pattern, a partial board, or any name not
  backed by the run's SV.
- Result files computed on the old placeholder replays (forever.2/.3 harness) are not shipped. `tests/results/variants/forever4-real/`
  holds the D8 and druid-veto variants re-scored on runs 16-18.

## forever.5 (healer verdict = healing output)
- `replay/<run>.dm.lua` (runs 16-18): the run's own C_DamageMeter snapshots exported raw from its FD SV by
  `tools/export_dm.py` (via `tools/dm_extract.lua`); `"<secret>"` = the value was secret when FD read it. The harness
  serves each snapshot from PLAYER_REGEN_ENABLED at its GetTime(); before the first kept snapshot there is no meter
  data (FD keeps 21). `KTH_NO_METER=1` replays without it. R8 checks each file is byte-identical to a fresh export.
  Run 13 gets no meter file (board-less: its friendly rows would bring names into a run without real names).
- `tools/dm_match.py`, `tools/dm_rules.py`: meter rows vs combat log (row sides, amounts) and threshold tuning.
- `tools/rescore5.sh` then `python3 tools/score5.py > tests/results/SCORES-forever.5.md`: original / forever.3 /
  forever.5 without meter / forever.5 on runs 16-18 (plate precision/recall, TTI, on→off flips, DPS druids marked,
  resto druids missed, user-definition recall, claims, phase table).
- R9 (`tests/regress/druid_mana_dps_stream.lua` + `.dm.lua`, SYNTHETIC): two enemy DPS druids on MANA with damage only
  are never marked (BG with meter, arena and open world with the class clear); control
  `druid_resto_stream.lua` + `.dm.lua` (SYNTHETIC): a healing druid is marked. R9b: on real runs 16-18 no enemy druid
  without healing is marked. `dupfirst_stream.dm.lua` (SYNTHETIC) gives R2 its meter rows.
- Results: `tests/results/REGRESS-forever.5.txt` (all ok).

## forever.6 (class-group meter rules, user: recall of forever.3 with the precision of forever.5)
- `tools/forensics6.py` (per player: plate sightings, power, casts, links, forever.3/forever.5 marks and claims) and
  `tools/forensics6_meter.py` (per enemy class group: raw heal/damage rows and the forever.6 verdict at each snapshot).
- `tools/rescore6.sh` then `python3 tools/score5.py orig port3 port5 f6a-grp60 f6b-grp63 f6c-grp70 f6d-weak2
  f6e-weak1-nocap port6`: variants via `KTH_CFG="key=value,..."` (thresholds only; replay data untouched).
- `tools/earlysim6.py` -> `tests/results/EARLYSIM-forever.6.txt`: OPTIMISTIC estimate of earlier meter reads rebuilt
  from the combat log (FD kept only 21 snapshots). Flagged; never used in scores or tests.
- R10: named real-data cases. All 9 enemy healers of runs 16-18 must be marked with 0 on->off flips (Bleep, Frobby,
  Invictusap, Gorrotar, Aerie, Brocky, Randess, Ank, Karen). Joff, Tatusera and Torvian must never be marked or
  claimed. Ganon, Romsly and Vale must never be claimed. Against forever.5, R10 fails 4 cases (Gorrotar, Randess,
  Ank, Karen), as expected.
- Results: `tests/results/SCORES-forever.6.md`, `tests/results/REGRESS-forever.6.txt` (all ok).

## forever.7 (spec shortcut, healer-only spells, time-to-mark)
- R10 now also asserts a time-to-mark ceiling per real healer (forever.6's mark time on the same replay; no slower).
- R11 `healonly_spell_stream.lua` (synthetic): Holy Shock cast → marked ≤ 2 s (zones none/arena/pvp × class secret/clear); Penance (dropped from the list) and no cast → no mark.
- R12 `lowlevel_healer_stream.lua` (+`.dm.lua`, synthetic): level-22 priest without healer-only spells is marked by the meter; spec stays unknown.
- R13 `spec_arena_stream.lua`, `spec_role_stream.lua` (synthetic): arena spec 105 → mark; spec 71 / 0 → nothing; group role HEALER → claim, DAMAGER → nothing.
- Synthetic fixtures model API returns whose readability is unmeasured on Forever (arena specs, roles); the scoreboard mock keeps talentSpec secret as measured.

## forever.8 (user's healer-only list)
- R11 `healonly_spell_stream.lua` (synthetic) has one enemy per listed spell (Penance 402289, Power Infusion 10060, Prayer of Mending 401859, Light's Vigil 1310911, Wild Growth 408120, Riptide 408521). Each is marked 1 s after its cast, in zones none/arena/pvp × class secret/clear (42 checks). Swiftmend 18562, Holy Shock 1311606, Riptide-named NPC spell 22419 and no cast give no mark.
- tools/sim8.py: a combat-log simulation of the list (not live behaviour).

## run 19 (2026-10-10; held out until forever.9b, a TRAINING/regression run since forever.10)
- `replay/2026-10-10-run19-bg.{lua,truth.json,dm.lua}` exported with tools/export_replay.py + tools/export_dm.py from the raw
  run (`/workspace/foreverdump/real/2026-10-10-run19-bg`, 0 hashed keys, real board 31/31). FD kept all 17 meter
  snapshots of this match (under the 21 ring), so the meter timeline is complete.
- `tools/score5.py` takes `KTH_RUNS=run19` (default still runs 16-18). `results/SCORES-run19.md`, `results/REGRESS-run19.txt`.
- R16 `regress/specname_test.lua`: scoreboard talentSpec names; Forever returns the class name post-match -> no verdict.
- R17 (forever.10): run 19 is no longer held out. Hard: every truth-v2 enemy healer claimed (Danukeru, 汇源, Moun) and
  plate-marked whenever its plate was up after the claim; 0 false marks/claims either side (梦之旅程, Aurelís, Suikoden);
  every friendly truth healer claimed; 0 on->off flips. (Until forever.9b: held-out, hard only on Danukeru/汇源.)
- `tools/kmin_sim.py`: per class group and snapshot, min/max healer count consistent with the anonymous meter rows,
  plus druid RAGE/ENERGY plate-power share (analysis only).

## forever.10 (truth v2, kmin / elimination / druid form tie-break)
- Truth v2 (tools/export_replay.py; user: HoT healers count): healer = heal share >= 0.30 with HoT ticks counted as
  heals on others, AND >= 5 heal events on others including ticks (was >= 5 direct heals). Roster fields `ho, dmg, hoEv,
  firstHOany, healer_v1`. Only changes over runs 16-19: run 19 Moun (E, PRIEST, .74, 54 events) and Grassy (F, DRUID,
  .87, 15 events) become healers. The 0.30 share threshold is kept (Furbreezze .31, Randess .39 are R10 healers).
- R18 `regress/kmin_test.lua`: kRange on real meter rows (7 reads from runs 17-19), form share, elimination (synthetic
  records, labelled). `tools/rescore10.sh`: forever.10 switch variants; `results/SCORES-forever.10.md`,
  `results/REGRESS-forever.10.txt`.
- replay_score.lua writes `lastSeen` (last sweep a plate was up) next to `seen`.

## forever.11 (threshold setting, debug switch, perf)
- replay_score.lua: `KTH_SETTINGS="healerSharePct=N,debug=0|1,ov.PRIEST=N,ov.PRIEST:Holy=N"` sets the user's saved
  settings before the match; `KTH_PERF=1` times every handler/ticker (out.perf); out.debugCapture counts timeline reads
  and plate-log rows.
- R19 `regress/threshold_test.lua` (90 checks): defaults = forever.10 E.CFG, GUI -> verdict code, precedence
  class+spec -> class -> global, Use global, clamp, reset; debug checkbox = /kthdebug, migration of /kthdebug off.
- R20: runs 16-19 with defaults, explicit 60%, debug on, debug off: marks, flips, records and mouse-over identical to
  `results/run*.port10.json`; debug off captures nothing.
- tools/rescore11.sh (settings variants, incl. 50/70% and a Priest 80% override); tools/perf11.py ->
  results/PERF-forever.11.md (perf numbers include the harness's 1 s plate-log call; live it runs every 2 s).

## forever.12 (teamMax removed, more settings, reset-all)
- replay_score.lua KTH_SETTINGS also takes removeSharePct, meterMinHeal, healsNeeded, elimEnabled=0|1, formTieEnabled=0|1.
- R21 `regress/settings12_test.lua` (88 checks): defaults = E.CFG; each GUI control saved and reaching actVote / kRange /
  E.cfg; remove-mark clamp; General reset; Reset tab resets every setting live + debug default (fails on forever.11).
- R22: runs 16-19 with defaults and explicit defaults identical to `results/run*.port11.json`; elimination off ->
  Moun not claimed, tie-break off -> 梦之旅程 claimed (run 19).
- tools/rescore12.sh -> results/SCORES-forever.12.md; results/PERF-forever.12.md.
