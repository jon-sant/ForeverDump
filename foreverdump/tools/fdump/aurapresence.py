"""v2.2.25 aura-presence probe: offline scorer.

The addon (ForeverDump/AuraPresence.lua) writes ForeverDumpLogDB.auraPresence:
  codes[envTag][unitFamily][spellID] = {N|S|K|T|C|E|held: n}   result codes of C_UnitAuras.GetUnitAuraBySpellID
  tape = ["t|unit|name|guid|sid|state|envTag", ...]           change-only presence states P/A/S/C/E/H
  anchor = {gameTime, epoch}                                   GetTime() <-> time() at the first tick
This scores the tape's P (present) / A (absent) states against the combat log's aura state for the same player and
spell (SPELL_AURA_APPLIED / _REFRESH / _APPLIED_DOSE open, SPELL_AURA_REMOVED / UNIT_DIED close). S / C / E / H are
reported as "unreadable" per env tag - the key question is whether presence is readable while restricted.

usage: python3 -m tools.fdump.aurapresence SV.lua WoWCombatLog.txt truth.json [--json out.json]
"""
import argparse
import bisect
import collections
import json
import os
import sys
import time

from . import refdata

OPEN = {"SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH", "SPELL_AURA_APPLIED_DOSE"}
CLOSE = {"SPELL_AURA_REMOVED"}
EDGE = 0.5   # s: a tape sample within EDGE of a log transition is scored "edge" (not right / wrong)


def as_list(x):
    if isinstance(x, list):
        return x
    if isinstance(x, dict):
        try:
            return [x[k] for k in sorted(x, key=lambda k: int(k))]
        except (TypeError, ValueError):
            return list(x.values())
    return []


def parse_tape(rows):
    out = []
    for r in as_list(rows):
        p = str(r).split("|")
        if len(p) < 7:
            continue
        try:
            out.append({"t": float(p[0]), "unit": p[1], "name": p[2], "guid": p[3], "sid": int(p[4]), "st": p[5],
                        "tag": "|".join(p[6:])})
        except ValueError:
            continue
    return out


def log_intervals(lines_iter, sids=None):
    """(guid, sid) -> sorted list of [start, end] log-seconds; plus the transition times"""
    openAt, iv = {}, collections.defaultdict(list)
    for t, p in lines_iter:
        if t is None or not p:
            continue
        ev = p[0]
        if ev in OPEN or ev in CLOSE:
            if len(p) < 10:
                continue
            try:
                sid = int(p[9])
            except ValueError:
                continue
            if sids is not None and sid not in sids:
                continue
            k = (p[5], sid)
            if ev in OPEN:
                openAt.setdefault(k, t)
            elif k in openAt:
                iv[k].append([openAt.pop(k), t])
        elif ev == "UNIT_DIED" and len(p) > 5:
            for k in [k for k in openAt if k[0] == p[5]]:
                iv[k].append([openAt.pop(k), t])
    for k, t0 in openAt.items():
        iv[k].append([t0, float("inf")])
    return iv


def state_at(ivs, t):
    """True present / False absent / None within EDGE of a transition"""
    for a, b in ivs or ():
        if abs(t - a) <= EDGE or (b != float("inf") and abs(t - b) <= EDGE):
            return None
        if a <= t <= b:
            return True
    return False


def anchor_pair(anc):
    """(gameTime, epoch) of an anchor; the refined second-edge pair (Core.TimeAnchor epochTick / gameTimeTick) when the
    addon recorded it (v2.2.26 source), else the coarse whole-second pair (<= 1 s early)."""
    anc = anc or {}
    if isinstance(anc.get("epochTick"), (int, float)) and isinstance(anc.get("gameTimeTick"), (int, float)):
        return anc["gameTimeTick"], anc["epochTick"]
    return anc.get("gameTime"), anc.get("epoch")


def epoch_to_logsec(epoch, utc_off=None):
    """epoch -> refdata log seconds. utc_off: the log's own zone in hours (refdata.log_utc_offset); None falls back to
    the box zone (correct only when the box runs in the client's zone)."""
    lt = time.localtime(epoch) if utc_off is None else time.gmtime(epoch + utc_off * 3600)
    return refdata.log_seconds(lt.tm_year, lt.tm_mon, lt.tm_mday, lt.tm_hour, lt.tm_min, lt.tm_sec) + (epoch - int(epoch))


def name_index(truth):
    """'First Surname' (UnitName name + realm, realm == Forever surname) and first name -> guid"""
    full, first = {}, collections.defaultdict(list)
    for g, r in (truth or {}).items():
        if r.get("full"):
            full[r["full"]] = g
        if r.get("first"):
            first[r["first"]].append(g)
    return full, first


def resolve(sample, full, first, mine_guid=None):
    if sample["guid"]:
        return sample["guid"], "guid"
    if sample["unit"] == "player" and mine_guid:
        return mine_guid, "player"
    nm = sample["name"]
    if not nm:
        return None, "noname"
    fn = nm.replace("-", " ", 1)
    if fn in full:
        return full[fn], "full"
    f = nm.split("-")[0]
    if len(first.get(f, ())) == 1:
        return first[f][0], "first"
    return None, "ambiguous"


def score(ap, iv, truth, offset=0.0, utc_off=None):
    g0, e0 = anchor_pair(ap.get("anchor"))
    full, first = name_index(truth)
    mine = next((g for g, r in (truth or {}).items() if r.get("mine")), None)
    res = collections.defaultdict(lambda: collections.Counter())
    unresolved = collections.Counter()
    for s in parse_tape(ap.get("tape")):
        tag = s["tag"]
        if s["st"] not in ("P", "A", "U", "D"):
            res[tag]["unreadable:" + s["st"]] += 1
            continue
        if g0 is None or e0 is None:
            res[tag]["noanchor"] += 1
            continue
        g, how = resolve(s, full, first, mine)
        if not g:
            unresolved[how] += 1
            res[tag]["unresolved"] += 1
            continue
        lt = epoch_to_logsec(e0 + (s["t"] - g0), utc_off) + offset
        truthState = state_at(iv.get((g, s["sid"])), lt)
        if s["st"] == "U":
            # v2.2.26: unknown is never scored as absent; report what the log had at that moment
            res[tag]["unknown:" + ("edge" if truthState is None else ("present" if truthState else "absent"))] += 1
            continue
        if truthState is None:
            res[tag]["edge"] += 1
        elif truthState == (s["st"] in ("P", "D")):
            res[tag]["agree:" + s["st"]] += 1
        else:
            res[tag]["disagree:" + s["st"]] += 1
    return {k: dict(v) for k, v in res.items()}, dict(unresolved)


def extras(ap, g0=None, e0=None, utc_off=None, offset=0.0):
    """v2.2.26 probe sections: tracked list, restricted share, OOC AuraData detail, totems, derived, restriction flips,
    health context. Empty dict for a v2.2.25 tape."""
    out = {}
    if ap.get("list"):
        out["list"] = ap["list"]
    if ap.get("restricted"):
        out["restricted"] = ap["restricted"]
    det = [str(r).split("|") for r in as_list(ap.get("detail"))]
    if det:
        by = collections.defaultdict(collections.Counter)
        for p in det:
            if len(p) >= 15:
                by[p[-1]]["rows"] += 1
                by[p[-1]]["stacks>1" if p[5].isdigit() and int(p[5]) > 1 else "stacks<=1"] += 1
                by[p[-1]]["withPoints" if p[8] else "noPoints"] += 1
        out["detail"] = {k: dict(v) for k, v in by.items()}
        out["detailSpells"] = len({p[4] for p in det if len(p) > 4})
        out["detailDropped"] = ap.get("detailDropped", 0)
    if ap.get("totemCodes"):
        out["totemCodes"] = ap["totemCodes"]
        out["totemRows"] = len(as_list(ap.get("totems")))
    der = [str(r).split("|") for r in as_list(ap.get("derived"))]
    if der:
        c = collections.Counter((p[1], p[2], p[3]) for p in der if len(p) >= 8)
        out["derived"] = [{"cast": int(k[0]), "aura": int(k[1]), "on": k[2], "n": n} for k, n in sorted(c.items())]
    for k in ("restrict", "hctx"):
        if ap.get(k):
            out[k] = ap[k]
    return out


def code_table(ap):
    """envTag -> {code: n} summed over unit families and spells (the readability question)"""
    out = {}
    for tag, byF in (ap.get("codes") or {}).items():
        c = collections.Counter()
        for _f, byS in (byF or {}).items():
            for _sid, cc in (byS or {}).items():
                for k, n in (cc or {}).items():
                    if isinstance(n, (int, float)):
                        c[k] += n
        out[tag] = dict(c)
    return out


def occurrence(log_paths, sids):
    """spellID -> SPELL_AURA_APPLIED count over the given combat logs"""
    c = collections.Counter()
    for path in log_paths:
        for _t, p in refdata.lines(path):
            if p and p[0] == "SPELL_AURA_APPLIED" and len(p) > 9:
                try:
                    sid = int(p[9])
                except ValueError:
                    continue
                if sid in sids:
                    c[sid] += 1
    return dict(c)


def auto_offset(raw, apd, log_path, truth):
    """(offset, pairs): median log-minus-anchor time over the player's own UNIT_SPELLCAST_SUCCEEDED (clear spellID) vs
    SPELL_CAST_SUCCESS rows; (0.0, 0) when there is no 'mine' GUID, no anchor or no pair."""
    from .pvescript import fit_offset
    mine = next((g for g, r in (truth or {}).items() if r.get("mine")), None)
    g0, e0 = anchor_pair(apd.get("anchor"))
    if not mine or g0 is None or e0 is None:
        return 0.0, 0
    rec = sorted((e for s in as_list((raw.get("ForeverDumpRecordDB") or {}).get("sessions"))
                  for e in as_list(s.get("events")) if isinstance(e, dict) and "t" in e), key=lambda e: e["t"])
    cl = [(t, p) for t, p in refdata.lines(log_path) if t is not None and p]
    return fit_offset(rec, g0, e0, cl, mine, refdata.log_utc_offset(log_path))


def _strkeys(o):
    """SV tables mix integer (spellID / array) and string keys; JSON keys are strings anyway (run 19 crash fix)."""
    if isinstance(o, dict):
        return {str(k): _strkeys(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [_strkeys(v) for v in o]
    return o


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("sv")
    ap.add_argument("log")
    ap.add_argument("truth")
    ap.add_argument("--offset", default="auto",
                    help="seconds added to the anchor-mapped time, or 'auto' (default): fitted from the player's own casts "
                         "(the anchor's epoch is whole seconds, so it can be up to 1 s early - run 20 scored 4 false "
                         "disagreements at offset 0)")
    ap.add_argument("--json")
    a = ap.parse_args(argv)
    from .dump import load_raw
    raw = load_raw(a.sv)
    apd = (raw.get("ForeverDumpLogDB") or {}).get("auraPresence")
    if not apd:
        print("no auraPresence section (capture level lab, v2.2.25+ needed)")
        return 2
    sids = {s["sid"] for s in parse_tape(apd.get("tape"))}
    iv = log_intervals(refdata.lines(a.log), sids or None)
    truth = json.load(open(a.truth))
    off, npairs = (float(a.offset), None) if a.offset != "auto" else auto_offset(raw, apd, a.log, truth)
    sc, unres = score(apd, iv, truth, off, refdata.log_utc_offset(a.log))
    out = {"offset": off, "offsetPairs": npairs, "codes": code_table(apd), "score": sc, "unresolved": unres, "fields": apd.get("fields"),
           "slots": apd.get("slots"), "caster": apd.get("caster"), "bigDef": apd.get("bigDef"), "err": apd.get("err"),
           "tapeVersion": apd.get("v", 1), "v2226": extras(apd)}
    js = json.dumps(_strkeys(out), indent=1, sort_keys=True, default=str)
    if a.json:
        with open(a.json, "w") as f:
            f.write(js)
    print(js)
    return 0


if __name__ == "__main__":
    sys.exit(main())
