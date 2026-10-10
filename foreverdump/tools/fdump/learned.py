"""Learned spell / NPC / class DB: offline seed (ForeverDump/Data/learned-seed.lua + tools/fdump/data/learned-seed.json).

Evidence: (1) the combat logs of earlier captures (spell names / schools, cast START->SUCCESS times per caster type,
cast -> aura map with BUFF/DEBUFF and applied->removed durations, damage / heal ranges, target types, NPC casts / cast
models / interrupted spells / typical targets); (2) the addon's live ForeverDumpDB.learned[build] tables (every clear
spellID from any unit, NPC DB, per-class catalog for other players); (3) ForeverDumpDB.drift[build] changelogs.

Rules: v2.2.21 (user decision 2026-10-09) - nothing is stripped or anonymized; the seed keeps what the evidence holds
(raw). Merge is idempotent per capture id, values are promoted only with >= THRESHOLD samples, and a
value that disagrees with the seed is FLAGGED as a drift proposal (old -> new, build, date), never silently overwritten.
"""
import collections
import json
import os
import re
import statistics

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SEED_JSON = os.path.join(ROOT, "tools", "fdump", "data", "learned-seed.json")
SEED_LUA = os.path.join(ROOT, "ForeverDump", "Data", "learned-seed.lua")
SCHEMA = "foreverdump.learned/1"
THRESHOLD = 3
GUID_RE = re.compile(r"(Player|Creature|Pet|Vehicle|GameObject|Item)-[0-9A-Fa-f-]+")


def _ctype(guid, me):
    if not isinstance(guid, str) or guid.startswith("0000"):
        return None
    if guid == me:
        return "player"
    k = guid.split("-", 1)[0]
    return {"Player": "pc", "Creature": "npc", "Vehicle": "npc", "Pet": "pet"}.get(k, k.lower())


def npc_id(guid):
    if not isinstance(guid, str):
        return None
    p = guid.split("-")
    if p[0] in ("Creature", "Vehicle") and len(p) >= 6 and p[5].isdigit():
        return int(p[5])
    return None


def _stat(vals):
    vals = [v for v in vals if isinstance(v, (int, float))]
    if not vals:
        return None
    return {"n": len(vals), "min": round(min(vals), 3), "med": round(statistics.median(vals), 3), "max": round(max(vals), 3)}


HOSTILE, FRIENDLY = 0x40, 0x10


def from_log(fx, me, label="log", seen=None, build=None, date=None):
    """combat log -> evidence dict. `seen` dedupes events shared by appended logs across captures."""
    seen = seen if seen is not None else set()
    sp = collections.defaultdict(lambda: {"names": set(), "school": None, "casts": collections.Counter(), "castT": collections.defaultdict(list),
                                          "aura": collections.defaultdict(lambda: {"n": 0, "kind": None, "dur": []}), "dmg": [], "heal": [],
                                          "tgt": collections.Counter(), "auraKind": None})
    npcs = collections.defaultdict(lambda: {"name": None, "spells": collections.Counter(), "castT": collections.defaultdict(list),
                                            "interrupted": collections.Counter(), "tgt": collections.Counter()})
    starts = {}
    lastcast = {}
    applied = {}
    recent_aura = {}
    n = 0
    for e in fx.get("events", []):
        if not e.get("cleu"):
            continue
        a = e["a"]
        if len(a) < 14:
            continue
        sub = e.get("sub")
        key = (e["t"], sub, a[3], a[7], a[11] if len(a) > 11 else None, e.get("rawAmount"))
        if key in seen:
            continue
        seen.add(key)
        n += 1
        src, dst = a[3], a[7]
        sid = a[11] if isinstance(a[11], int) else None
        if sid is None:
            continue
        s = sp[sid]
        if isinstance(a[12], str) and a[12] not in ("<nil>",):
            s["names"].add(a[12])
        if isinstance(a[13], int) and a[13] > 0:
            s["school"] = a[13]
        ct = _ctype(src, me)
        nid = npc_id(src)
        if nid and isinstance(a[4], str) and a[4] != "<nil>":
            npcs[nid]["name"] = a[4]
        dn = npc_id(dst)
        if dn and isinstance(a[8], str) and a[8] != "<nil>":
            npcs[dn]["name"] = a[8]
        t = e["t"]
        if sub == "SPELL_CAST_START":
            starts[(src, sid)] = t
            if nid:
                npcs[nid]["spells"][sid] += 1
        elif sub == "SPELL_CAST_SUCCESS":
            s["casts"][ct or "?"] += 1
            st = starts.pop((src, sid), None)
            if st is not None and 0 < t - st < 30:
                s["castT"][ct or "?"].append(round(t - st, 3))
                if nid:
                    npcs[nid]["castT"][sid].append(round(t - st, 3))
            lastcast[src] = (t, sid, dst)
            # the log may write the aura before the cast (same timestamp): look back 0.2 s
            selfc = dst == src or (isinstance(dst, str) and dst.startswith("0000"))
            for (at, aid, adst, akind) in recent_aura.get(src, ()):
                if 0 <= t - at <= 0.2 and (aid == sid or (adst == dst and adst != src) or (adst == src and selfc)):
                    m = s["aura"][aid]
                    m["n"] += 1
                    m["kind"] = akind
            if nid and st is None:
                npcs[nid]["spells"][sid] += 1
            # target type relative to the caster (flags are relative to the logger: only meaningful for me)
            if dst == src or (isinstance(dst, str) and dst.startswith("0000")):
                tt = "self"
            elif ct == "player" and isinstance(a[9], int):
                tt = "enemy" if a[9] & HOSTILE else ("friendly" if a[9] & FRIENDLY else "neutral")
            else:
                tt = "unit"
            s["tgt"][tt] += 1
            if nid:
                tk = _ctype(dst, me)
                npcs[nid]["tgt"]["me" if dst == me else (tk or "none")] += 1
        elif sub in ("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH"):
            kind = e["raw"][3] if len(e.get("raw") or []) > 3 else None
            s["auraKind"] = kind
            if sub == "SPELL_AURA_APPLIED":
                applied[(src, dst, sid)] = t
            ra = recent_aura.setdefault(src, collections.deque(maxlen=6))
            ra.append((t, sid, dst, kind))
            lc = lastcast.get(src)
            # a self-buff right after an offensive cast is usually a proc (Flurry after a Stormstrike crit): not a mapping
            selfcast = isinstance(lc[2], str) and (lc[2] == src or lc[2].startswith("0000")) if lc else False
            if lc and 0 <= t - lc[0] <= 1.0 and (lc[1] == sid or (lc[2] == dst and dst != src) or (dst == src and selfcast)):
                m = sp[lc[1]]["aura"][sid]
                m["n"] += 1
                m["kind"] = kind
        elif sub == "SPELL_AURA_REMOVED":
            t0 = applied.pop((src, dst, sid), None)
            if t0 is not None and 0 < t - t0 < 3600:
                s.setdefault("auraDur", []).append(round(t - t0, 3))
        elif sub in ("SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE"):
            amt = e.get("rawAmount")
            if isinstance(amt, (int, float)) and amt > 0:
                s["dmg"].append(amt)
        elif sub in ("SPELL_HEAL", "SPELL_PERIODIC_HEAL"):
            amt = e.get("rawAmount")
            if isinstance(amt, (int, float)) and amt > 0:
                s["heal"].append(amt)
        elif sub == "SPELL_INTERRUPT":
            extra = a[14] if len(a) > 14 and isinstance(a[14], int) else None
            if dn and extra:
                npcs[dn]["interrupted"][extra] += 1
    # durations of auras onto the cast map
    spells = {}
    for sid, s in sp.items():
        out = {"name": sorted(s["names"])[0] if s["names"] else None, "school": s["school"],
               "casts": dict(s["casts"]), "castT": {k: _stat(v) for k, v in s["castT"].items()},
               "tgt": dict(s["tgt"]), "auraKind": s["auraKind"], "auraDur": _stat(s.get("auraDur") or []),
               "dmg": _stat(s["dmg"]), "heal": _stat(s["heal"]), "aura": {}}
        for aid, m in s["aura"].items():
            out["aura"][aid] = {"n": m["n"], "kind": m["kind"]}
        spells[sid] = out
    for sid, out in spells.items():
        for aid, m in out["aura"].items():
            ad = spells.get(aid, {}).get("auraDur")
            if ad:
                m["dur"] = ad
    np = {nid: {"name": v["name"], "spells": dict(v["spells"]), "castT": {k: _stat(x) for k, x in v["castT"].items()},
                "interrupted": dict(v["interrupted"]), "tgt": dict(v["tgt"])} for nid, v in npcs.items()}
    return {"label": label, "id": "log:%s" % label, "build": build, "date": date, "events": n, "spells": spells, "npcs": np, "classes": {}}


def from_sv(dump, label="sv"):
    """ForeverDumpDB.learned[build] (+ drift changelog) -> evidence"""
    db = dump.db if hasattr(dump, "db") else dump
    out = {"label": label, "id": "sv:%s" % label, "spells": {}, "npcs": {}, "classes": {}, "drift": []}
    for build, d in ((db or {}).get("learned") or {}).items():
        if not isinstance(d, dict):
            continue
        out["build"] = build
        out["id"] = "sv:%s:%s:%s" % (label, build, d.get("first"))
        for sid, e in (d.get("spells") or {}).items():
            try:
                sid = int(sid)
            except (TypeError, ValueError):
                continue
            x = {"name": e.get("name"), "school": e.get("school"), "rank": e.get("rank"), "apiCast": e.get("ct"),
                 "helpful": e.get("helpful"), "harmful": e.get("harmful"), "baseCooldown": e.get("bcd"), "baseGCD": e.get("bgcd"),
                 "casts": dict(e.get("by") or {}), "tgt": dict(e.get("tgt") or {}), "castT": {}, "chanT": {}, "aura": {}}
            for bucket, k in (("cast", "castT"), ("chan", "chanT")):
                for ct, s in (e.get(bucket) or {}).items():
                    if isinstance(s, (list, tuple)) and len(s) >= 4 and s[0]:
                        x[k][ct] = {"n": s[0], "min": s[1], "max": s[2], "med": round(s[3] / s[0], 3)}
            for aid, a in (e.get("aura") or {}).items():
                ds = a.get("dur")
                x["aura"][int(aid)] = {"n": a.get("n", 0), "kind": "BUFF" if a.get("helpful") else ("DEBUFF" if a.get("helpful") is False else None),
                                       "dispel": a.get("dispel"), "dur": {"n": ds[0], "min": ds[1], "max": ds[2], "med": round(ds[3] / ds[0], 3)} if ds else None}
            amt = e.get("amt") or {}
            for k, dst in (("damage", "dmg"), ("heal", "heal")):
                vals = [amt[j] for j in (k, k + "Crit") if amt.get(j)]
                if vals:
                    x[dst] = {"n": sum(v[0] for v in vals), "min": min(v[1] for v in vals), "max": max(v[2] for v in vals)}
            out["spells"][sid] = x
        for nid, e in (d.get("npcs") or {}).items():
            try:
                nid = int(nid)
            except (TypeError, ValueError):
                continue
            ct = {}
            for k, s in (e.get("cast") or {}).items():
                if isinstance(s, (list, tuple)) and len(s) >= 4 and s[0]:
                    ct[k] = {"n": s[0], "min": s[1], "max": s[2], "med": round(s[3] / s[0], 3)}
            intr = e.get("intr") or {}
            out["npcs"][nid] = {"name": e.get("name"), "spells": {k: v for k, v in (e.get("spells") or {}).items()}, "castT": ct,
                                "interruptible": (intr.get("yes", 0) > intr.get("no", 0)) if intr else None,
                                "interrupted": e.get("interrupted"), "tgt": dict(e.get("tgt") or {})}
        for cls, e in (d.get("classes") or {}).items():
            out["classes"][str(cls)] = {"n": e.get("n", 0), "spells": {int(k): v for k, v in (e.get("spells") or {}).items() if str(k).isdigit()}}
    for build, d in ((db or {}).get("drift") or {}).items():
        for c in (d or {}).get("changelog") or []:
            out["drift"].append(dict(c, build=c.get("build", build)))
    return out


def load_seed(path=SEED_JSON):
    if path and os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return {"schema": SCHEMA, "spells": {}, "npcs": {}, "classes": {}, "merged": [], "conflicts": [], "proposals": []}


def _conf(n):
    return "high" if n >= 10 else ("medium" if n >= THRESHOLD else "low")


def _mergestat(old, new):
    if not new:
        return old
    if not old:
        return dict(new)
    n = (old.get("n") or 0) + (new.get("n") or 0)
    med = round(((old.get("med") or 0) * (old.get("n") or 0) + (new.get("med") or 0) * (new.get("n") or 0)) / max(n, 1), 3)
    return {"n": n, "min": min(old["min"], new["min"]), "max": max(old["max"], new["max"]), "med": med}


def merge(seed, evidences, threshold=THRESHOLD, tol=0.25):
    """seed + evidence -> (seed', report). Idempotent per evidence id; conflicts flagged (drift proposals), never overwritten."""
    out = json.loads(json.dumps(seed or load_seed(None)))
    out["schema"] = SCHEMA
    S, N, C = out.setdefault("spells", {}), out.setdefault("npcs", {}), out.setdefault("classes", {})
    merged = out.setdefault("merged", [])
    conflicts, proposals = out.setdefault("conflicts", []), out.setdefault("proposals", [])
    rep = {"skipped": [], "promoted": [], "conflicts": [], "proposals": [], "spells": 0, "npcs": 0}
    for ev in evidences:
        if ev.get("id") in merged:
            rep["skipped"].append(ev.get("label"))
            continue
        merged.append(ev.get("id"))
        b, dt = ev.get("build"), ev.get("date")
        for sid, x in ev.get("spells", {}).items():
            k = str(sid)
            e = S.setdefault(k, {"casts": {}, "castT": {}, "aura": {}, "tgt": {}, "firstBuild": b, "firstSeen": dt})
            e["lastBuild"], e["lastSeen"] = b or e.get("lastBuild"), dt or e.get("lastSeen")
            for f in ("name", "school", "rank", "apiCast", "helpful", "harmful", "baseCooldown", "baseGCD", "auraKind"):
                if x.get(f) is not None:
                    e[f] = x[f]
            for ct, c in (x.get("casts") or {}).items():
                e["casts"][ct] = e["casts"].get(ct, 0) + c
            for tt, c in (x.get("tgt") or {}).items():
                e["tgt"][tt] = e["tgt"].get(tt, 0) + c
            for ct, st in (x.get("castT") or {}).items():
                if not st:
                    continue
                old = e["castT"].get(ct)
                # drift: the promoted cast time disagrees with consistent new evidence -> proposal, value kept
                if old and old.get("promoted") is not None and st["n"] >= threshold and abs(st["med"] - old["promoted"]) > tol:
                    p = {"kind": "castTime", "spell": int(sid), "caster": ct, "old": old["promoted"], "new": st["med"], "n": st["n"],
                         "build": b, "date": dt, "capture": ev.get("label")}
                    if p not in proposals:
                        proposals.append(p)
                        rep["proposals"].append(p)
                    e["castT"][ct] = dict(_mergestat({k2: v for k2, v in old.items() if k2 != "promoted"}, st), promoted=old["promoted"])
                    continue
                m = _mergestat({k2: v for k2, v in (old or {}).items() if k2 != "promoted"}, st)
                if old and old.get("promoted") is not None:
                    m["promoted"] = old["promoted"]
                elif m["n"] >= threshold and (m["max"] - m["min"]) <= max(0.3, 0.2 * m["med"]):
                    m["promoted"] = m["med"]
                    rep["promoted"].append({"spell": int(sid), "field": "castTime:" + ct, "value": m["med"], "n": m["n"]})
                e["castT"][ct] = m
            for aid, a in (x.get("aura") or {}).items():
                ak = str(aid)
                o = e["aura"].setdefault(ak, {"n": 0})
                o["n"] += a.get("n", 0)
                for f in ("kind", "dispel"):
                    if a.get(f):
                        o[f] = a[f]
                if a.get("dur"):
                    o["dur"] = _mergestat(o.get("dur"), a["dur"])
            for f in ("dmg", "heal", "auraDur"):
                if x.get(f):
                    e[f] = _mergestat(e.get(f), x[f])
            n = sum(e["casts"].values())
            e["samples"] = n
            e["confidence"] = _conf(n)
            rep["spells"] += 1
        for nid, x in ev.get("npcs", {}).items():
            k = str(nid)
            e = N.setdefault(k, {"spells": {}, "castT": {}, "interrupted": {}, "tgt": {}, "firstBuild": b, "firstSeen": dt})
            e["lastBuild"], e["lastSeen"] = b or e.get("lastBuild"), dt or e.get("lastSeen")
            if x.get("name"):
                e["name"] = x["name"]
            for f in ("spells", "interrupted", "tgt"):
                v = x.get(f) or {}
                if isinstance(v, (int, float)) and not isinstance(v, bool):
                    # run 6: v2.2.6 recorders store a plain count here (no per-spell split) -> "?" bucket
                    e[f]["?"] = e[f].get("?", 0) + v
                    continue
                if not isinstance(v, dict):
                    continue
                for kk, c in v.items():
                    if isinstance(c, (int, float)):
                        e[f][str(kk)] = e[f].get(str(kk), 0) + c
            for kk, st in (x.get("castT") or {}).items():
                if st:
                    e["castT"][str(kk)] = _mergestat(e["castT"].get(str(kk)), st)
            if x.get("interruptible") is not None:
                e["interruptible"] = x["interruptible"]
            if e["interrupted"]:
                e["interruptible"] = True
            rep["npcs"] += 1
        for cls, x in ev.get("classes", {}).items():
            e = C.setdefault(cls, {"n": 0, "spells": {}})
            e["n"] += x.get("n", 0)
            for kk, c in (x.get("spells") or {}).items():
                e["spells"][str(kk)] = e["spells"].get(str(kk), 0) + c
        for d in ev.get("drift") or []:
            p = {"kind": d.get("kind"), "key": d.get("key"), "old": d.get("old"), "new": d.get("new"), "n": d.get("n"),
                 "build": d.get("build"), "date": d.get("date"), "what": d.get("what"), "capture": ev.get("label")}
            if p not in proposals:
                proposals.append(p)
                rep["proposals"].append(p)
    return anonymize(out), rep


def anonymize(seed):
    """v2.2.21: identity - the seed is stored raw (kept as a function for callers)."""
    return seed


def _lua(v, ind=""):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, dict):
        parts = []
        for k in sorted(v, key=lambda x: (not str(x).lstrip("-").isdigit(), int(x) if str(x).lstrip("-").isdigit() else 0, str(x))):
            x = v[k]
            if x is None:
                continue
            ks = "[%s]" % k if str(k).lstrip("-").isdigit() else (k if re.match(r"^[A-Za-z_]\w*$", str(k)) else "[%s]" % json.dumps(k))
            parts.append("%s = %s" % (ks, _lua(x)))
        return "{ " + ", ".join(parts) + " }"
    if isinstance(v, list):
        return "{ " + ", ".join(_lua(x) for x in v) + " }"
    return "nil"


def runtime_view(seed):
    """compact runtime table: promoted cast times, aura map + durations, NPC cast models (starting points only)"""
    sp, np = {}, {}
    for k, e in seed.get("spells", {}).items():
        x = {}
        if e.get("name"):
            x["name"] = e["name"]
        if e.get("school"):
            x["school"] = e["school"]
        ct = [st.get("promoted") for st in (e.get("castT") or {}).values() if st.get("promoted") is not None]
        if ct:
            x["castTime"] = sorted(ct)[len(ct) // 2]
        au = {}
        for aid, a in (e.get("aura") or {}).items():
            dd = a.get("dur") or {}
            d = dd.get("max")
            if a.get("n", 0) >= 2:   # a single co-occurrence (a proc) is not a mapping
                # a duration only when consistent (charges consumed / cancelled / target died give short random values)
                tight = d and dd.get("n", 0) >= 2 and (d - dd.get("min", 0)) <= 0.1 * d
                au[int(aid)] = round(d, 1) if tight else 0
        if au:
            x["auras"] = au
        if e.get("helpful") is not None:
            x["helpful"] = e["helpful"]
        x["conf"] = e.get("confidence")
        x["lastBuild"] = e.get("lastBuild")
        sp[int(k)] = x
    for k, e in seed.get("npcs", {}).items():
        x = {"name": e.get("name")}
        cts = [st for st in (e.get("castT") or {}).values() if st and st.get("n", 0) >= 2]
        if cts:
            best = max(cts, key=lambda s: s["n"])
            x["castMedian"], x["n"] = best["med"], best["n"]
        if e.get("interruptible") is not None:
            x["interruptible"] = e["interruptible"]
        np[int(k)] = x
    return {"spells": sp, "npcs": np}


def to_lua(seed):
    rv = runtime_view(seed)
    L = ["-- ForeverDump learned seed (generated by `fdump.py analyze --write-seed` / tools/fdump/learned.py; full JSON mirror",
         "-- tools/fdump/data/learned-seed.json). STARTING POINTS ONLY: live observations re-verify every value (Drift.lua) and",
         "-- override it at runtime when they consistently disagree. Spell / NPC IDs, spell / NPC names, numbers. No players.",
         "local _, ns = ...", "ns.LearnedSeed = {", '    schema = "%s",' % SCHEMA, '    generated = "%s",' % seed.get("generated", ""),
         "    spells = {"]
    for sid in sorted(rv["spells"]):
        L.append("        [%d] = %s," % (sid, _lua(rv["spells"][sid])))
    L += ["    },", "    npcs = {"]
    for nid in sorted(rv["npcs"]):
        L.append("        [%d] = %s," % (nid, _lua(rv["npcs"][nid])))
    L += ["    },", "}", ""]
    return "\n".join(L)


def write_seed(seed, json_path=SEED_JSON, lua_path=SEED_LUA):
    os.makedirs(os.path.dirname(json_path), exist_ok=True)
    with open(json_path, "w") as f:
        json.dump(seed, f, indent=1, sort_keys=True)
    os.makedirs(os.path.dirname(lua_path), exist_ok=True)
    with open(lua_path, "w") as f:
        f.write(to_lua(seed))


def markdown(seed, rep, top=25):
    sp, np = seed.get("spells", {}), seed.get("npcs", {})
    L = ["## Learned spell / NPC / class DB", "",
         "Seed: ForeverDump/Data/learned-seed.lua (+ tools/fdump/data/learned-seed.json). %d spells, %d NPCs, %d classes; "
         "promotion threshold %d samples; drift proposals are flagged, never applied silently." % (len(sp), len(np), len(seed.get("classes", {})), THRESHOLD), "",
         "This run: %d spell / %d NPC evidence rows, %d promoted, %d drift proposal(s), skipped (already merged): %s" % (
             rep.get("spells", 0), rep.get("npcs", 0), len(rep.get("promoted", [])), len(rep.get("proposals", [])), ", ".join(rep.get("skipped") or []) or "-"), "",
         "### Most-seen spells", "", "| spell | name | school | casts by | cast time (promoted) | auras | damage | heal | conf |", "|---|---|---|---|---|---|---|---|---|"]
    rows = sorted(sp.items(), key=lambda kv: -(kv[1].get("samples") or 0))[:top]
    for k, e in rows:
        ct = ", ".join("%s %s (n=%d)" % (c, s.get("promoted", "-"), s.get("n", 0)) for c, s in (e.get("castT") or {}).items())
        au = ", ".join("%s%s" % (a, ("/%s %.1fs" % (v.get("kind") or "?", v["dur"]["max"])) if v.get("dur") else "") for a, v in list((e.get("aura") or {}).items())[:4])
        d, h = e.get("dmg"), e.get("heal")
        L.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (k, e.get("name") or "?", e.get("school") or "?",
                 ", ".join("%s %d" % kv for kv in (e.get("casts") or {}).items()) or "-", ct or "-", au or "-",
                 ("%s-%s" % (d["min"], d["max"])) if d else "-", ("%s-%s" % (h["min"], h["max"])) if h else "-", e.get("confidence")))
    L += ["", "### NPCs", "", "| npcID | name | spells | cast model | interruptible | targets |", "|---|---|---|---|---|---|"]
    for k, e in sorted(np.items(), key=lambda kv: -sum((kv[1].get("spells") or {}).values()))[:top]:
        cm = ", ".join("%s %.2fs n=%d" % (s, v["med"], v["n"]) for s, v in (e.get("castT") or {}).items() if v)
        L.append("| %s | %s | %s | %s | %s | %s |" % (k, e.get("name") or "?", ", ".join("%s x%d" % kv for kv in (e.get("spells") or {}).items()) or "-",
                 cm or "-", e.get("interruptible"), ", ".join("%s %d" % kv for kv in (e.get("tgt") or {}).items()) or "-"))
    if rep.get("proposals"):
        L += ["", "### Drift proposals (old -> new; review, then `--write-seed`)", "", "| kind | key | old | new | n | build | date |", "|---|---|---|---|---|---|---|"]
        for p in rep["proposals"]:
            L.append("| %s | %s | %s | %s | %s | %s | %s |" % (p.get("kind"), p.get("spell", p.get("key")), p.get("old"), p.get("new"), p.get("n"), p.get("build"), p.get("date")))
    return "\n".join(L) + "\n"
