#!/usr/bin/env bash
# v2.2.11: the original serial command list (reference / --serial fallback); tests/run_converter_tests.sh now runs
# the same commands through tests/runner.py in parallel. Add new tests to BOTH (tests/test_runner_parity.py checks).
# Full test run: addon smoke test in the mock client (writes tests/out/ForeverDump.lua), then converter e2e.
set -eo pipefail   # a failing test fails the run even when piped through tail (perf gate included)
cd "$(dirname "$0")/.."
mkdir -p tests/out
export FORE_DOCS="${FORE_DOCS:-$PWD/ref/wusf/Interface/AddOns}"
# v2.2.13: every lua5.1 below is the WoW-like build (x / 0 and x % 0 raise like the client); no stock fallback.
# luacheck (a system tool, not game code) keeps the stock interpreter.
export PATH="$(printf %s "$PATH" | tr ':' '\n' | grep -v '/.cache/wowlua/path$' | paste -sd:)"   # stock lookups below
export FD_STOCK_LUA="$(command -v lua5.1)"
export LUA_PATH="${LUA_PATH:-$("$FD_STOCK_LUA" -e 'io.write(package.path)')}" LUA_CPATH="${LUA_CPATH:-$("$FD_STOCK_LUA" -e 'io.write(package.cpath)')}"
export WOWLUA="$(bash tests/build_wowlua.sh | tail -1)"
mkdir -p .cache/wowlua/path && ln -sf "$WOWLUA" .cache/wowlua/path/lua5.1 && ln -sf "$WOWLUA" .cache/wowlua/path/lua
export PATH="$PWD/.cache/wowlua/path:$PATH"
lua5.1 -e 'if pcall(function() local z = 0 return 1 / z end) then os.exit(1) end'
luac5.1 -p ForeverDump/*.lua ForeverDump/Lib/*.lua
"$FD_STOCK_LUA" "$(command -v luacheck)" ForeverDump tests --no-color -q --exclude-files "tests/legacy_addon/*"
lua5.1 tests/smoke.lua ForeverDump tests/out/ForeverDump.lua | tail -1
lua5.1 tests/hsm.lua ForeverDump | tail -1
lua5.1 tests/knowledge_parse.lua ForeverDump | tail -1
lua5.1 tests/timing.lua ForeverDump | tail -1
lua5.1 tests/learned.lua ForeverDump | tail -1
python3 tests/test_converter.py
lua5.1 tests/buggrabber.lua ForeverDump | tail -1
python3 tests/test_xref.py
python3 tests/test_migrate.py
lua5.1 tests/regress.lua ForeverDump | tail -1
python3 tests/test_v22.py
python3 tests/test_identity.py
python3 tests/test_v222.py
busted tests/spec/containers_spec.lua | tail -1
python3 tests/test_v223.py
python3 tests/test_v224.py
python3 tests/test_v224_tools.py
python3 tests/test_v225_ho.py
python3 tests/test_v225_findings.py
python3 tests/test_v226_replay.py
python3 tests/test_v226_replay_exec.py
python3 tests/test_v226_reconcile.py
python3 tests/test_golden_run5.py
# PERFORMANCE.md gate: static perf lint (errors and warnings fail) + runtime N-cast benchmark (25/50/100 casts + aged session):
# per-event cost flat, <1% frame impact, no idle OnUpdate. Hard 2-minute wall cap (bench --cap 100 aborts itself; timeout 120 backstop).
# v2.2.4 perf gate inside --assert: aged/fresh impact ratio <= 1.5, SPELL_UPDATE_COOLDOWN storm <= 0.5 %, 40-man scanner
# slice max <= budget (the bench re-executes itself with glibc fastbins off; see its header).
python3 tools/fdump.py perfcheck ForeverDump --strict | tail -1
timeout 120 lua5.1 tests/perf_bench.lua ForeverDump --assert --json tests/out/perf_bench.json | tail -1
# v2.2.6: SV size/serialize-time at full capture caps (test ring fill <= 26 MB, ~30 MB total target)
lua5.1 tests/sv_serialize_bench.lua test | tail -2
lua5.1 tests/sv_serialize_bench.lua release | tail -2
# v2.2.10: diag has no artificial caps -> the bench only REPORTS diag size/save time (30 min BG fill); diag is gated on
# in-game cost instead: a 30 min battleground replayed accelerated through the addon (real run 8 when present)
lua5.1 tests/sv_serialize_bench.lua diag | tail -2
python3 tests/bg_replay_gate.py
# v2.2.7 (run 6): static lint (combat-protected APIs guarded, no hooks, no bare os, no secret truth tests, deferred
# blocked prints, ObjectiveTracker read-only) + combat-guard regression in the mock client
python3 tests/test_v227_lint.py
lua5.1 tests/combat_guard.lua ForeverDump
lua5.1 tests/hsm_alive.lua ForeverDump
lua5.1 tests/worldcap_pack.lua ForeverDump
# v2.2.8: engine health (helper failure -> degraded, New failure -> down, guard + counters in the tape header)
lua5.1 tests/hsm_health.lua ForeverDump degraded
lua5.1 tests/hsm_health.lua ForeverDump down
lua5.1 tests/hsm_health.lua ForeverDump guard
# v2.2.9 (run 8 BG): error-handler frames never make an error ours; FD_Logs macro never carries a stale /combatlog
lua5.1 tests/run8_regress.lua ForeverDump stack | tail -1
lua5.1 tests/run8_regress.lua ForeverDump macro | tail -1
python3 -W ignore tests/test_v229_run8.py 2>&1 | tail -1
python3 tests/test_v227_secret_lint.py
lua5.1 tests/secret_inject.lua ForeverDump
lua5.1 tests/static_once.lua ForeverDump
# v2.2.7 follow-up (runs 6/6b FINDINGS): engine-health leads, ws decode, coverage fallbacks, meter join by time
python3 tests/test_v227_findings.py
# v2.2.10: lossless DAMAGE_METER_* run-length rows - the same stream replayed through the whole addon with and without
# RLE must expand to identical combat/record/tape streams (synthetic always; run 8 when the private capture is present)
python3 tests/test_v2210_dmrle.py 2>&1 | tail -1
# v2.2.10: cumulative master secrets guide (docs/SECRETS-GUIDE.html/.md + state JSON) must match `fdump.py master-guide`
# output for the runs under real/ and be newer than the newest run data; structure/placeholder checks only without real/
python3 -W ignore tests/test_master_guide.py 2>&1 | tail -1
# v2.2.11 (run 9 BG: "constant table overflow"): SavedVariables always load - SVPack packs at PLAYER_LOGOUT into
# constant-limit-safe chunk strings; counter == luac, unit/edge suite, 30 min BG replay at 2x/10x loads in stock Lua 5.1
# (<= 10 % of the 262,143 limit, exact unpack), no-pack control, real run 9 round trip (when present), both formats
python3 -u tests/test_v2211_svpack.py 2>&1 | tail -1
# v2.2.11 (user decisions): static dump only via /fdump static run; FD_Logs ON starts every capture clean (keeps learned + static)
python3 tests/test_v2211_static.py | tail -1
lua5.1 tests/capture_wipe.lua ForeverDump | tail -1
# v2.2.11 (run 9 taint.log isdst): UTC offset without writing into date() tables, several zones incl. half/45-min/+14/-11
for tz in America/New_York UTC Asia/Kolkata Pacific/Chatham America/St_Johns Pacific/Kiritimati Pacific/Pago_Pago; do
    TZ=$tz lua5.1 tests/utcoffset.lua ForeverDump | tail -1
done
lua5.1 tests/taint_run9.lua ForeverDump | tail -1
lua5.1 tests/bg_chat_taint.lua ForeverDump | tail -1
lua5.1 tests/version_visibility.lua ForeverDump | tail -1
lua5.1 tests/lab_v2215.lua ForeverDump | tail -1
lua5.1 tests/attr_v2216.lua ForeverDump | tail -1
lua5.1 tests/raw_identity.lua ForeverDump | tail -1
lua5.1 tests/dm_session_bg.lua ForeverDump | tail -1
lua5.1 tests/svpack_div0.lua ForeverDump | tail -1
lua5.1 tests/svpack_div0.lua tests/fixtures/svpack_v2212 --expect-fail | tail -1
python3 tests/test_div_lint.py
