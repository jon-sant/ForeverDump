"""WorldCapture ('ws' tape records) decoder + per-token coverage (v2.2.7).

Each ws record carries five-state codes for 16 fields of one unit token. v2.2.7 stores two exact 32-bit words
(p = fields 1-8, q = fields 9-16). v2.2.6 stored one 64-bit word in a Lua number (53-bit mantissa): its low nibbles
(exists, health, part of healthMax) were rounded away whenever a high field was set. The decoder marks those as
'L' (lost) instead of reporting a wrong code."""
from __future__ import annotations

import collections
import math

FIELDS = ["exists", "health", "healthMax", "power", "powerMax", "threat", "threatDet", "range10", "range28",
          "inRange", "casting", "channeling", "notInt", "buffN", "debuffN", "dead"]
CODES = {0: "N", 1: "S", 2: "T", 3: "K", 4: "C", 5: "E", 6: "G"}


def _nibbles(word, count):
    return [CODES.get((word >> (4 * i)) & 15, "?") for i in range(count)]


def lost_nibbles(p):
    """legacy single-word pack: how many low nibbles a double could not represent"""
    if not isinstance(p, (int, float)) or p < 2 ** 53:
        return 0
    ulp_bits = math.floor(math.log2(p)) - 52
    return min(16, (ulp_bits + 3) // 4)


def decode(rec):
    p, q = rec.get("p"), rec.get("q")
    if not isinstance(p, (int, float)):
        return None, "none"
    if isinstance(q, (int, float)):
        return dict(zip(FIELDS, _nibbles(int(p), 8) + _nibbles(int(q), 8))), "exact"
    codes = _nibbles(int(p), 16)
    k = lost_nibbles(p)
    for i in range(k):
        codes[i] = "L"
    return dict(zip(FIELDS, codes)), ("legacy-lossy" if k else "legacy-exact")


def coverage(tapes):
    """tapes: [{'tape': [...]}] -> per token family: samples, per-field code counts, clear extras seen"""
    fam = collections.defaultdict(lambda: {"samples": 0, "fields": collections.defaultdict(collections.Counter),
                                           "extras": collections.Counter(), "formats": collections.Counter(),
                                           "ids": set(), "tgts": set()})
    for s in tapes:
        for r in s.get("tape") or []:
            if not isinstance(r, dict) or r.get("k") != "ws":
                continue
            f = fam[r.get("tok") or "?"]
            f["samples"] += 1
            codes, fmt = decode(r)
            f["formats"][fmt] += 1
            for k, v in (codes or {}).items():
                f["fields"][k][v] += 1
            for x in ("hp", "th", "tp", "bn", "dn", "sp", "bar", "me", "id", "tgt"):
                if r.get(x) is not None:
                    f["extras"][x] += 1
            if r.get("id"):
                f["ids"].add(str(r["id"]).split(":")[0])
            if r.get("tgt"):
                f["tgts"].add(str(r["tgt"]).split(":")[0])
    out = {}
    for tok, f in fam.items():
        out[tok] = {"samples": f["samples"], "formats": dict(f["formats"]),
                    "fields": {k: dict(v) for k, v in f["fields"].items()}, "extras": dict(f["extras"]),
                    "idKinds": sorted(f["ids"]), "tgtKinds": sorted(f["tgts"])}
    return out


def markdown(cov, fields=("exists", "health", "healthMax", "power", "threat", "range28", "casting", "buffN", "dead")):
    L = ["| token | samples | format | " + " | ".join(fields) + " | clear extras |", "|" + "---|" * (len(fields) + 4)]
    for tok in sorted(cov, key=lambda t: -cov[t]["samples"]):
        c = cov[tok]
        cells = []
        for fld in fields:
            cnt = c["fields"].get(fld) or {}
            cells.append(" ".join("%s%d" % (k, v) for k, v in sorted(cnt.items(), key=lambda kv: -kv[1])) or "-")
        L.append("| %s | %d | %s | %s | %s |" % (tok, c["samples"], ",".join("%s %d" % kv for kv in c["formats"].items()),
                                                 " | ".join(cells), ", ".join("%s %d" % kv for kv in sorted(c["extras"].items())) or "-"))
    return L
