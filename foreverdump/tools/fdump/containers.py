"""v2.2.2 container-state schema report (CONTAINERS.md / containers.json).

Source: ForeverDumpLogDB.containers (addon >= 2.2.2: every probed return walked recursively, per field the five-state
code A/N/S/K|T/C (+E), container flags, clear length, key list, per context x unit class). For older SVs (<= 2.2.1) a
"legacy" schema is derived from the combat probe cells (one level of aura fields, return codes) and the UNIT_AURA payload
codes, so run 3 already feeds the partial-secrets matrix. Never contains values: only codes, counts, key names.
"""
import json
import os

from .probes import kv

CODES = {"A": "absent", "N": "nil", "S": "secret", "K": "container (all clear)", "T": "container with secret contents",
         "C": "clear", "E": "error", "R": "multiple returns"}
AURA_FIELDS = ["auraInstanceID", "isFromPlayerOrPlayerPet", "sourceUnit", "applications", "expirationTime", "duration",
               "dispelName", "spellId", "name", "icon", "isHelpful", "isHarmful", "canActivePlayerDispel", "points"]
GROUPS = [("player", "player"), ("target NPC", "npc"), ("party/raid", "party"), ("pet", "pet"), ("self via other token", "self")]


def group_of(ucls):
    u = str(ucls)
    if u == "player":
        return "player"
    fam, _, rel = u.partition(":")
    if fam in ("pet",) or rel.startswith("pet"):
        return "pet"
    if fam.startswith("party") or fam.startswith("raid"):
        return "party/raid"
    if rel == "self":
        return "self via other token"
    if "npc" in rel:
        return "target NPC"
    if "player" in rel:
        return "other player"
    return "other"


def base_ctx(ctx):
    return str(ctx).split("|")[0]


def _cnt(d):
    return {str(k): int(v) for k, v in (d or {}).items() if isinstance(v, (int, float))}


def node_from_codes(codes, obs=None):
    c = _cnt(codes)
    return {"s": c, "obs": obs if obs is not None else sum(c.values())}


# ---------------------------------------------------------------- extraction
def _normalize(n):
    """addon aggregate -> plain dict (SV lists of tables may come back as lists)"""
    if not isinstance(n, dict):
        return None
    out = {"s": _cnt(n.get("s")), "obs": int(n.get("obs") or 0)}
    for k in ("ty", "lenMax", "lenClear", "lenSecret", "nMax", "ncMax", "secretKeys", "iterErr", "trunc"):
        if n.get(k) is not None:
            out[k] = n[k]
    if isinstance(n.get("fl"), dict):
        out["fl"] = {k: _cnt(v) for k, v in n["fl"].items()}
    if isinstance(n.get("f"), dict):
        out["f"] = {k: _normalize(v) for k, v in n["f"].items() if isinstance(v, dict)}
    if isinstance(n.get("arr"), dict):
        out["arr"] = _normalize(n["arr"])
    return out


def from_addon(log):
    c = log.get("containers") if isinstance(log, dict) else None
    if not isinstance(c, dict) or not isinstance(c.get("schema"), dict):
        return None
    schema = {}
    for ctx, byU in c["schema"].items():
        for ucls, byP in (byU or {}).items():
            for probe, node in (byP or {}).items():
                nn = _normalize(node)
                if nn:
                    schema.setdefault(ctx, {}).setdefault(ucls, {})[probe] = nn
    return {"source": "addon:ForeverDumpLogDB.containers", "build": c.get("build"), "runs": c.get("runs"),
            "ctxRuns": c.get("ctxRuns") or {}, "skipped": c.get("skipped") or {}, "errors": c.get("errors") or {}, "schema": schema}


def from_legacy(log):
    """<= 2.2.1: combat probe cells (one level) + UNIT_AURA payload codes"""
    cp = log.get("combatProbe") if isinstance(log, dict) else None
    if not isinstance(cp, dict):
        return None
    schema = {}
    errors = {}
    for ctx, byU in (cp.get("cells") or {}).items():
        for ucls, byI in (byU or {}).items():
            for item, cell in (byI or {}).items():
                if not isinstance(cell, dict):
                    continue
                n = int(cell.get("n") or 0)
                rs = cell.get("r")
                names = None
                if isinstance(rs, dict) and rs:
                    if all(str(k).isdigit() for k in rs):
                        rs = [rs[k] for k in sorted(rs, key=lambda x: int(x))]
                    else:
                        names, rs = list(rs.keys()), list(rs.values())
                elif not isinstance(rs, list):
                    rs = []
                if cell.get("e"):
                    node = {"s": {"E": int(cell["e"])}, "obs": n}
                    if n - int(cell["e"]) > 0 and rs:
                        node["s"].update(_cnt(rs[0]))
                    errors[item.split("[")[0].replace("aura:", "C_UnitAuras.")] = str(cell.get("err") or "")[:160]
                elif len(rs) > 1:
                    node = {"s": {"R": n}, "obs": n, "ty": "returns",
                            "f": {(names[i] if names else "ret%d" % (i + 1)): node_from_codes(r) for i, r in enumerate(rs)}}
                elif rs:
                    node = node_from_codes(rs[0], n)
                else:
                    node = {"s": {}, "obs": n}
                if isinstance(cell.get("f"), dict) and cell["f"]:
                    node["f"] = {k: node_from_codes(v) for k, v in cell["f"].items()}
                schema.setdefault(ctx, {}).setdefault(ucls, {})[item] = node
    for key, dc in (cp.get("durations") or {}).items():
        ctx, ucls, filt = (key.split("|", 2) + ["", ""])[:3]
        node = {"s": {"K" if dc.get("state") == "K" else str(dc.get("state")): 1}, "obs": 1, "ty": "duration object",
                "f": {k + "()": {"s": {str(v): 1}, "obs": 1} for k, v in dc.items() if k != "state"}}
        schema.setdefault(ctx, {}).setdefault(ucls, {})["aura:GetAuraDuration[%s]#object" % filt] = node
    for key, sc in (cp.get("slotCounts") or {}).items():
        ctx, ucls, filt = (key.split("|", 2) + ["", ""])[:3]
        r, s = int((sc or {}).get("readable") or 0), int((sc or {}).get("secret") or 0)
        schema.setdefault(ctx, {}).setdefault(ucls, {})["count:GetAuraSlots(%s)" % filt] = {"s": {"C": r, "S": s} if s else {"C": r}, "obs": r + s, "ty": "count"}
    for ctx, byU in (cp.get("events") or {}).items():
        for ucls, byE in (byU or {}).items():
            e = (byE or {}).get("UNIT_AURA")
            if not isinstance(e, dict):
                continue
            n = int(e.get("n") or 0)
            r2 = (e.get("r") or {})
            r2 = (r2.get("2") or r2.get(2)) if isinstance(r2, dict) else (r2[1] if isinstance(r2, list) and len(r2) > 1 else None)
            node = {"s": _cnt(r2) or {"K": n}, "obs": n, "f": {}}
            for fld, codes in (e.get("f") or {}).items():
                if fld.startswith("addedAuras[1]."):
                    aa = node["f"].setdefault("addedAuras", {"s": {}, "obs": 0})
                    arr = aa.setdefault("arr", {"s": {"K": 0}, "obs": 0, "f": {}})
                    arr["f"][fld.split(".", 1)[1]] = node_from_codes(codes)
                    arr["obs"] = max(arr["obs"], sum(_cnt(codes).values()))
                    arr["s"]["K"] = arr["obs"]
                else:
                    prev = node["f"].get(fld, {})
                    nn = node_from_codes(codes)
                    if "arr" in prev:
                        nn["arr"] = prev["arr"]
                    node["f"][fld] = nn
            schema.setdefault(ctx, {}).setdefault(ucls, {})["event:UNIT_AURA"] = node
    return {"source": "legacy:combatProbe cells + UNIT_AURA payload codes (addon <= 2.2.1, one level deep)",
            "build": None, "schema": schema, "errors": errors, "skipped": {}}


def extract(dump):
    log = dump.log if hasattr(dump, "log") else dump.get("ForeverDumpLogDB", {})
    res = from_addon(log) or from_legacy(log) or {"source": "none", "schema": {}}
    if not res.get("build") and hasattr(dump, "meta"):
        try:
            m = dump.meta() if callable(dump.meta) else dump.meta
            res["build"] = str(m.get("build")) if m.get("build") is not None else None
        except Exception:  # noqa: BLE001 - plain dict dumps in tests
            pass
    res["build"] = str(res["build"]) if res.get("build") is not None else None
    return res


# ---------------------------------------------------------------- analysis
def dominant(s):
    s = {k: v for k, v in (s or {}).items() if v}
    if not s:
        return "-"
    if len(s) == 1:
        return next(iter(s))
    return "/".join(k for k, _ in sorted(s.items(), key=lambda kv_: (-kv_[1], kv_[0])))


def fmt_codes(node, parent_obs=None):
    if node is None:
        return "unobserved"
    s = dict(node.get("s") or {})
    if parent_obs and node.get("obs", 0) < parent_obs:
        s["A"] = s.get("A", 0) + parent_obs - node.get("obs", 0)
    return " ".join("%s%d" % (k, v) for k, v in sorted(s.items(), key=lambda kv_: -kv_[1]) if v) or "-"


def walk_fields(node, prefix=""):
    """yield (path, node, parent_obs) for every field (dict fields, array elements as [])"""
    for k, ch in sorted((node.get("f") or {}).items(), key=lambda kv_: str(kv_[0])):
        if not isinstance(ch, dict):
            continue
        p = prefix + ("." if prefix else "") + str(k)
        yield p, ch, node.get("obs")
        yield from walk_fields(ch, p)
    if isinstance(node.get("arr"), dict):
        p = prefix + "[]"
        yield p, node["arr"], None
        yield from walk_fields(node["arr"], p)


def is_partial(node):
    """a container that is itself readable (K/T) but has at least one secret field somewhere = partial secret"""
    if not any(k in ("K", "T", "R") for k in (node.get("s") or {})):
        return False
    secret = clear = 0
    for _, ch, _ in walk_fields(node):
        s = ch.get("s") or {}
        secret += s.get("S", 0) + s.get("T", 0)
        clear += s.get("C", 0)
    return secret > 0 and clear > 0 or (node.get("s") or {}).get("T", 0) > 0


def aura_source(byP):
    """the best aura-table probe in one ctx/unit cell: by-index HELPFUL first, then HARMFUL, then the UNIT_AURA payload"""
    order = ["C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL)", "aura:GetAuraDataByIndex[HELPFUL]",
             "C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL)", "aura:GetAuraDataByIndex[HARMFUL]",
             "C_UnitAuras.GetAuraDataByIndex(u,1,HELPFUL|PLAYER)", "aura:GetAuraDataByIndex[HELPFUL|PLAYER]",
             "C_UnitAuras.GetAuraDataByIndex(u,1,HARMFUL|PLAYER)", "aura:GetAuraDataByIndex[HARMFUL|PLAYER]"]
    for k in order:
        n = byP.get(k)
        if n and n.get("f"):
            return k, n
    ev = byP.get("event:UNIT_AURA")
    if ev and ((ev.get("f") or {}).get("addedAuras") or {}).get("arr"):
        return "event:UNIT_AURA addedAuras[]", ev["f"]["addedAuras"]["arr"]
    for k in order:
        if byP.get(k):
            return k, byP[k]
    return None, None


def aura_matrix(schema):
    """{(baseCtx, group): {"source": probe, "table": codes, "fields": {field: codes}}} merged over unit classes"""
    out = {}
    for ctx, byU in schema.items():
        for ucls, byP in byU.items():
            key = (base_ctx(ctx), group_of(ucls))
            src, node = aura_source(byP)
            if not node and not byP.get("event:UNIT_AURA"):
                continue
            cell = out.setdefault(key, {"sources": set(), "table": {}, "fields": {}, "units": set(), "obs": 0, "event": {}})
            ev = byP.get("event:UNIT_AURA")
            if ev:
                for fld in ("(payload)", "addedAuras", "removedAuraInstanceIDs", "updatedAuraInstanceIDs", "isFullUpdate"):
                    ch = ev if fld == "(payload)" else (ev.get("f") or {}).get(fld)
                    if ch:
                        dd = cell["event"].setdefault(fld, {})
                        for k, v in (ch.get("s") or {}).items():
                            dd[k] = dd.get(k, 0) + v
            cell["units"].add(ucls)
            if not node:
                continue
            cell["sources"].add(src)
            cell["units"].add(ucls)
            for k, v in (node.get("s") or {}).items():
                cell["table"][k] = cell["table"].get(k, 0) + v
            cell["obs"] += node.get("obs", 0)
            for f in AURA_FIELDS:
                ch = (node.get("f") or {}).get(f)
                if ch:
                    d = cell["fields"].setdefault(f, {})
                    for k, v in (ch.get("s") or {}).items():
                        d[k] = d.get(k, 0) + v
    return out


def count_matrix(schema):
    """can a clear aura COUNT be had? per (baseCtx, group, method): codes"""
    out = {}
    for ctx, byU in schema.items():
        for ucls, byP in byU.items():
            key0 = (base_ctx(ctx), group_of(ucls))
            for probe, node in byP.items():
                m = None
                if probe.startswith("count:"):
                    m = probe[len("count:"):]
                elif "GetAuraSlots" in probe:
                    m = "GetAuraSlots returns " + probe.split("(")[-1].split("[")[-1].rstrip(")]")
                elif "GetUnitAuras" in probe:
                    m = "GetUnitAuras " + probe.split(",")[-1].split("[")[-1].rstrip(")]")
                elif probe == "event:UNIT_AURA":
                    for fld in ("addedAuras", "removedAuraInstanceIDs", "updatedAuraInstanceIDs", "isFullUpdate"):
                        ch = (node.get("f") or {}).get(fld)
                        if ch:
                            d = out.setdefault(key0 + ("UNIT_AURA payload ." + fld,), {})
                            for k, v in (ch.get("s") or {}).items():
                                d[k] = d.get(k, 0) + v
                    continue
                if m:
                    d = out.setdefault(key0 + (m,), {})
                    for k, v in (node.get("s") or {}).items():
                        d[k] = d.get(k, 0) + v
    return out


def flatten(schema):
    """{(ctx, ucls, probe, path): dominant} for diffing"""
    flat = {}
    for ctx, byU in schema.items():
        for ucls, byP in byU.items():
            for probe, node in byP.items():
                flat[(ctx, ucls, probe, "")] = dominant(node.get("s"))
                for path, ch, _ in walk_fields(node):
                    flat[(ctx, ucls, probe, path)] = dominant(ch.get("s"))
    return flat


def diff(base, cur):
    """state changes vs a stored baseline schema (only keys observed on both sides change state; others are new/gone)"""
    a, b = flatten(base.get("schema") or {}), flatten(cur.get("schema") or {})
    changed = [{"key": "|".join(k), "was": a[k], "now": b[k]} for k in sorted(set(a) & set(b)) if a[k] != b[k]]
    new = ["|".join(k) for k in sorted(set(b) - set(a))]
    gone = ["|".join(k) for k in sorted(set(a) - set(b))]
    # legacy vs addon schemas use different probe ids: compare like with like only
    return {"baseSource": base.get("source"), "curSource": cur.get("source"), "changed": changed,
            "new": len(new), "gone": len(gone), "newSample": new[:40], "goneSample": gone[:40],
            "comparable": base.get("source", "").split(":")[0] == cur.get("source", "").split(":")[0]}


def report(dump, baseline_path=None):
    res = extract(dump)
    schema = res["schema"]
    am = aura_matrix(schema)
    cm = count_matrix(schema)
    partial = []
    for ctx, byU in sorted(schema.items()):
        for ucls, byP in sorted(byU.items()):
            for probe, node in sorted(byP.items()):
                if is_partial(node):
                    sec = [p for p, ch, _ in walk_fields(node) if (ch.get("s") or {}).get("S")]
                    clr = [p for p, ch, _ in walk_fields(node) if (ch.get("s") or {}).get("C")]
                    partial.append({"ctx": ctx, "unit": ucls, "probe": probe, "container": dominant(node.get("s")),
                                    "secretFields": sec[:30], "clearFields": clr[:30]})
    out = {"schema": "foreverdump.containers/1", "source": res["source"], "build": res.get("build"),
           "contexts": sorted(schema), "unitClasses": sorted({u for byU in schema.values() for u in byU}),
           "skipped": res.get("skipped") or {}, "errors": res.get("errors") or {},
           "auraMatrix": [{"ctx": k[0], "group": k[1], "sources": sorted(v["sources"]), "units": sorted(v["units"]), "table": v["table"],
                           "fields": v["fields"], "event": v.get("event") or {}} for k, v in sorted(am.items())],
           "countMatrix": [{"ctx": k[0], "group": k[1], "method": k[2], "codes": v} for k, v in sorted(cm.items())],
           "partial": partial, "raw": res}
    if baseline_path and os.path.exists(baseline_path):
        with open(baseline_path, encoding="utf-8") as f:
            out["diff"] = diff(json.load(f), res)
        out["diff"]["baseline"] = baseline_path
    return out


def _cell(codes):
    if not codes:
        return "unobserved"
    return " ".join("%s%d" % (k, v) for k, v in sorted(codes.items(), key=lambda kv_: (-kv_[1], kv_[0])) if v)


def _md(s):
    return str(s).replace("|", "\\|")


def markdown(r):
    L = ["# Container state (partial secrets)", "",
         "Source: `%s`, build %s. Codes: %s. Counts are observations; a field missing in some observations of its container "
         "is absent (A) there. Only codes / flags / key names are stored, never values." % (
             r["source"], r.get("build"), ", ".join("%s %s" % kv_ for kv_ in CODES.items())), ""]
    ctxs = sorted({m["ctx"] for m in r["auraMatrix"]} | {"ooc", "combat"})
    L += ["## Aura table, field by field (per context x unit class)", "",
          "First aura of the unit (`GetAuraDataByIndex(u,1,filter)`; the UNIT_AURA `addedAuras[]` payload where the API "
          "errored or returned nothing). 'unobserved' = no aura table seen there (no aura present, API error, or no such unit).", ""]
    am = {(m["ctx"], m["group"]): m for m in r["auraMatrix"]}
    groups = [g for g, _ in GROUPS]
    hdr = ["field"] + ["%s / %s" % (c, g) for c in ctxs for g in groups]
    L += ["| " + " | ".join(hdr) + " |", "|" + "---|" * len(hdr)]
    L.append("| *(table itself)* | " + " | ".join(_cell(am.get((c, g), {}).get("table")) for c in ctxs for g in groups) + " |")
    for f in AURA_FIELDS:
        L.append("| `%s` | " % f + " | ".join(_cell((am.get((c, g)) or {}).get("fields", {}).get(f)) for c in ctxs for g in groups) + " |")
    for fld in ("(payload)", "addedAuras", "removedAuraInstanceIDs", "updatedAuraInstanceIDs", "isFullUpdate"):
        L.append("| UNIT_AURA `%s` | " % fld + " | ".join(_cell((am.get((c, g)) or {}).get("event", {}).get(fld)) for c in ctxs for g in groups) + " |")
    L += ["", "Sources per cell: " + "; ".join("%s/%s: %s (%s)" % (m["ctx"], m["group"], ", ".join(m["sources"]), ", ".join(m["units"]))
                                               for m in r["auraMatrix"]), ""]
    L += ["## Can a clear aura COUNT be had?", "",
          "`C` = the count / slot list came back clear, `S` = secret, `E` = the call errored, `N` = nil (none / nothing added). "
          "For the UNIT_AURA payload a field that is nil vs secret is itself a clear yes/no signal.", "",
          "| context | unit class | method | codes |", "|---|---|---|---|"]
    for m in r["countMatrix"]:
        L.append("| %s | %s | %s | %s |" % (m["ctx"], m["group"], _md(m["method"]), _cell(m["codes"])))
    L += ["", "## Partial-secret containers (readable container, some secret fields)", ""]
    if r["partial"]:
        L += ["| context | unit | probe | container | secret fields | clear fields |", "|---|---|---|---|---|---|"]
        for p in r["partial"][:200]:
            L.append("| %s | %s | `%s` | %s | %s | %s |" % (_md(p["ctx"]), p["unit"], _md(p["probe"]), p["container"],
                                                         ", ".join(p["secretFields"][:12]) or "-", ", ".join(p["clearFields"][:12]) or "-"))
    else:
        L.append("none observed")
    if r.get("errors"):
        L += ["", "## Errors (text only)", ""] + ["- `%s`: %s" % (k, str(v).replace("\n", " ")) for k, v in sorted(r["errors"].items())]
    if r.get("skipped"):
        L += ["", "## Skipped in combat (protected / blocked)", ""] + ["- `%s`: %s" % kv_ for kv_ in sorted(r["skipped"].items())]
    if r.get("diff"):
        d = r["diff"]
        L += ["", "## Change detection vs baseline", "",
              "Baseline `%s` (%s) vs this capture (%s)%s: %d state change(s), %d new key(s), %d gone." % (
                  d.get("baseline"), d["baseSource"], d["curSource"], "" if d["comparable"] else " (different schema sources: new/gone expected)",
                  len(d["changed"]), d["new"], d["gone"])]
        for c in d["changed"][:80]:
            L.append("- `%s`: %s -> %s" % (c["key"], c["was"], c["now"]))
    L += ["", "## Per probe (every field)", ""]
    sch = r["raw"]["schema"]
    for ctx in sorted(sch):
        for ucls in sorted(sch[ctx]):
            L.append("<details><summary>%s / %s (%d probes)</summary>" % (ctx, ucls, len(sch[ctx][ucls])))
            L.append("")
            for probe, node in sorted(sch[ctx][ucls].items()):
                fl = node.get("fl") or {}
                extra = []
                if node.get("lenMax") is not None:
                    extra.append("len<=%s" % node["lenMax"])
                if node.get("ncMax") is not None:
                    extra.append("clear fields<=%s" % node["ncMax"])
                for k, v in fl.items():
                    extra.append("%s=%s" % (k, _cell(v)))
                L.append("- `%s`: **%s** %s" % (probe, fmt_codes(node), ("(" + ", ".join(extra) + ")") if extra else ""))
                for path, ch, pobs in walk_fields(node):
                    L.append("  - `%s`: %s" % (path, fmt_codes(ch, pobs)))
            L += ["", "</details>", ""]
    return "\n".join(L) + "\n"


def guide_json(r):
    """compact JSON for the guide (--containers)"""
    return {"schema": "foreverdump.containers/1", "source": r["source"], "build": r.get("build"),
            "auraMatrix": r["auraMatrix"], "countMatrix": r["countMatrix"], "partial": r["partial"][:60],
            "errors": r.get("errors"), "diff": {k: v for k, v in (r.get("diff") or {}).items() if k != "newSample" and k != "goneSample"}}
