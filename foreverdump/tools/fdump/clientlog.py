"""Parse Logs/Client.log (Forever 70245): '<M/D HH:MM:SS.mmm>  [L][Category] message' plus indented/continuation lines
(Lua error stacks). Summarises Lua errors by call site, LUA warnings, addon/SavedVariables lines, LimitedLuaResources,
screen switches; optionally splits errors by FD_Logs capture windows from a dump."""
import collections
import datetime
import re

LINE = re.compile(r"^(?P<md>\d{1,2}/\d{1,2}) (?P<hms>\d{1,2}:\d{2}:\d{2}(?:\.\d+)?)\s+\[(?P<lvl>\w)\]\[(?P<cat>[^\]]+)\] (?P<msg>.*)$")
ADDON = re.compile(r"[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\]([^\]:]+)\]?:(\d+)")


def anchor_offset(dump):
    """client zone (seconds east of UTC) from the first session anchor of a dump (Core.TimeAnchor utcOffset), or None"""
    if dump is None:
        return None
    for db in (dump.record, dump.combatlog):
        for s in as_list_safe(db.get("sessions")):
            a = s.get("anchor") if isinstance(s.get("anchor"), dict) else {}
            off = a.get("utcOffset") if a.get("utcOffset") is not None else s.get("utcOffsetSec")
            if isinstance(off, (int, float)):
                return off
    return None


def anchor_year(dump):
    """year of the first recorder/CL anchor date ("YYYY-MM-DD..."), so an old Client.log is not stamped with today's year"""
    import re
    raw = getattr(dump, "raw", dump) or {}
    for key in ("ForeverDumpRecordDB", "ForeverDumpCombatLogDB"):
        sess = (raw.get(key) or {}).get("sessions")
        sess = list(sess.values()) if isinstance(sess, dict) else (sess or [])
        for s in sess:
            a = (s.get("anchor") if isinstance(s, dict) else None) or {}
            m = re.match(r"(\d{4})-", str(a.get("date") or ""))
            if m:
                return int(m.group(1))
    return None


def dst_step(prev, cur):
    """v2.2.26: Client.log has no zone, so a DST change inside one log is inferred from the wall clock itself:
    fall back = the clock goes BACK ~1 h into the 01:xx hour (offset -3600 from then on); spring forward = the clock
    jumps from 01:xx to 03:xx within 30 min of real time (offset +3600). Returns the offset change in seconds."""
    d = (cur - prev).total_seconds()
    if cur.hour == 1 and prev.hour == 1 and -3600 - 300 <= d <= -3600 + 600 and cur.date() == prev.date():
        return -3600
    if prev.hour == 1 and cur.hour == 3 and cur.date() == prev.date() and 3600 < d <= 3600 + 1800:
        return 3600
    return 0


def _epoch(ts, utc_offset_sec):
    """Client.log stamps are the client's local wall clock without a zone. Time audit 2026-10-10: ts.timestamp() read
    them in the BOX zone; with the client offset (dump anchor) the epoch no longer depends on where the tools run."""
    if utc_offset_sec is None:
        return ts.timestamp()
    import calendar
    return calendar.timegm(ts.timetuple()) + ts.microsecond / 1e6 - utc_offset_sec


def _clock(epoch, utc_offset_sec):
    if utc_offset_sec is None:
        return datetime.datetime.fromtimestamp(epoch).strftime("%H:%M:%S")
    return datetime.datetime.fromtimestamp(epoch, datetime.timezone(datetime.timedelta(seconds=utc_offset_sec))).strftime("%H:%M:%S")


def parse(path, year=None, utc_offset_sec=None):
    year = year or datetime.date.today().year
    entries, cur, prev_mo, prev_ts = [], None, None, None
    with open(path, encoding="utf-8", errors="replace") as f:
        for n, raw in enumerate(f, 1):
            line = raw.rstrip("\r\n")
            m = LINE.match(line)
            if m:
                mo, d = m.group("md").split("/")
                # time audit: Client.log stamps have no year; a session crossing New Year (12/31 -> 1/1) moves on a year
                if prev_mo is not None and int(mo) < prev_mo:
                    year += 1
                prev_mo = int(mo)
                hms = m.group("hms")
                try:
                    ts = datetime.datetime.strptime("%d-%s-%s %s" % (year, mo, d, hms), "%Y-%m-%d %H:%M:%S.%f")
                except ValueError:
                    ts = datetime.datetime.strptime("%d-%s-%s %s" % (year, mo, d, hms), "%Y-%m-%d %H:%M:%S")
                if utc_offset_sec is not None and prev_ts is not None:
                    utc_offset_sec += dst_step(prev_ts, ts)
                prev_ts = ts
                cur = {"line": n, "time": ts.isoformat(timespec="milliseconds"), "epoch": _epoch(ts, utc_offset_sec), "level": m.group("lvl"),
                       "cat": m.group("cat"), "msg": m.group("msg"), "stack": []}
                entries.append(cur)
            elif line.strip() and cur is not None:
                cur["stack"].append(line.strip())
    return entries


def classify(e):
    msg = e["msg"]
    if e["cat"] == "Lua" and e["level"] == "E":
        if msg.startswith("Lua Error: "):
            return "lua_error"
        return "lua_warning"
    if "LimitedLuaResources" in msg:
        return "limited_lua_resources"
    if "SavedVariables" in msg or "SavedVars" in msg:
        return "saved_variables"
    if "Switching to screen" in msg or "Screen invalid" in msg:
        return "screen"
    if "AddOn" in msg or "Interface/AddOns" in msg or "Interface\\AddOns" in msg:
        return "addon"
    if "failed validation" in msg:
        return "cvar_validation"
    return "other"


def site(e):
    """(top frame, first Lua frame) for a Lua error"""
    top = e["stack"][0] if e["stack"] else ""
    lua = ""
    for fr in e["stack"]:
        a = ADDON.search(fr)
        if a:
            lua = "%s/%s:%s" % a.groups()
            break
    return top, lua


def summarize(entries, windows=None):
    kinds = collections.Counter(classify(e) for e in entries)
    levels = collections.Counter("%s/%s" % (e["level"], e["cat"]) for e in entries)
    groups = collections.OrderedDict()
    for e in entries:
        if classify(e) != "lua_error":
            continue
        top, lua = site(e)
        msg = e["msg"][len("Lua Error: "):]
        k = (msg[:200], top, lua)
        g = groups.setdefault(k, {"message": msg[:300], "top": top, "site": lua, "count": 0, "first": e["time"], "last": e["time"],
                                  "inCapture": 0, "outsideCapture": 0})
        g["count"] += 1
        g["last"] = e["time"]
        if windows:
            inside = any(a <= e["epoch"] <= b for a, b in windows)
            g["inCapture" if inside else "outsideCapture"] += 1
        tf = re.match(r"\[C\]: in function [`'](\w+)'", top)
        g["cTrampoline"] = bool(tf and "attempt to call a nil value" in msg)
        g["addon"] = lua.split("/")[0] if lua else None
    warnings = [{"time": e["time"], "msg": e["msg"]} for e in entries if classify(e) == "lua_warning"]
    addon_lines = [{"time": e["time"], "msg": e["msg"][:200]} for e in entries if classify(e) in ("addon", "saved_variables")]
    screens = [{"time": e["time"], "msg": e["msg"][:120]} for e in entries if classify(e) == "screen"]
    llr = sorted({e["msg"].split("LimitedLuaResources: ", 1)[-1] for e in entries if classify(e) == "limited_lua_resources"})
    tramp = collections.Counter()
    for g in groups.values():
        if g.get("cTrampoline"):
            tramp[re.sub(r".*function [`'](\w+)'.*", r"\1", g["top"])] += g["count"]
    first = entries[0]["time"] if entries else None
    last = entries[-1]["time"] if entries else None
    return {"lines": len(entries), "first": first, "last": last, "kinds": dict(kinds), "levels": dict(levels),
            "luaErrors": sum(g["count"] for g in groups.values()), "errorGroups": list(groups.values()),
            "cTrampolineNilCalls": dict(tramp), "luaWarnings": warnings, "addonLines": addon_lines[:200], "screens": screens,
            "limitedLuaResources": llr, "captureWindows": windows or []}


def capture_windows(dump):
    """[(startEpoch, endEpoch)] from recorder/CL sessions (sid cap-*) of a dump"""
    out = []
    if dump is None:
        return out
    for db in (dump.record, dump.combatlog):
        for s in as_list_safe(db.get("sessions")):
            a, b = s.get("startEpoch") or (s.get("anchor") or {}).get("epoch"), s.get("stopEpoch") or (s.get("anchorEnd") or {}).get("epoch")
            if a and b:
                out.append((float(a), float(b) + 1))
    return sorted(set(out))


def as_list_safe(v):
    if isinstance(v, list):
        return v
    if isinstance(v, dict):
        return [v[k] for k in sorted(v, key=lambda x: int(x) if str(x).isdigit() else 0)]
    return []


def markdown(s):
    L = ["# Client.log summary", "", "%d entries, %s .. %s" % (s["lines"], s["first"], s["last"]), "",
         "Kinds: " + ", ".join("%s %d" % kv for kv in sorted(s["kinds"].items(), key=lambda x: -x[1])), "",
         "## Lua errors (%d) by call site" % s["luaErrors"], "",
         "| count | first | last | message | top frame | first Lua frame | in capture | outside |", "|---|---|---|---|---|---|---|---|"]
    for g in sorted(s["errorGroups"], key=lambda g: -g["count"]):
        L.append("| %d | %s | %s | %s | `%s` | `%s` | %s | %s |" % (g["count"], g["first"][11:19], g["last"][11:19],
                 g["message"][:90].replace("|", "/"), g["top"], g["site"], g["inCapture"] if s["captureWindows"] else "-",
                 g["outsideCapture"] if s["captureWindows"] else "-"))
    if s["cTrampolineNilCalls"]:
        L += ["", "'attempt to call a nil value' raised directly by a C function frame (hooksecurefunc trampoline class): "
              + ", ".join("%s x%d" % kv for kv in sorted(s["cTrampolineNilCalls"].items(), key=lambda x: -x[1]))]
    if s["luaWarnings"]:
        L += ["", "## LUA warnings", ""] + ["- %s %s" % (w["time"][11:19], w["msg"]) for w in s["luaWarnings"]]
    if s["screens"]:
        L += ["", "## Screen switches (login / reload)", ""] + ["- %s %s" % (w["time"][11:19], w["msg"]) for w in s["screens"][:40]]
    if s["limitedLuaResources"]:
        L += ["", "## LimitedLuaResources", ""] + ["- " + x for x in s["limitedLuaResources"]]
    if s["captureWindows"]:
        L += ["", "Capture windows (from the dump): " + ", ".join(
            "%s-%s" % (_clock(a, s.get("utcOffsetSec")), _clock(b, s.get("utcOffsetSec")))
            for a, b in s["captureWindows"])]
    return "\n".join(L) + "\n"
