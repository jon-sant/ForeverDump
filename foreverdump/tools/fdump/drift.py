"""Baseline signatures + drift detection.

A baseline (schema foreverdump.baseline/1) is built from a SavedVariables dump: the addon's own compact signature
(ForeverDumpLogDB.baseline, v2.2+: ops/lab/combat/tokens/knowledge/restrictions) merged with what the converter can
derive from the full SV (docs hash + per-function signatures, present API/event names, secrecy letters per API/event
position and context, restriction timing, frame types). `drift OLD NEW` compares two baselines (or SVs, or baseline
folders) and writes DRIFT.md with the changes at the top."""
import json
import os

from .dump import Dump, as_list

SCHEMA = "foreverdump.baseline/1"


def fnv_hash(strings):
    """32-bit FNV-1a over the sorted list - the same algorithm as Baseline.lua (B.Hash)"""
    h = 2166136261
    for s in strings:
        for b in s.encode("utf-8", "surrogateescape"):
            h ^= b
            h = (h * 16777619) % 4294967296
    return "%08x" % h


def _type(x):
    return str(x.get("Type")) if isinstance(x, dict) else "nil"


def docs_signatures(dump):
    names, sigs, nf, ne, events = [], {}, 0, 0, []
    for sys in dump.doc_systems():
        nsn = str(sys.get("Namespace") or sys.get("Name") or "")
        for f in as_list(sys.get("Functions")):
            nf += 1
            args = ",".join(_type(a) for a in as_list(f.get("Arguments")))
            rets = ",".join(_type(r) for r in as_list(f.get("Returns")))
            s = "%s.%s(%s)%s" % (nsn, f.get("Name"), args, rets)
            names.append(s)
            key = ("%s.%s" % (sys.get("Namespace"), f.get("Name"))) if sys.get("Namespace") else str(f.get("Name"))
            if sys.get("Type") == "ScriptObject":
                key = "%s:%s" % (sys.get("Name"), f.get("Name"))
            sigs[key] = "(%s) -> %s" % (args, rets)
        for e in as_list(sys.get("Events")):
            ne += 1
            names.append("E:%s" % e.get("LiteralName"))
            events.append(str(e.get("LiteralName")))
            sigs["event:" + str(e.get("LiteralName"))] = ",".join(_type(p) for p in as_list(e.get("Payload")))
    names.sort()
    if not names:
        return {"missing": True}, {}, []
    return {"hash": fnv_hash(names), "functions": nf, "events": ne, "systems": len(dump.doc_systems())}, sigs, sorted(events)


def _letter(seen, sec):
    if not seen:
        return "-"
    if sec == seen:
        return "S"
    if sec == 0:
        return "C"
    return "M"


def secrecy(dump):
    out = {}
    for key, row in (dump.db.get("secretsObs") or {}).items():
        if not isinstance(key, str) or key.startswith("_") or not isinstance(row, dict):
            continue
        parts = []
        for pos in range(1, 13):
            c = row.get(pos)
            if not isinstance(c, list) or len(c) < 6:
                break
            parts.append(_letter(c[0], c[1]) + _letter(c[2], c[3]) + _letter(c[4], c[5]))
        if parts:
            out[key] = " ".join(parts)
    return out


def restriction_timing(dump):
    r = dump.log.get("restrictions") or {}
    flips, lat, last = {}, [], {}
    for f in as_list(r.get("flips")):
        k = "%s:%s" % (f.get("typeName", f.get("type")), f.get("stateName", f.get("state")))
        flips[k] = flips.get(k, 0) + 1
        if f.get("state") == 1:
            last[f.get("type")] = f.get("t")
        if f.get("state") == 2 and last.get(f.get("type")) is not None and f.get("t") is not None:
            lat.append(f["t"] - last[f["type"]])
    if not flips:
        return None
    return {"flips": flips, "activatingToActive": (sum(lat) / len(lat)) if lat else None}


def from_dump(dump):
    m = dump.meta()
    docs, sigs, events = docs_signatures(dump)
    base = {"schema": SCHEMA, "build": m.get("build"), "version": m.get("version"), "interface": m.get("toc"),
            "projectID": m.get("projectID"), "projectName": m.get("projectName"), "addon": m.get("addonVersion"),
            "docs": docs, "signatures": sigs, "events": events, "present": sorted(dump.present_functions()),
            "secrecy": secrecy(dump), "restrictions": restriction_timing(dump), "source": os.path.basename(str(dump.source))}
    w = dump.sections.get("widgets") or {}
    ft = {t: True for t in (w.get("types") or {})}
    ft.update({t: "notCreatable" for t in (w.get("notCreatable") or {})})
    for t in (w.get("failures") or {}):
        ft.setdefault(t, "failed")
    base["frameTypes"] = ft
    sig = dump.log.get("baseline")
    if isinstance(sig, dict):     # addon-side v2.2 parts
        for k in ("ops", "lab", "combat", "combatAbsent", "tokens", "knowledge"):
            if sig.get(k) is not None:
                base[k] = sig[k]
        base["addonSignature"] = {"v": sig.get("v"), "docs": sig.get("docs"), "reason": sig.get("reason")}
        if not base["restrictions"] and sig.get("restrictions"):
            base["restrictions"] = sig["restrictions"]
        if not base["secrecy"] and sig.get("secrecy"):
            base["secrecy"] = sig["secrecy"]
    else:
        base["note"] = "SV predates v2.2: no addon-side signature (ops/lab/combat/tokens/knowledge not available)"
    return base


def load(path):
    """baseline.json, a folder containing baseline.json, or anything Dump.load accepts"""
    p = path
    if os.path.isdir(p) and os.path.exists(os.path.join(p, "baseline.json")):
        p = os.path.join(p, "baseline.json")
    if p.endswith(".json"):
        with open(p, encoding="utf-8") as f:
            data = json.load(f)
        if data.get("schema") == SCHEMA:
            return data
    return from_dump(Dump.load(path))


def save(base, folder):
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, "baseline.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(base, f, indent=1, sort_keys=True, ensure_ascii=False)
    return path


def _dict_diff(a, b):
    a, b = a or {}, b or {}
    added = sorted(k for k in b if k not in a)
    removed = sorted(k for k in a if k not in b)
    changed = sorted(k for k in a if k in b and a[k] != b[k])
    return added, removed, changed


def _has_secret(s):
    return isinstance(s, str) and ("S" in s.replace("*", "") or "M" in s or s.startswith("T"))


def compare(old, new):
    r = {"old": {k: old.get(k) for k in ("build", "version", "interface", "projectID", "addon", "source")},
         "new": {k: new.get(k) for k in ("build", "version", "interface", "projectID", "addon", "source")}}
    r["buildBump"] = str(old.get("build")) != str(new.get("build"))
    r["interfaceChange"] = str(old.get("interface")) != str(new.get("interface"))
    r["docsHashChange"] = (old.get("docs") or {}).get("hash") != (new.get("docs") or {}).get("hash")
    # secrecy: per key/pos/context letters
    ns, nc = [], []
    os_, nw = old.get("secrecy") or {}, new.get("secrecy") or {}
    for k in sorted(set(os_) & set(nw)):
        a, b = os_[k].split(), nw[k].split()
        for pos in range(min(len(a), len(b))):
            for ci, ctx in enumerate(("ooc", "combat", "enc")):
                x, y = a[pos][ci], b[pos][ci]
                if x == "-" or y == "-" or x == y:
                    continue
                if y in "SM" and x == "C":
                    ns.append("%s#%d (%s): %s -> %s" % (k, pos + 1, ctx, x, y))
                elif y == "C" and x in "SM":
                    nc.append("%s#%d (%s): %s -> %s" % (k, pos + 1, ctx, x, y))
    for sect, label in (("combat", "combat probe"), ("tokens", "token survey"), ("knowledge", "spell knowledge")):
        a, b = old.get(sect) or {}, new.get(sect) or {}
        for k in sorted(set(a) & set(b)):
            x, y = str(a[k]), str(b[k])
            if x == y:
                continue
            if _has_secret(y) and not _has_secret(x):
                ns.append("%s %s: %s -> %s" % (label, k, x, y))
            elif _has_secret(x) and not _has_secret(y):
                nc.append("%s %s: %s -> %s" % (label, k, x, y))
    r["newlySecret"], r["newlyClear"] = ns, nc
    po, pn = set(old.get("present") or []), set(new.get("present") or [])
    r["apisAdded"], r["apisRemoved"] = (sorted(pn - po), sorted(po - pn)) if po and pn else ([], [])
    eo, en = set(old.get("events") or []), set(new.get("events") or [])
    r["eventsAdded"], r["eventsRemoved"] = (sorted(en - eo), sorted(eo - en)) if eo and en else ([], [])
    so, sn = old.get("signatures") or {}, new.get("signatures") or {}
    r["signatureChanges"] = ["%s: %s -> %s" % (k, so[k], sn[k]) for k in sorted(set(so) & set(sn)) if so[k] != sn[k]]
    r["docsAdded"] = sorted(k for k in sn if k not in so) if so else []
    r["docsRemoved"] = sorted(k for k in so if k not in sn) if sn else []
    ro, rn = old.get("restrictions") or {}, new.get("restrictions") or {}
    rt = []
    a, b = ro.get("activatingToActive"), rn.get("activatingToActive")
    if a is not None and b is not None and abs(a - b) > 0.05:
        rt.append("Activating -> Active latency %.3fs -> %.3fs" % (a, b))
    fa, fr, _ = _dict_diff(ro.get("flips"), rn.get("flips"))
    rt += ["new flip kind %s" % k for k in fa] + ["flip kind no longer seen %s" % k for k in fr]
    r["restrictionTiming"] = rt
    fo, fn = old.get("frameTypes") or {}, new.get("frameTypes") or {}
    a2, r2, c2 = _dict_diff(fo, fn)
    r["frameTypesAdded"], r["frameTypesRemoved"] = a2, r2
    r["frameTypesChanged"] = ["%s: %s -> %s" % (k, fo[k], fn[k]) for k in c2]
    for sect in ("ops", "lab"):
        a, b = old.get(sect) or {}, new.get(sect) or {}
        ch = []
        for ctx in sorted(set(a) & set(b)):
            x, y = a[ctx] or {}, b[ctx] or {}
            for k in sorted(set(x) | set(y)):
                if x.get(k) != y.get(k):
                    ch.append("%s %s: %s -> %s" % (ctx, k, x.get(k), y.get(k)))
        r[sect + "Changes"] = ch
    r["coverage"] = {s: (bool(old.get(s)), bool(new.get(s))) for s in ("secrecy", "ops", "lab", "combat", "tokens", "knowledge", "restrictions")}
    return r


def _list(title, items, limit=60):
    out = ["### %s (%d)" % (title, len(items)), ""]
    if not items:
        return out + ["none", ""]
    out += ["- `%s`" % x for x in items[:limit]]
    if len(items) > limit:
        out.append("- ... %d more (drift.json)" % (len(items) - limit))
    return out + [""]


def markdown(r):
    o, n = r["old"], r["new"]
    out = ["# Drift report", "", "old: build %s (%s, toc %s, addon %s) `%s`" % (o["build"], o["version"], o["interface"], o["addon"], o["source"]),
           "new: build %s (%s, toc %s, addon %s) `%s`" % (n["build"], n["version"], n["interface"], n["addon"], n["source"]), "",
           "## Summary", "",
           "| change | count |", "|---|---|",
           "| build bump | %s |" % ("**yes**" if r["buildBump"] else "no"),
           "| interface change | %s |" % ("**yes**" if r["interfaceChange"] else "no"),
           "| API docs hash changed | %s |" % ("**yes**" if r["docsHashChange"] else "no")]
    for k, label in (("newlySecret", "newly secret"), ("newlyClear", "newly clear"), ("apisAdded", "APIs added"),
                     ("apisRemoved", "APIs removed"), ("eventsAdded", "events added"), ("eventsRemoved", "events removed"),
                     ("signatureChanges", "signature changes"), ("restrictionTiming", "restriction timing changes"),
                     ("frameTypesAdded", "frame types added"), ("frameTypesRemoved", "frame types removed"),
                     ("frameTypesChanged", "frame types changed (creatable state)"), ("opsChanges", "operations matrix changes"),
                     ("labChanges", "lab changes")):
        out.append("| %s | %s |" % (label, ("**%d**" % len(r[k])) if r[k] else "0"))
    out += ["", "Coverage (old, new): " + ", ".join("%s %s" % (k, "/".join("yes" if x else "no" for x in v)) for k, v in r["coverage"].items()), ""]
    out += ["## Details", ""]
    for k, label in (("newlySecret", "Newly secret"), ("newlyClear", "Newly clear"), ("apisAdded", "APIs added"),
                     ("apisRemoved", "APIs removed"), ("eventsAdded", "Events added"), ("eventsRemoved", "Events removed"),
                     ("signatureChanges", "Signature changes"), ("docsAdded", "Documented functions/events added"),
                     ("docsRemoved", "Documented functions/events removed"), ("restrictionTiming", "Restriction timing"),
                     ("frameTypesAdded", "Frame types added"), ("frameTypesRemoved", "Frame types removed"),
                     ("frameTypesChanged", "Frame types changed"), ("opsChanges", "Operations matrix"), ("labChanges", "Lab")):
        out += _list(label, r[k])
    return "\n".join(out) + "\n"
