"""v2.2.4 per-spell GCD / cooldown reference table ("spell timing seed").

Shipped as ForeverDump/Data/spell-timing.lua (loaded in game into the CooldownTracker, lowest priority below live data)
with a JSON mirror tools/fdump/data/spell-timing.json. Per spellID: baseGCD, observedGCD, baseCooldown, observedCooldown,
castTime (seconds), startRecoveryCategory / category, source (api | observed | log | known-answer), samples, confidence,
first/last build and date. Spell IDs and numbers only: no names, no GUIDs, no character data.

Evidence per capture (evidence()):
  api      knowledge pass (GetSpellBaseCooldown -> baseCooldown/baseGCD ms, C_Spell.GetSpellInfo castTime ms), out of combat
  payload  SPELL_UPDATE_COOLDOWN (spellID, category, startRecoveryCategory): clear in combat on 1.60.1
  log      gaps between my consecutive cast begins (upper bounds of the GCD of the first spell), same-spell / same-category
           recast gaps (upper bound of the cooldown) and 'Not yet recovered' fails (lower bound)
  live     ForeverDumpDB.timing[build] (v2.2.4 Timing.lua: isActive/isOnGCD flips, clear out-of-combat reads, cast gaps)
merge(): api values fill empty fields; a differing value is a CONFLICT (flagged, never overwritten); observed values are
promoted only once their sample count reaches the threshold (pending until then); known answers are checked, not trusted
blindly (a mismatch is reported)."""
import collections
import datetime
import json
import os

from fdump.luasv import as_list

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SEED_JSON = os.path.join(ROOT, "tools", "fdump", "data", "spell-timing.json")
SEED_LUA = os.path.join(ROOT, "ForeverDump", "Data", "spell-timing.lua")
SCHEMA = "foreverdump.spelltiming/1"
GCD_SPELLS_MAX_GAP = 3.0      # a gap longer than this says nothing about the GCD
TIGHT = 0.30                  # a gap within baseGCD + 0.30 s counts as a GCD sample
THRESHOLD = 3                 # samples before an observed value is promoted

# known answers (user, 2026-10-08): shaman totems 1.0 s GCD, Lightning Shield 1.5 s. IDs seen in runs 3-5.
TOTEMS = [2484, 8184, 8227, 8181, 8177, 5394, 6375, 5675, 10595, 8166, 6363, 6364, 3599, 6390, 6391, 5730, 8154, 8155, 8071,
          8075, 8160, 8143]
LIGHTNING_SHIELD = [324, 325, 905]
KNOWN_ANSWERS = dict([(i, {"gcd": 1.0, "label": "totem"}) for i in TOTEMS] + [(i, {"gcd": 1.5, "label": "Lightning Shield"}) for i in LIGHTNING_SHIELD])


def _date(dump):
    m = (dump.db.get("meta") or {}) if isinstance(getattr(dump, "db", None), dict) else {}
    return str(m.get("date") or "")[:10] or None, str(m.get("build") or "") or None


def evidence(dump, fx=None, player=None, label="capture"):
    """one capture -> {meta, spells: {id: {...}}}"""
    date, build = _date(dump)
    sp = collections.defaultdict(dict)
    kdb = dump.db.get("knowledge") if isinstance(getattr(dump, "db", None), dict) else None
    for b, bv in ((kdb or {}).items() if isinstance(kdb, dict) else []):
        for sid, e in (((bv or {}).get("spells") or {}).items() if isinstance(bv, dict) else []):
            try:
                sid = int(sid)
            except (TypeError, ValueError):
                continue
            d = (e or {}).get("data") or {}
            for f, k in (("baseGCD", "baseGCD"), ("baseCooldown", "baseCooldown"), ("info.castTime", "castTime")):
                if isinstance(d.get(f), (int, float)):
                    sp[sid][k] = round(d[f] / 1000.0, 3)
            build = build or str(b)
    # SPELL_UPDATE_COOLDOWN payloads (RecordDB, clear)
    rs = as_list((dump.record or {}).get("sessions")) if getattr(dump, "record", None) else []
    for s in rs:
        for e in as_list((s or {}).get("events")):
            if e.get("e") == "SPELL_UPDATE_COOLDOWN":
                a = as_list(e.get("a"))
                if a and isinstance(a[0], int) and len(a) > 3:
                    if isinstance(a[3], int):
                        sp[a[0]]["srCategory"] = a[3]
                    if isinstance(a[2], int):
                        sp[a[0]]["category"] = a[2]
    # live learned (v2.2.4 Timing.lua)
    tdb = dump.db.get("timing") if isinstance(getattr(dump, "db", None), dict) else None
    for b, bv in ((tdb or {}).items() if isinstance(tdb, dict) else []):
        for sid, e in (((bv or {}).get("spells") or {}).items() if isinstance(bv, dict) else []):
            try:
                sp[int(sid)]["live"] = dict(e)
            except (TypeError, ValueError):
                pass
    # combat log
    if fx and player:
        # the file log is appended across sessions (run 5's file also holds run 4): only the capture's own span counts
        lo = hi = None
        try:
            from fdump.coverage import Live
            lo, hi = Live(dump).span
        except Exception:   # noqa: BLE001
            pass
        inspan = (lambda t: lo is None or (lo - 5 <= t <= hi + 5))
        casts = [e for e in fx.get("events", []) if e.get("cleu") and e["a"][3] == player and e["sub"] in ("SPELL_CAST_START", "SPELL_CAST_SUCCESS")
                 and isinstance(e["a"][11], int) and inspan(e["t"])]
        begins = []
        for e in casts:
            sid = e["a"][11]
            if e["sub"] == "SPELL_CAST_START":
                begins.append((e["t"], sid))
            else:
                ct = sp.get(sid, {}).get("castTime") or 0
                if not any(b[1] == sid and 0 <= e["t"] - b[0] <= ct + 0.6 for b in begins[-3:]):
                    begins.append((e["t"], sid))
        begins.sort()
        for (t0, a), (t1, _b) in zip(begins, begins[1:]):
            gap = t1 - t0
            if 0.05 < gap < GCD_SPELLS_MAX_GAP:
                x = sp[a]
                x["gapN"] = x.get("gapN", 0) + 1
                x["gapMin"] = round(min(x.get("gapMin", 99), gap), 3)
                x.setdefault("gaps", []).append(round(gap, 3))
        succ = collections.defaultdict(list)
        for e in casts:
            if e["sub"] == "SPELL_CAST_SUCCESS":
                succ[e["a"][11]].append(e["t"])
        for sid, ts in succ.items():
            gaps = [b - a for a, b in zip(ts, ts[1:])]
            if gaps:
                sp[sid]["recastMin"] = round(min(gaps), 3)
                sp[sid]["recastN"] = len(gaps)
        for e in fx.get("events", []):
            if e.get("cleu") and e["sub"] == "SPELL_CAST_FAILED" and e["a"][3] == player and e["a"][-1] == "Not yet recovered" and inspan(e["t"]):
                sid = e["a"][11]
                cat = sp.get(sid, {}).get("category")
                same = [s for s, x in sp.items() if s == sid or (cat and x.get("category") == cat)]
                prev = [t for s in same for t in succ.get(s, []) if t < e["t"]]
                if prev:
                    lb = round(e["t"] - max(prev), 3)
                    sp[sid]["nyrMin"] = max(sp[sid].get("nyrMin", 0), lb)   # the cooldown is longer than this
    cs = as_list((dump.combatlog or {}).get("sessions")) if getattr(dump, "combatlog", None) else []
    cid = (cs[-1] or {}).get("captureSid") if cs else None
    return {"label": label, "id": cid or "%s|%s" % (date, label), "build": build, "date": date, "spells": dict(sp)}


def load_seed(path=SEED_JSON):
    if path and os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return {"schema": SCHEMA, "spells": {}, "pending": {}, "conflicts": []}


def _conf(n):
    return "high" if n >= 10 else ("medium" if n >= THRESHOLD else "low")


def merge(seed, evidences, threshold=THRESHOLD):
    """seed + capture evidence -> (new seed, report). Never overwrites a differing value: conflicts are flagged."""
    out = json.loads(json.dumps(seed or {"spells": {}}))
    out["schema"] = SCHEMA
    S = out.setdefault("spells", {})
    P = out.setdefault("pending", {})
    conflicts = list(out.get("conflicts") or [])
    rep = {"promoted": [], "conflicts": [], "filled": 0, "knownAnswers": []}

    def conflict(sid, field, have, new, src, ev):
        c = {"spell": int(sid), "field": field, "seed": have, "new": new, "source": src, "capture": ev["label"], "build": ev["build"]}
        if c not in conflicts:
            conflicts.append(c)
            rep["conflicts"].append(c)

    # known answers are seeded (source known-answer) and then checked against every capture
    for sid, ka in KNOWN_ANSWERS.items():
        e = S.setdefault(str(sid), {})
        if e.get("knownGCD") is None:
            e["knownGCD"] = ka["gcd"]
    merged = out.setdefault("merged", [])
    for ev in evidences:
        if ev.get("id") in merged:
            rep.setdefault("skipped", []).append(ev["label"])   # already merged: samples are never counted twice
            continue
        merged.append(ev.get("id"))
        for sid, x in ev["spells"].items():
            key = str(sid)
            e = S.setdefault(key, {})
            e.setdefault("firstBuild", ev["build"])
            e.setdefault("firstSeen", ev["date"])
            e["lastBuild"], e["lastSeen"] = ev["build"], ev["date"]
            for f in ("baseGCD", "baseCooldown", "castTime", "srCategory", "category"):
                if x.get(f) is None:
                    continue
                if e.get(f) is None:
                    e[f] = x[f]
                    rep["filled"] += 1
                elif abs(float(e[f]) - float(x[f])) > 1e-6:
                    conflict(sid, f, e[f], x[f], "api" if f in ("baseGCD", "baseCooldown", "castTime") else "payload", ev)
            # GCD samples: log gaps within baseGCD + TIGHT (+ live isOnGCD learning)
            p = P.setdefault(key, {})
            base = e.get("knownGCD") or e.get("baseGCD")
            tight = [g for g in x.get("gaps", []) if base is not None and g <= base + TIGHT]
            if tight:
                p["gcdN"] = p.get("gcdN", 0) + len(tight)
                p["gcdMin"] = round(min(p.get("gcdMin", 99), min(tight)), 3)
            lv = x.get("live") or {}
            if lv.get("gcdN"):
                p["gcdN"] = p.get("gcdN", 0) + lv["gcdN"]
                p["gcdMin"] = round(min(p.get("gcdMin", 99), lv.get("gcdMin", 99)), 3)
            if lv.get("gcdCal") is not None:
                p["gcdCal"] = lv["gcdCal"]
            if x.get("gapMin") is not None:
                p["gapMin"] = round(min(p.get("gapMin", 99), x["gapMin"]), 3)
                ref = e.get("observedGCD") or e.get("knownGCD") or e.get("baseGCD")
                if ref is not None and x["gapMin"] < ref - 0.1:
                    conflict(sid, "gcd", ref, x["gapMin"], "log gap shorter than the GCD", ev)
            # cooldown samples (live isActive flips / clear reads); log recast + NYR bounds as checks
            if lv.get("cdN"):
                p["cdN"] = p.get("cdN", 0) + lv["cdN"]
                p["cdSum"] = round(p.get("cdSum", 0) + lv.get("cdSum", 0), 3)
            if lv.get("cal") is not None:
                p["cal"] = lv["cal"]
            cdref = e.get("observedCooldown") or e.get("baseCooldown")
            if x.get("recastMin") is not None and cdref and x["recastMin"] < cdref - 0.15:
                conflict(sid, "cooldown", cdref, x["recastMin"], "log recast before the cooldown", ev)
            if x.get("nyrMin") is not None:
                p["nyrMin"] = max(p.get("nyrMin", 0), x["nyrMin"])
                if cdref and x["nyrMin"] > cdref + 0.15:
                    conflict(sid, "cooldown", cdref, x["nyrMin"], "'Not yet recovered' after the cooldown", ev)
            if not p:
                P.pop(key, None)
    # promotion
    for key, p in list(P.items()):
        e = S.setdefault(key, {})
        if p.get("gcdCal") is not None and e.get("observedGCD") != p["gcdCal"]:
            e.update(observedGCD=p["gcdCal"], gcdSource="observed", gcdSamples=max(1, p.get("gcdN", 0)), gcdConfidence="high")
            rep["promoted"].append({"spell": int(key), "field": "observedGCD", "value": p["gcdCal"], "why": "clear out-of-combat read"})
        elif p.get("gcdN", 0) >= threshold and e.get("observedGCD") is None:
            e.update(observedGCD=p["gcdMin"], gcdSource="log", gcdSamples=p["gcdN"], gcdConfidence=_conf(p["gcdN"]))
            rep["promoted"].append({"spell": int(key), "field": "observedGCD", "value": p["gcdMin"], "why": "%d tight gaps" % p["gcdN"]})
        if p.get("cal") is not None and e.get("observedCooldown") != p["cal"]:
            e.update(observedCooldown=p["cal"], cdSource="observed", cdSamples=max(1, p.get("cdN", 0)), cdConfidence="high")
            rep["promoted"].append({"spell": int(key), "field": "observedCooldown", "value": p["cal"], "why": "clear out-of-combat read"})
        elif p.get("cdN", 0) >= threshold and e.get("observedCooldown") is None:
            v = round(p["cdSum"] / p["cdN"], 3)
            e.update(observedCooldown=v, cdSource="observed", cdSamples=p["cdN"], cdConfidence=_conf(p["cdN"]))
            rep["promoted"].append({"spell": int(key), "field": "observedCooldown", "value": v, "why": "%d isActive flips" % p["cdN"]})
    # resolved values the addon uses + source / confidence
    for key, e in S.items():
        if e.get("knownGCD") is not None:
            e["gcd"], e["source"], e["confidence"] = e["knownGCD"], "known-answer", "high"
        elif e.get("observedGCD") is not None and e.get("gcdConfidence") in ("high", "medium"):
            e["gcd"], e["source"], e["confidence"] = e["observedGCD"], e.get("gcdSource", "observed"), e["gcdConfidence"]
        elif e.get("baseGCD") is not None:
            e["gcd"], e["source"], e["confidence"] = e["baseGCD"], "api", "medium"
        if e.get("observedCooldown") is not None and e.get("cdConfidence") in ("high", "medium"):
            e["cooldown"] = e["observedCooldown"]
        elif e.get("baseCooldown"):
            e["cooldown"] = e["baseCooldown"]
        e["samples"] = (P.get(key) or {}).get("gcdN", 0) + (P.get(key) or {}).get("cdN", 0)
    out["conflicts"] = conflicts
    out["generated"] = datetime.date.today().isoformat()
    rep["knownAnswers"] = known_answer_check(out, evidences)
    return out, rep


def known_answer_check(seed, evidences):
    """baseGCD from the API and the minimum gap after each cast vs the known answer, per capture"""
    rows = []
    for sid, ka in sorted(KNOWN_ANSWERS.items()):
        for ev in evidences:
            x = ev["spells"].get(sid) or ev["spells"].get(str(sid)) or {}
            if not x:
                continue
            api = x.get("baseGCD")
            gap = x.get("gapMin")
            ok_api = api is None or abs(api - ka["gcd"]) < 1e-6
            ok_gap = gap is None or gap >= ka["gcd"] - 0.1
            rows.append({"spell": sid, "label": ka["label"], "known": ka["gcd"], "capture": ev["label"], "baseGCD": api, "gapMin": gap,
                         "gapN": x.get("gapN", 0), "ok": ok_api and ok_gap,
                         "why": "" if ok_api and ok_gap else ("baseGCD %s != %s" % (api, ka["gcd"]) if not ok_api else "a cast %.3f s after it" % gap)})
    return rows


def seed_events(seed):
    """seed -> replay 'cdseed' events (HybridState CDSeed)"""
    out = []
    for key, e in (seed or {}).get("spells", {}).items():
        x = {k: e.get(k) for k in ("gcd", "cooldown", "srCategory", "category", "confidence") if e.get(k) is not None}
        if x:
            out.append(dict(x, spell=int(key)))
    return out


LUA_FIELDS = ("gcd", "cooldown", "baseGCD", "observedGCD", "knownGCD", "baseCooldown", "observedCooldown", "castTime", "srCategory",
              "category", "source", "samples", "confidence", "firstBuild", "lastBuild", "firstSeen", "lastSeen")


def to_lua(seed):
    L = ["-- ForeverDump spell timing seed (generated by `fdump.py analyze` / tools/fdump/timing.py; JSON mirror",
         "-- tools/fdump/data/spell-timing.json). Per spellID: GCD / cooldown / cast time in seconds, startRecoveryCategory,",
         "-- category, source (api|observed|log|known-answer), samples, confidence, first/last build and date.",
         "-- Spell IDs and numbers only. Loaded into the CooldownTracker below live data (Timing.lua).",
         "local _, ns = ...", "ns.SpellTimingSeed = {", '    schema = "%s",' % SCHEMA, '    generated = "%s",' % seed.get("generated", ""),
         "    spells = {"]
    for key in sorted(seed.get("spells", {}), key=lambda k: int(k)):
        e = seed["spells"][key]
        parts = []
        for f in LUA_FIELDS:
            v = e.get(f)
            if v is None:
                continue
            parts.append("%s = %s" % (f, json.dumps(v) if isinstance(v, str) else repr(v)))
        if parts:
            L.append("        [%d] = { %s }," % (int(key), ", ".join(parts)))
    L += ["    },", "}", ""]
    return "\n".join(L)


def write_seed(seed, json_path=SEED_JSON, lua_path=SEED_LUA):
    os.makedirs(os.path.dirname(json_path), exist_ok=True)
    with open(json_path, "w") as f:
        json.dump(seed, f, indent=1, sort_keys=True)
    os.makedirs(os.path.dirname(lua_path), exist_ok=True)
    with open(lua_path, "w") as f:
        f.write(to_lua(seed))


def markdown(seed, rep):
    L = ["## Spell timing table (GCD / cooldown per spellID)", "",
         "Seed: ForeverDump/Data/spell-timing.lua (+ tools/fdump/data/spell-timing.json). Promotion threshold %d samples; "
         "conflicts are flagged, never overwritten." % THRESHOLD, "",
         "### Known answers (totems 1.0 s, Lightning Shield 1.5 s)", "",
         "Permanent regression check: GetSpellBaseCooldown baseGCD and the minimum gap between a cast of the spell and my next cast "
         "begin in the combat log (each capture's own span; a gap below the known GCD - 0.1 s would refute it).", "",
         "| spell | what | known GCD | captures | baseGCD (API) | min gap after it (log) | gaps | ok |", "|---|---|---|---|---|---|---|---|"]
    agg = collections.OrderedDict()
    for r in rep["knownAnswers"]:
        a = agg.setdefault(r["spell"], {"label": r["label"], "known": r["known"], "caps": [], "api": set(), "gap": None, "n": 0, "ok": True, "why": []})
        a["caps"].append(r["capture"])
        if r["baseGCD"] is not None:
            a["api"].add(r["baseGCD"])
        if r["gapMin"] is not None:
            a["gap"] = r["gapMin"] if a["gap"] is None else min(a["gap"], r["gapMin"])
        a["n"] += r["gapN"]
        if not r["ok"]:
            a["ok"] = False
            a["why"].append("%s: %s" % (r["capture"], r["why"]))
    for sid, a in agg.items():
        L.append("| %s | %s | %.1f | %s | %s | %s | %d | %s |" % (sid, a["label"], a["known"], ",".join(a["caps"]), ",".join(str(x) for x in sorted(a["api"])) or "-",
                                                            a["gap"] if a["gap"] is not None else "-", a["n"], "yes" if a["ok"] else "**NO: %s**" % "; ".join(a["why"])))
    bad = [r for r in rep["knownAnswers"] if not r["ok"]]
    L += ["", "Known-answer mismatches: %s." % (len(bad) or "none"), ""]
    L += ["### Table", "", "| spell | GCD | source | conf | baseGCD | observedGCD | cooldown | baseCD | observedCD | cast | srCat | cat | samples | builds | seen |",
          "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for key in sorted(seed["spells"], key=lambda k: int(k)):
        e = seed["spells"][key]
        if e.get("gcd") is None and e.get("cooldown") is None and e.get("srCategory") is None:
            continue
        L.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s-%s | %s..%s |" % (
            key, e.get("gcd"), e.get("source"), e.get("confidence"), e.get("baseGCD"), e.get("observedGCD"), e.get("cooldown"), e.get("baseCooldown"),
            e.get("observedCooldown"), e.get("castTime"), e.get("srCategory"), e.get("category"), e.get("samples"), e.get("firstBuild"),
            e.get("lastBuild"), e.get("firstSeen"), e.get("lastSeen")))
    if rep["promoted"]:
        L += ["", "Promoted this merge:", ""] + ["- %s %s = %s (%s)" % (p["spell"], p["field"], p["value"], p["why"]) for p in rep["promoted"]]
    if rep["conflicts"]:
        L += ["", "Conflicts (flagged, seed kept):", "", "| spell | field | seed | new | source | capture |", "|---|---|---|---|---|---|"]
        for c in rep["conflicts"]:
            L.append("| %s | %s | %s | %s | %s | %s |" % (c["spell"], c["field"], c["seed"], c["new"], c["source"], c["capture"]))
    return "\n".join(L) + "\n"
