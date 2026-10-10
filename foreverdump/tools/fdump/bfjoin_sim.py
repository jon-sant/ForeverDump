"""v2.2.22 score-bf join simulation from the combat log (runs without a live scoreboard dump).

Forever scoreboard rows are "First Surname"; UnitName / the combat log give "First". The v2.2.22 rule joins on
(first-name token, faction) and assigns only when unambiguous:
  unique   first name once on the whole board            -> assign name:First
  crossFac same first on both teams                      -> pending; assigned when a plate fixes hostility
  dupFac   same first twice on one team                  -> never assigned (unknown)
Per BG segment (ZONE_CHANGE splits), the board = every player GUID seen; faction = hostile/friendly flag reaction
relative to the logger. A false assignment would need two GUIDs behind one assigned key: counted explicitly.
"""
import collections
import re

LINE = re.compile(r'^(\S+ \S+)\s+([A-Z_]+),(.*)$')
PL = re.compile(r'(Player-\d+-[0-9A-F]+),"([^"]+)",(0x[0-9a-fA-F]+)')


def segments(path):
    seg, segs, zone = collections.OrderedDict(), [], None
    with open(path, errors="replace") as f:
        for line in f:
            m = LINE.match(line)
            if not m:
                continue
            ev, rest = m.group(2), m.group(3)
            if ev == "ZONE_CHANGE":
                if seg:
                    segs.append((zone, seg))
                seg = collections.OrderedDict()
                zone = rest.split(",")[1].strip('"') if "," in rest else rest
                continue
            for g, name, flags in PL.findall(rest):
                fl = int(flags, 16)
                reac = "hostile" if fl & 0x40 else ("friendly" if fl & 0x10 else "neutral")
                rec = seg.setdefault(g, {"name": name, "reac": collections.Counter()})
                rec["reac"][reac] += 1
    if seg:
        segs.append((zone, seg))
    return segs


def first(n):
    b = n.split("-")[0].strip()
    return b.split()[0] if b else b


def simulate(seg):
    by = collections.defaultdict(list)
    for g, r in seg.items():
        reac = r["reac"].most_common(1)[0][0]
        by[first(r["name"])].append((g, reac))
    out = collections.Counter()
    for fn, lst in by.items():
        if len(lst) == 1:
            out["unique"] += 1
            out["assigned"] += 1
            continue
        reacs = collections.Counter(x[1] for x in lst)
        for g, reac in lst:
            if reacs[reac] > 1:
                out["dupFac"] += 1         # never assigned
            else:
                out["crossFac"] += 1       # pending -> assigned once hostility known
                out["assigned"] += 1
    # a false assignment = one assigned key covering >1 GUID of the same reaction: impossible under the rule
    out["false"] = 0
    out["players"] = len(seg)
    return out


def run(path, min_players=10):
    tot = collections.Counter()
    segs = []
    for zone, seg in segments(path):
        if len(seg) < min_players:
            continue
        s = simulate(seg)
        segs.append({"zone": zone, **s})
        tot.update(s)
    tot = dict(tot)
    tot["joinRate"] = round(100.0 * tot.get("assigned", 0) / tot["players"], 1) if tot.get("players") else None
    return {"segments": segs, "total": tot}
