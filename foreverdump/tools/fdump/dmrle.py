"""v2.2.10 lossless DAMAGE_METER_* run-length rows -> every original occurrence.

The addon folds identical DAMAGE_METER_* rows (same event, flags and every scalar argument) into one run row:
  rc = occurrences, q = stream sequence number of the first one,
  dt[k] = ms since the previous occurrence, dq[k] = sequence numbers since the previous occurrence.
Combat ring / event recorder rows carry t (GetTime seconds, ms precision); replay tape dm rows carry d (ms since the
session start) and i (= q). expand_*() rebuild every occurrence with its exact ms time, payload and stream position.
Dump() calls expand_dump() on load, so every converter tool sees the raw stream unchanged."""
from __future__ import annotations

from .luasv import as_list

RLE_KEYS = ("rc", "q", "dt", "dq")


def _ms(t):
    return int(t * 1000 + 0.5) if t >= 0 else -int(-t * 1000 + 0.5)


def _occurrences(row, t_key):
    rc = int(row.get("rc") or 1)
    dt, dq = as_list(row.get("dt")), as_list(row.get("dq"))
    base = {k: v for k, v in row.items() if k not in RLE_KEYS}
    out = []
    if t_key == "t":
        ms, seq = _ms(float(row.get("t") or 0)), int(row.get("q") or 0)
    else:
        ms, seq = int(row.get("d") or 0), int(row.get("q") or row.get("i") or 0)
    for k in range(rc):
        if k:
            ms += int(dt[k - 1])
            seq += int(dq[k - 1])
        occ = dict(base)
        if t_key == "t":
            occ["t"] = ms / 1000.0
        else:
            occ["d"] = ms
            occ["i"] = seq
        out.append((seq, occ))
    return out


def expand_events(events, approx=False):
    """combat ring / recorder events (oldest first) -> raw stream in original order"""
    rows = as_list(events)
    if not any(isinstance(r, dict) and r.get("rc") is not None for r in rows):
        return rows
    virtual = {}
    firsts = {}
    for idx, r in enumerate(rows):
        if isinstance(r, dict) and r.get("rc") is not None:
            occ = _occurrences(r, "t")
            firsts[idx] = occ[0]
            for seq, o in occ[1:]:
                virtual[seq] = o
    if approx:   # ring wrapped at the safety ceiling: positions of folded occurrences vs lost rows are unknown -> time order
        allrows = [r for r in rows if not (isinstance(r, dict) and r.get("rc") is not None)]
        allrows += [o for _, o in firsts.values()] + list(virtual.values())
        return sorted(allrows, key=lambda r: (float(r.get("t") or 0) if isinstance(r, dict) else 0))
    out = []
    seq = 0
    for idx, r in enumerate(rows):
        seq += 1
        while seq in virtual:
            out.append(virtual.pop(seq))
            seq += 1
        if idx in firsts:
            s0, o = firsts[idx]
            seq = s0   # first occurrence position is authoritative
            out.append(o)
        else:
            out.append(r)
    for s in sorted(virtual):   # trailing occurrences after the last stored row
        out.append(virtual[s])
    return out


def expand_tape(tape):
    items = as_list(tape) if not isinstance(tape, dict) else [v for v in tape.values()]
    out = []
    for r in items:
        if isinstance(r, dict) and r.get("rc") is not None:
            out.extend(o for _, o in _occurrences(r, "d"))
        else:
            out.append(r)
    return out


def expand_dump(raw):
    """in place on the parsed SV tables; returns {stream: folded occurrences restored}"""
    stats = {}
    for dbname, label in (("ForeverDumpCombatLogDB", "combat"), ("ForeverDumpRecordDB", "record")):
        for s in as_list((raw.get(dbname) or {}).get("sessions")):
            if isinstance(s, dict) and isinstance(s.get("rle"), dict) and s.get("events") is not None:
                before = len(as_list(s["events"]))
                s["events"] = expand_events(s["events"], approx=bool(s.get("rleOrderApprox")))
                s["rleExpanded"] = len(s["events"]) - before
                stats[label] = stats.get(label, 0) + s["rleExpanded"]
    rep = (raw.get("ForeverDumpLogDB") or {}).get("replay") or {}
    for s in as_list(rep.get("sessions")) + ([rep["current"]] if isinstance(rep.get("current"), dict) else []):
        if isinstance(s, dict) and s.get("tape") is not None and any(
                isinstance(r, dict) and r.get("rc") is not None for r in (s["tape"].values() if isinstance(s["tape"], dict) else as_list(s["tape"]))):
            before = len(as_list(s["tape"]) if not isinstance(s["tape"], dict) else list(s["tape"].values()))
            s["tape"] = expand_tape(s["tape"])
            s["rleExpanded"] = len(s["tape"]) - before
            stats["tape"] = stats.get("tape", 0) + s["rleExpanded"]
    return stats
