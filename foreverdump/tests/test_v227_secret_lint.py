"""v2.2.7 permanent secret-value lint (run 6b: DamageMeter.lua:51 "boolean test on local 'v' (a secret boolean value)").

Contract for the modules that consume game-API values (SECRET_MODULES): a value returned by a game API - the 2nd+ result
of a pcall, a struct field read through field()/first(), an event payload argument, or any name spelled raw* - is
TRACKED. A tracked name may only be
  * passed to a classifier / clearing sink (ns.ClassifyValue, code, issecretvalue, ns.ClearNum/Str/Bool/Of/Table,
    ns.IsTrue, ns.IsNil, clear*, note, field, first, lenClear, sourceKind, rawequal, type, ...),
  * passed as an argument into pcall (errors stay contained),
  * returned unchanged (accessor pass-through) or aliased to another name (which becomes tracked too).
Anything else - `if v then`, `not v`, `v and`, `v or`, `v == x`, `x ~= v`, `<`/`>`, `v[`, `v.`, `v:`, `#v`, `..`,
arithmetic, storing it in a table constructor - is a violation.
S1 the taint-flow rule above.
S2 no `x and NAME or y` idiom (NAME a bare identifier) anywhere in SECRET_MODULES: it truth-tests NAME.
S3 no inline `select(2, pcall(...))` in SECRET_MODULES (the value escapes unclassified).
S4 Core: ClassifyValue/IsSecret start with type(v) == "nil" (no `v == nil` compare) and the clearing helpers exist.
usage: python3 tests/test_v227_secret_lint.py         (FD_LINT_ADDON=<dir> lints another tree, e.g. the v2.2.6 control)
"""
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.environ.get("FD_LINT_ADDON") or os.path.join(ROOT, "ForeverDump")
SECRET_MODULES = ["DamageMeter.lua", "WorldCapture.lua", "ReplayLog.lua", "Tokens.lua", "Identity.lua", "Inference.lua",
                  "OocFill.lua", "Derive.lua", os.path.join("Lib", "HybridState.lua")]
# v2.2.20 (run 15): Derive.lua joined after `channel and r[8] or r[10]` truth-tested a secret boolean in the BG (6
# selfErrors); S2 now also catches a numerically indexed operand (`and r[8] or`: packed pcall results)
# HybridState is a pure library behind a boundary guard (S5): its parameters are scrubbed before the body runs
FLOW_EXEMPT = {os.path.join("Lib", "HybridState.lua")}
SINKS = ("type", "code", "ClassifyValue", "IsSecret", "issecretvalue", "canaccessvalue", "issecrettable", "clear", "clearNum",
         "clearBool", "clearStr", "ClearNum", "ClearStr", "ClearBool", "ClearOf", "ClearWithCode", "ClearTable", "IsTrue", "IsNil", "isTrue",
         "isNil", "note", "field", "first", "lenClear", "sourceKind", "rawequal", "Scrub", "pcall", "isSecretValue",
         "hasSecret", "scrub", "count", "Shape", "IdKey", "classifyStruct", "OnCast", "ObserveEvent", "Walk",
         "auraSummary", "scrubDetail", "scrubSpell", "scrubSource",
         # v2.2.20 Derive.lua: record/baseName classify first; the handlers type-check / clearStr their arguments
         "record", "baseName", "hasRealm", "OnPower", "OnCastStart", "PlateColor",
         # v2.2.22 T-audit: fieldsOf/indexable only type()/code() the value and pcall(index) it; IsSecretValue classifies
         "fieldsOf", "FieldsOf", "indexable", "IsSecretValue")
HANDLERS = re.compile(r"function\s+(?:[\w.:]*[.:])?(OnEvent|onEvent|OnCast|onCast|onAura|onUnitCombat|onInterrupted|onTotem|"
                      r"OnSpellUpdateCooldown|auraSummary|scrubDetail|scrubSpell|scrubSource)\s*\(([^)]*)\)")
LUA_KW = {"and", "or", "not", "if", "then", "else", "elseif", "end", "do", "while", "for", "in", "function", "local",
          "return", "nil", "true", "false", "repeat", "until", "break"}


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def strip(line):
    """drop -- comments and blank string literal contents (keep the quotes)"""
    out, i, q = [], 0, None
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 2
                continue
            if c == q:
                q = None
                out.append(c)
            i += 1
            continue
        if c in "\"'":
            q = c
            out.append(c)
            i += 1
            continue
        if line.startswith("--", i):
            break
        out.append(c)
        i += 1
    return "".join(out)


def code_lines(path):
    lines, in_long = [], False
    for i, raw in enumerate(read(path).splitlines(), 1):
        line = raw
        if in_long:
            if "]]" in line:
                line, in_long = line.split("]]", 1)[1], False
            else:
                lines.append((i, ""))
                continue
        if "--[[" in line:
            head, tail = line.split("--[[", 1)
            if "]]" not in tail:
                in_long = True
            line = head
        lines.append((i, strip(line)))
    return lines


SINK_RE = "|".join(sorted(SINKS, key=len, reverse=True))


def _call_arg_context(before, after):
    """True when the occurrence is a direct argument of a sink call: SINK( ..., NAME [,)]"""
    if not re.match(r"\s*[,)]", after):
        return False
    depth, j = 0, len(before) - 1
    while j >= 0:
        ch = before[j]
        if ch == ")":
            depth += 1
        elif ch == "(":
            if depth == 0:
                m = re.search(r"(?:^|[^\w])(?:[\w.]*[.:])?(" + SINK_RE + r")\s*$", before[:j])
                return bool(m)
            depth -= 1
        elif ch in "{}" and depth == 0:
            return False
        j -= 1
    return False


def violations(path):
    out = []
    tracked = {}
    for ln, line in code_lines(path):
        if not line.strip():
            continue
        if re.match(r"^(local\s+)?function\b", line) or re.match(r"^\S.*=\s*function\s*\(", line):
            tracked = {}   # new top-level function: new scope
        hm = HANDLERS.search(line)
        if hm:
            for p in [x.strip() for x in hm.group(2).split(",")]:
                if p and p not in ("self", "event", "_", "...", "_args") and not p.startswith("max"):   # max*: config caps
                    tracked[p] = ln
        # bindings that create tracked names
        for m in re.finditer(r"(?:local\s+)?([\w\s,]+?)\s*=\s*(pcall|select\s*\(\s*2\s*,\s*pcall|field|first)\s*\(", line):
            names = [n.strip() for n in m.group(1).split(",")]
            if m.group(2) == "pcall":
                names = names[1:]
            for n in names:
                n = re.sub(r"^local\s+", "", n)
                if re.match(r"^[A-Za-z_]\w*$", n) and n not in ("_", "err", "msg", "errMsg"):
                    tracked[n] = ln
        for m in re.finditer(r"local\s+([\w\s,]+?)\s*=\s*\.\.\.", line):
            if any(hm2 for hm2 in [HANDLERS.search(line)]) or tracked:
                for n in [x.strip() for x in m.group(1).split(",")]:
                    if n:
                        tracked[n] = ln
        for m in re.finditer(r"\b(raw\w*)\b(?!\s*\()", line):
            if m.group(1) not in ("rawget", "rawequal", "rawset", "rawlen"):
                tracked.setdefault(m.group(1), ln)
        # alias / rebinding
        lhs_names = set()
        bind = re.match(r"^\s*(?:local\s+)?([\w\s,.\[\]\"]+?)\s*=(?!=)\s*(.*)$", line)
        if bind:
            lhs_names = {n.strip() for n in bind.group(1).split(",")}
            rhs = bind.group(2).strip()
            src_bind = re.match(r"(pcall|select\s*\(\s*2\s*,\s*pcall|field|first)\s*\(", rhs)
            for n in list(lhs_names):
                if n in tracked and not src_bind and not n.startswith("raw") and not re.match(r"^\w+\s*$", rhs):
                    if not (rhs in tracked):
                        del tracked[n]   # rebound to something else (e.g. a cleared copy)
            if re.match(r"^[A-Za-z_]\w*$", rhs) and rhs in tracked:
                for n in lhs_names:
                    if re.match(r"^[A-Za-z_]\w*$", n):
                        tracked[n] = ln
        for name in list(tracked):
            for m in re.finditer(r"(?<![\w.:])" + re.escape(name) + r"(?!\w)", line):
                before, after = line[:m.start()], line[m.end():]
                if re.match(r"\s*=(?!=)", after) or re.match(r"\s*,[\w\s,]*=(?!=)", after):
                    continue   # being assigned / bound
                if re.search(r"(?:^|[\s,(])local\s+[\w\s,]*$", before):
                    continue
                if re.search(r"function\b[\w\s.:]*\([\w\s,]*$", before):
                    continue   # parameter list
                if re.search(r"pcall\s*\(\s*function\s*\([^)]*\)", before) and re.search(r"\bend\s*\)", after):
                    continue   # inside a pcall'd closure on the same line: errors stay contained
                if _call_arg_context(before, after):
                    continue
                if re.search(r"\breturn\s+(?:\w+\s*,\s*)*$", before) and re.match(r"\s*(?:,\s*\w+\s*)*(end\b|$|;)", after):
                    continue   # pass-through return (accessor)
                if re.search(r"(?:^|\s|then\s)[A-Za-z_]\w*\s*=\s*$", before) and re.match(r"\s*(end\b|$|;|else\b)", after):
                    continue   # plain alias assignment `x = NAME`
                if re.search(r"\bin\s+(?:pairs|ipairs|next)\s*\(\s*$", before) or re.search(r"\bfor\s+[\w\s,]+in\s+next\s*,\s*$", before):
                    out.append((ln, name, "iterated", line.strip()))
                    continue
                out.append((ln, name, "raw use", line.strip()))
    return out


class SecretLint(unittest.TestCase):
    maxDiff = None

    def files(self):
        for rel in SECRET_MODULES:
            p = os.path.join(ADDON, rel)
            self.assertTrue(os.path.exists(p), rel)
            yield rel, p

    def test_s1_api_values_only_through_classifiers(self):
        bad = []
        for rel, p in self.files():
            if rel in FLOW_EXEMPT:
                continue
            bad += ["%s:%d %s (%s): %s" % (rel, ln, n, why, src[:140]) for ln, n, why, src in violations(p)]
        self.assertEqual(bad, [], "API values truth-tested / compared / indexed before classification")

    def test_s2_no_and_ident_or_idiom(self):
        bad = []
        for rel, p in self.files():
            for ln, line in code_lines(p):
                for m in re.finditer(r"\band\s+([A-Za-z_]\w*(?:\[\s*\d+\s*\])?)\s+or\b", line):
                    if m.group(1) not in ("true", "false", "nil"):
                        bad.append("%s:%d `and %s or`" % (rel, ln, m.group(1)))
        self.assertEqual(bad, [])

    def test_s3_no_inline_select_pcall(self):
        bad = []
        for rel, p in self.files():
            for ln, line in code_lines(p):
                if re.search(r"select\s*\(\s*2\s*,\s*pcall\s*\(", line):
                    bad.append("%s:%d" % (rel, ln))
        self.assertEqual(bad, [])

    def test_s4_core_classifier_contract(self):
        core = read(os.path.join(ADDON, "Core.lua"))
        for fn in ("ClassifyValue", "IsSecret"):
            m = re.search(r"function ns\." + fn + r"\(v\)\n\s*(.*)\n", core)
            self.assertTrue(m, fn)
            self.assertIn('type(v) == "nil"', m.group(1), fn + " must not compare v with nil")
        for helper in ("ClearOf", "ClearNum", "ClearStr", "ClearBool", "ClearTable", "IsTrue", "IsNil"):
            self.assertRegex(core, r"function ns\." + helper + r"\(", helper)
        self.assertNotRegex(core, r"function ns\.Clear\w+\([^)]*\)[^\n]*\band\s+v\s+or\b")

    def test_s5_hybridstate_boundary_covers_every_input(self):
        src = read(os.path.join(ADDON, "Lib", "HybridState.lua"))
        m = re.search(r"Lib\.BOUNDARY = \{(.*?)\}", src, re.S)
        self.assertTrue(m, "Lib.BOUNDARY missing")
        boundary = set(re.findall(r'"(\w+)"', m.group(1)))
        inputs = set(re.findall(r"^function M:((?:On|Record|CD|GCD|Set|Learn)\w*)\(", src, re.M))
        inputs -= {"CDActive", "CDCheckList", "CDExport", "GCD"}   # read-only queries without value inputs
        self.assertEqual(sorted(inputs - boundary), [], "public input methods outside the boundary guard")
        self.assertIn("for _, name in ipairs(Lib.BOUNDARY) do guard(M, name) end", src)
        self.assertIn("for _, name in ipairs(Lib.LEDGER_BOUNDARY) do guard(LedgerM, name) end", src)
        # the guard is fixed-arity (a1..a6, no varargs, for the storm budget): every guarded method must fit it
        mx = re.search(r"local MAXARGS = (\d+)", src)
        self.assertTrue(mx, "MAXARGS missing")
        lm = re.search(r"Lib\.LEDGER_BOUNDARY = \{(.*?)\}", src, re.S)
        guarded = {("M", n) for n in boundary} | {("LedgerM", n) for n in re.findall(r'"(\w+)"', lm.group(1))}
        sigs = {(o, n): ps for o, n, ps in re.findall(r"^function (M|LedgerM):(\w+)\(([^)]*)\)", src, re.M)}
        bad = []
        for key in sorted(guarded):
            self.assertIn(key, sigs, "guarded method has no definition: %s:%s" % key)
            params = [x.strip() for x in sigs[key].split(",") if x.strip()]
            if "..." in params or len(params) > int(mx.group(1)):
                bad.append("%s:%s(%s)" % (key[0], key[1], sigs[key]))
        self.assertEqual(bad, [], "guarded methods exceed the fixed guard arity or use varargs")
        # Lib.ARITY drives which parameters the wrapper scrubs: it must equal each signature exactly (a missing or short
        # entry would let a secret through unscrubbed)
        am = re.search(r"Lib\.ARITY = \{(.*?)\}", src, re.S)
        self.assertTrue(am, "Lib.ARITY missing")
        arity = {k: int(v) for k, v in re.findall(r"(\w+) = (\d+)", am.group(1))}
        wrong = []
        for (o, n) in sorted(guarded):
            params = [x.strip() for x in sigs[(o, n)].split(",") if x.strip()]
            if arity.get(n) != len(params):
                wrong.append("%s:%s has %d params, ARITY %s" % (o, n, len(params), arity.get(n)))
        self.assertEqual(wrong, [], "Lib.ARITY out of sync with the method signatures")

    def test_s0_lint_catches_the_run6b_bug(self):
        # self-test: the exact v2.2.6 field() (DamageMeter.lua:51) and the other shapes this lint must reject
        import tempfile
        samples = {
            "field": 'local function field(t, k)\n    local ok, v = pcall(function() return t[k] end)\n    return ok and v or nil\nend\n',
            "if": 'local function f(g)\n    local ok, v = pcall(g)\n    if v then return 1 end\nend\n',
            "not": 'local function f(g)\n    local ok, v = pcall(g)\n    return not v\nend\n',
            "eq": 'local function f(t)\n    local x = field(t, "isLocalPlayer")\n    if x == true then return 1 end\nend\n',
            "idx": 'local function f(g)\n    local ok, s = pcall(g)\n    return s:find("x")\nend\n',
            "evt": 'function M.OnEvent(event, a1)\n    if a1 == "player" then return 1 end\nend\n',
            "store": 'local function f(g)\n    local ok, v = pcall(g)\n    return { v = v }\nend\n',
        }
        clean = 'local function f(g)\n    local ok, v = pcall(g)\n    if not ok then return nil end\n    local n = ns.ClearNum(v)\n    if n and n > 0 then return n end\n    return v\nend\n'
        with tempfile.TemporaryDirectory() as d:
            for name, src in samples.items():
                p = os.path.join(d, name + ".lua")
                with open(p, "w") as f:
                    f.write(src)
                self.assertTrue(violations(p), "lint missed shape " + name)
            p = os.path.join(d, "clean.lua")
            with open(p, "w") as f:
                f.write(clean)
            self.assertEqual(violations(p), [], "lint flags the sanctioned shape")


if __name__ == "__main__":
    r = unittest.main(exit=False, verbosity=1).result
    sys.exit(0 if r.wasSuccessful() else 1)
