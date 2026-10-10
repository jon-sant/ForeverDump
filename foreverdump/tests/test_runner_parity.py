"""v2.2.11: tests/runner.py must run every test command of tests/run_converter_tests_serial.sh (no test dropped by the
parallel runner), and every secret_inject mode must be covered by the split jobs."""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tests"))
import runner  # noqa: E402

cmds = " ".join(t[2] for t in runner.TESTS)
miss = []
for ln in open(os.path.join(ROOT, "tests", "run_converter_tests_serial.sh")):
    ln = ln.strip()
    if not ln or ln.startswith(("#", "set ", "cd ", "mkdir", "export", "for ", "done")):
        continue
    core = ln.split("|")[0].replace("2>&1", "").strip()
    m = re.search(r"tests/[\w./]+", core)
    key = m.group(0) if m else core.split()[0]
    if key not in cmds:
        miss.append(ln)
modes = set()
for t in runner.TESTS:
    m = re.search(r"FD_INJECT_MODES=([\w,]+)", t[2])
    if m:
        modes |= set(m.group(1).split(","))
src = open(os.path.join(ROOT, "tests", "secret_inject.lua")).read()
allm = set(re.search(r"local MODES = \{([^}]*)\}", src).group(1).replace('"', "").replace(" ", "").split(","))
ok = not miss and modes == allm
print("runner parity %s: %d runner jobs; missing %s; inject modes %s/%s" % ("OK" if ok else "FAILED", len(runner.TESTS),
      miss, sorted(modes), sorted(allm)))
sys.exit(0 if ok else 1)
