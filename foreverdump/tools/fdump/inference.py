"""Inference + hybrid state machine (HSM) scoring against the WoWCombatLog file (ground truth, offline only).

Sources of predictions/inferences:
  * addon: ForeverDumpLogDB.inference (live HSM during FD_Logs: predictions, inferences, inputs, signals, anchor)
  * replay: the file log turned into a Forever-observable stream (player UNIT_SPELLCAST_* + UNIT_AURA add/remove for
    the player's own auras, auraInstanceIDs synthesized) and fed to the SAME Lua library (Lib/HybridState.lua) via
    lua5.1. Knowledge is learned online (only from events BEFORE each prediction: first applied->removed pair = aura
    duration, min recast gap = cooldown, observed non-crit amounts = range), like the addon caching while readable.
    Modes: `clear` (spellId readable, out-of-combat-like) and `secret` (spellId/fromPlayer secret, iid readable).
Truth: SPELL_CAST_START/SUCCESS, SPELL_AURA_APPLIED/REFRESH/REMOVED(/_DOSE), SPELL_DAMAGE/HEAL(+crit), SPELL_MISSED by the
player. Times: addon GetTime -> epoch through the inference anchor (xref timebase); file lines are epoch already."""
import collections
import json
import os
import shutil
import subprocess
import tempfile

from . import combatlog
from .xref import anchor_epoch
from .luasv import as_list

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(HERE, "..", "..", "ForeverDump", "Lib", "HybridState.lua")
RUNNER = os.path.join(HERE, "lua", "hsm_replay.lua")


def _flags(v):
    if isinstance(v, int):
        return v
    try:
        return int(str(v), 16) if str(v).startswith("0x") else int(v)
    except (TypeError, ValueError):
        return None


def owner_guid(fx):
    """the log owner: most frequent source with unit flags 0x511 (mine | friendly | player-controlled | player)"""
    c = collections.Counter()
    for e in fx.get("events", []):
        a = e.get("a") or []
        if e.get("cleu") and len(a) > 5 and _flags(a[5]) == 0x511 and str(a[3]).startswith("Player-"):
            c[(a[3], a[4])] += 1
    return c.most_common(1)[0][0] if c else (None, None)


def truth(fx, player):
    """player-centric ground truth from the file"""
    out = {"casts": [], "starts": [], "auras": [], "amounts": [], "misses": [], "damageTimes": [], "summons": [], "dispels": []}
    ends = {}
    for e in fx.get("events", []):
        if e.get("cleu") and e["sub"] in ("UNIT_DIED", "UNIT_DESTROYED", "UNIT_DISSIPATES", "SPELL_INSTAKILL"):
            a = e["a"]
            g = a[7] if len(a) > 7 else None
            if g and g not in ends:
                ends[g] = (a[0], e["sub"])
    for e in fx.get("events", []):
        if not e.get("cleu"):
            continue
        a = e["a"]
        sub, t = e["sub"], a[0]
        src, dst = a[3] if len(a) > 3 else None, a[7] if len(a) > 7 else None
        if src == player or dst == player:
            if sub.endswith("_DAMAGE") or sub.endswith("_DAMAGE_LANDED") or sub.endswith("_MISSED"):
                out["damageTimes"].append(t)
        if src != player:
            continue
        spell = a[11] if len(a) > 11 else None
        name = a[12] if len(a) > 12 else None
        if sub == "SPELL_CAST_SUCCESS":
            out["casts"].append({"t": t, "spell": spell, "name": name, "dst": dst})
        elif sub == "SPELL_CAST_START":
            out["starts"].append({"t": t, "spell": spell, "name": name})
        elif sub in ("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH", "SPELL_AURA_REMOVED", "SPELL_AURA_APPLIED_DOSE", "SPELL_AURA_REMOVED_DOSE"):
            out["auras"].append({"t": t, "sub": sub, "spell": spell, "name": name, "dst": dst,
                                 "auraType": a[14] if len(a) > 14 else None})
        elif sub in ("SPELL_DAMAGE", "SPELL_HEAL", "SPELL_PERIODIC_DAMAGE", "SPELL_PERIODIC_HEAL", "RANGE_DAMAGE"):
            amt = combatlog.file_amount(e)
            heal = sub.endswith("_HEAL")
            crit = (a[17] if heal else a[20]) if len(a) > (17 if heal else 20) else None
            out["amounts"].append({"t": t, "spell": spell, "amount": amt, "crit": crit in (1, True, "1"), "kind": "heal" if heal else "damage",
                                   "periodic": "PERIODIC" in sub, "dst": dst})
        elif sub == "SPELL_MISSED":
            out["misses"].append({"t": t, "spell": spell, "missType": a[14] if len(a) > 14 else None})
        elif sub == "SPELL_SUMMON":
            # totems/guardians: lifetime = first UNIT_DIED / UNIT_DESTROYED of the summoned GUID after the summon
            end = ends.get(dst)
            out["summons"].append({"t": t, "spell": spell, "name": name, "dst": dst,
                                   "end": end[0] if end and end[0] >= t else None, "endSub": end[1] if end and end[0] >= t else None})
        elif sub in ("SPELL_DISPEL", "SPELL_DISPEL_FAILED", "SPELL_STOLEN"):
            out["dispels"].append({"t": t, "spell": spell, "sub": sub, "dst": dst, "extraSpell": a[14] if len(a) > 14 else None})
    return out


def in_combat(tr, t, pad=6.0):
    import bisect
    d = tr["damageTimes"]
    i = bisect.bisect_left(d, t - pad)
    return i < len(d) and d[i] <= t + pad


# ------------------------------------------------------------------ replay stream
def replay_stream(fx, player, mode="secret", knowledge=None):
    """Forever-observable events + online learning, all in the player's frame of reference.
    mode "secret-pretrained": secret aura fields, but all knowledge (durations/cooldowns/ranges) known up front, like a
    spell-knowledge cache collected out of combat (tooltips) - an upper bound for the rules."""
    if mode == "secret-pretrained":
        evs, tr = replay_stream(fx, player, "secret")
        # tooltip knowledge from the SV (clear, collected out of combat): totem lifetimes, which the file log cannot
        # teach (Forever writes no UNIT_DESTROYED for expiring totems)
        for sid, k in (knowledge or {}).items():
            if k.get("summon") and any(x["spell"] == sid for x in tr["summons"]):
                evs.append({"t": -1, "k": "learn", "spell": sid, "summon": dict(k["summon"])})
        learns = [e for e in evs if e["k"] == "learn"]
        rest = [e for e in evs if e["k"] != "learn"]
        t0 = (rest[0]["t"] if rest else 0) - 1
        merged = {}
        for e in learns:
            m = merged.setdefault(e["spell"], {"t": t0, "k": "learn", "spell": e["spell"]})
            for k, v in e.items():
                if k not in ("t", "k", "spell"):
                    m[k] = v
        return list(merged.values()) + rest, tr
    tr = truth(fx, player)
    ev = []
    iid = 1000
    active = {}            # (dst, spell) -> (iid, appliedT)
    learned_dur, last_cast, learned_cd, amounts = {}, {}, {}, collections.defaultdict(list)
    learned_sum = {}
    harmful = {}
    for e in fx.get("events", []):
        if not e.get("cleu"):
            continue
        a = e["a"]
        sub, t = e["sub"], a[0]
        if (a[3] if len(a) > 3 else None) != player:
            continue
        spell = a[11] if len(a) > 11 else None
        dst = a[7] if len(a) > 7 else None
        unit = "player" if dst == player else (dst or "target")
        if sub == "SPELL_CAST_START":
            ev.append({"t": t, "k": "cast", "ev": "UNIT_SPELLCAST_START", "unit": "player", "spell": spell, "player": True})
        elif sub == "SPELL_CAST_SUCCESS":
            if spell in last_cast:
                gap = t - last_cast[spell]
                # v2.2.2: gaps > 180 s are pauses (the run-2 -> run-3 file spans ~2 h), not cooldowns
                if 1.6 < gap <= 180 and (spell not in learned_cd or gap < learned_cd[spell]):
                    learned_cd[spell] = gap
                    ev.append({"t": t - 1e-6, "k": "learn", "spell": spell, "cooldown": round(gap, 2)})
            last_cast[spell] = t
            tgt = "player" if (dst in (None, "0000000000000000", player)) else dst
            ev.append({"t": t, "k": "cast", "ev": "UNIT_SPELLCAST_SUCCEEDED", "unit": "player", "spell": spell, "player": True, "target": tgt})
        elif sub in ("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH"):
            helpful = (a[14] if len(a) > 14 else "BUFF") == "BUFF"
            harmful[spell] = not helpful
            if sub == "SPELL_AURA_REFRESH" and (dst, spell) in active:
                old = active[(dst, spell)][0]
                ev.append({"t": t, "k": "aura", "unit": unit, "removed": [old]})
            iid += 1
            active[(dst, spell)] = (iid, t)
            ad = {"iid": iid, "helpful": helpful}
            if mode == "clear":
                ad.update({"spellId": spell, "fromPlayer": True})
            ev.append({"t": t + 0.001, "k": "aura", "unit": unit, "added": [ad]})
        elif sub == "SPELL_AURA_REMOVED":
            got = active.pop((dst, spell), None)
            if got:
                ev.append({"t": t, "k": "aura", "unit": unit, "removed": [got[0]]})
                dur = t - got[1]
                if spell not in learned_dur and dur > 1.0:
                    learned_dur[spell] = dur
                    ev.append({"t": t + 1e-6, "k": "learn", "spell": spell,
                               "aura": {"duration": round(dur, 1), "helpful": not harmful.get(spell, False), "self": dst == player}})
        elif sub == "SPELL_SUMMON" and spell is not None:
            sm = next((x for x in tr["summons"] if x["t"] == t and x["dst"] == dst), None)
            if sm and sm.get("end") is not None and spell not in learned_sum:
                learned_sum[spell] = round(sm["end"] - t, 1)
                ev.append({"t": sm["end"] + 1e-6, "k": "learn", "spell": spell, "summon": {"duration": learned_sum[spell]}})
        elif sub in ("SPELL_DAMAGE", "SPELL_HEAL") and spell is not None:
            heal = sub == "SPELL_HEAL"
            amt = combatlog.file_amount(e)
            crit = (a[17] if heal else a[20]) if len(a) > (17 if heal else 20) else None
            if isinstance(amt, (int, float)) and crit not in (1, True, "1"):
                amounts[spell].append(amt)
                ev.append({"t": t + 1e-6, "k": "learn", "spell": spell,
                           "amount": {"min": min(amounts[spell]), "max": max(amounts[spell]), "kind": "heal" if heal else "damage"}})
        ev.append({"t": t + 0.0005, "k": "tick"}) if sub == "SPELL_AURA_REMOVED" else None
    ev.sort(key=lambda x: x["t"])
    return ev, tr


def _lua_value(v):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "{" + ",".join(_lua_value(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ",".join("[%s]=%s" % (json.dumps(str(k)), _lua_value(x)) for k, x in v.items() if x is not None) + "}"
    return "nil"


def run_replay(events, lib=LIB, lua="lua5.1", window=0.6, legacy=False):
    if not shutil.which(lua):
        return None
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as f:
        f.write("return { window = %s, legacy = %s, events = {\n" % (window, "true" if legacy else "nil"))
        for e in events:
            f.write(_lua_value(e) + ",\n")
        f.write("} }\n")
        path = f.name
    try:
        r = subprocess.run([lua, RUNNER, os.path.abspath(lib), path], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(path)
    if r.returncode != 0:
        raise RuntimeError("hsm replay failed: " + r.stderr[-400:])
    return json.loads(r.stdout or "{}")


# ------------------------------------------------------------------ scoring
def _near(lst, t, spell, window, after_only=False, key="spell", pred=None):
    best = None
    for x in lst:
        dt = x["t"] - t
        if after_only and dt < -0.05:
            continue
        if abs(dt) <= window and (spell is None or x.get(key) == spell) and (pred is None or pred(x)):
            if best is None or abs(dt) < abs(best["t"] - t):
                best = x
    return best


def score_predictions(preds, tr, epoch_of=lambda t: t):
    """per prediction: aura presence, duration error, amount within range, cooldown timing error + failure cases"""
    rows = []
    applied = [x for x in tr["auras"] if x["sub"] in ("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH")]
    removed = [x for x in tr["auras"] if x["sub"] == "SPELL_AURA_REMOVED"]
    for p in preds:
        t = epoch_of(p.get("t"))
        if t is None:
            continue
        spell = p.get("spell")
        r = {"t": t, "spell": spell, "unit": p.get("unit"), "ctx": "combat" if in_combat(tr, t) else "ooc", "checks": {}, "failures": []}
        if p.get("aura"):
            hit = _near(applied, t, spell, 1.0, after_only=True)
            c = {"expected": True, "present": bool(hit), "predicted": p["aura"].get("duration")}
            if hit:
                if hit["sub"] == "SPELL_AURA_REFRESH":
                    r["failures"].append("refresh")
                rem = next((x for x in removed if x["spell"] == spell and x["dst"] == hit["dst"] and x["t"] > hit["t"]), None)
                if rem and c["predicted"]:
                    actual = rem["t"] - hit["t"]
                    c["actual"] = round(actual, 2)
                    c["errorSec"] = round(actual - c["predicted"], 2)
                    if actual < c["predicted"] - 1.5:
                        r["failures"].append("removed-early (dispel/cancel/death)")
                    elif actual > c["predicted"] * 1.02 + 0.5:
                        r["failures"].append("pandemic/extension" if actual <= c["predicted"] * 1.3 + 0.5 else "longer-than-predicted")
                    elif abs(actual - c["predicted"]) > 0.5:
                        r["failures"].append("haste/duration-modifier")
            r["checks"]["aura"] = c
        if p.get("amount"):
            am = _near(tr["amounts"], t, spell, 3.0, after_only=True)
            if am:
                lo, hi = p["amount"].get("min"), p["amount"].get("max")
                inside = lo is not None and hi is not None and lo <= am["amount"] <= hi
                r["checks"]["amount"] = {"within": inside, "crit": am["crit"], "periodic": am["periodic"]}
                if am["crit"]:
                    r["failures"].append("crit")
            else:
                miss = _near(tr["misses"], t, spell, 3.0, after_only=True)
                r["checks"]["amount"] = {"within": None, "missed": miss["missType"] if miss else "no-hit-seen"}
                if miss:
                    r["failures"].append("resist/miss:" + str(miss["missType"]))
        if p.get("cooldownEnds"):
            pend = epoch_of(p["cooldownEnds"])
            cd = pend - t if pend is not None else 0
            nxt = next((x for x in tr["casts"] if x["spell"] == spell and x["t"] > t + 0.2), None)
            # v2.2.2: only a recast inside the window (predicted end + max(10 s, cd)) measures the cooldown; a later recast
            # (another session, the spell just not needed) says nothing about it and no longer inflates the mean error
            if nxt and nxt["t"] <= pend + max(10.0, cd):
                err = nxt["t"] - pend
                r["checks"]["cooldown"] = {"recastAfterPredictedEnd": round(err, 2), "contradicted": err < -0.3}
                if err < -0.3:
                    r["failures"].append("recast-before-predicted-cooldown-end (cd reset/haste)")
            else:
                r["checks"]["cooldown"] = {"recastAfterPredictedEnd": None, "contradicted": False, "noRecastInWindow": True}
        if p.get("summon"):
            hit = _near(tr.get("summons") or [], t, spell, 1.0)
            c = {"present": bool(hit), "predicted": p["summon"].get("duration")}
            if hit and hit.get("end") is not None:
                actual = hit["end"] - hit["t"]
                c["actual"], c["endSub"] = round(actual, 2), hit.get("endSub")
                if c["predicted"]:
                    c["errorSec"] = round(actual - c["predicted"], 2)
                    if actual < c["predicted"] - 1.5:
                        r["failures"].append("summon-ended-early (destroyed/replaced/recalled)")
            elif hit:
                c["actual"] = None
            r["checks"]["summon"] = c
        if p.get("dispel"):
            hit = _near(tr.get("dispels") or [], t, spell, 1.5, after_only=True)
            r["checks"]["dispel"] = {"result": hit["sub"] if hit else "nothing-dispelled"}
            if not hit:
                r["failures"].append("dispel: nothing removed (no dispellable effect / resisted)")
        rows.append(r)
    return rows


def summarize_predictions(rows):
    agg = collections.defaultdict(lambda: collections.Counter())
    errs = collections.defaultdict(list)
    fails = collections.Counter()
    for r in rows:
        for kind, c in r["checks"].items():
            k = (kind, r["ctx"])
            agg[k]["n"] += 1
            if kind == "aura":
                agg[k]["ok" if c["present"] else "bad"] += 1
                if "errorSec" in c:
                    errs[k].append(abs(c["errorSec"]))
            elif kind == "amount":
                if c.get("within") is True:
                    agg[k]["ok"] += 1
                elif c.get("within") is False:
                    agg[k]["bad"] += 1
                else:
                    agg[k]["pending"] += 1
            elif kind == "cooldown":
                if c.get("noRecastInWindow"):
                    agg[k]["pending"] += 1
                else:
                    agg[k]["bad" if c["contradicted"] else "ok"] += 1
                    errs[k].append(abs(c["recastAfterPredictedEnd"]))
            elif kind == "summon":
                agg[k]["ok" if c["present"] else "bad"] += 1
                if "errorSec" in c:
                    errs[k].append(abs(c["errorSec"]))
            elif kind == "dispel":
                res = c.get("result")
                agg[k]["ok" if res in ("SPELL_DISPEL", "SPELL_STOLEN") else ("bad" if res == "SPELL_DISPEL_FAILED" else "pending")] += 1
        for f in r["failures"]:
            fails[f] += 1
    out = []
    for (kind, ctx), c in sorted(agg.items()):
        judged = c["ok"] + c["bad"]
        e = errs.get((kind, ctx)) or []
        out.append({"kind": kind, "ctx": ctx, "n": c["n"], "ok": c["ok"], "bad": c["bad"], "pending": c["pending"],
                    "accuracy": round(100.0 * c["ok"] / judged, 1) if judged else None,
                    "meanAbsErrorSec": round(sum(e) / len(e), 2) if e else None})
    return out, dict(fails)


def score_inferences(infs, tr, player, epoch_of=lambda t: t):
    """each inference vs truth: applied/removed aura of that spell, cast start/end of the player"""
    applied = [x for x in tr["auras"] if x["sub"] in ("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH", "SPELL_AURA_APPLIED_DOSE")]
    removed = [x for x in tr["auras"] if x["sub"] == "SPELL_AURA_REMOVED"]
    per = collections.defaultdict(lambda: collections.Counter())
    for i in infs:
        t = epoch_of(i.get("t"))
        if t is None:
            continue
        ctx = "combat" if in_combat(tr, t) else "ooc"
        rule, kind, spell = i.get("rule"), i.get("kind"), i.get("spell")
        ok = None
        if kind == "applied" and spell is not None:
            ok = _near(applied, t, spell, 1.0) is not None
        elif kind == "removed" and spell is not None:
            ok = _near(removed, t, spell, 1.5) is not None
        elif kind == "expired" and spell is not None:
            ok = _near(removed, t, spell, 3.0) is not None
        elif kind in ("cast-start", "cast-end") and str(i.get("unit")) == "player":
            lst = tr["starts"] if kind == "cast-start" else tr["casts"]
            ok = _near(lst, t, spell, 0.6) is not None if (kind == "cast-start" or i.get("outcome") == "succeeded") else None
        c = per[(rule, ctx)]
        c["n"] += 1
        c["ok" if ok else ("bad" if ok is False else "unverifiable")] += 1
    out = []
    for (rule, ctx), c in sorted(per.items(), key=lambda kv: (str(kv[0][0]), kv[0][1])):
        judged = c["ok"] + c["bad"]
        out.append({"rule": rule, "ctx": ctx, "n": c["n"], "ok": c["ok"], "bad": c["bad"], "unverifiable": c["unverifiable"],
                    "accuracy": round(100.0 * c["ok"] / judged, 1) if judged else None})
    return out


def recall(infs, tr, epoch_of=lambda t: t):
    """share of the player's real aura applications that some inference caught"""
    applied = [x for x in tr["auras"] if x["sub"] == "SPELL_AURA_APPLIED"]
    hits = 0
    for x in applied:
        if any(i.get("kind") == "applied" and i.get("spell") == x["spell"] and epoch_of(i.get("t")) is not None
               and abs(epoch_of(i.get("t")) - x["t"]) <= 1.0 for i in infs):
            hits += 1
    return {"applications": len(applied), "caught": hits, "recall": round(100.0 * hits / len(applied), 1) if applied else None}


# ------------------------------------------------------------------ top level
def knowledge_from_dump(dump):
    """{spellId: {"summon": {"duration": s}}} from the SV spell knowledge (parsed tooltips). 2.2.1 SVs parsed a totem's
    lifetime as auraDuration (and a bogus heal from 'health'); 2.2.2 stores parsed.summon/summonDuration."""
    out = {}
    if dump is None:
        return out
    kdb = dump.db.get("knowledge") if isinstance(getattr(dump, "db", None), dict) else None   # ForeverDumpDB.knowledge[build]
    for b in ((kdb or {}).values() if isinstance(kdb, dict) else []):
        if not isinstance(b, dict):
            continue
        for sid, e in ((b or {}).get("spells") or {}).items():
            try:
                sid = int(sid)
            except (TypeError, ValueError):
                continue
            d = (e or {}).get("data") or {}
            p = d.get("parsed") or {}
            name = str(d.get("info.name") or "")
            if p.get("summon") or "Totem" in name:
                dur = p.get("summonDuration") or p.get("auraDuration")
                if dur:
                    out[sid] = {"summon": {"duration": dur, "name": p.get("summonName") or name or None}}
    return out


def analyze(dump=None, fx=None, player=None, modes=("clear", "secret", "secret-pretrained")):
    res = {"player": player, "addon": None, "replay": {}}
    kn = knowledge_from_dump(dump)
    tr = truth(fx, player) if fx and player else None
    inf = (dump.log.get("inference") or {}) if dump else {}
    if inf:
        anc = inf.get("anchor")

        def ep(t):
            e, _ = anchor_epoch(anc, t) if t is not None else (None, False)
            return e
        res["addon"] = {"inputs": inf.get("inputs") or {}, "counters": inf.get("counters"), "appliers": inf.get("appliers"),
                        "player": inf.get("player"), "live": inf.get("contradictions") or []}
        sessions = [h for h in as_list(inf.get("history")) if isinstance(h, dict)] + [inf]
        res["addon"]["sessions"] = len(sessions)
        if tr:
            prows, infs_ep = [], []
            for sess in sessions:
                a_ = sess.get("anchor") or anc

                def ep_s(t, a_=a_):
                    e, _ = anchor_epoch(a_, t) if t is not None else (None, False)
                    return e
                prows += score_predictions(as_list(sess.get("predictions")), tr, ep_s)
                for i in as_list(sess.get("inferences")):
                    if isinstance(i, dict) and i.get("t") is not None:
                        j = dict(i)
                        j["t"] = ep_s(i.get("t"))
                        infs_ep.append(j)
            res["addon"]["predictions"], res["addon"]["failures"] = summarize_predictions(prows)
            res["addon"]["rules"] = score_inferences(infs_ep, tr, player)
            res["addon"]["recall"] = recall(infs_ep, tr)
            res["addon"]["sample"] = prows[:40]
    if fx and player:
        for mode in modes:
            evs, _ = replay_stream(fx, player, mode, kn)
            out = run_replay(evs)
            if out is None:
                res["replay"][mode] = {"skipped": "lua5.1 not found"}
                continue
            prows = score_predictions(out.get("predictions") or [], tr)
            preds, fails = summarize_predictions(prows)
            res["replay"][mode] = {"events": len(evs), "counters": out.get("counters"), "predictions": preds, "failures": fails,
                                   "rules": score_inferences(out.get("inferences") or [], tr, player),
                                   "recall": recall(out.get("inferences") or [], tr),
                                   "contradictions": len(out.get("contradictions") or []), "sample": prows[:40]}
        res["truth"] = {"casts": len(tr["casts"]), "starts": len(tr["starts"]), "auras": len(tr["auras"]), "amounts": len(tr["amounts"]),
                        "misses": len(tr["misses"]), "summons": len(tr["summons"]),
                        "summonsWithEnd": sum(1 for x in tr["summons"] if x.get("end") is not None), "dispels": len(tr["dispels"])}
    return res


def _pct(v):
    return "-" if v is None else "%.1f%%" % v


def inference_markdown(res):
    out = ["# Inference lab report", "",
           "Each rule: were its inputs readable per context (addon capture), did its inference match the ground truth",
           "(WoWCombatLog file, offline), accuracy. Inference uses only values the API reported non-secret plus event timing.", ""]
    if res.get("player"):
        out.append("Ground truth player: `%s` (log owner, unit flags 0x511). Truth counts: %s" % (res["player"], res.get("truth")))
        out.append("")
    a = res.get("addon")
    if a:
        out += ["## Rule inputs (addon capture): readable / unreadable per context", "", "| signal | " + " | ".join(sorted(a["inputs"])) + " |",
                "|---|" + "---|" * len(a["inputs"])]
        sigs = sorted({s for byS in a["inputs"].values() for s in byS})
        for s in sigs:
            out.append("| %s | %s |" % (s, " | ".join("%s/%s" % ((a["inputs"][c].get(s) or {}).get("r", 0), (a["inputs"][c].get(s) or {}).get("u", 0))
                                                     for c in sorted(a["inputs"]))))
        out.append("")
        if a.get("rules"):
            out += ["## Addon inferences vs truth", ""] + _rule_table(a["rules"]) + ["", "Recall (real applications caught): %s" % a.get("recall"), ""]
    else:
        out += ["_no addon inference data in this SV (v2.2 FD_Logs records it); offline replay below uses the file log only._", ""]
    for mode, r in (res.get("replay") or {}).items():
        out += ["## Offline replay (%s mode)" % mode, ""]
        if r.get("skipped"):
            out += [r["skipped"], ""]
            continue
        out += _rule_table(r["rules"]) + ["", "Recall: %s; live contradictions: %s" % (r["recall"], r["contradictions"]), ""]
    return "\n".join(out) + "\n"


def _rule_table(rows):
    out = ["| rule | context | inferences | matched | wrong | unverifiable | accuracy |", "|---|---|---|---|---|---|---|"]
    for r in rows:
        out.append("| %s | %s | %d | %d | %d | %d | %s |" % (r["rule"], r["ctx"], r["n"], r["ok"], r["bad"], r["unverifiable"], _pct(r["accuracy"])))
    return out


def hsm_markdown(res):
    out = ["# Hybrid state machine (HSM) - predictions vs ground truth", "",
           "Per prediction kind and context: aura presence %, duration error, damage/heal within the predicted range %,",
           "cooldown timing error; then the failure cases. The library is ForeverDump/Lib/HybridState.lua (reusable).", ""]

    def table(preds, fails):
        o = ["| check | context | n | ok | wrong | pending | accuracy | mean abs error (s) |", "|---|---|---|---|---|---|---|---|"]
        for p in preds:
            o.append("| %s | %s | %d | %d | %d | %d | %s | %s |" % (p["kind"], p["ctx"], p["n"], p["ok"], p["bad"], p["pending"], _pct(p["accuracy"]),
                                                                    "-" if p["meanAbsErrorSec"] is None else p["meanAbsErrorSec"]))
        o += ["", "Failure cases: " + (", ".join("%s x%d" % kv for kv in sorted(fails.items(), key=lambda kv: -kv[1])) or "none"), ""]
        return o
    a = res.get("addon")
    if a and a.get("predictions") is not None:
        out += ["## Live HSM (addon capture)", ""] + table(a["predictions"], a.get("failures") or {})
    for mode, r in (res.get("replay") or {}).items():
        if r.get("skipped"):
            continue
        how = ("spell knowledge given up front, as if cached out of combat by Knowledge.lua" if mode.endswith("pretrained")
               else "knowledge learned online while values were readable")
        out += ["## Offline replay on the file log (%s mode, %d events, %s)" % (mode, r["events"], how), ""]
        out += table(r["predictions"], r["failures"])
    out += ["Notes: only the log owner's casts and auras are known in a file log; in Forever, UNIT_AURA only fires for unit",
            "tokens (player/target/focus/party/nameplates), so the replay is an upper bound for other units.", ""]
    return "\n".join(out) + "\n"


def _guide_rows(rule_rows, pred_rows, origin, prefix=""):
    rules = []
    for r in rule_rows:
        judged = r["ok"] + r["bad"]
        st = "pending" if judged == 0 else ("verified" if r["bad"] == 0 or (r["accuracy"] or 0) >= 90 else "failing")
        rules.append({"id": prefix + str(r["rule"]), "context": r["ctx"], "predictions": r["n"], "verified": r["ok"],
                      "contradicted": r["bad"], "pending": r["unverifiable"], "status": st, "source": origin})
    for p in pred_rows:
        judged = p["ok"] + p["bad"]
        st = "pending" if judged == 0 else ("verified" if (p["accuracy"] or 0) >= 90 else "failing")
        row = {"id": prefix + "hsm-" + p["kind"], "context": p["ctx"], "predictions": p["n"], "verified": p["ok"],
               "contradicted": p["bad"], "pending": p["pending"], "status": st, "source": origin}
        if p.get("meanAbsErrorSec") is not None:
            row["meanErrorSec"] = p["meanAbsErrorSec"]
        rules.append(row)
    return rules


def _guide_sample(rows, prefix=""):
    sample = []
    for r in rows:
        for kind, c in r["checks"].items():
            outcome, err = "unverified", None
            if kind == "aura":
                outcome = "verified" if c["present"] else "contradicted"
                err = c.get("errorSec")
            elif kind == "amount" and c.get("within") is not None:
                outcome = "verified" if c["within"] else "contradicted"
            elif kind == "cooldown":
                if c.get("noRecastInWindow"):
                    outcome = "unverified"
                else:
                    outcome = "contradicted" if c["contradicted"] else "verified"
                    err = c["recastAfterPredictedEnd"]
            elif kind == "summon":
                outcome = "verified" if c["present"] else "contradicted"
                err = c.get("errorSec")
            elif kind == "dispel":
                outcome = {"SPELL_DISPEL": "verified", "SPELL_STOLEN": "verified", "SPELL_DISPEL_FAILED": "contradicted"}.get(c.get("result"), "unverified")
            x = {"t": r["t"], "unit": "player" if r.get("unit") == "player" else "other", "spell": r["spell"], "kind": kind,
                 "rule": prefix + "hsm-" + kind, "conf": "high" if kind != "amount" else "medium", "outcome": outcome}
            if err is not None:
                x["errorSec"] = err
            sample.append(x)
    return sample


GUIDE_REPLAY_MODES = ("secret-pretrained", "secret", "clear")


def hsm_guide_json(res, build=None, captured=None):
    """schema foreverdump.hsm/1 (guide --hsm). rules = live addon rows (ids = HybridState rule names) followed by the offline
    file-log replay rows (ids prefixed 'replay:'; mode: secret-pretrained = only values the API reports as non-secret in
    combat + spell knowledge cached out of combat). Extra keys 'source'/'replayMode' are informational."""
    rules, sample, sources = [], [], []
    src = res.get("addon") if (res.get("addon") or {}).get("rules") else None
    if src:
        rules += _guide_rows(src.get("rules") or [], src.get("predictions") or [], "addon")
        sample += _guide_sample(src.get("sample") or [])
        sources.append("addon")
    mode = next((m for m in GUIDE_REPLAY_MODES if (res.get("replay") or {}).get(m)), None)
    if mode:
        r = res["replay"][mode]
        rules += _guide_rows(r.get("rules") or [], r.get("predictions") or [], "replay:" + mode, "replay:")
        sample += _guide_sample(r.get("sample") or [], "replay:")
        sources.append("replay:" + mode)
    return {"schema": "foreverdump.hsm/1", "build": build, "captured": captured, "source": "+".join(sources) or "none",
            "replayMode": mode, "rules": rules, "inputs": ((res.get("addon") or {}).get("inputs")) or {}, "predictions": sample[:40]}
