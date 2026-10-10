#!/usr/bin/env python3
"""v2.2.13 division audit (run 10: SVPack `1 / v` raised "Division by zero" in the client and every pack failed).

The WoW client's Lua raises on x / 0 and x % 0 (stock Lua 5.1 returns inf / nan). This lint compiles every addon file
with luac -l and checks every DIV / MOD instruction:
  * a constant divisor must be non-zero;
  * a variable divisor must be a reviewed site in ALLOW below (file, source-line substring, why it cannot be 0).
SVPack.lua (pack/unpack) may contain no variable-divisor site except the Estimate one (a module constant).
A new division needs a reviewed entry here; never loosen this by allowing a whole file."""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "ForeverDump")
LUAC = os.environ.get("LUAC", "luac5.1")

ALLOW = [  # (file, substring of the source line, reason the divisor is never 0)
    ("AuraPresence.lua", "AP.WALL_SHARE * 1000 / per", "per = costMs or COST_INIT, reset to COST_INIT unless > 0"),
    ("AuraPresence.lua", "AP.PERIOD / units)", "units = #FIXED + ROTATE >= 4"),
    ("AuraPresence.lua", "(step - job.visit % step) % step", "step = TIER_EVERY[t] > 1 in this branch (step <= 1 -> 1)"),
    ("AuraPresence.lua", "checks % AP.CHECK_EVERY", "CHECK_EVERY constant 8"),
    ("AuraPresence.lua", "spent / checks", "guarded checks >= CHECK_EVERY"),
    ("AuraPresence.lua", "#pl.W / AP.TIER_EVERY.W + #pl.C / AP.TIER_EVERY.C", "TIER_EVERY constants 3 / 10"),
    ("AuraPresence.lua", "((cpv + AP.UNIT_EXTRA) * per)", "UNIT_EXTRA 12 > 0, per reset to COST_INIT unless > 0"),
    ("Baseline.lua", "h % 256", "constant"), ("Baseline.lua", "hb % 2, r % 2", "constant"),
    ("Baseline.lua", "% 4294967296", "constant"),
    ("Baseline.lua", "avg = s / #lat", "guarded #lat > 0"),
    ("CVars.lua", "count % 100", "constant"),
    ("CombatLog.lua", "% size + 1", "size = max(100, ...)"),
    ("Core.lua", "done * 100 / total", "guarded total > 0"),
    ("DamageMeter.lua", "1 / math.max(0.5, hz)", "max(0.5, .)"),
    ("Drift.lua", "math.max(it.a + it.x, 1e-9)", "max"), ("Drift.lua", "math.max(it.xn, 1e-9)", "max"),
    ("Extras.lua", "% 200 == 0", "constant"), ("Extras.lua", "% 50 == 0", "constant"), ("Extras.lua", "% 25 == 0", "constant"),
    ("Globals.lua", "% 500 == 0", "constant"), ("Globals.lua", "% 200 == 0", "constant"), ("Globals.lua", "% 1000 == 0", "constant"),
    ("HybridState.lua", "d % self.healPeriod", "guarded healPeriod > 0 (onBeat)"),
    ("HybridState.lua", "local ph = d % P", "summonBeat: returns early when P <= 0 (v2.2.15)"),
    ("HybridState.lua", "local m = sum / #ct", "c-cad-amount: else-branch of #ct == 0 (v2.2.15)"),
    ("HybridState.lua", "wu.dtps = amt / dt", "guarded dt > 0.05"),
    ("HybridState.lua", "local err = math.abs(h.cur - cur) / max", "CandHealthActual: returns early unless max > 0 (v2.2.16)"),
    ("HybridState.lua", "amt / (r.max or r.min)", "guarded > 0"),
    ("HybridState.lua", "c[(n + 1) / 2]", "constant"), ("HybridState.lua", "(i - i % 2) / 2", "constant"),
    ("HybridState.lua", "cd.rr % k + 1", "guarded k == 0 -> break"),
    ("Perf.lua", "/ P.WINDOW", "module constant 1"), ("Perf.lua", "total / (dur * 10)", "guarded dur > 0"),
    ("Perf.lua", "h.ms / math.max(h.n, 1)", "max"), ("Perf.lua", "(r.totalMs or 0) / (dur * 10)", "guarded dur > 0"),
    ("Protected.lua", "% 500 == 0", "constant"),
    ("Recorder.lua", "% size + 1", "size = max(100, ...)"),
    ("ReplayLog.lua", "% 65521", "constant"), ("ReplayLog.lua", "% cap + 1", "tapeCap() >= 1"),
    ("ReplayLog.lua", "% 2147483647", "constant"), ("ReplayLog.lua", "(est / 1048576) / (dur / 60)", "guarded dur > 0"),
    ("ReplayLog.lua", "state.castN % every", "every = max(1, .)"),
    ("SVPack.lua", "l / P.CHUNK_LITERALS", "module constant (Estimate, not pack/unpack)"),
    ("Secrets.lua", "% #sweepList + 1", "inside while guard < #sweepList"),
    ("Static.lua", "% 4294967296", "constant"),
    ("Timing.lua", "e.gcdSum / e.gcdN", "gcdN >= minN >= 1"), ("Timing.lua", "e.cdSum / e.cdN", "cdN >= minN >= 1"),
    ("Verify.lua", "d.head % size + 1", "cap() >= 1"),
    ("World.lua", "% 100 == 0", "constant"), ("World.lua", "% 300 == 0", "constant"), ("World.lua", "% 2000 == 0", "constant"),
    ("World.lua", "% 20 == 0", "constant"),
    ("WorldCapture.lua", "st.pos % #st.list", "list refilled from a fixed non-empty token list when empty"),
]

INS = re.compile(r"^\s*\d+\s+\[(\d+)\]\s+(DIV|MOD)\s+(-?\d+) (-?\d+) (-?\d+)(.*)$")

def files():
    for d in (ADDON, os.path.join(ADDON, "Lib")):
        for n in sorted(os.listdir(d)):
            if n.endswith(".lua"):
                yield os.path.join(d, n)

def main():
    bad, sites, used = [], 0, set()
    for path in files():
        base = os.path.basename(path)
        src = open(path, encoding="utf-8").read().split("\n")
        out = subprocess.run([LUAC, "-l", "-p", path], capture_output=True, text=True, check=True).stdout
        for line in out.split("\n"):
            m = INS.match(line)
            if not m:
                continue
            sites += 1
            ln, op, c, rest = int(m.group(1)), m.group(2), int(m.group(5)), m.group(6)
            text = src[ln - 1]
            if c < 0:  # RK constant: its value is in the comment
                vals = rest.split(";")[-1].split() if ";" in rest else []
                try:
                    if float(vals[-1]) == 0:
                        bad.append("%s:%d %s by constant 0: %s" % (base, ln, op, text.strip()))
                    continue
                except (ValueError, IndexError):
                    pass
            hit = [a for a in ALLOW if a[0] == base and a[1] in text]
            if not hit:
                bad.append("%s:%d %s with a variable divisor, not reviewed: %s" % (base, ln, op, text.strip()))
            for a in hit:
                used.add(a)
    # SVPack pack/unpack: no unreviewed site at all (checked above), and the one allowed site must be the Estimate one
    sv = open(os.path.join(ADDON, "SVPack.lua"), encoding="utf-8").read()
    sv = "\n".join(ln.split("--", 1)[0] for ln in sv.split("\n"))   # code only (comments may quote the old probe)
    if re.search(r"\b1\s*/\s*v\b", sv) or "0/0" in sv:
        bad.append("SVPack.lua: '1 / v' sign probe or a 0/0 NaN spelling is back (run 10)")
    stale = [a for a in ALLOW if a not in used and a[2] != "constant"]
    if stale:
        bad.append("stale ALLOW entries (remove them): %r" % stale)
    for b in bad:
        print("FAIL", b)
    print("div lint: %d DIV/MOD sites, %d reviewed variable-divisor entries, %d problems" % (sites, len(used), len(bad)))
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main())
