"""Optional: compare a dump against Ketho/BlizzardInterfaceResources (branch `forever` by default):
Resources/GlobalAPI.lua and Resources/CVars.lua. Files are parsed as data (never executed)."""
import os
import re
import urllib.request

from .luasv import parse_savedvariables, as_list

BASE = "https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/%s/Resources/%s"


def _load(name, ref, branch):
    if ref and os.path.isdir(ref):
        with open(os.path.join(ref, name), encoding="utf-8") as f:
            return f.read()
    url = BASE % (branch, name)
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read().decode("utf-8")


def _as_data(text):
    text = re.sub(r"^local\s+", "", text, flags=re.M)
    text = re.sub(r"^return\b.*$", "", text, flags=re.M)
    return parse_savedvariables(text)


LUA_DEF = re.compile(r"^\s*function\s+([A-Za-z_][\w.]*)\s*\(|^\s*([A-Za-z_][\w.]*)\s*=", re.M)


def ui_source_definitions(ui_dir):
    """Names assigned or defined by Lua in a wow-ui-source tree (function X(), X = ..., incl. deprecation aliases)."""
    defs = set()
    for dp, _, fns in os.walk(ui_dir):
        for fn in fns:
            if fn.endswith(".lua"):
                with open(os.path.join(dp, fn), encoding="utf-8", errors="replace") as f:
                    for m in LUA_DEF.finditer(f.read()):
                        defs.add(m.group(1) or m.group(2))
    return defs


def compare(dump, ref=None, branch="forever", ui_source=None):
    res = {"source": ref or (BASE % (branch, "")), "branch": branch}
    g = _as_data(_load("GlobalAPI.lua", ref, branch))
    ketho_api = set(as_list(g.get("GlobalAPI")))
    lua_api = set(as_list(g.get("LuaAPI")))
    mine = dump.present_functions()
    # GlobalAPI.lua lists C (engine) functions only; Lua functions defined by FrameXML are in FrameXML.lua.
    # Subtract those (and the Lua stdlib) from the dump so the comparison is C API vs C API.
    framexml = set()
    try:
        framexml = set(as_list(_as_data(_load("FrameXML.lua", ref, branch)).get("FrameXML")))
    except Exception:  # optional file
        pass
    res["readme"] = None
    try:
        m = re.search(r"GetBuildInfo\(\)\s*=>\s*(.+)", _load("../README.md", ref, branch) if ref else "")
        res["readme"] = m.group(1).strip() if m else None
    except Exception:
        pass
    mine_c = {f for f in mine if f not in framexml and f not in lua_api and "." not in f}
    mine_ns = {f for f in mine if "." in f and f.startswith("C_")}
    ketho_ns = {f for f in ketho_api if "." in f}
    ketho_glob = {f for f in ketho_api if "." not in f}
    res["globalAPI"] = {"ketho": len(ketho_api), "dump": len(mine),
                        "dumpLuaDefined": len(mine & framexml), "frameXMLListed": len(framexml),
                        "onlyKetho": sorted(ketho_api - mine - lua_api),
                        "onlyDump": sorted((mine_c - ketho_glob) | (mine_ns - ketho_ns))}
    if ui_source:
        defs = ui_source_definitions(ui_source)
        only = res["globalAPI"]["onlyDump"]
        res["globalAPI"]["onlyDumpLuaDefinedInUISource"] = sorted(x for x in only if x in defs)
        res["globalAPI"]["onlyDump"] = sorted(x for x in only if x not in defs)
    try:
        ev = _as_data(_load("Events.lua", ref, branch)).get("Events") or {}
        kev = set()
        for v in ev.values():
            kev.update(as_list(v))
        dev = set(dump.events())
        res["events"] = {"ketho": len(kev), "dump": len(dev), "onlyKetho": sorted(kev - dev), "onlyDump": sorted(dev - kev)}
    except Exception as e:
        res["events"] = {"error": str(e)}
    try:
        c = _as_data(_load("CVars.lua", ref, branch))
        kvars = set(((c.get("CVars") or {}).get("var") or {}).keys())
        dvars = set(as_list(dump.db.get("cvarNames")))
        if not dvars:
            for rows in (dump.db.get("cvars") or {}).values():
                if isinstance(rows, dict):
                    dvars.update(rows.keys())
        res["cvars"] = {"ketho": len(kvars), "dump": len(dvars), "onlyKetho": sorted(kvars - dvars),
                        "onlyDump": sorted(dvars - kvars)}
    except Exception as e:  # CVars file optional
        res["cvars"] = {"error": str(e)}
    return res


def text(res, max_items=60):
    out = ["Compared with Ketho/BlizzardInterfaceResources (%s)" % res["branch"]]
    if res.get("readme"):
        out.append("Ketho data build: GetBuildInfo() => %s" % res["readme"])
    g = res.get("globalAPI") or {}
    if "dumpLuaDefined" in g:
        out.append("dump functions defined in Lua (FrameXML.lua, excluded from 'only in dump'): %d" % g["dumpLuaDefined"])
    if "onlyDumpLuaDefinedInUISource" in g:
        out.append("also defined/aliased in the --ui-source Lua (excluded): %d" % len(g["onlyDumpLuaDefinedInUISource"]))
    for key in ("globalAPI", "events", "cvars"):
        d = res.get(key) or {}
        if "error" in d:
            out.append("%s: %s" % (key, d["error"]))
            continue
        out.append("%s: ketho %d, dump %d, only in ketho %d, only in dump %d" % (
            key, d["ketho"], d["dump"], len(d["onlyKetho"]), len(d["onlyDump"])))
        for x in d["onlyKetho"][:max_items]:
            out.append("  - ketho only: %s" % x)
        for x in d["onlyDump"][:max_items]:
            out.append("  + dump only:  %s" % x)
    return "\n".join(out)
