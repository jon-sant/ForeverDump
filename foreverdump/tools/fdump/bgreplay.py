"""v2.2.10 real-data load replay: export a captured event stream (combat ring + event recorder) from a SavedVariables
file into a Lua stream file for tests/bg_replay.lua, which fires it back through the addon (accelerated, tiled).

The stream holds raw captured payloads (names/GUIDs of other players included), so it is written under tests/out/
(never packaged) and deleted by the caller after the run. Secret markers become the harness's secret value."""
from __future__ import annotations

import os
import pickle

from .luasv import as_list

SECRET_MARKERS = ("<secret>", "<secrettable>")


def _lua(v, out):
    if v is None or v == "<nil>":
        out.append("nil")
    elif isinstance(v, bool):
        out.append("true" if v else "false")
    elif isinstance(v, (int, float)):
        out.append(repr(v) if isinstance(v, float) else str(v))
    elif isinstance(v, str):
        if v in SECRET_MARKERS:
            out.append("X")
        else:
            out.append('"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")
                       .replace("\0", "\\0") + '"')
    elif isinstance(v, (list, tuple)):
        out.append("{")
        for x in v:
            _lua(x, out)
            out.append(",")
        out.append("}")
    elif isinstance(v, dict):
        out.append("{")
        for k, x in v.items():
            if isinstance(k, int):
                out.append("[%d]=" % k)
            else:
                out.append("[")
                _lua(str(k), out)
                out.append("]=")
            _lua(x, out)
            out.append(",")
        out.append("}")
    else:
        out.append("nil")


def load_raw(path):
    if path.endswith(".pkl"):
        with open(path, "rb") as f:
            return pickle.load(f)
    from .dump import load_raw as lr
    return lr(path)


def main_capture(raw, sid=None):
    """(combat session, record session or None) of the capture with the most combat-ring rows (or sid)"""
    cl = [s for s in as_list((raw.get("ForeverDumpCombatLogDB") or {}).get("sessions")) if isinstance(s, dict)]
    if sid:
        cl = [s for s in cl if s.get("captureSid") == sid]
    if not cl:
        return None, None
    best = max(cl, key=lambda s: len(as_list(s.get("events"))))
    rec = [s for s in as_list((raw.get("ForeverDumpRecordDB") or {}).get("sessions"))
           if isinstance(s, dict) and s.get("captureSid") == best.get("captureSid")]
    return best, (max(rec, key=lambda s: len(as_list(s.get("events")))) if rec else None)


def stream(raw, sid=None):
    """merged raw stream: every combat-ring row + recorder rows of event types the combat ring did not register"""
    cs, rs = main_capture(raw, sid)
    if not cs:
        return None
    reg = set(as_list(cs.get("registered")))
    rows = []
    for i, e in enumerate(as_list(cs.get("events"))):
        if isinstance(e, dict) and e.get("e") and not e.get("cleu"):
            rows.append((float(e.get("t") or 0), 0, i, e))
    nrec = 0
    for i, e in enumerate(as_list((rs or {}).get("events"))):
        if isinstance(e, dict) and e.get("e") and e.get("e") not in reg and not e.get("cb") and not e.get("redacted"):
            rows.append((float(e.get("t") or 0), 1, i, e))
            nrec += 1
    rows.sort(key=lambda x: (x[0], x[1], x[2]))
    meta = {"captureSid": cs.get("captureSid"), "anchor": cs.get("anchor"), "startTime": cs.get("startTime"),
            "stopTime": cs.get("stopTime"), "restrictionsAtStart": cs.get("restrictionsAtStart"),
            "instanceType": (cs.get("instanceAtStart") or {}).get("instanceType"), "combatRows": len(rows) - nrec,
            "recorderRows": nrec, "recorderFirst": as_list((rs or {}).get("events"))[0].get("t") if rs and as_list(rs.get("events")) else None}
    return meta, [r[3] for r in rows]


def export(src, out_path, sid=None):
    raw = load_raw(src)
    res = stream(raw, sid)
    if not res:
        raise SystemExit("no combat-ring capture in %s" % src)
    meta, rows = res
    out = ["return {meta="]
    _lua({k: v for k, v in meta.items() if k != "anchor"}, out)
    out.append(",anchor=")
    anc = meta.get("anchor") or {}
    _lua({"epoch": anc.get("epoch"), "gameTime": anc.get("gameTime"), "utcOffset": anc.get("utcOffset")}, out)
    out.append(",events={\n")
    for e in rows:
        out.append("{t=%r,e=" % float(e.get("t") or 0))
        _lua(e.get("e"), out)
        out.append(",c=%s,n=%d,a=" % ("true" if e.get("c") else "false", int(e.get("n") or len(as_list(e.get("a"))))))
        _lua(as_list(e.get("a")), out)
        out.append("},\n")
    out.append("}}\n")
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write("".join(out))
    return meta, len(rows)


if __name__ == "__main__":
    import sys
    m, n = export(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    print("exported %d rows (%s)" % (n, {k: v for k, v in m.items() if k != "anchor"}))
