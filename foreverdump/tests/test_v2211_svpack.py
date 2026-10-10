"""v2.2.11 permanent regression (run 9: 'Error loading ForeverDump.lua: constant table overflow').
WoW loads the SavedVariables file as one Lua 5.1 chunk; > 262,143 distinct literals and the whole file fails to load.
(0) svconst (the constant counter every check below uses) matches luac5.1 -l exactly on a real file that loads
(1) SVPack unit/edge suite (tests/svpack.lua: NaN/inf/-0, 2^31+ ints, odd keys, holes, forced splitting, 400k literals,
    rescue on a bad chunk, OFF guard), incl. the control that the same data written plainly overflows
(a) 2x and 10x the run 9 constant density (321,237 -> ~642k / ~3.2M distinct literals), generated directly at the
    constant-count level in a capture shape (tests/svpack_real.lua --synth; v2.2.11 speed-up: the old 30 min BG addon
    replay took minutes for the same proof; the PLAYER_LOGOUT -> PackAll -> reload path is asserted in
    tests/capture_wipe.lua and tests/svpack.lua): packed, written client-style, the file loads in stock Lua 5.1 as one
    chunk, unique constants <= 10 % of the limit (asserted), the unpack is exact; control at 10x with packing off
    reports its constant count, must be over the limit, and Lua must refuse it (the counter and Lua agree)
(b) real run 9 SV (when on this box): pack -> client-style write -> loads in stock Lua 5.1 -> unpack is exact (Lua),
    and the converter's decode of the packed file equals its parse of the original (Python, strict types)
(c) the converter reads both formats: the smoke SV (plain) and the same SV packed give identical parses
Nothing here is loosened later: the margin (10 %) and exactness are hard asserts."""
import io
import math
import re
import os
import subprocess
import sys
import threading
from concurrent.futures import ProcessPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "tests"))
from fdump import svconst, svpack  # noqa: E402
from fdump import svcache  # noqa: E402

RUN8_SV = os.path.join(ROOT, "real", "2026-10-08-run8-bg", "sv", "ForeverDump.lua")
RUN9_SV = os.path.join(ROOT, "real", "2026-10-08-run9-bg", "sv", "ForeverDump.lua")
RUN9_CONSTANTS = 321237
MARGIN = 0.10
FAILS = []
OUT = os.path.join(ROOT, "tests", "out")
_buf = threading.local()


def say(line):
    getattr(_buf, "out", sys.stdout).write(line + "\n")


def check(cond, msg):
    say(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        FAILS.append(msg)


def lua_loads(path):
    """loadfile only (compile = what fails with 'constant table overflow'), path passed via the environment"""
    p = subprocess.run(["lua5.1", "-e", "local f, e = loadfile(os.getenv('FD_SV_PATH')) "
                        "if not f then io.write(tostring(e)) os.exit(1) end io.write('loaded')"],
                       capture_output=True, text=True, env=dict(os.environ, FD_SV_PATH=path))
    return p.returncode == 0 and p.stdout.strip() == "loaded", p.stdout.strip().split("\n")[0] if p.returncode else ""


def load(path, unpack=True):
    """parse once per file content: disk cache keyed by file sha1 + parser code sha1 (tools/fdump/svcache.py)"""
    return svcache.parse_file(path, unpack=unpack)


def eq(x, y, p=""):
    if isinstance(x, float) and isinstance(y, float) and math.isnan(x) and math.isnan(y):
        return None
    if type(x) is not type(y):
        return "%s: type %s vs %s" % (p, type(x).__name__, type(y).__name__)
    if isinstance(x, dict):
        if set(x) != set(y):
            return "%s: keys %s" % (p, sorted(map(str, set(x) ^ set(y)))[:5])
        for k in x:
            r = eq(x[k], y[k], "%s.%s" % (p, k))
            if r:
                return r
        return None
    if isinstance(x, list):
        if len(x) != len(y):
            return "%s: len %d vs %d" % (p, len(x), len(y))
        for i, (u, v) in enumerate(zip(x, y)):
            r = eq(u, v, "%s[%d]" % (p, i + 1))
            if r:
                return r
        return None
    return None if x == y else "%s: %r vs %r" % (p, x, y)


def t0_counter():
    """(0) counter == luac on a real loadable SV (run 8), else on the smoke SV"""
    path = RUN8_SV if os.path.exists(RUN8_SV) else os.path.join(OUT, "ForeverDump.lua")
    if not os.path.exists(path):
        check(False, "svconst control file missing (%s)" % path)
        return
    p = subprocess.run(["luac5.1", "-l", "-p", path], capture_output=True, text=True)
    m = re.search(r"(\d+) constants, \d+ functions", p.stdout)
    n = svconst.scan_file(path, depth=1)["total"]
    check(m is not None and int(m.group(1)) == n, "svconst == luac5.1 -l on %s (%s vs %d)" % (
        "run 8 SV" if path == RUN8_SV else "smoke SV", m and m.group(1), n))
    # the special spellings the writers emit: NaN as 0/0 (<= 2.2.12) and (1e999-1e999) (2.2.13), +-inf as +-1e999, -0, 2^31+ integers, escapes
    snippet = ('X = {\n\t["nan"] = 0/0,\n\t["inf"] = 1e999,\n\t["ninf"] = -1e999,\n\t[5] = 0,\n\t[6] = -0,\n'
               '\t["big"] = 2147483648,\n\t["esc"] = "a\\n\\"b\\0",\n\t0/0, -- [1]\n'
               '\t["nan2"] = (1e999-1e999),\n\t(1e999-1e999), -- [2]\n}\n')   # v2.2.13 NaN spelling
    fn = os.path.join(OUT, "svconst-special.lua")
    with open(fn, "w") as f:
        f.write(snippet)
    try:
        p = subprocess.run(["luac5.1", "-l", "-p", fn], capture_output=True, text=True)
        m = re.search(r"(\d+) constants, \d+ functions", p.stdout)
        n = svconst.scan(snippet)["total"]
        check(m is not None and int(m.group(1)) == n, "svconst == luac5.1 -l on NaN/inf/-0/2^31/escapes (%s vs %d)"
              % (m and m.group(1), n))
    finally:
        os.remove(fn)


def t1_unit():
    p = subprocess.run(["lua5.1", "tests/svpack.lua", "ForeverDump"], cwd=ROOT, capture_output=True, text=True)
    say("  " + p.stdout.strip().replace("\n", "\n  "))
    check(p.returncode == 0, "tests/svpack.lua unit/edge suite")


def synth(tag, literals, nopack=False):
    out = os.path.join(OUT, "svpack-density-%s.lua" % tag)
    cmd = ["lua5.1", "tests/svpack_real.lua", "ForeverDump", "-", out, "--synth", str(literals)]
    if nopack:
        cmd.append("--no-pack")
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    lit = 0
    for ln in p.stdout.splitlines():
        if ln.startswith("literals="):
            lit = int(ln.split("=")[1])
    return out, p, lit


def ta_one(scale):
    limit = svconst.LUA51_MAXK
    target = RUN9_CONSTANTS * scale
    out, p, lit = synth("%dx" % scale, target)
    try:
        say("  " + p.stdout.strip().replace("\n", "\n  "))
        ok, err = lua_loads(out)
        k = svconst.scan_file(out, depth=1)["total"]
        mb = os.path.getsize(out) / 1048576 if os.path.exists(out) else 0
        check(lit >= 0.95 * target, "(a) %dx: generated %d distinct literals (target %d = %dx run 9)" % (scale, lit, target, scale))
        check(p.returncode == 0 and "svpack_real OK" in p.stdout,
              "(a) %dx: pack -> client-style write -> one chunk -> unpack exact %s" % (scale, p.stderr[-300:]))
        check(ok, "(a) %dx: packed SV (%.1f MB) loads in stock Lua 5.1 as one chunk %s" % (scale, mb, err))
        check(k <= limit * MARGIN, "(a) %dx: unique constants %d <= %d (10%% of %d)" % (scale, k, int(limit * MARGIN), limit))
        if scale == 10:
            raw = load(out)
            check(isinstance(raw.get("ForeverDumpLogDB"), dict) and "replay" in raw["ForeverDumpLogDB"]
                  and len(raw["ForeverDumpLogDB"]["replay"]["sessions"]) >= 1,
                  "(a) 10x: converter decodes the packed SV (LogDB.replay present)")
    finally:
        if os.path.exists(out):
            os.remove(out)


def ta_control():
    limit = svconst.LUA51_MAXK
    out, p, lit = synth("10x-control", RUN9_CONSTANTS * 10, nopack=True)
    try:
        ok, err = lua_loads(out)
        k = svconst.scan_file(out, depth=1)["total"]
        say("  info control 10x without packing: %d unique constants (%.0f%% of the limit), loads=%s %s"
            % (k, 100.0 * k / limit, ok, err))
        check(p.returncode == 0 and "loads=false constant table overflow" in p.stdout,
              "(a) control: the generator's own one-chunk load fails with constant table overflow")
        check(k > limit and not ok and "constant table overflow" in err,
              "(a) control: over the limit (%d > %d) and stock Lua refuses it - the counter and Lua agree" % (k, limit))
    finally:
        if os.path.exists(out):
            os.remove(out)


def tb_real():
    if not os.path.exists(RUN9_SV):
        say("  skip (b): real run 9 SV not on this box")
        return
    ok, err = lua_loads(RUN9_SV)
    check(not ok and "constant table overflow" in err, "(b) control: the original run 9 SV does not load (%s)" % err)
    out = os.path.join(OUT, "svpack-run9.lua")
    try:
        p = subprocess.run(["lua5.1", "tests/svpack_real.lua", "ForeverDump", RUN9_SV, out], cwd=ROOT, capture_output=True,
                           text=True)
        say("  " + p.stdout.strip())
        check(p.returncode == 0, "(b) run 9: packed file loads in stock Lua 5.1 + Lua unpack exact")
        ok, err = lua_loads(out)
        k = svconst.scan_file(out, depth=1)["total"]
        k0 = svconst.scan_file(RUN9_SV, depth=1)["total"]
        check(ok and k <= svconst.LUA51_MAXK * MARGIN, "(b) run 9: constants %d -> %d (limit %d)" % (k0, k, svconst.LUA51_MAXK))
        a = load(RUN9_SV)
        b = load(out)
        b.get("ForeverDumpDB", {}).pop("svpack", None)
        r = eq(a, b)
        check(r is None, "(b) run 9: converter decode of the packed file == parse of the original %s" % (r or ""))
    finally:
        if os.path.exists(out):
            os.remove(out)


def tc_formats():
    smoke = os.path.join(OUT, "ForeverDump.lua")
    if not os.path.exists(smoke):
        check(False, "(c) smoke SV missing (run tests/smoke.lua first)")
        return
    packed = os.path.join(OUT, "svpack-smoke.lua")
    lua = r'''
local ns = { Print = function() end, config = {} }
assert(loadfile("ForeverDump/SVPack.lua"))("ForeverDump", ns)
local P = ns.SVPack
P.PLAIN_MAX = 0                       -- pack every var, even small ones
P.CHUNK_LITERALS, P.CHUNK_BYTES = 500, 20000   -- and force many chunks + grafts
assert(loadfile(arg[1]))()
P.PackAll()
local out = {}
local function q(s) return (string.format("%q", s):gsub("\\\n", "\\n")) end
local function w(v)
    local t = type(v)
    if t == "string" then out[#out + 1] = q(v) elseif t == "number" then out[#out + 1] = P.Num(v)
    elseif t == "boolean" then out[#out + 1] = tostring(v)
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            out[#out + 1] = "[" .. (type(k) == "string" and q(k) or P.Num(k)) .. "]="
            w(x) out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    end
end
for _, n in ipairs(P.Names()) do if _G[n] ~= nil then out[#out + 1] = "\n" .. n .. " = " w(_G[n]) out[#out + 1] = "\n" end end
local f = assert(io.open(arg[2], "w")) f:write(table.concat(out)) f:close()
'''
    try:
        p = subprocess.run(["lua5.1", "-", smoke, packed], input=lua, cwd=ROOT, capture_output=True, text=True)
        check(p.returncode == 0, "(c) smoke SV packed (all vars, forced small chunks) %s" % p.stderr[-300:])
        a = load(smoke)
        b = load(packed)
        info = dict(svpack.LAST)
        for raw in (a, b):
            raw.get("ForeverDumpDB", {}).pop("svpack", None)
        r = eq(a, b)
        check(r is None and len(info) >= 3, "(c) converter: plain and packed smoke SV parse identically (%d packed vars, %d chunks) %s"
              % (len(info), sum(v.get("chunks") or 0 for v in info.values()), r or ""))
        braw = load(packed, unpack=False)
        check(any(svpack.is_packed(v) for v in braw.values()), "(c) unpack=False returns the packed form")
    finally:
        if os.path.exists(packed):
            os.remove(packed)


TESTS = {"t0_counter": lambda: t0_counter(), "t1_unit": lambda: t1_unit(), "tc_formats": lambda: tc_formats(),
         "ta_2x": lambda: ta_one(2), "ta_10x": lambda: ta_one(10), "ta_control": lambda: ta_control(),
         "tb_real": lambda: tb_real()}


def run(name):
    """one part in its own process (CPU-heavy Python parsing/counting would serialize on the GIL in threads)"""
    import time
    _buf.out = io.StringIO()
    del FAILS[:]
    t0 = time.time()
    try:
        TESTS[name]()
    except Exception as e:  # noqa: BLE001 - a crash is a failure, reported with the test name
        check(False, "%s crashed: %r" % (name, e))
    say("  time %s %.1f s" % (name, time.time() - t0))
    return name, _buf.out.getvalue(), list(FAILS)


def main():
    """independent parts run in parallel processes; output stays grouped per part, in a fixed order"""
    os.makedirs(OUT, exist_ok=True)
    names = list(TESTS)
    workers = int(os.environ.get("FD_TEST_JOBS", "0")) or min(len(names), os.cpu_count() or 2)
    fails = []
    with ProcessPoolExecutor(max_workers=workers) as ex:
        for name, out, f in ex.map(run, names):
            print("[%s]" % name)
            sys.stdout.write(out)
            fails += f
    print("test_v2211_svpack %s: %d failure(s)" % ("OK" if not fails else "FAILED", len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
