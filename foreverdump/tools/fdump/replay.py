"""Offline sealed-tape replay for ForeverDumpLogDB.replay (v2.2.6).

Reads session_hdr + decide/verdict/anchor/map/sec/api ring records from the SV,
reconstructs chronological order, joins cast-sync anchors to CLEU SPELL_CAST_SUCCESS
(when a combat log fixture is provided), and checks decide determinism
(same rule-id + input bitmap → same kind/conf across the tape).

Privacy: tape must not contain raw Player-/Pet- GUIDs or player names; this module
flags any that slip through.
"""
from __future__ import annotations

import collections
import json
import os
import re
import shutil
import subprocess
import tempfile

from .luasv import as_list
from . import combatlog

PLAYER_GUID = re.compile(r"Player-\d+-[0-9A-Fa-f]+")
PET_GUID = re.compile(r"Pet-0-\d+-\d+-\d+-\d+-[0-9A-Fa-f]+")
NAME_REALM = re.compile(r"\b[A-Z][a-z]+-[A-Za-z]+(?:-[A-Za-z]+)?\b")


def _sessions(dump):
    log = dump.log or {}
    rep = log.get("replay") or {}
    return as_list(rep.get("sessions")), rep


def reconstruct_tape(sess):
    """Ring buffer -> chronological list (by rec.i / seq)."""
    tape = sess.get("tape") or {}
    if isinstance(tape, dict):
        items = [v for v in tape.values() if isinstance(v, dict)]
    else:
        items = [v for v in as_list(tape) if isinstance(v, dict)]
    items.sort(key=lambda r: (r.get("i") or 0, r.get("d") or 0))
    return items


def identity_scan(obj, path=""):
    """v2.2.21 (raw identity): list of (path, snippet) for every raw GUID / Name-Realm in tape/hdr (informational:
    identities are stored raw on purpose; this counts them for the report)."""
    hits = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            hits.extend(identity_scan(v, path + "." + str(k)))
    elif isinstance(obj, (list, tuple)):
        for i, v in enumerate(obj):
            hits.extend(identity_scan(v, "%s[%d]" % (path, i)))
    elif isinstance(obj, str):
        if PLAYER_GUID.search(obj) or PET_GUID.search(obj):
            hits.append((path, obj[:80]))
        elif "-" in obj and len(obj) > 6 and NAME_REALM.search(obj):
            if not obj.startswith(("npc:", "Creature-")):
                hits.append((path, obj[:80]))
    return hits


privacy_scan = identity_scan   # pre-2.2.21 name


def join_anchors_cleu(anchors, fx, t0_epoch=None, window_ms=750):
    """Match tape anchors (spell + ms-delta) to CLEU SPELL_CAST_SUCCESS by spell id + time."""
    if not fx or not anchors:
        return {"matched": 0, "anchors": len(anchors or []), "pairs": []}
    casts = []
    for e in fx.get("events") or []:
        if not e.get("cleu") or e.get("sub") != "SPELL_CAST_SUCCESS":
            continue
        a = e.get("a") or []
        spell = a[11] if len(a) > 11 else None
        t = a[0] if a else None
        if spell is None or t is None:
            continue
        casts.append({"t": t, "spell": spell, "src": a[3] if len(a) > 3 else None})
    pairs, used = [], set()
    for an in anchors:
        sp, d_ms = an.get("spell"), an.get("d")
        if sp is None or d_ms is None:
            continue
        # if we have session epoch t0, convert; else relative match among spells
        best, best_dt = None, None
        for i, c in enumerate(casts):
            if i in used or c["spell"] != sp:
                continue
            if t0_epoch is not None:
                dt = abs((c["t"] - t0_epoch) * 1000.0 - float(d_ms))
            else:
                # without epoch: only spell co-occurrence count
                dt = 0.0
            if best is None or dt < best_dt:
                best, best_dt = i, dt
        if best is not None and (t0_epoch is None or best_dt <= window_ms):
            used.add(best)
            pairs.append({"anchor": an, "cleu": casts[best], "dt_ms": best_dt})
    return {"matched": len(pairs), "anchors": len(anchors), "pairs": pairs}


def decide_determinism(records, rules):
    """Group decide rows by (r, b) → set of (kind, c); flag non-singleton groups."""
    groups = collections.defaultdict(set)
    for rec in records:
        if rec.get("k") != "decide":
            continue
        key = (rec.get("r"), rec.get("b"))
        groups[key].add((rec.get("kind"), rec.get("c")))
    conflicts = []
    for key, outs in groups.items():
        if len(outs) > 1:
            conflicts.append({"rule": key[0], "bits": key[1], "ruleName": (rules or {}).get(key[0]),
                              "outcomes": sorted(list(outs), key=lambda x: str(x))})
    # v2.2.7 (runs 6/6b): 0 groups is NOT a pass when the tape shows combat (meter records) -- the live HSM did not run
    # and "OK (0 groups)" hid it. vacuous = combat evidence without a single decide record.
    combat = any(rec.get("k") == "dm" for rec in records)
    vacuous = len(groups) == 0 and combat
    return {"groups": len(groups), "conflicts": conflicts, "vacuous": vacuous, "ok": len(conflicts) == 0 and not vacuous}


def analyze_session(sess, fx=None):
    hdr = sess.get("hdr") or {}
    tape = reconstruct_tape(sess)
    by_k = collections.Counter(r.get("k") for r in tape)
    rules = sess.get("rules") or {}
    if isinstance(rules, list):
        rules = {i + 1: v for i, v in enumerate(rules)}
    # lua array may be 1-indexed dict
    rules = {int(k) if str(k).isdigit() else k: v for k, v in (rules.items() if isinstance(rules, dict) else [])}
    det = decide_determinism(tape, rules)
    anchors = sess.get("anchors") or as_list(sess.get("anchors"))
    if isinstance(anchors, dict):
        anchors = list(anchors.values())
    t0 = hdr.get("t0")
    # TimeAnchor may be {getTime, epoch}; hdr.anchor
    anchor_meta = hdr.get("anchor") or {}
    t0_epoch = None
    if isinstance(anchor_meta, dict) and anchor_meta.get("epoch") and anchor_meta.get("getTime"):
        # convert session-relative GetTime to epoch via first GetTime sample
        gt0 = float(anchor_meta["getTime"])
        ep0 = float(anchor_meta["epoch"])
        # tape d is ms since sess.t0 (GetTime); epoch ≈ ep0 + (t0 + d/1000 - gt0)
        if t0 is not None:
            t0_epoch = ep0 + (float(t0) - gt0)
    join = join_anchors_cleu(anchors, fx, t0_epoch=t0_epoch)
    priv = identity_scan({"hdr": hdr, "tape": tape, "rules": rules})
    return {
        "verbosity": hdr.get("verbosity"),
        "verbosityEnd": hdr.get("verbosityEnd"),
        "addonVersion": hdr.get("addonVersion"),
        "schemaVersion": hdr.get("schemaVersion"),
        "groupType": hdr.get("groupType"),
        "groupSize": hdr.get("groupSize"),
        "n": sess.get("n") or len(tape),
        "overwritten": sess.get("overwritten") or 0,
        "overflow": sess.get("overflow") or 0,
        "ringOverflow": sess.get("ringOverflow") or {},
        "dropped": sess.get("dropped") or {},
        "bytes": sess.get("bytes") or 0,
        "byKind": dict(by_k),
        "decide": det,
        "anchorJoin": {k: join[k] for k in ("matched", "anchors") if k in join},
        "anchorJoinRate": (join["matched"] / join["anchors"]) if join.get("anchors") else None,
        "rawIdentities": len(priv),
        "rawIdentitySamples": priv[:5],
        "seeds": hdr.get("seeds"),
        "mapStart": hdr.get("mapStart"),
        "mapEnd": hdr.get("mapEnd"),
        "combatLogStart": hdr.get("combatLogStart"),
        "combatLogEnd": hdr.get("combatLogEnd"),
    }


def analyze(dump, combatlog_path=None):
    sessions, rep = _sessions(dump)
    fx = None
    if combatlog_path and os.path.isfile(combatlog_path):
        try:
            fx = combatlog.parse_file(combatlog_path)
        except Exception as e:
            fx = {"_error": str(e), "events": []}
    out_sessions = []
    for i, s in enumerate(sessions):
        if not isinstance(s, dict):
            continue
        out_sessions.append(analyze_session(s, fx=fx if isinstance(fx, dict) and "events" in fx else None))
    return {
        "v": rep.get("v") or 1,
        "sessionCount": len(out_sessions),
        "sessions": out_sessions,
        "combatlog": bool(fx and fx.get("events")),
        "summary": _summary(out_sessions),
    }


def _summary(sessions):
    if not sessions:
        return {"ok": True, "note": "no replay sessions in SV (capture with FD_Logs on v2.2.6+)"}
    priv = sum(s.get("rawIdentities") or 0 for s in sessions)
    conf = sum(len((s.get("decide") or {}).get("conflicts") or []) for s in sessions)
    vac = sum(1 for s in sessions if (s.get("decide") or {}).get("vacuous"))
    return {
        "ok": priv == 0 and conf == 0 and vac == 0,
        "rawIdentities": priv,
        "decideConflicts": conf,
        "decideVacuous": vac,
        "totalRecords": sum(s.get("n") or 0 for s in sessions),
        "verbosities": sorted({s.get("verbosity") for s in sessions if s.get("verbosity")}),
    }


def markdown(res):
    L = ["# ForeverDump sealed replay tape", ""]
    sm = res.get("summary") or {}
    L.append("Sessions: **%d**; records: **%s**; raw identities (stored on purpose): **%s**; decide conflicts: **%s**; vacuous (no decide "
             "records with combat on tape): **%s**."
             % (res.get("sessionCount") or 0, sm.get("totalRecords"), sm.get("rawIdentities"), sm.get("decideConflicts"),
                sm.get("decideVacuous")))
    L.append("")
    if not res.get("sessions"):
        L.append("_No ForeverDumpLogDB.replay sessions. Capture with FD_Logs (v2.2.6+) — default release elevates to test during capture._")
        L.append("")
        return "\n".join(L)
    for i, s in enumerate(res["sessions"], 1):
        L.append("## Session %d (%s → %s)" % (i, s.get("verbosity"), s.get("verbosityEnd")))
        L.append("- addon %s schema %s; group %s/%s; bytes≈%s; overwritten=%s overflow=%s"
                 % (s.get("addonVersion"), s.get("schemaVersion"), s.get("groupType"), s.get("groupSize"),
                    s.get("bytes"), s.get("overwritten"), s.get("overflow")))
        L.append("- kinds: %s" % ", ".join("%s=%d" % kv for kv in sorted((s.get("byKind") or {}).items())))
        det = s.get("decide") or {}
        L.append("- decide determinism: %s (%d groups, %d conflicts)"
                 % ("VACUOUS (combat on tape, 0 decide records: the live HSM did not run)" if det.get("vacuous")
                    else ("OK" if det.get("ok") else "CONFLICTS"), det.get("groups") or 0, len(det.get("conflicts") or [])))
        aj = s.get("anchorJoin") or {}
        if aj.get("anchors"):
            L.append("- cast-sync anchors joined to CLEU SUCCESS: %s / %s (rate %s)"
                     % (aj.get("matched"), aj.get("anchors"),
                        ("%.0f%%" % (100 * (s.get("anchorJoinRate") or 0))) if s.get("anchorJoinRate") is not None else "n/a"))
        elif not res.get("combatlog"):
            L.append("- cast-sync anchors: %d (no combat log provided for join)" % (aj.get("anchors") or 0))
        if s.get("privacyHits"):
            L.append("- **privacy hits: %d** samples: %s" % (s["privacyHits"], s.get("privacySamples")))
        if s.get("ringOverflow"):
            L.append("- ring overflows: %s" % s["ringOverflow"])
        L.append("")
    L.append("## Notes")
    L.append("- Default in-game level is **release** (<1% CPU). FD_Logs elevates to **diag** (v2.2.9 default captureLevel; test on request) ≤10%, then restores.")
    L.append("- `/fdump level` overrides between captures. One zip ships both modes.")
    L.append("")
    return "\n".join(L)


def write(dump, out_dir, combatlog_path=None):
    os.makedirs(out_dir, exist_ok=True)
    res = analyze(dump, combatlog_path=combatlog_path)
    with open(os.path.join(out_dir, "replay.json"), "w", encoding="utf-8") as f:
        json.dump(res, f, indent=2, sort_keys=True)
    md = markdown(res)
    with open(os.path.join(out_dir, "REPLAY.md"), "w", encoding="utf-8") as f:
        f.write(md)
    return res


# --------------------------------------------------------------------------- re-execution

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(HERE, "..", "..", "ForeverDump", "Lib", "HybridState.lua")
RUNNER = os.path.join(HERE, "lua", "hsm_replay.lua")


def _lua():
    for c in ("lua5.1", "lua"):
        if shutil.which(c):
            return c
    return None


def taped_decides(sess):
    """Tape decide rows in order, resolved against sess.rules for rule names."""
    rules = sess.get("rules") or {}
    if isinstance(rules, list):
        rules = {i + 1: v for i, v in enumerate(rules)}
    rules = {int(k) if str(k).isdigit() else k: v for k, v in (rules.items() if isinstance(rules, dict) else [])}
    out = []
    for rec in reconstruct_tape(sess):
        if rec.get("k") != "decide":
            continue
        rid = rec.get("r")
        out.append({
            "id": rec.get("id") or rec.get("i"),
            "r": rid,
            "rule": rules.get(rid) or rules.get(str(rid)),
            "kind": rec.get("kind"),
            "c": rec.get("c"),
            "sp": rec.get("sp"),
            "b": rec.get("b"),
        })
    return out


def reexec_hsm(events_lua_path, shadow=True):
    """Run Lib/HybridState.lua on events via hsm_replay.lua; return parsed JSON (incl. decides)."""
    lua = _lua()
    if not lua:
        return {"_error": "no lua5.1"}
    # inject shadowFindings into events file if needed
    path = events_lua_path
    if shadow:
        raw = open(events_lua_path, encoding="utf-8").read()
        if "shadowFindings" not in raw:
            raw = raw.replace("return {", "return {\n  shadowFindings = true,", 1)
            fd, path = tempfile.mkstemp(suffix=".lua", prefix="hsm_ev_")
            os.close(fd)
            open(path, "w", encoding="utf-8").write(raw)
    try:
        r = subprocess.run([lua, RUNNER, os.path.abspath(LIB), os.path.abspath(path)],
                           capture_output=True, text=True, timeout=60)
    finally:
        if path != events_lua_path and os.path.isfile(path):
            os.remove(path)
    if r.returncode != 0:
        return {"_error": r.stderr or r.stdout, "returncode": r.returncode}
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError as e:
        return {"_error": "bad json: %s" % e, "stdout": r.stdout[:500]}


def exact_match_decides(taped, regenerated):
    """Exact-match determinism: same rule names, confidence codes, kinds, and IDs in order.

    regenerated: list of {rule, kind, c, spell, id} from hsm_replay decides.
    taped: from taped_decides (rule resolved).
    """
    # Align by sequential decide index (tape id may be inference id; regen id is 1..n)
    n = min(len(taped), len(regenerated))
    mismatches = []
    for i in range(n):
        a, b = taped[i], regenerated[i]
        # compare rule name + kind + conf code
        ar, br = a.get("rule"), b.get("rule")
        ak, bk = a.get("kind"), b.get("kind")
        ac, bc = a.get("c"), b.get("c")
        if ar != br or ak != bk or ac != bc:
            mismatches.append({"i": i, "tape": {"rule": ar, "kind": ak, "c": ac, "id": a.get("id")},
                               "regen": {"rule": br, "kind": bk, "c": bc, "id": b.get("id")}})
    return {
        "ok": len(mismatches) == 0 and len(taped) == len(regenerated) and len(taped) > 0,
        "nTape": len(taped),
        "nRegen": len(regenerated),
        "mismatches": mismatches[:20],
        "lengthMatch": len(taped) == len(regenerated),
    }


def cleu_diff(taped_anchors, fx, t0_epoch=None):
    """Diff cast-sync anchors against CLEU SUCCESS: unmatched anchors and unmatched CLEU casts (same spell window)."""
    join = join_anchors_cleu(taped_anchors, fx, t0_epoch=t0_epoch)
    matched_spells = {(p["cleu"]["spell"], p["cleu"]["t"]) for p in join.get("pairs") or []}
    cleu_casts = []
    for e in (fx or {}).get("events") or []:
        if e.get("cleu") and e.get("sub") == "SPELL_CAST_SUCCESS":
            a = e.get("a") or []
            if len(a) > 11 and isinstance(a[11], int):
                cleu_casts.append({"t": a[0], "spell": a[11]})
    unmatched_cleu = [c for c in cleu_casts if (c["spell"], c["t"]) not in matched_spells]
    # only count CLEU near session if we have epoch; else report join stats only
    return {
        "anchorMatched": join.get("matched"),
        "anchorTotal": join.get("anchors"),
        "unmatchedAnchors": (join.get("anchors") or 0) - (join.get("matched") or 0),
        "cleuCasts": len(cleu_casts),
        "unmatchedCleuNear": len(unmatched_cleu) if t0_epoch is not None else None,
        "ok": (join.get("anchors") or 0) == 0 or (join.get("matched") or 0) == (join.get("anchors") or 0),
    }


def reexec_session(sess, events_lua_path, fx=None):
    """Full sealed-tape proof: re-exec HybridState, exact-match decides, optional CLEU diff."""
    taped = taped_decides(sess)
    regen = reexec_hsm(events_lua_path, shadow=True)
    if regen.get("_error"):
        return {"ok": False, "error": regen["_error"], "taped": len(taped)}
    decides = regen.get("decides") or []
    match = exact_match_decides(taped, decides)
    anchors = sess.get("anchors") or []
    if isinstance(anchors, dict):
        anchors = list(anchors.values())
    hdr = sess.get("hdr") or {}
    t0_epoch = None
    am = hdr.get("anchor") or {}
    if isinstance(am, dict) and am.get("epoch") and am.get("getTime") and hdr.get("t0") is not None:
        t0_epoch = float(am["epoch"]) + (float(hdr["t0"]) - float(am["getTime"]))
    cleu = cleu_diff(anchors, fx, t0_epoch=t0_epoch) if fx else {"ok": True, "note": "no CLEU"}
    return {
        "ok": match["ok"] and cleu.get("ok", True),
        "determinism": match,
        "cleu": cleu,
        "nVerdictsRegen": len(regen.get("verdicts") or []),
        "shadowVerdicts": [v for v in (regen.get("verdicts") or []) if str(v.get("kind") or "").startswith("shadow-")],
    }


def perturb_decides(taped):
    """Deliberately break a tape decide stream (must fail exact_match)."""
    import copy
    out = copy.deepcopy(taped)
    if not out:
        return out
    mid = out[len(out) // 2]
    mid["rule"] = "PERTURBED-RULE"
    mid["c"] = 0
    mid["kind"] = "perturbed"
    return out
