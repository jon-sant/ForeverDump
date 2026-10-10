"""Self-performance report (v2.2.3): PERF.md + perf.json from ForeverDumpLogDB.perf (Perf.lua), with a legacy fallback
for older SVs built from the FD_Logs profile snapshots (sections.profile, capture:on / capture:off).

Flags (PERFORMANCE.md rule: <1% framerate impact, O(1) per-event cost, no idle OnUpdate):
  impact      ForeverDump handler time / capture wall time >= 2% (release budget, user 2026-10-08)
  growth      a handler's mean cost PER CALL in the last third of the session > 2x the first third
              (both thirds need >= 20 calls and the increase must be >= 0.02 ms) -> cost grows with session length
  size growth a sampled table size that is still growing in the last third of the session (unbounded)
"""
import statistics

from .dump import as_list

MIN_CALLS = 20
RATIO = 2.0
MIN_DELTA_MS = 0.02


def _f(v, d=0.0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return d


def _r(v, d=4):
    return round(v, d) if isinstance(v, float) else v


def _windows(h):
    w = h.get("w") or {}
    items = w.items() if isinstance(w, dict) else enumerate(as_list(w), 1)
    out = []
    for k, v in items:
        v = as_list(v) if not isinstance(v, dict) else [v.get(1) or v.get("1"), v.get(2) or v.get("2")]
        if len(v) >= 2:
            out.append((int(k), int(_f(v[0])), _f(v[1])))
    return sorted(out)


# caps of the v2.2.3 tables (HybridState push(): maxLog 2000 + 25% slack; hsm.maxSignals 3000) for sessions recorded
# before Perf.Size carried its bound (v2.2.4)
LEGACY_BOUNDS = {"hsm.predictions": 2500, "hsm.inferences": 2500, "inference.signals": 3000}
# v2.2.7 (runs 6/6b): per-slice budgets of the time-sliced scanners (tests/perf_bench.lua wc40/raid40 budgetMs). The
# mock bench passed (wc40 0.073 ms) while the real client averaged 0.126-0.130 ms per WorldCapture slice in every 6/6b
# capture and nothing flagged it. A real capture whose MEAN slice exceeds the budget is now a perf flag.
SLICE_BUDGET_MS = {"WorldCapture.Slice": 0.1, "TokenScan.Slice": 0.12}


def growth(wins):
    """(first-third mean ms/call, last-third mean, ratio, flagged) over the windows that saw calls."""
    wins = [w for w in wins if w[1] > 0]
    if len(wins) < 3:
        return None
    k = max(1, len(wins) // 3)
    a, b = wins[:k], wins[-k:]
    na, nb = sum(w[1] for w in a), sum(w[1] for w in b)
    if na < MIN_CALLS or nb < MIN_CALLS:
        return None
    ma, mb = sum(w[2] for w in a) / na, sum(w[2] for w in b) / nb
    ratio = mb / ma if ma > 0 else (float("inf") if mb > 0 else 1.0)
    return {"first": round(ma, 4), "last": round(mb, 4), "ratio": round(ratio, 2) if ratio != float("inf") else None,
            "grows": ratio > RATIO and mb - ma >= MIN_DELTA_MS}


def session(rec):
    dur = _f(rec.get("duration"))
    hs = []
    total = 0.0
    for key, h in (rec.get("handlers") or {}).items():
        if not isinstance(h, dict):
            continue
        n, ms = int(_f(h.get("n"))), _f(h.get("ms"))
        total += ms
        wins = _windows(h)
        g = growth(wins)
        hs.append({"key": key, "n": n, "ms": round(ms, 3), "mean": round(ms / n, 4) if n else 0, "max": round(_f(h.get("max")), 3),
                   "windows": len(wins), "growth": g})
    hs.sort(key=lambda x: -x["ms"])
    samples = [s for s in as_list(rec.get("samples")) if isinstance(s, dict)]
    out = {"sid": rec.get("sid"), "version": rec.get("version"), "duration": round(dur, 1), "handlerMs": round(total, 3),
           "calls": sum(h["n"] for h in hs), "impactPct": round(total / (dur * 10), 4) if dur > 0 else None,
           "handlers": hs, "samples": len(samples)}
    out["flags"] = []
    if out["impactPct"] is not None and out["impactPct"] >= 2:
        out["flags"].append("impact %.2f%% of wall time >= 2%%" % out["impactPct"])
    for h in hs:
        b = SLICE_BUDGET_MS.get(h["key"])
        if b is not None and h["n"] >= MIN_CALLS and h["mean"] > b:
            out["flags"].append("%s: mean %.4f ms per slice > budget %.2f ms (real client, %d slices)" % (
                h["key"], h["mean"], b, h["n"]))
    for h in hs:
        if h["growth"] and h["growth"]["grows"]:
            out["flags"].append("%s: cost per call grows %.4f -> %.4f ms (x%s) over the session" % (
                h["key"], h["growth"]["first"], h["growth"]["last"], h["growth"]["ratio"]))
    if samples:
        def series(key):
            return [(s.get("t"), s.get(key)) for s in samples if isinstance(s.get(key), (int, float))]
        st = {}
        for key in ("heapKB", "fps", "app", "all", "own", "ownPeak"):
            ser = series(key)
            if ser:
                vals = [v for _, v in ser]
                st[key] = {"first": vals[0], "last": vals[-1], "min": min(vals), "max": max(vals), "median": statistics.median(vals)}
        sizes = {}
        for s in samples:
            for k, v in (s.get("sz") or {}).items():
                sizes.setdefault(k, []).append(v)
        szs = {}
        bounds = rec.get("bounds") if isinstance(rec.get("bounds"), dict) else dict(LEGACY_BOUNDS)
        for k, vals in sizes.items():
            third = max(1, len(vals) // 3)
            still = len(vals) >= 24 and vals[-1] > vals[-third] and vals[-1] > max(vals[:-third] or [0])
            bound = bounds.get(k)
            # v2.2.4: a capped table filling up to its cap is bounded by construction; flag only when no cap is known
            # or the cap is exceeded
            flag = still and (bound is None or vals[-1] > bound)
            szs[k] = {"first": vals[0], "last": vals[-1], "max": max(vals), "stillGrowing": still, "bound": bound,
                      "flagged": flag}
            if flag:
                out["flags"].append("size %s still growing at the end (%s -> %s)%s" % (k, vals[0], vals[-1],
                                    "" if bound is None else ", past its cap %s" % bound))
        out["sampleStats"], out["sizes"] = st, szs
    # v2.2.16: attribute the all-time own PeakTime (cumulative since load) to the step between two marks
    marks = [m for m in as_list(rec.get("peakMarks")) if isinstance(m, dict)]
    if marks:
        out["peakMarks"] = [{"label": m.get("label"), "peak": m.get("peak"), "t": m.get("t")} for m in marks]
        prev = None
        for m in marks:
            pk = m.get("peak")
            if isinstance(pk, (int, float)) and (prev is None or pk > prev[1] + 1.0):
                out["peakSetBy"] = {"between": prev[0] if prev else "(addon load)", "and": m.get("label"), "peak": pk}
            if isinstance(pk, (int, float)):
                prev = (m.get("label"), pk)
    return out


def legacy(dump):
    """pre-2.2.3 SVs: capture:on / capture:off profile snapshot pairs (C_AddOnProfiler + memory)."""
    prof = (dump.sections.get("profile") or {})
    snaps = [s for s in as_list(prof.get("snapshots")) if isinstance(s, dict)]
    pairs = []
    for i, s in enumerate(snaps):
        if s.get("reason") != "capture:on":
            continue
        off = next((t for t in snaps[i + 1:] if t.get("reason") == "capture:off"), None)
        if not off:
            continue
        dur = _f(off.get("gameTime")) - _f(s.get("gameTime"))
        app0, app1 = (s.get("profiler") or {}).get("application") or {}, (off.get("profiler") or {}).get("application") or {}
        row = {"duration": round(dur, 1), "app": {k: (_r(app0.get(k), 1), _r(app1.get(k), 1)) for k in ("RecentAverageTime", "PeakTime",
                                                                                          "CountTimeOver50Ms", "CountTimeOver100Ms")},
               "addons": {}}
        for name, a in (off.get("addons") or {}).items():
            b = (s.get("addons") or {}).get(name) or {}
            m0, m1 = b.get("metrics") or {}, a.get("metrics") or {}
            row["addons"][name] = {
                "memKB": (round(_f(b.get("memoryKB")), 0), round(_f(a.get("memoryKB")), 0)),
                "session": (_r(m0.get("SessionAverageTime")), _r(m1.get("SessionAverageTime"))),
                "recent": (_r(m0.get("RecentAverageTime")), _r(m1.get("RecentAverageTime"))),
                "over1": int(_f(m1.get("CountTimeOver1Ms")) - _f(m0.get("CountTimeOver1Ms"))),
                "over10": int(_f(m1.get("CountTimeOver10Ms")) - _f(m0.get("CountTimeOver10Ms"))),
                "over50": int(_f(m1.get("CountTimeOver50Ms")) - _f(m0.get("CountTimeOver50Ms"))),
            }
        flags = []
        r0, r1 = _f(row["app"]["RecentAverageTime"][0]), _f(row["app"]["RecentAverageTime"][1])
        if r0 > 0 and r1 / r0 >= 1.5:
            flags.append("application frame time rose x%.1f during the capture (%.1f -> %.1f ms/frame)" % (r1 / r0, r0, r1))
        own = row["addons"].get("ForeverDump")
        if own and own["memKB"][1] - own["memKB"][0] > 10240:
            flags.append("ForeverDump memory +%.1f MB during the capture" % ((own["memKB"][1] - own["memKB"][0]) / 1024))
        row["flags"] = flags
        pairs.append(row)
    return pairs


def analyze(dump):
    perf = (dump.log or {}).get("perf") or {}
    sess = [session(r) for r in as_list(perf.get("sessions")) if isinstance(r, dict)]
    return {"source": "perf" if sess else ("profile snapshots (legacy, pre-2.2.3)" if legacy(dump) else "none"),
            "sessions": sess, "legacy": legacy(dump), "addonVersion": (dump.db or {}).get("addonVersion"),
            "rule": "<1% of wall time, cost per call flat over the session, bounded tables"}


def markdown(rep):
    L = ["# PERF: ForeverDump self-performance", "",
         "Source: %s (addon %s). Rule (PERFORMANCE.md): %s." % (rep["source"], rep.get("addonVersion"), rep["rule"]), ""]
    for i, s in enumerate(rep["sessions"], 1):
        L += ["## Capture %d (%s, v%s)" % (i, s.get("sid"), s.get("version")), "",
              "- %.0f s, %d handler calls, %.1f ms total = **%s%%** of wall time" % (
                  s["duration"], s["calls"], s["handlerMs"], s["impactPct"]),
              "- flags: " + ("; ".join(s["flags"]) if s["flags"] else "none (flat per-call cost, under 1%)"), "",
              "| handler | calls | total ms | mean ms | max ms | first-third mean | last-third mean | grows |",
              "|---|---|---|---|---|---|---|---|"]
        for h in s["handlers"][:25]:
            g = h["growth"] or {}
            L.append("| %s | %d | %.2f | %.4f | %.2f | %s | %s | %s |" % (
                h["key"], h["n"], h["ms"], h["mean"], h["max"], g.get("first", ""), g.get("last", ""),
                "**yes**" if g.get("grows") else ("no" if g else "n/a")))
        st = s.get("sampleStats") or {}
        if st:
            L += ["", "Samples (%d): " % s["samples"] + "; ".join(
                "%s %s -> %s (min %s, max %s)" % (k, v["first"], v["last"], v["min"], v["max"]) for k, v in st.items())]
        if s.get("sizes"):
            L += ["", "Table sizes: " + "; ".join("%s %s -> %s%s" % (k, v["first"], v["last"], (" (still growing, capped at %s)" % v["bound"] if v.get("bound") is not None and not v.get("flagged") else " (still growing)") if v["stillGrowing"]
                                                                       else "") for k, v in sorted(s["sizes"].items()))]
        if s.get("peakMarks"):
            L += ["", "Own PeakTime marks (v2.2.16): " + "; ".join("%s %s" % (m["label"], m["peak"]) for m in s["peakMarks"])]
            if s.get("peakSetBy"):
                p = s["peakSetBy"]
                L.append("All-time peak %s ms set between `%s` and `%s`." % (p["peak"], p["between"], p["and"]))
        L.append("")
    if rep["legacy"]:
        L += ["## Profile snapshots (capture:on vs capture:off)", "",
              "C_AddOnProfiler and memory at the start and end of each FD_Logs capture. Per-addon counters undercount time "
              "spent in an addon's OnUpdate/timers on this client; the application frame time is the reliable signal.", ""]
        for p in rep["legacy"]:
            a = p["app"]
            L.append("- %.0f s capture: application RecentAverageTime %s -> %s ms, PeakTime %s -> %s" % (
                p["duration"], a["RecentAverageTime"][0], a["RecentAverageTime"][1], a["PeakTime"][0], a["PeakTime"][1]))
            L.append("- flags: " + ("; ".join(p.get("flags") or []) or "none"))
            L += ["", "| addon | memory KB | session avg ms | recent avg ms | +frames >1 ms | >10 ms | >50 ms |", "|---|---|---|---|---|---|---|"]
            for name, r in sorted(p["addons"].items(), key=lambda kv: -kv[1]["memKB"][1]):
                L.append("| %s | %s -> %s | %s -> %s | %s -> %s | %d | %d | %d |" % (
                    name, r["memKB"][0], r["memKB"][1], r["session"][0], r["session"][1], r["recent"][0], r["recent"][1],
                    r["over1"], r["over10"], r["over50"]))
            L.append("")
    if not rep["sessions"] and not rep["legacy"]:
        L.append("No perf data: capture with FD_Logs ON (v2.2.3+ records ForeverDumpLogDB.perf automatically).")
    return "\n".join(L) + "\n"
