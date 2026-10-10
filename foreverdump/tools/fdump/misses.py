"""v2.2.4 miss explainer: every log event the live engine missed or got wrong, each with a reason class and a "what would
fix it" hint. Log-centric (events from/to me, my totems, my target) plus live-centric (live events with no log
counterpart, e.g. the 227 heal after the log file ended). Works on the coverage context (coverage.analyze()["_ctx"])."""
import collections

from fdump.coverage import LAG_BEFORE, LAG_AFTER, _args, _cats, _secret

HINT = {
    "outside-capture": "nothing to fix in the engine: start the file log before /fd capture and stop it after (or ignore)",
    "after-log-end": "the file log stopped before the live capture: run /combatlog until after /fd stop",
    "not-on-tracked-token": "track the unit on nameplate/softenemy tokens through the Identity ledger (token->GUID) and feed it to the HSM",
    "target-changed": "keep the previous target GUID for 0.4 s after PLAYER_TARGET_CHANGED (ledger 'token' entry) and match against both",
    "no-api-signal": "engine limit: no live event carries this (use C_DamageMeter totals after combat, or accept the gap)",
    "secret-payload": "signal arrives but its payload is secret: resolve through the Ledger (cached clear value) or elimination",
    "timing-window": "the live signal exists but outside the matching window: widen the rule window (see the observed lag)",
    "amount-mismatch": "a live signal is in the window with a different amount (partial absorb/resist/overkill): match with tolerance",
    "rule-gap": "visible and clear but not attributed: add or extend an HSM rule (see the rule column)",
    "wrong-attribution": "attributed to the wrong source: tighten the rule (cast-frame / DM per-source) for this category",
    "concurrent-source": "another source hit the same unit in the same window: use cast-frame evidence or the DM per-source delta",
    "recorder-throttle": "the HSM had it, the offline recorder dropped it (5/s cap): raise RecordDB cap for this event or rely on CombatLogDB",
    "no-log-record": "live event with no file-log counterpart in the window: check the log filter / lag",
}


def _rel(e, player, mine, tg):
    a = e["a"]
    return a[3] == player or a[3] in mine or a[7] == player or (tg and (a[7] == tg or a[3] == tg))


def explain(cov, fx, player):
    ctx = cov.get("_ctx") or {}
    live, cls = ctx.get("live"), ctx.get("cls")
    if live is None:
        return {"rows": [], "byReason": {}, "liveUnmatched": []}
    lo, hi = live.span
    ev = [e for e in fx.get("events", []) if e.get("cleu")]
    log_lo = min((e["t"] for e in ev), default=None)
    log_hi = max((e["t"] for e in ev), default=None)
    mine = set(e["a"][7] for e in ev if e["sub"] == "SPELL_SUMMON" and e["a"][3] == player)
    tchg = [x["te"] for x in live.by.get("PLAYER_TARGET_CHANGED", [])]
    rec_rate = collections.Counter(int(x["te"]) for x in live.record)
    rows = []
    refs, attrs = ctx.get("refs") or {}, (ctx.get("attrs") or {}).get("after") or []
    aura_ok = [refs[x["ref"]] for x in attrs if x.get("k") == "aura" and x.get("src") == "mine" and x.get("ref") in refs]

    def resolved(t, tok):
        return any(abs(r.get("t", 0) - t) <= 0.35 and (r.get("unit") == tok or (tok == "player" and r.get("unit") == "player")) for r in aura_ok)

    def add(e, cat, reason, detail=""):
        rows.append({"t": round(e["t"], 3), "sub": e["sub"], "cat": cat, "src": cls(e["a"][3]), "dst": cls(e["a"][7]),
                     "spell": e["a"][11] if len(e["a"]) > 11 else None, "ctx": live.ctx(e["t"]), "reason": reason, "detail": detail,
                     "hint": HINT.get(reason, "")})

    for e in ev:
        t, a = e["t"], e["a"]
        tg = live.target_at(t)
        if not _rel(e, player, mine, tg):
            continue
        if lo is None or not (lo - 1 <= t <= hi + 1):
            continue
        tok = "player" if a[7] == player else ("target" if tg and a[7] == tg else None)
        for cat, d in _cats(e):
            if cat not in ("damage", "miss", "heal", "aura+", "aura-", "interrupt", "cast-start", "cast-success"):
                continue
            near_tc = any(abs(t - x) <= 0.4 for x in tchg)
            if cat in ("damage", "miss", "heal"):
                if a[7] in mine:
                    add(e, cat, "no-api-signal", "dst is my totem/pet: no unit token for it")
                    continue
                if tok is None:
                    add(e, cat, "target-changed" if near_tc else "not-on-tracked-token", "dst not player/target")
                    continue
                act = "HEAL" if cat == "heal" else ("WOUND" if cat == "damage" else None)

                def p(x, amt=True):
                    xa = _args(x)
                    if xa[:1] != [tok] or len(xa) < 2:
                        return False
                    if act and xa[1] != act:
                        return False
                    if not act and xa[1] in ("WOUND", "HEAL"):
                        return False
                    return (not amt) or act is None or (len(xa) > 3 and xa[3] == d.get("amount"))
                if live.near("UNIT_COMBAT", t, LAG_BEFORE, LAG_AFTER, pred=p):
                    continue
                w = live.near("UNIT_COMBAT", t, 3.0, 3.0, pred=p)
                if w:
                    add(e, cat, "timing-window", "live lag %.3f s" % (w["te"] - t))
                elif live.near("UNIT_COMBAT", t, LAG_BEFORE, LAG_AFTER, pred=lambda x: p(x, amt=False)):
                    add(e, cat, "amount-mismatch", "log %s, absorbed %s, resisted %s" % (d.get("amount"), d.get("absorbed"), d.get("resisted")))
                elif cat == "heal" and not d.get("amount"):
                    add(e, cat, "no-api-signal", "full overheal: UNIT_COMBAT carries no 0-amount heal")
                elif rec_rate.get(int(t), 0) >= 5 or rec_rate.get(int(t) + 1, 0) >= 5:
                    add(e, cat, "recorder-throttle", "RecordDB at its 5/s cap in this second")
                else:
                    add(e, cat, "no-api-signal" if live.ctx(t) == "combat" else "no-log-record", "no UNIT_COMBAT on %s" % tok)
            elif cat in ("aura+", "aura-"):
                if tok is None:
                    if a[3] == player or a[3] in mine:
                        add(e, cat, "target-changed" if near_tc else "not-on-tracked-token", "my aura on a non-token unit")
                    continue
                m = live.near("UNIT_AURA", t, 0.35, 0.35, pred=lambda x: _args(x)[:1] == [tok])
                if not m:
                    add(e, cat, "recorder-throttle" if rec_rate.get(int(t), 0) >= 5 else "no-api-signal", "no UNIT_AURA on %s" % tok)
                else:
                    pl = _args(m)[1] if len(_args(m)) > 1 and isinstance(_args(m)[1], dict) else {}
                    fld = "addedAuras" if cat == "aura+" else "removedAuraInstanceIDs"
                    if fld in pl and _secret(pl.get(fld)) and (a[3] == player or a[3] in mine):
                        if cat == "aura+" and resolved(t, tok):
                            continue      # the HSM attributed it to me anyway (cast-frame / ledger rule): not a miss
                        add(e, cat, "secret-payload", "%s secret (presence readable)" % fld)
            elif cat in ("cast-start", "cast-success") and cls(a[3]) == "npc":
                stok = "target" if tg and a[3] == tg else None
                if stok is None:
                    continue
                evn = "UNIT_SPELLCAST_START" if cat == "cast-start" else "UNIT_SPELLCAST_SUCCEEDED"
                if not live.near(evn, t, 0.3, 0.3, pred=lambda x: _args(x)[:1] == ["target"]):
                    add(e, cat, "target-changed" if near_tc else "no-api-signal", "no %s on target" % evn)
            elif cat == "interrupt" and tok:
                if not live.near("UNIT_SPELLCAST_INTERRUPTED", t, 0.3, 0.3, pred=lambda x: _args(x)[:1] == [tok]):
                    add(e, cat, "no-api-signal", "no UNIT_SPELLCAST_INTERRUPTED on %s" % tok)
    # engine attribution errors (replay 'after')
    for r in ((cov.get("replay") or {}).get("after") or {}).get("errors") or []:
        reason = "wrong-attribution" if r.get("claim") not in (None, "none") else "rule-gap"
        if r.get("truth") == "player":
            reason = "concurrent-source" if r.get("claim") == "mine" else reason
        rows.append({"t": r.get("t"), "sub": "HSM", "cat": r.get("cat"), "src": r.get("truth"), "dst": "-", "spell": None, "ctx": "combat",
                     "reason": reason, "detail": "claim %s by rule %s, amount %s" % (r.get("claim"), r.get("rule"), r.get("amount")),
                     "hint": HINT[reason]})
    # live-centric: player UNIT_COMBAT with no log counterpart
    unmatched = []
    seen = set()
    for x in live.by.get("UNIT_COMBAT", []):
        xa = _args(x)
        if xa[:1] != ["player"] or len(xa) < 4 or xa[1] not in ("HEAL", "WOUND") or not isinstance(xa[3], (int, float)):
            continue
        t = x["te"]
        if (round(t, 2), xa[1], xa[3]) in seen:
            continue          # the same event from CombatLogDB and RecordDB
        seen.add((round(t, 2), xa[1], xa[3]))
        sub = ("SPELL_HEAL", "SPELL_PERIODIC_HEAL") if xa[1] == "HEAL" else None
        hit = None
        for e in ev:
            if t - LAG_AFTER - 0.2 <= e["t"] <= t + LAG_BEFORE and e["a"][7] == player:
                if (sub is None or e["sub"] in sub):
                    am = [c[1].get("amount") for c in _cats(e)]
                    if xa[3] in am:
                        hit = e
                        break
        if hit is None:
            reason = "after-log-end" if log_hi is not None and t > log_hi else ("outside-capture" if log_lo is not None and t < log_lo else "no-log-record")
            unmatched.append({"t": round(t, 3), "action": xa[1], "amount": xa[3], "ctx": live.ctx(t), "reason": reason, "hint": HINT[reason]})
    by = collections.Counter(r["reason"] for r in rows)
    return {"rows": rows, "byReason": dict(by), "liveUnmatched": unmatched, "logSpan": (log_lo, log_hi), "liveSpan": (lo, hi)}


def group(rows):
    g = collections.OrderedDict()
    for r in rows:
        k = (r["sub"], r["cat"], r["src"], r["dst"], r["spell"], r["ctx"], r["reason"], r["detail"])
        x = g.setdefault(k, {"sub": r["sub"], "cat": r["cat"], "src": r["src"], "dst": r["dst"], "spell": r["spell"], "ctx": r["ctx"],
                             "reason": r["reason"], "detail": r["detail"], "first": r["t"], "last": r["t"], "n": 0})
        x["n"] += 1
        x["last"] = r["t"]
    return sorted(g.values(), key=lambda x: (-x["n"], x["first"] or 0))


def markdown(res, fmt_t=None):
    f = fmt_t or (lambda t: "%s" % t)
    L = ["## Miss explainer", "", "| reason | n | what would fix it |", "|---|---|---|"]
    for k, n in sorted(res["byReason"].items(), key=lambda kv: -kv[1]):
        L.append("| %s | %d | %s |" % (k, n, HINT.get(k, "")))
    if res["rows"]:
        L += ["", "Grouped (first/last time, count):", "", "| first | last | n | event | cat | src>dst | spell | ctx | reason | detail |",
              "|---|---|---|---|---|---|---|---|---|---|"]
        for g in group(res["rows"])[:60]:
            L.append("| %s | %s | %d | %s | %s | %s>%s | %s | %s | %s | %s |" % (f(g["first"]), f(g["last"]), g["n"], g["sub"], g["cat"], g["src"],
                                                                         g["dst"], g["spell"], g["ctx"], g["reason"], g["detail"]))
    if res["liveUnmatched"]:
        L += ["", "Live events with no file-log counterpart:", "", "| time | action | amount | ctx | reason |", "|---|---|---|---|---|"]
        for u in res["liveUnmatched"]:
            L.append("| %s | %s | %s | %s | %s |" % (f(u["t"]), u["action"], u["amount"], u["ctx"], u["reason"]))
    return "\n".join(L) + "\n"
