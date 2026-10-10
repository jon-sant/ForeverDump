"""Clock formatting for reports (time audit 2026-10-10).

Epochs in reports used to be formatted with datetime.fromtimestamp(t) = the BOX zone, so the same dump printed
different wall clocks on a box in another zone (or under TZ=UTC in the test matrix). The client's zone is known from
the dump (Core.TimeAnchor utcOffset / CombatLog utcOffsetSec); Dump() registers it here and every report clock uses it.
No dump loaded -> box zone (old behaviour)."""
import datetime

CLIENT_OFFSET = None   # seconds east of UTC of the client that wrote the most recently loaded dump


def set_client_offset(off):
    global CLIENT_OFFSET
    if isinstance(off, (int, float)):
        CLIENT_OFFSET = off


def dump_offset(raw):
    """first anchor utcOffset in a raw SV dict (recorder / CL sessions), else None"""
    for key in ("ForeverDumpRecordDB", "ForeverDumpCombatLogDB"):
        sess = ((raw or {}).get(key) or {}).get("sessions")
        sess = list(sess.values()) if isinstance(sess, dict) else (sess or [])
        for s in sess:
            if not isinstance(s, dict):
                continue
            a = s.get("anchor") if isinstance(s.get("anchor"), dict) else {}
            off = a.get("utcOffset") if a.get("utcOffset") is not None else s.get("utcOffsetSec")
            if isinstance(off, (int, float)):
                return off
    return None


def dt(epoch, off=None):
    off = CLIENT_OFFSET if off is None else off
    if off is None:
        return datetime.datetime.fromtimestamp(epoch)
    return datetime.datetime.fromtimestamp(epoch, datetime.timezone(datetime.timedelta(seconds=off)))


def clock(epoch, fmt="%H:%M:%S", off=None):
    return dt(epoch, off).strftime(fmt)
