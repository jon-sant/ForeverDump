"""Load a ForeverDump dump (SavedVariables .lua, dump.json, or an export dir) and expose views."""
import json
import os

from .luasv import parse_savedvariables, as_list

SV_NAMES = ("ForeverDumpDB", "ForeverDumpStaticDB", "ForeverDumpDocsDB", "ForeverDumpStringsDB", "ForeverDumpRecordDB",
            "ForeverDumpLogDB", "ForeverDumpCombatLogDB")
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REFERENCE_DIR = os.path.join(REPO, "fixtures", "forever-70245")
STATIC_SECTIONS = ("docs", "api", "globals", "strings", "widgets", "templates", "frames", "addons", "cvars", "protected",
                   "extras")


def splice_static(raw):
    """v2.2.7: the addon saves static client data once per build in ForeverDumpStaticDB (docs, strings, static sections,
    v1 keys). Put it back into the legacy layout every tool reads (ForeverDumpDocsDB / ForeverDumpStringsDB /
    ForeverDumpDB.sections.* / ForeverDumpDB.apis...). Capture-only SVs (static cleared) keep the marker
    ForeverDumpDB.static; Dump then falls back to the repo reference (fixtures/forever-70245)."""
    st = raw.pop("ForeverDumpStaticDB", None)
    db = raw.setdefault("ForeverDumpDB", {})
    info = {"source": None, "marker": db.get("static")}
    if isinstance(st, dict):
        info["sig"] = st.get("sig")
        if isinstance(st.get("docs"), dict) and st["docs"] and not raw.get("ForeverDumpDocsDB"):
            raw["ForeverDumpDocsDB"] = st["docs"]
        if isinstance(st.get("strings"), dict) and st["strings"] and not raw.get("ForeverDumpStringsDB"):
            raw["ForeverDumpStringsDB"] = st["strings"]
        secs = db.setdefault("sections", {})
        for k, v in (st.get("sections") or {}).items():
            secs.setdefault(k, v)
        for k, v in (st.get("v1") or {}).items():
            db.setdefault(k, v)
        if st.get("sections") or st.get("docs"):
            info["source"] = "sv"
    elif raw.get("ForeverDumpDocsDB") or (db.get("sections") or {}).get("api"):
        info["source"] = "sv-legacy"
    raw["_static"] = info
    return raw


def _int_keys(obj):
    """JSON turns int keys into strings; give them back for Lua-ish tables."""
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            if isinstance(k, str) and k.isdigit():
                k = int(k)
            out[k] = _int_keys(v)
        return out
    if isinstance(obj, list):
        return [_int_keys(v) for v in obj]
    return obj


def load_raw(path):
    if os.path.isdir(path):
        path = os.path.join(path, "dump.json")
    if path.endswith(".json"):
        with open(path, encoding="utf-8") as f:
            return _int_keys(json.load(f))
    # v2.2.11: parsed once per file content + parser code, then reused from .cache/svcache (see svcache.py)
    from .svcache import parse_file
    return splice_static(parse_file(path))


def load_reference(path=REFERENCE_DIR):
    """names-only static reference shipped in the repo (api-surface.json + environment.json of build 70245)"""
    try:
        with open(os.path.join(path, "api-surface.json"), encoding="utf-8") as f:
            ref = json.load(f)
        with open(os.path.join(path, "environment.json"), encoding="utf-8") as f:
            ref["environment"] = json.load(f)
        return ref
    except (OSError, ValueError):
        return None


class Dump:
    def __init__(self, raw, source=""):
        # v2.2.10: DAMAGE_METER_* run-length rows -> every original occurrence (lossless), before any tool reads the rings
        from . import dmrle
        self.rle_expanded = dmrle.expand_dump(raw) if isinstance(raw, dict) else {}
        self.raw = raw
        self.source = source
        self.db = raw.get("ForeverDumpDB") or {}
        self.docs = raw.get("ForeverDumpDocsDB") or {}
        sdb = raw.get("ForeverDumpStringsDB") or {}
        self.strings = sdb.get("strings") or {}
        # v2.1 compact dumps store global string names only (values are in Ketho GlobalStrings / GlobalStrings.db2)
        self.strings_compact = not self.strings and bool(sdb.get("names"))
        if self.strings_compact:
            self.strings = {n: "" for n in as_list(sdb.get("names"))}
        self.record = raw.get("ForeverDumpRecordDB") or {}
        self.log = raw.get("ForeverDumpLogDB") or {}
        self.combatlog = raw.get("ForeverDumpCombatLogDB") or {}
        from . import timefmt   # time audit: report clocks in the client's zone, not the box's
        timefmt.set_client_offset(timefmt.dump_offset(raw))
        self.sections = self.db.get("sections") or {}
        self._doc_index = None
        info = raw.get("_static") or {}
        self.static_source = info.get("source") or ("sv-legacy" if (self.docs or self.sections.get("api")) else None)
        self.reference = None
        if not self.static_source:
            self.reference = load_reference()
            if self.reference:
                self.static_source = "reference:forever-70245"

    @classmethod
    def load(cls, path):
        return cls(load_raw(path), source=path)

    # ------------------------------------------------------------ meta
    def meta(self):
        m = self.db.get("meta") or {}
        if not m:
            for s in self.sections.values():
                if isinstance(s, dict) and s.get("meta"):
                    return s["meta"]
        return m

    def build_label(self):
        m = self.meta()
        return "%s.%s (toc %s)" % (m.get("version", "?"), m.get("build", "?"), m.get("toc", "?"))

    # ------------------------------------------------------------ docs
    def doc_systems(self):
        return as_list(self.docs.get("systems"))

    def doc_tables(self):
        """All documented tables (system + shared): name -> table."""
        out = {}
        for sys in self.doc_systems():
            for t in as_list(sys.get("Tables")):
                if t.get("Name"):
                    out[t["Name"]] = t
        for t in as_list(self.docs.get("sharedTables")):
            if t.get("Name"):
                out[t["Name"]] = t
        return out

    def doc_functions(self):
        """full name -> (system, function). Excludes ScriptObject (widget) systems."""
        if self._doc_index is None:
            idx = {}
            for sys in self.doc_systems():
                if sys.get("Type") == "ScriptObject":
                    continue
                ns = sys.get("Namespace")
                for f in as_list(sys.get("Functions")):
                    name = f.get("Name")
                    if name:
                        idx[(ns + "." + name) if ns else name] = (sys, f)
            self._doc_index = idx
        return self._doc_index

    def doc_events(self):
        out = {}
        for sys in self.doc_systems():
            for e in as_list(sys.get("Events")):
                if e.get("LiteralName"):
                    out[e["LiteralName"]] = (sys, e)
        return out

    def scriptobject_systems(self):
        return [s for s in self.doc_systems() if s.get("Type") == "ScriptObject"]

    # ------------------------------------------------------------ present API
    def namespaces(self):
        """C_ namespace -> {functions: [...], fields: {...}, children: {...}}"""
        ns = (self.sections.get("api") or {}).get("namespaces") or {}
        if not ns and self.reference:
            # the repo reference is names-only: namespace -> list of member kinds (no function names)
            ns = {k: (v if isinstance(v, dict) else {"functions": [], "reference": True})
                  for k, v in (self.reference.get("namespaces") or {}).items()}
        return ns

    def global_functions(self):
        g = (self.sections.get("globals") or {}).get("functions") or {}
        sec = as_list(g.get("secure"))
        if not sec:
            # fall back on the v1 list (secure globals + C_ members)
            sec = [a for a in as_list(self.db.get("apis")) if "." not in a]
        if not sec and self.reference:
            sec = list(self.reference.get("globalFunctions") or [])
        return sec, as_list(g.get("insecure"))

    def present_functions(self):
        out = set()
        sec, _ = self.global_functions()
        out.update(sec)
        for ns, info in self.namespaces().items():
            if not isinstance(info, dict):
                continue
            for f in as_list(info.get("functions")):
                out.add(ns + "." + f)
        if not out:
            out.update(as_list(self.db.get("apis")))
        return out

    def global_tables(self):
        return (self.sections.get("globals") or {}).get("tables") or {}

    def constants(self):
        return (self.sections.get("globals") or {}).get("constants") or {}

    def runtime_enum(self):
        return (self.sections.get("globals") or {}).get("enum") or {}

    def frames(self):
        return (self.sections.get("frames") or {}).get("frames") or {}

    def widget_types(self):
        return (self.sections.get("widgets") or {}).get("types") or {}

    def events(self):
        evs = as_list(self.db.get("events"))
        if not evs:
            evs = sorted(self.doc_events())
        if not evs and self.reference:
            evs = list(self.reference.get("events") or [])
        return evs

    def all_global_names(self):
        names = set(self.present_functions())
        names.update(n.split(".")[0] for n in list(names))
        names.update(self.namespaces().keys())
        names.update(self.global_tables().keys())
        names.update(self.constants().keys())
        names.update(self.strings.keys())
        names.update(self.frames().keys())
        _, insecure = self.global_functions()
        names.update(insecure)
        for extra in ("Enum", "Constants", "_G"):
            names.add(extra)
        return names
