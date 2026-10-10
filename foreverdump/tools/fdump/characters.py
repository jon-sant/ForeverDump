"""Player identity: who is the combat log owner (v2.2.21: nothing is scrubbed; scrub_names is kept for callers).

Sources, in order:
  1. the SV: ForeverDumpDB.meta.identity (ForeverDump >= 2.2.1 writes UnitName/UnitFullName/GetUnitName(player,true)/
     realm/UnitGUID/class/level on every capture, each classified; secret values are flagged, never stored), plus older
     fallbacks (combat recorder session playerGUID, inference player GUID);
  2. tools/fdump/characters.json (optional; for logs without a matching SV);
  3. the log itself: the most frequent source with unit flags 0x511 (mine | friendly | player-controlled | player).
Forever characters have first AND last names ('Uglaz Doomaxe'); the combat log writes only 'Uglaz-ClassicBetaPvE-'."""
import collections
import json
import os
import re

from .dump import as_list

GUID_RX = re.compile(r"^Player-\d+-[0-9A-Fa-f]+$")
CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "characters.json")


def _norm(s):
    return re.sub(r"[\s'\-]", "", s or "").lower()


def parse_name(spec):
    """'First Last' | 'First' | 'Name-Realm[-Region]' | 'First Last-Realm' | GUID -> dict"""
    spec = (spec or "").strip()
    if GUID_RX.match(spec):
        return {"guid": spec}
    head, _, rest = spec.partition("-")
    realm = rest.split("-")[0] if rest else None
    toks = head.split()
    return {"first": toks[0] if toks else head, "last": " ".join(toks[1:]) or None, "realm": realm or None, "raw": spec}


def load_config(path=None):
    path = path or os.environ.get("FDUMP_CHARACTERS") or CONFIG
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    out = []
    for c in data.get("characters") or []:
        disp = c.get("display") or c.get("combatLogName") or ""
        p = parse_name(disp)
        first = c.get("combatLogName") or p.get("first")
        last = p.get("last")
        if not last and p.get("realm") and not c.get("realm"):
            last = p["realm"]           # 'Pally-Palzy': first-last or name-realm; scrub both parts either way
        out.append({"source": "characters.json", "display": disp, "first": first, "last": last,
                    "realm": c.get("realm") or None, "guid": c.get("guid") or None, "role": c.get("role")})
    return out


def identity_from_dump(dump):
    """the SV's own player identity (None if the SV has none)"""
    if dump is None:
        return None
    meta = dump.meta() if callable(getattr(dump, "meta", None)) else {}
    idn = (meta or {}).get("identity") or (dump.log.get("identity") if hasattr(dump, "log") else None)
    if isinstance(idn, dict) and (idn.get("guid") or idn.get("name")):
        name = idn.get("name") or ""
        toks = name.split()
        realm = idn.get("realm") or idn.get("normalizedRealm")
        last = idn.get("lastName") or (" ".join(toks[1:]) or None)
        # Forever (run 3): UnitName/UnitFullName("player") return (first, LAST name), not (name, realm); 2.2.1 SVs stored the
        # second return as nameRealm and left lastName empty
        for second in (idn.get("nameRealm"), idn.get("fullNameRealm")):
            if not last and isinstance(second, str) and second and second not in (idn.get("realm"), idn.get("normalizedRealm")):
                last = second
        uwr = idn.get("unitNameWithRealm")
        first = idn.get("firstName") or (toks[0] if toks else None)
        if not last and isinstance(uwr, str) and first and uwr.startswith(first + " "):
            last = uwr[len(first) + 1:]
        display = idn.get("displayName") or (("%s %s" % (first, last)) if first and last else (name or None))
        return {"source": "sv-meta", "display": display, "first": first,
                "last": last, "realm": realm,
                "guid": idn.get("guid"), "class": idn.get("classFile"), "level": idn.get("level"),
                "anySecret": idn.get("anySecret"), "secret": sorted((idn.get("secret") or {}).keys())}
    guid = None   # pre-2.2.1 SVs: GUID only
    for sess in as_list(dump.combatlog.get("sessions")) if hasattr(dump, "combatlog") else []:
        guid = guid or sess.get("playerGUID") or (sess.get("meta") or {}).get("playerGUID")
    inf = dump.log.get("inference") if hasattr(dump, "log") else None
    guid = guid or ((inf or {}).get("player") or {}).get("guid")
    return {"source": "sv-sessions", "guid": guid} if guid else None


def log_players(fx):
    """{guid: {"names": Counter(name-in-log), "owner": count of 0x511 source lines}} from parsed file-log events"""
    out = {}
    for e in (fx or {}).get("events", []):
        a = e.get("a") or []
        if not e.get("cleu") or len(a) < 9:
            continue
        for gi, ni, fi in ((3, 4, 5), (7, 8, 9)):
            g = a[gi]
            if isinstance(g, str) and g.startswith("Player-"):
                r = out.setdefault(g, {"names": collections.Counter(), "owner": 0})
                if isinstance(a[ni], str) and a[ni] not in ("<nil>", "nil"):
                    r["names"][a[ni]] += 1
                if gi == 3:
                    try:
                        fl = int(str(a[fi]), 16) if str(a[fi]).lower().startswith("0x") else int(a[fi])
                    except (TypeError, ValueError):
                        fl = 0
                    if fl == 0x511:
                        r["owner"] += 1
    return out


def _log_name_parts(n):
    head, _, rest = n.partition("-")
    return head, rest.split("-")[0] if rest else ""


def find_in_log(players, first=None, realm=None, guid=None):
    """-> (guid, name-in-log) of the best matching log player, or (None, None)"""
    if guid:
        r = players.get(guid)
        return (guid, r["names"].most_common(1)[0][0] if r and r["names"] else None) if r else (None, None)
    if not first:
        return None, None
    best = []
    for g, r in players.items():
        for n, cnt in r["names"].items():
            h, rl = _log_name_parts(n)
            if _norm(h) == _norm(first) and (not realm or _norm(rl) == _norm(realm)):
                best.append((r["owner"], cnt, g, n))
    if not best and realm:
        return find_in_log(players, first, None)
    if not best:
        return None, None
    best.sort(reverse=True)
    return best[0][2], best[0][3]


def known(dump=None, config=True):
    ids = []
    sv = identity_from_dump(dump)
    if sv:
        ids.append(sv)
    if config:
        ids += load_config()
    return ids


def _match_known(p, ids):
    for c in ids:
        if p.get("guid") and c.get("guid") == p["guid"]:
            return c
    for c in ids:
        if not p.get("first"):
            break
        cand = {_norm(c.get("first")), _norm(c.get("display"))}
        if _norm(p["first"]) in cand or _norm(p.get("raw")) in cand or \
                (p.get("last") and _norm(p["first"] + p["last"]) == _norm(c.get("display"))):
            return c
    return None


def resolve(spec=None, fx=None, dump=None, config=True):
    """-> (guid, info). spec: GUID | 'First Last' | 'First' | 'Name-Realm'. No spec: SV identity GUID, then SV name,
    then configured characters, then the 0x511 auto-detect."""
    players = log_players(fx) if fx else {}
    ids = known(dump, config)
    info = {"spec": spec, "logPlayers": len(players)}
    if spec:
        p = parse_name(spec)
        if p.get("guid"):
            info.update(method="guid-given")
            return p["guid"], info
        k = _match_known(p, ids)
        if k and k.get("guid") and (not players or k["guid"] in players):
            info.update(method="known:" + k["source"], character=k.get("display"))
            return k["guid"], info
        g, n = find_in_log(players, p["first"], p.get("realm"))
        if g:
            info.update(method="name-in-log", logName=n)
            return g, info
        if k and k.get("guid"):
            info.update(method="known:" + k["source"] + " (not in log)", character=k.get("display"))
            return k["guid"], info
        info["note"] = ("%r is a known character (%s) but not in this log; auto-selecting" % (spec, k.get("display")) if k
                        else "%r not found in the log or the known characters; auto-selecting" % spec)
    # automatic
    for k in ids:
        if k.get("guid") and (not players or k["guid"] in players):
            info.update(method="auto:%s guid" % k["source"], character=k.get("display"))
            return k["guid"], info
    for k in ids:
        if k.get("first") and players:
            g, n = find_in_log(players, k["first"], k.get("realm"))
            if g:
                info.update(method="auto:%s name" % k["source"], character=k.get("display"), logName=n)
                return g, info
    owners = sorted(((r["owner"], g) for g, r in players.items() if r["owner"]), reverse=True)
    if owners:
        g = owners[0][1]
        info.update(method="auto:log-owner 0x511", logName=players[g]["names"].most_common(1)[0][0] if players[g]["names"] else None)
        return g, info
    sv = identity_from_dump(dump)
    if sv and sv.get("guid"):
        info.update(method="sv (no log)")
        return sv["guid"], info
    info.setdefault("note", "no player found")
    return None, info


def describe(guid, info):
    return "player %s via %s%s%s" % (guid, info.get("method"), (" (%s)" % info["character"]) if info.get("character") else "",
                                     ("; " + info["note"]) if info.get("note") else "")


def scrub_names(dump=None, config=True):
    """name tokens + GUIDs the anonymizer must remove (first and last names of every known character)"""
    names, guids = set(), set()
    for k in known(dump, config):
        for x in (k.get("first"), k.get("last"), k.get("display")):
            if x:
                names.add(x)
                names.update(t for t in re.split(r"[\s\-]+", x) if len(t) >= 2)
        if k.get("guid"):
            guids.add(k["guid"])
    return sorted(names, key=lambda s: (-len(s), s)), sorted(guids)
