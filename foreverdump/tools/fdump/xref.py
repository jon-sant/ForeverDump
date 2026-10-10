"""xref: one ordered timeline from the addon's captures and the client's WoWCombatLog file.

Sources (tag `source`):
  addon-event        event recorder entries (/fdump record, FD_Logs)        secret = payload positions that were secret
  addon-cl           combat recorder entries (/fdump cl, FD_Logs)
  addon-error / addon-blocked / addon-contradiction / addon-probe / addon-anchor
  file-cl            parsed WoWCombatLog*.txt lines (unrestricted: never secret)
Time: addon records carry GetTime() (`t`) + session anchors {gameTime, epoch, server, utcOffset, epochTick, gameTimeTick};
  epoch(t) = epochTick + (t - gameTimeTick) when the anchor was refined at a time() tick (precise to ~1 frame), else
  epoch + (t - gameTime) (+-1 s). The file log is local wall time with a UTC offset -> epoch. Both use the client
  machine clock, so they line up without server-time skew (GetServerTime is kept for reference).
Matching (addon -> file): UNIT_COMBAT(player) -> *_DAMAGE/_HEAL/_MISSED/ENVIRONMENTAL_* with dest = player;
  UNIT_COMBAT(other unit) -> damage/heal by anyone on a non-player dest; UNIT_SPELLCAST_SUCCEEDED/START(player) ->
  SPELL_CAST_SUCCESS/START by the player with the same spellID. Quality: exact (<=100 ms, amount equal),
  time+amount (within window, amount equal), time-only:secret-amount, time-only:amount-differs, unmatched."""
import collections
import datetime
import json

from .dump import as_list
from . import combatlog

DAMAGE_HEAL = ("_DAMAGE", "_HEAL", "_MISSED", "_DAMAGE_LANDED", "_ABSORBED")


def anchor_epoch(anchor, t, fallback=None):
    if isinstance(anchor, dict) and t is not None:
        if anchor.get("epochTick") is not None and anchor.get("gameTimeTick") is not None:
            return anchor["epochTick"] + (t - anchor["gameTimeTick"]), True
        if anchor.get("epoch") is not None and anchor.get("gameTime") is not None:
            return anchor["epoch"] + (t - anchor["gameTime"]), False
    if fallback and t is not None and fallback[0] is not None and fallback[1] is not None:
        return fallback[1] + (t - fallback[0]), False
    return None, False


def _short(a, n=6):
    out = []
    for v in as_list(a)[:n]:
        s = json.dumps(v, ensure_ascii=False) if not isinstance(v, str) else v
        out.append(s[:40])
    return out


def _secret_list(e):
    s = as_list(e.get("s"))
    return [int(x) for x in s if isinstance(x, (int, float))]


_RTYPE = {0: "Combat", 1: "Encounter", 2: "ChallengeMode", 3: "PvPMatch", 4: "Map", 5: "Chat"}
_RSTATE = {0: "Inactive", 1: "Activating", 2: "Active"}


def _capture_anchor(dump, sid):
    """anchor of the recorder/CL session that belongs to capture sid (precise GetTime -> epoch)"""
    for db in (dump.combatlog, dump.record):
        for sess in as_list(db.get("sessions")):
            if isinstance(sess.get("anchor"), dict) and (sid is None or sess.get("captureSid") == sid or sess.get("sid") == sid):
                return sess["anchor"]
    return None


def _stamp_epoch(dump, rec):
    """epoch for a ns.Stamp record: GetTime through the capture anchor when possible, else epoch/server seconds"""
    if rec.get("t") is not None:
        anc = _capture_anchor(dump, rec.get("sid"))
        if anc:
            ep, _ = anchor_epoch(anc, rec["t"])
            if ep:
                return ep
    ep = rec.get("epoch") or rec.get("time")
    return float(ep) if ep else None


def _probe_short(f):
    after = f.get("probeAfter") or {}
    sec = sorted(k for k, v in after.items() if isinstance(v, str) and ("S" in v.split("=")[-1][:1] or "=S" in v))
    return ("secret after flip: " + ",".join(sec)) if sec else None


def addon_items(dump):
    items = []
    for kind, db, src in (("rec", dump.record, "addon-event"), ("cl", dump.combatlog, "addon-cl")):
        for sess in as_list(db.get("sessions")):
            anchor = sess.get("anchor")
            fb = (sess.get("startTime"), sess.get("startEpoch"))
            sid = sess.get("sid") or "%s-legacy-%s" % (kind, sess.get("startEpoch"))
            for e in as_list(sess.get("events")):
                if not isinstance(e, dict) or e.get("t") is None:
                    continue
                ep, precise = anchor_epoch(anchor, e["t"], fb)
                if ep is None:
                    continue
                items.append({"epoch": ep, "precise": precise, "source": src, "event": e.get("sub") or e.get("e"),
                              "sid": sid, "captureSid": sess.get("captureSid"), "inCombat": bool(e.get("c")),
                              "encounter": bool(e.get("enc")), "secret": _secret_list(e), "a": as_list(e.get("a")),
                              "t": e["t"]})
            if anchor:
                ep, precise = anchor_epoch(anchor, anchor.get("gameTime"))
                items.append({"epoch": ep, "precise": precise, "source": "addon-anchor", "event": "%s session start" % kind,
                              "sid": sid, "secret": [], "a": [anchor.get("date"), anchor.get("server"), anchor.get("utcOffset")]})
    log = dump.log or {}
    for e in as_list(log.get("errors")):
        ep = e.get("epoch") or e.get("time")
        if ep:
            items.append({"epoch": float(ep), "precise": False, "source": "addon-error", "event": "LUA_ERROR",
                          "sid": e.get("sid"), "secret": [], "a": [str(e.get("message", ""))[:120], e.get("addon")]})
    rlog = log.get("restrictions") or {}
    have_flips = bool(as_list(rlog.get("flips")))
    for f in as_list(rlog.get("flips")):
        ep = _stamp_epoch(dump, f)
        if ep:
            items.append({"epoch": ep, "precise": True, "source": "addon-restriction",
                          "event": "RESTRICTION %s:%s" % (f.get("typeName"), f.get("stateName")), "sid": f.get("sid"),
                          "inCombat": bool((f.get("ctx") or {}).get("combat")), "secret": [], "t": f.get("t"),
                          "a": [f.get("prev"), (f.get("ctx") or {}).get("lastMarker"), _probe_short(f)]})
    for m in as_list(rlog.get("markers")):
        ep = _stamp_epoch(dump, m)
        if ep:
            items.append({"epoch": ep, "precise": True, "source": "addon-context", "event": m.get("event"), "sid": m.get("sid"),
                          "inCombat": bool(m.get("combat")), "secret": [], "t": m.get("t"),
                          "a": [(m.get("encounter") or {}).get("name"), (m.get("instance") or {}).get("type")]})
    for e in as_list(log.get("blocked")):
        ep = e.get("epoch") or e.get("time")
        if ep and e.get("event") == "ADDON_RESTRICTION_STATE_CHANGED":
            if have_flips:
                continue
            args = e.get("args") or {}
            t, st = args.get("type"), args.get("state")
            ep2 = _stamp_epoch(dump, e) or float(ep)
            items.append({"epoch": ep2, "precise": ep2 != float(ep), "source": "addon-restriction",
                          "event": "RESTRICTION %s:%s" % (_RTYPE.get(t, t), _RSTATE.get(st, st)), "sid": e.get("sid"),
                          "inCombat": bool(e.get("inCombat")), "secret": [], "t": e.get("t"), "a": []})
            continue
        if ep:
            items.append({"epoch": float(ep), "precise": False, "source": "addon-blocked", "event": e.get("event"),
                          "sid": e.get("sid"), "secret": [], "a": _short(list((e.get("args") or {}).values()))})
    for c in as_list((dump.db.get("secretsLive") or {}).get("contradictions")):
        if c.get("epoch"):
            items.append({"epoch": float(c["epoch"]), "precise": False, "source": "addon-contradiction", "event": c.get("key"),
                          "sid": c.get("sid"), "secret": [c.get("pos")] if c.get("observed") == "secret" else [],
                          "a": [c.get("pos"), c.get("doc"), c.get("observed"), c.get("ctx"), c.get("count")]})
    for key, res in (dump.sections.get("probe") or {}).items():
        if isinstance(res, dict) and isinstance(res.get("anchor"), dict):
            ep, precise = anchor_epoch(res["anchor"], res["anchor"].get("gameTime"))
            if ep:
                items.append({"epoch": ep, "precise": precise, "source": "addon-probe", "event": "probe:" + str(key),
                              "sid": res.get("sid"), "secret": [], "a": [res.get("reason")]})
    return items


def file_items(fx):
    items = []
    for e in fx.get("events", []):
        a = e.get("a") or []
        if e.get("cleu"):
            items.append({"epoch": a[0], "precise": True, "source": "file-cl", "event": e.get("sub"), "secret": [],
                          "src": a[3] if len(a) > 3 else None, "srcName": a[4] if len(a) > 4 else None,
                          "dst": a[7] if len(a) > 7 else None, "dstName": a[8] if len(a) > 8 else None,
                          "amount": combatlog.file_amount(e), "spellID": a[11] if len(a) > 11 else None,
                          "line": e.get("line")})
        else:
            items.append({"epoch": e.get("t"), "precise": True, "source": "file-cl", "event": e.get("e"), "secret": [],
                          "a": _short(a)})
    return items


def _amount(a, idx):
    v = a[idx] if len(a) > idx else None
    return v


def match(items, player_guid, window_ms=750, exact_ms=100):
    files = [i for i in items if i["source"] == "file-cl" and i.get("dst") is not None]
    files.sort(key=lambda i: i["epoch"])
    used = set()
    stats = collections.Counter()
    import bisect
    keys = [f["epoch"] for f in files]
    for it in items:
        if it["source"] not in ("addon-event", "addon-cl"):
            continue
        ev, a = it["event"], it.get("a") or []
        unit = a[0] if a else None
        cand_filter = None
        want_amount = None
        if ev == "UNIT_COMBAT":
            want_amount = _amount(a, 3)
            if unit == "player":
                def cand_filter(f):
                    return f["dst"] == player_guid and (f["event"] or "").endswith(DAMAGE_HEAL + ("ENVIRONMENTAL_DAMAGE",)) \
                        or (f["dst"] == player_guid and (f["event"] or "").startswith("ENVIRONMENTAL"))
            else:
                def cand_filter(f):
                    return f["dst"] != player_guid and (f["event"] or "").endswith(DAMAGE_HEAL)
        elif ev in ("UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START") and unit == "player":
            sub = "SPELL_CAST_SUCCESS" if ev.endswith("SUCCEEDED") else "SPELL_CAST_START"
            sid = _amount(a, 2)

            def cand_filter(f, sub=sub, sid=sid):
                return f["src"] == player_guid and f["event"] == sub and (sid in (None, "<secret>") or f.get("spellID") == sid)
        else:
            continue
        win = window_ms / 1000.0 if it.get("precise") else max(window_ms / 1000.0, 1.5)
        lo = bisect.bisect_left(keys, it["epoch"] - win)
        hi = bisect.bisect_right(keys, it["epoch"] + win)
        # v2.2.11: one file line can be matched once per addon stream - the event recorder (addon-event) and the combat
        # recorder (addon-cl) record the same game event independently (smoke: both streams in one capture)
        src_key = it["source"]
        cands = [f for f in files[lo:hi] if (src_key, id(f)) not in used and cand_filter(f)]
        if not cands:
            it["match"] = {"quality": "unmatched"}
            stats["unmatched"] += 1
            continue
        secret_amt = want_amount == "<secret>"

        def score(f):
            same = (not secret_amt and want_amount is not None and f.get("amount") == want_amount)
            return (0 if same else 1, abs(f["epoch"] - it["epoch"]))
        best = min(cands, key=score)
        used.add((src_key, id(best)))
        dt = (best["epoch"] - it["epoch"]) * 1000.0
        if ev == "UNIT_COMBAT":
            if secret_amt:
                q = "time-only:secret-amount"
            elif best.get("amount") == want_amount:
                q = "exact" if abs(dt) <= exact_ms else "time+amount"
            else:
                q = "time-only:amount-differs"
        else:
            q = "exact" if abs(dt) <= exact_ms else "time+spell"
        it["match"] = {"quality": q, "dtMs": round(dt, 1), "file": "%s %s->%s %s" % (best["event"], best.get("srcName"),
                                                                                       best.get("dstName"), best.get("amount")),
                       "fileLine": best.get("line")}
        best.setdefault("matchedBy", []).append(it["event"])
        stats[q] += 1
    return dict(stats)


def segments(items, gap=8.0):
    """combat segments: addon PLAYER_REGEN_DISABLED..ENABLED; else file-log activity separated by `gap` s"""
    segs = []
    start = None
    for it in items:
        if it["source"] in ("addon-event", "addon-cl"):
            if it["event"] == "PLAYER_REGEN_DISABLED" and start is None:
                start = it["epoch"]
            elif it["event"] == "PLAYER_REGEN_ENABLED" and start is not None:
                segs.append((start - 1.0, it["epoch"] + 1.0, "addon PLAYER_REGEN"))
                start = None
    if start is not None:
        segs.append((start - 1.0, items[-1]["epoch"], "addon PLAYER_REGEN (open)"))
    if not segs:
        dmg = [i["epoch"] for i in items if i["source"] == "file-cl" and (i["event"] or "").endswith("_DAMAGE")]
        if dmg:
            s0 = prev = dmg[0]
            for t in dmg[1:]:
                if t - prev > gap:
                    segs.append((s0 - 1.0, prev + 1.0, "file damage burst"))
                    s0 = t
                prev = t
            segs.append((s0 - 1.0, prev + 1.0, "file damage burst"))
    return segs


def client_items(entries):
    out = []
    for e in entries or []:
        if e["cat"] == "Lua" and e["level"] == "E":
            top = e["stack"][0] if e["stack"] else ""
            out.append({"epoch": e["epoch"], "precise": True, "source": "client-log", "event": "CLIENT_LUA_ERROR",
                        "secret": [], "a": [e["msg"][:120], top[:80]]})
    return out


def build(dump, fx, player_guid, window_ms=750, client=None):
    items = addon_items(dump) + (file_items(fx) if fx else []) + client_items(client)
    items = [i for i in items if i.get("epoch") is not None]
    items.sort(key=lambda i: (i["epoch"], 0 if i["source"] == "file-cl" else 1))
    stats = match(items, player_guid, window_ms) if fx else {}
    offset = None
    if fx:
        offset = fx.get("utcOffsetSec")
    if offset is None:
        for sess in as_list(dump.combatlog.get("sessions")) + as_list(dump.record.get("sessions")):
            if isinstance(sess.get("anchor"), dict) and sess["anchor"].get("utcOffset") is not None:
                offset = sess["anchor"]["utcOffset"]
                break
    tz = datetime.timezone(datetime.timedelta(seconds=offset or 0))
    for it in items:
        it["iso"] = datetime.datetime.fromtimestamp(it["epoch"], tz).isoformat(timespec="milliseconds")
        it["secretStatus"] = "secret" if it.get("secret") else ("clear" if it["source"] != "file-cl" else "unrestricted")
    by_source = collections.Counter(i["source"] for i in items)
    return {"items": items, "stats": stats, "bySource": dict(by_source), "segments": segments(items), "utcOffsetSec": offset,
            "playerGUID": player_guid}


def write_jsonl(path, res):
    with open(path, "w", encoding="utf-8") as f:
        for it in res["items"]:
            row = {k: v for k, v in it.items() if k not in ("a",)}
            if it.get("a") is not None:
                row["a"] = _short(it["a"], 8)
            f.write(json.dumps(row, ensure_ascii=False, default=str) + "\n")


def markdown(res, per_segment=80):
    L = ["# ForeverDump xref timeline", "",
         "Player GUID: `%s`; UTC offset %s s. Sources: %s" % (res["playerGUID"], res["utcOffsetSec"],
                                                              ", ".join("%s %d" % kv for kv in sorted(res["bySource"].items()))),
         "", "Match quality (addon -> file): " + (", ".join("%s %d" % kv for kv in sorted(res["stats"].items())) or "n/a"), ""]
    for n, (a, b, why) in enumerate(res["segments"], 1):
        rows = [i for i in res["items"] if a <= i["epoch"] <= b]
        q = collections.Counter(i["match"]["quality"] for i in rows if i.get("match"))
        L += ["## Combat %d (%s): %s .. %s, %d lines" % (n, why, rows[0]["iso"] if rows else "?", rows[-1]["iso"] if rows else "?", len(rows)),
              "", "matches: " + (", ".join("%s %d" % kv for kv in sorted(q.items())) or "none"), "",
              "| time | source | event | details | secret | match |", "|---|---|---|---|---|---|"]
        for i in rows[:per_segment]:
            if i["source"] == "file-cl" and i.get("dst") is not None:
                det = "%s -> %s %s" % (i.get("srcName"), i.get("dstName"), "" if i.get("amount") is None else i.get("amount"))
            else:
                det = " ".join(str(x) for x in _short(i.get("a") or [], 5))
            m = i.get("match")
            ms = ("%s (%+.0f ms) %s" % (m["quality"], m.get("dtMs", 0), m.get("file", ""))) if m and m["quality"] != "unmatched" else (
                "unmatched" if m else ("<- " + ",".join(i["matchedBy"]) if i.get("matchedBy") else ""))
            sec = "secret %s" % i["secret"] if i.get("secret") else i["secretStatus"]
            L.append("| %s | %s | %s | %s | %s | %s |" % (i["iso"][11:23], i["source"], i["event"], det.replace("|", "/")[:80], sec, ms))
        if len(rows) > per_segment:
            L.append("| ... %d more lines in timeline.jsonl | | | | | |" % (len(rows) - per_segment))
        L.append("")
    if not res["segments"]:
        L.append("No combat segments found (no PLAYER_REGEN pairs in the addon data and no damage in the file log).")
    return "\n".join(L) + "\n"
