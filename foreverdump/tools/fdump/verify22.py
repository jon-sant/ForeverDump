"""Secrets verifier v2.2: reconcile observations with the 70245 inventory (expected secrecy ground truth).

Value states (addon v2.2): absent / nil / secret / container(-secret|-clear) / clear. Only present values (secret,
container, clear) enter rates. Statuses:
  CONFIRMED           observations agree with the expectation (conditional: verified when a same-frame predicate
                      sample exists, else 'unverified-predicate')
  CONTRADICTED        always-secret but a present clear scalar; never-secret but secret; conditional and the same-frame
                      Should*BeSecret disagreed with the observed value
  INCONCLUSIVE        only nil/absent/container values, or v2.1 data where 'clear' may be a nil (Nilable /
                      MayReturnNothing / container return types) and no secret sample exists
  UNDOCUMENTED-SECRET observed secret, no secrecy tag in the inventory
  UNOBSERVED          no data
v2.1 SVs counted nil as clear and never looked inside containers; for those the converter uses the inventory
(Nilable / MayReturnNothing / container types) plus probe-section values ("<nil>") as evidence instead."""
import collections
import re

from .dump import as_list
from .secrets import observations

STATUS_ORDER = ("CONTRADICTED", "UNDOCUMENTED-SECRET", "INCONCLUSIVE", "CONFIRMED", "UNOBSERVED")


def _intmap(v):
    out = {}
    if isinstance(v, dict):
        for k, x in v.items():
            try:
                out[int(k)] = x
            except (TypeError, ValueError):
                pass
    elif isinstance(v, list):
        for i, x in enumerate(v, 1):
            if x is not None:
                out[i] = x
    return out


def probe_evidence(dump):
    """api name -> Counter(nil/secret/clear/userdata) from probe-section SafeCall results"""
    ev = collections.defaultdict(collections.Counter)

    def walk(node, depth=0):
        if depth > 6 or not isinstance(node, dict):
            return
        for k, v in node.items():
            if isinstance(v, dict) and "ok" in v and "values" in v and isinstance(k, str):
                vals = as_list(v.get("values"))
                first = vals[0] if vals else "<nil>"
                if first == "<nil>" or first is None:
                    ev[k]["nil"] += 1
                elif first in ("<secret>", "<secret table>"):
                    ev[k]["secret"] += 1
                elif first == "<userdata>":
                    ev[k]["userdata"] += 1
                else:
                    ev[k]["clear"] += 1
            elif isinstance(v, dict):
                walk(v, depth + 1)
    walk(dump.sections.get("probe") or {})
    return ev


def context_predicates(dump):
    """v2.1 fallback: Should* values snapshotted per context (secrets section) -> {'combat': {...}, 'ooc': {...}}"""
    out = {}
    sct = dump.sections.get("secrets") or {}
    for snap, ctx in (("inCombat", "combat"), ("outOfCombat", "ooc"), ("inEncounter", "enc")):
        g = (sct.get(snap) or {}).get("getters") or {}
        vals = {}
        for k, res in g.items():
            if k.startswith("C_Secrets.Should") and isinstance(res, dict) and as_list(res.get("values")):
                vals[k.split(".", 1)[1]] = as_list(res["values"])[0]
        if vals:
            out[ctx] = vals
    return out


TAG_TO_CONTEXT_PRED = {"SecretWhenCooldownsRestricted": "ShouldCooldownsBeSecret", "SecretWhenAurasRestricted": "ShouldAurasBeSecret",
                       "SecretWhenUnitStatsRestricted": "ShouldUnitStatsBeSecret"}


def _field_key(key):
    """field:C_Spell.GetSpellCooldown#1.startTime -> ('api:C_Spell.GetSpellCooldown', 1, 'startTime');
    field:Struct.field -> (None, None, ('Struct','field'))"""
    m = re.match(r"^field:(.+)#(\d+)\.(.+)$", key)
    if m:
        return "api:" + m.group(1), int(m.group(2)), m.group(3)
    m = re.match(r"^field:([^.#]+)\.(.+)$", key)
    if m:
        return None, None, (m.group(1), m.group(2))
    return None, None, None


def reconcile(dump, inv):
    obs, _, _ = observations(dump)
    ctx_all = dict(getattr(observations, "ctx", {}) or {})
    raw = dump.db.get("secretsObs") or {}
    v22 = any(isinstance(r, dict) and any(k in r for k in ("nl", "ab", "ct", "pv")) for r in raw.values()) \
        or str((dump.meta() or {}).get("addonVersion") or dump.db.get("addonVersion") or "").startswith("2.2")
    pev = probe_evidence(dump)
    nil_doc = nil_by_doc_text(dump)
    cpred = context_predicates(dump)
    rows = []
    seen = set()

    def emit(key, pos, exp, name=None, field=None):
        r = raw.get(key) if isinstance(raw.get(key), dict) else {}
        buckets = (ctx_all.get(key) or {}).get(pos) or {}
        nl, ab = _intmap(r.get("nl")).get(pos, 0), _intmap(r.get("ab")).get(pos, 0)
        ct = _intmap(r.get("ct")).get(pos)
        pv = _intmap(r.get("pv")).get(pos)
        n = sum(b[0] for b in buckets.values())
        s = sum(b[1] for b in buckets.values())
        cont_n, cont_s = (as_list(ct) + [0, 0])[:2] if ct else (0, 0)
        clear_scalar = n - s - (cont_n - cont_s)
        sctx = sorted(c for c, b in buckets.items() if b[1])
        cctx = sorted(c for c, b in buckets.items() if b[0] > b[1])
        cls = exp["class"] if exp else "none"
        row = {"key": key, "pos": pos, "name": name, "field": field, "expected": cls, "tag": exp and exp.get("tag"),
               "predicate": exp and exp.get("predicate"), "present": n, "secret": s, "clear": clear_scalar,
               "containers": cont_n, "containersSecret": cont_s, "nil": nl, "absent": ab, "secretContexts": sctx,
               "clearContexts": cctx, "dataVersion": "v2.2" if v22 else "v2.1"}
        if pv:
            pv = (as_list(pv) + [0, 0, 0, 0])[:4]
            row["predicateSamples"] = {"trueSecret": pv[0], "trueClear": pv[1], "falseSecret": pv[2], "falseClear": pv[3]}
        api_name = key.split(":", 1)[1].split("#")[0]
        evid = pev.get(api_name)
        if evid:
            row["probeEvidence"] = dict(evid)
        if exp is not None and api_name in nil_doc and key.startswith("api:"):
            exp = dict(exp, docTextNil=True)
        ambiguous = (not v22) and exp is not None and (exp.get("nilable") or exp.get("mayReturnNothing") or exp.get("variadic")
                                                       or exp.get("docTextNil")
                                                       or exp.get("container") or (evid and (evid.get("nil") or evid.get("userdata"))))
        status, note = "UNOBSERVED", ""
        if n == 0:
            if nl or ab:
                status, note = "INCONCLUSIVE", "only nil/absent values observed (%d nil, %d absent)" % (nl, ab)
        elif cls == "always":
            if clear_scalar > 0 and not ambiguous:
                status, note = "CONTRADICTED", "documented always-secret; %d present clear value(s) in %s" % (clear_scalar, ", ".join(cctx))
            elif clear_scalar > 0 and ambiguous and s == 0:
                status = "INCONCLUSIVE"
                note = "v2.1 counted nil/containers as clear; %s; no secret sample" % _why(exp, evid)
            elif clear_scalar > 0 and ambiguous:
                status = "CONFIRMED"
                note = "secret whenever a value was present; the %d 'clear' sample(s) are attributable to nil returns (%s)" % (
                    clear_scalar, _why(exp, evid))
            elif cont_n and cont_s == 0 and s == 0:
                status, note = "INCONCLUSIVE", "container(s) with no secret contents (e.g. the player's own cast)"
            else:
                status = "CONFIRMED"
        elif cls == "never":
            status = "CONTRADICTED" if s else "CONFIRMED"
            note = ("NeverSecret but secret in " + ", ".join(sctx)) if s else ""
        elif cls == "conditional":
            ps = row.get("predicateSamples")
            if ps and (ps["falseSecret"] or ps["trueClear"]):
                status = "CONTRADICTED"
                note = "same-frame %s disagreed: secret while false %d, clear while true %d" % (exp.get("predicate"), ps["falseSecret"], ps["trueClear"])
            elif ps:
                status, note = "CONFIRMED", "verified against same-frame predicate"
            else:
                status = "CONFIRMED"
                note = "unverified-predicate (no same-frame sample)"
                cp = TAG_TO_CONTEXT_PRED.get(exp.get("tag") or "")
                if cp and cpred:
                    bad = [c for c in sctx if cpred.get(c.split("/")[0], {}).get(cp) is False] + \
                          [c for c in cctx if cpred.get(c.split("/")[0], {}).get(cp) is True]
                    note += "; %s with the per-context %s snapshot%s" % ("INCONSISTENT" if bad else "consistent", cp,
                                                                          (" (" + ", ".join(bad) + ")") if bad else "")
                if s:
                    note += "; secret in " + ", ".join(sctx)
        else:
            status = "UNDOCUMENTED-SECRET" if s else "CONFIRMED"
            note = ("no secrecy tag; secret in " + ", ".join(sctx)) if s else ""
        row["status"], row["note"] = status, note
        rows.append(row)

    for name, e in inv.functions.items():
        key = "api:" + name
        npos = max(len(e["slots"]), max([p for p in (ctx_all.get(key) or {})] or [0]), 1)
        for pos in range(1, npos + 1):
            emit(key, pos, inv.expected(key, pos), e["slots"][pos - 1]["name"] if pos <= len(e["slots"]) else None)
        seen.add(key)
    for name, e in inv.events.items():
        key = "event:" + name
        npos = max(len(e["slots"]), max([p for p in (ctx_all.get(key) or {})] or [0]), 1)
        for pos in range(1, npos + 1):
            emit(key, pos, inv.expected(key, pos), e["slots"][pos - 1]["name"] if pos <= len(e["slots"]) else None)
        seen.add(key)
    for key in sorted(set(ctx_all) | set(k for k in obs)):
        if key in seen or not isinstance(key, str):
            continue
        if key.startswith("field:"):
            pkey, ppos, field = _field_key(key)
            if pkey:
                exp = inv.expected(pkey, ppos, field)
            elif isinstance(field, tuple):
                exp = inv.struct_field(*field)
            else:
                exp = None
            emit(key, 1, exp, field=field if isinstance(field, str) else (field[1] if field else None))
        elif key.startswith(("api:", "event:")):
            for pos in sorted((ctx_all.get(key) or {1: {}})):
                emit(key, pos, None)
    by = collections.Counter(r["status"] for r in rows)

    def cov(pred):
        sel = [r for r in rows if pred(r)]
        o = [r for r in sel if r["status"] != "UNOBSERVED"]
        return {"positions": len(sel), "observed": len(o), "percent": round(100.0 * len(o) / len(sel), 2) if sel else 0.0}
    coverage = {"all": cov(lambda r: not r["key"].startswith("field:")),
                "expectedSecretOrNever": cov(lambda r: r["expected"] in ("always", "conditional", "never")),
                "alwaysSecret": cov(lambda r: r["expected"] == "always"),
                "conditional": cov(lambda r: r["expected"] == "conditional"),
                "structFields": cov(lambda r: r["key"].startswith("field:"))}
    order = {s: i for i, s in enumerate(STATUS_ORDER)}
    rows.sort(key=lambda r: (order.get(r["status"], 9), r["key"], r["pos"]))
    return {"build": dump.build_label(), "ground": "api-secrecy-inventory-forever-70245.tsv", "inventory": inv.stats(),
            "dataVersion": "v2.2" if v22 else "v2.1", "statusCounts": dict(by), "coverage": coverage,
            "liveContradictions": as_list((dump.db.get("secretsLive") or {}).get("contradictions")), "rows": rows,
            "docsCrossCheck": docs_cross_check(dump, inv)}


def nil_by_doc_text(dump):
    """functions whose Documentation text says they return nil (Nilable=false in the docs notwithstanding,
    e.g. UnitSpellTargetClass: 'Returns nil if the unit is not casting a spell')"""
    out = set()
    for sys in dump.doc_systems():
        ns = sys.get("Namespace")
        for f in as_list(sys.get("Functions")):
            txt = " ".join(str(x) for x in as_list(f.get("Documentation")))
            if re.search(r"\b(returns? nil|nil if|returns nothing)\b", txt, re.I):
                out.add(((ns + ".") if ns else "") + str(f.get("Name")))
    return out


def _why(exp, evid):
    parts = []
    if exp.get("docTextNil"):
        parts.append("doc text says it returns nil")
    if exp.get("nilable"):
        parts.append("return is Nilable")
    if exp.get("mayReturnNothing"):
        parts.append("MayReturnNothing")
    if exp.get("variadic"):
        parts.append("variadic/empty Returns (only valid inside its event)")
    if exp.get("container"):
        parts.append("returns a container (%s): issecretvalue(obj) is false, needs obj:HasSecretValues()" % exp.get("type"))
    if evid and evid.get("nil"):
        parts.append("probe saw <nil> %dx" % evid["nil"])
    return "; ".join(parts) or "possible nil"


def docs_cross_check(dump, inv):
    """first principles: does the inventory agree with the docs the client itself shipped (dump docs)?"""
    from .secrets import classify_parent
    agree = disagree = 0
    diffs = []
    missing = 0
    for sys in dump.doc_systems():
        if sys.get("Type") == "ScriptObject":
            continue
        ns = sys.get("Namespace")
        for f in as_list(sys.get("Functions")):
            name = ((ns + ".") if ns else "") + str(f.get("Name"))
            e = inv.functions.get(name)
            if not e:
                missing += 1
                continue
            a = classify_parent(f)
            b, _ = inv._parent(e["tags"])
            a = {"unspecified": "none", "never": "none", "partial": "none"}.get(a, a)
            if a == b:
                agree += 1
            else:
                disagree += 1
                if len(diffs) < 30:
                    diffs.append({"function": name, "dumpDocs": a, "inventory": b})
    return {"agree": agree, "disagree": disagree, "missingInInventory": missing, "examples": diffs}


def markdown(rep, before=None, max_rows=300):
    L = ["# Forever secrets VERIFY report (v2.2)", "",
         "Build %s. Ground truth: `%s` (%d functions, %d events). Data: %s SavedVariables." % (
             rep["build"], rep["ground"], rep["inventory"]["functions"], rep["inventory"]["events"], rep["dataVersion"]), "",
         "Value states: absent / nil / secret / container / clear; only present values count. Conditional rows are only "
         "CONTRADICTED when the same-frame `C_Secrets.Should*BeSecret` disagreed (v2.2 data); NeverSecret fields secret are "
         "always CONTRADICTED.", "", "## Summary", "", "| status | count |" + (" before (v2.1 verifier) |" if before else ""),
         "|---|---|" + ("---|" if before else "")]
    for k in STATUS_ORDER:
        L.append("| %s | %d |%s" % (k, rep["statusCounts"].get(k, 0), (" %s |" % before.get(k, "-")) if before else ""))
    dc = rep["docsCrossCheck"]
    L += ["", "Inventory vs the client's own docs (dump): %d agree, %d disagree, %d dump functions not in the inventory." % (
        dc["agree"], dc["disagree"], dc["missingInInventory"])]
    L += ["", "## Coverage", "", "| scope | positions | observed | % |", "|---|---|---|---|"]
    for k, c in rep["coverage"].items():
        L.append("| %s | %d | %d | %.2f |" % (k, c["positions"], c["observed"], c["percent"]))

    def table(status, limit):
        sel = [r for r in rep["rows"] if r["status"] == status]
        L.extend(["", "## %s (%d)" % (status, len(sel)), ""])
        if not sel:
            L.append("none")
            return
        L.extend(["| key | pos | expected | tag | present | secret | clear | containers | nil | absent | note |",
                  "|---|---|---|---|---|---|---|---|---|---|---|"])
        for r in sel[:limit]:
            L.append("| %s | %s | %s | %s | %d | %d | %d | %d | %d | %d | %s |" % (
                r["key"], r["pos"], r["expected"], r.get("tag") or "", r["present"], r["secret"], r["clear"], r["containers"],
                r["nil"], r["absent"], (r.get("note") or "").replace("|", "/")))
        if len(sel) > limit:
            L.append("| ... %d more in verify.json |||||||||||" % (len(sel) - limit))
    for st in ("CONTRADICTED", "UNDOCUMENTED-SECRET", "INCONCLUSIVE", "CONFIRMED"):
        table(st, max_rows)
    lc = rep["liveContradictions"]
    L += ["", "## Contradictions flagged live in game (%d; v2.1 flags used the old nil-as-clear rule)" % len(lc), ""]
    for c in lc[:50]:
        L.append("- %s #%s doc %s observed %s (%s) x%s" % (c.get("key"), c.get("pos"), c.get("doc"), c.get("observed"), c.get("ctx"), c.get("count")))
    return "\n".join(L) + "\n"
