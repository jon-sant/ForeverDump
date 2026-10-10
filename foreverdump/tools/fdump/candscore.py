"""v2.2.15: score the HSM's parallel candidate (shadow) rules against the combat-log truth.

Each replayed attribution may carry `cand = {id: "mine"|"other"}` (claims made by candidate rules while the HSM handled
that event). For every candidate the category score is computed twice with coverage.score: `before` = the live rule's
claims, `after` = the same attributions with the candidate's claim substituted where it made one. A candidate is
promotable only if it beats the live rule (accuracy up, falseSelf not up) on every run that has scorable events.
"""
import collections
import copy

from . import coverage


def cand_ids(attrs):
    ids = collections.OrderedDict()
    for a in attrs:
        for k in (a.get("cand") or {}):
            ids[k] = True
    return list(ids)


def _cat_of(a, refs):
    x = refs.get(a.get("ref")) or {}
    if a["k"] == "uc":
        if x.get("player"):
            return "heal-on-me" if x.get("action") == "HEAL" else "damage-taken"
        return "damage-on-target" if x.get("action") == "WOUND" else ("miss-on-target" if x.get("action") != "HEAL" else "heal-on-target")
    if a["k"] == "interrupt":
        return "interrupt"
    return "aura-on-target" if x.get("unit") != "player" else "aura-on-me"


def score_candidates(attrs, truth, refs):
    """-> {cid: {cat: {before: score, after: score, n: claims}}}"""
    attrs = [a for a in attrs if a.get("k") in ("uc", "interrupt", "aura")]
    base, _ = coverage.score(attrs, truth, refs)
    out = {}
    for cid in cand_ids(attrs):
        alt = []
        cats = collections.Counter()
        for a in attrs:
            c = (a.get("cand") or {}).get(cid)
            if c is not None:
                b = dict(a)
                b["src"], b["rule"] = c, cid
                alt.append(b)
                cats[_cat_of(a, refs)] += 1
            else:
                alt.append(a)
        sc, _ = coverage.score(alt, truth, refs)
        out[cid] = {cat: {"before": base.get(cat), "after": sc.get(cat), "claims": n} for cat, n in cats.items()}
    return out


# v2.2.16: false-self claims are a first-class gate. A candidate may never raise false-self claims vs the live rule on
# any run; its accuracy may drop by at most NOISE (max(NOISE_PT, one event of that run)); promotion needs a false-self
# cut (or an accuracy gain beyond noise) on at least one run and no failure on any.
NOISE_PT = 2.0


def noise(scorable):
    return max(NOISE_PT, 100.0 / scorable) if scorable else NOISE_PT


def gate_run(before, after):
    """-> (ok, better, why) for one run/category"""
    b, a = before or {}, after or {}
    n = a.get("scorable") or b.get("scorable") or 0
    ab, aa = b.get("accuracy") or 0.0, a.get("accuracy") or 0.0
    fb, fa = b.get("falseSelf", 0), a.get("falseSelf", 0)
    if fa > fb:
        return False, False, "falseSelf %d -> %d" % (fb, fa)
    if aa < ab - noise(n):
        return False, False, "accuracy %.1f -> %.1f (noise %.1f)" % (ab, aa, noise(n))
    return True, (fa < fb) or (aa > ab + noise(n)), ""


def verdict(per_run):
    """per_run = {run: {cid: {cat: {before, after}}}} -> {cid: {cat: {status promote|provisional|off, runs, better, worse, why}}}"""
    res = {}
    cids = sorted({c for r in per_run.values() for c in r})
    for cid in cids:
        cats = sorted({cat for r in per_run.values() for cat in (r.get(cid) or {})})
        for cat in cats:
            better, worse, runs, why = 0, 0, 0, []
            for run, r in per_run.items():
                x = (r.get(cid) or {}).get(cat)
                if not x or not x.get("after") or not (x["after"].get("scorable") or 0):
                    continue
                runs += 1
                ok, bet, w = gate_run(x.get("before"), x["after"])
                if not ok:
                    worse += 1
                    why.append("%s: %s" % (run, w))
                elif bet:
                    better += 1
            st = "promote" if runs and worse == 0 and better > 0 else ("provisional" if worse == 0 and runs else "off")
            res.setdefault(cid, {})[cat] = {"status": st, "runs": runs, "better": better, "worse": worse, "why": why}
    return res


def rule_metrics(attrs, truth, refs):
    """per live rule: mine claims, false-self claims (claimed mine, log says someone else), correct mine, U claims"""
    out = collections.defaultdict(collections.Counter)
    for a in attrs:
        if a.get("k") not in ("uc", "interrupt", "aura"):
            continue
        tr = truth.get(a.get("ref"))
        if not tr:
            continue
        x = out[a.get("rule") or "none"]
        x["n"] += 1
        tm = tr["src"] in ("me", "mine")
        src = a.get("src")
        if src == "mine":
            x["mine"] += 1
            x["correctMine" if tm else "falseSelf"] += 1
        elif src in (None, "none"):
            x["unknown"] += 1
        elif tm:
            x["missedSelf"] += 1
    res = {}
    for r, c in out.items():
        d = dict(c)
        d["precision"] = round(100.0 * c["correctMine"] / c["mine"], 1) if c["mine"] else None
        res[r] = d
    return res
