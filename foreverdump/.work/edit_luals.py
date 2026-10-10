p='/workspace/foreverdump/tools/fdump/luals.py'; s=open(p).read()
a='''def func_stub(full, f, tm, present=True, sep="."):
    lines = doc_lines(f)
    if not present:'''
b='''SMAP = {"functions": {}, "events": {}, "structs": {}}
SECRET_ARG_TEXT = {
    "NotAllowed": "passing a secret value as an argument raises an error",
    "AllowedWhenUntainted": "only secure (untainted) code may pass secret values; addon code passing one errors",
    "AllowedWhenTainted": "addon code may pass secret values",
}


def secret_lines(full):
    e = SMAP["functions"].get(full)
    if not e:
        return []
    out = []
    sec = e["secrecy"]
    if sec in ("always", "conditional", "partial"):
        out.append("--- **Secret returns** (%s)%s. Guard with `issecretvalue(v)` before arithmetic, comparison, "
                   "concatenation or using it as a table key." % (sec, (": " + ", ".join(e["conditions"])) if e["conditions"] else ""))
    obs = e.get("observedSummary") or {}
    if obs:
        out.append("--- Observed: " + "; ".join("%s secret at %s (%d samples)" % (k, v["secretPositions"] or "none", v["samples"])
                                                for k, v in obs.items()))
    if e.get("secretArguments") in SECRET_ARG_TEXT:
        out.append("--- Secret arguments: %s (%s)." % (e["secretArguments"], SECRET_ARG_TEXT[e["secretArguments"]]))
    if e.get("restrictions"):
        out.append("--- Restrictions: " + ", ".join(e["restrictions"]))
    return out


def ret_secret_suffix(full, idx):
    e = SMAP["functions"].get(full)
    if not e or idx >= len(e["returns"]):
        return ""
    r = e["returns"][idx]
    obs = e.get("observedSummary") or {}
    seen = any(idx + 1 in v["secretPositions"] for v in obs.values())
    if r["secrecy"] == "always":
        return " # SECRET (always)"
    if r["secrecy"] == "conditional":
        return " # SECRET when: %s" % (", ".join(e["conditions"]) or "ConditionalSecret")
    if seen:
        return " # SECRET (observed at runtime)"
    if r["secrecy"] == "never":
        return " # never secret"
    return ""


def func_stub(full, f, tm, present=True, sep="."):
    lines = doc_lines(f) + secret_lines(full)
    if not present:'''
assert a in s; s=s.replace(a,b)
a='''    for r in as_list(f.get("Returns")):
        t = tm.of(r)
        if r.get("Nilable"):
            t += "?"
        if r.get("StrideIndex"):
            lines.append("---@return %s ... %s" % (t, safe_name(r.get("Name", "ret"))))
        else:
            lines.append("---@return %s %s" % (t, safe_name(r.get("Name", "ret"))))'''
b='''    for ri, r in enumerate(as_list(f.get("Returns"))):
        t = tm.of(r)
        if r.get("Nilable"):
            t += "?"
        sfx = ret_secret_suffix(full, ri)
        if r.get("StrideIndex"):
            lines.append("---@return %s ... %s%s" % (t, safe_name(r.get("Name", "ret")), sfx))
        else:
            lines.append("---@return %s %s%s" % (t, safe_name(r.get("Name", "ret")), sfx))'''
assert a in s; s=s.replace(a,b)
a='''def generate(dump, out):
    write.label = dump.build_label()'''
b='''def generate(dump, out):
    from . import secrets as secretsmod
    global SMAP
    SMAP = secretsmod.build(dump)
    write.label = dump.build_label()'''
assert a in s; s=s.replace(a,b)
a='''        for fld in as_list(t.get("Fields")):
            opt = "?" if fld.get("Nilable") else ""
            lines.append("---@field %s%s %s" % (fld.get("Name"), opt, tm.of(fld)))'''
b='''        for fld in as_list(t.get("Fields")):
            opt = "?" if fld.get("Nilable") else ""
            cls = ("always" if fld.get("SecretValue") else "never" if fld.get("NeverSecret")
                   else "conditional" if fld.get("ConditionalSecret") else "")
            sfx = {"always": " # SECRET (always)", "conditional": " # SECRET (conditional)", "never": " # never secret"}.get(cls, "")
            lines.append("---@field %s%s %s%s" % (fld.get("Name"), opt, tm.of(fld), sfx))'''
assert a in s; s=s.replace(a,b)
a='''        if ev in evdocs:
            payload = ", ".join("%s: %s" % (p.get("Name"), tm.of(p)) for p in as_list(evdocs[ev][1].get("Payload")))
        lines.append('---| "%s" # %s' % (ev, payload))'''
b='''        se = SMAP["events"].get(ev) or {}
        sec_pl = {p["name"]: p["secrecy"] for p in se.get("payload", [])}
        if ev in evdocs:
            payload = ", ".join("%s: %s%s" % (p.get("Name"), tm.of(p), {"always": " [SECRET]", "conditional": " [secret?]"}.get(
                sec_pl.get(p.get("Name")), "")) for p in as_list(evdocs[ev][1].get("Payload")))
        obs = se.get("observedSummary") or {}
        if obs:
            payload += " (observed secret positions: %s)" % "; ".join("%s %s" % (k, v["secretPositions"]) for k, v in obs.items())
        if se.get("conditions"):
            payload += " {%s}" % ", ".join(se["conditions"])
        lines.append('---| "%s" # %s' % (ev, payload))'''
assert a in s; s=s.replace(a,b)
open(p,'w').write(s)
print("edited")
