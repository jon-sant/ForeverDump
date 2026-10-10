"""Parse Logs/WoWCombatLog*.txt (advanced or basic) into CLEU replay fixtures, and cross-check against an
addon-side capture (/fdump cl). Best-effort: the text log is not identical to the CLEU payload:
  * the file has no hideCaster field (we insert false),
  * with advanced logging an extra unit-info block (17 fields <= v21, 19 fields in v22) follows the prefix,
  * v22 damage/heal suffixes carry an extra raw/base amount as their 2nd field (kept in `rawAmount`),
  * verified on a real Forever 1.60.1.70245 log (v22, PROJECT_ID 18): ENVIRONMENTAL_* lines put the advanced block
    before environmentalType; damage suffixes have no isOffHand (padded with nil, `padded`), SPELL_DAMAGE ends with
    an ST/AOE marker (moved to `scope`).
`shape="cleu"` (default) converts to the CLEU argument layout; the untouched fields stay in `raw` and the
advanced block in `adv`, so nothing is lost. Use `compare()` against a /fdump cl session to verify on your build.
"""
import calendar
import datetime
import re

LINE = re.compile(r"^(\d{1,2})/(\d{1,2})(?:/(\d{4}))?\s+(\d{1,2}):(\d{2}):(\d{2})(?:\.(\d+))?([+-]\d{1,2}(?::?\d{2})?)?\s+(.*)$")
GUIDISH = re.compile(r"^(0000000000000000|[A-Za-z]+-[0-9A-Za-z-]+)$")

# Lines that are not CLEU (no source/dest header). ENCOUNTER_* become context events like the addon records.
CONTEXT = {"ENCOUNTER_START", "ENCOUNTER_END", "CHALLENGE_MODE_START", "CHALLENGE_MODE_END"}
NON_CLEU = CONTEXT | {"COMBAT_LOG_VERSION", "ZONE_CHANGE", "MAP_CHANGE", "COMBATANT_INFO", "EMOTE", "WORLD_MARKER_PLACED",
                      "WORLD_MARKER_REMOVED", "ARENA_MATCH_START", "ARENA_MATCH_END", "PLAYER_INFO"}
# Special subevents without a standard prefix/suffix.
SPECIAL = {"UNIT_DIED", "UNIT_DESTROYED", "UNIT_DISSIPATES", "PARTY_KILL", "ENCHANT_APPLIED", "ENCHANT_REMOVED",
           "SPELL_ABSORBED", "SPELL_HEAL_ABSORBED", "SPELL_EMPOWER_START", "SPELL_EMPOWER_END", "SPELL_EMPOWER_INTERRUPT"}


def tokenize(s):
    """Split a combat log line body on commas, honouring "quotes", [brackets] and (parens). Returns values."""
    pos, n = 0, len(s)

    def parse_value():
        nonlocal pos
        if pos < n and s[pos] == '"':
            pos += 1
            buf = []
            while pos < n and s[pos] != '"':
                if s[pos] == "\\" and pos + 1 < n:
                    pos += 1
                buf.append(s[pos])
                pos += 1
            pos += 1
            return "".join(buf), True
        if pos < n and s[pos] in "[(":
            close = "]" if s[pos] == "[" else ")"
            pos += 1
            items = []
            while pos < n and s[pos] != close:
                v, _ = parse_value()
                items.append(v)
                if pos < n and s[pos] == ",":
                    pos += 1
            pos += 1
            return items, False
        start = pos
        while pos < n and s[pos] not in ",)]":
            pos += 1
        return convert(s[start:pos].strip()), False

    out = []
    while pos < n:
        v, _ = parse_value()
        out.append(v)
        if pos < n and s[pos] == ",":
            pos += 1
            if pos == n:
                out.append(None)
        elif pos < n:
            pos += 1  # stray char
    return out


def convert(tok):
    if tok == "nil" or tok == "":
        return None
    if re.match(r"^[0-9A-F]{16}$", tok):  # empty GUID 0000000000000000 stays a string
        return tok
    if re.match(r"^-?0x[0-9a-fA-F]+$", tok):
        return int(tok, 16)
    if re.match(r"^-?\d+$", tok):
        return int(tok)
    if re.match(r"^-?\d*\.\d+(e[-+]?\d+)?$", tok, re.I):
        return float(tok)
    return tok


def prefix_len(sub):
    if sub.startswith("SWING_"):
        return 0
    if sub.startswith("ENVIRONMENTAL_"):
        return 1
    if sub.startswith(("SPELL_", "RANGE_", "DAMAGE_SPLIT", "DAMAGE_SHIELD")):
        return 3
    return 0


def to_epoch(m, year_default, utc_offset_sec):
    mo, d, y, hh, mi, ss, frac, tz = m.group(1, 2, 3, 4, 5, 6, 7, 8)
    year = int(y) if y else year_default
    micro = int((frac or "0").ljust(6, "0")[:6])
    dt = datetime.datetime(year, int(mo), int(d), int(hh), int(mi), int(ss), micro)
    if tz:
        sign = -1 if tz.startswith("-") else 1
        digits = tz[1:].replace(":", "")
        hours = int(digits[:-2]) if len(digits) > 2 else int(digits)
        mins = int(digits[-2:]) if len(digits) > 2 else 0
        offset = sign * (hours * 3600 + mins * 60)
    else:
        offset = utc_offset_sec
    return calendar.timegm(dt.timetuple()) + micro / 1e6 - (offset or 0)


def parse_file(path, year=None, utc_offset_sec=None, shape="cleu", limit=None, subevents=None):
    if year is None:
        year = datetime.date.today().year
    if utc_offset_sec is None:
        utc_offset_sec = datetime.datetime.now().astimezone().utcoffset().total_seconds()
    header = {}
    events, counts, unparsed = [], {}, 0
    adv_size = 19
    with open(path, encoding="utf-8", errors="replace") as f:
        for lineno, line in enumerate(f, 1):
            line = line.rstrip("\r\n")
            if not line:
                continue
            m = LINE.match(line)
            if not m:
                unparsed += 1
                continue
            body = m.group(9)
            fields = tokenize(body)
            if not fields:
                continue
            sub = fields[0]
            t = to_epoch(m, year, utc_offset_sec)
            if sub == "COMBAT_LOG_VERSION":
                kv = dict(zip(fields[2::2], fields[3::2]))
                header = {"version": fields[1], "advanced": kv.get("ADVANCED_LOG_ENABLED") == 1,
                          "build": kv.get("BUILD_VERSION"), "projectID": kv.get("PROJECT_ID"), "line": lineno}
                adv_size = 19 if (isinstance(fields[1], int) and fields[1] >= 22) else 17
                events.append({"t": t, "e": "COMBAT_LOG_VERSION", "fileOnly": True, "a": fields[1:], "n": len(fields) - 1})
                continue
            if sub in NON_CLEU or len(fields) < 9:
                entry = {"t": t, "e": sub, "a": fields[1:], "n": len(fields) - 1}
                if sub in CONTEXT:
                    entry["ctx"] = True
                else:
                    entry["fileOnly"] = True
                events.append(entry)
                continue
            if subevents and sub not in subevents:
                continue
            counts[sub] = counts.get(sub, 0) + 1
            head = fields[1:9]   # sGUID, sName, sFlags, sRaid, dGUID, dName, dFlags, dRaid
            rest = fields[9:]
            entry = {"t": t, "e": "COMBAT_LOG_EVENT_UNFILTERED", "cleu": True, "sub": sub, "line": lineno}
            if shape == "raw":
                args = [t, sub, False] + head + rest
            else:
                pl = 0 if sub in SPECIAL and not sub.startswith("SPELL_") else prefix_len(sub)
                # real 70245 logs: ENVIRONMENTAL_* put the advanced block BEFORE environmentalType
                # (ENVIRONMENTAL_DAMAGE,<8 base>,<19 advanced>,Falling,amount,raw,...), spell prefixes come before it
                env = sub.startswith("ENVIRONMENTAL_")
                if env:
                    pl = 0
                prefix, after = rest[:pl], rest[pl:]
                adv = None
                if len(after) >= adv_size and isinstance(after[0], str) and GUIDISH.match(after[0]) \
                        and isinstance(after[1], str) and GUIDISH.match(after[1]):
                    adv, after = after[:adv_size], after[adv_size:]
                if adv is not None and (sub.endswith("_DAMAGE") or sub.endswith("_DAMAGE_LANDED")
                                        or sub.endswith("_HEAL")) and len(after) >= 2 \
                        and isinstance(header.get("version"), int) and header["version"] >= 22:
                    ai = 1 if env else 0          # amount index inside `after`; v22 adds the unmitigated amount after it
                    entry["rawAmount"] = after[ai + 1]
                    after = after[:ai + 1] + after[ai + 2:]
                if after and after[-1] in ("ST", "AOE") and sub.endswith(("_DAMAGE", "_DAMAGE_LANDED", "_HEAL", "_MISSED", "_ABSORBED")):
                    entry["scope"] = after[-1]    # v22 trailing single-target/AoE marker (not part of the CLEU payload)
                    after = after[:-1]
                if sub.endswith(("_DAMAGE", "_DAMAGE_LANDED")) and adv is not None:
                    base = (1 if env else 0)
                    if len(after) - base == 9:    # CLEU damage suffix has 10 fields; the file omits isOffHand
                        after = after + [None]
                        entry["padded"] = "isOffHand"
                if adv is not None:
                    entry["adv"] = adv
                entry["raw"] = rest
                args = [t, sub, False] + head + prefix + after
            entry["a"] = ["<nil>" if v is None else v for v in args]
            entry["n"] = len(args)
            events.append(entry)
            if limit and len(events) >= limit:
                break
    return {"kind": "combatlog", "source": "file", "file": str(path), "header": header, "events": events,
            "counts": counts, "total": sum(counts.values()), "unparsedLines": unparsed, "shape": shape,
            "utcOffsetSec": utc_offset_sec}


def compare(file_fx, addon_session, tolerance=0.002):
    """Match CLEU entries by (timestamp, subevent); report arity/field differences (legacy cleu-force captures)."""
    def key(e):
        a = e.get("a") or []
        ts = a[0] if a and isinstance(a[0], (int, float)) else None
        # GUIDs are not part of the key so redacted captures (cl.redactPlayers) still match
        return (round(ts, 2) if ts is not None else None, e.get("sub"))

    fe = [e for e in file_fx.get("events", []) if e.get("cleu")]
    ae = [e for e in addon_session.get("events", []) if e.get("cleu")]
    index = {}
    for e in fe:
        index.setdefault(key(e), []).append(e)
    matched, only_addon, arity, field_diffs = 0, [], {}, []
    used = set()
    for e in ae:
        cands = index.get(key(e)) or []
        hit = next((c for c in cands if id(c) not in used), None)
        if not hit:
            only_addon.append({"t": e["a"][0] if e.get("a") else None, "sub": e.get("sub")})
            continue
        used.add(id(hit))
        matched += 1
        na, nf = e.get("n", 0), hit.get("n", 0)
        if na != nf:
            arity.setdefault(e.get("sub"), {}).setdefault("%d(addon) vs %d(file)" % (na, nf), 0)
            arity[e.get("sub")]["%d(addon) vs %d(file)" % (na, nf)] += 1
        for i, (x, y) in enumerate(zip(e.get("a", []), hit.get("a", []))):
            if i == 0 or x in ("<secret>", "<secrettable>") or y in ("<secret>",):
                continue
            if x != y and not (isinstance(x, (int, float)) and isinstance(y, (int, float)) and abs(x - y) <= tolerance):
                if len(field_diffs) < 200:
                    field_diffs.append({"sub": e.get("sub"), "pos": i + 1, "addon": x, "file": y})
    only_file = [{"t": e["a"][0], "sub": e.get("sub")} for e in fe if id(e) not in used]
    return {"matched": matched, "addonOnly": len(only_addon), "fileOnly": len(only_file),
            "arityMismatch": arity, "fieldDiffs": field_diffs,
            "addonOnlySample": only_addon[:50], "fileOnlySample": only_file[:50]}


DAMAGE_SUFFIX = ("_DAMAGE", "_HEAL")


def file_amount(e):
    """amount of a file-log damage/heal entry in cleu shape (after prefix + spell/env block)."""
    a, sub = e["a"], e.get("sub", "")
    if sub.startswith("SWING_"):
        base = 11
    elif sub.startswith("ENVIRONMENTAL_"):
        base = 12
    else:
        base = 14
    v = a[base] if len(a) > base else None
    return v if isinstance(v, (int, float)) else None


def compare_forever(file_fx, addon_session, player_guid, window=2.0):
    """Match addon UNIT_COMBAT("player", ...) entries to file-log damage/heal lines whose dest is the player, by
    wall-clock time (addon t is GetTime(); mapped with session startEpoch/startTime, ~1 s precision) and amount."""
    st, se = addon_session.get("startTime"), addon_session.get("startEpoch")
    if st is None or se is None:
        return {"error": "session has no startTime/startEpoch"}
    fe = [e for e in file_fx.get("events", []) if e.get("cleu") and len(e["a"]) > 7 and e["a"][7] == player_guid
          and e.get("sub", "").endswith(DAMAGE_SUFFIX)]
    ae = [e for e in addon_session.get("events", []) if e.get("e") == "UNIT_COMBAT" and (e.get("a") or [None])[0] == "player"]
    used, matched, secret, unmatched = set(), 0, 0, []
    for e in ae:
        a = e["a"]
        amount = a[3] if len(a) > 3 else None
        when = se + (e["t"] - st)
        if amount == "<secret>":
            secret += 1
        cands = [f for f in fe if id(f) not in used and abs(f["a"][0] - when) <= window
                 and (amount == "<secret>" or file_amount(f) == amount)]
        if cands:
            best = min(cands, key=lambda f: abs(f["a"][0] - when))
            used.add(id(best))
            matched += 1
        else:
            unmatched.append({"t": when, "action": a[1] if len(a) > 1 else None, "amount": amount})
    return {"mode": "forever", "addonUnitCombat": len(ae), "fileDamageHealOnPlayer": len(fe), "matched": matched,
            "secretAmounts": secret, "addonOnly": len(unmatched), "fileOnly": len(fe) - len(used),
            "addonOnlySample": unmatched[:50]}


def synthesize_forever(fx, player_guid, unit="player"):
    """Add synthetic Forever-available events derived from CLEU lines that involve `player_guid`, so a file
    fixture can also drive handlers written for Forever (no CLEU). Mapping (best-effort, marked synthetic):
      SPELL_CAST_START/SUCCESS/FAILED by player -> UNIT_SPELLCAST_START/SUCCEEDED/FAILED(unit, castGUID, spellID)
      *_DAMAGE / *_HEAL on player -> UNIT_COMBAT(unit, "WOUND"|"HEAL", flagText, amount, schoolMask)
      SWING_DAMAGE/SWING_MISSED by player -> PLAYER_SWING(duration?, 0)  (duration unknown -> 0)
    The original CLEU entries stay; replay with { cleu = false } to feed only the Forever-style events."""
    out = []
    n = 0
    for e in fx["events"]:
        out.append(e)
        if not e.get("cleu"):
            continue
        a = e["a"]
        sub, src, dst = a[1], a[3], a[7]
        syn = None
        if src == player_guid and sub in ("SPELL_CAST_START", "SPELL_CAST_SUCCESS", "SPELL_CAST_FAILED"):
            ev = {"SPELL_CAST_START": "UNIT_SPELLCAST_START", "SPELL_CAST_SUCCESS": "UNIT_SPELLCAST_SUCCEEDED",
                  "SPELL_CAST_FAILED": "UNIT_SPELLCAST_FAILED"}[sub]
            n += 1
            syn = {"e": ev, "a": [unit, "Cast-synthetic-%d" % n, a[11]], "n": 3}
        elif dst == player_guid and (sub.endswith("_DAMAGE") or sub.endswith("_HEAL")):
            pl = prefix_len(sub)
            amount = a[11 + pl] if len(a) > 11 + pl else 0
            crit_idx = 11 + pl + (6 if sub.endswith("_DAMAGE") else 3)
            crit = len(a) > crit_idx and a[crit_idx] not in (None, "<nil>", False, 0)
            school = a[13] if pl == 3 else (a[11 + pl + 2] if len(a) > 11 + pl + 2 else 1)
            syn = {"e": "UNIT_COMBAT", "a": [unit, "HEAL" if sub.endswith("_HEAL") else "WOUND",
                                             "CRITICAL" if crit else "", amount, school], "n": 5}
        elif dst == player_guid and sub.endswith("_MISSED"):
            pl = prefix_len(sub)
            miss = a[11 + pl] if len(a) > 11 + pl else "MISS"
            syn = {"e": "UNIT_COMBAT", "a": [unit, miss, "", 0, a[13] if pl == 3 else 1], "n": 5}
        elif src == player_guid and sub in ("SWING_DAMAGE", "SWING_MISSED"):
            syn = {"e": "PLAYER_SWING", "a": [0, 0], "n": 2}
        if syn:
            syn.update({"t": e["t"], "synthetic": True, "fromLine": e.get("line")})
            out.append(syn)
    fx = dict(fx, events=out, synthesizedFor=player_guid,
              syntheticCount=sum(1 for e in out if e.get("synthetic")))
    return fx
