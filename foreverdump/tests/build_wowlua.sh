#!/usr/bin/env bash
# v2.2.13: build a WoW-like Lua 5.1 interpreter for the tests. The game client's Lua RAISES on division and modulo by
# zero ("Division by zero"); stock Lua 5.1 returns inf/nan, so run 10's SVPack failure (1/v on v == 0) passed every
# test. Builds the official lua-5.1.5 source (sha256-pinned, cached in .cache/wowlua) with lvm.c's runtime DIV / MOD
# raising on a zero divisor. Constant folding in the compiler already refuses x/0 (left to the VM), so a literal "0/0"
# also raises when the chunk runs, as in the client. Output: .cache/wowlua/bin/lua5.1 (prints its path).
set -eo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/.cache/wowlua"
BIN="$D/bin/lua5.1"
SHA=2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333
STAMP="$D/bin/.build-v2"   # bump when the build changes (v2: -Wl,-E so C modules such as lfs.so load)
if [ -x "$BIN" ] && [ -f "$STAMP" ] && "$BIN" -e 'if pcall(function() return 1/0 end) then os.exit(1) end' 2>/dev/null; then echo "$BIN"; exit 0; fi
mkdir -p "$D/bin"
cd "$D"
if [ ! -f lua-5.1.5.tar.gz ]; then curl -sfL -o lua-5.1.5.tar.gz https://www.lua.org/ftp/lua-5.1.5.tar.gz; fi
echo "$SHA  lua-5.1.5.tar.gz" | sha256sum -c - >/dev/null
rm -rf lua-5.1.5 && tar xzf lua-5.1.5.tar.gz
python3 - "$D/lua-5.1.5/src/lvm.c" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = '#include "lvm.h"\n'
patch = anchor + '''
/* ForeverDump tests: the WoW client raises on a zero divisor (stock 5.1: inf/nan) */
#undef luai_numdiv
#undef luai_nummod
#define luai_numdiv(a,b) ((b) == 0 ? (luaG_runerror(L, "Division by zero"), (a)) : (a)/(b))
#define luai_nummod(a,b) ((b) == 0 ? (luaG_runerror(L, "Modulo by zero"), (a)) : ((a) - floor((a)/(b))*(b)))
'''
assert anchor in s
open(p, "w").write(s.replace(anchor, patch, 1))
PY
# no make needed: one gcc call (core + libs + lua.c; luac.c/print.c excluded)
CC="${CC:-gcc}"
SRCS=$(ls lua-5.1.5/src/*.c | grep -v -e '/luac\.c$' -e '/print\.c$')
$CC -O2 -w -DLUA_USE_POSIX -DLUA_USE_DLOPEN -o "$BIN" $SRCS -lm -ldl -Wl,-E
"$BIN" -e 'assert(not pcall(function() local z = 0 return 1/z end)); assert(not pcall(function() local z = 0 return 5%z end)); assert(not pcall(loadstring("return 0/0")))'
touch "$STAMP"
echo "$BIN"
