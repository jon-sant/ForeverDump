"""v2.2.7 static lint (permanent): bans the run-6 error patterns in the addon.

R1 combat-protected APIs (ns.COMBAT_PROTECTED in Core.lua) may only be called behind a combat guard.
R2 no hooks: hooksecurefunc( / :HookScript( are never called (v2.2 rule; run 2 trampoline nil-calls).
R3 no bare `os.` (WoW has no os table; run 6 Drift.lua:156) - only as a fallback after `or`/`and`.
R4 hot/capture paths never truth-test a pcall result value (`ok and v or nil`; run 6 DamageMeter.lua:51 secret boolean).
R5 Errors.onBlock never prints synchronously (run 6: 47 prints into ChatFrame1 from inside the blocked call).
R6 no ForeverDump code touches ObjectiveTracker objects except the read-only UI signature in Core.lua.
R7 capture slices (Tokens, WorldCapture) compute ns.CombatLocked() once per slice.
usage: python3 tests/test_v227_lint.py
"""
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "ForeverDump")
HOT = {"DamageMeter.lua", "Tokens.lua", "WorldCapture.lua", "Inference.lua", "ReplayLog.lua", "CombatLog.lua",
       "Recorder.lua", "HSMUI.lua", "Errors.lua", "Restrictions.lua", "Learned.lua", "Identity.lua", "Timing.lua",
       "CombatProbe.lua", "HybridState.lua"}
GUARD_TOKENS = ("CombatGuard", "combatSkip(", "CombatSkip(", "PROT[", "st.locked")


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def lua_files():
    for dp, _, fns in os.walk(ADDON):
        for fn in fns:
            if fn.endswith(".lua"):
                yield os.path.join(dp, fn)


def code_lines(path):
    """(lineno, code-without-comment, raw) with long comments and -- comments removed; strings kept."""
    out, in_long = [], False
    for i, raw in enumerate(read(path).splitlines(), 1):
        line = raw
        if in_long:
            if "]]" in line:
                line = line.split("]]", 1)[1]
                in_long = False
            else:
                out.append((i, "", raw))
                continue
        if "--[[" in line:
            head, tail = line.split("--[[", 1)
            if "]]" not in tail:
                in_long = True
            line = head
        # strip -- comments that are not inside a string (good enough for this codebase: no "--" in strings checked)
        m = re.search(r'--(?![^"]*"(?:[^"]*"[^"]*")*[^"]*$)', line)
        if m:
            line = line[:m.start()]
        out.append((i, line, raw))
    return out


def strip_strings(s):
    return re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', s)


def protected_apis():
    core = read(os.path.join(ADDON, "Core.lua"))
    m = re.search(r"ns\.COMBAT_PROTECTED\s*=\s*\{([^}]*)\}", core)
    assert m, "ns.COMBAT_PROTECTED missing in Core.lua"
    names = re.findall(r'(?:\["([\w.]+)"\]|(\w+))\s*=\s*true', m.group(1))
    return sorted({a or b for a, b in names})


class Lint(unittest.TestCase):
    def test_r1_protected_apis_guarded(self):
        apis = protected_apis()
        self.assertIn("CheckInteractDistance", apis)
        bad = []
        for path in lua_files():
            fn = os.path.basename(path)
            if fn == "Core.lua":
                continue
            lines = code_lines(path)
            text = "\n".join(c for _, c, _ in lines)
            for idx, (no, code, raw) in enumerate(lines):
                for api in apis:
                    if not re.search(r'(?<![\w.])' + re.escape(api) + r'(?!\w)', code):
                        continue
                    # declarative table rows (Tokens FIELDS, CombatProbe item lists): the reader loop must guard
                    if re.match(r'\s*\{\s*"', code) or re.match(r'\s*\{\s*"[\w.]+"\s*,\s*"', code):
                        if fn == "Tokens.lua" and "PROT[fd[2]]" in text:
                            continue
                        if fn == "CombatProbe.lua" and "combatSkip(" in text and "COMBAT_SKIP" in text:
                            continue
                    if re.search(r'^\s*local\s+COMBAT_SKIP\s*=', code):
                        continue
                    window = "\n".join(c for _, c, _ in lines[max(0, idx - 8): idx + 3])
                    if any(tok in window for tok in GUARD_TOKENS):
                        continue
                    if fn in ("Probe.lua",) and "InCombat" in window:
                        continue
                    bad.append("%s:%d %s" % (fn, no, raw.strip()[:100]))
        self.assertEqual(bad, [], "combat-protected API without a combat guard:\n" + "\n".join(bad))

    def test_r2_no_hooks(self):
        bad = []
        for path in lua_files():
            for no, code, raw in code_lines(path):
                c = strip_strings(code)
                if re.search(r'\bhooksecurefunc\s*\(|:HookScript\s*\(', c):
                    bad.append("%s:%d %s" % (os.path.basename(path), no, raw.strip()[:100]))
        self.assertEqual(bad, [], "hooks are banned:\n" + "\n".join(bad))

    def test_r3_no_bare_os(self):
        bad = []
        for path in lua_files():
            for no, code, raw in code_lines(path):
                c = strip_strings(code)
                for m in re.finditer(r'(?<![\w.])os\.\w+', c):
                    before = c[:m.start()]
                    if re.search(r'(\bor|\band|\(os\s+and|rawget\(_G,\s*""\)\s+and)\s*\(?\s*$', before):
                        continue
                    bad.append("%s:%d %s" % (os.path.basename(path), no, raw.strip()[:100]))
        self.assertEqual(bad, [], "bare os.* (no os table in WoW):\n" + "\n".join(bad))

    def test_r4_no_truth_test_of_pcall_value(self):
        bad = []
        for path in lua_files():
            if os.path.basename(path) not in HOT:
                continue
            for no, code, raw in code_lines(path):
                if re.search(r'\bok\w*\s+and\s+[A-Za-z_][\w.]*\s+or\s+(nil|false)\b', strip_strings(code)):
                    bad.append("%s:%d %s" % (os.path.basename(path), no, raw.strip()[:100]))
        self.assertEqual(bad, [], "truth test of a possibly-secret pcall value:\n" + "\n".join(bad))

    def test_r5_onblock_no_sync_print(self):
        src = read(os.path.join(ADDON, "Errors.lua"))
        m = re.search(r"local function onBlock\(event, \.\.\.\)(.*?)\nend\n", src, re.S)
        self.assertTrue(m, "onBlock not found")
        body = "\n".join(l for l in m.group(1).splitlines() if not l.strip().startswith("--"))
        self.assertNotIn("ns.Print(", body)
        self.assertIn("deferPrint(", body)

    def test_r6_objective_tracker_read_only(self):
        bad = []
        for path in lua_files():
            fn = os.path.basename(path)
            for no, code, raw in code_lines(path):
                c = strip_strings(code)
                if re.search(r'ObjectiveTracker', c):
                    bad.append("%s:%d %s" % (fn, no, raw.strip()[:100]))
        self.assertEqual(bad, [], "ObjectiveTracker referenced outside quoted read-only names:\n" + "\n".join(bad))

    def test_r7_capture_slices_lock_once(self):
        for fn in ("Tokens.lua", "WorldCapture.lua"):
            src = read(os.path.join(ADDON, fn))
            self.assertIn("ns.CombatLocked()", src, fn + ": slice must compute ns.CombatLocked() once")


if __name__ == "__main__":
    r = unittest.main(exit=False, verbosity=1).result
    n = r.testsRun
    print("test_v227_lint: %d checks, %d failed" % (n, len(r.failures) + len(r.errors)))
    sys.exit(0 if r.wasSuccessful() else 1)
