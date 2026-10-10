#!/usr/bin/env python3
"""v2.2.11 test runner (tests/run_converter_tests.sh calls it): the same commands as before, every one of them, with
per-test wall times. Phases keep the data dependencies: phase 1 produces the shared fixtures (smoke ->
tests/out/ForeverDump.lua, hsm -> tests/out/hsm_sv.lua) next to the lints; phase 2 runs everything else in parallel;
perf-measuring gates run in phase 3 with fewer neighbours (their limits are CPU-time based, unchanged).
A test passes only on exit code 0 (same as `set -eo pipefail`). Output of each test is kept in tests/out/runner/<id>.log
and the last line(s) printed like before.
usage: python3 tests/runner.py [-j N] [--serial] [--only REGEX] [--timing tests/out/runner/timing.json]"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TZS = ["America/New_York", "UTC", "Asia/Kolkata", "Pacific/Chatham", "America/St_Johns", "Pacific/Kiritimati",
       "Pacific/Pago_Pago"]

# (id, phase, shell command, lines of output to show)
TESTS = [
    # phase 0 = background: no fixture dependency (own replays), started first and running across phases 1-3
    ("test_v2210_dmrle_run8", 0, "python3 tests/test_v2210_dmrle.py Run8 2>&1", 1),
    ("test_v2210_dmrle_synth", 0, "python3 tests/test_v2210_dmrle.py Synthetic Expander 2>&1", 1),
    ("luac", 1, "luac5.1 -p ForeverDump/*.lua ForeverDump/Lib/*.lua", 1),
    # luacheck is a system tool, not game code: it runs on the stock interpreter (its constant folder divides by zero)
    ("luacheck", 1, '"$FD_STOCK_LUA" "$(command -v luacheck)" ForeverDump tests --no-color -q --exclude-files "tests/legacy_addon/*"', 1),
    ("smoke", 1, "lua5.1 tests/smoke.lua ForeverDump tests/out/ForeverDump.lua", 1),
    ("hsm", 1, "lua5.1 tests/hsm.lua ForeverDump", 1),
    ("taint_run9", 1, "lua5.1 tests/taint_run9.lua ForeverDump", 1),
    ("bg_chat_taint", 1, "lua5.1 tests/bg_chat_taint.lua ForeverDump", 1),
    ("version_visibility", 1, "lua5.1 tests/version_visibility.lua ForeverDump", 1),
    ("lab_v2215", 1, "lua5.1 tests/lab_v2215.lua ForeverDump", 1),
    ("attr_v2216", 1, "lua5.1 tests/attr_v2216.lua ForeverDump", 1),
    ("derive_v2218", 1, "lua5.1 tests/derive_v2218.lua ForeverDump", 1),
    ("audit_t_v2222", 1, "lua5.1 tests/audit_t_v2222.lua ForeverDump", 1),
    ("test_v2222_audit", 2, "python3 tests/test_v2222_audit.py", 1),
    ("test_v2223", 2, "python3 tests/test_v2223.py", 1),
    ("v2224_friend", 1, "lua5.1 tests/v2224_friend.lua ForeverDump", 1),
    ("v2225_exact", 1, "lua5.1 tests/v2225_exact.lua ForeverDump", 1),
    ("v2225_env_aura", 1, "lua5.1 tests/v2225_env_aura.lua ForeverDump", 1),
    ("v2226_aura", 1, "lua5.1 tests/v2226_aura.lua ForeverDump", 1),
    ("v2227_dynamic", 1, "lua5.1 tests/v2227_dynamic.lua ForeverDump", 1),
    ("v2228_run22", 1, "lua5.1 tests/v2228_run22.lua ForeverDump", 1),
    ("v2228_coldstart", 1, "lua5.1 tests/v2228_coldstart.lua ForeverDump", 1),
    ("v2229_sched", 1, "lua5.1 tests/v2229_sched.lua ForeverDump", 1),
    ("test_v2229_replay", 2, "python3 tests/test_v2229_replay.py", 1),
    ("test_learnedauras", 2, "python3 tests/test_learnedauras.py", 1),
    ("test_v2225", 2, "python3 tests/test_v2225.py", 1),
    ("test_pvescript", 2, "python3 tests/test_pvescript.py", 1),
    ("test_run22_tools", 2, "python3 tests/test_run22_tools.py", 1),
    ("oocfill_v2219", 1, "lua5.1 tests/oocfill_v2219.lua ForeverDump", 1),
    ("bgentry_v2220", 1, "lua5.1 tests/bgentry_v2220.lua ForeverDump", 1),
    ("raw_identity", 1, "lua5.1 tests/raw_identity.lua ForeverDump", 1),
    ("dm_session_bg", 1, "lua5.1 tests/dm_session_bg.lua ForeverDump", 1),
    ("knowledge_parse", 1, "lua5.1 tests/knowledge_parse.lua ForeverDump", 1),
    ("timing", 1, "lua5.1 tests/timing.lua ForeverDump", 1),
    ("learned", 1, "lua5.1 tests/learned.lua ForeverDump", 1),
    ("buggrabber", 1, "lua5.1 tests/buggrabber.lua ForeverDump", 1),
    ("test_converter", 2, "python3 tests/test_converter.py", 1),
    ("test_xref", 2, "python3 tests/test_xref.py", 1),
    ("test_migrate", 2, "python3 tests/test_migrate.py", 1),
    ("regress", 1, "lua5.1 tests/regress.lua ForeverDump", 1),
    ("test_v22", 2, "python3 tests/test_v22.py", 1),
    ("test_identity", 2, "python3 tests/test_identity.py", 1),
    ("test_v222", 2, "python3 tests/test_v222.py", 1),
    ("busted_containers", 1, "busted tests/spec/containers_spec.lua", 1),
    ("test_v223", 2, "python3 tests/test_v223.py", 1),
    ("test_v224", 2, "python3 tests/test_v224.py", 1),
    ("test_v224_tools", 2, "python3 tests/test_v224_tools.py", 1),
    ("test_v225_ho", 2, "python3 tests/test_v225_ho.py", 1),
    ("test_v225_findings", 2, "python3 tests/test_v225_findings.py", 1),
    ("test_v226_replay", 2, "python3 tests/test_v226_replay.py", 1),
    ("test_v226_replay_exec", 2, "python3 tests/test_v226_replay_exec.py", 1),
    ("test_v226_reconcile", 2, "python3 tests/test_v226_reconcile.py", 1),
    ("test_golden_run5", 2, "python3 tests/test_golden_run5.py", 1),
    ("perfcheck", 1, "python3 tools/fdump.py perfcheck ForeverDump --strict", 1),
    ("perf_bench", 3, "timeout 120 lua5.1 tests/perf_bench.lua ForeverDump --assert --json tests/out/perf_bench.json", 1),
    ("sv_bench_test", 2, "lua5.1 tests/sv_serialize_bench.lua test", 2),
    ("sv_bench_release", 2, "lua5.1 tests/sv_serialize_bench.lua release", 2),
    ("sv_bench_diag", 2, "lua5.1 tests/sv_serialize_bench.lua diag", 2),
    ("bg_replay_gate", 3, "python3 tests/bg_replay_gate.py", 3),
    ("bg_replay_lab", 3, "python3 tests/bg_replay_gate.py --level lab", 3),
    ("perf_bench_lab", 3, "timeout 120 lua5.1 tests/perf_bench.lua ForeverDump --assert --level lab --no-raid", 1),
    ("test_v227_lint", 1, "python3 tests/test_v227_lint.py", 1),
    ("combat_guard", 1, "lua5.1 tests/combat_guard.lua ForeverDump", 1),
    ("hsm_alive", 1, "lua5.1 tests/hsm_alive.lua ForeverDump", 1),
    ("worldcap_pack", 1, "lua5.1 tests/worldcap_pack.lua ForeverDump", 1),
    ("hsm_health_degraded", 1, "lua5.1 tests/hsm_health.lua ForeverDump degraded", 1),
    ("hsm_health_down", 1, "lua5.1 tests/hsm_health.lua ForeverDump down", 1),
    ("hsm_health_guard", 1, "lua5.1 tests/hsm_health.lua ForeverDump guard", 1),
    ("run8_stack", 1, "lua5.1 tests/run8_regress.lua ForeverDump stack", 1),
    ("run8_macro", 1, "lua5.1 tests/run8_regress.lua ForeverDump macro", 1),
    ("test_v229_run8", 2, "python3 -W ignore tests/test_v229_run8.py 2>&1", 1),
    ("test_v227_secret_lint", 1, "python3 tests/test_v227_secret_lint.py", 1),
    # v2.2.11: the 7 injection modes split over 4 parallel jobs (together = all modes, same checks per job; elems and
    # whole never reach the HybridState boundary guard on their own and elems leaves no S codes as the last mode, so
    # each rides with a mode that does; subsets keep the list order)
    ("secret_inject_a", 2, "FD_INJECT_MODES=SB,whole lua5.1 tests/secret_inject.lua ForeverDump", 1),
    ("secret_inject_b", 2, "FD_INJECT_MODES=SN,SS lua5.1 tests/secret_inject.lua ForeverDump", 1),
    ("secret_inject_c", 2, "FD_INJECT_MODES=typed lua5.1 tests/secret_inject.lua ForeverDump", 1),
    ("secret_inject_d", 2, "FD_INJECT_MODES=elems,mixed lua5.1 tests/secret_inject.lua ForeverDump", 1),
    ("static_once", 1, "lua5.1 tests/static_once.lua ForeverDump", 1),
    ("test_v227_findings", 2, "python3 tests/test_v227_findings.py", 1),
    ("test_v2216", 2, "python3 tests/test_v2216.py", 1),
    ("test_v2218", 2, "python3 tests/test_v2218.py", 1),
    ("test_v2219", 2, "python3 tests/test_v2219.py", 1),
    ("test_v2220", 2, "python3 tests/test_v2220.py", 1),
    ("test_v2221", 2, "python3 tests/test_v2221.py", 1),
    ("test_unhash_inclusion", 2, "python3 tests/test_unhash_inclusion.py", 1),
    # v2.2.11: the two round trips are independent -> two runner jobs (same assertions; each class runs its replays in parallel)
    ("test_master_guide", 2, "python3 -W ignore tests/test_master_guide.py 2>&1", 1),
    ("test_v2211_svpack", 2, "python3 -u tests/test_v2211_svpack.py 2>&1", 1),
    ("test_v2211_static", 2, "python3 tests/test_v2211_static.py", 1),
    ("capture_wipe", 1, "lua5.1 tests/capture_wipe.lua ForeverDump", 1),
    # v2.2.13 (run 10): every lua5.1 job runs under the WoW-like interpreter (x / 0 and x % 0 raise, see ensure_wowlua)
    ("svpack_div0", 1, "lua5.1 tests/svpack_div0.lua ForeverDump", 1),
    ("svpack_div0_v2212_fails", 1, "lua5.1 tests/svpack_div0.lua tests/fixtures/svpack_v2212 --expect-fail", 1),
    ("test_div_lint", 1, "python3 tests/test_div_lint.py", 1),
] + [("utcoffset_" + tz.replace("/", "_"), 1, "TZ=%s lua5.1 tests/utcoffset.lua ForeverDump" % tz, 1) for tz in TZS] \
  + [("tzmatrix_" + tz.replace("/", "_"), 2, "TZ=%s python3 tests/test_tz_matrix.py" % tz, 1) for tz in TZS] \
  + [("timelua_" + tz.replace("/", "_"), 1, "TZ=%s lua5.1 tests/time_lua.lua ForeverDump" % tz, 1) for tz in TZS] \
  + [("pvescript_" + tz.replace("/", "_"), 2, "TZ=%s python3 tests/test_pvescript.py" % tz, 1) for tz in TZS] \
  + [("v2225_" + tz.replace("/", "_"), 2, "TZ=%s python3 tests/test_v2225.py" % tz, 1) for tz in TZS]


def ensure_wowlua():
    """v2.2.13: build (cached) the WoW-like Lua 5.1 (tests/build_wowlua.sh) and put it first on PATH as lua5.1 for every
    job. No silent fallback to stock Lua: stock 5.1 returns inf/nan on x / 0 where the client raises (run 10)."""
    p = subprocess.run(["bash", os.path.join(ROOT, "tests", "build_wowlua.sh")], cwd=ROOT, capture_output=True, text=True)
    binp = (p.stdout or "").strip().splitlines()[-1:] if p.returncode == 0 else []
    if not binp or not os.path.isfile(binp[0]):
        sys.stderr.write("runner: cannot build the WoW-like lua5.1 (tests/build_wowlua.sh):\n%s%s\n" % (p.stdout, p.stderr))
        sys.exit(2)
    shim = os.path.join(ROOT, ".cache", "wowlua", "path")
    # the stock interpreter = lua5.1 on PATH without the shim (a caller may already have the shim on PATH)
    clean = os.pathsep.join(d for d in os.environ.get("PATH", "").split(os.pathsep) if os.path.abspath(d) != shim)
    stock = subprocess.run(["bash", "-c", "command -v lua5.1"], capture_output=True, text=True,
                           env=dict(os.environ, PATH=clean)).stdout.strip()
    if not stock:
        sys.stderr.write("runner: no stock lua5.1 on PATH (needed for luacheck and the module paths)\n")
        sys.exit(2)
    os.environ["FD_STOCK_LUA"] = stock
    os.environ["PATH"] = clean
    # the system Lua tools (luacheck, busted) keep finding their modules (the build's default paths lack Debian's)
    for var, expr in (("LUA_PATH", "package.path"), ("LUA_CPATH", "package.cpath")):
        if var not in os.environ:
            q = subprocess.run([stock, "-e", "io.write(%s)" % expr], capture_output=True, text=True)
            if q.returncode == 0 and q.stdout:
                os.environ[var] = q.stdout
    os.makedirs(shim, exist_ok=True)
    for name in ("lua5.1", "lua"):
        link = os.path.join(shim, name)
        if os.path.islink(link) or os.path.exists(link):
            os.remove(link)
        os.symlink(binp[0], link)
    os.environ["PATH"] = shim + os.pathsep + os.environ.get("PATH", "")
    chk = subprocess.run(["bash", "-c", "lua5.1 -e 'if pcall(function() local z = 0 return 1 / z end) then os.exit(1) end'"],
                         capture_output=True, text=True)
    if chk.returncode != 0:
        sys.stderr.write("runner: lua5.1 on PATH does not raise on division by zero\n")
        sys.exit(2)
    return binp[0]


def run(t, logdir):
    tid, _phase, cmd, show = t
    t0 = time.time()
    p = subprocess.run(["bash", "-o", "pipefail", "-c", cmd], cwd=ROOT, capture_output=True, text=True)
    dt = time.time() - t0
    out = (p.stdout or "") + (p.stderr or "")
    with open(os.path.join(logdir, tid + ".log"), "w") as f:
        f.write(out)
    tail = [ln for ln in out.strip().splitlines() if ln.strip()][-show:] if out.strip() else []
    return tid, p.returncode, dt, tail


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-j", type=int, default=os.cpu_count() or 4)
    ap.add_argument("--serial", action="store_true", help="one test at a time (baseline timing)")
    ap.add_argument("--only", help="regex on test ids")
    ap.add_argument("--timing", default=os.path.join(ROOT, "tests", "out", "runner", "timing.json"))
    a = ap.parse_args()
    os.environ.setdefault("FORE_DOCS", os.path.join(ROOT, "ref", "wusf", "Interface", "AddOns"))
    wl = ensure_wowlua()
    print("lua5.1 = %s (WoW-like: / 0 and %% 0 raise)" % os.path.relpath(wl, ROOT))
    logdir = os.path.join(ROOT, "tests", "out", "runner")
    os.makedirs(logdir, exist_ok=True)
    tests = [t for t in TESTS if not a.only or re.search(a.only, t[0])]
    t_all = time.time()
    results, failed = {}, []
    phase_limits = {1: a.j, 2: a.j, 3: max(1, min(2, a.j))}
    bg = [t for t in tests if t[1] == 0]
    bg_ex, bg_fut = None, []
    if bg and not a.serial:
        bg_ex = cf.ThreadPoolExecutor(max_workers=len(bg))
        bg_fut = [bg_ex.submit(run, t, logdir) for t in bg]
        phase_limits = {1: max(1, a.j - len(bg)), 2: max(1, a.j - len(bg)), 3: max(1, min(2, a.j))}
    elif bg:
        for t in bg:
            tests.remove(t)
            tests.append((t[0], 1) + t[2:])
    for phase in (1, 2, 3):
        batch = [t for t in tests if t[1] == phase]
        if not batch:
            continue
        workers = 1 if a.serial else phase_limits[phase]
        # longest first (from the last timing file) so the pool drains evenly
        prev = {}
        if os.path.exists(a.timing):
            try:
                prev = json.load(open(a.timing)).get("tests", {})
            except ValueError:
                prev = {}
        batch.sort(key=lambda t: -prev.get(t[0], {}).get("sec", 0))
        p0 = time.time()
        with cf.ThreadPoolExecutor(max_workers=workers) as ex:
            for tid, rc, dt, tail in ex.map(lambda t: run(t, logdir), batch):
                results[tid] = {"sec": round(dt, 2), "rc": rc, "phase": phase}
                mark = "ok  " if rc == 0 else "FAIL"
                print("[%s %6.1fs] %-26s %s" % (mark, dt, tid, " | ".join(tail)[:220]), flush=True)
                if rc != 0:
                    failed.append(tid)
        print("-- phase %d: %d test(s) in %.1fs wall (%d worker(s))" % (phase, len(batch), time.time() - p0, workers), flush=True)
    if bg_ex:
        for t, fu in zip(bg, bg_fut):
            tid, rc, dt, tail = fu.result()
            results[tid] = {"sec": round(dt, 2), "rc": rc, "phase": 0}
            print("[%s %6.1fs] %-26s %s" % ("ok  " if rc == 0 else "FAIL", dt, tid, " | ".join(tail)[:220]), flush=True)
            if rc != 0:
                failed.append(tid)
        bg_ex.shutdown()
        print("-- background: %d test(s)" % len(bg), flush=True)
    wall = time.time() - t_all
    cpu_sum = sum(r["sec"] for r in results.values())
    with open(a.timing, "w") as f:
        json.dump({"wall": round(wall, 1), "sumOfTests": round(cpu_sum, 1), "serial": a.serial, "jobs": a.j,
                   "tests": results}, f, indent=1, sort_keys=True)
    print("RUNNER %s: %d test(s), %d failed %s; wall %.1fs (sum of test times %.1fs)" % (
        "OK" if not failed else "FAILED", len(results), len(failed), failed if failed else "", wall, cpu_sum))
    print("RUNNER_EXIT:%d" % (1 if failed else 0))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
