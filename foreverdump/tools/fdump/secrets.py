"""Secrets map: documented secrecy/restriction annotations (Blizzard_APIDocumentation, as walked by the addon) merged
with runtime observations (ForeverDumpDB.secretsObs in v2.1, plus anything derivable from recorder / combat-recorder
sessions and probe results in older dumps).

Secrecy classes (per function return / event payload / struct field):
  always       documented secret every time: SecretReturns, SecretValue, SecretPayloads
  conditional  secret under a documented condition: SecretWhen*, SecretIn*, ConditionalSecret, SecretReturnsForAspect,
               ConstSecretAccessor (returns secret when the object/argument is secret)
  never        NeverSecret / ReturnsNeverSecret
  unspecified  no annotation (treat as "not documented secret"; observations may still show secrets)
Argument rule (SecretArguments): NotAllowed = passing a secret errors; AllowedWhenUntainted = only secure (untainted)
code may pass secrets, so addon code passing one errors; AllowedWhenTainted = addons may pass secrets.
"""
import collections
import json
import re

from .dump import as_list

COND_PREFIXES = ("SecretWhen", "SecretIn")
ALWAYS_KEYS = ("SecretReturns", "SecretValue", "SecretPayloads")
RESTRICT_KEYS = ("HasRestrictions", "IsProtectedFunction", "RestrictedForMacroChatMessages", "RequireNPERestricted")
STANDARD = {"Name", "Type", "Arguments", "Returns", "Documentation", "Nilable", "InnerType", "Mixin", "Default",
            "StrideIndex", "KeyType", "NilableContents", "EnumValue", "LiteralName", "Payload", "Fields", "Values",
            "MinValue", "MaxValue", "NumValues", "Namespace", "Environment", "Predicates", "Tables", "Events",
            "Functions", "ObjectType", "_present", "_valid", "SynchronousEvent", "UniqueEvent", "CallbackEvent",
            "MayReturnNothing"}
SLOT_NAMES = ("outOfCombat", "inCombat", "inEncounter")


def is_flag(k):
    return isinstance(k, str) and k not in STANDARD


def node_flags(node):
    return {k: v for k, v in node.items() if is_flag(k) and not isinstance(v, dict)}


def conditions(node):
    """Names of the conditional-secrecy flags on a function/event node."""
    out = [k for k in node if isinstance(k, str) and k.startswith(COND_PREFIXES) and node[k]]
    if node.get("SecretReturnsForAspect"):
        out.append("SecretReturnsForAspect=%s" % ",".join(str(a) for a in as_list(node["SecretReturnsForAspect"])))
    if node.get("ConstSecretAccessor"):
        out.append("ConstSecretAccessor")
    return sorted(out)


def classify_value(node, parent_class="unspecified"):
    if node.get("SecretValue"):
        return "always"
    if node.get("NeverSecret"):
        return "never"
    if node.get("ConditionalSecret") or node.get("ConditionalSecretContents"):
        return "conditional"
    return parent_class


def classify_parent(node):
    if any(node.get(k) for k in ALWAYS_KEYS):
        return "always"
    if conditions(node):
        return "conditional"
    if node.get("ReturnsNeverSecret"):
        return "never"
    return "unspecified"


def aspect_names(dump):
    """Enum.SecretAspect (or similarly named) value -> name, from the docs tables or the runtime Enum."""
    out = {}
    for name, t in dump.doc_tables().items():
        if "Aspect" in name and t.get("Type") == "Enumeration":
            for f in as_list(t.get("Fields")):
                if "EnumValue" in f:
                    out.setdefault(str(f["EnumValue"]), "%s.%s" % (name, f.get("Name")))
    return out


# ------------------------------------------------------------------ runtime observations
def _new_row():
    return collections.defaultdict(lambda: [0, 0, 0, 0, 0, 0])


def _add(obs, key, n, secret_positions, slot):
    row = obs.setdefault(key, _new_row())
    sp = set(int(p) for p in as_list(secret_positions) if isinstance(p, (int, float)))
    n = max(1, min(int(n or 0), 24))
    for pos in range(1, n + 1):
        c = row[pos]
        c[slot] += 1
        if pos in sp:
            c[slot + 1] += 1


def _slot(in_combat, in_enc=False):
    return 4 if in_enc else (2 if in_combat else 0)


def _walk_safecalls(node, path, out, depth=0):
    if depth > 6 or not isinstance(node, dict):
        return
    for k, v in node.items():
        if isinstance(v, dict):
            if v.get("ok") is True and "n" in v:
                out.append((str(k), v))
            else:
                _walk_safecalls(v, str(k), out, depth + 1)


def observations(dump):
    """Merge every runtime source into {kind:name: {pos: [oN, oS, cN, cS, eN, eS]}} plus a per-source count."""
    obs = {}
    sources = collections.Counter()
    raw = dump.db.get("secretsObs") or {}
    ctx = {}
    for key, row in raw.items():
        if key.startswith("_") or not isinstance(row, (dict, list)):
            continue
        items = row.items() if isinstance(row, dict) else enumerate(row, 1)
        r = obs.setdefault(key, _new_row())
        for pos, c in items:
            if pos == "x":
                for xp, buckets in (c.items() if isinstance(c, dict) else enumerate(as_list(c), 1)):
                    if not isinstance(buckets, dict):
                        continue
                    for cname, b in buckets.items():
                        b = as_list(b)
                        if cname == "_n" or len(b) < 2:
                            continue
                        ctx.setdefault(key, {}).setdefault(int(xp), {})[cname] = [int(x or 0) for x in (b + [0])[:3]]
                continue
            try:
                ip = int(pos)
            except (TypeError, ValueError):
                continue
            c = as_list(c)
            if len(c) == 6:
                r[ip] = [a + int(b or 0) for a, b in zip(r[ip], c)]
        sources["secretsObs"] += 1
    observations.ctx = ctx
    if raw:
        return obs, dict(sources), True  # v2.1 dumps already aggregate everything (avoid double counting)
    # legacy (v2.0) derivation
    for sess in as_list(dump.record.get("sessions")):
        for e in as_list(sess.get("events")):
            if isinstance(e, dict) and e.get("e"):
                _add(obs, ("cleu:" if e.get("cleu") else "event:") + e["e"], e.get("n"), e.get("s"), _slot(e.get("c")))
                sources["recorder"] += 1
    for sess in as_list(dump.combatlog.get("sessions")):
        for e in as_list(sess.get("events")):
            if isinstance(e, dict) and e.get("e"):
                _add(obs, "event:" + e["e"], e.get("n"), e.get("s"), _slot(e.get("c"), e.get("enc")))
                sources["combatRecorder"] += 1
                for gname, g in (e.get("g") or {}).items():
                    if isinstance(g, dict) and "n" in g:
                        _add(obs, "api:" + gname, g.get("n"), g.get("s"), _slot(e.get("c"), e.get("enc")))
    probe = dump.sections.get("probe") or {}
    for key, res in probe.items():
        if not isinstance(res, dict):
            continue
        calls = []
        _walk_safecalls(res, key, calls)
        inc = bool(res.get("inCombat")) or key == "inCombat"
        for path, sc in calls:
            if "." in path or path[:1].isupper():
                _add(obs, "api:" + path, sc.get("n"), sc.get("secret"), _slot(inc))
                sources["probe"] += 1
    return obs, dict(sources), False


def _ctx_from_slots(row):
    """legacy rows (no context buckets): one bucket per combat state"""
    out = {}
    for pos, c in row.items():
        for i, name in enumerate(("ooc", "combat", "enc")):
            if c[i * 2]:
                out.setdefault(pos, {})["%s/?/?" % name] = [c[i * 2], c[i * 2 + 1], 0]
    return out


STATUS_ORDER = ("CONTRADICTED", "UNDOCUMENTED-SECRET", "CONFIRMED", "UNOBSERVED")


def verify_position(doc, buckets):
    """doc: always|conditional|never|unspecified ; buckets: {ctx: [n, s, inaccessible]} -> verdict dict"""
    if not buckets:
        return {"status": "UNOBSERVED", "doc": doc, "effective": doc, "verified": False}
    n = sum(b[0] for b in buckets.values())
    sec = sum(b[1] for b in buckets.values())
    secret_ctx = sorted(c for c, b in buckets.items() if b[1])
    clear_ctx = sorted(c for c, b in buckets.items() if b[0] > b[1])
    combat_seen = any(c.split("/")[0] in ("combat", "enc") for c in buckets)
    v = {"doc": doc, "samples": n, "secret": sec, "clear": n - sec, "secretContexts": secret_ctx, "clearContexts": clear_ctx,
         "inaccessible": sum(b[2] for b in buckets.values() if len(b) > 2)}
    if sec == n:
        v["effective"] = "always"
    elif sec:
        v["effective"] = "conditional"
    else:
        v["effective"] = "clear" if combat_seen else ("conditional" if doc in ("always", "conditional") else "clear")
    v["verified"] = bool(sec) or combat_seen
    if doc == "always":
        v["status"] = "CONTRADICTED" if n > sec else "CONFIRMED"
        if n > sec:
            v["note"] = "documented always-secret, observed clear in " + ", ".join(clear_ctx)
    elif doc == "never":
        v["status"] = "CONTRADICTED" if sec else "CONFIRMED"
        if sec:
            v["note"] = "documented NeverSecret, observed secret in " + ", ".join(secret_ctx)
    elif doc == "conditional":
        v["status"] = "CONFIRMED"
        v["note"] = ("secret in " + ", ".join(secret_ctx)) if sec else "clear so far (condition not triggered in: %s)" % ", ".join(clear_ctx)
        if not sec:
            v["verified"] = False
    else:
        v["status"] = "UNDOCUMENTED-SECRET" if sec else "CONFIRMED"
        if sec:
            v["note"] = "no secrecy annotation, observed secret in " + ", ".join(secret_ctx)
    return v


def _fmt_counts(c, slot):
    n, s = c[slot], c[slot + 1]
    if not n:
        return ""
    return "%d/%d" % (s, n)


def _observed_summary(row):
    """Aggregate a row: per slot, positions observed secret."""
    out = {}
    for i, name in enumerate(SLOT_NAMES):
        seen = sum(1 for c in row.values() if c[i * 2])
        if not seen:
            continue
        sec = sorted(p for p, c in row.items() if c[i * 2 + 1])
        out[name] = {"samples": max(c[i * 2] for c in row.values()), "secretPositions": sec}
    return out


# ------------------------------------------------------------------ build
def build(dump):
    flag_counts = collections.defaultdict(collections.Counter)
    flag_values = collections.defaultdict(collections.Counter)
    present = dump.present_functions()

    def note_flags(kind, node):
        for k, v in node_flags(node).items():
            flag_counts[k][kind] += 1
            if not isinstance(v, bool):
                flag_values[k][json.dumps(v)] += 1

    funcs, events, structs, widgets = {}, {}, {}, {}
    for sys in dump.doc_systems():
        ns = sys.get("Namespace")
        is_widget = sys.get("Type") == "ScriptObject"
        for f in as_list(sys.get("Functions")):
            name = f.get("Name")
            if not name:
                continue
            kind = "widgetMethod" if is_widget else "function"
            note_flags(kind, f)
            for a in as_list(f.get("Arguments")):
                note_flags("argument", a)
            for r in as_list(f.get("Returns")):
                note_flags("return", r)
            pc = classify_parent(f)
            rets = [{"name": r.get("Name"), "type": r.get("Type"), "secrecy": classify_value(r, pc)}
                    for r in as_list(f.get("Returns"))]
            args = [{"name": a.get("Name"), "type": a.get("Type"),
                     "secrecy": classify_value(a, "unspecified")} for a in as_list(f.get("Arguments"))]
            entry = {
                "secrecy": pc if rets or pc != "unspecified" else "unspecified",
                "conditions": conditions(f),
                "secretArguments": f.get("SecretArguments"),
                "returns": rets, "arguments": args,
                "restrictions": sorted(k for k in f if k in RESTRICT_KEYS or str(k).startswith(("Requires", "Require"))),
                "flags": node_flags(f),
            }
            if any(r["secrecy"] in ("always", "conditional") for r in rets) and entry["secrecy"] in ("unspecified", "never"):
                entry["secrecy"] = "partial"  # some returns flagged individually
            if is_widget:
                widgets["%s:%s" % (sys.get("Name"), name)] = entry
            else:
                full = (ns + "." + name) if ns else name
                entry["present"] = full in present or bool(f.get("_present"))
                funcs[full] = entry
        for e in as_list(sys.get("Events")):
            lit = e.get("LiteralName")
            if not lit:
                continue
            note_flags("event", e)
            for p in as_list(e.get("Payload")):
                note_flags("payload", p)
            pc = classify_parent(e)
            payload = [{"name": p.get("Name"), "type": p.get("Type"), "secrecy": classify_value(p, pc)}
                       for p in as_list(e.get("Payload"))]
            if pc == "unspecified" and any(p["secrecy"] in ("always", "conditional") for p in payload):
                pc = "partial"
            events[lit] = {"secrecy": pc, "conditions": conditions(e), "payload": payload,
                           "restrictions": sorted(k for k in e if k in RESTRICT_KEYS), "flags": node_flags(e)}
    for name, t in dump.doc_tables().items():
        note_flags("table", t)
        fields = []
        for fl in as_list(t.get("Fields")):
            note_flags("structField", fl)
            if "EnumValue" in fl:
                continue
            fields.append({"name": fl.get("Name"), "type": fl.get("Type"), "secrecy": classify_value(fl)})
        if fields:
            structs[name] = {"fields": fields}

    obs, obs_sources, aggregated = observations(dump)
    findings = []

    def attach(entry, key, slots_label):
        row = obs.get(key)
        if not row:
            return
        entry["observed"] = {str(p): c for p, c in sorted(row.items())}
        entry["observedSummary"] = _observed_summary(row)
        doc_sec = {i + 1: x["secrecy"] for i, x in enumerate(entry.get(slots_label) or [])}
        for pos, c in row.items():
            if c[1] + c[3] + c[5] and doc_sec.get(pos, entry.get("secrecy")) in ("never", "unspecified"):
                findings.append({"key": key, "position": pos, "issue": "observed secret but documented %s"
                                 % doc_sec.get(pos, entry.get("secrecy")), "counts": c})
            if doc_sec.get(pos) == "always" and (c[0] + c[2] + c[4]) and not (c[1] + c[3] + c[5]):
                findings.append({"key": key, "position": pos, "issue": "documented always-secret but never observed secret",
                                 "counts": c})

    for name, entry in funcs.items():
        attach(entry, "api:" + name, "returns")
    for name, entry in events.items():
        attach(entry, "event:" + name, "payload")
    ctx_all = dict(getattr(observations, "ctx", {}) or {})
    for key, row in obs.items():
        if key not in ctx_all:
            ctx_all[key] = _ctx_from_slots(row)

    def verify_entry(entry, key, slots_label):
        slots = entry.get(slots_label) or []
        buckets = ctx_all.get(key) or {}
        out = {}
        npos = max([len(slots)] + [p for p in buckets])
        for pos in range(1, npos + 1):
            doc = slots[pos - 1]["secrecy"] if pos <= len(slots) else entry.get("secrecy", "unspecified")
            if doc == "partial":
                doc = "unspecified"
            out[str(pos)] = verify_position(doc, buckets.get(pos))
            if pos <= len(slots):
                out[str(pos)]["name"] = slots[pos - 1].get("name")
        if not slots and not buckets:
            out["1"] = verify_position(entry.get("secrecy", "unspecified"), None)
        entry["verify"] = out

    for name, entry in funcs.items():
        verify_entry(entry, "api:" + name, "returns")
    for name, entry in events.items():
        verify_entry(entry, "event:" + name, "payload")
    field_verify = {}
    for key, per in ctx_all.items():
        if key.startswith("field:"):
            field_verify[key[6:]] = verify_position("unspecified", per.get(1))
    live = dump.db.get("secretsLive") or {}
    unmatched = {}
    for key, row in obs.items():
        kind, _, name = key.partition(":")
        if (kind == "api" and name in funcs) or (kind == "event" and name in events):
            continue
        unmatched[key] = {"observed": {str(p): c for p, c in sorted(row.items())}, "observedSummary": _observed_summary(row)}
        if kind == "field":
            sec = sum(c[1] + c[3] + c[5] for c in row.values())
            if sec:
                findings.append({"key": key, "position": 1, "issue": "struct field observed secret", "counts": row[1]})

    state = {}
    sct = dump.sections.get("secrets") or {}
    for k in ("outOfCombat", "inCombat", "inEncounter"):
        if isinstance(sct.get(k), dict):
            state[k] = sct[k]
    for k, res in (dump.sections.get("probe") or {}).items():
        if isinstance(res, dict) and isinstance(res.get("secretState"), dict):
            state.setdefault("probe:" + k, res["secretState"])
    sec_cvars = sorted(n for n in as_list(dump.db.get("cvarNames")) if isinstance(n, str)
                       and re.search(r"secret|restrict|lockdown", n, re.I))
    prim_names = ("issecretvalue", "issecrettable", "canaccessvalue", "canaccesssecrets", "canaccesstable",
                  "hasanysecretvalues", "scrubsecretvalues", "secretwrap", "dropsecretaccess", "issecure", "issecurevariable")
    sec_ns = sorted(n for n in present if re.match(r"C_(Secrets|RestrictedActions|CombatLog|Declassif)", n))
    secret_api_present = sorted(n for n in present if re.search(r"[Ss]ecret|Restrict", n))

    def count(d, key="secrecy"):
        return dict(collections.Counter(v[key] for v in d.values()))

    ret_counts = collections.Counter(r["secrecy"] for f in funcs.values() for r in f["returns"])
    pay_counts = collections.Counter(p["secrecy"] for e in events.values() for p in e["payload"])
    fld_counts = collections.Counter(fl["secrecy"] for s in structs.values() for fl in s["fields"])
    sa_counts = collections.Counter(str(f["secretArguments"]) for f in funcs.values() if f["secretArguments"])
    headline = {
        "build": dump.build_label(),
        "distinctFlags": len(flag_counts),
        "functions": {"documented": len(funcs), "bySecrecy": count(funcs),
                      "present": sum(1 for f in funcs.values() if f.get("present")),
                      "secretArguments": dict(sa_counts),
                      "restricted": sum(1 for f in funcs.values() if f["restrictions"])},
        "functionReturns": dict(ret_counts),
        "widgetMethods": {"documented": len(widgets), "bySecrecy": count(widgets)},
        "events": {"documented": len(events), "bySecrecy": count(events)},
        "eventPayloadFields": dict(pay_counts),
        "structFields": dict(fld_counts),
        "observations": {"keys": len(obs), "sources": obs_sources, "aggregatedByAddon": aggregated,
                         "keysWithSecret": sum(1 for r in obs.values() if any(c[1] + c[3] + c[5] for c in r.values())),
                         "findings": len(findings)},
    }
    return {
        "schema": 1,
        "headline": headline,
        "flags": {k: {"count": dict(v), "values": dict(flag_values.get(k, {}))} for k, v in sorted(flag_counts.items())},
        "aspects": aspect_names(dump),
        "primitivesPresent": {n: n in present for n in prim_names},
        "secretRelatedApiPresent": secret_api_present,
        "restrictionNamespaces": sec_ns,
        "secretRelatedCVars": sec_cvars,
        "state": state,
        "functions": funcs, "widgetMethods": widgets, "events": events, "structs": structs,
        "unmatchedObservations": unmatched,
        "findings": findings,
        "fieldVerify": field_verify,
        "liveContradictions": as_list(live.get("contradictions")),
        "sessions": (dump.db.get("secretsObs") or {}).get("_sessions") or {},
    }


# ------------------------------------------------------------------ helpers used by luals / mocks / apicheck
def effective(entry, pos, doc):
    """Verified class wins over the documented one: always | conditional | observed | clear | doc class."""
    v = (entry.get("verify") or {}).get(str(pos))
    if not v or not v.get("verified"):
        return doc
    e = v.get("effective")
    if e == "clear":
        return "clear"
    if doc in ("always", "conditional"):
        return e
    return "observed" if e in ("always", "conditional") else doc


def secret_return_index(smap):
    """function -> list of (position, secrecy, conditions) for returns that may be secret (verified data preferred)."""
    out = {}
    for name, f in smap["functions"].items():
        rs = []
        for i, r in enumerate(f["returns"]):
            cls = effective(f, i + 1, r["secrecy"])
            if cls in ("always", "conditional", "observed"):
                rs.append((i + 1, cls, f["conditions"]))
        obs = f.get("observedSummary") or {}
        for slot in obs.values():
            for p in slot["secretPositions"]:
                if not any(x[0] == p for x in rs):
                    rs.append((p, "observed", []))
        if rs:
            out[name] = sorted(rs)
    return out


def describe(secrecy, conds):
    if secrecy == "always":
        return "SECRET (always)"
    if secrecy == "conditional":
        return "SECRET when: " + (", ".join(conds) if conds else "ConditionalSecret")
    if secrecy == "observed":
        return "SECRET (observed at runtime, undocumented)"
    if secrecy == "never":
        return "never secret"
    return ""


# ------------------------------------------------------------------ markdown
def _md_obs(entry, pos):
    row = entry.get("observed") or {}
    c = row.get(str(pos))
    if not c:
        return "", "", ""
    return _fmt_counts(c, 0), _fmt_counts(c, 2), _fmt_counts(c, 4)


def to_markdown(smap, limit_unspecified=0):
    h = smap["headline"]
    L = ["# Forever secrets map", "",
         "Build %s. Generated by `fdump.py secrets` from the dump's APIDocumentation walk plus runtime observations." % h["build"],
         "", "Observed columns are `secret/seen` counts per position (return value or event payload field). "
         "Out = out of combat, In = in combat, Enc = in an encounter. Empty = never observed.", "",
         "## Headline", ""]
    f = h["functions"]
    L += ["- distinct secrecy/restriction flags in the docs: **%d**" % h["distinctFlags"],
          "- functions documented: %d (present in client: %d); by secrecy: %s" % (f["documented"], f["present"], f["bySecrecy"]),
          "- function returns by secrecy: %s" % h["functionReturns"],
          "- SecretArguments: %s" % f["secretArguments"],
          "- functions with restrictions (HasRestrictions / protected / Requires*): %d" % f["restricted"],
          "- widget methods: %d; by secrecy: %s" % (h["widgetMethods"]["documented"], h["widgetMethods"]["bySecrecy"]),
          "- events: %d; by secrecy: %s; payload fields: %s" % (h["events"]["documented"], h["events"]["bySecrecy"],
                                                                 h["eventPayloadFields"]),
          "- struct fields: %s" % h["structFields"],
          "- runtime observations: %s" % h["observations"], ""]
    L += ["## Secret-related API and state", "",
          "- primitives present: " + ", ".join("%s=%s" % (k, "yes" if v else "no") for k, v in smap["primitivesPresent"].items()),
          "- restriction namespaces/functions: " + (", ".join(smap["restrictionNamespaces"]) or "none"),
          "- secret-related CVars: " + (", ".join(smap["secretRelatedCVars"]) or "none"), ""]
    for k, st in smap["state"].items():
        L.append("- state `%s`: combatLogRestricted=%s, restrictions=%s" % (
            k, json.dumps(st.get("combatLogRestricted"))[:80],
            ", ".join("%s=%s" % (n, (as_list((v or {}).get("values")) or ["?"])[0]) for n, v in sorted((st.get("restrictions") or {}).items()))))
    if not smap["state"]:
        L.append("- no runtime state captured in this dump (run `/fdump secrets` or FD_Logs with addon v2.1)")
    L += ["", "## Flags found in the documentation", "", "| flag | where (count) | values |", "|---|---|---|"]
    for k, v in smap["flags"].items():
        L.append("| %s | %s | %s |" % (k, ", ".join("%s %d" % kv for kv in sorted(v["count"].items())),
                                      ", ".join("%s×%d" % kv for kv in sorted(v["values"].items()))[:120]))
    if smap["aspects"]:
        L += ["", "Aspect values (SecretReturnsForAspect / SecretArgumentsAddAspect): " +
              ", ".join("%s=%s" % kv for kv in sorted(smap["aspects"].items(), key=lambda kv: int(kv[0])))]

    def fn_rows(pred, title):
        rows = []
        for name, e in sorted(smap["functions"].items()):
            if not pred(e):
                continue
            rets = e["returns"] or [{"name": "-", "secrecy": e["secrecy"]}]
            for i, r in enumerate(rets, 1):
                o, c, en = _md_obs(e, i)
                rows.append("| %s | %s | %s | %s | %s | %s | %s |" % (
                    name if i == 1 else "", r["name"], r["secrecy"], o, c, en,
                    ("; ".join(e["conditions"]) + ("" if e.get("present") else " NOT PRESENT")) if i == 1 else ""))
        if rows:
            L.extend(["", "## " + title, "", "| API | return | documented | Out | In | Enc | notes |", "|---|---|---|---|---|---|---|"])
            L.extend(rows)

    fn_rows(lambda e: e["secrecy"] == "always", "Functions documented secret (SecretReturns / SecretValue: treat as always secret for addon code; observations show when it really applies)")
    fn_rows(lambda e: e["secrecy"] in ("conditional", "partial"), "Functions: conditionally secret")
    fn_rows(lambda e: e.get("observed") and e["secrecy"] not in ("always", "conditional", "partial"),
            "Functions: observed at runtime (other)")
    na = sorted(n for n, e in smap["functions"].items() if e["secretArguments"] == "NotAllowed")
    L += ["", "## Functions that reject secret arguments (SecretArguments=NotAllowed, %d)" % len(na), "", ", ".join(na)]
    L += ["", "## Events with secret payloads", "", "| event | field | documented | Out | In | Enc | notes |",
          "|---|---|---|---|---|---|---|"]
    for name, e in sorted(smap["events"].items()):
        if e["secrecy"] in ("unspecified", "never") and not e.get("observed"):
            continue
        pl = e["payload"] or [{"name": "-", "secrecy": e["secrecy"]}]
        for i, p in enumerate(pl, 1):
            o, c, en = _md_obs(e, i)
            if e["secrecy"] in ("unspecified", "never") and not (o or c or en):
                continue
            L.append("| %s | %s | %s | %s | %s | %s | %s |" % (name if i == 1 else "", p["name"], p["secrecy"], o, c, en,
                                                               "; ".join(e["conditions"]) if i == 1 else ""))
    L += ["", "## Struct fields documented secret", "", "| struct | field | documented |", "|---|---|---|"]
    for name, s in sorted(smap["structs"].items()):
        for fl in s["fields"]:
            if fl["secrecy"] in ("always", "conditional"):
                L.append("| %s | %s | %s |" % (name, fl["name"], fl["secrecy"]))
    if smap["unmatchedObservations"]:
        L += ["", "## Other runtime observations (undocumented API/events, struct fields)", "",
              "| key | pos | Out | In | Enc |", "|---|---|---|---|---|"]
        for k, v in sorted(smap["unmatchedObservations"].items()):
            for p, c in v["observed"].items():
                L.append("| %s | %s | %s | %s | %s |" % (k, p, _fmt_counts(c, 0), _fmt_counts(c, 2), _fmt_counts(c, 4)))
    L += ["", "## Findings (documentation vs observation)", ""]
    if smap["findings"]:
        for fd in smap["findings"]:
            L.append("- `%s` #%s: %s (%s)" % (fd["key"], fd["position"], fd["issue"], fd["counts"]))
    else:
        L.append("- none (no runtime observations contradict the documentation, or none were captured)")
    return "\n".join(L) + "\n"


# ------------------------------------------------------------------ verify report
def verify_report(smap):
    rows = []
    for kind, coll in (("api", smap["functions"]), ("event", smap["events"])):
        for name, e in coll.items():
            for pos, v in (e.get("verify") or {}).items():
                rows.append(dict(v, key="%s:%s" % (kind, name), kind=kind, pos=int(pos), present=e.get("present", True)))
    for name, v in (smap.get("fieldVerify") or {}).items():
        rows.append(dict(v, key="field:" + name, kind="field", pos=1, present=True))
    by_status = collections.Counter(r["status"] for r in rows)

    def cov(pred):
        sel = [r for r in rows if pred(r)]
        obs = [r for r in sel if r["status"] != "UNOBSERVED"]
        return {"positions": len(sel), "observed": len(obs), "percent": round(100.0 * len(obs) / len(sel), 2) if sel else 0.0}

    secretish = ("always", "conditional", "never")
    coverage = {
        "all": cov(lambda r: r["kind"] in ("api", "event")),
        "documentedSecretOrNever": cov(lambda r: r["doc"] in secretish),
        "functionReturnsSecret": cov(lambda r: r["kind"] == "api" and r["doc"] in ("always", "conditional")),
        "eventPayloadSecret": cov(lambda r: r["kind"] == "event" and r["doc"] in ("always", "conditional")),
        "verifiedInCombat": cov(lambda r: r["doc"] in ("always", "conditional") and r["kind"] in ("api", "event")
                                and (r["status"] == "UNOBSERVED" or any(c.split("/")[0] in ("combat", "enc")
                                                                        for c in r.get("secretContexts", []) + r.get("clearContexts", [])))),
    }
    # verifiedInCombat: observed rows that include a combat/encounter context
    sel = [r for r in rows if r["doc"] in ("always", "conditional") and r["kind"] in ("api", "event")]
    inc = [r for r in sel if any(c.split("/")[0] in ("combat", "enc") for c in r.get("secretContexts", []) + r.get("clearContexts", []))]
    coverage["verifiedInCombat"] = {"positions": len(sel), "observed": len(inc),
                                    "percent": round(100.0 * len(inc) / len(sel), 2) if sel else 0.0}
    order = {s: i for i, s in enumerate(STATUS_ORDER)}
    rows.sort(key=lambda r: (order.get(r["status"], 9), r["key"], r["pos"]))
    return {"build": smap["headline"]["build"], "statusCounts": dict(by_status), "coverage": coverage,
            "liveContradictions": smap.get("liveContradictions") or [], "sessions": smap.get("sessions") or {},
            "rows": rows}


def verify_markdown(rep, max_rows=400):
    L = ["# Forever secrets VERIFY report", "",
         "Build %s. Documented secrecy (APIDocumentation) reconciled with live observations (issecretvalue per "
         "position, per context `state/instanceType/unit`)." % rep["build"], "",
         "- CONFIRMED: docs and observations agree (conditional + only clear so far is CONFIRMED but marked unverified)",
         "- **CONTRADICTED**: docs say secret but it was observed clear in that context, or NeverSecret observed secret",
         "- UNOBSERVED: no data yet",
         "- **UNDOCUMENTED-SECRET**: observed secret, no secrecy annotation", "",
         "## Summary", ""]
    for k in STATUS_ORDER:
        L.append("- %s: %d" % (k, rep["statusCounts"].get(k, 0)))
    L += ["", "## Coverage", "", "| scope | positions | observed | % |", "|---|---|---|---|"]
    for k, c in rep["coverage"].items():
        L.append("| %s | %d | %d | %.2f |" % (k, c["positions"], c["observed"], c["percent"]))
    if rep["sessions"]:
        L += ["", "Capture sessions: " + ", ".join("%s (sweep calls %s)" % (k, v.get("sweepCalls")) for k, v in sorted(rep["sessions"].items()))]

    def table(status, title, limit):
        sel = [r for r in rep["rows"] if r["status"] == status]
        L.extend(["", "## %s (%d)" % (title, len(sel)), ""])
        if not sel:
            L.append("none")
            return
        L.extend(["| key | pos | name | documented | samples | secret | clear | secret in | clear in | note |",
                  "|---|---|---|---|---|---|---|---|---|---|"])
        for r in sel[:limit]:
            L.append("| %s | %d | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                r["key"], r["pos"], r.get("name") or "", r["doc"], r.get("samples", ""), r.get("secret", ""), r.get("clear", ""),
                ", ".join(r.get("secretContexts", [])), ", ".join(r.get("clearContexts", [])), r.get("note", "")))
        if len(sel) > limit:
            L.append("| ... %d more in verify.json | | | | | | | | | |" % (len(sel) - limit))

    table("CONTRADICTED", "CONTRADICTED", max_rows)
    table("UNDOCUMENTED-SECRET", "UNDOCUMENTED-SECRET", max_rows)
    table("CONFIRMED", "CONFIRMED", max_rows)
    uno = [r for r in rep["rows"] if r["status"] == "UNOBSERVED" and r["doc"] in ("always", "conditional", "never")]
    L += ["", "## UNOBSERVED documented-secret/never positions (%d; all UNOBSERVED rows in verify.json)" % len(uno), ""]
    L.append(", ".join("%s#%d" % (r["key"], r["pos"]) for r in uno[:600]) + (" ..." if len(uno) > 600 else ""))
    lc = rep["liveContradictions"]
    L += ["", "## Contradictions detected live in game (%d)" % len(lc), ""]
    if lc:
        L += ["| key | pos | documented | observed | context | count | session | epoch |", "|---|---|---|---|---|---|---|---|"]
        for c in lc[:max_rows]:
            L.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % (c.get("key"), c.get("pos"), c.get("doc"), c.get("observed"),
                                                                 c.get("ctx"), c.get("count"), c.get("sid"), c.get("epoch")))
    else:
        L.append("none recorded")
    return "\n".join(L) + "\n"
