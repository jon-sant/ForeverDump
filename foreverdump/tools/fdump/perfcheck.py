"""Static performance lint for WoW addons (PERFORMANCE.md rule).

The rule: no measurable framerate impact (<1%), no idle OnUpdate, O(1) per-event cost, dirty-only throttled redraws,
heavy work out of combat or offline. This lint is the cheap, static half; tests/perf_bench.lua (runtime, N casts,
2-minute wall cap) is the authoritative half.

Findings (level):
  onupdate-every-frame (error)  OnUpdate handler neither throttled (elapsed accumulator / GetTime compare) nor self-removing
  onupdate-idle        (warn)   throttled OnUpdate that is never removed/hidden in the file (runs while idle)
  global-walk          (error)  pairs(_G)/pairs(getfenv()) outside an annotated, cached or dump-only function
  heavy-call           (error)  an OnUpdate/OnEvent handler calls a same-file function that walks _G, or a known-expensive
                                client API (UpdateAddOnMemoryUsage, UpdateAddOnCPUUsage, ...). Cross-file chains (run 4:
                                redraw -> Knowledge.DB -> ns.Meta -> pairs(_G)) are what the runtime benchmark catches.
  sort-in-handler      (warn)   table.sort inside an OnUpdate/OnEvent handler body
  string-build-onupdate(warn)   string building in an unthrottled OnUpdate body (rebuild text only when dirty)
  queue-shift          (warn in a handler body, else note)  table.remove(t, 1) / table.insert(t, 1, v): O(n) per call
  ticker-no-cancel     (warn)   C_Timer.NewTicker without any :Cancel() in the file
  register-all-events  (error)  RegisterAllEvents()

Suppress a finding with a comment on the same or the previous line:  -- perf-ok: <reason>
"""
import os
import re

from .apicheck import tokenize, addon_files

OPENERS = {"function", "if", "do", "repeat"}
CLOSERS = {"end", "until"}
ANNOT = re.compile(r"--\s*perf-ok\b", re.I)
RULE = ("no measurable framerate impact (<1%), no idle OnUpdate, O(1) per-event cost, dirty-only throttled redraws, "
        "heavy work out of combat or offline")


def _block_end(toks, i):
    """toks[i] is 'function': index of its matching 'end'."""
    depth = 0
    for j in range(i, len(toks)):
        k, v, _ = toks[j]
        if k != "name":
            continue
        if v in OPENERS:
            depth += 1
        elif v in CLOSERS:
            depth -= 1
            if depth == 0:
                return j
    return len(toks) - 1


def _functions(toks):
    """name (last dotted segment and full) -> (start, end) token span for every named function in the file."""
    out = {}
    n = len(toks)
    for i, (k, v, _) in enumerate(toks):
        if k != "name" or v != "function":
            continue
        name = None
        j = i + 1
        if j < n and toks[j][0] == "name" and toks[j][1] not in ("(",):
            parts = [toks[j][1]]
            j += 1
            while j + 1 < n and toks[j][1] in (".", ":") and toks[j + 1][0] == "name":
                parts.append(toks[j + 1][1])
                j += 2
            name = ".".join(parts)
        elif i >= 2 and toks[i - 1][1] == "=":   # x = function / a.b = function
            j = i - 2
            parts = [toks[j][1]]
            while j >= 2 and toks[j - 1][1] in (".", ":"):
                parts.insert(0, toks[j - 2][1])
                j -= 2
            name = ".".join(parts)
        if name:
            span = (i, _block_end(toks, i))
            out[name] = span
            out.setdefault(name.split(".")[-1], span)
    return out


def _body_text(toks, span):
    return " ".join(t[1] if t[0] != "str" else '"%s"' % t[1] for t in toks[span[0]:span[1] + 1])


def _annotated(lines, line):
    for ln in (line, line - 1):
        if 1 <= ln <= len(lines) and ANNOT.search(lines[ln - 1]):
            return True
    return False


def _handlers(toks, funcs, script):
    """(line, span) for each SetScript/HookScript(script, handler) whose handler resolves to a body in this file."""
    out = []
    n = len(toks)
    for i in range(n - 5):
        if toks[i][1] in ("SetScript", "HookScript") and toks[i + 1][1] == "(" and toks[i + 2] == ("str", script, toks[i + 2][2]) \
                and toks[i + 3][1] == ",":
            h = toks[i + 4]
            if h[1] == "function":
                out.append((toks[i][2], (i + 4, _block_end(toks, i + 4))))
            elif h[0] == "name" and h[1] != "nil":
                parts = [h[1]]
                j = i + 5
                while j + 1 < n and toks[j][1] in (".", ":") and toks[j + 1][0] == "name":
                    parts.append(toks[j + 1][1])
                    j += 2
                span = funcs.get(".".join(parts)) or funcs.get(parts[-1])
                if span:
                    out.append((toks[i][2], span))
    return out


THROTTLE = re.compile(r"(\w+ = \w+ \+ \(?\s*\w+|\w+ = \w+ \+ \w+)|GetTime \( \) - \w+|(<|>|<=|>=) [\w.]*[Ii]nterval|"
                      r"(acc|elapsed|el|dt|since|t)\w* (<|>|<=|>=)")
SELF_REMOVE = re.compile(r'SetScript \( "OnUpdate" , nil \)|: Hide \( \)')
HEAVY_APIS = ("UpdateAddOnMemoryUsage", "UpdateAddOnCPUUsage", "GetScriptCPUUsage", "ResetCPUUsage", "debugstack")
STRING_BUILD = re.compile(r'\.\. |string \. format|table \. concat|: format \(|format \(')


def scan_file(path, rel=None):
    rel = rel or path
    with open(path, encoding="utf-8", errors="replace") as f:
        src = f.read()
    lines = src.split("\n")
    toks = tokenize(src)
    funcs = _functions(toks)
    findings = []

    def add(level, rule, line, msg):
        if _annotated(lines, line):
            return
        findings.append({"level": level, "rule": rule, "file": rel, "line": line, "message": msg})

    # functions that walk _G
    heavy = {}
    n = len(toks)
    walks = []
    for i in range(n - 4):
        if toks[i][1] in ("pairs", "next") and toks[i + 1][1] == "(" and (toks[i + 2][1] == "_G" or toks[i + 2][1] == "getfenv"):
            walks.append(i)
    for name, span in funcs.items():
        if any(span[0] <= w <= span[1] and not _annotated(lines, toks[w][2]) for w in walks):
            heavy[name] = span
    for w in walks:
        add("error", "global-walk", toks[w][2], "pairs(_G) walks every global (52k on Forever 70245, ~17 ms): cache the result once per "
            "session or run it in a chunked out-of-combat job; never from an event, OnUpdate or redraw path")
    onupd = _handlers(toks, funcs, "OnUpdate")
    onev = _handlers(toks, funcs, "OnEvent")
    has_remove = bool(re.search(r'SetScript\s*\(\s*"OnUpdate"\s*,\s*nil\s*\)|:Hide\s*\(\s*\)', src))
    seen = set()
    for line, span in onupd:
        if span in seen:
            continue
        seen.add(span)
        body = _body_text(toks, span)
        throttled = bool(THROTTLE.search(body))
        self_rm = bool(SELF_REMOVE.search(body))
        if not throttled and not self_rm:
            add("error", "onupdate-every-frame", line, "OnUpdate runs every frame with no throttle and never removes itself: "
                "accumulate elapsed and act at <=10 Hz, and SetScript('OnUpdate', nil) / Hide() when idle")
        elif not self_rm and not has_remove:
            add("warn", "onupdate-idle", line, "throttled OnUpdate is never removed or hidden: idle frames still pay for it; "
                "install it on MarkDirty and remove it when nothing is pending")
        if not throttled and STRING_BUILD.search(body):
            add("warn", "string-build-onupdate", line, "string building inside an unthrottled OnUpdate: rebuild text only when dirty")
    hw = {name.split(".")[-1]: [name.split(".")[-1], "pairs(_G)"] for name in heavy if not _annotated(lines, toks[heavy[name][0]][2])}
    for api in HEAVY_APIS:
        hw.setdefault(api, [api, "known-expensive client API"])
    for line, span in onupd + onev:
        body_toks = toks[span[0]:span[1] + 1]
        for j, t in enumerate(body_toks):
            if t[0] == "name" and t[1] in hw and (j + 1 < len(body_toks) and body_toks[j + 1][1] == "(") \
                    and (j == 0 or body_toks[j - 1][1] != "function"):
                add("error", "heavy-call", t[2], "an OnUpdate/OnEvent handler reaches a _G walk: %s (cache it once per session)" % (
                    " -> ".join(hw[t[1]][:8])))
            if t[1] == "sort" and j and body_toks[j - 1][1] == "." and j > 1 and body_toks[j - 2][1] == "table":
                add("warn", "sort-in-handler", t[2], "table.sort in a per-event/per-frame handler: keep the list ordered "
                    "incrementally or cache the sorted result until it changes")
    handler_spans = [s for _, s in onupd + onev]
    for i in range(n - 6):
        if toks[i][1] == "table" and toks[i + 1][1] == "." and toks[i + 2][1] in ("remove", "insert") and toks[i + 3][1] == "(":
            j = i + 4
            depth = 0
            while j < n and not (depth == 0 and toks[j][1] == ","):
                depth += toks[j][1] in ("(", "{", "[")
                depth -= toks[j][1] in (")", "}", "]")
                if depth < 0:
                    break
                j += 1
            if j + 1 < n and toks[j][1] == "," and toks[j + 1] == ("num", "1", toks[j + 1][2]) and \
                    (toks[i + 2][1] == "remove" and toks[j + 2][1] == ")" or toks[i + 2][1] == "insert" and toks[j + 2][1] == ","):
                in_h = any(s[0] <= i <= s[1] for s in handler_spans)
                add("warn" if in_h else "note", "queue-shift", toks[i][2], "table.%s(t, 1...) shifts the whole list (O(n)); "
                    "fine for small bounded lists, otherwise use a ring buffer or amortised trim" % toks[i + 2][1])
        if toks[i][1] == "RegisterAllEvents" and toks[i + 1][1] == "(":
            add("error", "register-all-events", toks[i][2], "RegisterAllEvents: every event in the client hits this frame")
    if re.search(r"NewTicker\s*\(", src) and not re.search(r":\s*Cancel\s*\(", src):
        m = re.search(r"NewTicker\s*\(", src)
        add("warn", "ticker-no-cancel", src[:m.start()].count("\n") + 1, "C_Timer.NewTicker never cancelled: stop it when the feature is off")
    return findings


def scan(folder, files=None):
    files = files or addon_files(folder)
    out = []
    for p in files:
        out.extend(scan_file(p, os.path.relpath(p, folder)))
    order = {"error": 0, "warn": 1, "note": 2}
    out.sort(key=lambda f: (order.get(f["level"], 9), f["file"], f["line"]))
    return out


def summary(findings):
    c = {"error": 0, "warn": 0, "note": 0}
    for f in findings:
        c[f["level"]] = c.get(f["level"], 0) + 1
    return c


def markdown(findings, title="Performance lint", folder=""):
    c = summary(findings)
    L = ["## %s" % title if title else "", "",
         "Rule (PERFORMANCE.md): %s. Static lint: %d error(s), %d warning(s), %d note(s)%s. "
         "The runtime gate is tests/perf_bench.lua-style N-cast benchmarking with a 2-minute wall cap." % (
             RULE, c["error"], c["warn"], c["note"], (" in " + folder) if folder else ""), ""]
    if not findings:
        L.append("- none found")
    for f in findings:
        L.append("- **%s** %s:%d [%s] %s" % (f["level"], f["file"], f["line"], f["rule"], f["message"]))
    return "\n".join(L) + "\n"
