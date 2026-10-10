"""(2) LuaLS (lua-language-server) annotation stubs generated from a dump."""
import os
import re

from .luasv import as_list

IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LUA_KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local",
                "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "goto"}
PRIM = {
    "bool": "boolean", "boolean": "boolean", "number": "number", "luaIndex": "number", "fileID": "number",
    "size_t": "number", "time_t": "number", "uiMapID": "number", "integer": "number", "float": "number",
    "string": "string", "cstring": "string", "function": "function", "table": "table", "userdata": "userdata",
    "WOWGUID": "string", "textureAtlas": "string", "textureKit": "string", "uiAddon": "string|number",
    "kstringClubMessage": "string", "ClubId": "string", "ClubStreamId": "string", "BigUInteger": "string",
    "BigInteger": "string", "FileAsset": "string|number", "TextureAsset": "string|number",
    "UnitToken": "string", "UnitTokenVariant": "string", "UnitTokenType": "string", "uiUnit": "number", "normalizedValue": "number", "uiRect": "table",
    "SpellIdentifier": "number|string", "ItemInfo": "number|string", "LuaValueVariant": "any",
    "SimpleFrame": "Frame", "SimpleTexture": "Texture", "SimpleFontString": "FontString",
}


def lua_str(s):
    s = str(s)
    out = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")
    out = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", lambda m: "\\%03d" % ord(m.group(0)), out)
    return '"' + out + '"'


def key(k):
    if isinstance(k, str) and IDENT.match(k) and k not in LUA_KEYWORDS:
        return k
    return "[%s]" % (lua_str(k) if isinstance(k, str) else k)


def lua_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    return lua_str(v)


def safe_name(n):
    n = re.sub(r"[^A-Za-z0-9_]", "_", str(n))
    if not n or n[0].isdigit() or n in LUA_KEYWORDS:
        n = "_" + n
    return n


class TypeMapper:
    def __init__(self, dump):
        self.tables = dump.doc_tables()
        self.enums = {n for n, t in self.tables.items() if t.get("Type") == "Enumeration"}
        self.structs = {n for n, t in self.tables.items() if t.get("Type") == "Structure"}
        self.callbacks = {n for n, t in self.tables.items() if t.get("Type") == "CallbackType"}
        self.unknown = set()

    def base(self, t):
        if t is None:
            return "any"
        if t in PRIM:
            return PRIM[t]
        if t in self.enums:
            return "Enum." + t
        if t in self.structs or t in self.callbacks:
            return t
        self.unknown.add(t)
        return t

    def of(self, field):
        if field.get("Mixin"):
            return field["Mixin"]
        t = field.get("Type")
        if t == "table" and field.get("InnerType"):
            inner = self.base(field["InnerType"])
            return ("(%s)[]" % inner) if "|" in inner else inner + "[]"
        return self.base(t)

    def alias_lines(self):
        out = []
        for t in sorted(self.unknown):
            if not IDENT.match(t):
                continue
            guess = "any"
            if re.search(r"(GUID|Token|String|Atlas|Kit|Name|Text|Link|Path)$", t):
                guess = "string"
            elif re.search(r"(ID|Index|Count|Level|Slot|Rank|Type|Flags|Mask|Amount|Time|Duration)$", t):
                guess = "number"
            out.append("---@alias %s %s" % (t, guess))
        return out


FLAG_SKIP = {"Name", "Type", "Arguments", "Returns", "Documentation", "_present", "Payload", "LiteralName",
             "Fields", "Values"}


def flag_text(node):
    flags = ["%s=%s" % (k, node[k]) for k in sorted(node, key=str)
             if isinstance(k, str) and k not in FLAG_SKIP and not isinstance(node[k], (dict, list))]
    return ", ".join(flags)


def doc_lines(node, indent=""):
    out = []
    for d in as_list(node.get("Documentation")):
        for line in str(d).splitlines():
            out.append(indent + "--- " + line)
    f = flag_text(node)
    if f:
        out.append(indent + "--- `" + f + "`")
    return out


SMAP = {"functions": {}, "events": {}, "structs": {}}
SECRET_ARG_TEXT = {
    "NotAllowed": "passing a secret value as an argument raises an error",
    "AllowedWhenUntainted": "only secure (untainted) code may pass secret values; addon code passing one errors",
    "AllowedWhenTainted": "addon code may pass secret values",
}


def secret_lines(full):
    e = SMAP["functions"].get(full)
    if not e:
        return []
    out = []
    sec = e["secrecy"]
    if sec in ("always", "conditional", "partial"):
        out.append("--- **Secret returns** (%s)%s. Guard with `issecretvalue(v)` before arithmetic, comparison, "
                   "concatenation or using it as a table key." % (sec, (": " + ", ".join(e["conditions"])) if e["conditions"] else ""))
    obs = e.get("observedSummary") or {}
    if obs:
        out.append("--- Observed: " + "; ".join("%s secret at %s (%d samples)" % (k, v["secretPositions"] or "none", v["samples"])
                                                for k, v in obs.items()))
    if e.get("secretArguments") in SECRET_ARG_TEXT:
        out.append("--- Secret arguments: %s (%s)." % (e["secretArguments"], SECRET_ARG_TEXT[e["secretArguments"]]))
    if e.get("restrictions"):
        out.append("--- Restrictions: " + ", ".join(e["restrictions"]))
    return out


def ret_secret_suffix(full, idx):
    e = SMAP["functions"].get(full)
    if not e or idx >= len(e["returns"]):
        return ""
    r = e["returns"][idx]
    obs = e.get("observedSummary") or {}
    seen = any(idx + 1 in v["secretPositions"] for v in obs.values())
    v = (e.get("verify") or {}).get(str(idx + 1)) or {}
    if v.get("status") == "CONTRADICTED":
        mark = " [CONTRADICTED: %s]" % v.get("note", "")
    elif v.get("status") == "UNDOCUMENTED-SECRET":
        return " # SECRET (observed at runtime, undocumented) [verified]"
    elif v.get("verified"):
        mark = " [verified]"
    else:
        mark = " [unverified]"
    if r["secrecy"] == "always":
        return " # SECRET (always)" + mark
    if r["secrecy"] == "conditional":
        return " # SECRET when: %s%s" % (", ".join(e["conditions"]) or "ConditionalSecret", mark)
    if seen:
        return " # SECRET (observed at runtime)" + mark
    if r["secrecy"] == "never":
        return " # never secret" + mark
    return ""


def func_stub(full, f, tm, present=True, sep="."):
    lines = doc_lines(f) + secret_lines(full)
    if not present:
        lines.append("--- **Documented but NOT present in this Forever client.**")
        lines.append("---@deprecated")
    params = []
    for a in as_list(f.get("Arguments")):
        name = safe_name(a.get("Name", "arg"))
        opt = "?" if a.get("Nilable") or "Default" in a else ""
        desc = (" Default: %s" % a["Default"]) if "Default" in a else ""
        lines.append("---@param %s%s %s%s" % (name, opt, tm.of(a), desc))
        params.append(name)
    for ri, r in enumerate(as_list(f.get("Returns"))):
        t = tm.of(r)
        if r.get("Nilable"):
            t += "?"
        sfx = ret_secret_suffix(full, ri)
        if r.get("StrideIndex"):
            lines.append("---@return %s ... %s%s" % (t, safe_name(r.get("Name", "ret")), sfx))
        else:
            lines.append("---@return %s %s%s" % (t, safe_name(r.get("Name", "ret")), sfx))
    lines.append("function %s(%s) end" % (full, ", ".join(params)))
    return lines


def undocumented_stub(full):
    return ["--- Present in the client, not in Blizzard_APIDocumentation (signature unknown).",
            "---@return any ...", "function %s(...) end" % full]


def write(path, lines):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("---@meta\n-- Generated by ForeverDump tools from %s. Do not edit.\n\n" % write.label)
        f.write("\n".join(lines) + "\n")


def generate(dump, out):
    from . import secrets as secretsmod
    global SMAP
    SMAP = secretsmod.build(dump)
    write.label = dump.build_label()
    tm = TypeMapper(dump)
    files = []
    docfns = dump.doc_functions()
    present = dump.present_functions()
    have_present = bool(present)

    def is_present(full):
        return (full in present) if have_present else True

    # ---- namespaces
    by_ns = {}
    for full, (sys, f) in docfns.items():
        ns = sys.get("Namespace")
        by_ns.setdefault(ns, []).append((full, sys, f))
    for ns, info in dump.namespaces().items():
        for fn in as_list(info.get("functions")):
            full = ns + "." + fn
            if full not in docfns:
                by_ns.setdefault(ns, []).append((full, None, None))
    for ns in sorted(k for k in by_ns if k):
        lines = ["%s = {}" % ns, ""]
        for full, sys, f in sorted(by_ns[ns], key=lambda x: x[0]):
            lines += func_stub(full, f, tm, is_present(full)) if f else undocumented_stub(full)
            lines.append("")
        rel = "Namespaces/%s.lua" % safe_name(ns)
        write(os.path.join(out, rel), lines)
        files.append(rel)

    # ---- global functions
    lines = []
    for full, sys, f in sorted(by_ns.get(None, []), key=lambda x: x[0]):
        lines += func_stub(full, f, tm, is_present(full)) + [""]
    secure, _ = dump.global_functions()
    documented = set(docfns)
    widget_names = set()
    for s in secure:
        if s not in documented and IDENT.match(s) and s != "CreateFrame":
            lines += undocumented_stub(s) + [""]
    write(os.path.join(out, "Globals.lua"), lines)
    files.append("Globals.lua")

    # ---- structures / callback types
    lines = []
    for name in sorted(tm.structs):
        t = tm.tables[name]
        lines += doc_lines(t)
        lines.append("---@class %s" % name)
        for fld in as_list(t.get("Fields")):
            opt = "?" if fld.get("Nilable") else ""
            cls = ("always" if fld.get("SecretValue") else "never" if fld.get("NeverSecret")
                   else "conditional" if fld.get("ConditionalSecret") else "")
            sfx = {"always": " # SECRET (always)", "conditional": " # SECRET (conditional)", "never": " # never secret"}.get(cls, "")
            lines.append("---@field %s%s %s%s" % (fld.get("Name"), opt, tm.of(fld), sfx))
        lines.append("")
    for name in sorted(tm.callbacks):
        t = tm.tables[name]
        args = ", ".join("%s: %s" % (safe_name(a.get("Name", "arg")), tm.of(a)) for a in as_list(t.get("Arguments")))
        lines += doc_lines(t) + ["---@alias %s fun(%s)" % (name, args), ""]
    write(os.path.join(out, "Structures.lua"), lines)
    files.append("Structures.lua")

    # ---- enums (runtime values win over documented ones)
    runtime = dump.runtime_enum()
    lines = ["Enum = {}", ""]
    names = set(runtime) | tm.enums
    for name in sorted(names, key=str):
        if not isinstance(name, str) or not IDENT.match(name):
            continue
        values = runtime.get(name)
        if not isinstance(values, dict):
            values = {f.get("Name"): f.get("EnumValue") for f in as_list(tm.tables.get(name, {}).get("Fields"))}
        lines.append("---@enum Enum.%s" % name)
        lines.append("Enum.%s = {" % name)
        for k in sorted(values, key=lambda k: (str(type(values[k])), values[k] if isinstance(values[k], (int, float)) else 0, str(k))):
            v = values[k]
            if isinstance(v, (int, float, str, bool)):
                lines.append("\t%s = %s," % (key(k), lua_value(v)))
        lines += ["}", ""]
    write(os.path.join(out, "Enums.lua"), lines)
    files.append("Enums.lua")

    # ---- constants
    lines = []
    ct = (dump.sections.get("globals") or {}).get("constantsTable")
    if isinstance(ct, dict) and ct:
        lines.append("Constants = {")

        def emit(d, depth):
            for k in sorted(d, key=str):
                v = d[k]
                if isinstance(v, dict):
                    lines.append("\t" * depth + "%s = {" % key(k))
                    emit(v, depth + 1)
                    lines.append("\t" * depth + "},")
                elif isinstance(v, (int, float, str, bool)):
                    lines.append("\t" * depth + "%s = %s," % (key(k), lua_value(v)))
        emit(ct, 1)
        lines += ["}", ""]
    for k, v in sorted(dump.constants().items()):
        if IDENT.match(str(k)) and isinstance(v, (int, float, bool, str)):
            lines.append("%s = %s" % (k, lua_value(v)))
    write(os.path.join(out, "Constants.lua"), lines)
    files.append("Constants.lua")

    # ---- events
    lines = ["---@alias ForeverEvent"]
    evdocs = dump.doc_events()
    for ev in sorted(set(dump.events()) | set(evdocs)):
        payload = ""
        se = SMAP["events"].get(ev) or {}
        sec_pl = {p["name"]: p["secrecy"] for p in se.get("payload", [])}
        if ev in evdocs:
            payload = ", ".join("%s: %s%s" % (p.get("Name"), tm.of(p), {"always": " [SECRET]", "conditional": " [secret?]"}.get(
                sec_pl.get(p.get("Name")), "")) for p in as_list(evdocs[ev][1].get("Payload")))
        obs = se.get("observedSummary") or {}
        if obs:
            payload += " (observed secret positions: %s)" % "; ".join("%s %s" % (k, v["secretPositions"]) for k, v in obs.items())
        if se.get("conditions"):
            payload += " {%s}" % ", ".join(se["conditions"])
        lines.append('---| "%s" # %s' % (ev, payload))
    write(os.path.join(out, "Events.lua"), lines)
    files.append("Events.lua")

    # ---- widgets
    lines = []
    types = dump.widget_types()
    methods = {}
    cls_of = {}
    for label, info in types.items():
        cls = info.get("objectType") or label.split(":")[-1]
        cls = safe_name(cls.split(".")[-1])
        cls_of[label] = cls
        methods[cls] = set(as_list(info.get("methods"))) | methods.get(cls, set())
    isa = {cls_of[l]: set(as_list(i.get("isA"))) for l, i in types.items()}
    sysfns = [(s, {f.get("Name"): f for f in as_list(s.get("Functions"))}) for s in dump.scriptobject_systems()]
    for cls in sorted(methods):
        mset = methods[cls]
        parent, best = None, -1
        for other, oset in methods.items():
            if other != cls and other in isa.get(cls, set()) and oset < mset and len(oset) > best:
                parent, best = other, len(oset)
        own = mset - (methods[parent] if parent else set())
        applicable = [(s, fns) for s, fns in sysfns if fns and set(fns) <= mset]
        applicable.sort(key=lambda x: len(x[1]))
        lines.append("---@class %s%s" % (cls, (" : " + parent) if parent else ""))
        lines.append("local %s = {}" % cls)
        for m in sorted(own):
            sig = next((fns[m] for _, fns in applicable if m in fns), None)
            if m in ("RegisterEvent", "UnregisterEvent", "IsEventRegistered"):
                lines += ["---@param event ForeverEvent", "---@return boolean",
                          "function %s:%s(event) end" % (cls, m)]
                continue
            if m == "RegisterUnitEvent":
                lines += ["---@param event ForeverEvent", "---@param ... string", "---@return boolean",
                          "function %s:%s(event, ...) end" % (cls, m)]
                continue
            if sig:
                body = func_stub("%s:%s" % (cls, m), sig, tm)
            else:
                body = ["---@return any ...", "function %s:%s(...) end" % (cls, m)]
            lines += body
        lines.append("")
        widget_names.add(cls)
    creatable = sorted({cls_of[l] for l in types if not l.startswith(("Anim:", "Userdata:")) and
                        l not in ("Texture", "MaskTexture", "Line", "FontString", "AnimationGroup", "ControlPoint", "Font")})
    lines.append("---@alias FrameType " + ("|".join('"%s"' % c for c in creatable) or "string"))
    lines.append("---@param frameType FrameType")
    lines.append("---@param name? string")
    lines.append("---@param parent? any")
    lines.append("---@param template? string")
    lines.append("---@param id? number")
    lines.append("---@return Frame")
    for c in creatable:
        lines.append('---@overload fun(frameType: "%s", name?: string, parent?: any, template?: string, id?: number): %s' % (c, c))
    lines.append("function CreateFrame(frameType, name, parent, template, id) end")
    write(os.path.join(out, "Widgets.lua"), lines)
    files.append("Widgets.lua")

    # ---- named frames
    lines = []
    for name, info in sorted(dump.frames().items()):
        if IDENT.match(name) and isinstance(info, dict):
            t = safe_name(info.get("objectType") or "Frame")
            lines += ["---@type %s" % (t if t in widget_names else "Frame"), "%s = {}" % name]
    write(os.path.join(out, "Frames.lua"), lines)
    files.append("Frames.lua")

    # ---- non-C_ global tables (mixins, utils, registries)
    lines = []
    for name, info in sorted(dump.global_tables().items()):
        if not IDENT.match(name) or not isinstance(info, dict) or info.get("insecure"):
            continue
        if info.get("alias"):
            lines.append("%s = %s" % (name, info["alias"]))
            continue
        lines.append("---@class %s" % name)
        lines.append("%s = {}" % name)
        for fn in as_list(info.get("functions")):
            if IDENT.match(fn):
                lines.append("function %s.%s(...) end" % (name, fn))
        lines.append("")
    write(os.path.join(out, "GlobalTables.lua"), lines)
    files.append("GlobalTables.lua")

    # ---- global strings
    lines = ["%s = %s" % (k, lua_str(v)) for k, v in sorted(dump.strings.items()) if IDENT.match(str(k))]
    write(os.path.join(out, "GlobalStrings.lua"), lines)
    files.append("GlobalStrings.lua")

    # ---- aliases for unknown documented type names
    write(os.path.join(out, "Aliases.lua"), tm.alias_lines())
    files.append("Aliases.lua")

    with open(os.path.join(out, ".luarc.json.example"), "w") as f:
        f.write('{\n  "runtime.version": "Lua 5.1",\n  "workspace.library": ["%s"],\n'
                '  "diagnostics.globals": ["ForeverDumpDB"],\n  "workspace.checkThirdParty": false\n}\n'
                % os.path.abspath(out).replace("\\", "/"))
    return files
