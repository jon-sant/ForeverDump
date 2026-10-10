"""v2.2 report renderers: operations matrix (OPS.md), workarounds lab (LAB.md + porting patterns), combat probe set
(COMBAT-SECRETS.md + combat.json), unit token survey (UNIT-TOKENS.md + tokens.json), spell knowledge
(KNOWLEDGE.md + knowledge.json). Codes: N nil, S secret, T container with secrets, K container clear, C clear,
E error; a trailing * marks mixed observations (dominant code shown)."""
import collections

from .dump import as_list

CODE_NAME = {"N": "nil", "S": "secret", "T": "container(secret)", "K": "container(clear)", "C": "clear", "E": "error", "-": "-"}
CTX_ORDER = ["ooc", "restricted", "combat", "enc"]
CTX_LABEL = {"ooc": "out of combat", "restricted": "restriction active", "combat": "in combat", "enc": "encounter"}


def kv(x):
    """items of a Lua table that the SV parser may have turned into a list (1-based)"""
    if isinstance(x, dict):
        return list(x.items())
    if isinstance(x, list):
        return [(i + 1, v) for i, v in enumerate(x) if v is not None]
    return []


def dominant(counts):
    if not isinstance(counts, dict):
        return "-"
    nums = {k: v for k, v in counts.items() if isinstance(v, (int, float))}
    if not nums:
        return "-"
    best = max(sorted(nums), key=lambda k: nums[k])
    return str(best) + ("*" if sum(nums.values()) > nums[best] else "")   # count-valued fields (powerCost.n) have numeric keys


def _ctxs(d):
    return [c for c in CTX_ORDER if c in d] + sorted(c for c in d if c not in CTX_ORDER)


# ------------------------------------------------------------------ operations matrix
def ops(dump):
    rows = []
    for rec in as_list(dump.log.get("controls")):
        if not isinstance(rec, dict) or not isinstance(rec.get("ops"), dict):
            continue
        ctx = "%s/%s" % (rec.get("ctx", "?"), rec.get("execution", "addon"))
        for value, res in sorted(rec["ops"].items()):
            if not isinstance(res, dict):
                continue
            row = {"ctx": ctx, "value": value, "state": res.get("state"), "ops": {}}
            for op, e in res.items():
                if isinstance(e, dict) and "ok" in e:
                    row["ops"][op] = {"ok": e.get("ok"), "resultSecret": e.get("resultSecret"), "err": e.get("err"),
                                      "numericString": e.get("numericString"), "tonumberNil": e.get("tonumberNil"),
                                      "getTextSecret": e.get("getTextSecret"), "getValueSecret": e.get("getValueSecret")}
            rows.append(row)
    return rows


def ops_markdown(rows):
    out = ["# What you can do with a secret (operations matrix)", "",
           "Captured from addon code (not chat /run, which is force-tainted: `ForceTaint_Strong`). Only booleans and error",
           "texts are stored; never the value. `ok/S` = succeeded and the result is secret.", ""]
    if not rows:
        return "\n".join(out + ["_no controls records in this dump (v2.2 FD_Logs captures them automatically)_", ""])
    allops = sorted({op for r in rows for op in r["ops"]})
    out.append("| context | value | state | " + " | ".join(allops) + " |")
    out.append("|---|---|---|" + "---|" * len(allops))
    for r in rows:
        cells = []
        for op in allops:
            e = r["ops"].get(op)
            if not e:
                cells.append("")
            elif e["ok"]:
                cells.append("ok" + ("/S" if e.get("resultSecret") else "") + (" (tonumber->nil)" if e.get("tonumberNil") else ""))
            else:
                cells.append("**err**")
        out.append("| %s | %s | %s | %s |" % (r["ctx"], r["value"], r.get("state") or "", " | ".join(cells)))
    errs = collections.OrderedDict()
    for r in rows:
        for op, e in r["ops"].items():
            if e.get("err"):
                errs.setdefault(e["err"], set()).add(op)
    if errs:
        out += ["", "## Error texts", ""] + ["- `%s` (%s)" % (k, ", ".join(sorted(v))) for k, v in errs.items()]
    return "\n".join(out) + "\n"


# ------------------------------------------------------------------ lab
def lab(dump):
    items = collections.OrderedDict()
    for rec in as_list(dump.log.get("lab")):
        if not isinstance(rec, dict):
            continue
        ctx = rec.get("ctx", "?")
        for it in as_list(rec.get("items")):
            key = it.get("id")
            e = items.setdefault(key, {"id": key, "group": it.get("group"), "approach": it.get("approach"), "ctx": {}})
            e["ctx"][ctx] = {k: v for k, v in it.items() if k not in ("group", "approach", "id")}
    return list(items.values())


PATTERNS = [
    ("Health / power bars", "statusbar", "StatusBar:SetMinMaxValues(0, UnitHealthMax) + SetValue(UnitHealth(unit)) - the engine draws it; never compare or do math in Lua."),
    ("Numbers as text", "fontstring-settext", "FontString:SetText(secret) / SetFormattedText - display is allowed; GetText() returns a secret, so do not read it back."),
    ("Percent / colour", "healthpercent-curve", "UnitHealthPercent(unit, true, curve) or a colour curve -> pass the (secret) result straight to SetAlpha/SetVertexColor."),
    ("Cooldowns", "cooldown-duration", "Cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(id)); NeverSecret fields (isEnabled/isActive/isOnGCD) for logic."),
    ("Timers / cast bars", "duration-methods", "Duration objects: StatusBar:SetTimerDuration(duration) for bars; duration methods return secrets under restriction."),
    ("Unit comparisons", "compare-units", "Check C_Secrets.CanCompareUnitTokens first; UnitIsUnit may return a secret boolean under restriction."),
    ("Logic that needs numbers", "neighbour", "Use the clear neighbours (UnitHealthMax, UnitIsDeadOrGhost, UnitAffectingCombat, event arrival) and cache values while readable."),
]


def _lab_cell(c):
    if not c:
        return ""
    if c.get("available") is False:
        return "absent"
    s = "ok" if c.get("ok") else "err"
    if c.get("outputSecret") is True:
        s += ", output secret"
    elif c.get("outputSecret") is False:
        s += ", output clear"
    return s


def lab_markdown(items):
    out = ["# Workarounds lab - sanctioned paths for secret values", "",
           "Boundary diagnostics only (no side-channel extraction). Every API/method was checked against the 70245 docs first.", ""]
    if not items:
        out.append("_no lab records in this dump (v2.2 FD_Logs runs the lab automatically, in and out of combat)_")
    else:
        out += ["| approach | group | out of combat | in combat | notes |", "|---|---|---|---|---|"]
        for it in items:
            o, c = it["ctx"].get("ooc"), it["ctx"].get("combat") or it["ctx"].get("enc")
            notes = []
            for cc in (o, c):
                if cc:
                    for k in ("err", "setErr", "setValueErr", "secretInputErr", "setAlphaErr"):
                        if cc.get(k):
                            notes.append("%s: %s" % (k, str(cc[k])[:80]))
                    if cc.get("absent"):
                        notes.append("absent: " + ", ".join(as_list(cc["absent"])))
            out.append("| %s | %s | %s | %s | %s |" % (it["approach"], it["group"], _lab_cell(o), _lab_cell(c), "; ".join(sorted(set(notes)))[:240]))
    out += ["", "## Porting patterns for secret values", "",
            "Generated from the lab results above plus the research report (secrets-research.md).", "",
            "| need | pattern | evidence (lab) |", "|---|---|---|"]
    byid = {it["id"]: it for it in items}
    for need, lid, text in PATTERNS:
        ev = byid.get(lid)
        evs = "; ".join("%s: %s" % (k, _lab_cell(v)) for k, v in sorted(ev["ctx"].items())) if ev else (
            "neighbour items" if lid == "neighbour" else "not measured yet")
        out.append("| %s | %s | %s |" % (need, text, evs))
    return "\n".join(out) + "\n"


# ------------------------------------------------------------------ combat probe set
ITEM_API = {"UnitIsUnit(u,player)": "UnitIsUnit", "CanCompareUnitTokens": "C_Secrets.CanCompareUnitTokens",
            "ShouldUnitIdentityBeSecret": "C_Secrets.ShouldUnitIdentityBeSecret"}


def _item_api(item):
    if ":" in item and item.split(":", 1)[0] in ("aura", "casting", "dispel"):
        kind, rest = item.split(":", 1)
        name = rest.split("[")[0].split("(")[0]
        if kind == "casting" or name in ("ShouldSpellAuraBeSecret", "GetSpellAuraSecrecy"):
            return "C_Secrets." + name
        return ("C_Spell." if kind == "dispel" else "C_UnitAuras.") + name
    return ITEM_API.get(item, item)


def _expect(inv, item, ret, field=None):
    if not inv:
        return None
    api = _item_api(item)
    pos = ret if isinstance(ret, int) else 1
    if not isinstance(ret, int) and ret is not None:
        e = inv.entry("api:" + api)
        if e:
            names = [s["name"] for s in e["slots"]]
            alias = {"startTimeMS": "startTimeMs", "endTimeMS": "endTimeMs", "texture": "textureID", "text": "displayName",
                     "isTradeSkill": "isTradeskill", "castID": "castID"}
            n = alias.get(ret, ret)
            pos = names.index(n) + 1 if n in names else 1
    x = inv.expected("api:" + api, pos, field)
    return x


def _mismatch(obs, exp):
    if not exp or obs in ("-", "E", "N") or obs.startswith("N"):
        return False
    o = obs.rstrip("*")
    cls = exp.get("class")
    if cls == "never" and o == "S":   # v2.2.22: a "T" struct is judged per field (f rows), not as a whole
        return True
    if cls == "always" and o == "C" and not exp.get("container"):
        return True
    return False


def combat(dump, inv=None):
    cp = dump.log.get("combatProbe") or {}
    cells = cp.get("cells") or {}
    matrix = collections.OrderedDict()   # item -> ret/field -> ucls -> ctx -> {obs, exp, mismatch}
    for ctx, byU in cells.items():
        for ucls, byI in (byU or {}).items():
            for item, c in (byI or {}).items():
                if not isinstance(c, dict):
                    continue
                for ret, counts in kv(c.get("r")):
                    exp = _expect(inv, item, ret)
                    obs = dominant(counts)
                    m = matrix.setdefault(item, collections.OrderedDict()).setdefault(str(ret), {}).setdefault(ucls, {})
                    m[ctx] = {"obs": obs, "counts": counts, "exp": exp and exp.get("class"), "tag": exp and exp.get("tag"),
                              "mismatch": _mismatch(obs, exp), "pred": c.get("p"), "doc": c.get("doc"), "hsv": c.get("hsv"),
                              "err": c.get("err")}
                for fld, counts in (c.get("f") or {}).items():
                    exp = _expect(inv, item, 1, fld)
                    obs = dominant(counts)
                    m = matrix.setdefault(item, collections.OrderedDict()).setdefault("." + fld, {}).setdefault(ucls, {})
                    m[ctx] = {"obs": obs, "counts": counts, "exp": exp and exp.get("class"), "tag": exp and exp.get("tag"),
                              "mismatch": _mismatch(obs, exp)}
    det = cp.get("det") or {}
    return {"matrix": matrix, "detectability": det, "timeLeft": cp.get("timeLeft") or {}, "durations": cp.get("durations") or {},
            "slotCounts": cp.get("slotCounts") or {}, "ops": cp.get("ops") or {}, "events": cp.get("events") or {},
            "absent": cp.get("absent") or {}, "runs": as_list(cp.get("runs")), "runCount": cp.get("runCount") or {},
            "dropped": cp.get("dropped")}


QUESTIONS = [("casting", "Is it casting/channelling?"), ("whichSpell", "Which spell?"), ("anyAura", "Any buff/debuff?"),
             ("myAura", "MY buff/debuff?"), ("whatAura", "WHAT aura?"), ("stacksDuration", "Stacks / duration?"),
             ("dispellable", "Dispellable?")]


def _det_answer(r):
    if not isinstance(r, dict):
        return "-"
    nums = {k: v for k, v in r.items() if k in ("yes", "partial", "no", "n/a")}
    if not nums:
        return "-"
    best = max(sorted(nums), key=lambda k: nums[k])
    mixed = len([k for k in nums if k != "n/a"]) > 1
    return best + ("*" if mixed else "")


def combat_markdown(res):
    out = ["# Combat secrets matrix", "",
           "Item x unit class x context. Cell = observed code (documented class in brackets); **bold** = mismatch with the",
           "70245 docs. Codes: N nil, S secret, T container w/ secrets, K container clear, C clear, E error, * mixed.", ""]
    m = res["matrix"]
    if not m:
        return "\n".join(out + ["_no combat probe data in this dump (v2.2 FD_Logs captures it automatically)_", ""])
    ctxs = sorted({ctx for item in m.values() for r in item.values() for u in r.values() for ctx in u},
                  key=lambda c: CTX_ORDER.index(c) if c in CTX_ORDER else 9)
    classes = sorted({u for item in m.values() for r in item.values() for u in r})
    mism = []
    # detectability first (one-glance answers)
    out += ["## Detectability (yes / partial / no / n/a per unit class x context)", ""]
    det = res["detectability"]
    dclasses = sorted({u for byU in det.values() for u in byU})
    for q, label in QUESTIONS:
        out.append("**%s**" % label)
        out.append("")
        out.append("| unit class | " + " | ".join(CTX_LABEL.get(c, c) for c in _ctxs(det)) + " | evidence (last) |")
        out.append("|---|" + "---|" * (len(_ctxs(det)) + 1))
        for u in dclasses:
            ev = ""
            cells = []
            for c in _ctxs(det):
                r = (det.get(c) or {}).get(u, {}).get(q)
                cells.append(_det_answer(r))
                if isinstance(r, dict) and r.get("ev"):
                    ev = r["ev"]
            if any(x != "-" for x in cells):
                out.append("| %s | %s | %s |" % (u, " | ".join(cells), ev[:100]))
        out.append("")
    out += ["## Matrix", ""]
    for item, rets in m.items():
        out.append("### %s" % item)
        out.append("")
        out.append("| return/field | unit class | " + " | ".join(CTX_LABEL.get(c, c) for c in ctxs) + " |")
        out.append("|---|---|" + "---|" * len(ctxs))
        for ret, byU in rets.items():
            for u in classes:
                if u not in byU:
                    continue
                cells = []
                for c in ctxs:
                    x = byU[u].get(c)
                    if not x:
                        cells.append("")
                        continue
                    s = "%s [%s]" % (x["obs"], x.get("exp") or "?")
                    if x.get("mismatch"):
                        s = "**%s**" % s
                        mism.append((item, ret, u, c, x["obs"], x.get("exp")))
                    cells.append(s)
                out.append("| %s | %s | %s |" % (ret, u, " | ".join(cells)))
        out.append("")
    if res["timeLeft"]:
        out += ["## Cast / channel time left", "",
                "Derived `endTimeMS - GetTime()*1000` vs the sanctioned duration object.", "",
                "| ctx / unit class | endTimeMS | derived | error | duration object | HasSecretValues | GetRemainingDuration |",
                "|---|---|---|---|---|---|---|"]
        for k, tl in sorted(res["timeLeft"].items()):
            d = tl.get("duration") or {}
            out.append("| %s | %s | %s | %s | %s | %s | %s |" % (k, tl.get("endTimeState"), "ok" if tl.get("derivedOk") else "blocked",
                                                              (tl.get("derivedErr") or "")[:70], d.get("state"), d.get("HasSecretValues"),
                                                              d.get("GetRemainingDuration")))
        out.append("")
    if res["ops"]:
        out += ["## Operations on representative secrets (per category)", "", "| ctx | category | state | " +
                " | ".join(["arith", "compare", "tostring", "concat", "format", "tableKey", "setText", "statusBar"]) + " |",
                "|---|---|---|" + "---|" * 8]
        for ctx, cats in sorted(res["ops"].items()):
            for cat, r in sorted(cats.items()):
                def cell(op):
                    e = r.get(op)
                    if not isinstance(e, dict):
                        return ""
                    return ("ok" + ("/S" if e.get("resultSecret") or e.get("getTextSecret") else "")) if e.get("ok") else "err"
                out.append("| %s | %s | %s | %s |" % (ctx, cat, r.get("state"), " | ".join(cell(o) for o in
                                                                                       ["arith", "compare", "tostring", "concat", "format", "tableKey", "setText", "statusBar"])))
        out.append("")
    if res["events"]:
        out += ["## Event payloads per unit class", "", "| ctx | unit class | event | n | arg codes | updateInfo fields |", "|---|---|---|---|---|---|"]
        for ctx, byU in sorted(res["events"].items()):
            for u, byE in sorted(byU.items()):
                for ev, e in sorted(byE.items()):
                    args = " ".join("%s:%s" % (k, dominant(v)) for k, v in sorted(kv(e.get("r")), key=lambda x: str(x[0])))
                    flds = " ".join("%s:%s" % (k, dominant(v)) for k, v in sorted((e.get("f") or {}).items()))[:200]
                    out.append("| %s | %s | %s | %s | %s | %s |" % (ctx, u, ev, e.get("n"), args, flds))
        out.append("")
    out += ["## Mismatches with the docs (%d)" % len(mism), ""]
    out += ["- %s %s / %s / %s: observed %s, documented %s" % x for x in mism] or ["none"]
    if res["absent"]:
        out += ["", "## Absent in this build", ""] + ["- %s (%s)" % kv for kv in sorted(res["absent"].items())]
    return "\n".join(out) + "\n"


def combat_json(res):
    """compact JSON for the guide (--combat): item -> ret -> class -> ctx -> {obs, exp, mismatch}"""
    m = {}
    for item, rets in res["matrix"].items():
        m[item] = {r: {u: {c: {k: v for k, v in x.items() if k in ("obs", "exp", "tag", "mismatch")} for c, x in byC.items()}
                       for u, byC in byU.items()} for r, byU in rets.items()}
    det = {c: {u: {q: _det_answer(r) for q, r in byQ.items()} for u, byQ in byU.items()} for c, byU in res["detectability"].items()}
    return {"version": 1, "matrix": m, "detectability": det, "timeLeft": res["timeLeft"], "absent": res["absent"],
            "runCount": res["runCount"]}


# ------------------------------------------------------------------ unit token survey
CHECKS = ["UnitExists", "UnitGUID", "UnitName", "UnitIsUnit(player)", "UnitIsUnit(target)", "UnitCanAttack", "UnitIsPlayer",
          "UnitHealth", "UnitHealthMax", "CanCompareUnitTokens", "ShouldUnitIdentityBeSecret"]


def tokens(dump):
    tk = dump.log.get("tokens") or {}
    fams = collections.OrderedDict()
    for ctx, rec in (tk.get("ctx") or {}).items():
        for fam, r in (rec.get("families") or {}).items():
            f = fams.setdefault(fam, {"family": fam, "ctx": {}})
            checks = {}
            for chk, b in (r.get("checks") or {}).items():
                checks[chk] = {split: dominant(c) for split, c in (b or {}).items()}
            f["ctx"][ctx] = {"tokens": r.get("tokens"), "exist": r.get("exist"), "notExist": r.get("notExist"),
                             "existSecret": r.get("existSecret"), "errors": r.get("errors"), "checks": checks}
    out = []
    for fam, f in fams.items():
        works, ident, vals = [], [], []
        for ctx in _ctxs(f["ctx"]):
            c = f["ctx"][ctx]
            ex = c["checks"]
            if c["exist"]:
                works.append("%s: %d/%d resolved" % (ctx, c["exist"], c["tokens"]))
            elif c["existSecret"]:
                works.append("%s: existence secret" % ctx)
            idc = {k: (ex.get(k) or {}).get("exist") for k in ("UnitGUID", "UnitName")}
            if any(v for v in idc.values()):
                sec = [k for k, v in idc.items() if v and v.rstrip("*") == "S"]
                ident.append("%s: %s" % (ctx, ("secret (" + ",".join(sec) + ")") if sec else "clear"))
            vc = {k: (ex.get(k) or {}).get("exist") for k in ("UnitHealth", "UnitHealthMax")}
            if any(v for v in vc.values()):
                sec = [k for k, v in vc.items() if v and v.rstrip("*") == "S"]
                vals.append("%s: %s" % (ctx, ("secret (" + ",".join(sec) + ")") if sec else "clear"))
        f["summary"] = {"works": "; ".join(works) or "no unit seen (token valid, nothing to resolve)",
                        "identitySecret": "; ".join(ident) or "-", "valuesSecret": "; ".join(vals) or "-"}
        out.append(f)
    return {"families": out, "absent": tk.get("absent") or {}}


def tokens_markdown(res):
    out = ["# Unit token survey", "",
           "Per token family (not per index), once per capture context. One-glance answer first, details below.", "",
           "| family | token works? | identity secret when? | values secret when? |", "|---|---|---|---|"]
    if not res["families"]:
        return "\n".join(out + ["", "_no token survey in this dump (v2.2 FD_Logs runs it automatically)_", ""])
    for f in res["families"]:
        s = f["summary"]
        out.append("| %s | %s | %s | %s |" % (f["family"], s["works"], s["identitySecret"], s["valuesSecret"]))
    out += ["", "## Details (codes for existing units; `none:` = a non-existent token of that family)", ""]
    out.append("| family | ctx | resolved | " + " | ".join(CHECKS) + " |")
    out.append("|---|---|---|" + "---|" * len(CHECKS))
    for f in res["families"]:
        for ctx in _ctxs(f["ctx"]):
            c = f["ctx"][ctx]
            cells = []
            for chk in CHECKS:
                b = c["checks"].get(chk) or {}
                cells.append(" ".join("%s%s" % ("" if k == "exist" else k + ":", v) for k, v in sorted(b.items())))
            out.append("| %s | %s | %s/%s | %s |" % (f["family"], ctx, c["exist"], c["tokens"], " | ".join(cells)))
    if res["absent"]:
        out += ["", "Absent: " + ", ".join("%s (%s)" % kv for kv in sorted(res["absent"].items()))]
    return "\n".join(out) + "\n"


# ------------------------------------------------------------------ spell knowledge
def knowledge(dump):
    kn = dump.db.get("knowledge") or {}
    out = {}
    for build, kb in kn.items():
        spells = kb.get("spells") or {}
        fields = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
        per = {}
        for sid, e in spells.items():
            for ctx, codes in (e.get("ctx") or {}).items():
                for f, c in (codes or {}).items():
                    if f != "tooltipLines":
                        fields[f][ctx][c] += 1
            d = e.get("data") or {}
            per[str(sid)] = {"name": d.get("info.name"), "castTime": d.get("info.castTime"), "maxRange": d.get("info.maxRange"),
                             "baseCooldown": d.get("baseCooldown"), "parsed": d.get("parsed"), "learned": e.get("learned"),
                             "helpful": d.get("IsSpellHelpful"), "secrecy": {k[8:]: v for k, v in d.items() if str(k).startswith("secrecy.")}}
        out[str(build)] = {"player": kb.get("player"), "listed": kb.get("listed"),
                           "fields": {f: {c: dict(cnt) for c, cnt in byC.items()} for f, byC in fields.items()}, "spells": per}
    return out


def knowledge_markdown(res):
    out = ["# Spell knowledge (per build)", "", "Clear data from out of combat; secrecy per field and context (tooltip secrecy is part of the answer).", ""]
    if not res:
        return "\n".join(out + ["_no knowledge in this dump (v2.2 FD_Logs collects it)_", ""])
    for build, kb in sorted(res.items()):
        p = kb.get("player") or {}
        out += ["## build %s - %s %s (spec %s), %s spells" % (build, p.get("class"), p.get("level"), p.get("specName") or p.get("specIndex"),
                                                               kb.get("listed")), ""]
        ctxs = sorted({c for byC in kb["fields"].values() for c in byC})
        out.append("| field | " + " | ".join(ctxs) + " |")
        out.append("|---|" + "---|" * len(ctxs))
        for f, byC in sorted(kb["fields"].items()):
            out.append("| %s | %s |" % (f, " | ".join(dominant(byC.get(c)) for c in ctxs)))
        out += ["", "| spell | name | cast | cd | parsed | learned |", "|---|---|---|---|---|---|"]
        for sid, s in sorted(kb["spells"].items(), key=lambda kv: int(kv[0]) if kv[0].isdigit() else 0):
            out.append("| %s | %s | %s | %s | %s | %s |" % (sid, s.get("name"), s.get("castTime"), s.get("baseCooldown"),
                                                          s.get("parsed") or "", s.get("learned") or ""))
        out.append("")
    return "\n".join(out) + "\n"
