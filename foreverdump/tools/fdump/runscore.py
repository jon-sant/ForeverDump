"""Run scorecard for a v2.2.21/22 BG capture (box only): truth from the scoreboard (server class per full name) joined
to combat-log GUIDs by (first-name token, reaction), then per-unit scoring of the live class engine, the v2.2.22
score-bf join (simulated on the capture's own scoreboard rows vs its plate keys), prefill, census.

Truth sources (independent of the class engine under test):
  - KTH_ForeverDiag scoreRows / scoreInfoRows (name "First Surname", classToken, faction)  [optional]
  - ForeverDump derive.units score-via units (full name + class, server provided)
Log: GUID -> "First-Realm-" names and hostile/friendly flags (relative to the logger).
"""
import collections
import json
import os
import re

PL = re.compile(r'(Player-\d+-[0-9A-F]+),"([^"]+)",(0x[0-9a-fA-F]+)')


def first(n):
    if not isinstance(n, str):
        return None
    b = n.split("-")[0].strip()
    return b.split()[0] if b else None


def log_players(path, t_from=None):
    out = {}
    with open(path, errors="replace") as f:
        for line in f:
            for g, name, flags in PL.findall(line):
                fl = int(flags, 16)
                r = out.setdefault(g, {"name": name, "first": first(name), "reac": collections.Counter(), "n": 0})
                r["n"] += 1
                if fl & 0x40:
                    r["reac"]["hostile"] += 1
                elif fl & 0x10:
                    r["reac"]["friendly"] += 1
                if fl & 0x1:
                    r["reac"]["mine"] += 1
    for r in out.values():
        r["hostile"] = r["reac"]["hostile"] > r["reac"]["friendly"]
    return out


def board_from_kth(kth):
    rows = {}
    for r in kth.get("scoreInfoRows") or []:
        v = r.get("vals") or {}
        if isinstance(v.get("name"), str) and isinstance(v.get("classToken"), str):
            rows[v["name"]] = {"full": v["name"], "first": first(v["name"]), "class": v["classToken"], "faction": v.get("faction")}
    for r in kth.get("scoreRows") or []:
        v = r.get("vals") or {}
        n, cls = v.get("1"), v.get("9")
        if isinstance(n, str) and isinstance(cls, str) and n not in rows:
            rows[n] = {"full": n, "first": first(n), "class": cls, "faction": v.get("6"), "race": v.get("7")}
        elif isinstance(n, str) and n in rows and isinstance(v.get("7"), str):
            rows[n]["race"] = v.get("7")
    return rows


def board_from_fd(raw):
    rows = {}
    units = (((raw.get("ForeverDumpLogDB") or {}).get("derive") or {}).get("units")) or {}
    for k, u in units.items():
        if isinstance(u, dict) and u.get("via") == "score":
            for n in (u.get("names") or {}):
                rows[n] = {"full": n, "first": first(n), "class": u.get("class"), "enemy": u.get("enemy")}
    return rows


def truth(players, board, my_faction):
    """GUID -> class via (first, side). side: hostile <-> faction != mine."""
    by = collections.defaultdict(list)
    for r in board.values():
        side = None if r.get("faction") is None or my_faction is None else (r["faction"] != my_faction)
        by[(r["first"], side)].append(r)
    out, amb = {}, []
    for g, p in players.items():
        cands = by.get((p["first"], p["hostile"])) or []
        if len(cands) == 1:
            out[g] = dict(p, cls=cands[0]["class"], full=cands[0]["full"])
        elif len(cands) > 1:
            amb.append(g)
    return out, amb


def merge_boards(kth_board, fd_board, my_faction):
    b = dict(kth_board)
    for n, r in fd_board.items():
        if n not in b and my_faction is not None and r.get("enemy") is not None:
            b[n] = dict(r, faction=(1 - my_faction) if r["enemy"] else my_faction)
    return b


def live_units(raw, tr):
    """per-unit scoring of derive.units (class engine) against truth (GUID -> cls). Keys: name:<First> or name:<Full>."""
    units = (((raw.get("ForeverDumpLogDB") or {}).get("derive") or {}).get("units")) or {}
    by_full = {v["full"]: g for g, v in tr.items()}
    by_first = collections.defaultdict(list)
    for g, v in tr.items():
        by_first[v["first"]].append(g)
    rows = []
    for k, u in units.items():
        if not isinstance(u, dict) or not isinstance(k, str) or not k.startswith("name:"):
            continue
        n = k[5:]
        gs = []
        if n in by_full:
            gs = [by_full[n]]
        else:
            gs = [g for g in by_first.get(first(n), []) if u.get("enemy") is None or tr[g]["hostile"] == bool(u.get("enemy"))]
        for g in (u.get("guids") or {}):
            if g in tr:
                gs = [g]
        rec = {"key": k, "class": u.get("class"), "via": u.get("via"), "enemy": u.get("enemy"), "prov": u.get("prov"),
               "chain": u.get("chain"), "guids": gs}
        if len(gs) == 1:
            t = tr[gs[0]]["cls"]
            rec["truth"] = t
            rec["ok"] = None if not u.get("class") else (u.get("class") == t)
        elif len(gs) > 1:
            truths = {tr[g]["cls"] for g in gs}
            rec["truth"] = "/".join(sorted(truths))
            rec["ok"] = None if not u.get("class") else (u.get("class") in truths and len(truths) == 1)
            rec["ambiguous"] = True
        rows.append(rec)
    return rows


def plate_keys(raw):
    """keys the live client produced from plates / raid tokens (UnitName form), i.e. power / cache chains"""
    units = (((raw.get("ForeverDumpLogDB") or {}).get("derive") or {}).get("units")) or {}
    out = {}
    for k, u in units.items():
        if not isinstance(u, dict) or not isinstance(k, str) or not k.startswith("name:"):
            continue
        ch = u.get("chain") or []
        if u.get("via") != "score" or any(isinstance(c, str) and (c.startswith("power=") or c.startswith("cache:")) for c in ch):
            out[k[5:]] = u
    return out


def bfjoin_v2222(board, plates, my_faction, tr):
    """v2.2.22 rule on the scoreboard rows vs the plate keys; per-unit false check against truth."""
    by_first = collections.defaultdict(list)
    for r in board.values():
        by_first[r["first"]].append(r)
    res = collections.Counter()
    assigned = []
    for fn, rows in by_first.items():
        fac = collections.Counter(r.get("faction") for r in rows)
        for r in rows:
            enemy = None if r.get("faction") is None or my_faction is None else r["faction"] != my_faction
            if fac[r.get("faction")] > 1:
                res["dupFac"] += 1
                continue
            p = plates.get(fn)
            if len(rows) > 1:
                if p is None or p.get("enemy") is None or bool(p.get("enemy")) != enemy:
                    res["pendingCrossFac"] += 1
                    continue
                how = "crossFac"
            else:
                how = "unique"
            res[how] += 1
            if p is not None:
                res["metPlate"] += 1
            assigned.append((fn, r["class"], enemy, how, p is not None))
    # false: an assigned name:First whose plate unit (by truth, same first + side) has a different class
    by_first_t = collections.defaultdict(list)
    for g, v in tr.items():
        by_first_t[v["first"]].append(v)
    false, checked = [], 0
    for fn, cls, enemy, how, met in assigned:
        tv = [v for v in by_first_t.get(fn, []) if enemy is None or v["hostile"] == enemy]
        if len(tv) == 1:
            checked += 1
            if tv[0]["cls"] != cls:
                false.append((fn, cls, tv[0]["cls"]))
    res["assigned"] = len(assigned)
    res["checked"] = checked
    res["false"] = len(false)
    return dict(res), false
