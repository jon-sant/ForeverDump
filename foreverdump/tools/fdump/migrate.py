"""Legacy-addon migration toolkit (`fdump.py migrate`).

Mapping database (old API -> Forever API), merged from:
  1. data/migration_curated.json   hand-curated 9.x-12.x API moves with signature / return-shape notes
  2. data/migration_shims.json     parsed from Blizzard_Deprecated* (wow-ui-source `forever` + `live`): `Old = C_X.New`
                                   aliases and `function Old(...) ... C_X.New(...) end` wrappers (`fdump.py migrate-db`)
  3. the dump                      what exists in THIS client (present globals / C_ namespaces / events), the secrets
                                   map (now-secret returns, restricted events) and protected flags
Statuses per call site:
  ok | removed | renamed | signature-changed | deprecated-shim | now-secret | restricted-event | removed-event |
  renamed-event | protected | replacement-missing
plus TOC checks (Interface vs this client), taint-prone patterns, and secret-value flow findings (secretflow)."""
import collections
import json
import os
import re

from .apicheck import tokenize, addon_files, KEYWORDS, LUA_GLOBALS
from . import perfcheck
from .dump import as_list
from . import secrets as secretsmod
from .secretflow import SecretFlow

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
EVENT_NAME = re.compile(r"^[A-Z][A-Z0-9_]{2,}$")


# ------------------------------------------------------------------ shim parsing
ALIAS = re.compile(r"^\s*([A-Za-z_][\w.]*)\s*=\s*([A-Za-z_][\w]*(?:\.[A-Za-z_]\w*)+)\s*;?\s*(?:--.*)?$")
FUNC = re.compile(r"^\s*function\s+([A-Za-z_][\w.:]*)\s*\(([^)]*)\)")
CALL = re.compile(r"\b(C_[A-Za-z]\w*\.[A-Za-z_]\w*|[A-Z][A-Za-z]+Util\.[A-Za-z_]\w*|Settings\.[A-Za-z_]\w*)\s*\(")


def parse_shim_file(path, rel, branch):
    out = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
    ver = re.search(r"Deprecated_(\d+_\d+_\d+)", rel)
    version = ver.group(1).replace("_", ".") if ver else None
    i = 0
    while i < len(lines):
        line = lines[i]
        m = ALIAS.match(line)
        if m and not m.group(1).startswith(("local",)) and m.group(1) != m.group(2):
            out[m.group(1)] = {"new": m.group(2), "kind": "alias", "file": rel, "branch": branch, "line": i + 1, "version": version}
            i += 1
            continue
        m = FUNC.match(line)
        if m:
            name, args = m.group(1), m.group(2).strip()
            depth, body, j = 0, [], i
            while j < len(lines):
                body.append(lines[j])
                depth += len(re.findall(r"\b(function|do|then|repeat)\b", lines[j])) - len(re.findall(r"\b(end|until)\b", lines[j]))
                if depth <= 0 and j > i:
                    break
                if depth <= 0 and j == i and re.search(r"\bend\b", lines[j]):
                    break
                j += 1
            text = "\n".join(body)
            calls = [c for c in CALL.findall(text) if c != name]
            direct = re.search(r"return\s+" + re.escape(calls[0]) + r"\s*\(([^)]*)\)\s*;?\s*\n\s*end", text) if calls else None
            kind = "alias" if direct and direct.group(1).replace(" ", "") == args.replace(" ", "") else "wrapper"
            out[name] = {"new": calls[0] if calls else None, "kind": kind, "args": args, "file": rel, "branch": branch,
                         "line": i + 1, "version": version, "bodyLines": len(body),
                         "returnsTable": bool(re.search(r"\.(\w+)\s*;?\s*$", text, re.M)) and "Info" in text}
            i = j + 1
            continue
        i += 1
    return out


def parse_shims(addons_dir, branch):
    db = {}
    toc_tags = {}
    for root, _, names in os.walk(addons_dir):
        for n in sorted(names):
            p = os.path.join(root, n)
            rel = os.path.relpath(p, addons_dir)
            if n.endswith(".toc"):
                with open(p, encoding="utf-8", errors="replace") as f:
                    for line in f:
                        m = re.match(r"^\s*([^#\s][^\[]*?\.lua)\s*(\[.*\])?", line)
                        if m:
                            toc_tags[os.path.join(os.path.dirname(rel), m.group(1).replace("\\", "/"))] = (m.group(2) or "").strip()
            if n.endswith(".lua") and "Deprecated" in rel:
                for k, v in parse_shim_file(p, rel, branch).items():
                    db.setdefault(k, v)
    for v in db.values():
        v["loadTag"] = toc_tags.get(v["file"], "")
    return db


def build_shim_db(dirs):
    out = {}
    for branch, d in dirs:
        for k, v in parse_shims(d, branch).items():
            if k in out:
                out[k].setdefault("alsoIn", []).append(branch)
            else:
                out[k] = v
    return out


def load_db():
    with open(os.path.join(DATA, "migration_curated.json")) as f:
        cur = json.load(f)
    shims = {}
    p = os.path.join(DATA, "migration_shims.json")
    if os.path.exists(p):
        with open(p) as f:
            shims = json.load(f).get("functions", {})
    return cur, shims


# ------------------------------------------------------------------ scanning
SHIM_KEY = re.compile(r"^(?:[A-Za-z_][A-Za-z0-9_]*|C_[A-Za-z0-9_]+\.[A-Za-z0-9_]+|[A-Z][A-Za-z0-9_]*\.[A-Za-z0-9_]+)$")


class Migrator:
    def __init__(self, dump, smap=None):
        self.dump = dump
        self.cur, self.shims = load_db()
        self.present = dump.present_functions()
        self.allnames = dump.all_global_names()
        # only addon-callable keys: globals, C_ namespaces, Upper.Tables (drop mixin methods and local field renames)
        self.shims = {k: v for k, v in self.shims.items() if SHIM_KEY.match(k)}
        g = (dump.sections.get("globals") or {}).get("functions") or {}
        self.present |= set(as_list(g.get("insecure")))
        self.namespaces = {ns: set(as_list(i.get("functions"))) for ns, i in dump.namespaces().items()}
        self.global_tables = set(dump.global_tables().keys()) if isinstance(dump.global_tables(), dict) else set()
        self.known = dump.all_global_names() | LUA_GLOBALS
        self.events = set(dump.events())
        self.smap = smap or secretsmod.build(dump)
        self.flow = SecretFlow.from_smap(self.smap, secretsmod)
        self.secret_ret = secretsmod.secret_return_index(self.smap)
        self.protected = set(self.cur.get("protected", []))
        for full, f in self.smap["functions"].items():
            if "IsProtectedFunction" in f["restrictions"] or "HasRestrictions" in f["restrictions"]:
                self.protected.add(full)
        prot = (dump.sections.get("protected") or {}).get("functions") or {}
        if isinstance(prot, dict):
            for k, v in prot.items():
                if isinstance(v, dict) and (v.get("protected") or v.get("explicitProtected")):
                    self.protected.add(k)
        self.toc = (dump.meta() or {}).get("toc")
        self.blizzard_addons = set()
        for name in ("blizzard_addons_forever.txt",):
            p = os.path.join(os.path.dirname(os.path.dirname(HERE)), "ref", name)
            if os.path.exists(p):
                self.blizzard_addons = {l.strip() for l in open(p) if l.strip()}

    def exists(self, full):
        if not full:
            return False
        if "." in full:
            ns, _, fn = full.partition(".")
            if ns in self.namespaces:
                return fn in self.namespaces[ns] or full in self.present
            return full in self.present
        return full in self.present

    def secrecy_of(self, full):
        rs = self.secret_ret.get(full)
        f = self.smap["functions"].get(full)
        if not f and not rs:
            return None
        parts = []
        if rs:
            parts.append("returns %s secret (%s)" % (",".join("#%d" % p for p, _, _ in rs),
                                                      "/".join(sorted({c for _, c, _ in rs}))))
            conds = sorted({c for _, _, cs in rs for c in cs})
            if conds:
                parts.append("when " + ", ".join(conds))
        if f:
            sf = smap_struct_secret(self.smap, f)
            if sf:
                parts.append("struct fields secret: " + ", ".join(sf[:8]) + (" ..." if len(sf) > 8 else ""))
            if f.get("secretArguments") == "NotAllowed":
                parts.append("rejects secret arguments")
        return "; ".join(parts) or None

    def value_exists(self, full):
        """a function OR a table path/constant (Constants.X.Y, Enum.Z, ChatFrameConstants.W)"""
        if self.exists(full):
            return True
        root = full.split(".")[0]
        return root in self.allnames and (root in ("Enum", "Constants") or root.endswith("Constants") or "." not in full)

    def classify(self, name):
        """-> dict(status, replacement, notes, secrecy, source)"""
        cur = self.cur["functions"].get(name)
        shim = self.shims.get(name)
        present = self.exists(name) or ("." not in name and name in self.allnames)
        r = {"name": name, "present": present}
        if present:
            if name in self.protected:
                r.update(status="protected", notes="protected/restricted: callable only from secure code (or out of combat)")
            elif shim:
                r.update(status="deprecated-shim", replacement=shim.get("new"),
                         notes="provided by %s (%s; loads only while CVar loadDeprecationFallbacks=1%s)" % (
                             shim["file"], shim["branch"], ", " + shim["loadTag"] if shim.get("loadTag") else ""), source="shim")
            else:
                sec = self.secrecy_of(name)
                r.update(status="now-secret" if sec else "ok", secrecy=sec)
            if r["status"] in ("deprecated-shim",) and r.get("replacement"):
                r["secrecy"] = self.secrecy_of(r["replacement"])
            return r
        entry = cur or shim
        if not entry:
            r.update(status="removed", notes="not present in this client and no known replacement")
            return r
        new = entry.get("new")
        kind = entry.get("kind")
        src = "curated" if cur else "shim:%s" % shim["file"]
        if new is None or kind == "none":
            r.update(status="removed", replacement=None, notes=entry.get("returns") or "no addon replacement", source=src)
            return r
        base_new = new.split("(")[0].split("[")[0]
        if not self.value_exists(base_new) and not base_new.startswith(("_G", "Settings.", "MenuUtil.", "Menu.")):
            r.update(status="replacement-missing", replacement=new,
                     notes="mapped to %s, which is NOT present in this client. %s" % (new, entry.get("returns") or ""), source=src)
            return r
        status = "renamed" if kind == "alias" else "signature-changed"
        r.update(status=status, replacement=new, notes=entry.get("returns") or ("same arguments" if kind == "alias" else
                                                                                 "wrapper in Blizzard_Deprecated: review the body"),
                 example=entry.get("example"), source=src, secrecy=self.secrecy_of(base_new))
        if base_new in self.protected:
            r["notes"] += " (replacement is protected)"
        return r

    def scan(self, folder):
        files = addon_files(folder)
        sites, events, taint, defined = [], [], [], set()
        parsed = {}
        for p in files:
            with open(p, encoding="utf-8", errors="replace") as f:
                src = f.read()
            toks = tokenize(src)
            parsed[p] = (toks, src)
            for i, (k, v, _) in enumerate(toks):
                prev = toks[i - 1][1] if i else ""
                nxt = toks[i + 1][1] if i + 1 < len(toks) else ""
                if k == "name" and prev not in (".", ":") and (prev in ("function", "local") or nxt == "="):
                    if prev == "local" or (i >= 2 and toks[i - 2][1] == "local"):
                        pass  # locals are scoped per file in the scan below
                    elif prev == "function" and nxt not in (".", ":") and not self.exists(v):
                        defined.add(v)
                    elif nxt == "=" and prev not in ("function", ",") and not self.exists(v):
                        defined.add(v)  # addon-owned global table/value
        cache = {}
        flow_findings = []
        for p, (toks, src) in parsed.items():
            rel = os.path.relpath(p, folder)
            locals_ = {}
            lhs_skip, rhs_ref, alias = set(), set(), {}
            n = len(toks)
            for i, (k, v, line) in enumerate(toks):
                if k != "name" or v in KEYWORDS:
                    continue
                prev = toks[i - 1][1] if i else ""
                nxt = toks[i + 1][1] if i + 1 < n else ""
                if prev == "local" or (prev == "function" and i >= 2 and toks[i - 2][1] == "local"):
                    # a local shadows the global from the NEXT line on (`local UnitBuff = UnitBuff` still reads the global)
                    names = [v]
                    j = i + 1
                    while j + 1 < n and toks[j][1] == "," and toks[j + 1][0] == "name":
                        names.append(toks[j + 1][1])
                        j += 2
                    end = j - 1
                    if j < n and toks[j][1] == "=":
                        depth, x = 0, j + 1
                        while x < n:
                            tv = toks[x][1]
                            if tv in ("(", "{", "["):
                                depth += 1
                            elif tv in (")", "}", "]"):
                                depth -= 1
                            nxt_line = toks[x + 1][2] if x + 1 < n else 10 ** 9
                            if depth <= 0 and nxt_line > toks[x][2] and tv not in (",", "=", "..", "and", "or", "+", "-", "*", "/", "not"):
                                break
                            x += 1
                        end = x
                    for nm in names:
                        locals_[nm] = end
                        alias.pop(nm, None)
                    for x in range(i + 2, j, 2):
                        lhs_skip.add(x)
                    # positional upvalue caching: local UnitBuff, UnitAura = UnitBuff, UnitAura
                    if j < n and toks[j][1] == "=":
                        rhs = toks[j + 1:end + 1]
                        if rhs and all((t[0] == "name") if q % 2 == 0 else (t[1] == ",") for q, t in enumerate(rhs)):
                            for q, nm in enumerate(names):
                                if 2 * q < len(rhs) and (rhs[2 * q][1] not in locals_ or locals_[rhs[2 * q][1]] >= i):
                                    alias[nm] = rhs[2 * q][1]
                                    rhs_ref.add(j + 1 + 2 * q)
                    continue
                if i in lhs_skip:
                    continue
                via = None
                if v in locals_ and i > locals_[v]:
                    if v in alias and nxt == "(" and prev not in (".", ":"):
                        via, v = v, alias[v]
                    else:
                        continue
                if prev in (".", ":") or v in LUA_GLOBALS:
                    continue
                prev2 = toks[i - 2][1] if i >= 2 else ""
                if v not in locals_ and v in self.present and v not in LUA_GLOBALS and (
                        (prev == "function" and nxt not in (".", ":") and prev2 != "local")
                        or (nxt == "=" and i + 2 < n and toks[i + 2][1] != "=" and prev not in ("local", ",", "for")
                            and prev2 != "local" and not (prev == "(" or prev == "{"))):
                    taint.append({"file": rel, "line": line, "pattern": "overwrites-global",
                                  "message": "redefines Blizzard global %s: taints every Blizzard caller; use hooksecurefunc(%r, fn)" % (v, v)})
                    continue
                full = v
                if v.startswith("C_") and nxt == "." and i + 2 < n and toks[i + 2][0] == "name":
                    full = v + "." + toks[i + 2][1]
                elif v in ("_G",):
                    continue
                is_call = (toks[i + 3][1] == "(") if full != v and i + 3 < n else nxt == "("
                if i in rhs_ref:
                    is_call = None  # reference captured into a local alias; calls through the alias are reported too
                interesting = full in self.cur["functions"] or full in self.shims or (full.startswith("C_") and "." in full) \
                    or ((is_call or is_call is None) and (full in self.known or full in self.protected or (full not in defined and full[:1].isupper())))
                if not interesting or (full in defined and full not in self.cur["functions"]):
                    continue
                if prev == "function" or (nxt == "=" and full == v):
                    continue
                if full not in cache:
                    cache[full] = self.classify(full)
                c = cache[full]
                if c["status"] == "ok" and not is_call:
                    continue
                if c["status"] == "removed" and not (full in self.cur["functions"] or full in self.shims or is_call
                                                     or (is_call is None and full[:1].isupper())):
                    continue
                if c["status"] == "removed" and full not in self.cur["functions"] and full not in self.shims and not full[:1].isupper() \
                        and not full.startswith("C_"):
                    continue
                site = dict(c, file=rel, line=line, call=bool(is_call))
                if is_call is None:
                    site["ref"] = "local alias"
                if via:
                    site["via"] = via
                sites.append(site)
            # events
            for i in range(n - 3):
                if toks[i][1] in ("RegisterEvent", "RegisterUnitEvent", "RegisterEventCallback") and toks[i + 1][1] == "(" \
                        and toks[i + 2][0] == "str":
                    events.append(self.event_status(toks[i + 2][1], rel, toks[i][2], "register"))
                elif toks[i][1] == "RegisterEvent" and toks[i + 1][1] == "(" and i + 3 < n and toks[i + 2][0] == "name" \
                        and toks[i + 3][1] == ",":
                    pass
                elif toks[i][1] in ("event", "e", "evt") and toks[i + 1][1] == "==" and toks[i + 2][0] == "str" \
                        and EVENT_NAME.match(toks[i + 2][1]):
                    events.append(self.event_status(toks[i + 2][1], rel, toks[i][2], "compare"))
                elif toks[i][1] == "function" and toks[i + 2][1] in (":", ".") and i + 3 < n and EVENT_NAME.match(toks[i + 3][1]) \
                        and toks[i + 1][1] != "SlashCmdList" and (toks[i + 3][1] in self.events or toks[i + 3][1] in self.cur["events"]):
                    events.append(self.event_status(toks[i + 3][1], rel, toks[i][2], "handler"))
            taint.extend(self.taint_patterns(rel, toks, src))
            flow_findings.extend(self.flow.scan(rel, toks))
        toc = self.toc_checks(folder)
        rep = self.report(folder, files, sites, events, taint, toc, flow_findings)
        # PERFORMANCE.md: ported code carries the same perf rule as ForeverDump itself
        rep["performance"] = perfcheck.scan(folder, files)
        rep["performanceCounts"] = perfcheck.summary(rep["performance"])
        return rep

    def event_status(self, ev, rel, line, how):
        cur = self.cur["events"].get(ev) or {}
        r = {"event": ev, "file": rel, "line": line, "how": how}
        if cur.get("status") == "restricted-event":
            r.update(status="restricted-event", notes=cur.get("note"))
        elif ev in self.events:
            e = self.smap["events"].get(ev) or {}
            if e.get("secrecy") in ("always", "conditional", "partial"):
                sec = [p["name"] for p in e.get("payload", []) if p["secrecy"] in ("always", "conditional")]
                r.update(status="now-secret", notes="payload secret: %s (%s)" % (", ".join(sec) or "all", ", ".join(e.get("conditions", [])) or e["secrecy"]))
            elif e.get("restrictions"):
                r.update(status="restricted-event", notes="documented restrictions: " + ", ".join(e["restrictions"]))
            else:
                r.update(status="ok")
        elif cur.get("new"):
            r.update(status="renamed-event", replacement=cur["new"], notes=cur.get("note", ""))
            if cur["new"] not in self.events:
                r["notes"] += " (replacement %s not in this client either)" % cur["new"]
        else:
            r.update(status="removed-event", notes="event not known to this client")
        return r

    def taint_patterns(self, rel, toks, src):
        out = []
        n = len(toks)
        has_lockdown_guard = "InCombatLockdown" in src
        uses_secure_tpl = bool(re.search(r"Secure\w*Template", src))
        for i, (k, v, line) in enumerate(toks):
            nxt = toks[i + 1][1] if i + 1 < n else ""
            prev = toks[i - 1][1] if i else ""
            if v == "RegisterAllEvents" and prev == ":":
                out.append({"file": rel, "line": line, "pattern": "RegisterAllEvents",
                            "message": "RegisterAllEvents also registers restricted events (COMBAT_LOG_EVENT*) -> ADDON_ACTION_FORBIDDEN on Forever"})
            if v in ("UIDropDownMenu_Initialize", "UIDropDownMenu_AddButton", "EasyMenu", "ToggleDropDownMenu") and nxt == "(":
                out.append({"file": rel, "line": line, "pattern": "UIDropDownMenu",
                            "message": "%s: legacy dropdowns taint the shared menu frames; use the Blizzard_Menu API (MenuUtil)" % v})
            if v == "SetAttribute" and prev == ":" and uses_secure_tpl and not has_lockdown_guard:
                out.append({"file": rel, "line": line, "pattern": "secure-attribute-unguarded",
                            "message": "SetAttribute on a secure template without any InCombatLockdown() check in this file (blocked in combat)"})
            if v in ("SetPoint", "SetSize", "SetWidth", "SetHeight", "Show", "Hide", "ClearAllPoints") and prev == ":" \
                    and uses_secure_tpl and not has_lockdown_guard:
                out.append({"file": rel, "line": line, "pattern": "secure-layout-unguarded",
                            "message": "%s in a file using secure templates without InCombatLockdown(): blocked in combat "
                                       "(ADDON_ACTION_BLOCKED, like ClassicFishingCompanion's CFCHUDFrame:SetHeight)" % v})
            if v == "SetBackdrop" and prev == ":" and "BackdropTemplate" not in src:
                out.append({"file": rel, "line": line, "pattern": "SetBackdrop",
                            "message": "SetBackdrop needs frames created with \"BackdropTemplate\" (9.0+)"})
            if v in ("this", "arg1", "arg2", "event") and prev not in (".", ":", "local", ",", "(", "function") and nxt != "=" \
                    and v != "event":
                out.append({"file": rel, "line": line, "pattern": "implicit-global",
                            "message": "implicit global '%s' (pre-3.0 handler style) no longer exists" % v})
            if v in ("getglobal", "setglobal", "table.getn") and nxt == "(":
                out.append({"file": rel, "line": line, "pattern": "legacy-lua", "message": "%s: use _G[...]" % v})
            if v == "PlaySound" and nxt == "(" and i + 2 < n and toks[i + 2][0] == "str":
                out.append({"file": rel, "line": line, "pattern": "PlaySound-string",
                            "message": "PlaySound(\"%s\"): sound names were replaced by SOUNDKIT IDs (7.3)" % toks[i + 2][1]})
            if v == "SetTexture" and prev == ":" and i + 2 < n and toks[i + 2][0] == "num" and i + 3 < n and toks[i + 3][1] == ",":
                out.append({"file": rel, "line": line, "pattern": "SetTexture-color",
                            "message": "SetTexture(r, g, b) no longer sets a color: use SetColorTexture"})
        return out

    def toc_checks(self, folder):
        out = []
        tocs = sorted(f for f in os.listdir(folder) if f.lower().endswith(".toc"))
        if not tocs:
            return [{"level": "error", "message": "no .toc file"}]
        for t in tocs:
            with open(os.path.join(folder, t), encoding="utf-8", errors="replace") as f:
                text = f.read()
            ifaces = re.findall(r"^##\s*Interface\s*:\s*(.+)$", text, re.M)
            flavored = re.findall(r"^##\s*(Interface-\w+)\s*:\s*(.+)$", text, re.M)
            vals = [int(x) for v in ifaces for x in re.findall(r"\d+", v)]
            if not ifaces:
                out.append({"level": "error", "toc": t, "message": "no ## Interface line"})
            elif self.toc and int(self.toc) not in vals:
                out.append({"level": "error", "toc": t, "message": "## Interface: %s does not include this client's %s: the addon is "
                            "listed as out of date. Set ## Interface: %s (a comma list like '%s, 120001' is accepted by "
                            "current clients; verify on Forever)" % (", ".join(map(str, vals)), self.toc, self.toc, self.toc)})
            for key, val in flavored:
                out.append({"level": "warn", "toc": t, "message": "## %s: %s is a legacy per-flavor key (BigWigs packager era); "
                            "clients ignore it. Use per-flavor TOC files or a comma list in ## Interface" % (key, val.strip())})
            for dep in re.findall(r"^##\s*(?:Dependencies|RequiredDeps|Dep\w*)\s*:\s*(.+)$", text, re.M):
                for d in [x.strip() for x in dep.split(",") if x.strip()]:
                    if d.startswith("Blizzard_") and self.blizzard_addons and d not in self.blizzard_addons:
                        out.append({"level": "error", "toc": t, "message": "depends on %s, which does not exist on Forever" % d})
            if re.search(r"^##\s*SavedVariables", text, re.M) is None:
                out.append({"level": "note", "toc": t, "message": "no SavedVariables (fine if the addon keeps no state)"})
        return out

    def report(self, folder, files, sites, events, taint, toc, flow):
        merged = collections.OrderedDict()
        for s in sites:
            k = (s["name"], s["status"])
            if k in merged:
                merged[k]["sites"].append("%s:%d" % (s["file"], s["line"]))
            else:
                merged[k] = dict(s, sites=["%s:%d" % (s["file"], s["line"])])
        apis = list(merged.values())
        order = ["removed", "replacement-missing", "signature-changed", "renamed", "deprecated-shim", "restricted-event",
                 "protected", "now-secret", "ok"]
        apis.sort(key=lambda a: (order.index(a["status"]) if a["status"] in order else 99, a["name"]))
        ev_m = collections.OrderedDict()
        for e in events:
            k = (e["event"], e["status"])
            if k in ev_m:
                ev_m[k]["sites"].append("%s:%d" % (e["file"], e["line"]))
            else:
                ev_m[k] = dict(e, sites=["%s:%d" % (e["file"], e["line"])])
        counts = collections.Counter(s["status"] for s in sites)
        ev_counts = collections.Counter(e["status"] for e in ev_m.values())
        return {"folder": folder, "dump": self.dump.build_label(), "clientToc": self.toc,
                "files": [os.path.relpath(p, folder) for p in files],
                "callSiteCounts": dict(counts), "apiCounts": dict(collections.Counter(a["status"] for a in apis)),
                "eventCounts": dict(ev_counts), "apis": apis, "events": list(ev_m.values()), "toc": toc,
                "taint": taint, "secretFlow": flow,
                "db": {"curated": len(self.cur["functions"]), "shims": len(self.shims)}}


def smap_struct_secret(smap, f):
    out = []
    for r in f.get("returns", []):
        st = smap["structs"].get(r.get("type"))
        if st:
            for fl in st["fields"]:
                if fl["secrecy"] in ("always", "conditional"):
                    out.append("%s.%s" % (r["type"], fl["name"]))
                elif r["secrecy"] in ("always", "conditional") and fl["secrecy"] != "never":
                    out.append("%s.%s" % (r["type"], fl["name"]))
    return out


def markdown(rep):
    L = ["# Migration report: %s" % rep["folder"], "",
         "Against %s (client TOC %s). Mapping DB: %d curated + %d Blizzard_Deprecated shim entries." % (
             rep["dump"], rep["clientToc"], rep["db"]["curated"], rep["db"]["shims"]), "",
         "## Summary", "",
         "- APIs by status: " + ", ".join("%s %d" % kv for kv in sorted(rep["apiCounts"].items())),
         "- call sites by status: " + ", ".join("%s %d" % kv for kv in sorted(rep["callSiteCounts"].items())),
         "- events by status: " + ", ".join("%s %d" % kv for kv in sorted(rep["eventCounts"].items())),
         "- TOC findings: %d; taint-prone patterns: %d; secret-value flow findings: %d" % (len(rep["toc"]), len(rep["taint"]), len(rep["secretFlow"])),
         "- performance lint (PERFORMANCE.md): %d error(s), %d warning(s)" % (
             (rep.get("performanceCounts") or {}).get("error", 0), (rep.get("performanceCounts") or {}).get("warn", 0)),
         "", "## TOC", ""]
    for t in rep["toc"]:
        L.append("- **%s** %s: %s" % (t["level"], t.get("toc", ""), t["message"]))
    L += ["", "## API call sites", "", "| API | status | replacement | notes | secrecy | sites |", "|---|---|---|---|---|---|"]
    for a in rep["apis"]:
        if a["status"] == "ok":
            continue
        L.append("| %s | **%s** | %s | %s | %s | %s |" % (a["name"], a["status"], a.get("replacement") or "",
                                                        (a.get("notes") or "").replace("|", "/"), (a.get("secrecy") or "").replace("|", "/"),
                                                        ", ".join(a["sites"][:6]) + (" (+%d)" % (len(a["sites"]) - 6) if len(a["sites"]) > 6 else "")))
    oks = [a["name"] for a in rep["apis"] if a["status"] == "ok"]
    L += ["", "OK (present, no secrecy/restriction flags): " + (", ".join(oks) or "none")]
    examples = [a for a in rep["apis"] if a.get("example")]
    if examples:
        L += ["", "### Replacement examples", ""]
        for a in examples:
            L.append("- `%s` -> `%s`" % (a["name"], a["example"]))
    L += ["", "## Events", "", "| event | status | replacement | notes | sites |", "|---|---|---|---|---|"]
    for e in rep["events"]:
        L.append("| %s | %s | %s | %s | %s |" % (e["event"], "**%s**" % e["status"] if e["status"] != "ok" else "ok", e.get("replacement", ""),
                                                (e.get("notes") or "").replace("|", "/"), ", ".join(e["sites"][:5])))
    L += ["", "## Taint-prone patterns", ""]
    for t in rep["taint"] or []:
        L.append("- %s:%d [%s] %s" % (t["file"], t["line"], t["pattern"], t["message"]))
    if not rep["taint"]:
        L.append("- none found")
    L += ["", "## Secret-value flow (operations that error when the value is secret)", ""]
    for f in rep["secretFlow"]:
        L.append("- %s:%d %s %s" % (f["file"], f["line"], f["level"], f["message"]))
    if not rep["secretFlow"]:
        L.append("- none found")
    if "performance" in rep:
        L += [""] + perfcheck.markdown(rep["performance"], "Performance (PERFORMANCE.md)").split("\n")
        L += ["Runtime check for the ported code: the generated mocks ship `perf_guard.lua` and `spec/perf_spec.lua` "
              "(per-event cost at 25/50/100 growth checkpoints, no idle OnUpdate, 2-minute wall cap)."]
    return "\n".join(L) + "\n"
