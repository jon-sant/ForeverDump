# Performance requirements (standing rule)

This rule applies to everything in this repository: the ForeverDump addon, every module added to it, the converter's
generated code (mocks, specs, fixtures) and any addon ported with `fdump.py migrate`. It is enforced by the default test
runner (`tests/run_converter_tests.sh`), so a build that breaks it fails.

## The rule

1. **Framerate impact (one build, two levels).** Default (no FD_Logs capture) is **release** level: all addon handler time
   together must be **under 2%** of wall time (user decision 2026-10-08; was 1%). One-click FD_Logs elevates to **diag** (v2.2.9 default `captureLevel`; `test` on request)
   for tracing / data gathering / live evaluation — capture mode may use up to **10%**; when capture stops, verbosity
   returns to release. `/fdump level` is a manual override between captures. Both gates are measured in the same build
   (`tests/perf_bench.lua`). At 60 fps, 2% ≈ 0.33 ms/frame.
2. **No idle OnUpdate.** A frame has an OnUpdate script only while it has pending work. Install the script when something
   becomes dirty and remove it (`SetScript("OnUpdate", nil)`) or hide the frame once nothing is pending. Hidden windows
   have no OnUpdate and no UI event registrations.
3. **O(1) per-event cost.** The cost of handling one event must not depend on how long the session has run, or on how many
   casts, auras, units or predictions have been seen. Use bounded ring buffers or amortised trims (never
   `table.remove(t, 1)` on a large list), incremental counters instead of re-walking history, and caches keyed by a version
   number.
4. **Dirty-only, throttled redraws.** UI text and bars are rebuilt only when their data changed (a dirty flag or version
   counter), at most 5-10 Hz, and only while visible. Countdowns may tick at 1 Hz.
5. **Heavy work out of combat or offline.** Walks of `_G` (52k globals on Forever 70245, about 17 ms each), full API sweeps,
   documentation scans and sorting of large tables happen in chunked out-of-combat jobs, once per session (cached), or in
   the offline converter. They never run from an event handler, OnUpdate or redraw path. Container/combat probes run once
   per context or unit class, not on every event.

6. **Budgets are drift-guarded data, not constants (v2.2.4).** This is the standing drift design rule applied to performance.
   Every learned or static value (scanner budget, LRU caps, GCD/cooldown seeds, cast models) is a starting point. It is
   keyed by build, re-verified live, decayed when not re-confirmed and drift-flagged with a changelog entry. Each one is
   configurable (`/fdump set ...`), never hard-coded without an override path. Learned tables are LRU-capped and O(1) per
   update. Seed merges happen offline (`fdump analyze --write-seed`), never in game.

## Every perf test run finishes within 2 minutes

Every performance test run must finish within **2 minutes of total wall time**. This applies to the default runner, CI and
manual runs alike.

- `tests/perf_bench.lua` uses reasonable cast counts by default: four back-to-back 25-cast windows (checkpoints 25/50/75/100),
  then five more 25-cast windows after 2000 casts pushed through the handlers (the "aged session"), a 3 x 10 s
  SPELL_UPDATE_COOLDOWN storm and a 30 s 40-man battleground scan. A full run takes 7-10 s.
- A hard wall-clock cap (`--cap`, default 100 s) aborts the run and prints the trend measured so far.
- The test runner adds `timeout 120` as a backstop.
- To compare an old build that is slow, use checkpoints (`--marks 1,2,4,8,16 --win 1`) and the cap. Do not use long runs.

## How it is enforced

| check | where | fails when |
|---|---|---|
| runtime benchmark | `lua5.1 tests/perf_bench.lua ForeverDump --assert` (default runner) | Lua instructions per event / per frame at the aged checkpoint > 1.5x the 25-cast count (+200 / +100); garbage per event > 2x; **aged/fresh frame-time impact ratio > 1.5**; aged impact > 0.45%; **FD_Logs capture (test) impact > 10%** at any checkpoint; **release-level post-capture window >= 2%** (was 1%; user, 2026-10-08); **SPELL_UPDATE_COOLDOWN storm > 2%** at capture and release level (was 0.5%; limit set by the user on 2026-10-08); **40-man scanner slice max > its budget** (0.12 ms); idle OnUpdate after 700 s; no self-perf; over cap |
| diag battleground replay (v2.2.10) | `python3 tests/bg_replay_gate.py` (default runner): a real 30 min BG (run 8, when on the box; else synthetic) replayed accelerated through the whole addon, `tests/bg_replay.lua --assert` | measured level is not diag; **capture impact > 10%** (whole run, first or last 5 min); **last/first 5 min impact ratio > 1.5**; a safety ceiling hit; any recorder throttle drop, tape overflow or signal drop |
| SV size (v2.2.6, v2.2.10) | `tests/sv_serialize_bench.lua test / release / diag` | test ring fill > 26 MB; release ring fill > 4 MB. diag: report only (no data cap at diag; save time measured, not capped) |
| static perf lint | `python3 tools/fdump.py perfcheck ForeverDump --strict` (default runner) | an unthrottled OnUpdate that never removes itself, a throttled one never removed, `pairs(_G)` outside an annotated cached or dump-only function, a handler reaching a `_G` walk or an expensive client API, `table.sort` or `table.remove(t, 1)` in a handler, string building in an unthrottled OnUpdate, `RegisterAllEvents`, or a `NewTicker` that is never cancelled |
| HSM / UI unit checks | `tests/hsm.lua` | project info re-walked, unbounded push, Appliers not cached, stale unit state kept, an OnUpdate left installed when idle or hidden |
| ported addons | `fdump.py migrate` writes a "Performance (PERFORMANCE.md)" section into MIGRATION.md | the same lint, reported per call site |
| generated code | `fdump.py mocks` ships `perf_guard.lua` and `spec/perf_spec.lua` | per-event cost grows across the 25/50/100 checkpoints, an idle OnUpdate remains, or the run exceeds the 2-minute cap |

A justified exception is annotated in the code with `-- perf-ok: <reason>` on the same line or the line above. Examples are
the dump-only `_G` walks in the chunked job runner and the once-per-session project scan.

## Measuring in game: the self-perf monitor

Every FD_Logs capture records its own cost in `ForeverDumpLogDB.perf` (Perf.lua, `perf.enabled`, on by default). It keeps
numbers only:

- per-handler call counts, total, max and 15 s windows
- 5 s samples of the Lua heap, the framerate, the C_AddOnProfiler application/overall/own metrics and the sizes of the
  addon's growing tables

Inspect it in two ways:

- `/fdump perf` in game shows the top handlers and the percentage of wall time.
- `python3 tools/fdump.py perf ForeverDump.lua` writes PERF.md and perf.json. They flag:
  - impact >= 2% (release budget; v2.2.10, user 2026-10-08)
  - handlers whose cost per call grows with session length (last third > 2x first third)
  - tables that are still growing at the end

For pre-2.2.3 SVs, PERF.md falls back to the FD_Logs profile snapshots (capture:on vs capture:off).

## Why (run 4, v2.2.2)

The frame rate fell as the user cast more abilities. Causes:

- `ns.Meta()` walked all 52,517 globals on every call (about 17 ms).
- It was reached from the HSM window redraw (once per text line at 5 Hz, and the number of lines grew with predictions),
  from every UNIT_AURA (container DB lookup) and from every combat-probe read in lockdown.

Measured cost:

- In game: the application frame time rose from 20.7 to 59.3 ms during the 86 s capture.
- In the benchmark: the per-frame cost grew 1.5 -> 2.6 -> 5.2 -> 9.5 ms over the first 1/2/4/8 casts, reaching 57-64% frame
  impact.

After the fixes (v2.2.3), the same benchmark shows 0.004-0.009 ms per frame (0.04-0.08%), flat through an aged session of
2,110 casts, and no idle OnUpdate.

## Perf gate (v2.2.4, run 5)

Symptom: the aged session (~2,100 casts) measured 0.92% against 0.17% for a fresh one. The gate requires the aged session
within 1.5x of fresh, the SPELL_UPDATE_COOLDOWN storm at 0.5% or lower (v2.2.10: 2% at capture and release level, set by the user on 2026-10-08), and the scanner never exceeding its slice budget.

What was found:

- **Most of the "growth" was the host allocator, not the addon.** Lua instruction counts per event and per frame were flat
  (about 2,700 and 1,050) while wall time grew. glibc consolidates every freed small chunk ("fastbins") on the first
  allocation of 1 KB or more after a large free. The bench does a full collect before each window, which frees a big
  heap, so whichever handler next allocated a large block paid 5-130 ms. Examples were a table resize in
  `Tokens.Scan.OnCast` and the 2.7 KB HSM body string.
  - With fastbins disabled (`GLIBC_TUNABLES=glibc.malloc.mxfast=0`), the old one-string HSM body is flat (0.025 vs 0.020
    ms/frame). An earlier note blamed Lua 5.1 string-hash collisions; that diagnosis was wrong.
  - WoW does not use glibc malloc. `tests/perf_bench.lua` therefore re-executes itself with fastbins off. Set
    `FD_BENCH_ALLOC=native` to compare against the default allocator. With it, only the first aged window shows the hit;
    the median still passes.
- **Real O(k) per event: SPELL_UPDATE_COOLDOWN.** Every event rebuilt and walked the whole cooling set: `CDActive()` built
  a new list, and `Inference` checked all k spells. With 54 spells cooling, that was 4,142 Lua instructions per event.
  The fix uses incremental indices in `HybridState`:
  - a dense active array with O(1) swap-remove;
  - a lazy min-heap of predicted ready times, rebuilt only when stale entries pile up;
  - a "due" set for spells within 2 s of their predicted ready time, re-read on every event;
  - round-robin re-reads of far-from-ready spells, at most once per second each.

  `HS:CDCheckList(horizon, budget)` returns a reused buffer. The UI's "latest cooldown" bar keeps a tracker pointer that is
  re-picked only when that cooldown settles, and the body shows at most 8 cooldown lines.
- **Allocation-free hot paths:**
  - `Secrets.ObserveLive` (every recorded event) reuses scratch tables and memoised key/context strings.
  - The recent-list move-to-front is O(1) for repeats.
  - `Tokens.Scan.OnCast` uses numeric keys.
  - The scanner reuses token-map entries, caches families and the profiler clock, and caches SPELL_UPDATE_COOLDOWN payload
    counters per context.
- **Scanner budget is enforced inside the loop.** The deadline is checked after every field read, not per token. A token
  cut off by the deadline resumes at the next field in the next slice (`st.resume`). New reads stop `bailMs` (0.04 ms)
  before the budget, so one in-flight call still ends inside it. Over-budget slices are counted per capture
  (`cost.overBudget`). The scanner's event frame is now timed by the self-perf monitor (`TokenScan.<event>`).

Before and after (bench, default allocator before, fastbins off after; ms per 10-cast window unless noted):

| module | fresh before | aged before | fresh after | aged after |
|---|---|---|---|---|
| Tokens scanner onEvent (Scan.OnCast) | small (not in the top list) | 17.9 (17.5) | 1.1 | 1.2 (0.6) |
| Recorder (incl. ObserveLive) | 9.2 | 12.7 | 7.2 | 5.6 |
| Inference | not separated | 9.2 | 6.8 | 4.1 |
| HSM body refresh | 0.27 ms/call | 5.4 ms/call | line pool | flat |
| SPELL_UPDATE_COOLDOWN storm | 0.62-1.04% (4,142 instr/event in the handler) | | 0.29-0.39% median (1,654 instr/event) | |
| 40-man scan max slice (budget 0.12) | 0.14-0.24 ms (outliers 2.5) | | 0.093-0.115 ms | |
| impact (fresh vs aged medians) | 0.17% | 0.92% | 0.17-0.24% | 0.19-0.25% (ratio 1.00-1.18) |

## v2.2.10: diag without data caps (real-data BG replay)

The user's rule: don't artificially limit diag data collection. diag ceilings are now runaway backstops only, and the
diag gate is in-game cost. Measured by replaying run 8 (21.7 min, 125,584 recorded events) tiled to 30 min, accelerated
(14.5 s wall):

| | 1x (run 8 density) | 2x (raid/nameplate tokens doubled) |
|---|---|---|
| capture impact, whole run | 0.667% | 0.772% |
| first / last 5 min | 0.558% / 0.648% (ratio 1.16) | 0.655% / 0.739% (ratio 1.13) |
| Lua memory over base at 20 / 30 min | +190 / +253 MB (without DM run rows: +257 / +359 MB) | +224 / +302 MB |
| rows kept (combat / recorder / tape) | 54,835 / 85,144 / 215,123; nothing dropped, no ceiling hit | |
| SV | 76.8 MB, mock save 11.4 s (one number; not gated) | |

DAMAGE_METER_* run rows fold 77,675 of 132,510 combat-ring rows. The round trip is exact for combat, recorder and tape
DM rows (`tests/test_v2210_dmrle.py`).


## v2.2.15: capture level lab (user decision 2026-10-09)

User directive (2026-10-09 13:42): "pack in many tests, leads and probes; temporary perf impact during diag captures is
fine". Therefore:

- New capture level **lab** (FD_Logs default) = diag + parallel shadow rules + lab probes. **Perf at lab is measured
  and reported, not gated** (`bg_replay_lab`, `perf_bench_lab` print numbers; they fail only on the backstop).
- **Backstop = report** (user decision 2026-10-09, "data collection and probing come first, optimize later"): Perf.Add
  counts handler calls >= 250 ms; 3 within 60 s print a red warning in ForeverDump's own frame and are recorded in the
  SV (`perf.sessions[n].backstop`); lab keeps collecting and no test fails on it. Recorded every capture: `maxCall`
  and `spikes` (calls >= 50 ms with the call's heap delta; < 64 KB = GC-attributed). Mock BG replay (1800 s): worst
  single calls 170-230 ms, all GC atomic steps over the big capture heap (none with GC stopped; handlers' own work
  < 10 ms except the pre-existing TokenScan.Slice ~60 ms). GC-pause reduction (e.g. fewer objects per tape row) is
  deferred.
- Cost per probe (`Lab.<event>`, `Lab.sweep`, `Lab.sample`, `Probe.step`) and per shadow-rule family
  (`inference.cand.cost`: n, ms, max) are recorded every capture.
- **Unchanged**: release level <= 2 % and all its gates; diag <= 10 %, storm 2 %, the BG replay gate at diag.
- First numbers (mock, run-8 BG replay 1800 s): lab 0.722 % vs diag 0.638 %; lab probes 576 ms total; shadow rules
  heal-target 12.9 ms / 323 calls, aura-me 9.6 ms / 251, heal-me 6.0 ms / 92 (max 0.51 ms); perf_bench lab
  0.30-0.39 %, storm 0.50 %, release after lab 0.017 %.
