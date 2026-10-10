"""(1) JSON exports per section."""
import json
import math
import os

from .luasv import as_list

V1_KEYS = ("build", "version", "buildNumber", "toc", "apis", "events", "enums", "cvars", "cvarNames", "commands")


def _fix_str(s):
    # invalid UTF-8 from the SV (read with surrogateescape) -> U+FFFD so JSON stays writable
    try:
        s.encode("utf-8")
        return s
    except UnicodeEncodeError:
        return s.encode("utf-8", "surrogateescape").decode("utf-8", "replace")


def _clean(o):
    if isinstance(o, str):
        return _fix_str(o)
    if isinstance(o, float) and (math.isnan(o) or math.isinf(o)):
        return str(o)
    if isinstance(o, dict):
        return {_fix_str(str(k)): _clean(v) for k, v in o.items()}
    if isinstance(o, list):
        return [_clean(v) for v in o]
    return o


def write_json(path, obj, indent=1):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(_clean(obj), f, indent=indent, ensure_ascii=False, sort_keys=True)


def export(dump, out):
    written = []

    def w(rel, obj):
        p = os.path.join(out, rel)
        write_json(p, obj)
        written.append(rel)

    w("dump.json", dump.raw)  # full parsed dump; reload with any tool here
    w("meta.json", {"meta": dump.meta(), "history": dump.db.get("history"), "errors": dump.db.get("errors"),
                    "config": dump.db.get("config"), "schemaVersion": dump.db.get("schemaVersion")})
    w("v1.json", {k: dump.db.get(k) for k in V1_KEYS if k in dump.db})
    for name, data in dump.sections.items():
        w("sections/%s.json" % name, data)
    if dump.docs:
        w("docs.json", dump.docs)
    if dump.strings:
        w("strings.json", dump.strings)
    for i, sess in enumerate(as_list(dump.record.get("sessions")), 1):
        w("record/session_%d.json" % i, sess)
    for i, sess in enumerate(as_list(dump.combatlog.get("sessions")), 1):
        w("combatlog/session_%d.json" % i, sess)
    if dump.log:
        w("errors.json", {"errors": as_list(dump.log.get("errors")), "blocked": as_list(dump.log.get("blocked")),
                          "handlerEvents": as_list(dump.log.get("handlerEvents")),
                          "droppedErrors": dump.log.get("droppedErrors"), "droppedBlocked": dump.log.get("droppedBlocked")})
    return written
