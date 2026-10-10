"""(6) Diff two dumps: functions, documented signatures/flags, events/payloads, enums, tables, constants,
CVars, widgets, templates, global strings, meta. Markdown + JSON."""
from .luasv import as_list


def _sig(f):
    def fields(lst):
        return [(a.get("Name"), a.get("Type"), a.get("InnerType"), bool(a.get("Nilable")), a.get("Default"))
                for a in as_list(lst)]
    flags = {k: f[k] for k in f if isinstance(k, str) and k not in ("Name", "Type", "Arguments", "Returns",
                                                                       "Documentation", "_present")
             and not isinstance(f[k], (dict, list))}
    return {"args": fields(f.get("Arguments")), "returns": fields(f.get("Returns")), "flags": flags}


def _set_diff(a, b):
    a, b = set(a), set(b)
    return {"added": sorted(b - a), "removed": sorted(a - b)}


def _cvars(d):
    out = {}
    for cat, rows in (d.db.get("cvars") or {}).items():
        if isinstance(rows, dict):
            for name, row in rows.items():
                if isinstance(row, dict):
                    out[name] = row.get("default")
    if not out:
        for n in as_list(d.db.get("cvarNames")):
            out[n] = None
    return out


def diff(a, b):
    r = {"from": a.build_label(), "to": b.build_label()}
    r["meta"] = {k: {"from": a.meta().get(k), "to": b.meta().get(k)}
                 for k in ("version", "build", "toc", "projectID", "projectName", "scriptsDisallowedForBeta", "locale")
                 if a.meta().get(k) != b.meta().get(k)}
    r["functions"] = _set_diff(a.present_functions(), b.present_functions())
    da, db_ = a.doc_functions(), b.doc_functions()
    r["documentedFunctions"] = _set_diff(da, db_)
    changed = {}
    for name in sorted(set(da) & set(db_)):
        sa, sb = _sig(da[name][1]), _sig(db_[name][1])
        if sa != sb:
            ch = {}
            for k in ("args", "returns", "flags"):
                if sa[k] != sb[k]:
                    ch[k] = {"from": sa[k], "to": sb[k]}
            changed[name] = ch
    r["signatureChanges"] = changed
    ea, eb = a.doc_events(), b.doc_events()
    r["events"] = _set_diff(set(a.events()) | set(ea), set(b.events()) | set(eb))
    payload = {}
    for ev in sorted(set(ea) & set(eb)):
        pa = [(p.get("Name"), p.get("Type"), bool(p.get("Nilable"))) for p in as_list(ea[ev][1].get("Payload"))]
        pb = [(p.get("Name"), p.get("Type"), bool(p.get("Nilable"))) for p in as_list(eb[ev][1].get("Payload"))]
        if pa != pb:
            payload[ev] = {"from": pa, "to": pb}
    r["eventPayloadChanges"] = payload
    ena, enb = a.runtime_enum(), b.runtime_enum()
    r["enums"] = _set_diff(ena, enb)
    enum_changes = {}
    for en in sorted(set(ena) & set(enb)):
        x, y = ena[en], enb[en]
        if isinstance(x, dict) and isinstance(y, dict) and x != y:
            enum_changes[en] = {"added": {k: y[k] for k in y if k not in x},
                                "removed": sorted(k for k in x if k not in y),
                                "changed": {k: [x[k], y[k]] for k in x if k in y and x[k] != y[k]}}
    r["enumChanges"] = enum_changes
    ta, tb = a.doc_tables(), b.doc_tables()
    r["documentedTables"] = _set_diff(ta, tb)
    tch = {}
    for t in sorted(set(ta) & set(tb)):
        fa = [(f.get("Name"), f.get("Type"), bool(f.get("Nilable")), f.get("EnumValue")) for f in as_list(ta[t].get("Fields"))]
        fb = [(f.get("Name"), f.get("Type"), bool(f.get("Nilable")), f.get("EnumValue")) for f in as_list(tb[t].get("Fields"))]
        if fa != fb:
            tch[t] = {"added": sorted(set(x[0] for x in fb) - set(x[0] for x in fa)),
                      "removed": sorted(set(x[0] for x in fa) - set(x[0] for x in fb))}
    r["tableChanges"] = tch
    ca, cb = a.constants(), b.constants()
    r["constants"] = dict(_set_diff(ca, cb), changed={k: [ca[k], cb[k]] for k in set(ca) & set(cb) if ca[k] != cb[k]})
    va, vb = _cvars(a), _cvars(b)
    r["cvars"] = dict(_set_diff(va, vb), defaultChanged={k: [va[k], vb[k]] for k in set(va) & set(vb) if va[k] != vb[k]})
    wa, wb = a.widget_types(), b.widget_types()
    r["widgetTypes"] = _set_diff(wa, wb)
    r["widgetMethods"] = {}
    for t in sorted(set(wa) & set(wb)):
        d = _set_diff(as_list(wa[t].get("methods")), as_list(wb[t].get("methods")))
        if d["added"] or d["removed"]:
            r["widgetMethods"][t] = d
    tpa = (a.sections.get("templates") or {}).get("templates") or {}
    tpb = (b.sections.get("templates") or {}).get("templates") or {}
    r["templates"] = _set_diff(tpa, tpb)
    sa, sb = a.strings, b.strings
    texts = not (getattr(a, "strings_compact", False) or getattr(b, "strings_compact", False))  # compact = names only
    r["globalStrings"] = dict(_set_diff(sa, sb), changed=sorted(k for k in set(sa) & set(sb) if texts and sa[k] != sb[k]))
    return r


def _count(d):
    return len(d.get("added", [])) + len(d.get("removed", []))


def markdown(r, max_items=200):
    out = ["# ForeverDump diff", "", "From **%s** to **%s**" % (r["from"], r["to"]), ""]
    if r["meta"]:
        out.append("## Meta")
        for k, v in r["meta"].items():
            out.append("- %s: `%s` -> `%s`" % (k, v["from"], v["to"]))
        out.append("")

    def section(title, d, key_added="added", key_removed="removed"):
        if not (d.get(key_added) or d.get(key_removed)):
            return
        out.append("## %s (+%d / -%d)" % (title, len(d.get(key_added, [])), len(d.get(key_removed, []))))
        for x in list(d.get(key_added, []))[:max_items]:
            out.append("- `+ %s`" % x)
        for x in list(d.get(key_removed, []))[:max_items]:
            out.append("- `- %s`" % x)
        out.append("")

    section("Functions present", r["functions"])
    section("Documented functions", r["documentedFunctions"])
    if r["signatureChanges"]:
        out.append("## Signature / flag changes (%d)" % len(r["signatureChanges"]))
        for name, ch in list(r["signatureChanges"].items())[:max_items]:
            out.append("- `%s`: %s" % (name, "; ".join("%s %s -> %s" % (k, v["from"], v["to"]) for k, v in ch.items())))
        out.append("")
    section("Events", r["events"])
    if r["eventPayloadChanges"]:
        out.append("## Event payload changes (%d)" % len(r["eventPayloadChanges"]))
        for ev, ch in list(r["eventPayloadChanges"].items())[:max_items]:
            out.append("- `%s`: %s -> %s" % (ev, ch["from"], ch["to"]))
        out.append("")
    section("Enums", r["enums"])
    if r["enumChanges"]:
        out.append("## Enum value changes (%d)" % len(r["enumChanges"]))
        for en, ch in list(r["enumChanges"].items())[:max_items]:
            out.append("- `Enum.%s`: +%s -%s ~%s" % (en, ch["added"], ch["removed"], ch["changed"]))
        out.append("")
    section("Documented tables", r["documentedTables"])
    section("Constants", r["constants"])
    if r["constants"].get("changed"):
        out.append("Changed constants: " + ", ".join("`%s` %s->%s" % (k, v[0], v[1]) for k, v in list(r["constants"]["changed"].items())[:max_items]))
        out.append("")
    section("CVars", r["cvars"])
    if r["cvars"].get("defaultChanged"):
        out.append("CVar defaults changed: " + ", ".join("`%s` %s->%s" % (k, v[0], v[1]) for k, v in list(r["cvars"]["defaultChanged"].items())[:max_items]))
        out.append("")
    section("Widget types", r["widgetTypes"])
    for t, d in r["widgetMethods"].items():
        section("Widget %s methods" % t, d)
    section("XML templates", r["templates"])
    section("Global strings", r["globalStrings"])
    if r["globalStrings"].get("changed"):
        out.append("%d global strings changed text." % len(r["globalStrings"]["changed"]))
    summary = {k: _count(v) for k, v in r.items() if isinstance(v, dict) and ("added" in v or "removed" in v)}
    out.insert(4, "Summary: " + ", ".join("%s %d" % (k, v) for k, v in summary.items() if v) + "\n")
    return "\n".join(out) + "\n"
