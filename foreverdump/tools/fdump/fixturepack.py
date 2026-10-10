"""Fixture packs from real captures (fixtures/<build>/), v2.2.21: RAW.

User decision 2026-10-09: no data is scrubbed, anonymized or rewritten. The combat log and taint log are copied
byte-for-byte (optionally the first N lines), player GUIDs / names / realms included. environment.json keeps the SV
meta and every changed CVar as read; api-surface.json lists the API names.
"""
import json
import shutil


def combat_log(src, dst, max_lines=None):
    """copy the first max_lines lines verbatim (all when max_lines is falsy) -> number of lines written"""
    if not max_lines:
        shutil.copyfile(src, dst)
        with open(dst, "rb") as f:
            return sum(1 for _ in f)
    n = 0
    with open(src, "rb") as f, open(dst, "wb") as o:
        for ln in f:
            if n >= max_lines:
                break
            o.write(ln)
            n += 1
    return n


def taint_log(src, dst):
    shutil.copyfile(src, dst)


def environment(dump):
    """build / environment facts and every changed CVar, as read (raw)"""
    meta = dump.meta() if callable(getattr(dump, "meta", None)) else {}
    keep = dict(meta) if isinstance(meta, dict) else {}
    cv = (dump.sections.get("cvars") or {})
    keep["cvarsChanged"] = {c.get("name"): c.get("current") for c in (cv.get("changedFromDefault") or [])
                            if isinstance(c, dict)}
    keep["cvarCounts"] = cv.get("counts")
    return keep


def api_surface(dump):
    ns = dump.namespaces()
    sec, insec = dump.global_functions()
    return {
        "globalFunctions": sorted(set(sec) | set(insec)),
        "namespaces": {k: sorted(v) for k, v in sorted(ns.items())},
        "events": sorted(dump.events()),
        "counts": {"globalFunctions": len(set(sec) | set(insec)), "namespaces": len(ns),
                   "namespaceFunctions": sum(len(v) for v in ns.values()), "events": len(dump.events())},
    }


def write_json(path, obj):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=1, sort_keys=True, ensure_ascii=False, default=str)
