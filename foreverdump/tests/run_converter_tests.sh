#!/usr/bin/env bash
# Full test run (v2.2.11): every command of tests/run_converter_tests_serial.sh, run by tests/runner.py in parallel
# (phase 1 fixtures + lints, phase 2 the rest, phase 3 perf gates, long independent replays in the background).
# Pass/fail per test is its exit code, as with `set -eo pipefail`; the last line is RUNNER_EXIT:<0|1>.
# Per-test logs: tests/out/runner/<id>.log; timings: tests/out/runner/timing.json. --serial runs one at a time.
set -o pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/out
export FORE_DOCS="${FORE_DOCS:-$PWD/ref/wusf/Interface/AddOns}"
python3 tests/test_runner_parity.py
exec python3 -u tests/runner.py "$@"
