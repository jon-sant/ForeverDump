"""v2.2.10 master guide: per-run secret-state inspection of a ForeverDump SavedVariables capture.

Reads the combat recorder ring (ForeverDumpCombatLogDB.sessions[].events), the token scanner matrix (tokenscan), the
combat probe cells (combatProbe) and the containers/aura schema, and reduces them to COUNTS AND CODES ONLY:
  ring.sessions[] = {epoch, events[event][family][ctx] = {n, secretAny, args: {argIndex: nSecret}, present: {argIndex: nNonNil}, fields: {field: nSecret}},
                     deaths[ctx][guidKind] = n (guidKind = Creature/Player/Pet/Vehicle/secret/other; never the GUID)}
Nothing in the result carries a name, GUID, castGUID or free-text argument, so it is safe to cache next to the run and
to feed the master guide. Parsing a 35 MB SV takes ~8 s, so `inspect_cached` keys a JSON cache by SV size + mtime."""
import collections
import json
import os
import re

SCHEMA = "foreverdump.svinspect/5"   # /5 (run 20): + auraPresence codes per env tag
SECRET_MARKS = ("<secret>", "<secrettable>")
PVP_INSTANCES = ("pvp", "arena")


def family(tok):
    """unit token -> guide family (player, target, focus, friendly, enemy-player, npc, pet, nameplate, chain, soft, other)"""
    if not isinstance(tok, str):
        return None
    t = tok.lower()
    if t == "player":
        return "player"
    if t in ("target", "playertarget"):
        return "target"
    if t == "focus":
        return "focus"
    if re.match(r"^(party|raid)pet\d+$", t) or t == "pet" or re.match(r"^arenapet\d+$", t):
        return "pet"
    if re.match(r"^(party|raid)\d+$", t):
        return "friendly"
    if re.match(r"^arena\d+$", t):
        return "enemy-player"
    if re.match(r"^boss\d+$", t) or t == "npc":
        return "npc"
    if re.match(r"^nameplate\d+$", t):
        return "nameplate"
    if t.startswith("soft"):
        return "soft" if not t.endswith("target") else "chain"
    if t.endswith("target") or t == "mouseover":
        return "chain"
    if t == "vehicle":
        return "pet"
    return "other"


def scan_family(fam):
    """tokenscan family (digits -> N) -> guide family"""
    return family(re.sub("N", "1", fam))


def guid_kind(v):
    if v in SECRET_MARKS:
        return "secret"
    if not isinstance(v, str):
        return "other"
    k = v.split("-", 1)[0]
    return k if k in ("Creature", "Player", "Pet", "Vehicle", "GameObject") else "other"


def _ctx(in_combat, instance):
    if instance in PVP_INSTANCES:
        return "pvp"
    return "combat" if in_combat else "ooc"


def _is_secret(v):
    return isinstance(v, str) and v in SECRET_MARKS


def _new_cell():
    return {"n": 0, "secretAny": 0, "args": collections.Counter(), "present": collections.Counter(), "fields": collections.Counter()}


def combat_ring(raw):
    """per recorder session (keyed by its start epoch, so a session kept in several runs' SVs counts once)"""
    sessions = []
    for ss in ((raw.get("ForeverDumpCombatLogDB") or {}).get("sessions") or []):
        if not isinstance(ss, dict):
            continue
        out = collections.defaultdict(lambda: collections.defaultdict(lambda: collections.defaultdict(_new_cell)))
        deaths = collections.defaultdict(collections.Counter)
        inst = ((ss.get("instanceAtStart") or {}).get("instanceType")) if isinstance(ss.get("instanceAtStart"), dict) else None
        for e in ss.get("events") or []:
            if not isinstance(e, dict):
                continue
            ev = e.get("e")
            if isinstance(e.get("instance"), dict):
                inst = e["instance"].get("instanceType")
            if not isinstance(ev, str):
                continue
            args = e.get("a") if isinstance(e.get("a"), list) else []
            ctx = _ctx(bool(e.get("c")), inst)
            if ev == "UNIT_DIED":
                deaths[ctx][guid_kind(args[0] if args else None)] += 1
                fam = "guid"
            else:
                fam = family(args[0]) if args and isinstance(args[0], str) and ev.startswith("UNIT_") else "-"
                fam = fam or "-"
            cell = out[ev][fam][ctx]
            cell["n"] += 1
            sec = False
            for i, v in enumerate(args):
                if v is not None and v != "<nil>":
                    cell["present"][str(i + 1)] += 1
                if _is_secret(v):
                    cell["args"][str(i + 1)] += 1
                    sec = True
                elif isinstance(v, dict):
                    for k, fv in v.items():
                        if _is_secret(fv):
                            cell["fields"][str(k)] += 1
                            sec = True
            if sec:
                cell["secretAny"] += 1
        ev_out = {ev: {f: {c: {"n": x["n"], "secretAny": x["secretAny"], "args": dict(x["args"]), "present": dict(x["present"]),
                               "fields": dict(x["fields"])}
                           for c, x in sorted(byc.items())} for f, byc in sorted(byf.items())} for ev, byf in sorted(out.items())}
        sessions.append({"epoch": ss.get("startEpoch") or ss.get("startTime"), "kind": ss.get("kind"),
                         "events": ev_out, "deaths": {c: dict(v) for c, v in sorted(deaths.items())}})
    return {"sessions": sessions}


def token_matrix(dump):
    from . import tokenscan
    res = tokenscan.analyze(dump)
    rows = []
    for build, b in sorted(res.get("builds", {}).items()):
        for r in b["rows"]:
            st = r["state"]
            ctx = "pvp" if r["instance"] in PVP_INSTANCES else ("ooc" if st == "ooc" else "combat")
            rows.append({"build": build, "ctx": ctx, "state": st, "family": r["family"], "gfamily": scan_family(r["family"]),
                         "cells": {f: {"code": c["code"], "n": c["n"], "share": c["share"]} for f, c in r["cells"].items()}})
    return rows


def probe_matrix(dump):
    from . import probes
    try:
        res = probes.combat(dump)
    except Exception as e:  # noqa: BLE001 - legacy SVs; record and continue
        return {"error": str(e)[:200]}
    out = {}
    for item, byret in res["matrix"].items():
        for ret, byu in byret.items():
            for ucls, byc in byu.items():
                for ctx, c in byc.items():
                    out.setdefault(item, {}).setdefault(ret, {}).setdefault(ucls, {})[ctx] = {
                        "code": c.get("obs"), "counts": {str(k): v for k, v in (c.get("counts") or {}).items()
                                                         if isinstance(v, (int, float))}}
    # v2.2.25: ctx@env counters (world-solo/party/dungeon/raid/arena/bg) - lets the guide map a probe ctx to an
    # environment instead of assuming "restricted / combat with players" == battleground
    env = {}
    try:
        for k, n in ((dump.log.get("combatProbe") or {}).get("envCtx") or {}).items():
            ctx, _, tag = str(k).partition("@")
            env.setdefault(ctx, {})[tag.split("/")[0]] = env.get(ctx, {}).get(tag.split("/")[0], 0) + (n if isinstance(n, (int, float)) else 0)
    except Exception:  # noqa: BLE001
        env = {}
    return {"matrix": out, "detectability": res.get("detectability") or {}, "runCount": res.get("runCount") or {},
            "envCtx": env}


def aura_matrix(dump):
    from . import containers
    try:
        r = containers.report(dump)
    except Exception as e:  # noqa: BLE001
        return {"error": str(e)[:200]}
    return {"auraMatrix": r.get("auraMatrix") or [], "countMatrix": r.get("countMatrix") or [],
            "errors": sorted((r.get("errors") or {}).keys()),
            "partial": [{k: x.get(k) for k in ("ctx", "unit", "probe", "container", "secretFields", "clearFields")}
                        for x in (r.get("partial") or [])]}


def inspect(sv_path):
    from .dump import Dump, load_raw
    raw = load_raw(sv_path)
    dump = Dump(raw, source=sv_path)
    out = {"schema": SCHEMA, "build": str((dump.meta() or {}).get("build") or "?"),
           "addonVersion": str((dump.db.get("meta") or {}).get("addonVersion") or dump.db.get("addonVersion") or "?")}
    out["ring"] = combat_ring(raw)
    try:
        out["tokens"] = token_matrix(dump)
    except Exception as e:  # noqa: BLE001
        out["tokens"] = []
        out["tokensError"] = str(e)[:200]
    out["probes"] = probe_matrix(dump)
    out["containers"] = aura_matrix(dump)
    out["auraPresence"] = presence_codes(raw)
    return out


def presence_codes(raw):
    """v2.2.25 AuraPresence (C_UnitAuras.GetUnitAuraBySpellID on curated IDs): envTag -> unit family -> {code: n},
    summed over spell IDs (codes and counts only)"""
    ap = ((raw or {}).get("ForeverDumpLogDB") or {}).get("auraPresence") or {}
    out = {}
    for tag, byF in (ap.get("codes") or {}).items():
        for fam, byS in (byF or {}).items():
            c = out.setdefault(str(tag), {}).setdefault(str(fam), {})
            for _sid, cc in (byS or {}).items():
                for k, n in (cc or {}).items():
                    if isinstance(n, (int, float)):
                        c[str(k)] = c.get(str(k), 0) + int(n)
    return out


def _key(sv_path):
    st = os.stat(sv_path)
    return "%d:%d" % (st.st_size, int(st.st_mtime))


def inspect_cached(sv_path, cache_path):
    """cache keyed by SV size+mtime; the cache holds codes and counts only (no names / GUIDs)"""
    key = _key(sv_path)
    if os.path.exists(cache_path):
        try:
            with open(cache_path, encoding="utf-8") as f:
                c = json.load(f)
            if c.get("svKey") == key and c.get("schema") == SCHEMA:
                return c
        except (OSError, ValueError):
            pass
    out = inspect(sv_path)
    out["svKey"] = key
    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(out, f, sort_keys=True, indent=0)
    return out
