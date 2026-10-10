"""Lexical secret-value flow check (used by `check` and `migrate`).

Tracks values that come from documented/observed secret sources:
  * `local a, b = API(...)` / `a = API(...)` where return #n of API is secret (always / conditional / observed)
  * `local info = API(...)` whose return is a struct with secret fields, then `info.field`
  * direct use `API(...) <op>` / `<op> API(...)`
  * event handler parameters named after the event: `function obj:UNIT_HEALTH(unit)` / `obj.UNIT_COMBAT(self, ...)`
    (an `event` first parameter is skipped, AceEvent style) and `if event == "X" then local a, b = ...`
and flags, until the variable is reassigned:
  arithmetic (+ - * / % ^, unary -), comparisons (< > <= >= == ~=), length (#), boolean tests (if/while/not/and/or),
  use as a table key (t[v]): error for always-secret sources, warn for conditional/observed;
  concatenation (..) and string.* / :method calls: note (allowed by the client but the result is a secret string).
A use is "guarded" (downgraded to note) when issecretvalue/canaccessvalue/issecrettable/hasanysecretvalues is applied to
the same variable earlier in the window. Lexical only: no scopes or aliasing; treat findings as review hints."""
import re

ARITH = {"+", "-", "*", "/", "%", "^"}
CMP = {"<", ">", "<=", ">=", "==", "~="}
GUARDS = {"issecretvalue", "canaccessvalue", "issecrettable", "hasanysecretvalues", "canaccesstable", "canaccesssecrets"}
STRING_FUNCS = {"format", "sub", "len", "upper", "lower", "find", "match", "gsub", "gmatch", "rep", "byte", "split"}
WINDOW = 600
EVENT_NAME = re.compile(r"^[A-Z][A-Z0-9_]{3,}$")


def _api_at(toks, i):
    """Return (fullname, index_after_name) if toks[i] starts `Name(` or `NS.Name(`."""
    k, v, _ = toks[i]
    if k != "name":
        return None, i
    if i + 3 < len(toks) and toks[i + 1][1] == "." and toks[i + 2][0] == "name" and toks[i + 3][1] == "(":
        return v + "." + toks[i + 2][1], i + 3
    if i + 1 < len(toks) and toks[i + 1][1] == "(" and (i == 0 or toks[i - 1][1] not in (".", ":")):
        return v, i + 1
    return None, i


def _close(toks, j):
    """j at '(' -> index of matching ')'."""
    depth = 0
    for x in range(j, len(toks)):
        if toks[x][1] in ("(", "{", "["):
            depth += 1
        elif toks[x][1] in (")", "}", "]"):
            depth -= 1
            if depth == 0:
                return x
    return len(toks) - 1


class SecretFlow:
    def __init__(self, ret_index, struct_fields, ret_structs, event_payload):
        self.ret = ret_index            # full -> {pos: cls}
        self.structs = struct_fields    # StructName -> {field: cls}
        self.rstructs = ret_structs     # full -> {pos: StructName}
        self.events = event_payload     # EVENT -> {pos: cls}

    @classmethod
    def from_smap(cls, smap, secretsmod):
        ret = {f: {p: c for p, c, _ in lst} for f, lst in secretsmod.secret_return_index(smap).items()}
        structs = {n: {fl["name"]: fl["secrecy"] for fl in s["fields"] if fl["secrecy"] in ("always", "conditional")}
                   for n, s in smap["structs"].items()}
        structs = {k: v for k, v in structs.items() if v}
        all_fields = {n: {fl["name"]: fl["secrecy"] for fl in s["fields"]} for n, s in smap["structs"].items()}
        rstructs = {}
        for full, f in smap["functions"].items():
            for i, r in enumerate(f["returns"], 1):
                t = r.get("type")
                if t in all_fields and (t in structs or r["secrecy"] in ("always", "conditional")):
                    rstructs.setdefault(full, {})[i] = t
                    # fields inherit the function's secrecy unless documented NeverSecret
                    if r["secrecy"] in ("always", "conditional"):
                        inh = structs.setdefault("%s@%s" % (t, full), {})
                        for fname, fcls in all_fields[t].items():
                            if fcls != "never":
                                inh[fname] = fcls if fcls in ("always", "conditional") else r["secrecy"]
                        rstructs[full][i] = "%s@%s" % (t, full)
        events = {}
        for ev, e in smap["events"].items():
            pos = {}
            for i, p in enumerate(e["payload"], 1):
                c = secretsmod.effective(e, i, p["secrecy"])
                if c in ("always", "conditional", "observed"):
                    pos[i] = c
            for slot in (e.get("observedSummary") or {}).values():
                for p in slot["secretPositions"]:
                    pos.setdefault(p, "observed")
            if pos:
                events[ev] = pos
        return cls(ret, structs, rstructs, events)

    # ------------------------------------------------------------------
    def scan(self, path, toks):
        findings = []
        tainted = {}  # var -> (source, cls, start_index, kind) ; kind "value" | "struct:<Name>"
        n = len(toks)

        def taint_assign(names, i_rhs):
            api, j = _api_at(toks, i_rhs)
            if not api:
                if toks[i_rhs][1] == "..." and current_event[0]:
                    ev = current_event[0]
                    for pos, nm in enumerate(names, 1):
                        cls = self.events.get(ev, {}).get(pos)
                        if cls and nm != "_":
                            tainted[nm] = ("%s payload #%d" % (ev, pos), cls, i_rhs, "value")
                return
            end = _close(toks, j)
            if end + 1 < n and toks[end + 1][1] in (".", ":", "["):
                return
            for pos, nm in enumerate(names, 1):
                if nm == "_":
                    continue
                cls = self.ret.get(api, {}).get(pos)
                if self.rstructs.get(api, {}).get(pos):
                    tainted[nm] = ("%s return #%d" % (api, pos), "struct", i_rhs, "struct:" + self.rstructs[api][pos])
                elif cls:
                    tainted[nm] = ("%s return #%d" % (api, pos), cls, i_rhs, "value")
                elif nm in tainted:
                    del tainted[nm]

        current_event = [None]
        i = 0
        while i < n:
            k, v, line = toks[i]
            # event context:  if event == "X"  /  elseif event == "X"
            if v in ("event", "e", "evt", "ev") and i + 2 < n and toks[i + 1][1] == "==" and toks[i + 2][0] == "str" \
                    and EVENT_NAME.match(toks[i + 2][1]):
                current_event[0] = toks[i + 2][1]
            # handler named after the event:  function X:EVENT(a, b)  / function X.EVENT(self, a)
            if v == "function" and i + 4 < n and toks[i + 1][0] == "name" and toks[i + 2][1] in (".", ":") \
                    and EVENT_NAME.match(toks[i + 3][1] or "") and toks[i + 4][1] == "(":
                ev = toks[i + 3][1]
                current_event[0] = ev
                params, j = [], i + 5
                while j < n and toks[j][1] != ")":
                    if toks[j][0] == "name":
                        params.append(toks[j][1])
                    j += 1
                if toks[i + 2][1] == "." and params and params[0] == "self":
                    params = params[1:]
                if params and params[0] in ("event", "e", "evt", "ev", "_"):
                    params = params[1:]
                for pos, nm in enumerate(params, 1):
                    cls = self.events.get(ev, {}).get(pos)
                    if cls:
                        tainted[nm] = ("%s payload #%d" % (ev, pos), cls, j, "value")
                i = j
                continue
            # assignments
            if k == "name" and (i == 0 or toks[i - 1][1] not in (".", ":")):
                names, j = [v], i + 1
                while j + 1 < n and toks[j][1] == "," and toks[j + 1][0] == "name":
                    names.append(toks[j + 1][1])
                    j += 2
                if j < n and toks[j][1] == "=" and j + 1 < n and (i == 0 or toks[i - 1][1] in ("local", ";", ")", "end", "then",
                                                                                                "do", "else") or toks[i - 1][0] in ("name", "str", "num")):
                    for nm in names:
                        tainted.pop(nm, None)
                    taint_assign(names, j + 1)
                    i = j + 1
                    continue
            # direct use of an API call result
            api, j = _api_at(toks, i)
            if api and (api in self.ret) and 1 in self.ret[api]:
                end = _close(toks, j)
                prev = toks[i - 1][1] if i else ""
                nxt = toks[end + 1][1] if end + 1 < n else ""
                self._use(findings, path, line, "%s return #1" % api, self.ret[api][1], prev, nxt, toks, i, end, guarded=False)
            # uses of tainted variables
            if k == "name" and v in tainted and (i == 0 or toks[i - 1][1] not in (".", ":")):
                src, cls, start, kind = tainted[v]
                if i - start > WINDOW:
                    del tainted[v]
                else:
                    guarded = self._guarded(toks, start, i, v)
                    if kind.startswith("struct:"):
                        if i + 2 < n and toks[i + 1][1] == "." and toks[i + 2][0] == "name":
                            fcls = self.structs.get(kind[7:], {}).get(toks[i + 2][1])
                            if fcls:
                                prev = toks[i - 1][1] if i else ""
                                nxt = toks[i + 3][1] if i + 3 < n else ""
                                self._use(findings, path, line, "%s .%s (%s)" % (src, toks[i + 2][1], kind[7:].split("@")[0]), fcls, prev, nxt,
                                          toks, i, i + 2, guarded or self._guarded(toks, start, i, v + "." + toks[i + 2][1]))
                    elif not (i + 1 < n and toks[i + 1][1] in (".", "[")):
                        prev = toks[i - 1][1] if i else ""
                        nxt = toks[i + 1][1] if i + 1 < n else ""
                        self._use(findings, path, line, "%s (in '%s')" % (src, v), cls, prev, nxt, toks, i, i, guarded)
            i += 1
        return findings

    def _guarded(self, toks, start, i, var):
        parts = var.split(".")
        for x in range(max(0, start), i):
            if toks[x][1] in GUARDS and x + 2 < len(toks) and toks[x + 1][1] == "(" and toks[x + 2][1] == parts[0]:
                return True
        return False

    def _use(self, findings, path, line, src, cls, prev, nxt, toks, i, end, guarded):
        op = None
        if prev in ARITH or nxt in ARITH:
            op = "arithmetic"
        elif prev in CMP or nxt in CMP:
            op = "comparison"
        elif prev == "#":
            op = "length (#)"
        elif prev in ("if", "while", "not", "and", "or", "elseif", "until") or nxt in ("then", "and", "or", "do"):
            op = "boolean test"
        elif prev == "[" and nxt == "]":
            op = "table key"
        elif prev == ".." or nxt == "..":
            op = "concat"
        elif nxt == ":" and end + 2 < len(toks) and toks[end + 2][1] in STRING_FUNCS:
            op = "string method"
        elif prev == "(" and i >= 3 and toks[i - 2][1] in STRING_FUNCS and toks[i - 3][1] == ".":
            op = "string function"
        if not op:
            return
        if op in ("concat", "string method", "string function"):
            level = "note"
            msg = "%s on a possibly secret value from %s: allowed, but the result is a secret string (no compare/length/parse)" % (op, src)
        else:
            level = "error" if cls == "always" else "warn"
            msg = "%s on a %s secret value from %s: errors when the value is secret" % (
                op, "documented" if cls == "always" else ("observed" if cls == "observed" else "conditionally"), src)
        if guarded:
            level = "note"
            msg += " (guarded by issecretvalue/canaccessvalue earlier)"
        else:
            msg += "; guard with issecretvalue(v) / canaccessvalue(v)"
        findings.append({"level": level, "file": path, "line": line, "code": "secret-op", "message": msg})
