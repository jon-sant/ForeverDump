"""v2.2.5 higher-order correlation: chains A->B->C, sequences/timing, identity joins, elimination.

Profiles: "full" (default, heavy post-analysis -- no wall-clock cap) and "quick" (fast iteration).
Composes high-lift 1-hop edges from correlate.mine with beam search (depth <= 3, or 4 where cheap),
scores end-to-end against a shuffled-time null (many circular shifts), and holdouts across captures.
Proposed live HSM rules are for review only (not auto-enabled).
"""
import bisect
import collections
import re
import statistics
import time

from fdump.correlate import _index, _min_dt, _base, _idmatch, durations

HO_PROFILES = {
    "full": {
        "max_depth": 4, "beam": 120, "edge_cap": 800, "chain_cap": 200,
        "min_support": 2, "min_lift": 2.5,
        "windows": (0.05, 0.15, 0.3, 0.75, 1.5), "shuffles": 24,
        "seq_top": 40, "ident_top": 40, "elim_top": 20,
    },
    "quick": {
        "max_depth": 3, "beam": 40, "edge_cap": 200, "chain_cap": 60,
        "min_support": 2, "min_lift": 3.0,
        "windows": (0.05, 0.15, 0.3), "shuffles": 8,
        "seq_top": 15, "ident_top": 15, "elim_top": 8,
    },
}


def _near_any(ts, t, w, forward=False):
    m = _min_dt(ts, t, forward=forward)
    if m is None:
        return None
    if forward:
        return m if 0 <= m <= w else None
    return m if abs(m) <= w else None


def _compatible(a, b):
    if a == b:
        return True
    if a.startswith(b + "|") or b.startswith(a + "|"):
        return True
    if _base(a) != _base(b):
        return False
    if "=" not in a and "=" not in b:
        return True
    return _idmatch(a, b)


def _edge_score(r):
    return (r.get("support", 0) + r.get("supportB", 0)) * min(float(r.get("lift") or 1), 50) * float(r.get("precision") or 0)


def _select_edges(rules, rare, edge_cap, min_lift):
    out = []
    for r in list(rules) + list(rare or []):
        if r.get("kind") == "truth->truth":
            continue
        if (r.get("lift") or 0) < min_lift and not r.get("idMatch") and not r.get("rare"):
            continue
        if r.get("known") in ("ui echo", "log structure", "health side effect"):
            continue
        out.append(r)
    out.sort(key=lambda r: (-_edge_score(r), not r.get("idMatch"), r.get("known") is not None))
    return out[:edge_cap]


def _score_path(keys, windows, ia, forward_flags, L, shuffles, combat):
    if not keys or any(k not in ia or not ia[k] for k in keys):
        return None
    src, dst = ia[keys[0]], ia[keys[-1]]
    na, nb = len(src), len(dst)
    if na == 0 or nb == 0:
        return None

    def walk_from(t0):
        t = t0
        for i, k in enumerate(keys[1:]):
            w = windows[min(i, len(windows) - 1)]
            fw = forward_flags[min(i, len(forward_flags) - 1)] if forward_flags else False
            m = _near_any(ia[k], t, w, forward=fw)
            if m is None:
                return None
            t = t + m
        return t

    hits, lags, fight_ids = [], [], set()
    for t0 in src:
        tend = walk_from(t0)
        if tend is None:
            continue
        hits.append(t0)
        lags.append(tend - t0)
        fight_ids.add(next((i for i, (c0, c1) in enumerate(combat or []) if c0 - 1 <= t0 <= c1 + 1), "ooc"))
    if not hits:
        return None
    wtot = sum(windows[:max(1, len(keys) - 1)]) if windows else 0.05
    wlast = windows[-1] if windows else 0.05
    reached = 0
    for tb in dst:
        j = bisect.bisect_left(src, tb)
        cands = []
        if j > 0:
            cands.append(src[j - 1])
        if j < len(src):
            cands.append(src[j])
        if j + 1 < len(src):
            cands.append(src[j + 1])
        got = False
        for t0 in cands:
            if abs(t0 - tb) > wtot + wlast:
                continue
            tend = walk_from(t0)
            if tend is not None and abs(tend - tb) <= wlast:
                got = True
                break
        if got:
            reached += 1
    prec = len(hits) / float(na)
    rec = reached / float(nb)
    null_precs = []
    span = max(L, 1e-6)
    nshuf = max(1, int(shuffles))
    for s_i in range(1, nshuf + 1):
        shift = (span * s_i) / float(nshuf + 1)
        n_hit = sum(1 for t0 in src if walk_from(t0 + shift) is not None)
        null_precs.append(n_hit / float(na))
    null_p = statistics.mean(null_precs) if null_precs else 0.0
    from fdump.correlate_findings import smooth_lift
    lift, lift_lo, lift_hi = smooth_lift(prec, null_p, na)
    return {
        "support": len(hits), "nA": na, "nB": nb, "supportB": reached,
        "precision": round(prec, 3), "recall": round(rec, 3),
        "lift": lift, "liftLo": lift_lo, "liftHi": lift_hi, "nullA": round(null_p, 4),
        "lagMedian": round(statistics.median(lags), 3) if lags else 0.0,
        "fights": len(fight_ids), "provisional": len(fight_ids) <= 1,
        "times": hits[:12],
    }


def _plain(chain):
    hops = chain["hops"]
    kind = chain.get("pattern", "chain")
    a, c = hops[0], hops[-1]
    mid = hops[1:-1]

    def short(k):
        return k.replace("|", " / ")

    if kind == "identity":
        reason = ("the same unit is visible on several tokens at once; when those views agree in the same frame "
                  "and my cast also lands, the secret source on one token is the clear identity on another "
                  "(%s -> %s -> %s)" % (short(a), " -> ".join(short(m) for m in mid) or "...", short(c)))
        rule = ("IdentityJoin: when UNIT_SPELLCAST_INTERRUPTED fires on target/nameplate/softenemy in the same frame as "
                "UNIT_SPELLCAST_SUCCEEDED|player with a matching spell id, attribute the interrupt to me.")
    elif kind == "elimination":
        reason = ("a live hit on my target has no matching own-cast frame and no DamageMeter update in that frame, "
                  "so after subtracting what I can claim the remainder is someone else (%s -> %s)" % (short(a), short(c)))
        rule = ("Elimination: UNIT_COMBAT damage on target with no my-cast and no DAMAGE_METER update in-frame -> src=other; "
                "reconcile post-combat as live total - C_DamageMeter mine.")
    elif kind == "sequence":
        reason = ("ordered timing: %s then %s within %.0f ms (learned lag median %.3f s)"
                  % (short(a), short(c), (chain.get("windows") or [0.15])[0] * 1000, chain.get("lagMedian") or 0))
        rule = ("Sequence: watch %s; expect %s within %.0f ms (or treat absence as the opposite signal)."
                % (short(a), short(c), (chain.get("windows") or [0.15])[0] * 1000))
    elif kind == "absence":
        reason = ("expected follow-up %s did not fire after %s inside the window -- absence itself is the signal"
                  % (short(c), short(a)))
        rule = ("Absence: after %s, if %s is missing within %.0f ms, record the negative evidence."
                % (short(a), short(c), (chain.get("windows") or [0.15])[0] * 1000))
    else:
        via = (" via " + " -> ".join(short(m) for m in mid)) if mid else ""
        reason = ("%s links%s to ground truth %s (end-to-end precision %s, lift %s vs shuffled-time null)"
                  % (short(a), via, short(c), chain.get("precision"), chain.get("lift")))
        rule = ("Chain: on %s, look for %s within the hop windows, then treat %s as the meaning "
                "(proposed only -- enable after holdout review)."
                % (short(a), " / ".join(short(m) for m in mid) or "(direct)", short(c)))
    blob = " || ".join(hops)
    if "INTERRUPTED" in blob and ("8046" in blob or "INTERRUPT" in c or "INTERRUPT" in blob):
        reason = ("target cast interrupted (secret interrupter) + my Earth Shock SUCCEEDED in the same frame "
                  "-> the interrupt was mine")
        rule = ("InterruptAttribution: UNIT_SPELLCAST_INTERRUPTED on target/nameplate/softenemy in the same frame as "
                "UNIT_SPELLCAST_SUCCEEDED|player (interrupt spell) -> src=mine; confirm with DAMAGE_METER type-5 if present.")
    if "DAMAGE_METER" in blob and "UNIT_COMBAT" in blob and kind != "elimination":
        reason = ("DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick "
                  "(and without my cast) are someone else's -- subtract to recover others-on-target")
        rule = ("MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit "
                "as mine-or-group; absence + no own cast -> other (elimination).")
    return reason, rule


def _compose_chains(edges, ia_live, ia_truth, span, combat, cfg):
    lo, hi = span
    L = max(1e-6, (hi or 0) - (lo or 0))
    ll = [e for e in edges if e["kind"] == "live->live"]
    lt = [e for e in edges if e["kind"] == "live->truth"]
    lt_by, ll_by = collections.defaultdict(list), collections.defaultdict(list)
    for e in lt:
        lt_by[e["a"]].append(e)
        lt_by[_base(e["a"])].append(e)
    for e in ll:
        ll_by[e["a"]].append(e)
        ll_by[_base(e["a"])].append(e)
    chains, seen = [], set()

    def add_chain(hops, windows, pattern="chain"):
        key = tuple(hops)
        if key in seen:
            return
        ia = {}
        for h in hops[:-1]:
            if h not in ia_live:
                return
            ia[h] = ia_live[h]
        if hops[-1] not in ia_truth and hops[-1] not in ia_live:
            return
        ia[hops[-1]] = ia_truth.get(hops[-1]) or ia_live[hops[-1]]
        sc = _score_path(hops, windows, ia, [False] * (len(hops) - 1), L, cfg["shuffles"], combat)
        if not sc or sc["support"] < cfg["min_support"]:
            return
        if sc["lift"] < cfg["min_lift"] and pattern == "chain" and sc["precision"] < 0.8:
            return
        seen.add(key)
        chain = {"hops": list(hops), "windows": list(windows), "pattern": pattern, "depth": len(hops) - 1,
                 "kind": "live->truth" if hops[-1] in ia_truth else "live->live", **sc}
        chain["reason"], chain["proposedRule"] = _plain(chain)
        chains.append(chain)

    ll_beam = sorted(ll, key=_edge_score, reverse=True)[:cfg["beam"]]
    lt_beam = sorted(lt, key=_edge_score, reverse=True)[:cfg["beam"]]
    for e1 in ll_beam:
        for e2 in lt_beam:
            if not _compatible(e1["b"], e2["a"]):
                continue
            mid = e2["a"] if e2["a"] in ia_live else e1["b"]
            if e1["a"] not in ia_live or mid not in ia_live or e2["b"] not in ia_truth:
                continue
            add_chain([e1["a"], mid, e2["b"]], [e1.get("window", 0.05), e2.get("window", 0.05)])

    if cfg["max_depth"] >= 3:
        for e1 in ll_beam[:max(20, cfg["beam"] // 2)]:
            bridges = (ll_by.get(e1["b"], []) + ll_by.get(_base(e1["b"]), []))[:16]
            for e2 in bridges:
                if e2 is e1 or not _compatible(e1["b"], e2["a"]):
                    continue
                sinks = (lt_by.get(e2["b"], []) + lt_by.get(_base(e2["b"]), []))[:16]
                for e3 in sinks:
                    if not _compatible(e2["b"], e3["a"]):
                        continue
                    mid1 = e1["b"] if e1["b"] in ia_live else e2["a"]
                    mid2 = e3["a"] if e3["a"] in ia_live else e2["b"]
                    if e1["a"] not in ia_live or mid1 not in ia_live or mid2 not in ia_live or e3["b"] not in ia_truth:
                        continue
                    add_chain([e1["a"], mid1, mid2, e3["b"]],
                              [e1.get("window", 0.05), e2.get("window", 0.05), e3.get("window", 0.05)])

    if cfg["max_depth"] >= 4:
        seeds = [e for e in ll_beam if e.get("idMatch") or any(x in e["a"] + e["b"] for x in
                 ("SPELLCAST", "INTERRUPT", "DAMAGE_METER", "UNIT_COMBAT"))][:40]
        for e1 in seeds:
            for e2 in ll_by.get(e1["b"], [])[:6]:
                if not _compatible(e1["b"], e2["a"]):
                    continue
                for e3 in ll_by.get(e2["b"], [])[:4]:
                    if not _compatible(e2["b"], e3["a"]):
                        continue
                    for e4 in (lt_by.get(e3["b"], []) + lt_by.get(_base(e3["b"]), []))[:6]:
                        if not _compatible(e3["b"], e4["a"]):
                            continue
                        hops = [e1["a"], e1["b"], e2["b"], e4["a"], e4["b"]]
                        hops2 = [hops[0]]
                        for h in hops[1:]:
                            if h != hops2[-1]:
                                hops2.append(h)
                        if len(hops2) < 4 or hops2[-1] not in ia_truth:
                            continue
                        if any(h not in ia_live for h in hops2[:-1]):
                            continue
                        add_chain(hops2, [0.05] * (len(hops2) - 1))

    chains.sort(key=lambda c: (-c["lift"] * c["support"], -c["precision"], c["depth"]))
    return chains[:cfg["chain_cap"]]


def _identity_joins(c, cfg):
    ia, it = _index(c["lf"]), _index(c["tf"])
    lo, hi = c["span"]
    L = max(1e-6, (hi or 0) - (lo or 0))
    out = []
    inter_keys = [k for k in ia if k.startswith("UNIT_SPELLCAST_INTERRUPTED|")]
    my_succ = [k for k in ia if k.startswith("UNIT_SPELLCAST_SUCCEEDED|player")]
    truth_int = [k for k in it if k.startswith("SPELL_INTERRUPT|")]
    for ik in inter_keys:
        for mk in my_succ:
            for tk in truth_int:
                ia_combo = {ik: ia[ik], mk: ia[mk], tk: it[tk]}
                sc = _score_path([ik, mk, tk], [0.05, 0.05], ia_combo, [False, False], L, cfg["shuffles"], c["combat"])
                if not sc or sc["support"] < 1:
                    continue
                chain = {"hops": [ik, mk, tk], "windows": [0.05, 0.05], "pattern": "identity", "depth": 2,
                         "kind": "live->truth", "idMatch": _idmatch(mk, tk), **sc}
                chain["reason"], chain["proposedRule"] = _plain(chain)
                out.append(chain)
    for i, a in enumerate(inter_keys):
        for b in inter_keys[i + 1:]:
            if a.split("|")[0] != b.split("|")[0]:
                continue
            for mk in my_succ[:4]:
                for tk in truth_int[:4]:
                    ia_combo = {a: ia[a], b: ia[b], mk: ia[mk], tk: it[tk]}
                    sc = _score_path([a, b, mk, tk], [0.05, 0.05, 0.05], ia_combo, [False, False, False],
                                     L, cfg["shuffles"], c["combat"])
                    if not sc or sc["support"] < 1:
                        continue
                    chain = {"hops": [a, b, mk, tk], "windows": [0.05, 0.05, 0.05], "pattern": "identity",
                             "depth": 3, "kind": "live->truth", "idMatch": _idmatch(mk, tk), **sc}
                    chain["reason"], chain["proposedRule"] = _plain(chain)
                    out.append(chain)
    for d in durations(c["live"], c["lf"]):
        if not d.get("consistent") or d["n"] < 2:
            continue
        chain = {"hops": [d["from"], d["to"]], "windows": [min(1.5, max(0.05, d["median"] * 1.5))],
                 "pattern": "sequence", "depth": 1, "kind": "live->live",
                 "support": d["n"], "nA": d["n"], "nB": d["n"], "supportB": d["n"],
                 "precision": 1.0, "recall": 1.0, "lift": 99.0, "nullA": 0.0,
                 "lagMedian": d["median"], "fights": 1, "provisional": True, "npc": d.get("npc"), "times": []}
        chain["reason"], chain["proposedRule"] = _plain(chain)
        out.append(chain)
    out.sort(key=lambda c: (-(c.get("lift") or 0) * (c.get("support") or 0), -(c.get("precision") or 0)))
    return out[:cfg["ident_top"]]


def _sequences(c, edges, cfg):
    ia, it = _index(c["lf"]), _index(c["tf"])
    lo, hi = c["span"]
    L = max(1e-6, (hi or 0) - (lo or 0))
    out = []
    for e in edges:
        if e.get("kind") not in ("live->truth", "live->live"):
            continue
        if abs(e.get("lagMedian") or 0) < 0.02 and e.get("window", 0) <= 0.05:
            continue
        src = ia if e["kind"].startswith("live") else it
        dst = it if e["kind"].endswith("truth") else ia
        if e["a"] not in src or e["b"] not in dst:
            continue
        sc = _score_path([e["a"], e["b"]], [e.get("window", 0.15)],
                         {e["a"]: src[e["a"]], e["b"]: dst[e["b"]]}, [True], L, cfg["shuffles"], c["combat"])
        if not sc or sc["support"] < cfg["min_support"]:
            continue
        chain = {"hops": [e["a"], e["b"]], "windows": [e.get("window", 0.15)], "pattern": "sequence",
                 "depth": 1, "kind": e["kind"], **sc}
        chain["reason"], chain["proposedRule"] = _plain(chain)
        out.append(chain)
        miss = sc["nA"] - sc["support"]
        if miss >= cfg["min_support"] and miss / float(sc["nA"]) >= 0.5:
            anti = {"hops": [e["a"], e["b"]], "windows": [e.get("window", 0.15)], "pattern": "absence",
                    "depth": 1, "kind": e["kind"], "support": miss, "nA": sc["nA"], "nB": sc["nB"], "supportB": 0,
                    "precision": round(miss / float(sc["nA"]), 3), "recall": 0.0,
                    "lift": round((miss / float(sc["nA"])) / max(1.0 - sc["precision"], 1e-3), 1),
                    "nullA": round(1.0 - sc["precision"], 4), "lagMedian": e.get("lagMedian") or 0,
                    "fights": sc["fights"], "provisional": sc["provisional"], "times": []}
            anti["reason"], anti["proposedRule"] = _plain(anti)
            out.append(anti)
    out.sort(key=lambda c: (-(c.get("lift") or 0) * (c.get("support") or 0), -(c.get("precision") or 0)))
    return out[:cfg["seq_top"]]


def _elimination(c, cfg):
    ia, it = _index(c["lf"]), _index(c["tf"])
    lo, hi = c["span"]
    L = max(1e-6, (hi or 0) - (lo or 0))
    out = []
    uc = [k for k in ia if k.startswith("UNIT_COMBAT|target") and ("WOUND" in k or k.count("|") == 1)]
    my_cast = [k for k in ia if k.startswith("UNIT_SPELLCAST_SUCCEEDED|player")]
    dm = [k for k in ia if k.startswith("DAMAGE_METER_COMBAT_SESSION_UPDATED")]
    other_dmg = [k for k in it if "SPELL_DAMAGE|player>" in k or "SWING_DAMAGE|player>" in k]
    mine_dmg = [k for k in it if k.startswith("SPELL_DAMAGE|me>") or k.startswith("SWING_DAMAGE|me>")]
    if not uc:
        return out
    my_ts = sorted({t for k in my_cast for t in ia[k]})
    dm_ts = sorted({t for k in dm for t in ia[k]})
    for uk in uc[:8]:
        elim_ts = [t for t in ia[uk]
                   if _near_any(my_ts, t, 0.05) is None and _near_any(dm_ts, t, 0.05) is None]
        if elim_ts and other_dmg:
            for tk in other_dmg[:12]:
                ia_combo = {"ELIM|" + uk: elim_ts, tk: it[tk]}
                sc = _score_path(["ELIM|" + uk, tk], [0.15], ia_combo, [False], L, cfg["shuffles"], c["combat"])
                if not sc or sc["support"] < 1:
                    continue
                chain = {"hops": ["ELIM(no my-cast, no DM):" + uk, tk], "windows": [0.15], "pattern": "elimination",
                         "depth": 2, "kind": "live->truth", **sc}
                chain["reason"], chain["proposedRule"] = _plain(chain)
                out.append(chain)
        join_ts = [t for t in ia[uk] if _near_any(dm_ts, t, 0.05) is not None]
        if join_ts and mine_dmg:
            for tk in mine_dmg[:8]:
                ia_combo = {"DMJOIN|" + uk: join_ts, tk: it[tk]}
                sc = _score_path(["DMJOIN|" + uk, tk], [0.05], ia_combo, [False], L, cfg["shuffles"], c["combat"])
                if not sc or sc["support"] < cfg["min_support"]:
                    continue
                chain = {"hops": ["DMJOIN:" + uk + "+DAMAGE_METER", tk], "windows": [0.05], "pattern": "chain",
                         "depth": 2, "kind": "live->truth", **sc}
                chain["reason"], chain["proposedRule"] = _plain(chain)
                out.append(chain)
    out.sort(key=lambda c: (-(c.get("lift") or 0) * (c.get("support") or 0), -(c.get("precision") or 0)))
    return out[:cfg["elim_top"]]


def higher_order(c, rules, rare, profile="full"):
    cfg = dict(HO_PROFILES.get(profile) or HO_PROFILES["full"])
    t0 = time.time()
    edges = _select_edges(rules, rare, cfg["edge_cap"], cfg["min_lift"])
    ia_live, ia_truth = _index(c["lf"]), _index(c["tf"])
    allc = (_compose_chains(edges, ia_live, ia_truth, c["span"], c["combat"], cfg)
            + _identity_joins(c, cfg) + _sequences(c, edges, cfg) + _elimination(c, cfg))
    uniq, seen = [], set()
    for ch in allc:
        k = (ch["pattern"], tuple(ch["hops"]))
        if k in seen:
            continue
        seen.add(k)
        uniq.append(ch)
    # Prefer identity / elimination even at support=1 (smoothed lift no longer inflates them to 9999)
    def _rank(c):
        pri = 0 if c.get("pattern") in ("identity", "elimination") else 1
        return (pri, -(c.get("lift") or 0) * (c.get("support") or 0), -(c.get("precision") or 0), c.get("depth", 9))
    uniq.sort(key=_rank)
    # Always keep all identity/elim, then fill with other chains up to cap
    special = [c for c in uniq if c.get("pattern") in ("identity", "elimination")]
    other = [c for c in uniq if c.get("pattern") not in ("identity", "elimination")]
    cap = cfg["chain_cap"] + cfg["ident_top"]
    kept = special + other[: max(0, cap - len(special))]
    return {"chains": kept[:cap + cfg.get("elim_top", 20)], "profile": profile, "edgesUsed": len(edges),
            "elapsedSec": round(time.time() - t0, 3),
            "config": {k: (list(v) if isinstance(v, tuple) else v) for k, v in cfg.items()}}


def holdout_chain(chain, c):
    ia_live, ia_truth = _index(c["lf"]), _index(c["tf"])
    ia = {}
    for h in chain["hops"]:
        if h.startswith("ELIM") or h.startswith("DMJOIN"):
            return {"status": "absent", "nA": 0, "reason": "synthetic-key"}
        if h in ia_live:
            ia[h] = ia_live[h]
        elif h in ia_truth:
            ia[h] = ia_truth[h]
        else:
            return {"status": "absent", "nA": 0}
    lo, hi = c["span"]
    L = max(1e-6, (hi or 0) - (lo or 0))
    fw = [True] * (len(chain["hops"]) - 1) if chain.get("pattern") == "sequence" else [False] * (len(chain["hops"]) - 1)
    sc = _score_path(chain["hops"], chain.get("windows") or [0.05] * (len(chain["hops"]) - 1),
                     ia, fw, L, 4, c["combat"])
    if not sc:
        return {"status": "absent", "nA": 0}
    held = sc["precision"] >= 0.5 * (chain.get("precision") or 0) and sc["support"] > 0
    return {"status": "held" if held else "failed", "nA": sc["nA"], "support": sc["support"],
            "precision": sc["precision"]}


def find_chains(res, *rxs, patterns=None):
    out = []
    for ch in res.get("higher") or []:
        if patterns and ch.get("pattern") not in patterns:
            continue
        hops = ch.get("hops") or []
        if len(rxs) == 1:
            if any(re.search(rxs[0], h) for h in hops):
                out.append(ch)
            continue
        if len(rxs) <= len(hops):
            i, ok = 0, True
            for rx in rxs:
                while i < len(hops) and not re.search(rx, hops[i]):
                    i += 1
                if i >= len(hops):
                    ok = False
                    break
                i += 1
            if ok:
                out.append(ch)
        else:
            blob = " || ".join(hops)
            if all(re.search(rx, blob) for rx in rxs):
                out.append(ch)
    return out


def markdown_higher(res, top=30):
    hs = res.get("higher") or []
    if not hs:
        return ["", "## Higher-order leads (v2.2.5)", "",
                "No chains mined (enable higher-order; profile full|quick).", ""]
    L = ["", "## Higher-order leads (v2.2.5)", "",
         "Chains A->B->C (depth <= 4), sequences/timing, identity joins (multi-token same-frame), and elimination "
         "(my casts + meter totals subtracted from what is seen). Each row is plain-words reasoning plus a **proposed** "
         "live HSM rule (review only -- not auto-enabled). Holdout = re-score on the other captures; provisional = one fight.",
         "",
         "| # | capture | pattern | depth | hops | support | prec | lift | flags | holdout |",
         "|---|---|---|---|---|---|---|---|---|---|"]
    for i, ch in enumerate(hs[:top], 1):
        hops = " -> ".join("`%s`" % h for h in ch["hops"])
        flags = ",".join(x for x in ("provisional" if ch.get("provisional") else "",
                                     "id-match" if ch.get("idMatch") else "", ch.get("pattern") or "") if x)
        ho = "; ".join("%s:%s" % (k, v.get("status")) for k, v in (ch.get("holdout") or {}).items()) or "-"
        L.append("| %d | %s | %s | %d | %s | %d/%d | %s | %s | %s | %s |" % (
            i, ch.get("capture"), ch.get("pattern"), ch.get("depth", 0), hops, ch.get("support", 0), ch.get("nA", 0),
            ch.get("precision"), ch.get("lift"), flags, ho))
    L += ["", "### Reasoning and proposed rules", ""]
    for i, ch in enumerate(hs[:top], 1):
        L += ["**%d. [%s / %s]** %s" % (i, ch.get("capture"), ch.get("pattern"), ch.get("reason") or ""),
              "", "> proposed: %s" % (ch.get("proposedRule") or ""), ""]
    return L
