"""v2.2.11 (user decision) static lint: the static dump is collected ONLY by the slash command `/fdump static run`
(`force` = alias). Fails if any code path other than the slash handler can start it:
  1 ST.Start is called exactly once in the addon, in Commands.lua, inside the `static` slash branch, with "slash"
  2 ST.Start refuses any other reason (guard present in Static.lua)
  3 Static.lua registers no event (no ns.On / RegisterEvent / C_Timer path that reaches Start) and ST.Check never calls Start
  4 /fdump all and ns.RunAll skip static sections (no RunSection of a static section outside Static.lua's step())
  5 runtime: tests/static_once.lua (login, new build, /fdump all, FD_Logs ON never run it; the slash command does)"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "ForeverDump")
FAILS = []


def check(c, m):
    print(("  ok   " if c else "  FAIL ") + m)
    if not c:
        FAILS.append(m)


def code(path):
    out = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            out.append(re.sub(r"--.*$", "", line.rstrip("\n")))
    return out


def main():
    files = []
    for dp, _, fns in os.walk(ADDON):
        files += [os.path.join(dp, f) for f in fns if f.endswith(".lua")]
    calls = []
    for p in files:
        for i, line in enumerate(code(p), 1):
            if re.search(r"Static\.Start\s*\(|\bST\.Start\s*\(", line) and not re.search(r"function\s+ST\.Start", line):
                calls.append((os.path.relpath(p, ADDON), i, line.strip()))
    check(len(calls) == 1 and calls[0][0] == "Commands.lua" and '"slash"' in calls[0][2],
          "exactly one ST.Start call, the slash command: %s" % calls)
    if calls and calls[0][0] == "Commands.lua":
        lines = code(os.path.join(ADDON, "Commands.lua"))
        ctx = "\n".join(lines[max(0, calls[0][1] - 12):calls[0][1]])
        check('cmd == "static"' in ctx and 'sub == "run"' in ctx, "the call sits in the `static run|force` slash branch")
    st = "\n".join(code(os.path.join(ADDON, "Static.lua")))
    check(re.search(r'function ST\.Start\(why\)\s*\n\s*if why ~= "slash" then return false', st) is not None,
          "ST.Start refuses every reason except \"slash\"")
    check(not re.search(r"ns\.On\(|RegisterEvent|SetScript", st), "Static.lua hooks no event / script")
    chk = st[st.find("function ST.Check()"):]
    chk = chk[:chk.find("\nend") + 4]
    check("Start" not in chk and "step" not in chk and "after(" not in chk, "ST.Check only reports")
    cmds = "\n".join(code(os.path.join(ADDON, "Commands.lua")))
    allb = cmds[cmds.find('cmd == "all"'):cmds.find('cmd == "static"')]
    check("IsStatic(name)" in allb and "RunAll()" not in allb, "/fdump all skips static sections")
    ra = cmds[cmds.find("function ns.RunAll()"):]
    ra = ra[:ra.find("\nend") + 4]
    check("IsStatic(name)" in ra, "ns.RunAll skips static sections")
    p = subprocess.run(["lua5.1", "tests/static_once.lua", "ForeverDump"], cwd=ROOT, capture_output=True, text=True)
    check(p.returncode == 0, "runtime: " + (p.stdout.strip().splitlines() or ["?"])[-1])
    print("test_v2211_static %s: %d failure(s)" % ("OK" if not FAILS else "FAILED", len(FAILS)))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
