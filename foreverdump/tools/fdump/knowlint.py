"""v2.2.4 knowledge semantic lint + reality cross-check (PERMANENT check, runs in every build via `fdump knowledge`
and `fdump analyze`).

* re-parses every stored description with the CURRENT addon parser (lua kparse.lua -> K.Parse/K.Lint) so older
  captures are judged by today's rules, and lists lint violations (lockout-as-aura, summon/imbue leaks, health-as-amount,
  unclassified duration phrases, period-as-duration)
* data checks: multi-cost spells keep every cost; tooltip header (N Mana / N yd range / N sec cooldown / cast time)
  vs GetSpellBaseCooldown / GetSpellInfo / GetSpellPowerCost; aura duration without any observed aura -> 'unverified'
* combat-log cross-check: aura applied->removed durations vs parsed, cooldown vs recast intervals and 'Not yet
  recovered' timing, damage/heal amounts vs the parsed range; spell -> applied aura id mapping (SPELL_CAST_SUCCESS ->
  SPELL_AURA_APPLIED, same source and destination, <= 0.3 s) merged with the live-learned map
* tooltip-line cooldown hypothesis: evidence table (line count per context vs the cooldown state from the log)
"""
import collections
import json
import os
import shutil
import subprocess
import tempfile

from fdump.inference import _lua_value

HERE = os.path.dirname(os.path.abspath(__file__))
RUNNER = os.path.join(HERE, "lua", "kparse.lua")
KLUA = os.path.join(HERE, "..", "..", "ForeverDump", "Knowledge.lua")


def spells(dump):
    kdb = dump.db.get("knowledge") if isinstance(getattr(dump, "db", None), dict) else None
    out = {}
    for b, bv in ((kdb or {}).items() if isinstance(kdb, dict) else []):
        for sid, e in (((bv or {}).get("spells") or {}).items() if isinstance(bv, dict) else []):
            try:
                out[int(sid)] = dict(e or {}, build=b)
            except (TypeError, ValueError):
                continue
    return out


def reparse(sp, lua="lua5.1", klua=KLUA):
    """{id: {parsed, lint, header}} from the current parser; None without lua"""
    if not shutil.which(lua):
        return None
    inp = {}
    for sid, e in sp.items():
        d = e.get("data") or {}
        tt = d.get("tooltip")
        if isinstance(tt, dict):
            tt = [tt[k] for k in sorted(tt, key=lambda x: int(x))]
        inp[sid] = {"text": d.get("description"), "tooltip": tt if isinstance(tt, list) else None}
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as f:
        f.write("return {\n")
        for sid, x in inp.items():
            f.write("[%d] = %s,\n" % (sid, _lua_value({k: v for k, v in x.items() if v is not None})))
        f.write("}\n")
        path = f.name
    try:
        r = subprocess.run([lua, RUNNER, os.path.abspath(klua), path], capture_output=True, text=True, timeout=60)
    finally:
        os.unlink(path)
    if r.returncode != 0:
        raise RuntimeError("kparse failed: " + r.stderr[-300:])
    raw = json.loads(r.stdout or "{}")
    return {int(k): v for k, v in raw.items()}


def _costs(d):
    c = d.get("costs")
    if isinstance(c, dict):
        c = [c[k] for k in sorted(c, key=lambda x: int(x))]
    return c if isinstance(c, list) else None


def data_checks(sp, rp, observed=None):
    rows = []
    legacy_costs = []
    observed = observed or {}
    for sid, e in sorted(sp.items()):
        d = e.get("data") or {}
        if not d:
            continue
        name = d.get("info.name")
        p = (rp or {}).get(sid, {}).get("parsed") or d.get("parsed") or {}
        h = (rp or {}).get(sid, {}).get("header") or d.get("header") or {}
        for v in (rp or {}).get(sid, {}).get("lint") or []:
            rows.append({"spell": sid, "name": name, "check": "lint:" + v.get("rule"), "severity": "error", "detail": v.get("detail")})
        old = d.get("parsed") or {}
        if rp and old.get("auraDuration") and not p.get("auraDuration"):
            rows.append({"spell": sid, "name": name, "check": "reparse-fixed", "severity": "info",
                         "detail": "stored parse had auraDuration=%s; current parser: %s" % (old.get("auraDuration"),
                                                                                            {k: p.get(k) for k in ("lockout", "interrupt", "summonDuration", "imbueDuration") if p.get(k)})})
        costs = _costs(d)
        if costs is None and d.get("cost") is not None:
            legacy_costs.append(sid)
        ctx = (e.get("ctx") or {}).get("ooc") or {}
        if costs is not None and isinstance(ctx.get("powerCost.n"), int) and ctx["powerCost.n"] != len(costs):
            rows.append({"spell": sid, "name": name, "check": "multi-cost", "severity": "error", "detail": "API returned %s cost(s), stored %d" % (ctx["powerCost.n"], len(costs))})
        # header vs structured APIs
        if h:
            bc = d.get("baseCooldown")
            if h.get("cooldown") is not None and isinstance(bc, (int, float)) and abs(h["cooldown"] - bc / 1000.0) > 0.05:
                rows.append({"spell": sid, "name": name, "check": "header-vs-api:cooldown", "severity": "warn", "detail": "tooltip %s s vs GetSpellBaseCooldown %s ms" % (h["cooldown"], bc)})
            if h.get("cooldown") is None and isinstance(bc, (int, float)) and bc > 1500:
                rows.append({"spell": sid, "name": name, "check": "header-vs-api:cooldown", "severity": "warn", "detail": "GetSpellBaseCooldown %s ms but no 'N sec cooldown' header" % bc})
            ct = d.get("info.castTime")
            if h.get("castTime") is not None and isinstance(ct, (int, float)) and abs(h["castTime"] - ct / 1000.0) > 0.05:
                rows.append({"spell": sid, "name": name, "check": "header-vs-api:castTime", "severity": "warn", "detail": "tooltip %s s vs GetSpellInfo.castTime %s ms" % (h["castTime"], ct)})
            mr = d.get("info.maxRange")
            if isinstance(h.get("range"), (int, float)) and isinstance(mr, (int, float)) and abs(h["range"] - mr) > 0.5:
                rows.append({"spell": sid, "name": name, "check": "header-vs-api:range", "severity": "warn", "detail": "tooltip %s yd vs GetSpellInfo.maxRange %s" % (h["range"], mr)})
            cost1 = (costs[0].get("cost") if costs else d.get("cost"))
            if h.get("cost") is not None and isinstance(cost1, (int, float)) and h["cost"] != cost1:
                rows.append({"spell": sid, "name": name, "check": "header-vs-api:cost", "severity": "warn", "detail": "tooltip %s vs GetSpellPowerCost %s" % (h["cost"], cost1)})
        if p.get("auraDuration") and not (e.get("learned") or {}).get("auraDuration") and not (e.get("learned") or {}).get("untilCancelled") \
                and not observed.get(sid, {}).get("auraDurations"):
            rows.append({"spell": sid, "name": name, "check": "unverified-aura", "severity": "note",
                         "detail": "parsed auraDuration %s s never observed (no clear aura live, none in the log)" % p["auraDuration"]})
    if legacy_costs:
        rows.append({"spell": "-", "name": "%d spell(s)" % len(legacy_costs), "check": "costs-legacy", "severity": "note",
                     "detail": "only the first power cost recorded (pre-2.2.4 capture); v2.2.4 keeps every cost entry"})
    return rows


def log_checks(sp, rp, fx, player):
    """parsed knowledge vs the combat log (my casts only)"""
    if not fx:
        return {"rows": [], "auraMap": {}, "observed": {}}
    ev = [e for e in fx.get("events", []) if e.get("cleu")]
    casts = collections.defaultdict(list)
    fails = collections.defaultdict(list)
    amounts = collections.defaultdict(list)
    auras = collections.defaultdict(list)
    open_ = {}
    pending = []   # (t, spell, dst) recent casts for aura mapping
    amap = collections.defaultdict(collections.Counter)
    for e in ev:
        a, sub, t = e["a"], e["sub"], e["t"]
        if a[3] != player:
            if sub == "SPELL_AURA_REMOVED" and (a[7], a[11]) in open_:
                pass
            else:
                continue
        if sub == "SPELL_CAST_SUCCESS":
            casts[a[11]].append(t)
            pending.append((t, a[11], a[7]))
            pending = [x for x in pending if t - x[0] <= 0.3]
        elif sub == "SPELL_CAST_FAILED":
            fails[a[11]].append((t, a[-1]))
        elif sub in ("SPELL_DAMAGE", "SPELL_HEAL"):
            amt = a[14] if len(a) > 14 else None
            crit = a[20] if sub == "SPELL_DAMAGE" and len(a) > 20 else (a[17] if len(a) > 17 else None)
            if isinstance(amt, int):
                amounts[a[11]].append((amt, crit in (1, True, "1")))
        elif sub == "SPELL_AURA_APPLIED":
            open_[(a[7], a[11])] = t
            for (tc, sc, dst) in pending:
                if 0 <= t - tc <= 0.3 and (dst == a[7] or a[7] == player or dst in (None, "0000000000000000")):
                    amap[sc][a[11]] += 1
        elif sub == "SPELL_AURA_REFRESH":
            open_[(a[7], a[11])] = t
        elif sub == "SPELL_AURA_REMOVED":
            t0 = open_.pop((a[7], a[11]), None)
            if t0 is not None:
                auras[a[11]].append(round(t - t0, 2))
    rows = []
    observed = {}
    for sid, e in sorted(sp.items()):
        d = e.get("data") or {}
        if not d:
            continue
        name = d.get("info.name")
        p = (rp or {}).get(sid, {}).get("parsed") or d.get("parsed") or {}
        ob = {}
        # aura duration: the mapped aura id(s) (log), else the same id
        ids = [sid] if auras.get(sid) else ([x for x, n in amap.get(sid, collections.Counter()).most_common(1) if n >= 2] or [sid])
        durs = [x for i in ids for x in auras.get(i, [])]
        if durs:
            ob["auraDurations"] = sorted(durs)[-5:]
            full = max(durs)
            pd = p.get("auraDuration") or p.get("stun")
            if pd and full > pd + 1.0:
                rows.append({"spell": sid, "name": name, "check": "log:aura-longer-than-parsed", "severity": "warn", "detail": "observed %.1f s > parsed %s s" % (full, pd)})
            elif pd and abs(full - pd) <= 1.0:
                rows.append({"spell": sid, "name": name, "check": "log:aura-duration", "severity": "ok", "detail": "observed max %.1f s = parsed %s s" % (full, pd)})
            elif pd:
                rows.append({"spell": sid, "name": name, "check": "log:aura-shorter", "severity": "note",
                             "detail": "observed max %.1f s < parsed %s s (removed early: dispel/charges/death)" % (full, pd)})
        if p.get("lockout") and auras.get(sid):
            rows.append({"spell": sid, "name": name, "check": "log:lockout-as-aura", "severity": "error", "detail": "an aura with this spell id was applied: re-check the lockout classification"})
        # cooldown
        bc = d.get("baseCooldown")
        if isinstance(bc, (int, float)) and bc > 1500:
            cd = bc / 1000.0
            ts = sorted(casts.get(sid, []))
            gaps = [round(b - a_, 3) for a_, b in zip(ts, ts[1:])]
            if gaps:
                ob["minRecast"] = min(gaps)
                if min(gaps) < cd - 0.1:
                    rows.append({"spell": sid, "name": name, "check": "log:recast-before-cooldown", "severity": "error", "detail": "recast after %.2f s < cooldown %.1f s" % (min(gaps), cd)})
                else:
                    rows.append({"spell": sid, "name": name, "check": "log:cooldown-recast", "severity": "ok", "detail": "min recast %.2f s >= cooldown %.1f s" % (min(gaps), cd)})
            for tf, reason in fails.get(sid, []):
                if reason != "Not yet recovered":
                    continue
                prev = [x for x in ts if x <= tf]
                since = round(tf - prev[-1], 3) if prev else None
                ok = since is not None and since < cd + 0.1
                ob.setdefault("notYetRecovered", []).append(since)
                rows.append({"spell": sid, "name": name, "check": "log:not-yet-recovered", "severity": "ok" if ok else "warn",
                             "detail": "'Not yet recovered' %s s after my last cast (cooldown %.1f s)%s" % (since, cd, "" if ok else ": outside the window (shared cooldown?)")})
        # damage / heal range
        if p.get("amountMin") and amounts.get(sid):
            lo, hi = p["amountMin"], p.get("amountMax") or p["amountMin"]
            nc = [x for x, c in amounts[sid] if not c]
            if nc:
                ob["amounts"] = [min(nc), max(nc)]
                out = [x for x in nc if x < lo * 0.95 or x > hi * 1.35]
                rows.append({"spell": sid, "name": name, "check": "log:amount-range", "severity": "warn" if out else "ok",
                             "detail": "non-crit %d..%d vs parsed %d..%d%s" % (min(nc), max(nc), lo, hi, (" (%d outside)" % len(out)) if out else "")})
        if ob:
            observed[sid] = ob
    return {"rows": rows, "auraMap": {k: dict(v) for k, v in amap.items()}, "observed": observed}


def cdline_evidence(dump, sp, fx, player):
    """tooltip-line cooldown hypothesis: per sample (spell x context) the tooltip line COUNT vs whether the spell was on
    cooldown at the sample time (log: my last cast of it within its base cooldown). Run-5 samples carry only the
    knowledge-pass time (stamp of the run), not a per-spell time: rows show that uncertainty."""
    kdb = dump.db.get("knowledge") if isinstance(getattr(dump, "db", None), dict) else {}
    runs = []
    for b, bv in ((kdb or {}).items() if isinstance(kdb, dict) else []):
        for r in (bv or {}).get("runs") or []:
            runs.append(r)
    ev = [e for e in (fx or {}).get("events", []) if e.get("cleu") and e["a"][3] == player and e["sub"] == "SPELL_CAST_SUCCESS"]
    rows = []
    probe = {}
    for b, bv in ((kdb or {}).items() if isinstance(kdb, dict) else []):
        for sid, v in ((bv or {}).get("cdLineProbe") or {}).items():
            probe[int(sid)] = v
    for sid, e in sorted(sp.items()):
        d = e.get("data") or {}
        bc = d.get("baseCooldown")
        if not (isinstance(bc, (int, float)) and bc > 1500):
            continue
        cd = bc / 1000.0
        ctxs = e.get("ctx") or {}
        n = {c: (len(str(v.get("tooltipLines") or "").split(",")) if v.get("tooltipLines") else None) for c, v in ctxs.items()}
        # sample time: the knowledge run of that context (epoch); combat run fires 2 s after the first REGEN_DISABLED
        st = {}
        for r in runs:
            c = r.get("ctx")
            ep = r.get("epoch") or r.get("time")
            if c and isinstance(ep, (int, float)):
                st[c] = ep
        for c, cnt in n.items():
            t = st.get(c)
            oncd = None
            if t is not None and ev:
                last = [x["t"] for x in ev if x["a"][11] == sid and x["t"] <= t]
                oncd = bool(last and t - last[-1] < cd)
            # shared-cooldown view (ASSUMPTION, not readable live): spells with the same base cooldown and the same last name
            # word ("... Shock") share one cooldown in Classic; shown separately, never used for the verdict
            shared = None
            if t is not None and ev:
                fam = str(d.get("info.name") or "").split(" ")[-1]
                ids = [s2 for s2, e2 in sp.items() if (e2.get("data") or {}).get("baseCooldown") == bc
                       and str((e2.get("data") or {}).get("info.name") or "").split(" ")[-1] == fam]
                last = [x["t"] for x in ev if x["a"][11] in ids and x["t"] <= t]
                shared = bool(last and t - last[-1] < cd)
            rows.append({"spell": sid, "name": d.get("info.name"), "ctx": c, "lines": cnt, "codes": (ctxs.get(c) or {}).get("tooltipLines"),
                         "sampleTime": t, "onCooldownByOwnCast": oncd, "onCooldownShared": shared})
    base = {}
    for r in rows:
        if r["ctx"] == "ooc" and r["lines"]:
            base[r["spell"]] = r["lines"]
    for r in rows:
        r["extraLine"] = (r["lines"] is not None and r["spell"] in base and r["lines"] > base[r["spell"]])
    scorable = [r for r in rows if r["onCooldownByOwnCast"] is not None and r["ctx"] == "combat"]
    agree = sum(1 for r in scorable if r["extraLine"] == r["onCooldownByOwnCast"])
    probe_rows = []
    for sid, v in probe.items():
        for k, cnt in (v or {}).items():
            ph, ctx, nl, types = (str(k).split("|") + [None] * 4)[:4]
            probe_rows.append({"spell": sid, "phase": ph, "ctx": ctx, "lines": nl, "types": types, "count": cnt})
    agree_shared = sum(1 for r in scorable if r["extraLine"] == r.get("onCooldownShared"))
    proven = bool(scorable) and agree == len(scorable) and len(scorable) >= 10 and len(set(r["sampleTime"] for r in scorable)) >= 2
    return {"rows": rows, "scorable": len(scorable), "agree": agree, "agreeShared": agree_shared, "proven": proven, "probe": probe_rows,
            "sampleTimes": len(set(r["sampleTime"] for r in scorable)),
            "verdict": "proven" if proven else "NOT proven (needs >= 10 known-answer samples per phase, 100% agreement; HSM signal stays disabled)"}


def analyze(dump, fx=None, player=None, lua="lua5.1"):
    sp = spells(dump)
    rp = reparse(sp, lua=lua)
    lc = log_checks(sp, rp, fx, player)
    res = {"spells": len(sp), "reparsed": rp is not None, "data": data_checks(sp, rp, lc["observed"])}
    res["log"] = lc["rows"]
    res["auraMapLog"] = lc["auraMap"]
    res["observed"] = lc["observed"]
    live_map = {sid: e.get("auraMap") for sid, e in sp.items() if e.get("auraMap")}
    merged = collections.defaultdict(collections.Counter)
    for sid, m in lc["auraMap"].items():
        for aid, n in m.items():
            merged[int(sid)][int(aid)] += n
    for sid, m in live_map.items():
        for aid, x in (m or {}).items():
            merged[int(sid)][int(aid)] += (x.get("n") if isinstance(x, dict) else int(x or 0))
    res["auraMap"] = {sid: dict(m) for sid, m in merged.items()}
    res["cdLine"] = cdline_evidence(dump, sp, fx, player)
    res["reparse"] = {sid: v.get("parsed") for sid, v in (rp or {}).items()}
    return res


def markdown(res):
    L = ["", "## v2.2.4 semantic lint + reality cross-check (standing check list)", "",
         "Every build: stored descriptions re-parsed with the current parser; rules: lockout/interrupt text never becomes "
         "auraDuration; summon lifetimes/pulses and imbue durations never become aura or cast amounts; every 'N sec/min' is "
         "classified (aura / lockout / stun / summon / imbue / period / header) or counted ambiguous; multi-cost spells keep every "
         "cost; tooltip header fields agree with the structured APIs; a parsed aura duration never observed is 'unverified'.", ""]
    sev = collections.Counter(r["severity"] for r in res["data"] + res["log"])
    L.append("Summary: %s" % ", ".join("%s %d" % (k, v) for k, v in sorted(sev.items())))
    L += ["", "| spell | name | check | severity | detail |", "|---|---|---|---|---|"]
    order = {"error": 0, "warn": 1, "info": 2, "note": 3, "ok": 4}
    for r in sorted(res["data"] + res["log"], key=lambda r: (order.get(r["severity"], 9), str(r["spell"]))):
        L.append("| %s | %s | %s | %s | %s |" % (r["spell"], r.get("name"), r["check"], r["severity"], r["detail"]))
    if res["auraMap"]:
        L += ["", "### Spell -> applied aura id (live correlation + combat log, <= 0.3 s, same source/destination)", "",
              "| cast | aura id(s) (count) |", "|---|---|"]
        for sid, m in sorted(res["auraMap"].items()):
            L.append("| %s | %s |" % (sid, ", ".join("%s (%d)" % (a, n) for a, n in sorted(m.items(), key=lambda x: -x[1]))))
    c = res["cdLine"]
    L += ["", "### Hypothesis: tooltip line count tracks 'on cooldown' (line count / types only, never text)", "",
          "Verdict: **%s**. Combat samples: %d agree with own-cast cooldown state out of %d (%d with the shared-cooldown "
          "assumption); %d distinct sample time(s)." % (c["verdict"], c["agree"], c["scorable"], c["agreeShared"], c["sampleTimes"]), "",
          "| spell | name | ctx | lines | codes | extra line | on cd (own cast) | on cd (shared-cd assumption) |", "|---|---|---|---|---|---|---|---|"]
    for r in c["rows"]:
        L.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % (r["spell"], r.get("name"), r["ctx"], r["lines"], r["codes"], r["extraLine"],
                                                           r["onCooldownByOwnCast"], r.get("onCooldownShared")))
    if c["probe"]:
        L += ["", "Known-answer probes (v2.2.4, every capture):", "", "| spell | phase | ctx | lines | line types | count |", "|---|---|---|---|---|---|"]
        for r in c["probe"]:
            L.append("| %s | %s | %s | %s | %s | %s |" % (r["spell"], r["phase"], r["ctx"], r["lines"], r["types"], r["count"]))
    return "\n".join(L) + "\n"
