"""v2.2.5 distinct-findings layer: token-alias collapse, lift smoothing, chain minimality,
holdout status, echo appendix, and a short 'Distinct findings' table (target << 30 rows).

Proposed live HSM rules stay review-only unless already wired in the addon.
"""
import collections
import math
import re
import statistics

# --------------------------------------------------------------------------- lift / null
EPS_COUNT = 0.5  # add-half pseudo-count so a zero null never yields infinite lift


def smooth_lift(prec, null_rate, n_a=1):
    """Finite lift with a crude CI from smoothed rates. Never returns 9999."""
    n = max(1.0, float(n_a))
    p = (prec * n + EPS_COUNT) / (n + 2 * EPS_COUNT)
    q = (null_rate * n + EPS_COUNT) / (n + 2 * EPS_COUNT)
    lift = p / max(q, 1e-9)
    # delta-method-ish log CI using binomial variance on smoothed counts
    se = math.sqrt(max(p * (1 - p), 1e-9) / (n + 2 * EPS_COUNT) + max(q * (1 - q), 1e-9) / (n + 2 * EPS_COUNT))
    lo = max(0.0, (p - 1.96 * se)) / max(q + 1.96 * se, 1e-9)
    hi = min(1.0, (p + 1.96 * se)) / max(q - 1.96 * se, 1e-9) if (q - 1.96 * se) > 1e-9 else lift * 3
    return round(min(lift, 1e4), 2), round(min(lo, lift), 2), round(min(hi, 1e4), 2)


def apply_lift_smoothing(row):
    """Mutate a rule/chain dict that has precision + nullA (or null_precs mean)."""
    null = row.get("nullA")
    if null is None:
        null = row.get("nullB") or 0.0
    lift, lo, hi = smooth_lift(row.get("precision") or 0.0, null or 0.0, row.get("nA") or 1)
    row["lift"] = lift
    row["liftLo"], row["liftHi"] = lo, hi
    return row


# --------------------------------------------------------------------------- token aliasing
CANON_RANK = {
    "player": 0, "pet": 1, "target": 2, "focus": 3, "mouseover": 4,
    "softenemy": 5, "softfriend": 6, "softinteract": 7,
    "nameplateN": 8, "partyN": 9, "raidN": 10, "arenaN": 11, "bossN": 12,
    "targettarget": 13, "focustarget": 14,
}


def _tok_family(tok):
    if not tok:
        return None
    t = re.sub(r"\d+$", "N", tok)
    if t.endswith("target") and t not in ("target",):
        return t  # targettarget, focustarget, …
    return t


def prefer_token(a, b):
    ra, rb = CANON_RANK.get(_tok_family(a), 50), CANON_RANK.get(_tok_family(b), 50)
    if ra != rb:
        return a if ra < rb else b
    return a if (a or "") <= (b or "") else b


def discover_aliases(live, player_guid):
    """Find token aliases of *me* (player).

    Only promote a global alias tok→player when evidence is strong:
      - GUID signal says tok maps to player_guid, or
      - same-frame identical payloads with player on many frames (n>=8) AND tok is a
        known 'view of me' family (targettarget / focustarget / *target of mob).
    Nameplates and softenemy are reported as observations but NOT collapsed globally
    (they often share incidental payloads without being the player).

    Instance-level same-frame dedup happens in canonicalize_features via alias_to
    plus per-frame collapse of duplicate payloads.
    """
    from fdump.correlate import live_events, _tokclass, _args, _clear_scalar, _secret

    ME_VIEWS = {"targettarget", "focustarget", "pettarget"}
    groups = collections.defaultdict(list)
    for e in live_events(live):
        a = _args(e)
        if not a or not isinstance(a[0], str):
            continue
        tok = _tokclass(a[0])
        if not tok:
            continue
        rest = []
        for v in a[1:]:
            if isinstance(v, dict):
                rest.append("{" + ",".join(sorted((str(k) for k in v.keys()))[:6]) + "}")   # run 8: mixed int/str keys
            elif _clear_scalar(v) or (isinstance(v, str) and not _secret(v)):
                rest.append(repr(v))
            else:
                rest.append("?")
        key = (round(e["te"], 2), e.get("e"), tuple(rest))
        groups[key].append(tok)

    edges = collections.Counter()  # (alias, canon) counts from same-frame
    frame_pairs = []  # for instance collapse hints
    for key, toks in groups.items():
        uniq = sorted(set(toks))
        if len(uniq) < 2:
            continue
        canon = uniq[0]
        for x in uniq[1:]:
            canon = prefer_token(canon, x)
        for x in uniq:
            if x != canon:
                edges[(x, canon)] += 1
                frame_pairs.append((key[0], x, canon, key[1]))

    guid_hits = collections.Counter()
    for s in getattr(live, "signals", []) or []:
        g, u = s.get("guid"), s.get("unit")
        if not g or not u:
            continue
        tok = _tokclass(u) or u
        if g == player_guid and tok and tok != "player":
            guid_hits[tok] += 1
            edges[(tok, "player")] += 3

    alias_to = {}
    obs = []
    for (a, b), n in edges.most_common(80):
        canon = prefer_token(a, b)
        other = b if canon == a else a
        # only record obs
        if other == canon:
            continue
        # global collapse only for strong me-views → player
        promote = False
        if canon == "player" and other in ME_VIEWS and (n >= 8 or guid_hits.get(other, 0) >= 1):
            promote = True
        elif canon == "player" and guid_hits.get(other, 0) >= 3 and other in ME_VIEWS:
            promote = True
        obs.append({"alias": other, "canon": canon, "n": n, "via": "guid" if guid_hits.get(other) else "same-frame-payload",
                    "collapsed": promote})
        if promote:
            alias_to[other] = "player"

    # dedupe obs by alias (keep strongest)
    best = {}
    for o in obs:
        cur = best.get(o["alias"])
        if not cur or o["n"] > cur["n"]:
            best[o["alias"]] = o
    out = sorted(best.values(), key=lambda o: -o["n"])
    return alias_to, out


def canonicalize_features(feats, alias_to):
    """(1) Rewrite global me-view aliases. (2) Same-frame identical payloads: keep preferred token only."""
    # pass 1: global alias rewrite
    rewritten = []
    collapsed = 0
    for t, keys, e in feats:
        new_keys, local = [], set()
        for k in keys:
            parts = k.split("|", 2)
            if len(parts) >= 2 and parts[1] in alias_to:
                parts[1] = alias_to[parts[1]]
                nk = "|".join(parts)
                collapsed += 1
            else:
                nk = k
            if nk not in local:
                local.add(nk)
                new_keys.append(nk)
        rewritten.append((t, new_keys, e))

    # pass 2: per-frame payload dedup across tokens
    # group by (round te, event, args-without-token-suffix of keys).
    # parts[1] is a unit token only when it looks like one — never "arg0=5" / "spell=…"
    # (those are payload keys; treating them as tokens collapsed distinct meter types).
    UNIT_TOK = re.compile(
        r"^(player|target|targettarget|focus|mouseover|pet|vehicle|soft(enemy|friend)|"
        r"nameplateN|partyN|raidN|arenaN|bossN|npc)$")
    buckets = collections.defaultdict(list)
    for i, (t, keys, e) in enumerate(rewritten):
        for k in keys:
            parts = k.split("|")
            if len(parts) < 2:
                continue
            ev, maybe_tok, rest = parts[0], parts[1], parts[2:]
            if not UNIT_TOK.match(maybe_tok):
                continue  # not a token-keyed feature; leave alone
            buckets[(round(t, 2), ev, tuple(rest))].append((i, maybe_tok, k))

    drop_keys = collections.defaultdict(set)  # feat index -> keys to drop
    for _key, members in buckets.items():
        toks = {tok for _, tok, _ in members}
        if len(toks) < 2:
            continue
        # prefer player > target > ...
        best = None
        for _, tok, _ in members:
            best = tok if best is None else prefer_token(best, tok)
        for i, tok, k in members:
            if tok != best:
                drop_keys[i].add(k)
                collapsed += 1

    out, seen = [], set()
    for i, (t, keys, e) in enumerate(rewritten):
        keys2 = [k for k in keys if k not in drop_keys.get(i, ())]
        if not keys2:
            continue
        sig = (round(t, 3), tuple(keys2))
        if sig in seen:
            continue
        seen.add(sig)
        out.append((t, keys2, e))
    return out, collapsed


# --------------------------------------------------------------------------- echoes
ECHO_RX = re.compile(
    r"BAG_UPDATE_COOLDOWN|ACTIONBAR_UPDATE_(COOLDOWN|STATE)|UNIT_HAPPINESS|"
    r"ACTION_RANGE_CHECK_UPDATE|GLOBAL_(REGION_)?MOUSE|WORLD_CURSOR|UPDATE_MOUSEOVER|"
    r"CURRENT_SPELL_CAST_CHANGED|MODIFIER_STATE|UNIT_PORTRAIT_UPDATE|UNIT_MODEL_CHANGED|"
    r"PLAYER_(STARTED|STOPPED)_(LOOKING|TURNING)|UPDATE_SHAPESHIFT_FORM|"
    r"UNIT_SPELLCAST_SENT\|.*UNIT_SPELLCAST_SUCCEEDED"  # SENT->SUCCEEDED same cast (any separator)
)


def is_echo_blob(blob):
    return bool(ECHO_RX.search(blob or ""))


def is_echo_rule(r):
    if r.get("known") in ("ui echo", "health side effect", "log structure", "token alias"):
        return True
    return is_echo_blob(r.get("a", "") + " -> " + r.get("b", ""))


def is_echo_chain(ch):
    hops = ch.get("hops") or []
    blob = " || ".join(hops)
    # SENT -> SUCCEEDED of the same cast is always an echo (even with a clear spell id)
    if len(hops) <= 2 and re.search(r"UNIT_SPELLCAST_SENT\|", blob) and re.search(r"UNIT_SPELLCAST_SUCCEEDED\|", blob):
        return True
    if not is_echo_blob(blob):
        return False
    # Keep only when an *echo-class* hop itself carries a clear combat spellID
    # unavailable elsewhere (e.g. SPELL_UPDATE_COOLDOWN|arg0=370). A truth-side spell=
    # on SPELL_CAST_SUCCESS does not rescue BAG_/ACTIONBAR_/MOUSE echoes.
    for h in hops:
        if is_echo_blob(h) and re.search(r"(?:arg\d|spell)=(\d{3,})", h):
            if re.search(r"SPELL_UPDATE_COOLDOWN", h):
                return False  # informative clear payload
    return True


# --------------------------------------------------------------------------- holdout status
def holdout_status(holdout):
    """cross-run (>=2 held) | held-1 | provisional | failed."""
    if not holdout:
        return "provisional"
    n_held = sum(1 for v in holdout.values() if v.get("status") == "held")
    n_failed = sum(1 for v in holdout.values() if v.get("status") == "failed")
    if n_held >= 2:
        return "cross-run"
    if n_held == 1:
        return "held-1"
    if n_failed:
        return "failed"
    return "provisional"


def annotate_status(row):
    """Set status from holdout; provisional flag follows status (cross-run/held-1 clear it)."""
    ho = row.get("holdout") or {}
    n_held = sum(1 for v in ho.values() if v.get("status") == "held")
    n_failed = sum(1 for v in ho.values() if v.get("status") == "failed")
    if n_held >= 2:
        row["status"], row["provisional"] = "cross-run", False
    elif n_held == 1:
        row["status"], row["provisional"] = "held-1", False
    elif n_failed and n_held == 0:
        row["status"], row["provisional"] = "failed", True
    else:
        # no other-capture hold, or only absences: single-run / one-fight
        row["status"], row["provisional"] = "provisional", True
    return row


# --------------------------------------------------------------------------- chain minimality
def _subchains(hops):
    """all proper contiguous sub-chains of length >= 2 (as hop tuples)."""
    out = []
    n = len(hops)
    for i in range(n):
        for j in range(i + 2, n + 1):
            if j - i < n:
                out.append(tuple(hops[i:j]))
    return out


def minimize_chains(chains, min_gain=0.05):
    """Drop a chain if some shorter sub-chain (present in the set or as a 1-hop projection)
    already matches precision within min_gain and has support >= this chain's support * 0.9.
    Also drop depth>=3 chains whose middle hops are same-frame echoes (DAMAGE_METER, HEAL_PREDICTION
    alias duplicates)."""
    by_hops = {tuple(c["hops"]): c for c in chains}
    keep = []
    for c in chains:
        hops = c.get("hops") or []
        if len(hops) <= 2:
            keep.append(c)
            continue
        # middle-echo prune: if any internal hop is a pure meter/prediction echo and endpoints
        # already co-occur, drop
        mid = hops[1:-1]
        if mid and all(re.search(r"DAMAGE_METER|UNIT_HEAL_PREDICTION|UNIT_HEALTH\|", m) for m in mid):
            # check endpoints exist as a shorter finding
            ends = (hops[0], hops[-1])
            dominated = False
            for other in chains:
                oh = other.get("hops") or []
                if len(oh) == 2 and oh[0] == ends[0] and oh[-1] == ends[-1]:
                    if (other.get("precision") or 0) + min_gain >= (c.get("precision") or 0):
                        dominated = True
                        break
            if dominated:
                c = dict(c)
                c["pruned"] = "middle-echo"
                continue
        # sub-chain dominance
        dominated = False
        for sub in _subchains(hops):
            o = by_hops.get(sub)
            if not o:
                continue
            if (o.get("precision") or 0) + min_gain >= (c.get("precision") or 0) and (
                    o.get("support") or 0) >= 0.9 * (c.get("support") or 0):
                dominated = True
                break
        if dominated:
            continue
        keep.append(c)
    return keep


# --------------------------------------------------------------------------- finding keys / grouping
def _norm_hop(h):
    """Strip alias residue and numeric nameplate indices already N; drop redundant arg detail for grouping."""
    h = re.sub(r"\|arg\d+=[^|]+", "", h)  # drop clear args for grouping key (kept in evidence)
    h = re.sub(r"\|spell=\d+", "", h)
    return h


def finding_key(ch):
    pat = ch.get("pattern") or "chain"
    hops = ch.get("hops") or []
    # interrupt family
    blob = " || ".join(hops)
    if "INTERRUPTED" in blob and "INTERRUPT" in blob:
        return ("identity-interrupt", "interrupt")
    if "ELIM" in blob or pat == "elimination":
        return ("elimination", "elimination")
    if "DMJOIN" in blob or ("DAMAGE_METER" in blob and "UNIT_COMBAT" in blob and pat == "chain"):
        return ("meter-frame-join", pat)
    if "6371" in blob or ("HEAL" in blob and "PERIODIC_HEAL" in blob and "mine" in blob):
        return ("totem-heal-live", pat)
    if "SPELL_UPDATE_COOLDOWN" in blob and re.search(r"arg0=\d{3,}", blob):
        return ("cd-payload-clear", pat)
    if pat == "identity":
        return ("identity-" + _norm_hop(hops[0])[:40], pat)
    if pat == "sequence":
        return ("seq:" + "->".join(_norm_hop(h) for h in hops[:2]), pat)
    if pat == "absence":
        return ("abs:" + "->".join(_norm_hop(h) for h in hops[:2]), pat)
    # generic: first + last normalized
    return ("chain:" + _norm_hop(hops[0]) + "=>" + _norm_hop(hops[-1]), pat)


def group_chains(chains):
    groups = collections.defaultdict(list)
    for c in chains:
        groups[finding_key(c)].append(c)
    return groups


# Already-live HSM rules (review table column)
ALREADY_LIVE = {
    "identity-interrupt": False,  # proposed, not enabled
    "elimination": True,          # meter frame-join / others-on-target already in HybridState
    "meter-frame-join": True,
    "totem-heal-live": False,
    "cd-payload-clear": True,     # CooldownTracker CDPayload (v2.2.4)
    "token-alias": False,         # offline collapse only; live Ledger resolves token→GUID
}


def plain_finding(key, members):
    kind, pat = key[0], key[1] if len(key) > 1 else "chain"
    best = max(members, key=lambda c: (
        0 if c.get("provisional") else 1,
        sum(1 for v in (c.get("holdout") or {}).values() if v.get("status") == "held"),
        (c.get("precision") or 0) * (c.get("support") or 0),
        -(c.get("depth") or 9),
    ))
    for m in members:
        annotate_status(m)
    annotate_status(best)
    # status across group: best holdout
    statuses = [m.get("status") for m in members]
    if "cross-run" in statuses:
        status = "cross-run"
    elif "held-1" in statuses:
        status = "held-1"
    elif all(s == "failed" for s in statuses):
        status = "failed"
    else:
        status = "provisional"

    family = kind.split(":")[0] if ":" in kind else kind
    already = ALREADY_LIVE.get(family, ALREADY_LIVE.get(kind, False))
    reason = best.get("reason") or (" -> ".join(best.get("hops") or []))
    rule = best.get("proposedRule") or ""
    if family == "cd-payload-clear":
        reason = ("SPELL_UPDATE_COOLDOWN carries my spellID in the clear during combat "
                  "(arg0 matches the cast); arg3 is the GCD start-recovery category (133 vs 0). "
                  "Already fed into CooldownTracker via HS:CDPayload.")
        rule = "(already live) CooldownTracker CDPayload"
        already = True
    elif family == "totem-heal-live":
        reason = ("Totem heal ticks (e.g. spell 6371) show live as UNIT_COMBAT HEAL + "
                  "UNIT_HEAL_PREDICTION on player with no own cast nearby (~0.9 precision).")
        rule = ("TotemHealLive: UNIT_COMBAT|player HEAL + UNIT_HEAL_PREDICTION|player without "
                "UNIT_SPELLCAST_SUCCEEDED|player in-frame -> src=mine (totem); confirm with meter type 2/3.")
    elif family == "identity-interrupt":
        reason = best.get("reason") or reason
        rule = best.get("proposedRule") or rule
    elif family == "elimination" or family == "meter-frame-join":
        already = True
        rule = "(already live) HybridState meter frame-join / others-on-target elimination"

    captures = sorted({m.get("capture") for m in members if m.get("capture")})
    return {
        "id": family if family in ALREADY_LIVE or family in (
            "identity-interrupt", "totem-heal-live", "cd-payload-clear", "elimination",
            "meter-frame-join", "token-alias") else kind,
        "family": family,
        "pattern": best.get("pattern"),
        "meaning": reason,
        "evidence": {
            "hops": best.get("hops"),
            "support": best.get("support"),
            "nA": best.get("nA"),
            "precision": best.get("precision"),
            "recall": best.get("recall"),
            "lift": best.get("lift"),
            "liftLo": best.get("liftLo"),
            "liftHi": best.get("liftHi"),
            "captures": captures,
            "variants": len(members),
            "depth": best.get("depth"),
        },
        "status": status,
        "alreadyLive": already,
        "proposedRule": None if already else rule,
        "best": best,
    }


# --------------------------------------------------------------------------- public API
def distill(res, alias_obs=None, max_findings=12):
    """Build res['findings'], res['echoes'], fix lifts/status on higher+rules; return findings list."""
    # smooth lifts on 1-hop + higher
    for r in (res.get("rules") or []) + (res.get("rare") or []):
        apply_lift_smoothing(r)
        annotate_status(r)
    higher = list(res.get("higher") or [])
    for ch in higher:
        apply_lift_smoothing(ch)
        annotate_status(ch)

    echoes, leads = [], []
    for ch in higher:
        if is_echo_chain(ch):
            echoes.append(ch)
        else:
            leads.append(ch)
    # also park echo 1-hop new rules into echoes appendix (not findings)
    for r in res.get("rules") or []:
        if not r.get("known") and is_echo_rule(r):
            echoes.append({"hops": [r["a"], r["b"]], "pattern": "echo-1hop", "capture": r.get("capture"),
                           "support": r.get("support"), "precision": r.get("precision"), "lift": r.get("lift"),
                           "holdout": r.get("holdout"), "reason": "echo/side-effect", "depth": 1})

    leads = minimize_chains(leads)
    groups = group_chains(leads)
    findings = [plain_finding(k, ms) for k, ms in groups.items()]

    # inject token-alias finding once
    if alias_obs:
        findings.insert(0, {
            "id": "token-alias",
            "family": "token-alias",
            "pattern": "identity",
            "meaning": (
                "Unit-token aliasing: when a mob targets me, targettarget (and often nameplate/softenemy) "
                "refers to the same unit as player, so every player signal is duplicated on those tokens. "
                "Mining collapses aliases to a canonical token before scoring; this row reports the aliasing itself."
            ),
            "evidence": {
                "aliases": [o for o in alias_obs if o.get("collapsed")][:12] or alias_obs[:12],
                "observed": alias_obs[:12],
                "n": len(alias_obs),
                "captures": res.get("captures") or [],
            },
            "status": "cross-run",
            "alreadyLive": False,
            "proposedRule": (
                "Offline: canonicalize tokens via same-frame payload identity + Ledger token→GUID before mining. "
                "Live: Ledger already caches token→GUID; avoid double-counting aliased tokens in attribution."
            ),
            "best": None,
        })

    # also promote strong 1-hop non-echo unknowns that matter (cd payload, dm7, etc.)
    promote_1hop(res, findings)

    for f in findings:
        if f["id"] in ("token-alias", "cd-payload-clear", "dm-type-7", "totem-heal-live",
                       "identity-interrupt", "elimination", "meter-frame-join") or f.get("priority"):
            f["priority"] = 1
    rank = {"cross-run": 0, "held-1": 1, "provisional": 2, "failed": 3}

    def sort_key(f):
        is_seq = (f.get("pattern") in ("sequence", "absence")
                  or str(f.get("id", "")).startswith(("seq:", "abs:")))
        return (
            0 if f.get("priority") else 1,
            rank.get(f.get("status"), 9),
            1 if is_seq else 0,
            -(f.get("evidence", {}).get("precision") or 0),
            -(f.get("evidence", {}).get("support") or 0),
        )
    findings.sort(key=sort_key)
    # dedupe by id (keep first = best after sort / upsert)
    dedup, seen = [], set()
    for f in findings:
        if f["id"] in seen:
            continue
        seen.add(f["id"])
        dedup.append(f)
    findings = dedup
    pri = [f for f in findings if f.get("priority")]
    # drop weak priority rows (e.g. elimination with prec<<0.3) except interrupt (support can be 1)
    def weak(f):
        if f["id"] == "identity-interrupt":
            return False
        ev = f.get("evidence") or {}
        if f["id"] == "elimination" and (ev.get("precision") or 0) < 0.3:
            return True
        return False
    pri = [f for f in pri if not weak(f)]
    rest = [f for f in findings if not f.get("priority")]
    # drop filler chains that only restate priority findings (dm7 / totem / swing mirrors)
    def is_filler(f):
        hops = " || ".join((f.get("evidence") or {}).get("hops") or [])
        iid = f.get("id") or ""
        if iid.startswith("seq:") or iid.startswith("abs:"):
            return True
        if "SWING_DAMAGE|npc>me" in hops or "SWING_DAMAGE_LANDED|npc>me" in hops:
            return True  # covered by dm-type-7
        if "6371" in hops or "SPELL_PERIODIC_HEAL|mine" in hops:
            return True  # covered by totem-heal-live / meter-frame-join
        if "SPELL_SUMMON|me>mine" in hops:
            return True
        if "SWING_DAMAGE|me>npc" in hops or "SWING_DAMAGE_LANDED|me>npc" in hops:
            return True  # own swing — known
        if "SPELL_CAST_SUCCESS|me>none" in hops and "TOTEM" in hops:
            return True
        if "SPELL_CAST_SUCCESS|me>none" in hops and "SUCCEEDED" in hops:
            return True  # own cast echo
        return False
    rest = [f for f in rest if not is_filler(f)]
    findings = (pri + rest)[:max_findings]
    res["findings"] = findings
    res["echoes"] = echoes[:80]
    res["higher"] = leads  # replace with minimized non-echo leads
    return findings


def promote_1hop(res, findings):
    """Force-include high-value findings with best 1-hop/HO evidence (upsert)."""
    by_id = {f["id"]: i for i, f in enumerate(findings)}

    def upsert(fid, finding):
        finding["priority"] = 1
        if fid in by_id:
            findings[by_id[fid]] = finding
        else:
            by_id[fid] = len(findings)
            findings.append(finding)

    # --- CD payload: prefer live->truth arg0=ID -> SPELL_CAST_SUCCESS spell=ID ---
    cd = []
    for r in res.get("rules") or []:
        if r.get("kind") != "live->truth":
            continue
        m = re.search(r"SPELL_UPDATE_COOLDOWN\|arg0=(\d{3,})", r.get("a", ""))
        m2 = re.search(r"SPELL_CAST_SUCCESS\|me>\w+\|spell=(\d{3,})", r.get("b", ""))
        if m and m2 and m.group(1) == m2.group(1):
            annotate_status(r)
            apply_lift_smoothing(r)
            cd.append(r)
    if cd:
        best = max(cd, key=lambda r: (1 if (r.get("precision") or 0) >= 0.999 else 0, r.get("support") or 0, r.get("precision") or 0))
        n_held_max = max(
            sum(1 for v in (r.get("holdout") or {}).values() if v.get("status") == "held") for r in cd)
        st = "cross-run" if n_held_max >= 2 else ("held-1" if n_held_max == 1 else best.get("status"))
        sid = re.search(r"arg0=(\d+)", best["a"]).group(1)
        upsert("cd-payload-clear", {
            "id": "cd-payload-clear", "family": "cd-payload-clear", "pattern": "1hop",
            "meaning": (
                "SPELL_UPDATE_COOLDOWN carries my spellID in the clear during combat "
                "(arg0=%s matched SPELL_CAST_SUCCESS spell=%s, support %s/%s, prec %s). "
                "arg3 is the GCD start-recovery category (133 = on GCD, 0 = off). "
                "Already wired into CooldownTracker via HS:CDPayload (v2.2.4) — no new Lua needed."
                % (sid, sid, best.get("support"), best.get("nA"), best.get("precision"))
            ),
            "evidence": {
                "hops": [best["a"], best["b"]], "support": best.get("support"), "nA": best.get("nA"),
                "precision": best.get("precision"), "lift": best.get("lift"),
                "liftLo": best.get("liftLo"), "liftHi": best.get("liftHi"),
                "captures": sorted({r.get("capture") for r in cd}), "variants": len(cd), "depth": 1,
            },
            "status": st, "alreadyLive": True, "proposedRule": None, "best": best,
        })

    # --- DM type 7 ---
    dm7 = []
    for r in res.get("rules") or []:
        blob = r.get("a", "") + " -> " + r.get("b", "")
        if "DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=7" in blob and (
                "SWING_DAMAGE|npc>me" in blob or "SWING_DAMAGE_LANDED|npc>me" in blob):
            annotate_status(r)
            apply_lift_smoothing(r)
            dm7.append(r)
    if dm7:
        best = max(dm7, key=lambda r: (r.get("support") or 0, r.get("precision") or 0))
        n_held_max = max(
            sum(1 for v in (r.get("holdout") or {}).values() if v.get("status") == "held") for r in dm7)
        st = "cross-run" if n_held_max >= 2 else ("held-1" if n_held_max == 1 else best.get("status"))
        upsert("dm-type-7", {
            "id": "dm-type-7", "family": "dm-type-7", "pattern": "1hop",
            "meaning": (
                "DAMAGE_METER update type 7 fires on every enemy melee hit on me "
                "(best %s/%s, prec %s)."
                % (best.get("support"), best.get("nA"), best.get("precision"))
            ),
            "evidence": {
                "hops": [best["a"], best["b"]], "support": best.get("support"), "nA": best.get("nA"),
                "precision": best.get("precision"), "lift": best.get("lift"),
                "liftLo": best.get("liftLo"), "liftHi": best.get("liftHi"),
                "captures": sorted({r.get("capture") for r in dm7}), "variants": len(dm7), "depth": 1,
            },
            "status": st, "alreadyLive": False,
            "proposedRule": (
                "MeterType7: DAMAGE_METER_COMBAT_SESSION_UPDATED arg0=7 -> enemy melee taken; "
                "optional live hint when UNIT_COMBAT wound payload is secret."
            ),
            "best": best,
        })

    # --- Interrupt (1-hop or HO); provisional OK ---
    intr = []
    for r in (res.get("rules") or []) + (res.get("rare") or []):
        blob = r.get("a", "") + " -> " + r.get("b", "")
        if ("INTERRUPTED" in blob and ("SPELL_INTERRUPT" in blob or "SUCCEEDED" in blob)) or r.get("known") == "interrupt":
            annotate_status(r)
            apply_lift_smoothing(r)
            intr.append(r)
    for ch in list(res.get("higher") or []):
        blob = " || ".join(ch.get("hops") or [])
        if "INTERRUPTED" in blob and ("INTERRUPT" in blob or "SUCCEEDED" in blob):
            annotate_status(ch)
            apply_lift_smoothing(ch)
            intr.append(ch)
    if intr:
        best = max(intr, key=lambda r: (
            1 if (r.get("pattern") == "identity" or (r.get("depth") or 0) >= 2) else 0,
            r.get("support") or 0, r.get("precision") or 0))
        hops = best.get("hops") or [best.get("a"), best.get("b")]
        upsert("identity-interrupt", {
            "id": "identity-interrupt", "family": "identity-interrupt",
            "pattern": best.get("pattern") or "identity",
            "meaning": (
                best.get("reason") or
                "target cast interrupted (secret interrupter) + my interrupt-capable SUCCEEDED same frame "
                "-> the interrupt was mine (run 5 only so far; provisional until >=3 interrupts / holdout)."
            ),
            "evidence": {
                "hops": hops, "support": best.get("support"), "nA": best.get("nA"),
                "precision": best.get("precision"), "lift": best.get("lift"),
                "liftLo": best.get("liftLo"), "liftHi": best.get("liftHi"),
                "captures": sorted({r.get("capture") for r in intr if r.get("capture")}),
                "variants": len(intr), "depth": best.get("depth") or 1,
            },
            "status": best.get("status") or "provisional",
            "alreadyLive": False,
            "proposedRule": best.get("proposedRule") or (
                "InterruptAttribution: UNIT_SPELLCAST_INTERRUPTED on target/nameplate/softenemy in the same frame as "
                "UNIT_SPELLCAST_SUCCEEDED|player (interrupt spell) -> src=mine; confirm with DAMAGE_METER type-5 if present."
            ),
            "best": best,
        })


def markdown_distinct(res, top=30):
    fs = res.get("findings") or []
    L = ["", "## Distinct findings (v2.2.5)", "",
         "One row per real finding after token-alias collapse, lift smoothing, chain minimality, and echo filtering. "
         "Status: **cross-run** = held on ≥2 other captures; **held-1** = held on 1 other; **provisional** = single-run / "
         "one fight; **failed** = holdout failed. Proposed live rules are review-only unless marked already live.",
         "",
         "| # | id | status | already live? | meaning | best evidence | proposed rule |",
         "|---|---|---|---|---|---|---|"]
    for i, f in enumerate(fs[:top], 1):
        ev = f.get("evidence") or {}
        if f["id"] == "token-alias":
            evid = "%d alias edge(s); e.g. %s" % (
                ev.get("n") or 0,
                ", ".join("%s→%s" % (a["alias"], a["canon"]) for a in (ev.get("aliases") or [])[:4]) or "-")
        else:
            hops = ev.get("hops") or []
            evid = ("`%s` support %s/%s prec %s lift %s [%s–%s]; captures %s; %d variant(s)" % (
                " → ".join(hops[:3]), ev.get("support"), ev.get("nA"), ev.get("precision"),
                ev.get("lift"), ev.get("liftLo"), ev.get("liftHi"),
                ",".join(ev.get("captures") or []), ev.get("variants") or 1))
        meaning = (f.get("meaning") or "").replace("|", "/")
        if len(meaning) > 220:
            meaning = meaning[:217] + "..."
        prop = (f.get("proposedRule") or "—").replace("|", "/")
        if len(prop) > 120:
            prop = prop[:117] + "..."
        L.append("| %d | %s | %s | %s | %s | %s | %s |" % (
            i, f.get("id"), f.get("status"), "yes" if f.get("alreadyLive") else "no",
            meaning, evid, prop))
    # echoes appendix
    echoes = res.get("echoes") or []
    L += ["", "### Echoes / side-effects (appendix, not leads)", "",
          "%d pair(s)/chain(s) parked here (BAG/ACTIONBAR cooldown UI, mouse globals, SENT→SUCCEEDED, "
          "happiness, range checks, etc.) unless they uniquely carry a clear combat spellID." % len(echoes), ""]
    if echoes:
        L += ["| capture | pattern | hops (short) | support | prec | lift |",
              "|---|---|---|---|---|---|"]
        for e in echoes[:25]:
            hops = e.get("hops") or [e.get("a"), e.get("b")]
            L.append("| %s | %s | %s | %s | %s | %s |" % (
                e.get("capture"), e.get("pattern"),
                " → ".join((h or "")[:40] for h in hops[:3] if h),
                e.get("support"), e.get("precision"), e.get("lift")))
    return L
