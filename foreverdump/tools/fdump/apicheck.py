"""(5) Best-effort API checker: scan an addon folder against a dump.

Reports
  error   C_X.Y / Enum.X.Y / documented global that is NOT present in this client
  error   CreateFrame("Type") with a widget type the client could not create
  error   RegisterEvent("NAME") with an event this client does not know
  error   method called on a variable known to hold a widget type that lacks the method
  warn    global read that is not in the dump and not defined by the addon itself
  note    call to an API with restriction/secret flags (HasRestrictions, SecretArguments, Secret*Returns...)
  error/warn/note  secret-op: arithmetic / comparison / boolean test / string ops on a value from a documented or
          observed secret return, struct field or event payload (see fdump/secretflow.py)
It is a lexical scan (no scoping, no type inference beyond simple `local x = CreateFrame("T")`), so treat
warnings as hints."""
import os
import re

from .luasv import as_list
from . import secrets as secretsmod
from .secretflow import SecretFlow

LUA_GLOBALS = {"_G", "_VERSION", "assert", "collectgarbage", "error", "getfenv", "getmetatable", "ipairs", "load",
               "loadstring", "next", "pairs", "pcall", "print", "rawequal", "rawget", "rawset", "select", "setfenv",
               "setmetatable", "tonumber", "tostring", "type", "unpack", "xpcall", "coroutine", "debug", "math",
               "string", "table", "bit", "self", "arg", "newproxy", "gcinfo", "dofile", "loadfile", "require",
               "module", "os", "io", "package"}
KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil",
            "not", "or", "repeat", "return", "then", "true", "until", "while", "goto"}
FLAG_KEYS = ("HasRestrictions", "SecretArguments", "SecretReturns", "SecretWhenInCombat", "SecretReturnsForAspect",
             "ConditionalSecret", "SecretNonPlayerUnitOrMinionWhileUnitRestricted", "RequiresValidAndPublicCVar")
CREATORS = {"CreateTexture": "Texture", "CreateMaskTexture": "MaskTexture", "CreateFontString": "FontString",
            "CreateLine": "Line", "CreateAnimationGroup": "AnimationGroup"}

TOKEN = re.compile(r"""
    (?P<ws>\s+)
  | (?P<comment>--\[(?P<ceq>=*)\[.*?\](?P=ceq)\]|--[^\n]*)
  | (?P<lstr>\[(?P<seq>=*)\[.*?\](?P=seq)\])
  | (?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
  | (?P<num>0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|::|[-+*/%^#<>=(){}\[\];:,.])
""", re.S | re.X)


def tokenize(src):
    toks, pos, line = [], 0, 1
    while pos < len(src):
        m = TOKEN.match(src, pos)
        if not m:
            pos += 1
            continue
        kind = m.lastgroup if m.lastgroup not in ("ceq", "seq") else None
        for k in ("ws", "comment", "lstr", "str", "num", "name", "op"):
            if m.group(k) is not None:
                kind = k
                break
        text = m.group(0)
        if kind not in ("ws", "comment"):
            if kind == "str":
                toks.append(("str", text[1:-1], line))
            elif kind == "lstr":
                toks.append(("str", re.sub(r"^\[=*\[|\]=*\]$", "", text), line))
            else:
                toks.append((kind, text, line))
        line += text.count("\n")
        pos = m.end()
    return toks


def addon_files(folder):
    """Lua files listed by the addon's .toc files (all flavors) else every .lua below the folder."""
    files = []
    tocs = [f for f in os.listdir(folder) if f.lower().endswith(".toc")]
    for toc in tocs:
        with open(os.path.join(folder, toc), encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and line.lower().split(" [")[0].endswith(".lua"):
                    p = os.path.join(folder, line.split(" [")[0].replace("\\", "/"))
                    if os.path.exists(p) and p not in files:
                        files.append(p)
    if not files:
        for root, _, names in os.walk(folder):
            files += [os.path.join(root, n) for n in sorted(names) if n.endswith(".lua")]
    return files


class Checker:
    def __init__(self, dump):
        self.dump = dump
        self.known = dump.all_global_names() | LUA_GLOBALS
        self.present = dump.present_functions()
        self.docfns = dump.doc_functions()
        self.namespaces = {ns: set(as_list(i.get("functions"))) | set((i.get("fields") or {}).keys()) | set((i.get("children") or {}).keys())
                           for ns, i in dump.namespaces().items()}
        self.enum = dump.runtime_enum()
        self.events = set(dump.events())
        self.widgets = {}
        for label, info in dump.widget_types().items():
            t = info.get("objectType") or label.split(":")[-1]
            self.widgets.setdefault(t, set()).update(as_list(info.get("methods")))
        self.all_methods = set().union(*self.widgets.values()) if self.widgets else set()
        self.frames = {n: (i.get("objectType") if isinstance(i, dict) else None) for n, i in dump.frames().items()}
        self.missing_docs = set(as_list(dump.docs.get("missing")))
        self.findings = []
        self.flow = SecretFlow.from_smap(secretsmod.build(dump), secretsmod)

    def add(self, level, path, line, code, msg):
        self.findings.append({"level": level, "file": path, "line": line, "code": code, "message": msg})

    def flags(self, full):
        d = self.docfns.get(full)
        if not d:
            return []
        f = d[1]
        return ["%s=%s" % (k, f[k]) for k in FLAG_KEYS if k in f]

    def check_files(self, files, root=""):
        parsed = {}
        defined = set()
        for p in files:
            with open(p, encoding="utf-8", errors="replace") as f:
                toks = tokenize(f.read())
            parsed[p] = toks
            for i, (k, v, _) in enumerate(toks):
                prev = toks[i - 1][1] if i else ""
                nxt = toks[i + 1][1] if i + 1 < len(toks) else ""
                if k == "name" and prev not in (".", ":") and (nxt == "=" or prev == "function"):
                    defined.add(v)
                if k == "name" and nxt == "," and prev not in (".", ":"):
                    # multiple assignment `a, b = ...` handled loosely
                    j = i + 1
                    while j + 1 < len(toks) and toks[j][1] == "," and toks[j + 1][0] == "name":
                        j += 2
                    if j < len(toks) and toks[j][1] == "=":
                        defined.add(v)
        self.defined = defined
        guarded = set()
        for toks in parsed.values():
            for i in range(len(toks) - 5):
                if toks[i][1] == "rawget" and toks[i + 1][1] == "(" and toks[i + 2][1] == "_G" and toks[i + 4][0] == "str":
                    guarded.add(toks[i + 4][1])
        self.guarded = guarded
        for p, toks in parsed.items():
            rel = os.path.relpath(p, root) if root else p
            self.check_tokens(rel, toks)
            self.findings.extend(self.flow.scan(rel, toks))
        return self.findings

    def check_tokens(self, path, toks):
        locals_ = set()
        widget_vars = {}
        depth = 0
        n = len(toks)
        for i, (k, v, line) in enumerate(toks):
            if k == "op" and v == "{":
                depth += 1
            elif k == "op" and v == "}":
                depth = max(0, depth - 1)
            if k != "name" or v in KEYWORDS:
                continue
            prev = toks[i - 1][1] if i else ""
            prevk = toks[i - 1][0] if i else ""
            nxt = toks[i + 1][1] if i + 1 < n else ""
            # local declarations / params / loop vars
            if prev == "local" or (prev == "," and v in locals_) or prev == "for":
                locals_.add(v)
                j = i + 1
                while j + 1 < n and toks[j][1] == "," and toks[j + 1][0] == "name":
                    locals_.add(toks[j + 1][1])
                    j += 2
            if prevk == "op" and prev in ("(", ",") and self._in_param_list(toks, i):
                locals_.add(v)
                continue
            if prev in (".", ":"):
                continue
            if depth > 0 and nxt == "=" and prev in ("{", ",", ";"):
                continue  # table constructor key
            # widget variable tracking:  local f = CreateFrame("Button", ...)
            if nxt == "=" and i + 3 < n:
                rhs = toks[i + 2]
                if rhs[1] == "CreateFrame" and toks[i + 3][1] == "(" and i + 4 < n and toks[i + 4][0] == "str":
                    widget_vars[v] = toks[i + 4][1]
                elif i + 5 < n and rhs[0] == "name" and toks[i + 3][1] == ":" and toks[i + 4][1] in CREATORS:
                    widget_vars[v] = CREATORS[toks[i + 4][1]]
                elif i + 4 < n and rhs[1] in ("CreateAnimationGroup",):
                    widget_vars[v] = "AnimationGroup"
            if v in locals_:
                self.check_method(path, toks, i, widget_vars.get(v) or None, v)
                continue
            # global usage
            if v == "CreateFrame" and nxt == "(" and i + 2 < n and toks[i + 2][0] == "str":
                t = toks[i + 2][1]
                if self.widgets and t not in self.widgets:
                    self.add("error", path, line, "widget-type", 'CreateFrame("%s"): type not creatable in this client' % t)
            if v.startswith("C_") or v in self.namespaces:
                if nxt == "." and i + 2 < n and toks[i + 2][0] == "name":
                    member = toks[i + 2][1]
                    full = v + "." + member
                    if v not in self.namespaces:
                        self.add("error", path, line, "missing-namespace", "%s does not exist in this client" % v)
                    elif member not in self.namespaces[v]:
                        why = " (documented, but missing at runtime)" if full in self.missing_docs or full in self.docfns else ""
                        self.add("error", path, line, "missing-api", "%s not present in this client%s" % (full, why))
                    else:
                        fl = self.flags(full)
                        if fl:
                            self.add("note", path, line, "restricted", "%s: %s" % (full, ", ".join(fl)))
                elif v not in self.namespaces and v not in self.defined:
                    self.add("error", path, line, "missing-namespace", "%s does not exist in this client" % v)
                continue
            if v == "Enum" and nxt == "." and i + 2 < n:
                en = toks[i + 2][1]
                if self.enum and en not in self.enum:
                    self.add("error", path, line, "missing-enum", "Enum.%s not present in this client" % en)
                elif self.enum and i + 4 < n and toks[i + 3][1] == "." and toks[i + 4][0] == "name":
                    val = toks[i + 4][1]
                    if isinstance(self.enum.get(en), dict) and val not in self.enum[en]:
                        self.add("error", path, line, "missing-enum", "Enum.%s.%s not present in this client" % (en, val))
                continue
            if v in self.defined:
                self.check_method(path, toks, i, widget_vars.get(v) or self.frames.get(v), v)
                continue
            if v in self.known:
                if v in self.docfns and self.present and v not in self.present:
                    self.add("error", path, line, "missing-api", "%s is documented but not present in this client" % v)
                elif nxt == "(":
                    fl = self.flags(v)
                    if fl:
                        self.add("note", path, line, "restricted", "%s: %s" % (v, ", ".join(fl)))
                self.check_method(path, toks, i, self.frames.get(v), v)
                continue
            if v in self.guarded:
                self.add("note", path, line, "guarded-global", "global '%s' not in dump (guarded by rawget(_G, ...))" % v)
            else:
                self.add("warn", path, line, "unknown-global", "global '%s' not in dump and not defined by the addon" % v)
        # RegisterEvent("X") checks (any receiver)
        for i in range(n - 3):
            if toks[i][1] in ("RegisterEvent", "RegisterUnitEvent") and toks[i - 1][1] == ":" and toks[i + 1][1] == "(" \
                    and toks[i + 2][0] == "str":
                ev = toks[i + 2][1]
                if self.events and ev not in self.events:
                    self.add("error", path, toks[i][2], "unknown-event", 'RegisterEvent("%s"): event not known to this client' % ev)

    def _in_param_list(self, toks, i):
        j = i - 1
        while j >= 0 and (toks[j][0] == "name" or toks[j][1] in (",", "...")):
            j -= 1
        if j < 0 or toks[j][1] != "(":
            return False
        k = j - 1
        if k >= 0 and toks[k][1] == "function":
            return True
        while k >= 0 and (toks[k][0] == "name" or toks[k][1] in (".", ":")) and toks[k][1] != "function":
            k -= 1
        return k >= 0 and toks[k][1] == "function"

    def check_method(self, path, toks, i, wtype, var):
        n = len(toks)
        if i + 3 < n and toks[i + 1][1] == ":" and toks[i + 2][0] == "name":
            method = toks[i + 2][1]
            if wtype and wtype in self.widgets:
                if method not in self.widgets[wtype]:
                    self.add("error", path, toks[i][2], "widget-method", "%s:%s() - %s has no method %s in this client"
                             % (var, method, wtype, method))


def run(dump, folder):
    files = addon_files(folder)
    c = Checker(dump)
    findings = c.check_files(files, root=folder)
    # de-duplicate warnings per (code, message) but keep first location + count
    merged = {}
    for f in findings:
        k = (f["level"], f["code"], f["message"])
        if k in merged:
            merged[k]["count"] += 1
        else:
            merged[k] = dict(f, count=1)
    out = sorted(merged.values(), key=lambda f: ({"error": 0, "warn": 1, "note": 2}[f["level"]], f["file"], f["line"]))
    counts = {lvl: sum(1 for f in out if f["level"] == lvl) for lvl in ("error", "warn", "note")}
    return {"dump": dump.build_label(), "folder": folder, "files": [os.path.relpath(p, folder) for p in files],
            "counts": counts, "findings": out}


def text(result):
    lines = ["apicheck %s against %s (%d files)" % (result["folder"], result["dump"], len(result["files"]))]
    for f in result["findings"]:
        lines.append("%s:%d: %s [%s] %s%s" % (f["file"], f["line"], f["level"], f["code"], f["message"],
                                              (" (x%d)" % f["count"]) if f["count"] > 1 else ""))
    c = result["counts"]
    lines.append("%d error(s), %d warning(s), %d note(s)" % (c["error"], c["warn"], c["note"]))
    return "\n".join(lines)
