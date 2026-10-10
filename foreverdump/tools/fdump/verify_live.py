"""v2.2.4 verify-live: join the live in-engine verification records (ForeverDumpDB.verify[build] ring, Verify.lua) with
the combat log. Captures before v2.2.4 have no ring: the verdicts then come from the offline replay of the recorded live
events through the same library (marked source=replay). For each verdict: confirmed / refuted / no-truth by the log; per
check-type accuracy (confirmed / judged) and coverage (verdicts V or C / all verdicts); a knowledge patch the next build
loads (ForeverDump/Data/KnowledgePatch.lua): learned aura durations, cooldowns, aura mappings, per-NPC cast times, rule
timings."""
import collections
import re
import json
import os

from fdump.luasv import as_list
from fdump.xref import anchor_epoch


def ring_records(dump):
    """SV ring -> verdict dicts on the epoch timebase (via the session anchors)"""
    out = []
    vdb = dump.db.get("verify") if isinstance(getattr(dump, "db", None), dict) else None
    for b, d in ((vdb or {}).items() if isinstance(vdb, dict) else []):
        sess = as_list((d or {}).get("sessions"))
        ring = (d or {}).get("ring") or {}
        recs = ring.values() if isinstance(ring, dict) else ring
        for r in recs:
            if not isinstance(r, dict):
                continue
            anc = None
            for s in sess:
                if isinstance(s, dict) and (s.get("seq0") or 0) <= (r.get("s") or 0):
                    anc = s.get("anchor")
            te = anchor_epoch(anc or {}, r.get("t"))[0] if anc else None
            out.append({"t": te, "kind": r.get("k"), "v": r.get("v"), "src": r.get("src"), "conf": r.get("cf"), "spell": r.get("sp"),
                        "d": r.get("d"), "key": r.get("key"), "ctx": r.get("c"), "source": "ring"})
    return out


def unexpected(dump):
    vdb = dump.db.get("verify") if isinstance(getattr(dump, "db", None), dict) else None
    out = []
    for b, d in ((vdb or {}).items() if isinstance(vdb, dict) else []):
        for k, x in ((d or {}).get("unexpected") or {}).items():
            if isinstance(x, dict):
                out.append(dict(x, build=b))
    return sorted(out, key=lambda x: -(x.get("n") or 0))


def _log(fx, player):
    ev = [e for e in (fx or {}).get("events", []) if e.get("cleu")]
    idx = collections.defaultdict(list)
    for e in ev:
        a = e["a"]
        idx[e["sub"]].append(e)
    return ev, idx


def _near(lst, t, w, pred=None):
    best = None
    for e in lst:
        if abs(e["t"] - t) <= w and (pred is None or pred(e)):
            if best is None or abs(e["t"] - t) < abs(best["t"] - t):
                best = e
    return best


_PRECOND = re.compile(r"\bdead\b|\bghost\b", re.I)   # only "You are dead" provably fails before the cooldown check


def judge(verdicts, fx, player, cls):
    ev, idx = _log(fx, player)
    rows = []
    for v in verdicts:
        t, kind, sp = v.get("t"), v.get("kind"), v.get("spell")
        res, why = "no-truth", ""
        if t is None:
            rows.append(dict(v, truth=res, why="no time anchor"))
            continue
        if kind == "cooldown":
            if v.get("v") == "V" and str(v.get("src", "")).startswith("UNIT_SPELLCAST_SUCCEEDED"):
                e = _near(idx["SPELL_CAST_SUCCESS"], t, 0.15, lambda e: e["a"][3] == player and e["a"][11] == sp)
                res, why = ("confirmed", "log recast") if e else ("no-truth", "recast not in log")
            elif v.get("v") == "C":
                e = _near(idx["SPELL_CAST_SUCCESS"], t, 0.15, lambda e: e["a"][3] == player and e["a"][11] == sp)
                res, why = ("refuted", "recast succeeded in the log: the cooldown model was wrong") if e else ("no-truth", "")
                if e:
                    res = "confirmed-contradiction"
            else:
                e = _near(idx["SPELL_CAST_FAILED"], t, 0.15, lambda e: e["a"][3] == player and e["a"][11] == sp)
                if e and _PRECOND.search(str(e["a"][-1])):
                    # v2.2.16 (run 13): "You are dead" is checked BEFORE the cooldown;
                    # the failure says nothing about the cooldown model either way
                    res, why = "no-truth", "precondition failure (cooldown not checked): %s" % e["a"][-1]
                elif e:
                    nyr = e["a"][-1] == "Not yet recovered"
                    if v.get("v") == "V":
                        res, why = ("confirmed", "log: Not yet recovered") if nyr else ("refuted", "log reason: %s" % e["a"][-1])
                    else:
                        res, why = ("missed", "log says Not yet recovered: the cooldown model had no window") if nyr else ("confirmed", "log reason: %s" % e["a"][-1])
        elif kind == "cast-end":
            e = _near(idx["SPELL_CAST_SUCCESS"], t, 0.2, lambda e: cls(e["a"][3]) == "npc")
            res, why = ("confirmed" if v.get("v") == "V" else "confirmed-contradiction", "log NPC cast success") if e else ("no-truth", "")
        elif kind == "interrupt-attribution":
            e = _near(idx["SPELL_INTERRUPT"], t, 0.3)
            if e:
                mine = e["a"][3] == player
                res = "confirmed" if (mine and v.get("v") == "V") else ("refuted" if v.get("v") == "V" else "judged-unverified")
                why = "log interrupter %s, spell %s" % ("me" if mine else cls(e["a"][3]), e["a"][11])
        elif kind == "damage-range":
            e = _near(idx["SPELL_DAMAGE"], t, 0.15, lambda e: e["a"][3] == player and e["a"][11] == sp)
            res, why = ("confirmed" if v.get("v") == "V" else "confirmed-contradiction", "log amount %s" % (e["a"][14] if e else "?")) if e else ("no-truth", "")
        elif kind == "aura-expiry":
            e = _near(idx["SPELL_AURA_REMOVED"], t, 1.5, lambda e: e["a"][11] == sp)
            res, why = ("confirmed", "log removal") if e else ("no-truth", "")
        elif kind == "dm-total":
            res, why = "n/a", "post-combat meter vs live sum (see COVERAGE fights table)"
        rows.append(dict(v, truth=res, why=why))
    by = collections.defaultdict(collections.Counter)
    for r in rows:
        by[r["kind"]][r["v"]] += 1
        by[r["kind"]]["truth:" + r["truth"]] += 1
    acc = {}
    for k, c in by.items():
        judged = c["truth:confirmed"] + c["truth:refuted"] + c["truth:confirmed-contradiction"]
        n = sum(c[x] for x in ("V", "C", "U", "X", "P"))   # v2.2.16: shadow-candidate P verdicts counted
        acc[k] = {"n": n, "V": c["V"], "C": c["C"], "U": c["U"], "P": c["P"], "confirmed": c["truth:confirmed"] + c["truth:confirmed-contradiction"],
                  "refuted": c["truth:refuted"], "missed": c["truth:missed"],
                  "accuracy": round(100.0 * (c["truth:confirmed"] + c["truth:confirmed-contradiction"]) / judged, 1) if judged else None,
                  "coverage": round(100.0 * (c["V"] + c["C"]) / n, 1) if n else None}
    return rows, acc


def knowledge_patch(klint, cov, build=None):
    """next-build patch: only facts observed in reality (log or live), never names/GUIDs"""
    spells = {}
    rp = (klint or {}).get("reparse") or {}
    for sid, ob in (klint or {}).get("observed", {}).items():
        e = {}
        p = rp.get(sid) or rp.get(str(sid)) or {}
        # an observed aura duration only fills a GAP (no parsed duration) and never for charge-based auras
        ad = [x for x in ob.get("auraDurations") or [] if isinstance(x, (int, float))]
        # >= 2 consistent observations (a cancelled form / a dead target gives one short random value)
        if len(ad) >= 2 and (max(ad) - min(ad)) <= 0.1 * max(ad) and not p.get("auraDuration") and not p.get("consumable"):
            e["auraObserved"] = max(ad)
        if ob.get("minRecast") is not None and ob["minRecast"] < 600:
            e["minRecast"] = ob["minRecast"]
        if e:
            spells[int(sid)] = e
    for sid, m in (klint or {}).get("auraMap", {}).items():
        best = max(m.items(), key=lambda x: x[1]) if m else None
        if best and best[1] >= 2:
            spells.setdefault(int(sid), {})["auraId"] = int(best[0])
    for sid, p in ((klint or {}).get("reparse") or {}).items():
        if p.get("interrupt"):
            spells.setdefault(int(sid), {})["interrupt"] = True
            if p.get("lockout"):
                spells[int(sid)]["lockout"] = p["lockout"]
    npc = {}
    model = ((cov or {}).get("casts") or {}).get("model")
    for k, m in (model.items() if isinstance(model, dict) else []):
        if str(k).startswith("npc:") and isinstance(m, dict) and m.get("median"):
            npc[str(k)[4:]] = {"castMedian": round(m["median"], 3), "min": round(m["min"], 3), "max": round(m["max"], 3), "n": m["n"]}
    rules = {}
    tm = (cov or {}).get("timing") or {}
    if "damage/melee" in tm:
        rules["swingLag"] = [round(max(0.0, tm["damage/melee"]["min"] - 0.05), 3), round(tm["damage/melee"]["max"] + 0.1, 3)]
    return {"schema": "foreverdump.knowledgepatch/1", "build": build, "spells": spells, "npcCasts": npc, "rules": rules}


def _lua(v, ind=""):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "{ " + ", ".join(_lua(x) for x in v) + " }"
    if isinstance(v, dict):
        parts = []
        for k, x in sorted(v.items(), key=lambda kv: str(kv[0])):
            key = "[%s]" % k if isinstance(k, int) or (isinstance(k, str) and k.isdigit()) else ("[%s]" % json.dumps(k) if not k.isidentifier() else k)
            if isinstance(k, str) and k.isdigit():
                key = "[%s]" % int(k)
            parts.append("%s%s = %s" % (ind + "    ", key, _lua(x, ind + "    ")))
        return "{\n" + ",\n".join(parts) + "\n" + ind + "}"
    return "nil"


def patch_lua(patch):
    return ("-- ForeverDump knowledge patch (generated by `fdump.py verify-live` / `analyze`; facts observed in real captures).\n"
            "-- Loaded by Knowledge.lua into the HSM at capture start with LOWER priority than live data. No names, no GUIDs.\n"
            "local _, ns = ...\nns.KnowledgePatch = " + _lua(patch) + "\n")


def analyze(dump, fx, player, cov, klint, cls, replay_verdicts=None):
    ring = ring_records(dump)
    src = "ring" if ring else "replay"
    verdicts = ring if ring else [dict(v, source="replay") for v in as_list(replay_verdicts)]
    rows, acc = judge(verdicts, fx, player, cls)
    patch = knowledge_patch(klint, cov, build=None)
    return {"source": src, "verdicts": len(verdicts), "rows": rows, "accuracy": acc, "unexpected": unexpected(dump), "patch": patch}


def markdown(res):
    L = ["# VERIFY: live verification loop joined with the combat log", "",
         "Verdict source: **%s** (%s). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees "
         "with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for." % (
             res["source"], "SV ring ForeverDumpDB.verify" if res["source"] == "ring" else "pre-2.2.4 capture: offline replay of the recorded live events through HybridState MINOR 4"), "",
         "| check | n | V | C | U | P | confirmed | refuted | missed | accuracy % | coverage % |", "|---|---|---|---|---|---|---|---|---|---|---|"]
    for k, a in sorted(res["accuracy"].items()):
        L.append("| %s | %d | %d | %d | %d | %d | %d | %d | %d | %s | %s |" % (k, a["n"], a["V"], a["C"], a["U"], a.get("P", 0), a["confirmed"], a["refuted"], a["missed"], a["accuracy"], a["coverage"]))
    bad = [r for r in res["rows"] if r["truth"] in ("refuted", "missed")]
    if bad:
        L += ["", "Refuted / missed:", ""] + ["- t=%s %s %s spell %s: %s (%s)" % (r.get("t"), r["kind"], r["v"], r.get("spell"), r["truth"], r.get("why")) for r in bad[:30]]
    if res["unexpected"]:
        L += ["", "## Unexpected findings (live)", "", "| kind | key | detail | n | ctx |", "|---|---|---|---|---|"]
        for u in res["unexpected"][:60]:
            L.append("| %s | %s | %s | %s | %s |" % (u.get("kind"), u.get("key"), u.get("detail"), u.get("n"), u.get("c")))
    p = res["patch"]
    L += ["", "## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)", "",
          "%d spell fact set(s), %d NPC cast model(s), rules %s." % (len(p["spells"]), len(p["npcCasts"]), json.dumps(p["rules"])), ""]
    for sid, e in sorted(p["spells"].items()):
        L.append("- spell %s: %s" % (sid, json.dumps(e, sort_keys=True)))
    for k, e in sorted(p["npcCasts"].items()):
        L.append("- npc %s: cast median %.3f s (%.3f-%.3f, n=%d)" % (k, e["castMedian"], e["min"], e["max"], e["n"]))
    return "\n".join(L) + "\n"
