# Time-handling audit (2026-10-10)

Scope: /workspace/foreverdump (tools/fdump, tools/*.py, tests, addon Lua) and /workspace/kth (tools, tests).
Facts: combat-log stamps are client wall clock **with** their own zone (`M/D/YYYY HH:MM:SS.mmm-4`); Client.log stamps
are client wall clock with no zone and no year; FD SV anchors carry `{gameTime, epoch, utcOffset, date, epochTick, gameTimeTick}`.
The box runs America/New_York = the client zone, so every result produced on the box was right; the bugs fire only in
another zone (or when the client and the box disagree, or across a month or year boundary).

## Sites
| # | site | conversion | verdict before | fix | runs/results touched |
|---|---|---|---|---|---|
| 1 | fdump/combatlog.to_epoch | log stamp -> epoch | OK (uses suffix; box zone only without suffix) | - | none |
| 2 | kth/tools/logtruth.parse_ts | log stamp -> epoch | **BUG**: naive datetime().timestamp() = box zone, suffix ignored | honours suffix | none on the box; in UTC/Kolkata every KTH replay export breaks (below) |
| 3 | kth resolve / export_replay / sim8 / dm_match | via parse_ts | inherited #2 | via #2 | same |
| 4 | fdump/refdata._t, log_seconds | log wall clock -> seconds | **BUG**: day-of-month*86400 (jumps back at 10/31 -> 11/1, year ignored); ms/1000 assumed 3 digits | ordinal day; any fraction width | none (all runs inside Oct 7-10) |
| 5 | fdump/aurapresence.epoch_to_logsec | epoch -> log time | **BUG**: time.localtime = box zone | log's own zone (refdata.log_utc_offset) | none on the box; UTC/Kolkata scores were silently wrong (below) |
| 6 | fdump/pvescript | epoch -> log time | same as #5 (written today, fixed before use) | same | none |
| 7 | fdump/classderive.day_seconds | SV anchor date -> seconds | month-boundary bug of #4 | uses log_seconds | none |
| 8 | fdump/clientlog.parse | Client.log -> epoch | **BUG**: box zone; year = today; no New-Year rollover | anchor utcOffset + anchor year + 12->1 rollover | none on the box |
| 9 | fdump.py xref / clientlog cmd | passes #8 | box zone | passes anchor offset/year | none |
| 10 | analysis.ts, coverage._hms, guidejson.captured, fdump.py blocked `when` | epoch -> clock text | display in box zone | client zone from the dump (fdump/timefmt.py) | text only |
| 11 | xref.iso, restrictions clock | epoch -> clock text | OK (anchor offset) | - | none |
| 12 | guide/build_guide.py mtime / now | generation stamp | box zone, unlabeled | labelled with %Z | text only |
| 13 | timing.generated, combatlog year/offset fallback | today's date | OK (fallback only) | - | none |
| 14 | tests/test_v2225.ts | test fixture | localtime with hard-coded "-4" (fails outside -4) | gmtime(epoch-4h) | test only |
| 15 | aurapresence/pvescript anchor | GetTime <-> epoch | whole-second epoch, up to 1 s early | auto offset fit (earlier today); prefer epochTick/gameTimeTick when present | run19 aurapresence (below) |
| 16 | Lua Core TimeAnchor utcOffset | date tables arithmetic | OK (v2.2.11) | - | none |
| 17 | Lua CombatLog.lua utcOffset | time(l with isdst=false) | value OK, but the run-9 taint pattern (writes isdst, time(table)) | -> ns.TimeAnchor(true).utcOffset | source only (not shipped) |
| 18 | Lua AuraPresence anchor | {GetTime, time()} | 1 s skew (#15) | -> ns.TimeAnchor() | source only (not shipped) |
| 19 | Lua Drift.Decay | time{year,month,day} | coarse; time(table) (taint rule) | civil-day arithmetic Drift.DayNumber | source only (not shipped) |
| 20 | Lua ReplayLog (anchor = TimeAnchor, t = GetTime), Logs/DamageMeter/Static/SVPack (bare time()), Legacy/Logs date() text | - | OK | - | none |
| 21 | kth tests/replay_score.lua, perf11, earlysim6 | GetTime-relative / time-of-day buckets | OK (run-relative) | - | none |

DST (fixed in v2.2.26): refdata.lines keeps the log's first zone and shifts rows stamped in another suffix, so log
seconds stay continuous across 2026-11-01 02:00 ET and agree with epoch_to_logsec(first zone); Client.log infers the
switch from its wall clock (clientlog.dst_step: back ~1 h inside 01:xx, or 01:xx -> 03:xx within 30 min). Report
clocks (timefmt, pvescript "time ET") show the log's first zone, so after a fall-back they read EDT, not EST (label).
Also found in v2.2.26: tests/test_v2225.py scored without the log zone (passed only on a -4 box) - fixed and now part
of the per-zone matrix; the whole runner was also run under TZ=UTC: 0 FAIL.

## Impact (tools/tz/impact.sh, impact_old.sh; zones NY, UTC, Kolkata, Chatham, Los_Angeles, Kiritimati)
| result | new code, all zones | vs prior stored (NY) | old code under UTC / Kolkata |
|---|---|---|---|
| aurapresence run 19 | identical | score unchanged by time fixes; auto offset (+0.505 s, 85 pairs) moves combat 464/5/4 -> 465/6/2 agree/disagree/edge (stored as aurapresence.autooffset.json) | offset fit 0 pairs; scores plausible-looking but wrong |
| aurapresence run 20 | identical | identical scores (offset 0.99999996 -> 1.0 float noise) | ooc agree 49 / disagree 7 (new: 52 / 0 + 4 edge); offset fit 0 pairs |
| pvescript run 20 | identical | same events/codes; truth `t` now ordinal log seconds; non-unit arg1 token '-' | offset fit fails (0 pairs) |
| resim_v2223 (runs 10-18) | identical | = HSM-STATUS table | (no time dependency) |
| oocfill_score, rawjoin | identical | identical | (no time dependency) |
| KTH export_replay runs 10-19 | identical | old-vs-new code under NY byte-identical (all files); vs stored: .lua identical for 10-16 and 19, 17/18 header/board text and truth.json truth-v2 fields come from later export code, not time | tokens resolved 72318 -> 10196 (run 10), nHealers -> 0 on every run |
| KTH replay_score port12 runs 16-19 | identical (UTC, Kolkata, Chatham) | identical to tests/results/*.port12.json | n/a |

No prior published number changed because of a time bug.

## Tests
tests/test_tz_matrix.py (11 cases: every converter, midnight run-17 style 23:59->00:00, month, year, DST suffix) and
tests/time_lua.lua (no isdst/time(table), CombatLog/AuraPresence use TimeAnchor, Drift.DayNumber rollovers) run once per
zone in runner.TZS (7 zones), plus test_pvescript per zone. Runner: 111 tests, 0 FAIL.
