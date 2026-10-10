"""v2.2.6: per-fight, per-unit join of live HSM estimate vs C_DamageMeter vs combat log."""
from __future__ import annotations

from fdump.coverage import as_list


def _num(v):
    return v if isinstance(v, (int, float)) else None


def _delta(live, dm, log, tol_abs=5, tol_rel=0.02):
    """Return status/deltas for a metric triple (any may be None)."""
    row = {"live": live, "meter": dm, "log": log}
    statuses = []
    for a, b, name in ((live, dm, "live_vs_meter"), (dm, log, "meter_vs_log"), (live, log, "live_vs_log")):
        if a is None or b is None:
            statuses.append((name, "unexplained", None))
            continue
        d = a - b
        tol = max(tol_abs, abs(b) * tol_rel)
        if abs(d) <= tol:
            statuses.append((name, "match", d))
        else:
            statuses.append((name, "off", d))
    row["comparisons"] = {n: {"status": s, "delta": d} for n, s, d in statuses}
    # overall: match if all present comparisons match; else off if any off; else unexplained
    present = [s for _, s, _ in statuses if s != "unexplained"]
    if not present:
        row["verdict"] = "unexplained"
    elif all(s == "match" for s in present):
        row["verdict"] = "match"
    else:
        row["verdict"] = "off"
    return row


def _unit_from_sources(sources, type_name):
    """IdKey -> total for a meter type."""
    out = {}
    for src in as_list((sources or {}).get(type_name)):
        if not isinstance(src, dict):
            continue
        uid = src.get("id") or ("player" if src.get("isLocalPlayer") else None)
        if not uid:
            continue
        tot = _num(src.get("total"))
        if tot is None:
            continue
        out[uid] = out.get(uid, 0) + tot
    return out


def _log_player_totals(fight):
    """From coverage fights_truth row. v2.2.9: a fight outside the combat log file's span has NO log values (None)."""
    if fight.get("logCovered") is False:
        return {k: None for k in ("damage", "healing", "interrupts", "taken", "others")}
    return {
        "damage": fight.get("mineDamage"),
        "healing": fight.get("healEffective") or fight.get("mineHealEff"),
        "interrupts": fight.get("interruptsMine") or fight.get("mineInterrupts"),
        "taken": fight.get("takenDamage") or fight.get("taken"),
        "others": fight.get("otherOnTargets") or fight.get("otherDamage"),
    }


def _to_epoch(inf, gt):
    a = inf.get("anchor") if isinstance(inf.get("anchor"), dict) else None
    if not a or not isinstance(gt, (int, float)) or not isinstance(a.get("gameTime"), (int, float)) \
            or not isinstance(a.get("epoch"), (int, float)):
        return None
    return a["epoch"] + (gt - a["gameTime"])


def _live_by_time(inf, lo, hi):
    """v2.2.9 (run 8): the live HSM fight (or dm-reconcile inference) that overlaps the fight window [lo, hi] (epoch).
    The export keeps only the last fights (run 8: 13 of ~38 BG fights); index pairing and the 'last dm-reconcile'
    fallback gave every uncovered fight the same 1540/1252 numbers. No overlap -> {} (unexplained, never a neighbour)."""
    best, best_ov = None, 0.0
    for f in as_list(inf.get("fights")):
        if not isinstance(f, dict):
            continue
        s, e = _to_epoch(inf, f.get("start")), _to_epoch(inf, f.get("stop"))
        if s is None:
            continue
        e = e if e is not None else s + 1
        ov = min(e, hi) - max(s, lo)   # seconds of overlap; > -1 tolerates a sub-second gap between the two clocks
        if ov > -1 and (best is None or ov > best_ov):
            best, best_ov = f, ov
    if best is not None:
        le = best.get("liveEst") or {}
        return {
            "damage": le.get("damage", (best.get("dmg") or {}).get("mine")),
            "healing": le.get("healing", (best.get("heal") or {}).get("mine")),
            "interrupts": le.get("interrupts", (best.get("interrupts") or {}).get("mine")),
            "dispels": le.get("dispels", (best.get("dispels") or {}).get("mine")),
            "taken": le.get("taken", (best.get("taken") or {}).get("amount")),
            "world": best.get("world") or {},
            "reconcile": best.get("reconcile"),
        }
    for r in as_list(inf.get("inferences")):
        if isinstance(r, dict) and r.get("rule") == "dm-reconcile":
            t = _to_epoch(inf, r.get("t"))
            if t is not None and lo - 2 <= t <= hi + 15:
                return {"damage": r.get("liveMine"), "healing": r.get("liveHeal"), "interrupts": r.get("liveInterrupts"),
                        "dispels": r.get("liveDispels"), "taken": r.get("liveTaken"), "metrics": r.get("metrics"),
                        "units": r.get("units")}
    return {}


def _live_from_hsm(dump, fight_idx, lo=None, hi=None):
    """Pull liveEst / reconcile from inference export fights if present (by TIME when the export has an anchor)."""
    inf = (dump.log.get("inference") or {})
    if isinstance(lo, (int, float)) and isinstance(hi, (int, float)) and _to_epoch(inf, 0) is not None:
        return _live_by_time(inf, lo, hi)
    # current session export
    for key in ("export", "hs", "last"):
        block = inf.get(key) if isinstance(inf.get(key), dict) else None
    fights = as_list(inf.get("fights")) or as_list((inf.get("export") or {}).get("fights"))
    if not fights and isinstance(inf.get("live"), list):
        fights = []
    # Also check ReplayLog / Verify for dm-reconcile inferences
    for sess in as_list((dump.log.get("replay") or {}).get("sessions")):
        pass
    if fight_idx < len(fights):
        f = fights[fight_idx]
        le = f.get("liveEst") or {}
        return {
            "damage": le.get("damage", (f.get("dmg") or {}).get("mine")),
            "healing": le.get("healing", (f.get("heal") or {}).get("mine")),
            "interrupts": le.get("interrupts", (f.get("interrupts") or {}).get("mine")),
            "dispels": le.get("dispels", (f.get("dispels") or {}).get("mine")),
            "taken": le.get("taken", (f.get("taken") or {}).get("amount")),
            "world": f.get("world") or {},
            "reconcile": f.get("reconcile"),
        }
    # fallback: dm-reconcile inferences
    live = {}
    for r in as_list(inf.get("inferences")):
        if isinstance(r, dict) and r.get("rule") == "dm-reconcile":
            live = {
                "damage": r.get("liveMine"),
                "healing": r.get("liveHeal"),
                "interrupts": r.get("liveInterrupts"),
                "dispels": r.get("liveDispels"),
                "taken": r.get("liveTaken"),
                "metrics": r.get("metrics"),
                "units": r.get("units"),
            }
    return live


def _raw_fight_for(raw_fights, f, i):
    """v2.2.7 (run 6b): pick the meter fight by TIME, not by index. The SavedVariables keep every earlier capture's meter
    fights, so index 0 of a run-6b SV was run 6's fight (6b fight 1 got 1327/243/290/1 = run 6's numbers -> false 'off').
    A raw fight matches when its epoch (meter snapshot at regen/capture off) falls in [start - 2, stop + 15] of the log
    fight; 'deep' (regen) snapshots win. Index fallback only for old SVs without epochs; no match -> None (never a
    neighbour's numbers)."""
    lo, hi = f.get("start"), f.get("stop")
    with_epoch = [r for r in raw_fights if isinstance(r, dict) and isinstance(r.get("epoch"), (int, float))]
    if with_epoch and isinstance(lo, (int, float)) and isinstance(hi, (int, float)):
        cand = [r for r in with_epoch if lo - 2 <= r["epoch"] <= hi + 15]
        if not cand:
            return None
        cand.sort(key=lambda r: (not r.get("deep"), abs(r["epoch"] - hi)))
        return cand[0]
    if with_epoch:
        return None
    return raw_fights[i] if i < len(raw_fights) else (raw_fights[-1] if raw_fights else None)


def _sum_live(parts):
    """sum per-fight live HSM totals (and per-unit world rows) over a meter session"""
    out, world = {}, {}
    for p in parts:
        for k, v in (p or {}).items():
            if k == "world" and isinstance(v, dict):
                for uid, w in v.items():
                    acc = world.setdefault(uid, {})
                    for wk, wv in (w or {}).items():
                        if isinstance(wv, (int, float)) and not isinstance(wv, bool):
                            acc[wk] = (acc.get(wk) or 0) + wv
                        elif wk not in acc:
                            acc[wk] = wv
            elif isinstance(v, (int, float)) and not isinstance(v, bool):
                out[k] = (out.get(k) or 0) + v
            elif k not in out:
                out[k] = v
    out["world"] = world
    return out


def join(dump, coverage_res):
    """
    Build per-fight rows: metrics + per-unit IdKey joins.
    coverage_res must include fights + damageMeter from coverage.analyze.
    """
    fights = as_list(coverage_res.get("fights"))
    dm = coverage_res.get("damageMeter") or {}
    raw_fights = as_list((dump.log.get("damageMeter") or {}).get("fights"))
    out_fights = []
    for i, f in enumerate(fights):
        log_tot = _log_player_totals(f)
        dm_row = None
        # v2.2.16: reconcile rows are meter SESSION windows (coverage.session_join); a BG session spans several log
        # fights. The meter is compared once, on the session's last fight, against the session's log + live sums.
        session = None
        for r in as_list(dm.get("reconcile")):
            fl = r.get("fights") or [r.get("fight")]
            if f.get("n") in fl:
                session = fl
                if r.get("dmDur") is not None and f.get("n") == fl[-1]:
                    dm_row = r
                break
        if dm_row is not None and len(session or []) > 1:
            log_tot = {"damage": dm_row.get("logMine"), "healing": dm_row.get("logHealEff"), "interrupts": dm_row.get("logInterrupts"),
                       "taken": dm_row.get("logTaken"), "others": dm_row.get("logOtherOnTargets")}
        meter = {
            "damage": (dm_row or {}).get("dmMine"),
            "healing": (dm_row or {}).get("dmHeal"),
            "interrupts": (dm_row or {}).get("dmInterrupts"),
            "taken": (dm_row or {}).get("dmTaken"),
            "others": (dm_row or {}).get("dmOthers"),
            "dispels": None,
            "dur": (dm_row or {}).get("dmDur"),
        }
        # enrich from raw deep fight
        raw = _raw_fight_for(raw_fights, f, i)
        sources = {}
        if isinstance(raw, dict):
            ty = raw.get("types") or {}
            meter["dispels"] = (ty.get("Dispels") or {}).get("me")
            if meter["damage"] is None:
                meter["damage"] = (ty.get("DamageDone") or {}).get("me")
            if meter["healing"] is None:
                meter["healing"] = (ty.get("HealingDone") or {}).get("me")
            if meter["interrupts"] is None:
                meter["interrupts"] = (ty.get("Interrupts") or {}).get("me")
            if meter["taken"] is None:
                meter["taken"] = (ty.get("DamageTaken") or {}).get("me")
            for name, block in ty.items():
                if isinstance(block, dict) and block.get("sources"):
                    sources[name] = block["sources"]
        live = _live_from_hsm(dump, i, f.get("start"), f.get("stop"))
        if dm_row is not None and len(session or []) > 1:
            byn = {g.get("n"): (j, g) for j, g in enumerate(fights)}
            parts = [_live_from_hsm(dump, byn[n][0], byn[n][1].get("start"), byn[n][1].get("stop")) for n in session if n in byn]
            live = _sum_live(parts)
        metrics = {}
        for name in ("damage", "healing", "interrupts", "dispels", "taken"):
            metrics[name] = _delta(live.get(name), meter.get(name), log_tot.get(name),
                                   tol_abs=0 if name in ("interrupts", "dispels") else 5)
        # per-unit: meter sources vs live world vs log (log only has player-centric totals here)
        units = {}
        dmg_by = _unit_from_sources(sources, "DamageDone")
        heal_by = _unit_from_sources(sources, "HealingDone")
        taken_by = _unit_from_sources(sources, "DamageTaken")
        int_by = _unit_from_sources(sources, "Interrupts")
        disp_by = _unit_from_sources(sources, "Dispels")
        enemy_by = _unit_from_sources(sources, "EnemyDamageTaken")
        ids = set(dmg_by) | set(heal_by) | set(taken_by) | set(int_by) | set(disp_by) | set(enemy_by)
        world = live.get("world") or {}
        for uid in sorted(ids, key=str):
            w = world.get(uid) or {}
            live_u = {
                "damage": w.get("dmg") if uid != "player" else live.get("damage"),
                "healing": w.get("heal") if uid != "player" else live.get("healing"),
                "taken": w.get("taken") if uid != "player" else live.get("taken"),
                "interrupts": w.get("interrupts") if uid != "player" else live.get("interrupts"),
                "dispels": w.get("dispels") if uid != "player" else live.get("dispels"),
            }
            if uid == "player":
                live_u = {k: live.get(k) for k in ("damage", "healing", "taken", "interrupts", "dispels")}
            meter_u = {
                "damage": dmg_by.get(uid), "healing": heal_by.get(uid), "taken": taken_by.get(uid),
                "interrupts": int_by.get(uid), "dispels": disp_by.get(uid), "enemyTaken": enemy_by.get(uid),
            }
            log_u = log_tot if uid == "player" else {}
            u_metrics = {}
            for name in ("damage", "healing", "interrupts", "dispels", "taken"):
                u_metrics[name] = _delta(live_u.get(name), meter_u.get(name), log_u.get(name),
                                         tol_abs=0 if name in ("interrupts", "dispels") else 5)
            units[uid] = {"meter": meter_u, "live": live_u, "metrics": u_metrics,
                          "verdict": ("match" if all(m["verdict"] == "match" for m in u_metrics.values()
                                      if m.get("meter") is not None or m.get("live") is not None)
                                      else "off")}
            # simplify verdict
            present = [m for m in u_metrics.values() if m.get("meter") is not None or m.get("live") is not None]
            if not present:
                units[uid]["verdict"] = "unexplained"
            elif all(m["verdict"] == "match" for m in present):
                units[uid]["verdict"] = "match"
            elif any(m["verdict"] == "off" for m in present):
                units[uid]["verdict"] = "off"
            else:
                units[uid]["verdict"] = "unexplained"
        n_match = sum(1 for m in metrics.values() if m["verdict"] == "match")
        n_off = sum(1 for m in metrics.values() if m["verdict"] == "off")
        n_un = sum(1 for m in metrics.values() if m["verdict"] == "unexplained")
        out_fights.append({
            "n": f.get("n", i + 1),
            "span": [f.get("lo"), f.get("hi")],
            "dur": f.get("dur"),
            "live": {k: live.get(k) for k in ("damage", "healing", "interrupts", "dispels", "taken")},
            "meter": meter,
            "log": log_tot,
            "metrics": metrics,
            "units": units,
            "summary": {"match": n_match, "off": n_off, "unexplained": n_un},
            "deep": bool(sources),
            "nSources": sum(len(v) for v in sources.values()),
        })
    summary = {
        "fights": len(out_fights),
        "match": sum(f["summary"]["match"] for f in out_fights),
        "off": sum(f["summary"]["off"] for f in out_fights),
        "unexplained": sum(f["summary"]["unexplained"] for f in out_fights),
        "units": sum(len(f["units"]) for f in out_fights),
    }
    return {"fights": out_fights, "summary": summary}


def markdown(join_res):
    L = ["", "## Damage meter three-way join (live ↔ meter ↔ combat log)", ""]
    s = join_res.get("summary") or {}
    L.append("Fights %s; metric cells match %s / off %s / unexplained %s; per-unit rows %s." % (
        s.get("fights"), s.get("match"), s.get("off"), s.get("unexplained"), s.get("units")))
    L += ["", "| fight | metric | live | meter | log | live↔meter | meter↔log | verdict |",
          "|---|---|---|---|---|---|---|---|"]
    for f in join_res.get("fights") or []:
        for name, m in (f.get("metrics") or {}).items():
            c = m.get("comparisons") or {}
            L.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % (
                f.get("n"), name, m.get("live"), m.get("meter"), m.get("log"),
                (c.get("live_vs_meter") or {}).get("status"),
                (c.get("meter_vs_log") or {}).get("status"),
                m.get("verdict")))
    # per-unit compact
    any_u = any(f.get("units") for f in join_res.get("fights") or [])
    if any_u:
        L += ["", "### Per-unit (IdKey)", "",
              "| fight | unit | dmg meter | taken meter | verdict |",
              "|---|---|---|---|---|"]
        for f in join_res.get("fights") or []:
            for uid, u in sorted((f.get("units") or {}).items(), key=lambda kv: str(kv[0])):
                L.append("| %s | %s | %s | %s | %s |" % (
                    f.get("n"), uid, (u.get("meter") or {}).get("damage"),
                    (u.get("meter") or {}).get("taken") or (u.get("meter") or {}).get("enemyTaken"),
                    u.get("verdict")))
    return L


def correlation_facts(join_res):
    """Flat facts for the correlation / HO miner."""
    facts = []
    for f in join_res.get("fights") or []:
        for name, m in (f.get("metrics") or {}).items():
            facts.append({
                "kind": "dm-threeway",
                "fight": f.get("n"),
                "metric": name,
                "verdict": m.get("verdict"),
                "live": m.get("live"),
                "meter": m.get("meter"),
                "log": m.get("log"),
            })
        for uid, u in (f.get("units") or {}).items():
            facts.append({
                "kind": "dm-unit",
                "fight": f.get("n"),
                "unit": uid,
                "verdict": u.get("verdict"),
                "meter": u.get("meter"),
            })
    return facts
