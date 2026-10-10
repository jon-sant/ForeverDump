"""v2.2.4/v2.2.5 generic co-occurrence miner (data-driven, no hand-written rules).

Features
  live:  <EVENT>|<token class>            (L0) and <EVENT>|<token class>|<argN>=<clear value> (L1, low-cardinality positions only),
         payload tables contribute <EVENT>|<tok>|<argN>.has=<field> (key presence is readable even when the table is secret)
  truth: <SUB>|<src>><dst>               (T0) and <SUB>|<src>><dst>|spell=<id> (T1); classes me / mine / npc / player / none
Associations (1-hop)
  live->truth  (|dt| <= w)               what does a live signal mean in reality
  live->live   (|dt| <= w, A != B)       which live signals travel together (e.g. my Earth Shock SUCCEEDED + target INTERRUPTED)
  truth->truth (0 <= dt <= w, A != B)    log-only structure (cast -> aura id mappings)
  windows 50 / 150 / 300 / 750 ms. support = A occurrences with a B inside the window; precision = support / #A;
  recall = B occurrences with an A inside / #B; lift = precision / precision under a shuffled-time null (window coverage).
  Rules need support >= min_support (default 3) and lift >= 3, except frame-exact rare pairs. A rule whose supporting
  occurrences all fall in one fight is 'provisional'. Holdout: a rule mined on one capture is re-scored on every other.
Higher-order (v2.2.5)
  Chains A→B→C (depth ≤ 3, or 4 where cheap) composed from high-lift 1-hop edges (beam search); end-to-end support /
  precision / recall / lift vs shuffled-time null (many circular shifts); per-hop windows including 1.5 s. Sequences
  (A then B within dt, A without B). Identity joins (same-frame multi-token views; clear-id chains). Elimination
  (my casts + meter totals subtracted from what is seen). Profiles: full (heavy post-analysis, no wall-clock cap) and
  quick (--quick). Caps: beam / edge / chain / support / lift. Elapsed seconds are printed. Live HSM rules stay
  hand-reviewed (not data-driven yet). Perf-bench 2-min and in-game addon budgets are unchanged.
Durations
  live events that share one clear id-like value (e.g. castBarID) are chained in time order; X->Y deltas are grouped by
  (X, Y, npc of the unit) and kept when n >= 2 and the spread is small (enemy cast times START -> SUCCEEDED)."""
import bisect
import collections
import re
import statistics
import time

from fdump.coverage import Live, classes, _args, _secret
from fdump.luasv import as_list

WINDOWS = (0.05, 0.15, 0.3, 0.75)
TOK = re.compile(r"^(player|target|focus|mouseover|pet|softenemy|softfriend|softinteract|nameplate\d+|party\d|raid\d+|arena\d|boss\d|"
                 r"targettarget|focustarget|targettargettarget|[a-z]+target)$")
IDLIKE = re.compile(r"^[A-Za-z]+-[0-9A-F-]{6,}$|^(Cast|CastBar|Creature|Player|Pet|Vehicle|GameObject)-")


def _tokclass(v):
    if not isinstance(v, str) or not TOK.match(v):
        return None
    return re.sub(r"\d+$", "N", v)


def _clear_scalar(v):
    if isinstance(v, float):
        return v.is_integer()          # continuous values (swing speed, timestamps) make no useful categories
    return isinstance(v, (int, bool)) or (isinstance(v, str) and not _secret(v) and v != "<nil>" and len(v) <= 40)


def live_events(live):
    seen, out = set(), []
    for e in sorted(live.events + live.record, key=lambda x: x["te"]):
        k = (e.get("e"), round(e["te"], 3), repr(_args(e))[:80])
        if k in seen or not e.get("e"):
            continue
        seen.add(k)
        out.append(e)
    return out


def log_names(fx):
    """(player names, NPC names) from the file log (v2.2.21: informational; nothing is redacted)."""
    players, npcs = set(), set()
    for e in (fx or {}).get("events", []):
        if not e.get("cleu"):
            continue
        a = e["a"]
        for gi, ni in ((3, 4), (7, 8)):
            if len(a) <= ni or not isinstance(a[ni], str):
                continue
            g, n = str(a[gi]), a[ni]
            if g.startswith("Player-"):
                players.add(n)
                players.add(n.split("-")[0])
            elif g.startswith(("Creature-", "Vehicle-")):
                npcs.add(n)
    return players, npcs


# string args that are a unit's name (target of a cast): kept only when the name is a known NPC
NAME_ARGS = {("UNIT_SPELLCAST_SENT", 1)}


def _redact(ev, i, v, names):
    """v2.2.21 (raw identity): values are kept as logged - no <player>/<name> placeholders."""
    return v


def live_features(live, names=None):
    evs = live_events(live)
    card = collections.defaultdict(set)
    for e in evs:
        for i, v in enumerate(_args(e)[1:], 1):
            if _clear_scalar(v) and not (isinstance(v, str) and IDLIKE.match(v)):
                card[(e["e"], i)].add(_redact(e["e"], i, v, names))
    feats = []
    for e in evs:
        a = _args(e)
        tok = _tokclass(a[0]) if a else None
        base = e["e"] + ("|" + tok if tok else "")
        keys = [base]
        for i, v in enumerate(a[1:] if tok else a, 1 if tok else 0):
            if isinstance(v, dict):
                for f in sorted(v.keys(), key=lambda k: (not isinstance(k, (int, float)), str(k)))[:6]:   # run 8: mixed int/str keys (BG widget payloads)
                    keys.append("%s|arg%d.has=%s" % (base, i, f))
            elif _clear_scalar(v) and not (isinstance(v, str) and IDLIKE.match(v)) and len(card[(e["e"], i)]) <= 40:
                keys.append("%s|arg%d=%s" % (base, i, _redact(e["e"], i, v, names)))
        feats.append((e["te"], keys, e))
    return feats


def truth_features(fx, cls, lo, hi):
    out = []
    for e in fx.get("events", []):
        if not e.get("cleu") or (lo is not None and not (lo - 1 <= e["t"] <= hi + 1)):
            continue
        a = e["a"]
        s, d = cls(a[3]), cls(a[7])
        base = "%s|%s>%s" % (e["sub"], s, d)
        keys = [base]
        if len(a) > 11 and isinstance(a[11], int) and e["sub"].startswith(("SPELL", "RANGE")):
            keys.append("%s|spell=%d" % (base, a[11]))
        out.append((e["t"], keys, e))
    return out


BURST = 0.05


def _index(feats):
    """occurrence times per key; a burst of the same key inside 50 ms is ONE occurrence (DM updates come 8 per frame)"""
    idx = collections.defaultdict(list)
    for t, keys, _ in sorted(feats, key=lambda x: x[0]):
        for k in keys:
            if not idx[k] or t - idx[k][-1] > BURST:
                idx[k].append(t)
    return idx


def _min_dt(ts, t, forward=False):
    i = bisect.bisect_left(ts, t)
    best = None
    for j in (i - 1, i):
        if 0 <= j < len(ts):
            dt = ts[j] - t
            if forward and dt < 0:
                continue
            if best is None or abs(dt) < abs(best):
                best = dt
    if forward:
        j = bisect.bisect_left(ts, t)
        if j < len(ts):
            best = ts[j] - t
    return best


def _pairs(A, B, wmax, forward=False, same=False):
    """co-occurrence sweep: for each A event, B keys within wmax (min |dt|)"""
    co = collections.defaultdict(list)   # (ka, kb) -> [dt per A occurrence]
    bt = [x[0] for x in B]
    last = {}
    for t, ka_list, _ in A:
        ka_list = [k for k in ka_list if t - last.get(k, -9) > BURST]
        for k in ka_list:
            last[k] = t
        if not ka_list:
            continue
        i = bisect.bisect_left(bt, t - (0 if forward else wmax))
        near = {}
        while i < len(B) and B[i][0] <= t + wmax:
            dt = B[i][0] - t
            if not (forward and dt < 0):
                for kb in B[i][1]:
                    if kb not in near or abs(dt) < abs(near[kb]):
                        near[kb] = dt
            i += 1
        for ka in ka_list:
            for kb, dt in near.items():
                if same and _base(kb) == _base(ka):
                    continue
                co[(ka, kb)].append(dt)
    return co


def _coverage(ts, w, L, forward=False):
    """fraction of the span covered by the A windows (exact null rate of a uniformly placed point falling inside one)"""
    tot, end = 0.0, None
    for t in ts:
        a, b = (t, t + w) if forward else (t - w, t + w)
        if end is None or a > end:
            tot += b - a
        else:
            tot += max(0.0, b - end)
        end = b if end is None else max(end, b)
    return min(1.0, tot / L)


_NUM = re.compile(r"=(\d+)$")


def _idmatch(ka, kb):
    a, b = _NUM.search(ka), _NUM.search(kb)
    return bool(a and b and a.group(1) == b.group(1) and len(a.group(1)) >= 3)


def mine(A, B, span, combat, kind, forward=False, same=False, min_support=3, min_lift=3.0, p_rare=0.01):
    ia, ib = _index(A), _index(B)
    co = _pairs(A, B, max(WINDOWS), forward=forward, same=same)
    lo, hi = span
    if lo is None or hi is None:   # v2.2.21: a capture with no timed events (tiny / synthetic SV) has no span
        return [], []
    L = max(1e-6, hi - lo)
    cache = {}

    def cov(idx, k, w):
        key = (id(idx), k, w)
        if key not in cache:
            cache[key] = _coverage(idx[k], w, L, forward)
        return cache[key]
    rules, rare = [], []
    for (ka, kb), dts in co.items():
        if ka == kb:
            continue
        na, nb = len(ia[ka]), len(ib[kb])
        best = None
        md = None   # v2.2.13 speed-up: the B->A nearest distances do not depend on the window; computed once per pair
        for w in WINDOWS:
            sup = sum(1 for d in dts if abs(d) <= w)
            if sup == 0:
                continue
            if md is None:
                if forward:
                    md = sorted(m for m in (_min_dt_back(ia[ka], t) for t in ib[kb]) if m is not None)
                else:
                    md = sorted(abs(m) for m in (_min_dt(ia[ka], t) for t in ib[kb]) if m is not None)
            supb = bisect.bisect_right(md, w)
            prec, rec = sup / float(na), supb / float(nb)
            ca, cb = cov(ia, ka, w), cov(ib, kb, w)
            from fdump.correlate_findings import smooth_lift
            lp, lp_lo, lp_hi = smooth_lift(prec, cb, na)
            lr, lr_lo, lr_hi = smooth_lift(rec, ca, nb)
            use_p = lp >= lr
            cand = {"a": ka, "b": kb, "kind": kind, "window": w, "support": sup, "supportB": supb, "nA": na, "nB": nb,
                    "precision": round(prec, 3), "recall": round(rec, 3),
                    "lift": lp if use_p else lr,
                    "liftLo": lp_lo if use_p else lr_lo, "liftHi": lp_hi if use_p else lr_hi,
                    "nullA": round(ca, 4), "nullB": round(cb, 4), "idMatch": _idmatch(ka, kb),
                    "lagMedian": round(statistics.median([d for d in dts if abs(d) <= w]), 3)}
            if min(na, nb) < min_support:
                if w == WINDOWS[0]:
                    # rare side fully paired inside one frame: p = chance that all its occurrences land in the other side's windows
                    if nb < min_support and supb == nb:
                        pv, side = ca ** nb, "b"
                    elif na < min_support and sup == na:
                        pv, side = cb ** na, "a"
                    else:
                        pv, side = 1.0, None
                    if side and pv <= p_rare:
                        cand.update(p=round(pv, 6), rare=True, rareSide=side)
                        rare.append(cand)
                continue
            ok = (prec >= 0.5 and sup >= min_support and lp >= min_lift) or (rec >= 0.8 and supb >= min_support and lr >= min_lift)
            if ok and (best is None or cand["support"] + cand["supportB"] > 1.1 * (best["support"] + best["supportB"])):
                best = cand
        if best:
            rules.append(best)
    for r in rules + rare:
        fights = set()
        for t in ia[r["a"]]:
            m = _min_dt(ib[r["b"]], t, forward=forward)
            if m is not None and abs(m) <= r["window"]:
                fights.add(next((i for i, (c0, c1) in enumerate(combat) if c0 - 1 <= t <= c1 + 1), "ooc"))
        r["fights"] = len(fights)
        r["provisional"] = len(fights) <= 1
    return rules, rare


def _min_dt_back(ts, t):
    """distance to the latest A at or before t (forward rules: A precedes B)"""
    i = bisect.bisect_right(ts, t) - 1
    return (t - ts[i]) if i >= 0 else None


def _base(k):
    """event family: event name + token class (truth: sub + src>dst)"""
    p = k.split("|")
    return "|".join(p[:2]) if len(p) > 1 and ("=" not in p[1] and ".has" not in p[1]) else p[0]


def _prune(rules, per_group=2):
    """keep the most specific informative rule: drop an L0 rule when an L1 refinement of the same pair has equal support;
    then keep the best `per_group` rules per (event family A, event family B) so sibling values do not flood the list"""
    out = []
    keyset = {(r["a"], r["b"]): r for r in rules}
    for r in rules:
        dominated = False
        for r2 in rules:
            if r2 is r:
                continue
            if (r2["a"].startswith(r["a"] + "|") and r2["b"] == r["b"] or r2["b"].startswith(r["b"] + "|") and r2["a"] == r["a"]) \
                    and r2["support"] >= r["support"] and r2["precision"] >= r["precision"]:
                dominated = True
                break
        if not dominated:
            out.append(r)
    uniq, seen = [], {}
    for r in out:
        if r["kind"] == "live->live":
            u = tuple(sorted((r["a"], r["b"])))
            if u in seen:
                o = seen[u]
                if r["support"] + r["supportB"] > o["support"] + o["supportB"]:
                    uniq[uniq.index(o)] = r
                    seen[u] = r
                continue
            seen[u] = r
        uniq.append(r)
    out = uniq
    g = collections.defaultdict(list)
    for r in out:
        g[(_base(r["a"]), _base(r["b"]), r["kind"])].append(r)
    res = []
    for k, v in g.items():
        v.sort(key=lambda r: (-(r["support"] + r.get("supportB", 0)) * min(r["lift"], 50), -r["precision"]))
        for r in v[per_group:]:
            v[0].setdefault("siblings", 0)
            v[0]["siblings"] += 1
        res += v[:per_group]
    return res


def durations(live, feats):
    """chain live events sharing a clear id-like value; group X->Y deltas by npc"""
    chains = collections.defaultdict(list)
    for t, keys, e in feats:
        a = _args(e)
        for i, v in enumerate(a):
            if isinstance(v, str) and IDLIKE.match(v) and not v.startswith(("Player-", "Creature-", "Pet-")):
                tok = a[0] if a and isinstance(a[0], str) else None
                guid = live.target_at(t) if tok == "target" else ("player" if tok == "player" else None)
                chains[(i, v)].append((t, e["e"], guid))
    agg = collections.defaultdict(list)
    for _, ev in chains.items():
        ev.sort(key=lambda x: x[0])
        first = collections.OrderedDict()
        for t, x, g in ev:
            first.setdefault(x, (t, g))         # one occurrence per event name per chain (CombatLogDB + RecordDB copies)
        items = list(first.items())
        for i, (x, (t0, g0)) in enumerate(items):
            for y, (t1, _) in items[i + 1:]:
                if 0 < t1 - t0 < 30:
                    npc = "player" if g0 == "player" else None
                    if g0 and str(g0).startswith("Creature-"):
                        p = str(g0).split("-")
                        npc = p[5] if len(p) > 5 else None
                    agg[(x, y, npc)].append(t1 - t0)
    out = []
    for (x, y, npc), v in agg.items():
        if len(v) >= 2:
            m = statistics.median(v)
            spread = (max(v) - min(v)) / m if m else 9
            out.append({"from": x, "to": y, "npc": npc, "n": len(v), "median": round(m, 3), "min": round(min(v), 3), "max": round(max(v), 3),
                        "consistent": spread <= 0.1})
    return sorted(out, key=lambda r: (-r["consistent"], -r["n"]))


def capture(dump, fx, player):
    live = Live(dump)
    cls, _ = classes(fx, player)
    lf = live_features(live, log_names(fx))
    from fdump.correlate_findings import discover_aliases, canonicalize_features
    alias_to, alias_obs = discover_aliases(live, player)
    lf, n_collapse = canonicalize_features(lf, alias_to)
    lo, hi = live.span
    tf = truth_features(fx, cls, lo, hi)
    return {"live": live, "lf": lf, "tf": tf, "span": (lo, hi), "combat": live.combat,
            "player": player, "aliasTo": alias_to, "aliasObs": alias_obs, "aliasCollapsed": n_collapse}


def mine_capture(c, min_support=3, rare_top=3):
    rules, rare = [], []
    for args in ((c["lf"], c["tf"], "live->truth", False, False), (c["lf"], c["lf"], "live->live", False, True),
                 (c["tf"], c["tf"], "truth->truth", True, True)):
        r1, r2 = mine(args[0], args[1], c["span"], c["combat"], args[2], forward=args[3], same=args[4], min_support=min_support)
        rules += r1
        rare += r2
    rules = _prune(rules)
    rules.sort(key=lambda r: (-(r["support"] + r.get("supportB", 0)) * min(r["lift"], 50), r["a"]))
    # rare targets (fewer than min_support occurrences): per B the best few A by (id match, null probability, precision)
    by = collections.defaultdict(list)
    seen = set()
    for r in rare:
        if r["kind"] == "live->live":
            u = tuple(sorted((r["a"], r["b"])))
            if u in seen:
                continue
            seen.add(u)
        by[(r[r["rareSide"]], r["kind"])].append(r)
    keep = []
    for k, v in by.items():
        v.sort(key=lambda r: (not r["idMatch"], r["p"], -r["precision"]))
        for i, r in enumerate(v[:rare_top]):
            r["rank"] = i + 1
            keep.append(r)
    return rules, keep


def holdout(rule, c):
    """re-score one rule on another capture at the rule's window"""
    src = c["lf"] if rule["kind"].startswith("live") else c["tf"]
    dst = c["tf"] if rule["kind"].endswith("truth") else c["lf"]
    ia, ib = _index(src), _index(dst)
    ta, tb = ia.get(rule["a"]) or [], ib.get(rule["b"]) or []
    if not ta:
        return {"status": "absent", "nA": 0}
    fw = rule["kind"] == "truth->truth"
    sup = sum(1 for t in ta if (lambda m: m is not None and abs(m) <= rule["window"])(_min_dt(tb, t, forward=fw)))
    prec = sup / float(len(ta))
    return {"status": "held" if prec >= 0.5 * rule["precision"] and sup > 0 else "failed", "nA": len(ta), "support": sup,
            "precision": round(prec, 3)}


KNOWN = [
    ("interrupt", re.compile(r"UNIT_SPELLCAST_INTERRUPTED.*SPELL_INTERRUPT|SPELL_INTERRUPT.*UNIT_SPELLCAST_INTERRUPTED|"
                             r"UNIT_SPELLCAST_SUCCEEDED\|player\|arg\d=8046.*INTERRUPTED|INTERRUPTED.*UNIT_SPELLCAST_SUCCEEDED\|player\|arg\d=8046")),
    ("own cast", re.compile(r"UNIT_SPELLCAST_(SUCCEEDED|START|SENT)\|player.*SPELL_CAST_(SUCCESS|START)\|me>")),
    ("unit combat", re.compile(r"UNIT_COMBAT\|.*(DAMAGE|HEAL|MISSED)")),
    ("aura on token", re.compile(r"UNIT_AURA\|.*SPELL_AURA_")),
    ("enemy cast", re.compile(r"UNIT_SPELLCAST_\w+\|(target|nameplateN|softenemy).*SPELL_CAST_\w+\|npc>")),
    ("same spell", re.compile(r"\|spell=(\d+)\b.*\|spell=\1$")),
    ("damage meter", re.compile(r"DAMAGE_METER")),
    ("ui echo", re.compile(
        r"^(GLOBAL_|WORLD_CURSOR|UPDATE_MOUSEOVER|ACTIONBAR_|CURRENT_SPELL_CAST_CHANGED|MODIFIER_STATE|"
        r"BAG_UPDATE_COOLDOWN|UNIT_HAPPINESS|ACTION_RANGE_CHECK_UPDATE)|"
        r"-> (GLOBAL_|WORLD_CURSOR|UPDATE_MOUSEOVER|ACTIONBAR_|CURRENT_SPELL_CAST_CHANGED|MODIFIER_STATE|"
        r"BAG_UPDATE_COOLDOWN|UNIT_HAPPINESS|ACTION_RANGE_CHECK_UPDATE)|"
        r"UNIT_SPELLCAST_SENT\|.*->.*UNIT_SPELLCAST_SUCCEEDED\|")),
    ("log structure", re.compile(r"^(SWING_DAMAGE|SPELL_DAMAGE|SPELL_PERIODIC_DAMAGE)(_LANDED)?\|.* -> (SWING_DAMAGE|SPELL_DAMAGE|SPELL_PERIODIC_DAMAGE)(_LANDED)?\|")),
    ("token alias", re.compile(r"^(\w+)\|[a-zN]+\S* -> \1\|[a-zN]+")),
    ("health side effect", re.compile(r"UNIT_HEALTH|UNIT_MAXHEALTH|UNIT_POWER")),
    ("totem", re.compile(r"PLAYER_TOTEM_UPDATE.*SPELL_SUMMON|SPELL_SUMMON.*PLAYER_TOTEM_UPDATE")),
]


def known(rule):
    s = rule["a"] + " -> " + rule["b"]
    for name, rx in KNOWN:
        if rx.search(s):
            return name
    return None

def run(captures, min_support=3, profile="full", higher=True):
    """captures: [(label, dump, fx, player)] -> 1-hop rules + higher-order chains + holdout + durations.
    profile: 'full' (default, heavy post-analysis) or 'quick'. higher=False skips the HO pass."""
    from fdump import correlate_ho
    t_all = time.time()
    cs = []
    for label, dump, fx, player in captures:
        c = capture(dump, fx, player)
        c["label"] = label
        cs.append(c)
    res = {"captures": [c["label"] for c in cs], "rules": [], "durations": [], "higher": [],
           "profile": profile, "elapsedSec": {}}
    res["rare"] = []
    t_mine = time.time()
    per = {}
    for c in cs:
        rules, rare = mine_capture(c, min_support=min_support)
        for r in rules + rare:
            r["capture"] = c["label"]
            r["holdout"] = {o["label"]: holdout(r, o) for o in cs if o is not c}
            r["known"] = known(r)
        res["rules"] += rules
        res["rare"] += rare
        per[c["label"]] = (rules, rare)
        for d in durations(c["live"], c["lf"]):
            d["capture"] = c["label"]
            res["durations"].append(d)
    res["elapsedSec"]["mine"] = round(time.time() - t_mine, 3)
    if higher:
        t_ho = time.time()
        for c in cs:
            rules, rare = per[c["label"]]
            ho = correlate_ho.higher_order(c, rules, rare, profile=profile)
            for ch in ho["chains"]:
                ch["capture"] = c["label"]
                ch["holdout"] = {o["label"]: correlate_ho.holdout_chain(ch, o) for o in cs if o is not c}
            res["higher"] += ho["chains"]
            res.setdefault("higherMeta", {})[c["label"]] = {k: ho[k] for k in ("profile", "edgesUsed", "elapsedSec", "config")}
        res["elapsedSec"]["higher"] = round(time.time() - t_ho, 3)
    # merge alias observations across captures + distill distinct findings
    from fdump import correlate_findings as cf
    alias_obs, seen = [], set()
    for c in cs:
        for o in (c.get("aliasObs") or []):
            k = (o.get("alias"), o.get("canon"))
            if k in seen:
                continue
            seen.add(k)
            alias_obs.append(o)
    res["aliasObs"] = alias_obs
    t_dist = time.time()
    cf.distill(res, alias_obs=alias_obs)
    res["elapsedSec"]["distill"] = round(time.time() - t_dist, 3)
    res["elapsedSec"]["total"] = round(time.time() - t_all, 3)
    return res


def find_chains(res, *rxs, patterns=None):
    from fdump import correlate_ho
    return correlate_ho.find_chains(res, *rxs, patterns=patterns)

def find(res, a_rx, b_rx, rare=True):
    return [r for r in res["rules"] + (res.get("rare") or [] if rare else []) if re.search(a_rx, r["a"]) and re.search(b_rx, r["b"]) or re.search(a_rx, r["b"]) and re.search(b_rx, r["a"])]


def markdown(res, top=40):
    from fdump import correlate_findings as cf
    L = ["## Co-occurrence miner (tools/fdump/correlate.py)", "",
         "Captures: %s. 1-hop windows 50/150/300/750 ms; higher-order adds 1.5 s and depth <= 4 (profile %s). "
         "Lift uses add-½ smoothing (finite, with CI); status = cross-run / held-1 / provisional / failed. "
         "Tokens are canonicalized (alias collapse) before mining." % (", ".join(res["captures"]), res.get("profile", "full")), ""]
    L += cf.markdown_distinct(res)
    new = [r for r in res["rules"] if not r["known"]]
    L += ["### Rules not already encoded in the HSM (new leads)", "",
          "| capture | kind | A | B | window ms | support | precision | recall | lift | lag s | flags | holdout |", "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in new[:top]:
        L.append(_row(r))
    L += ["", "### Rediscovered (already known)", "", "| capture | kind | A | B | window ms | support | precision | recall | lift | lag s | flags | holdout |",
          "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    kn = [r for r in res["rules"] if r["known"]]
    for r in kn[:top]:
        L.append(_row(r))
    rr = [r for r in res.get("rare") or [] if r["kind"] != "live->live" or r["idMatch"] or r["rank"] == 1]
    rr.sort(key=lambda r: (r[r["rareSide"]], r["rank"]))
    L += ["", "### Rare targets (B seen fewer than min-support times; best A per B by id match, then null probability) - provisional by nature", "",
          "| capture | kind | A | B | rank | id match | p(null) | precision | lag s | holdout |", "|---|---|---|---|---|---|---|---|---|---|"]
    for r in rr[:top]:
        ho = "; ".join("%s:%s" % (k, v["status"]) for k, v in r["holdout"].items())
        L.append("| %s | %s | `%s` | `%s` | %d | %s | %s | %s | %s | %s |" % (r["capture"], r["kind"], r["a"], r["b"], r["rank"], r["idMatch"], r["p"],
                                                                     r["precision"], r["lagMedian"], ho or "-"))
    L += ["", "### Durations (shared clear id chains)", "", "| capture | from | to | npc | n | median s | min | max | consistent |", "|---|---|---|---|---|---|---|---|---|"]
    for d in res["durations"][:20]:
        L.append("| %s | %s | %s | %s | %d | %.3f | %.3f | %.3f | %s |" % (d["capture"], d["from"], d["to"], d["npc"], d["n"], d["median"], d["min"], d["max"], d["consistent"]))
    from fdump import correlate_ho
    L += correlate_ho.markdown_higher(res)
    facts = res.get("damageMeterFacts") or []
    if facts:
        L += ["", "## Damage-meter correlation facts (v2.2.6)", "",
              "%d fact(s) from live↔meter↔log join (offs feed regression checks)." % len(facts), ""]
        offs = [f for f in facts if f.get("verdict") == "off"][:30]
        for f in offs:
            L.append("- OFF fight %s %s unit=%s live/meter/log=%s/%s/%s" % (
                f.get("fight"), f.get("metric") or f.get("kind"), f.get("unit"),
                f.get("live"), f.get("meter") if not isinstance(f.get("meter"), dict) else (f.get("meter") or {}).get("damage"),
                f.get("log")))

    el = res.get("elapsedSec") or {}
    if el:
        L += ["", "_Elapsed: mine %ss, higher-order %ss, total %ss (profile %s)._" % (
            el.get("mine", "?"), el.get("higher", "skipped"), el.get("total", "?"), res.get("profile", "full")), ""]
    return "\n".join(L) + "\n"



def _row(r):
    flags = ",".join(x for x in ("provisional" if r["provisional"] else "", "id-match" if r.get("idMatch") else "", r["known"] or "") if x)
    ho = "; ".join("%s:%s" % (k, v["status"] + ("(%s)" % v.get("precision") if v.get("precision") is not None else "")) for k, v in r["holdout"].items())
    return "| %s | %s | `%s` | `%s` | %d | %d/%d | %s | %s | %s | %s | %s | %s |" % (
        r["capture"], r["kind"], r["a"], r["b"], int(r["window"] * 1000), r["support"], r["nA"], r["precision"], r["recall"], r["lift"],
        r["lagMedian"], flags, ho or "-")
