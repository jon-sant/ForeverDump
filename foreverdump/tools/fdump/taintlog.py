"""Parse Logs/taint.log (CVar taintLog 1..2) into structured entries + per-addon summary. Best-effort: the
message wording is not formally documented, unknown lines are kept with kind "other"."""
import re

TS = re.compile(r"^(\d{1,2}/\d{1,2}(?:/\d{2,4})?\s+\d{1,2}:\d{2}:\d{2}(?:\.\d+)?)(\s+)(.*)$")
PATTERNS = [
    ("global_tainted", re.compile(r"^Global variable (?P<variable>\S+) tainted by (?P<addon>\S+?)(?: - (?P<location>.*))?$")),
    ("action_blocked", re.compile(r"^An action was blocked(?P<combat> in combat)? because of taint from (?P<addon>\S+?) - (?P<function>.*)$")),
    # 70245: "Execution tainted by X while reading field info (<table: 0000...>) - .../MoneyFrame.lua:226 MoneyFrame_Update()"
    ("execution_tainted", re.compile(r"^Execution tainted by (?P<addon>\S+?) while reading (?P<variable>.+?)(?: \((?P<object><[^>]*>)\))?(?: - (?P<location>.*))?$")),
    # Forever secrets: "An attempt to perform arithmetic on a secret value was blocked because of taint from X - <file:line func()>"
    ("secret_blocked", re.compile(r"^An attempt to (?:perform )?(?P<operation>.+?) on a secret value was blocked because of taint from (?P<addon>\S+?)(?: - (?P<location>.*))?$")),
    ("attempt_blocked", re.compile(r"^An attempt to (?P<operation>.+?) was blocked because of taint from (?P<addon>\S+?)(?: - (?P<location>.*))?$")),
    ("protected_call", re.compile(r"^AddOn '(?P<addon>[^']+)' tried to call the protected function '(?P<function>[^']+)'")),
    ("forbidden_call", re.compile(r"^AddOn '(?P<addon>[^']+)' tried to call the forbidden function '(?P<function>[^']+)'")),
    ("key_tainted", re.compile(r"^(?P<variable>\S+) tainted by (?P<addon>\S+?)(?: - (?P<location>.*))?$")),
    ("interface_action_failed", re.compile(r"^Interface action failed because of an AddOn")),
    ("marker", re.compile(r"^\*\*\* (?P<message>.*) \*\*\*$")),
]
STACK = re.compile(r"^\s+(?P<frame>.*)$")


def parse(path):
    entries, current = [], None
    with open(path, encoding="utf-8", errors="replace") as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.rstrip("\r\n")
            if not line.strip():
                continue
            m = TS.match(line)
            if m:
                ts, indent, body = m.group(1), len(m.group(2).expandtabs(4)), m.group(3)
            else:
                ts, body = None, line.lstrip()
                indent = len(line) - len(body)
            if indent > 2:
                if current is not None:
                    current["stack"].append(body.strip())
                    if "addonFromStack" not in current:
                        a = re.search(r"[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\]", body)
                        if a and not a.group(1).startswith("Blizzard_"):
                            current["addonFromStack"] = a.group(1)
                continue
            body = body.strip()
            entry = {"time": ts, "line": lineno, "message": body, "kind": "other", "stack": []}
            for kind, rx in PATTERNS:
                mm = rx.match(body)
                if mm:
                    entry["kind"] = kind
                    entry.update({k: v for k, v in mm.groupdict().items() if v is not None})
                    if "combat" in entry:
                        entry["combat"] = True
                    break
            if entry["kind"] == "execution_tainted" and entry.get("variable", "").startswith("field "):
                entry["field"] = entry["variable"][6:]
            entries.append(entry)
            current = entry
    summary = {"byKind": {}, "byAddon": {}}
    for e in entries:
        summary["byKind"][e["kind"]] = summary["byKind"].get(e["kind"], 0) + 1
        addon = e.get("addon") or e.get("addonFromStack")
        if addon:
            d = summary["byAddon"].setdefault(addon, {})
            d[e["kind"]] = d.get(e["kind"], 0) + 1
    blocked_functions = {}
    for e in entries:
        if e["kind"] in ("action_blocked", "protected_call", "forbidden_call"):
            k = "%s -> %s" % (e.get("addon"), e.get("function"))
            blocked_functions[k] = blocked_functions.get(k, 0) + 1
    summary["blocked"] = blocked_functions
    # origin: first non-Blizzard frame in the stack (where the tainted execution entered Blizzard code)
    for e in entries:
        for fr in e["stack"]:
            a = re.search(r"[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\](\S+)", fr)
            if a and not a.group(1).startswith("Blizzard_"):
                e["origin"] = "%s/%s" % (a.group(1), a.group(2))
                break
    secret = {}
    for e in entries:
        if e["kind"] == "secret_blocked":
            k = "%s: %s at %s (entered via %s)" % (e.get("addon"), e.get("operation"), e.get("location"), e.get("origin", "?"))
            secret[k] = secret.get(k, 0) + 1
    summary["secretBlocked"] = secret
    cls = {}
    for e in entries:
        c, why = classify(e)
        e["class"], e["classWhy"] = c, why
        cls[c] = cls.get(c, 0) + 1
    summary["byClass"] = cls
    return {"file": str(path), "count": len(entries), "entries": entries, "summary": summary}


# v2.2.2: separate ForeverDump's intentional probes from real problems.
#   expected        = operations-matrix / lab boundary probes on secrets (Controls.lua opsFor, Lab.lua boundary ops), inside pcall
#   contained       = ForeverDump-only taint of its own tables (Lab AddPoint on our curve, Core utcOffset date table)
#   probe-blocked   = an action blocked inside a ForeverDump probe call (fixed in 2.2.2: attribution + combat skip)
#   blizzard-frame  = a Blizzard frame ran tainted because of us
#   benign-chat     = (v2.2.3) ChatFrameN:UpdateFading read oldestFadingLineTimestamp (v2.2.9: or the line's messageInfo)
#                     written by one of our chat lines (ns.Print
#                     from a slash command): no secret, no blocked action; every addon that prints to chat does this
#   contained also covers (v2.2.3) Blizzard mixin code (SecureTypes/CircularBuffer) running on OUR hidden ScrollingMessageFrame,
#                     the ops-matrix print sink (Controls.lua opsFor -> AddMessage); ChatFrame1 is not involved
#   unexpected      = everything else (other addons, unknown sites)
EXPECTED_PROBE = re.compile(r"ForeverDump/(Controls\.lua:1[4-9]\d|Lab\.lua:2[0-9]\d)")
CONTAINED = re.compile(r"ForeverDump/(Lab\.lua:\d+|Core\.lua:\d+ utcOffset)")


def classify(e):
    st = [str(f) for f in (e.get("stack") or [])]
    top = " | ".join(st[:3])
    msg = str(e.get("message") or "")
    allst = " | ".join(st)
    ours = "ForeverDump" in (str(e.get("addon") or "") + msg + allst)
    if not ours:
        return "unexpected", "not ForeverDump"
    if e.get("kind") == "execution_tainted" and "SecureTypes.lua" in top and re.search(r"ForeverDump/Controls\.lua:\d+ opsFor", allst) \
            and "ScrollingMessageFrame" in allst and not re.search(r"ChatFrame\d", allst):
        return "contained", "Blizzard mixin code on our own hidden ScrollingMessageFrame (ops-matrix print sink), not a Blizzard frame"
    if e.get("kind") == "execution_tainted" and re.search(r"ChatFrame\d+:UpdateFading", top) \
            and re.search(r"field (oldestFadingLineTimestamp|messageInfo)\b", msg):   # v2.2.9 run 8: messageInfo = the same chat line
        return "benign-chat", ("chat fading read a timestamp written by our chat print (ns.Print); no secret, no blocked action "
                               "(any addon printing to chat does this)")
    if "Blizzard_" in (st[0] if st else "") or re.search(r"ChatFrame\d|UpdateFading", top):
        return "blizzard-frame", "Blizzard frame ran tainted: %s" % (st[0] if st else "?")
    if "action was blocked" in msg or e.get("kind") in ("action_blocked", "protected_call", "forbidden_call"):
        if "ForeverDump/CombatProbe.lua" in allst or "ForeverDump/Containers.lua" in allst:
            return "probe-blocked", "blocked inside a ForeverDump probe (CombatProbe record(); 2.2.2 names it and skips it in combat)"
        return "unexpected", "blocked action outside the probe set"
    if e.get("kind") in ("secret_blocked", "attempt_blocked") and EXPECTED_PROBE.search(top):
        return "expected", "expected (ForeverDump probe): operations matrix / lab boundary op inside pcall"
    if e.get("kind") == "execution_tainted" and CONTAINED.search(top):
        return "contained", "ForeverDump-only taint of its own table (no Blizzard frame on the stack)"
    if e.get("kind") in ("secret_blocked", "attempt_blocked") and "ForeverDump/" in (st[0] if st else ""):
        return "expected", "secret operation inside ForeverDump code (pcall)"
    return "unexpected", "unclassified"


def text_summary(result):
    out = ["taint.log: %d entries" % result["count"]]
    for k, v in sorted(result["summary"]["byKind"].items(), key=lambda x: -x[1]):
        out.append("  %-24s %d" % (k, v))
    if result["summary"].get("byClass"):
        out.append("classification: " + ", ".join("%s=%d" % kv for kv in sorted(result["summary"]["byClass"].items(), key=lambda x: -x[1])))
    out.append("by addon:")
    for a, kinds in sorted(result["summary"]["byAddon"].items()):
        out.append("  %-30s %s" % (a, ", ".join("%s=%d" % kv for kv in sorted(kinds.items()))))
    if result["summary"].get("secretBlocked"):
        out.append("secret-value operations blocked by taint (the addon made Blizzard code run tainted; that code then touched a secret):")
        for k, v in sorted(result["summary"]["secretBlocked"].items(), key=lambda x: -x[1]):
            out.append("  %4dx %s" % (v, k))
    if result["summary"]["blocked"]:
        out.append("blocked/protected calls:")
        for k, v in sorted(result["summary"]["blocked"].items(), key=lambda x: -x[1]):
            out.append("  %4dx %s" % (v, k))
    return "\n".join(out)
