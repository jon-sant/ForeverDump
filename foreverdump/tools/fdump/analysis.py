"""v2.2.4 `fdump.py analyze`: one command, the whole offline pipeline (coverage + HSM replay, knowledge lint and reality
cross-check, live verification join, miss explainer, co-occurrence miner, secrecy drift, recorder/taint health,
accuracy trending) -> ANALYSIS.md with a ranked list of leads: severity, evidence and exact timestamps (user zone)."""
import collections
import datetime
import json

from fdump import coverage as covmod, knowlint, verify_live, misses as missmod, correlate
from fdump import timing as timingmod, learned as learnedmod, tokenscan as tokmod, probes
from fdump.luasv import as_list

SEV = {"high": 0, "medium": 1, "low": 2, "info": 3}


def ts(t):
    if not isinstance(t, (int, float)) or t < 1e9:
        return str(t)
    from fdump import timefmt
    return timefmt.clock(t, "%H:%M:%S.%f")[:12]


def accuracy_table(cov, ver=None):
    """per-rule accuracy for trending: attribution categories (replay after), casts, cooldowns, overheal, interrupts, verdicts"""
    out = {}
    for cat, s in (((cov or {}).get("replay") or {}).get("after") or {}).get("scores", {}).items():
        if s.get("accuracy") is not None:
            att = s.get("attributed") or 0
            out["attr:" + cat] = {"accuracy": s["accuracy"], "n": s.get("scorable"), "coverage": s.get("coverage"),
                                  "falseSelf": s.get("falseSelf", 0), "missedSelf": s.get("missedSelf", 0),
                                  "precision": round(100.0 * s.get("correct", 0) / att, 1) if att else None}
    # v2.2.16: per-rule false-self claims (first-class metric): accuracy = precision of the rule's "mine" claims
    for rule, m in ((cov or {}).get("ruleMetrics") or {}).items():
        if m.get("mine"):
            out["mine:" + rule] = {"accuracy": m.get("precision"), "n": m["mine"], "falseSelf": m.get("falseSelf", 0)}
    c = (cov or {}).get("casts") or {}
    if c.get("predicted"):
        out["enemy-cast-time"] = {"accuracy": round(100.0 * c.get("within150ms", 0) / c["predicted"], 1), "n": c["predicted"], "mae": c.get("mae")}
    oh = (cov or {}).get("overheal") or {}
    if oh.get("estimated"):
        out["overheal-estimate"] = {"accuracy": round(100.0 * oh.get("exact", 0) / oh["estimated"], 1), "n": oh["estimated"], "mae": oh.get("mae")}
    cd = ((cov or {}).get("cooldowns") or {}).get("counts") or {}
    judged = cd.get("confirms", 0) + cd.get("contradicts", 0)
    if judged:
        out["cooldown-fail"] = {"accuracy": round(100.0 * cd.get("confirms", 0) / judged, 1), "n": judged}
    for k, a in ((ver or {}).get("accuracy") or {}).items():
        if a.get("accuracy") is not None:
            out["verify:" + k] = {"accuracy": a["accuracy"], "n": a["n"], "coverage": a["coverage"]}
    return out


def leads(ctx):
    L = []

    def add(sev, kind, title, evidence, times=(), fix=""):
        L.append({"severity": sev, "kind": kind, "title": title, "evidence": evidence, "times": [ts(t) for t in times][:8], "fix": fix})
    cov, kl, ver, mi, mn = ctx.get("coverage") or {}, ctx.get("knowlint") or {}, ctx.get("verify") or {}, ctx.get("misses") or {}, ctx.get("miner") or {}
    # v2.2.7: the live engine itself was down (runs 6/6b: Drift os error inside I.NewHSM at every capture start)
    eh = ctx.get("engineHealth") or {}
    latest = eh.get("latest")

    for x in eh.get("skippedTrailing") or []:
        add("info", "short trailing capture skipped", "capture %s lasted %s s with no combat" % (x.get("sid"), x.get("sec")),
            "analysed %s instead (likely an accidental FD_Logs ON/OFF click at the end)" % latest)

    def earlier(sid):
        return bool(latest) and isinstance(sid, str) and sid.startswith("cap-") and sid != latest
    for e in eh.get("captureErrors") or []:
        if earlier(e.get("sid")):
            add("info", "capture module failed (earlier capture)", "%s: %s" % (e.get("where"), e.get("err")),
                "session %s (not the newest capture %s)" % (e.get("sid"), latest))
            continue
        add("high", "capture module failed", "%s: %s" % (e.get("where"), e.get("err")), "session %s" % e.get("sid"),
            fix="that module did not run for the whole capture; tests/hsm_alive.lua must reproduce it before the fix")
    for s in eh.get("tapeHealth") or []:
        add("high" if s.get("hsm") == "down" else "medium", "engine %s (tape header)" % s.get("hsm"),
            "capture %s: failed %s" % (s.get("sid"), ", ".join(str(x) for x in s.get("failed") or []) or "?"),
            "replay hdr.stats", fix="the named helper failed at capture start; see selfErrors where=hsm:<name>")
    for s in eh.get("down") or []:
        if earlier(s.get("sid")):
            add("info", "live HSM did not run (earlier capture)", "capture %s" % s.get("sid"), "not the newest capture %s" % latest)
            continue
        add("high", "live HSM did not run", "capture %s: %d UNIT_COMBAT recorded, no HSM export, no decide records" % (
            s.get("sid"), s.get("unitCombat")), "inference sid/counters + replay tape",
            fix="every live attribution of this capture is offline replay only; fix the start error first")
    # v2.2.6 damage-meter three-way join
    for f in ((ctx.get("damageMeterJoin") or {}).get("fights") or []):
        for name, m in (f.get("metrics") or {}).items():
            if m.get("verdict") == "off":
                add("medium", "dm-reconcile off", "fight %s %s live=%s meter=%s log=%s" % (
                    f.get("n"), name, m.get("live"), m.get("meter"), m.get("log")),
                    str((m.get("comparisons") or {})), fix="inspect liveEst attribution vs C_DamageMeter vs CLEU for this fight")
            elif m.get("verdict") == "unexplained" and (m.get("meter") is not None or m.get("log") is not None):
                add("low", "dm-reconcile unexplained", "fight %s %s" % (f.get("n"), name),
                    "live=%s meter=%s log=%s" % (m.get("live"), m.get("meter"), m.get("log")))
        for uid, u in (f.get("units") or {}).items():
            if u.get("verdict") == "off":
                add("low", "dm-unit off", "fight %s unit %s" % (f.get("n"), uid),
                    str(u.get("meter")), fix="per-unit IdKey join; feed HO miner")
    # contradictions
    for r in kl.get("data", []) + kl.get("log", []):
        if r["severity"] in ("warn", "error"):
            add("high" if r["severity"] == "error" else "medium", "knowledge contradiction", "%s %s: %s" % (r["spell"], r.get("name"), r["check"]),
                r["detail"], fix="fix the parser / knowledge entry; the regression suite (tests/knowledge_parse.lua) gets a case")
    for r in ver.get("rows", []):
        if r["truth"] in ("refuted", "missed"):
            add("high", "verification refuted", "%s %s (spell %s)" % (r["kind"], r["v"], r.get("spell")), r.get("why") or "", [r.get("t")],
                "the live check disagreed with the log: inspect the rule inputs at that time")
    after = ((cov.get("replay") or {}).get("after") or {})
    for c in after.get("contradictions") or []:
        if isinstance(c, dict):
            add("medium", "HSM contradiction", str(c.get("kind") or c.get("rule") or "contradiction"), json.dumps(c, default=str)[:200], [c.get("t")])
    for e in after.get("errors") or []:
        add("high", "attribution error", "%s claimed %s, truth %s" % (e.get("cat"), e.get("claim"), e.get("truth")), "rule %s amount %s" % (e.get("rule"), e.get("amount")),
            [e.get("t")], "tighten the rule for this category")
    # verdict contradictions inside the engine (live/replay C verdicts)
    for v in cov.get("verdicts") or []:
        if isinstance(v, dict) and v.get("v") == "C":
            add("medium", "live check contradicted", "%s spell %s" % (v.get("kind"), v.get("spell")), "src %s, d %s, conf %s" % (v.get("src"), v.get("d"), v.get("conf")),
                [v.get("t")], "knowledge or model wrong for this case; it feeds the knowledge patch")
    # engine misses
    groups = missmod.group(mi.get("rows", []))
    sevmap = {"rule-gap": "high", "wrong-attribution": "high", "timing-window": "medium", "target-changed": "medium",
              "not-on-tracked-token": "medium", "amount-mismatch": "medium", "concurrent-source": "medium", "recorder-throttle": "low",
              "secret-payload": "low", "no-api-signal": "info", "outside-capture": "info", "no-log-record": "low"}
    for g in groups:
        times = [r["t"] for r in mi["rows"] if r["reason"] == g["reason"] and r["sub"] == g["sub"] and r["spell"] == g["spell"]]
        add(sevmap.get(g["reason"], "low"), "engine miss: " + g["reason"], "%dx %s %s %s>%s spell %s (%s)" % (g["n"], g["sub"], g["cat"], g["src"], g["dst"], g["spell"], g["ctx"]),
            g["detail"], times, missmod.HINT.get(g["reason"], ""))
    for u in mi.get("liveUnmatched", []):
        add("medium" if u["reason"] == "no-log-record" else "low", "unmatched live event", "%s %s on player (%s)" % (u["action"], u["amount"], u["ctx"]),
            u["reason"], [u["t"]], u["hint"])
    # secrecy flips / drift
    for x in (ctx.get("drift") or {}).get("newlySecret", [])[:20]:
        add("high", "secrecy flip", "newly secret: %s" % x, "vs baseline %s" % ctx.get("baseline"), fix="re-check the HSM inputs that read it")
    for x in (ctx.get("drift") or {}).get("newlyClear", [])[:20]:
        add("medium", "secrecy flip", "newly clear: %s" % x, "vs baseline %s" % ctx.get("baseline"), fix="new data available: consider using it")
    for u in ver.get("unexpected", [])[:40]:
        add("medium" if u.get("kind") in ("secrecy-flip", "payload-shape") else "low", "unexpected (live): " + str(u.get("kind")), str(u.get("key")),
            "%s (n=%s, ctx %s)" % (u.get("detail"), u.get("n"), u.get("c")))
    # unknown ids: my own spells in the log without knowledge
    for sid, n in (ctx.get("unknownSpells") or {}).items():
        add("low", "unknown id", "my spell %s cast %dx without a knowledge entry" % (sid, n), "log SPELL_CAST_SUCCESS by me", fix="it is queued by Knowledge.OnOwnCast on the next capture")
    # recorder health
    for k, n in sorted((ctx.get("recorder") or {}).get("dropped", {}).items(), key=lambda kv: -kv[1]):
        if k in ("UNIT_COMBAT", "UNIT_HEALTH", "UNIT_AURA", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED"):
            add("low", "recorder throttle", "RecordDB dropped %d %s" % (n, k), "5/s per-event cap; CombatLogDB kept %s/%s; the HSM gets every event (own frame)" % (
                (ctx.get("recorder") or {}).get("clKept"), (ctx.get("recorder") or {}).get("clTotal")), fix="offline matcher uses CombatLogDB first")
    # taint
    t = ctx.get("taint") or {}
    for c, n in (t.get("byClass") or {}).items():
        if c in ("unexpected", "blizzard-frame", "probe-blocked"):
            add("high", "taint", "%d %s taint entr%s" % (n, c, "y" if n == 1 else "ies"), "taint.log", fix="see `fdump.py taint`")
    # accuracy changes vs previous captures
    hist = ctx.get("history") or []
    if hist:
        prev = hist[-1]
        for k, a in (ctx.get("accuracy") or {}).items():
            p = (prev.get("accuracy") or {}).get(k)
            if p and a.get("accuracy") is not None and p.get("accuracy") is not None and abs(a["accuracy"] - p["accuracy"]) >= 5:
                worse = a["accuracy"] < p["accuracy"]
                add("medium" if worse else "info", "accuracy change", "%s %s -> %s%% (vs %s)" % (k, p["accuracy"], a["accuracy"], prev["label"]),
                    "n %s -> %s" % (p.get("n"), a.get("n")))
    # miner: new correlations that held on other captures, rare frame-exact pairs with id match
    for r in mn.get("rules", []):
        held = sum(1 for v in r["holdout"].values() if v["status"] == "held")
        if r["known"] is None and held >= 1 and r["kind"] != "truth->truth" and r["capture"] == ctx.get("label"):
            if r["kind"] == "live->live" and not any(x in r["a"] + r["b"] for x in ("UNIT_", "BAG_UPDATE_COOLDOWN", "SPELL_", "PLAYER_TOTEM")):
                continue
            add("info", "miner: new correlation", "`%s` ~ `%s` (%d ms)" % (r["a"], r["b"], int(r["window"] * 1000)),
                "support %d/%d, precision %s, recall %s, lift %s, held on %d other capture(s)" % (r["support"], r["nA"], r["precision"], r["recall"], r["lift"], held))
    # v2.2.4 spell timing: known answers (totems 1.0 s, Lightning Shield 1.5 s) are a permanent regression check
    tm = ctx.get("timing") or {}
    for r in (tm.get("report") or {}).get("knownAnswers", []):
        if not r["ok"]:
            add("high", "known-answer mismatch", "spell %s (%s) known GCD %.1f s" % (r["spell"], r["label"], r["known"]), r["why"] + " in " + r["capture"],
                fix="the seed / tracker must never contradict a known answer: check the log span and the GCD learner")
    for c in (tm.get("report") or {}).get("conflicts", []):
        add("medium", "timing conflict", "spell %s %s: seed %s vs new %s" % (c["spell"], c["field"], c["seed"], c["new"]), "source %s, capture %s" % (c["source"], c["capture"]),
            fix="flagged, seed kept; review, then `fdump analyze --write-seed`")
    for p_ in (tm.get("report") or {}).get("promoted", []):
        add("info", "timing promoted", "spell %s %s = %s" % (p_["spell"], p_["field"], p_["value"]), p_["why"])
    lr = (ctx.get("learned") or {}).get("report") or {}
    for c in lr.get("conflicts", []):
        add("medium", "learned conflict", "%s %s %s: seed %s vs new %s" % (c.get("what", "spell"), c.get("spell", c.get("key")), c.get("field"), c.get("seed"), c.get("new")),
            "capture %s" % c.get("capture"), fix="drift proposal: review, then `--write-seed`")
    for p_ in lr.get("proposals", []):
        add("medium", "drift proposal", "%s %s: %s -> %s" % (p_.get("kind"), p_.get("key"), p_.get("old"), p_.get("new")),
            "n %s, build %s, %s (live drift guard flagged it)" % (p_.get("n"), p_.get("build"), p_.get("date")), fix="`fdump analyze --write-seed` adopts it")
    for sev_, kind, title, ev in tokmod.leads(ctx.get("tokens") or {}):
        add(sev_, kind, title, ev, fix="TOKENS.md")
    # v2.2.5+ higher-order chains → ANALYSIS leads (kept alongside distinct findings; never drop HO coverage)
    for ch in ((ctx.get("miner") or {}).get("higher") or [])[:40]:
        hops = ch.get("hops") or ch.get("path") or []
        title = " → ".join(str(h) for h in hops[:6])
        if not title:
            title = ch.get("proposedRule") or ch.get("pattern") or "chain"
        add("info" if ch.get("status") in ("provisional", None) else "low",
            "higher-order: " + str(ch.get("pattern") or ch.get("kind") or "chain"),
            title,
            "depth %s, support %s, prec %s, lift %s, status %s" % (
                ch.get("depth"), ch.get("support"), ch.get("precision"), ch.get("lift"), ch.get("status")),
            [], fix=ch.get("proposedRule") or "")
    for f in ((ctx.get("miner") or {}).get("findings") or []):
        st = f.get("status") or "provisional"
        sev = "medium" if st == "cross-run" and not f.get("alreadyLive") else (
            "low" if st in ("cross-run", "held-1") else "info")
        ev = f.get("evidence") or {}
        add(sev, "finding: " + str(f.get("id")), f.get("meaning") or f.get("id"),
            "status %s, alreadyLive %s, support %s/%s, prec %s, lift %s, captures %s" % (
                st, f.get("alreadyLive"), ev.get("support"), ev.get("nA"), ev.get("precision"),
                ev.get("lift"), ",".join(ev.get("captures") or [])),
            [], fix=f.get("proposedRule") or ("(already live)" if f.get("alreadyLive") else ""))
    L.sort(key=lambda x: (SEV[x["severity"]], x["kind"]))
    # collapse the long tail of identical info leads
    return L


def trending_md(rows):
    keys = sorted(set(k for r in rows for k in (r.get("accuracy") or {})))
    if not keys:
        return []
    L = ["## Rule accuracy trending", "", "Current library replayed over every capture (pre-2.2.4 captures have no live verify ring: replay).", "",
         "| rule | " + " | ".join(r["label"] for r in rows) + " |", "|---|" + "---|" * len(rows)]
    for k in keys:
        cells = []
        for r in rows:
            a = (r.get("accuracy") or {}).get(k)
            cells.append("%s%% (n=%s)" % (a["accuracy"], a.get("n")) if a else "-")
        L.append("| %s | %s |" % (k, " | ".join(cells)))
    return L + [""]


def markdown(ctx):
    ls = ctx["leads"]
    sev = collections.Counter(x["severity"] for x in ls)
    L = ["# ANALYSIS: %s" % ctx.get("label"), "",
         "Generated by `fdump.py analyze`. Leads are ranked by severity (high > medium > low > info); times are box-local (ET).", "",
         "Summary: %s." % ", ".join("%s %d" % (k, sev.get(k, 0)) for k in ("high", "medium", "low", "info")), "",
         "| # | severity | kind | lead | evidence | times | what would fix it |", "|---|---|---|---|---|---|---|"]
    info_n = 0
    for i, x in enumerate(ls, 1):
        if x["severity"] == "info":
            info_n += 1
            if info_n > 25:
                continue
        L.append("| %d | %s | %s | %s | %s | %s | %s |" % (i, x["severity"], x["kind"], x["title"].replace("|", "/"), str(x["evidence"]).replace("|", "/"),
                                                      ", ".join(x["times"]), x["fix"]))
    if info_n > 25:
        L.append("| | info | ... | %d more info lead(s) in analysis.json | | | |" % (info_n - 25))
    L.append("")
    L += trending_md((ctx.get("history") or []) + [{"label": ctx.get("label"), "accuracy": ctx.get("accuracy")}])
    if ctx.get("verifyMd"):
        L += [ctx["verifyMd"].replace("# VERIFY", "## VERIFY", 1)]
    if ctx.get("missesMd"):
        L += [ctx["missesMd"]]
    if ctx.get("minerMd"):
        L += [ctx["minerMd"]]
    if ctx.get("damageMeterJoinMd"):
        L += [ctx["damageMeterJoinMd"]]
    if ctx.get("knowlintMd"):
        L += [ctx["knowlintMd"]]
    if ctx.get("timingMd"):
        L += [ctx["timingMd"]]
    if ctx.get("learnedMd"):
        L += [ctx["learnedMd"]]
    if ctx.get("tokens"):
        b = ctx["tokens"].get("builds") or {}
        L += ["## Token matrix", "", "%d build(s), %d matrix row(s), %d change alert(s): see TOKENS.md." % (
            len(b), sum(len(x["rows"]) for x in b.values()), len(ctx["tokens"].get("changes") or [])), ""]
    return "\n".join(L) + "\n"


def unknown_spells(dump, fx, player):
    kdb = (dump.db.get("knowledge") or {}) if isinstance(getattr(dump, "db", None), dict) else {}
    known = set()
    for b, d in kdb.items():
        for sid in ((d or {}).get("spells") or {}):
            try:
                known.add(int(sid))
            except (TypeError, ValueError):
                pass
    c = collections.Counter(e["a"][11] for e in fx.get("events", []) if e.get("cleu") and e["sub"] == "SPELL_CAST_SUCCESS" and e["a"][3] == player
                            and isinstance(e["a"][11], int))
    return {sid: n for sid, n in c.items() if sid not in known}


def recorder(dump):
    cs = as_list((dump.combatlog or {}).get("sessions"))
    rs = as_list((dump.record or {}).get("sessions"))
    c, r = (cs[-1] if cs else {}), (rs[-1] if rs else {})
    return {"clKept": c.get("kept"), "clTotal": c.get("total"), "clOverwritten": c.get("overwritten"), "recKept": r.get("kept"),
            "dropped": dict(r.get("dropped") or {}), "perEventPerSec": (r.get("config") or {}).get("perEventPerSec")}


def engine_health(dump):
    """v2.2.7 (runs 6/6b): did the live HSM actually run in each capture? A capture-module start error or a capture with
    combat but no HSM export / no decide records means every live attribution of that capture is missing."""
    from fdump.dump import as_list
    out = {"captureErrors": [], "sessions": []}
    for e in as_list(dump.log.get("selfErrors")):
        if isinstance(e, dict) and str(e.get("where") or "").startswith(("capture:", "hsm:")):
            out["captureErrors"].append({"sid": e.get("sid"), "where": e.get("where"), "err": str(e.get("err"))[:200]})
    inf = dump.log.get("inference") or {}
    runs = {}
    for s in [inf] + [h for h in as_list(inf.get("history")) if isinstance(h, dict)]:
        if s.get("sid"):
            runs[s["sid"]] = bool(s.get("counters")) or bool(as_list(s.get("signals")))
    tapes = {}
    for s in as_list((dump.log.get("replay") or {}).get("sessions")):
        if isinstance(s, dict):
            sid = (s.get("hdr") or {}).get("sid") or s.get("sid")
            n = sum(1 for r in as_list(s.get("tape")) if isinstance(r, dict) and r.get("k") == "decide")
            # v2.2.8: the tape header states the engine health at OFF (hdr.stats.hsm up/degraded/down)
            stt = (s.get("hdr") or {}).get("stats") or {}
            if isinstance(stt, dict) and stt.get("hsm") in ("down", "degraded"):
                out.setdefault("tapeHealth", []).append({"sid": sid, "hsm": stt.get("hsm"),
                                                         "failed": as_list(stt.get("hsmFailed"))})
            if sid:
                tapes[sid] = tapes.get(sid, 0) + n
    seen = set()
    for c in as_list((dump.combatlog or {}).get("sessions")):
        if not isinstance(c, dict):
            continue
        sid = c.get("captureSid") or c.get("sid")
        uc = sum(1 for e in as_list(c.get("events")) if isinstance(e, dict) and e.get("e") == "UNIT_COMBAT")
        if sid in seen:
            continue
        seen.add(sid)
        out["sessions"].append({"sid": sid, "unitCombat": uc, "hsmExported": runs.get(sid, False), "decide": tapes.get(sid)})
    out["down"] = [s for s in out["sessions"] if s["unitCombat"] > 0 and not s["hsmExported"] and not s["decide"]]
    # v2.2.9 (run 8): one SV carries every earlier capture; only the NEWEST capture's engine problems are leads for this
    # run (run 8 led with three Drift/os failures from captures v2.2.7 had already fixed). Older ones stay, as info.
    sids = [x.get("sid") for x in out["sessions"] + out["captureErrors"] if isinstance(x.get("sid"), str)]
    sids += [sid for sid in tapes if isinstance(sid, str)]
    caps = sorted(x for x in sids if x.startswith("cap-"))
    out["latest"] = caps[-1] if caps else None
    try:
        from fdump.coverage import main_session
        ms, skipped = main_session((dump.combatlog or {}).get("sessions"))
        if ms.get("captureSid"):
            out["latest"] = ms["captureSid"]
        out["skippedTrailing"] = [{"sid": x.get("captureSid"), "sec": round((x.get("stopTime") or 0) - (x.get("startTime") or 0), 1)}
                                  for x in skipped]
    except Exception:   # noqa: BLE001 - health must never break analyze
        pass
    return out


def run(dump, fx, player, label="capture", taint=None, baseline=None, history_caps=(), lua="lua5.1",
        correlate_profile="full", correlate_higher=True):
    """history_caps: [(label, dump, fx, player)] older captures (miner holdout + trending).
    correlate_profile: 'full' (heavy) or 'quick'; correlate_higher enables v2.2.5 HO chains."""
    from fdump import drift as driftmod, taintlog
    ctx = {"label": label}
    ctx["engineHealth"] = engine_health(dump)
    cov = covmod.analyze(dump, fx, player, lua=lua)
    ctx["coverage"] = cov
    from fdump import damagemeter_join as dmjoin
    ctx["damageMeterJoin"] = dmjoin.join(dump, cov)
    ctx["damageMeterJoinMd"] = "\n".join(dmjoin.markdown(ctx["damageMeterJoin"]))
    ctx["damageMeterFacts"] = dmjoin.correlation_facts(ctx["damageMeterJoin"])
    kl = knowlint.analyze(dump, fx, player, lua=lua)
    ctx["knowlint"] = kl
    ctx["knowlintMd"] = knowlint.markdown(kl)
    ver = verify_live.analyze(dump, fx, player, cov, kl, cov["_ctx"]["cls"], replay_verdicts=cov.get("verdicts"))
    ctx["verify"] = ver
    ctx["verifyMd"] = verify_live.markdown(ver)
    mi = missmod.explain(cov, fx, player)
    ctx["misses"] = mi
    ctx["missesMd"] = missmod.markdown(mi, ts)
    caps = list(history_caps) + [(label, dump, fx, player)]
    mn = correlate.run(caps, profile=correlate_profile, higher=correlate_higher)
    mn["damageMeterFacts"] = ctx.get("damageMeterFacts") or []
    # meter OFF cells as separate regression leads (do not pollute HO distinct-findings status vocab)
    dm_findings = []
    for fact in mn["damageMeterFacts"]:
        if fact.get("verdict") != "off":
            continue
        dm_findings.append({
            "id": "dm-threeway-off",
            "title": "live/meter/log disagree on fight %s %s" % (fact.get("fight"), fact.get("metric") or fact.get("unit")),
            "kind": "dm-threeway",
            "status": "provisional",
            "alreadyLive": True,
            "evidence": fact,
            "proposedRule": "reconcile liveEst vs C_DamageMeter vs CLEU per IdKey",
        })
    mn["damageMeterFindings"] = dm_findings
    ctx["miner"] = mn
    ctx["minerMd"] = correlate.markdown(mn)
    if baseline:
        try:
            ctx["drift"] = driftmod.compare(driftmod.load(baseline), driftmod.from_dump(dump))
            ctx["baseline"] = baseline
        except Exception as ex:   # noqa: BLE001 - a broken baseline must not stop the analysis
            ctx["drift"] = {"error": str(ex)}
    if taint:
        t = taintlog.parse(taint)
        ctx["taint"] = {"count": t["count"], "byClass": t["summary"].get("byClass")}
    ctx["unknownSpells"] = unknown_spells(dump, fx, player)
    ctx["recorder"] = recorder(dump)
    ctx["accuracy"] = accuracy_table(cov, ver)
    hist = []
    for hl, hd, hfx, hp in history_caps:
        hc = covmod.analyze(hd, hfx, hp, lua=lua)
        hk = knowlint.analyze(hd, hfx, hp, lua=lua)
        hv = verify_live.analyze(hd, hfx, hp, hc, hk, hc["_ctx"]["cls"], replay_verdicts=hc.get("verdicts"))
        hist.append({"label": hl, "accuracy": accuracy_table(hc, hv)})
    ctx["history"] = hist
    seeds(ctx, dump, fx, player, label, history_caps)
    ctx["leads"] = leads(ctx)
    return ctx


def seeds(ctx, dump, fx, player, label, history_caps=()):
    """v2.2.4: evidence from every capture -> merged spell-timing and learned seeds (in memory; `--write-seed` writes them).
    Merges are idempotent per capture id, so re-running analyze on the same captures changes nothing."""
    caps = list(history_caps) + [(label, dump, fx, player)]
    tev = [timingmod.evidence(d, f, p, label=lab) for lab, d, f, p in caps]
    tseed, trep = timingmod.merge(timingmod.load_seed(), tev)
    ctx["timing"] = {"seed": tseed, "report": trep, "evidence": len(tev)}
    ctx["timingMd"] = timingmod.markdown(tseed, trep)
    seen = set()
    lev = []
    for lab, d, f, p in caps:
        date, build = timingmod._date(d)
        if f and p:
            lev.append(learnedmod.from_log(f, p, label=lab, seen=seen, build=build, date=date))
        sv = learnedmod.from_sv(d, label=lab)
        if sv["spells"] or sv["npcs"] or sv["drift"]:
            lev.append(sv)
    lseed, lrep = learnedmod.merge(learnedmod.load_seed(), lev)
    ctx["learned"] = {"seed": lseed, "report": lrep, "evidence": len(lev)}
    ctx["learnedMd"] = learnedmod.markdown(lseed, lrep)
    ctx["tokens"] = tokmod.analyze(dump)
    ctx["tokensMd"] = tokmod.markdown(ctx["tokens"], probes.tokens(dump))
    return ctx


def public(ctx):
    """JSON-safe summary (no in-memory context, no per-event miner tables)"""
    return {"label": ctx["label"], "leads": ctx["leads"], "accuracy": ctx["accuracy"], "history": ctx["history"],
            "verify": {k: v for k, v in ctx["verify"].items() if k != "rows"}, "misses": {"byReason": ctx["misses"]["byReason"],
            "liveUnmatched": ctx["misses"]["liveUnmatched"]}, "recorder": ctx["recorder"], "unknownSpells": ctx["unknownSpells"],
            "taint": ctx.get("taint"), "miner": {"captures": ctx["miner"]["captures"], "rules": _per_capture(ctx["miner"]["rules"], 150),
                                                  "rare": _per_capture(ctx["miner"]["rare"], 80), "durations": ctx["miner"]["durations"],
                                                  "higher": (ctx["miner"].get("higher") or [])[:120],
                                                  "findings": (ctx["miner"].get("findings") or [])[:40],
                                                  "elapsedSec": ctx["miner"].get("elapsedSec"), "profile": ctx["miner"].get("profile")},
            "drift": {k: ctx["drift"].get(k) for k in ("newlySecret", "newlyClear", "buildBump")} if ctx.get("drift") else None,
            "timing": {"report": (ctx.get("timing") or {}).get("report"), "spells": len(((ctx.get("timing") or {}).get("seed") or {}).get("spells") or {})},
            "learned": {"report": (ctx.get("learned") or {}).get("report"), "spells": len(((ctx.get("learned") or {}).get("seed") or {}).get("spells") or {}),
                        "npcs": len(((ctx.get("learned") or {}).get("seed") or {}).get("npcs") or {})},
            "tokens": {b: {"contexts": x["contexts"], "rows": len(x["rows"]), "cost": x["cost"], "dup": x["dup"], "alias": x["alias"]}
                       for b, x in ((ctx.get("tokens") or {}).get("builds") or {}).items()},
            "cdLine": _cdline_public((ctx.get("knowlint") or {}).get("cdLine")),
            "cdTracker": {k: ((ctx.get("coverage") or {}).get("cdtrack") or {}).get(k) for k in ("casts", "counts", "nyr")}}


def _per_capture(rows, cap):
    """first `cap` rows of every capture (rows are already ranked per capture), unknown pairs first"""
    out, n = [], {}
    for r in sorted(rows, key=lambda r: r.get("known") is not None):
        k = r.get("capture")
        if n.get(k, 0) < cap:
            n[k] = n.get(k, 0) + 1
            out.append(r)
    return out


def _cdline_public(c):
    """tooltip extra-line cooldown hypothesis: verdict + per-sample evidence (spell ids/names are game data; counts only)"""
    if not c:
        return None
    keep = ("spell", "name", "ctx", "lines", "extraLine", "onCooldownByOwnCast", "onCooldownShared")
    return {"verdict": c.get("verdict"), "proven": c.get("proven"), "scorable": c.get("scorable"), "agree": c.get("agree"),
            "agreeShared": c.get("agreeShared"), "sampleTimes": c.get("sampleTimes"),
            "rows": [{k: r.get(k) for k in keep} for r in c.get("rows") or []], "probe": c.get("probe") or []}
