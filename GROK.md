# GROK.md - Grok Build project instructions (same as AGENTS.md)

Read **HANDOFF.md first** (rules, state, open work), then **MEMORY.md** (standing preferences). Rules there are binding:
raw data (never scrub/hash), no combat log at runtime, never loosen checks, no "accurate but fewer" trade-offs,
correlate at every roadblock, derive secrets via alternate APIs, no static ID lists, per-build caches, perf ≤ 2 %
release / ≤ 10 % capture, status line + lesson in `foreverdump/PROGRESS.md` about every 5 minutes.

## Layout
The repo root is the "workspace root" (`WOWDEV_ROOT`). `foreverdump/` and `kth/` must stay siblings: KTH's harness
loads ForeverDump's mock (`foreverdump/tests/wowenv.lua`) and FD's TZ tests import `kth/tools`. Scripts find the root
via `$WOWDEV_ROOT` or by walking up to the first directory that contains `foreverdump/`. All ForeverDump commands below
run from `foreverdump/`.

## One-time setup (Debian/Ubuntu; versions used on the original box)
```
sudo apt-get install -y lua5.1 liblua5.1-0-dev luajit lua-check lua-busted lua-filesystem gcc curl python3 git git-lfs
#   lua5.1 5.1.5, luac5.1, luacheck 1.2.0, busted 2.2.0, LuaFileSystem 1.8.0, python 3.13 (3.8+ OK, stdlib only), gcc 14
bash handoff-tools/setup.sh      # checks tools, restores file mtimes from MANIFEST.tsv, builds the WoW-like lua5.1, builds tools/fdump/h32
```
- `tests/build_wowlua.sh` builds `foreverdump/.cache/wowlua/bin/lua5.1` from the shipped sha256-pinned
  `.cache/wowlua/lua-5.1.5.tar.gz` with division/modulo by zero **raising** like the game client. The runner puts it first
  on PATH; luacheck/busted keep using the stock interpreter (`FD_STOCK_LUA`).
- `tools/fdump/h32` (salt brute-forcer for the legacy unhash path) is built from `tools/fdump/h32.c`:
  `gcc -O2 -o tools/fdump/h32 tools/fdump/h32.c` (a prebuilt Linux x86-64 binary is included).
- Python tools are standard-library only. `foreverdump-research/guide` used a venv with `html5lib six webencodings`
  (`requirements-research.txt`).
- `FORE_DOCS` (Blizzard API docs tree for the mock) defaults to `foreverdump/ref/wusf/Interface/AddOns` in the runner;
  set it yourself for KTH tests: `export FORE_DOCS=$PWD/foreverdump/ref/wusf/Interface/AddOns`.
- After a **git clone** run `python3 handoff-tools/restore_mtimes.py` (setup.sh does it): git does not keep mtimes and
  `master-guide --check` compares guide vs run-data mtimes and the SV-inspect cache is keyed by SV size+mtime. If mtimes
  were changed anyway, the first `--check` reports STALE once (cache rebuild); see HANDOFF.md open work 7.

## Tests, lint, perf gates (must be 0 FAIL before any package)
```
cd foreverdump
bash tests/run_converter_tests.sh            # full runner (~126 tests: luac, luacheck, mock-client Lua tests, Python tools,
                                             # TZ matrix x7 zones, perf gates perfcheck/perf_bench/bg_replay_gate); prints RUNNER OK/FAILED + RUNNER_EXIT
TZ=UTC bash tests/run_converter_tests.sh     # required second pass under a foreign zone
python3 tests/runner.py --only 'v2229|sched' # subset by regex; --serial for one-at-a-time; logs in tests/out/runner/<id>.log
luacheck ForeverDump tests --exclude-files "tests/legacy_addon/*"        # lint (config: foreverdump/.luacheckrc)
python3 tools/fdump.py perfcheck ForeverDump --strict                     # static perf lint
timeout 120 lua5.1 tests/perf_bench.lua ForeverDump --assert              # perf gate (2-minute cap)
```
Ordering/timing: the runner runs phase 0 (long independent replays in background), phase 1 (fixtures + lints), phase 2
(parallel), phase 3 (perf gates, ≤ 2 workers), longest-first from `tests/out/runner/timing.json`. Don't run two runners at once.
Many tests read real captures under `real/` (run 5 golden, run 8 DM RLE, run 22 tools...): the captures part is required.

KTH: `cd kth && FORE_DOCS=$PWD/../foreverdump/ref/wusf/Interface/AddOns sh tests/regress/run_regress.sh` (R1-R8, prints "R? ok"/"FAIL").

## Build / package / post-build
```
cd foreverdump
python3 tools/package.py            # -> ForeverDump-v<ns.VERSION>.zip (version from ForeverDump/Core.lua ns.VERSION); verifies every entry by sha256
# post-build: unzip into a temp dir, luac5.1 -p every .lua listed in ForeverDump.toc, run the new version's tests against the unzipped addon,
# record "PACKAGED ... files, sha256 ..." + lesson in PROGRESS.md and a CHANGES.md section.
```
Version bump: `ns.VERSION` in `ForeverDump/Core.lua` + `## Version` in `ForeverDump/ForeverDump.toc` + CHANGES.md.

## Analyze a new capture (run N)
1. Put the user's files raw in `real/<date>-run<N>-<bg|dungeon|world>/`: `sv/ForeverDump.lua` (from
   `WTF/Account/<acct>/SavedVariables/`), `WoWCombatLog.txt` (if cut to the capture window keep `WoWCombatLog.original.txt`),
   `taint.log`/`Client.log` if present, the uploaded zip(s) in `raw/`, `RAW-NOTE.md` for anything done to them.
2. Check errors + versions first: `python3 tools/fdump.py info real/<run>/sv/ForeverDump.lua`, `... errors ...`, `... perf ... -o real/<run>/out/perf`.
3. Full pass (template `real/2026-10-08-run5/convert.sh`): `all`, `coverage`, `inference`, `verify-live`, `analyze --history ...`,
   `correlate` (at every roadblock), plus newer per-feature tools in `tools/fdump/` (aurapresence.py, totemscore.py,
   derivesim.py, pvescript.py `--mine <player GUID>` - always pass the GUID).
4. Add the run to `tools/fdump/data/unhash-inclusion.json` (0 hashed -> included) and rescore older runs with any changed tool.
5. `python3 tools/fdump.py learned-auras` (regenerates `ForeverDump/Data/LearnedAuras.lua`; `tests/test_learnedauras.py` fails when stale).
6. `python3 tools/fdump.py master-guide` (regenerates `docs/SECRETS-GUIDE.{html,md}` + state; `--check` verifies).
7. Write `real/<run>/out/REPORT.md`, update `docs/HSM-STATUS.md` / FINDINGS, PROGRESS.md lines with lessons; run the full runner.

## Data refresh per client build (reference data)
`tools/refresh/refresh_all.sh` (wraps `fetch_community.sh`: Gethe/wow-ui-source + Ketho/BlizzardInterfaceResources
branch `forever`, wago.tools DB2 CSVs; `extract_ui_cdn.sh`/`extract_db2_cdn.sh`: straight from Blizzard's CDN via
TACTSharp/DBC2CSV, needs dotnet, installed into `tools/refresh/.cache`). See `docs/REFERENCES.md` and `foreverdump/SELF-HOSTING.md`.

## Writing code here
- Lua 5.1 only (client), no `goto`, no integer division assumptions; never touch a secret value (classify first).
- No new hardcoded spell/aura ID tables; learn per build. No combat-log reads in the addon.
- Every change: test first (real-data replay when possible), full runner local + `TZ=UTC`, never relax an assertion.
