#!/usr/bin/env bash
# One-time setup after unzip/clone: tool check, mtimes, WoW-like lua5.1, h32. Safe to re-run.
set -eo pipefail
cd "$(dirname "$0")/.."
miss=0
for t in lua5.1 luac5.1 luacheck busted python3 gcc curl git; do command -v $t >/dev/null || { echo "missing tool: $t"; miss=1; }; done
lua5.1 -e 'require "lfs"' 2>/dev/null || echo "note: LuaFileSystem (lua-filesystem) not found for stock lua5.1"
[ $miss = 0 ] || { echo "install: sudo apt-get install -y lua5.1 liblua5.1-0-dev lua-check lua-busted lua-filesystem gcc curl python3 git"; exit 1; }
python3 handoff-tools/restore_mtimes.py
bash foreverdump/tests/build_wowlua.sh
[ -x foreverdump/tools/fdump/h32 ] || gcc -O2 -o foreverdump/tools/fdump/h32 foreverdump/tools/fdump/h32.c
[ -d foreverdump/real ] || echo "WARNING: captures part not present (foreverdump/real) - many tests need it"
echo "setup OK. Next: cd foreverdump && bash tests/run_converter_tests.sh"
