"""Restrictions summary (v2.2): ADDON_RESTRICTION_STATE_CHANGED flips, context markers and the flip probe deltas.

Sources, newest first:
  ForeverDumpLogDB.restrictions.{flips,markers,sessions,counts}  (v2.2 Restrictions.lua)
  ForeverDumpLogDB.blocked[event == ADDON_RESTRICTION_STATE_CHANGED]  (v2.1: type/state + stamp only)
  ForeverDumpCombatLogDB.sessions[].context counts (v2.1)
Enum names from RestrictedActionsConstantsDocumentation.lua (Forever 70245)."""
import collections
import datetime

from .dump import as_list

TYPE_NAMES = {0: "Combat", 1: "Encounter", 2: "ChallengeMode", 3: "PvPMatch", 4: "Map", 5: "Chat"}
STATE_NAMES = {0: "Inactive", 1: "Activating", 2: "Active"}
CODE = {"S": "secret", "C": "clear", "N": "nil", "X": "inaccessible", "E": "error"}


def _num(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return v


def flips(dump):
    log = dump.log or {}
    r = log.get("restrictions") or {}
    out = []
    if as_list(r.get("flips")):
        for f in as_list(r.get("flips")):
            if isinstance(f, dict):
                out.append(dict(f, source="restrictions"))
        return out, "v2.2"
    for b in as_list(log.get("blocked")):
        if isinstance(b, dict) and b.get("event") == "ADDON_RESTRICTION_STATE_CHANGED":
            a = b.get("args") or {}
            t, s = _num(a.get("type")), _num(a.get("state"))
            out.append({"type": t, "typeName": TYPE_NAMES.get(t, str(t)), "state": s, "stateName": STATE_NAMES.get(s, str(s)),
                        "sid": b.get("sid"), "t": b.get("t") or b.get("gameTime"), "epoch": b.get("epoch") or b.get("time"),
                        "server": b.get("server"), "ctx": {"combat": b.get("inCombat")}, "source": "blocked"})
    return out, "v2.1 (blocked log: type/state/stamp only, no context or probes)"


def _codes(v):
    """probe value -> {position or field: code}"""
    if isinstance(v, str):
        if v.startswith("E:"):
            return {"call": "E"}
        if "=" in v:
            return {kv.split("=", 1)[0]: kv.split("=", 1)[1] for kv in v.split() if "=" in kv}
        return {str(i + 1): c for i, c in enumerate(v)}
    return {}


def probe_delta(before, after):
    """keys whose code changed between two probe snapshots -> list of (probe, pos, from, to)"""
    out = []
    if not isinstance(before, dict) or not isinstance(after, dict):
        return out
    for k in sorted(set(before) | set(after)):
        if k in ("predicates", "addonChatRestricted", "error"):
            continue
        b, a = _codes(before.get(k)), _codes(after.get(k))
        for pos in sorted(set(b) | set(a)):
            if b.get(pos) != a.get(pos):
                out.append((k, pos, b.get(pos, "-"), a.get(pos, "-")))
    pb, pa = before.get("predicates") or {}, after.get("predicates") or {}
    for k in sorted(set(pb) | set(pa)):
        if pb.get(k) != pa.get(k):
            out.append(("C_Secrets." + k, "ret", str(pb.get(k)), str(pa.get(k))))
    if before.get("addonChatRestricted") != after.get("addonChatRestricted"):
        out.append(("C_ChatInfo.AreOutgoingAddonChatMessagesRestricted", "ret", str(before.get("addonChatRestricted")),
                    str(after.get("addonChatRestricted"))))
    return out


def summarize(dump):
    fl, origin = flips(dump)
    log = dump.log or {}
    r = log.get("restrictions") or {}
    markers = [m for m in as_list(r.get("markers")) if isinstance(m, dict)]
    by_type = collections.OrderedDict()
    for f in sorted(fl, key=lambda f: (f.get("epoch") or 0, f.get("t") or 0)):
        d = by_type.setdefault(f.get("typeName"), {"flips": 0, "states": collections.Counter(), "intervals": [],
                                                    "_open": None, "inCombatAtActivating": collections.Counter()})
        d["flips"] += 1
        d["states"][f.get("stateName")] += 1
        if f.get("state") in (1, 2):
            if d["_open"] is None:
                d["_open"] = f
            if f.get("state") == 1:
                d["inCombatAtActivating"]["InCombatLockdown=%s" % bool((f.get("ctx") or {}).get("combat"))] += 1
        elif f.get("state") == 0 and d["_open"] is not None:
            o = d["_open"]
            if o.get("t") is not None and f.get("t") is not None:
                d["intervals"].append(round(float(f["t"]) - float(o["t"]), 3))
            d["_open"] = None
    for d in by_type.values():
        d.pop("_open", None)
        iv = d["intervals"]
        d["activeSec"] = {"n": len(iv), "total": round(sum(iv), 1), "min": min(iv) if iv else None, "max": max(iv) if iv else None}
        d["states"] = dict(d["states"])
        d["inCombatAtActivating"] = dict(d["inCombatAtActivating"])
    # probe deltas: at event -> next frame (enforcement), and baseline (capture start) -> next frame
    becomes = collections.Counter()
    per_flip = []
    baselines = {s.get("sid"): s.get("probeAtStart") for s in as_list(r.get("sessions")) if isinstance(s, dict)}
    for f in fl:
        if not (f.get("probeAt") or f.get("probeAfter")):
            continue
        d1 = probe_delta(f.get("probeAt"), f.get("probeAfter"))
        base = baselines.get(f.get("sid"))
        d2 = probe_delta(base, f.get("probeAfter")) if base else []
        for k, pos, a, b in d1:
            becomes["%s %s #%s: %s -> %s" % (f.get("typeName"), k, pos, CODE.get(a, a), CODE.get(b, b))] += 1
        per_flip.append({"t": f.get("t"), "epoch": f.get("epoch"), "type": f.get("typeName"), "state": f.get("stateName"),
                         "statesAfter": f.get("statesAfter"), "atToAfter": d1, "baselineToAfter": d2})
    ctx = collections.Counter()
    for f in fl:
        c = f.get("ctx") or {}
        inst = c.get("instance") or {}
        ctx["%s/%s" % (f.get("typeName"), inst.get("type") or "?")] += 1
    return {"origin": origin, "flips": len(fl), "byType": by_type, "markers": dict(collections.Counter(m.get("event") for m in markers)),
            "counts": r.get("counts"), "dropped": r.get("dropped"), "probeDeltas": dict(becomes.most_common()), "perFlip": per_flip,
            "contexts": dict(ctx), "sessions": [{k: s.get(k) for k in ("sid", "flips", "markers", "statesAtStart", "statesAtEnd")}
                                                 for s in as_list(r.get("sessions")) if isinstance(s, dict)],
            "items": fl, "markerItems": markers}


def _when(ep, offset):
    if not isinstance(ep, (int, float)):
        return "?"
    tz = datetime.timezone(datetime.timedelta(seconds=offset or 0))
    return datetime.datetime.fromtimestamp(ep, tz).strftime("%H:%M:%S")


def markdown(s, utc_offset=None):
    L = ["# Addon restrictions (ADDON_RESTRICTION_STATE_CHANGED)", "",
         "Source: %s. %d flip(s)." % (s["origin"], s["flips"]), "",
         "States: 0 Inactive, 1 Activating (dispatch in progress; NOT enforced until the event dispatch completes), 2 Active.",
         "Types: 0 Combat, 1 Encounter, 2 ChallengeMode, 3 PvPMatch, 4 Map, 5 Chat.", ""]
    L += ["| type | flips | states | active intervals (s) | InCombatLockdown at Activating |", "|---|---|---|---|---|"]
    for t, d in s["byType"].items():
        a = d["activeSec"]
        L.append("| %s | %d | %s | n=%d total=%s min=%s max=%s | %s |" % (
            t, d["flips"], ", ".join("%s %d" % kv for kv in sorted(d["states"].items())), a["n"], a["total"], a["min"], a["max"],
            ", ".join("%s: %d" % kv for kv in sorted(d["inCombatAtActivating"].items())) or "-"))
    if s["markers"]:
        L += ["", "Context markers: " + ", ".join("%s %d" % kv for kv in sorted(s["markers"].items()))]
    if s["probeDeltas"]:
        L += ["", "## What changes at a flip (probe at the event vs next frame)", ""]
        for k, v in s["probeDeltas"].items():
            L.append("- %dx %s" % (v, k))
    elif s["origin"].startswith("v2.1"):
        L += ["", "No flip probes in this data (v2.1 logged flips only). v2.2 re-runs a small probe set at each flip and on the next "
              "frame while FD_Logs is ON."]
    L += ["", "## Flips", ""]
    for f in s["items"][:200]:
        c = f.get("ctx") or {}
        inst = c.get("instance") or {}
        L.append("- %s %s -> %s%s%s%s" % (_when(f.get("epoch"), utc_offset), f.get("typeName"), f.get("stateName"),
                                         " (InCombatLockdown)" if c.get("combat") else "",
                                         (" in %s/%s" % (inst.get("type"), inst.get("name"))) if inst.get("type") else "",
                                         (" encounter %s" % (c.get("encounter") or {}).get("name")) if c.get("encounter") else ""))
    return "\n".join(L) + "\n"
