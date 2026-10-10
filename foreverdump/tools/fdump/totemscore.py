"""Score the GetTotemInfo per-slot codes (AuraPresence totems tape, v2.2.26+) against the combat log (run 22).

Run 22 (BG): every GetTotemInfo return is secret in BG except the 5th (icon), which is nil (N) for an empty slot and
secret (S) while a totem stands -> per-slot presence side channel. Truth: the player's SPELL_SUMMON rows; the slot
comes from the PLAYER_TOTEM_UPDATE event row (slot argument) nearest to the summon - no totem/element table.
A totem ends at its UNIT_DIED / UNIT_DESTROYED, the next summon in the same slot, the player's death, or after
MAX_LIFE s (unknown duration; those samples are counted 'capped')."""
import argparse
import collections
import json
import sys

from . import refdata
from .aurapresence import anchor_pair, epoch_to_logsec

MAX_LIFE = 120.0
EDGE = 0.7
STEP = 0.5
FIELDS = ("haveTotem", "name", "startTime", "duration", "icon", "modRate", "spellID")


def tape(ap, utc_off, offset=0.0):
    g0, e0 = anchor_pair(ap.get("anchor"))
    tl = collections.defaultdict(list)
    for r in ap.get("totems") or []:
        f = r.split("|")
        if len(f) < 4:
            continue
        t = epoch_to_logsec(e0 + float(f[0]) - g0, utc_off) + offset
        tl[int(f[1])].append((t, f[3], f[-1], f[2]))
    for v in tl.values():
        v.sort()
    return tl


def summons(rows, mine):
    out, died = [], {}
    for t, p in rows:
        if t is None or not p:
            continue
        if p[0] == "SPELL_SUMMON" and len(p) > 10 and p[1] == mine:
            out.append({"t": t, "guid": p[5], "name": p[10], "end": None})
        elif p[0] in ("UNIT_DIED", "UNIT_DESTROYED") and len(p) > 5:
            died.setdefault(p[5], t)
            if p[5] == mine:
                for s in out:
                    if s["end"] is None and s["t"] < t:
                        s["end"], s["why"] = t, "player died"
    for s in out:
        d = died.get(s["guid"])
        if d is not None and (s["end"] is None or d < s["end"]):
            s["end"], s["why"] = d, "died"
    return out


def assign_slots(sm, tl):
    """slot of each summon = the slot of the PLAYER_TOTEM_UPDATE event row nearest to it within 1.5 s (each event row
    used once); no hardcoded totem -> element table"""
    used = set()
    evrows = [(r[0], slot, i) for slot, rows in tl.items() for i, r in enumerate(rows) if r[3] == "event"]
    for s in sm:
        best = None
        for t, slot, i in evrows:
            if (slot, i) in used or not (s["t"] - 0.3 <= t <= s["t"] + 1.5):
                continue
            if best is None or abs(t - s["t"]) < abs(best[0] - s["t"]):
                best = (t, slot, i)
        if best is not None:
            used.add((best[1], best[2]))
        s["slot"] = best[1] if best else None
    by = collections.defaultdict(list)
    for s in sm:
        if s["slot"] is not None:
            by[s["slot"]].append(s)
    for slot, lst in by.items():
        lst.sort(key=lambda x: x["t"])
        for a, b in zip(lst, lst[1:]):
            if a["end"] is None or b["t"] < a["end"]:
                a["end"], a["why"] = b["t"], "replaced"
    return by


def score(ap, rows, mine, utc_off, offset=0.0):
    tl = tape(ap, utc_off, offset)
    sm = summons(rows, mine)
    by = assign_slots(sm, tl)
    tend = max((t for t, _ in rows if t is not None), default=0)
    for lst in by.values():
        for s in lst:
            if s["end"] is None:
                s["end"], s["why"] = min(s["t"] + MAX_LIFE, tend), "capped"
    res = collections.Counter()
    per_tag = collections.defaultdict(collections.Counter)
    for slot, rows_ in tl.items():
        if not rows_:
            continue
        t, i = rows_[0][0], 0
        stop = rows_[-1][0]
        while t < stop:
            while i + 1 < len(rows_) and rows_[i + 1][0] <= t:
                i += 1
            code, tag = rows_[i][1], rows_[i][2]
            ivs = by.get(slot, [])
            on = [s for s in ivs if s["t"] <= t <= s["end"]]
            edge = any(abs(t - s["t"]) < EDGE or abs(t - s["end"]) < EDGE for s in ivs)
            if not edge and len(code) >= 5:
                truth = "totem" if on else "empty"
                if on and on[0].get("why") == "capped":
                    truth = "totem(capped)"
                k = "%s|icon=%s" % (truth, code[4])
                res[k] += 1
                per_tag[tag][k] += 1
            t += STEP
    unslotted = sum(1 for s in sm if s["slot"] is None)
    return {"summons": len(sm), "unslotted": unslotted, "bySlot": {s: len(v) for s, v in sorted(by.items())},
            "samples": dict(sorted(res.items())), "byTag": {k: dict(v) for k, v in sorted(per_tag.items())},
            "codes": ap.get("totemCodes"), "fields": FIELDS}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("sv")
    ap.add_argument("log")
    ap.add_argument("--mine", required=True)
    ap.add_argument("--offset", type=float, default=0.0)
    ap.add_argument("--json")
    a = ap.parse_args(argv)
    from .dump import load_raw
    raw = load_raw(a.sv)
    apd = (raw.get("ForeverDumpLogDB") or {}).get("auraPresence") or {}
    out = score(apd, list(refdata.lines(a.log)), a.mine, refdata.log_utc_offset(a.log), a.offset)
    js = json.dumps(out, indent=1, sort_keys=True, default=str)
    if a.json:
        with open(a.json, "w") as f:
            f.write(js)
    print(js)
    return 0


if __name__ == "__main__":
    sys.exit(main())
