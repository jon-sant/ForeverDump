"""Scripted-event verifier (run 20, PvE dungeon): combat-log truth per scripted event joined to what ForeverDump saw live.

For each event family it finds the combat-log rows (truth), maps them onto the client's GetTime() clock and lists, in a
window around each row, the recorder ring events (UNIT_AURA / UNIT_SPELLCAST_* / UNIT_COMBAT / PLAYER_TOTEM_UPDATE /
UNIT_DIED ...) by unit token, phase (ooc / combat, from PLAYER_REGEN_*) and argument code (C clear, S secret, N nil,
T secret table), plus the replay tape's 'decide' rows (FD's live derivations) and the aura-presence tape.

The GetTime <-> log clock offset is fitted from the player's own casts (UNIT_SPELLCAST_SUCCEEDED spellID clear vs
SPELL_CAST_SUCCESS), so the integer-second epoch anchor's up-to-1 s error does not misplace windows.

usage: python3 -m tools.fdump.pvescript SV.lua WoWCombatLog.txt --mine GUID [--json out.json] [--md out.md]
"""
import argparse
import bisect
import collections
import json
import statistics
import sys

from . import refdata
from .aurapresence import anchor_pair, as_list, epoch_to_logsec, parse_tape, _strkeys

FD_EVENTS = ("UNIT_AURA", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
             "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_COMBAT",
             "PLAYER_TOTEM_UPDATE", "UNIT_DIED", "WEAPON_ENCHANT_CHANGED", "UNIT_SPELLCAST_CHANNEL_START",
             "UNIT_HEAL_PREDICTION", "UNIT_SPELLCAST_SENT")


def code(v):
    if v == "<secret>":
        return "S"
    if v == "<secrettable>":
        return "T"
    if v == "<nil>" or v is None:
        return "N"
    if isinstance(v, dict):
        inner = "".join(sorted({code(x) if not isinstance(x, (dict, list)) else "K" for x in v.values()}))
        return "K{%s}" % inner
    return "C"


def sig(ev):
    """'token|code code ...' (token is arg 1 when it is a unit string)"""
    a = as_list(ev.get("a"))
    if not a:
        return "-", ""
    tok = a[0] if isinstance(a[0], str) and not a[0].startswith("<") else None
    rest = a[1:] if tok else a
    return (tok or "-"), " ".join(code(x) for x in rest)


def fit_offset(rec, g0, e0, cl, mine, utc_off=None):
    """median(log seconds of own SPELL_CAST_SUCCESS - mapped GetTime of the matching UNIT_SPELLCAST_SUCCEEDED)"""
    own = collections.defaultdict(list)
    for t, p in cl:
        if p[0] == "SPELL_CAST_SUCCESS" and len(p) > 9 and p[1] == mine:
            try:
                own[int(p[9])].append(t)
            except ValueError:
                pass
    d = []
    for ev in rec:
        a = as_list(ev.get("a"))
        if ev.get("e") == "UNIT_SPELLCAST_SUCCEEDED" and len(a) > 2 and a[0] == "player" and isinstance(a[2], (int, float)):
            lt = epoch_to_logsec(e0 + (ev["t"] - g0), utc_off)
            ts = own.get(int(a[2])) or []
            if ts:
                best = min(ts, key=lambda x: abs(x - lt))
                if abs(best - lt) < 3:
                    d.append(best - lt)
    return (statistics.median(d) if d else 0.0), len(d)


def phases(rec):
    """sorted [(t, 'combat'|'ooc')] transitions from PLAYER_REGEN_DISABLED / _ENABLED"""
    out = []
    for ev in rec:
        if ev.get("e") == "PLAYER_REGEN_DISABLED":
            out.append((ev["t"], "combat"))
        elif ev.get("e") == "PLAYER_REGEN_ENABLED":
            out.append((ev["t"], "ooc"))
    return out


def phase_at(ph, t):
    i = bisect.bisect_right([x[0] for x in ph], t) - 1
    return ph[i][1] if i >= 0 else "ooc"


def fmt(logsec):
    s = logsec % 86400
    return "%02d:%02d:%06.3f" % (s // 3600, s % 3600 // 60, s % 60)


def find_truth(cl, mine):
    """event key -> list of {t, ev, src, dst, sid, spell, extra}"""
    out = collections.defaultdict(list)
    grounding = set()
    own = {mine}   # me + my summons (totems): run 21 (open world) had another shaman's Flame Shock in the truth
    for t, p in cl:
        ev = p[0]
        if len(p) < 9:
            continue
        src, srcN, dst, dstN = p[1], p[2], p[5], p[6]
        sid = None
        spell = None
        if len(p) > 10 and not ev.startswith(("SWING", "UNIT_", "PARTY_", "ENCHANT")):
            try:
                sid, spell = int(p[9]), p[10]
            except ValueError:
                pass
        row = {"t": t, "time": fmt(t), "ev": ev, "src": srcN, "dst": dstN, "sid": sid, "spell": spell}
        if ev == "SPELL_SUMMON" and src == mine:
            own.add(dst)
        mineRow = src in own or dst in own
        aura = ev.startswith("SPELL_AURA_")
        if aura:
            row["auraType"] = p[12] if len(p) > 12 else None
            if ev.endswith("_DOSE") and len(p) > 13:
                row["stacks"] = p[13]
        if ev == "ENCHANT_APPLIED" and mineRow:
            row.update(spell=p[9] if len(p) > 9 else None, sid=int(p[10]) if len(p) > 10 and p[10].isdigit() else None,
                       item=p[12] if len(p) > 12 else None)
            out["1-self-buffs"].append(row)
        if aura and src == mine and dst == mine:
            out["1-self-buffs"].append(row)
        if sid == 8052 and src == mine and dst != mine:
            out["2-flame-shock"].append(row)
        if sid == 18070 and dst == mine:
            out["3-earthborer-acid"].append(row)
        if sid == 17364 and (aura or ev in ("SPELL_CAST_SUCCESS",)) and src == mine and dst != mine:
            out["4-stormstrike"].append(row)
        if sid == 1238931 and mineRow:
            out["4-stormstrike"].append(row)
        if ev == "SPELL_MISSED" and len(p) > 12 and p[12] == "IMMUNE" and mineRow:
            row["miss"] = "IMMUNE"
            out["5-immune"].append(row)
        if ev in ("SPELL_HEAL", "SPELL_PERIODIC_HEAL") and dst == mine:
            out["6-self-heal"].append(row)
        if ev == "SPELL_SUMMON" and sid == 8177 and src == mine:
            grounding.add(dst)
            out["7-grounding"].append(row)
        if (dst in grounding or src in grounding) and ev != "SPELL_SUMMON":
            out["7-grounding"].append(row)
        if ev == "UNIT_DIED" and dst in grounding:
            out["7-grounding"].append(row)
        if ev == "SPELL_INTERRUPT" and mineRow:
            row["interrupted"] = "%s %s" % (p[12], p[13]) if len(p) > 13 else None
            out["8-interrupt"].append(row)
        if ev == "SPELL_MISSED" and len(p) > 12 and dst == mine and sid == 9532:
            row["miss"] = p[12]
            out["9-resist"].append(row)
        if ev == "SPELL_MISSED" and len(p) > 12 and p[12] == "RESIST" and mineRow:
            row["miss"] = "RESIST"
            if row not in out["9-resist"]:
                out["9-resist"].append(row)
    return out


def fd_window(rec, g, lo=-0.3, hi=1.2, names=FD_EVENTS):
    out = []
    i = bisect.bisect_left([e["t"] for e in rec], g + lo)
    while i < len(rec) and rec[i]["t"] <= g + hi:
        ev = rec[i]
        if ev.get("e") in names:
            tok, c = sig(ev)
            out.append((ev["e"], tok, c, bool(ev.get("c")), ev["t"]))
        i += 1
    return out


def analyse(raw, cl, mine, utc_off=None):
    L = raw.get("ForeverDumpLogDB") or {}
    sess = as_list((raw.get("ForeverDumpRecordDB") or {}).get("sessions"))
    rec = sorted((e for s in sess for e in as_list(s.get("events"))), key=lambda e: e["t"])
    ap = L.get("auraPresence") or {}
    g0, e0 = anchor_pair(ap.get("anchor"))
    off, npairs = fit_offset(rec, g0, e0, cl, mine, utc_off)
    l0 = epoch_to_logsec(e0, utc_off)
    log2g = lambda t: g0 + (t - off - l0)  # noqa: E731
    ph = phases(rec)
    truth = find_truth(cl, mine)
    tape = []
    for sres in as_list((L.get("replay") or {}).get("sessions")):
        t0 = sres.get("t0") or 0
        for r in as_list(sres.get("tape")):
            if r.get("k") == "decide":
                tape.append(dict(r, g=t0 + (r.get("d") or 0) / 1000.0))
    tape.sort(key=lambda r: r["g"])
    apt = parse_tape(ap.get("tape"))
    report = {"logUtcOffset": utc_off, "offset": off, "offsetPairs": npairs, "events": {}}
    for key in sorted(truth):
        rows = []
        agg = collections.Counter()
        for r in truth[key]:
            g = log2g(r["t"])
            r = dict(r, g=round(g, 3), phase=phase_at(ph, g))
            fd = fd_window(rec, g)
            r["fd"] = sorted({"%s %s [%s]%s" % (e, tok, c, " c" if inc else "") for e, tok, c, inc, _t in fd})
            for e, tok, c, inc, t in fd:
                agg[(phase_at(ph, t), e, tok, c)] += 1   # phase of the FD event itself, not of the log row
            dec = [d for d in tape if g - 0.3 <= d["g"] <= g + 1.2 and (r.get("sid") is None or d.get("sp") in (None, r.get("sid")))]
            r["decide"] = sorted({"%s %s sp=%s c=%s" % (d.get("kind"), d.get("u"), d.get("sp"), d.get("c")) for d in dec})
            if r.get("sid"):
                r["presence"] = ["%s %s %s %s" % (fmt(epoch_to_logsec(e0 + (s["t"] - g0), utc_off) + off), s["unit"], s["st"], s["tag"])
                                 for s in apt if s["sid"] == r["sid"] and g - 1.5 <= s["t"] <= g + 1.5]
            rows.append(r)
        report["events"][key] = {"truth": rows,
                                 "fdAgg": [{"phase": k[0], "event": k[1], "token": k[2], "codes": k[3], "n": n}
                                           for k, n in sorted(agg.items())]}
    report["codes"] = ap.get("codes")
    return report


def to_md(rep):
    out = ["# Scripted-event verification", "", "clock offset (log - anchor) = %.3f s from %d own-cast pairs" %
           (rep["offset"], rep["offsetPairs"]), ""]
    for key, ev in rep["events"].items():
        out += ["## " + key, "", "| time ET | phase | CL event | src -> dst | spell (id) | extra |", "|---|---|---|---|---|---|"]
        for r in ev["truth"]:
            ex = " ".join("%s=%s" % (k, r[k]) for k in ("auraType", "stacks", "miss", "interrupted", "item") if r.get(k))
            out.append("| %s | %s | %s | %s -> %s | %s (%s) | %s |" % (r["time"], r["phase"], r["ev"], r["src"], r["dst"],
                                                                 r.get("spell"), r.get("sid"), ex))
        out += ["", "FD live (recorder, window -0.3..+1.2 s around each row):", "", "| phase | event | token | arg codes | n |",
                "|---|---|---|---|---|"]
        for a in ev["fdAgg"]:
            out.append("| %s | %s | %s | %s | %d |" % (a["phase"], a["event"], a["token"], a["codes"], a["n"]))
        dec = collections.Counter(d for r in ev["truth"] for d in r.get("decide", []))
        if dec:
            out += ["", "FD replay decides: " + "; ".join("%s x%d" % kv for kv in sorted(dec.items()))]
        pres = sorted({p for r in ev["truth"] for p in r.get("presence", [])})
        if pres:
            out += ["", "aura-presence tape: " + "; ".join(pres)]
        out.append("")
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("sv")
    ap.add_argument("log")
    ap.add_argument("--mine", required=True, help="the player's GUID")
    ap.add_argument("--json")
    ap.add_argument("--md")
    a = ap.parse_args(argv)
    from .dump import load_raw
    raw = load_raw(a.sv)
    cl = [(t, p) for t, p in refdata.lines(a.log) if t is not None and p]
    rep = analyse(raw, cl, a.mine, refdata.log_utc_offset(a.log))
    if a.json:
        with open(a.json, "w") as f:
            json.dump(_strkeys(rep), f, indent=1, default=str)
    md = to_md(rep)
    if a.md:
        with open(a.md, "w") as f:
            f.write(md)
    print(md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
