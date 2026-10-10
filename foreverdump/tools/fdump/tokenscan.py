"""v2.2.4 TOKENS.md: the group-aware discovery scanner's token matrix (ForeverDumpDB.tokenscan[build], Tokens.lua T.Scan).

Per context key "<ooc|combat|enc>|<instanceType>|<solo|party|raid>" and token family (digits -> N): five-state codes per
field (exists, guid, name, class, level, health, ...), the dominant code and its share. Plus scan cost per capture, token
dedupe pairs (two families resolving to the same GUID), alias learning (a secret-GUID token resolved through a clear one),
and change alerts (the dominant code of a cell differs from the stored baseline; written to the drift changelog in game).
Counts and codes only: the SV never holds GUIDs or names."""
import collections

from fdump.luasv import as_list

FIELDS = ("exists", "guid", "name", "class", "level", "health", "healthMax", "power", "isPlayer", "reaction", "canAttack",
          "isMe", "isTarget", "dead", "combat", "idSecret")
CODE_NAME = {"C": "clear", "S": "secret", "N": "nil", "T": "container(some fields secret)", "K": "table", "E": "error"}


def dominant(counts):
    """{code: n} -> (code, share, total); numeric-only values"""
    nums = {str(k): v for k, v in (counts or {}).items() if isinstance(v, (int, float))}
    tot = sum(nums.values())
    if not tot:
        return None, 0.0, 0
    best = max(sorted(nums), key=lambda k: nums[k])
    return best, nums[best] / float(tot), tot


def split_ctx(key):
    parts = str(key).split("|")
    while len(parts) < 3:
        parts.append("?")
    return {"state": parts[0], "instance": parts[1], "group": parts[2]}


def analyze(dump):
    db = dump.db if hasattr(dump, "db") else (dump or {})
    out = {"builds": {}, "changes": []}
    for build, d in ((db.get("tokenscan") or {}).items() if isinstance(db.get("tokenscan"), dict) else []):
        if not isinstance(d, dict):
            continue
        rows = []
        for ck, fams in (d.get("m") or {}).items():
            cx = split_ctx(ck)
            for fam, fields in (fams or {}).items():
                cells = {}
                for f, counts in (fields or {}).items():
                    code, share, tot = dominant(counts)
                    if code is not None:
                        cells[f] = {"code": code, "share": round(share, 3), "n": tot, "mixed": share < 0.999,
                                    "counts": {str(k): v for k, v in counts.items()}}
                rows.append(dict(cx, ctx=ck, family=fam, cells=cells))
        rows.sort(key=lambda r: (r["instance"], r["group"], r["state"], r["family"]))
        costs = [c for c in as_list(d.get("cost")) if isinstance(c, dict)]
        out["builds"][str(build)] = {"rows": rows, "contexts": sorted({r["ctx"] for r in rows}), "cost": costs,
                                     "dup": dict(d.get("dup") or {}), "alias": dict(d.get("alias") or {}),
                                     "baselineCells": sum(len(v or {}) for v in (d.get("baseline") or {}).values()) if isinstance(d.get("baseline"), dict) else 0}
    for build, d in ((db.get("drift") or {}).items() if isinstance(db.get("drift"), dict) else []):
        for c in as_list((d or {}).get("changelog")):
            if isinstance(c, dict) and c.get("kind") == "token-matrix":
                out["changes"].append(dict(c, build=c.get("build", build)))
    return out


def leads(res):
    """change alerts and over-budget slices -> analyze leads (severity, title, evidence)"""
    L = []
    for c in res.get("changes", []):
        L.append(("medium", "token matrix change", "%s: %s -> %s" % (c.get("key"), c.get("old"), c.get("new")),
                  "build %s, %s (re-verified every capture)" % (c.get("build"), c.get("date"))))
    for b, x in res.get("builds", {}).items():
        for c in x["cost"]:
            if (c.get("overBudget") or 0) > 0:
                L.append(("low", "token scan over budget", "%d slice(s) over %.2f ms (max %.3f ms)" % (c["overBudget"], c.get("budgetMs") or 0, c.get("maxSliceMs") or 0),
                          "capture %s" % c.get("start")))
    return L


def markdown(res, survey=None):
    L = ["# TOKENS: unit token matrix per context / instance type", "",
         "Discovery scanner (Tokens.lua `T.Scan`): every token family (player/pet/target/focus/mouseover/soft*, party1-4, raid1-40, "
         "arena1-5, boss1-8, nameplate1-40, plus `target` / `targettarget` chains) is read round-robin under a per-slice time budget. "
         "Codes: C clear, S secret, N nil, T secret table, K table, E error; `*` = mixed (dominant share < 100%). "
         "Re-verified every capture against the stored baseline; a changed dominant code is a change alert.", ""]
    if not res.get("builds"):
        L += ["_No scanner data in this dump (the scanner ships with v2.2.4; captures before it only have the one-shot survey below)._", ""]
    for b, x in sorted(res.get("builds", {}).items()):
        L += ["## build %s" % b, ""]
        if not x["rows"]:
            L += ["_scanner ran (%d capture(s)) but read no tokens yet_" % len(x["cost"]), ""]
        groups = collections.OrderedDict()
        for r in x["rows"]:
            groups.setdefault((r["instance"], r["group"]), []).append(r)
        for (inst, grp), rows in groups.items():
            L += ["### instance `%s`, group `%s`" % (inst, grp), "", "| state | family | " + " | ".join(FIELDS) + " |", "|---|---|" + "---|" * len(FIELDS)]
            for r in rows:
                cells = []
                for f in FIELDS:
                    c = r["cells"].get(f)
                    cells.append("-" if not c else (c["code"] + ("*" if c["mixed"] else "")))
                L.append("| %s | %s | %s |" % (r["state"], r["family"], " | ".join(cells)))
            L.append("")
        if x["cost"]:
            L += ["### Scan cost per capture", "", "| capture start | ms | slices | tokens | reads | existing | sweeps | sweep s | max slice ms | over budget | budget | list | contexts |",
                  "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
            for c in x["cost"]:
                L.append("| %s | %.2f | %s | %s | %s | %s | %s | %s | %.3f | %s | %s | %s | %s |" % (
                    c.get("start"), c.get("ms") or 0, c.get("slices"), c.get("tokens"), c.get("reads"), c.get("existing"), c.get("sweeps"),
                    c.get("sweepS"), c.get("maxSliceMs") or 0, c.get("overBudget", "-"), c.get("budgetMs"), c.get("listSize"),
                    ", ".join("%s %s" % (k.replace("|", "/"), v) for k, v in sorted((c.get("contexts") or {}).items()))))
            L.append("")
        if x["dup"]:
            L += ["### Same unit on several tokens (dedupe pairs)", ""] + ["- `%s`: %d" % kv for kv in sorted(x["dup"].items(), key=lambda kv: -kv[1])] + [""]
        if x["alias"]:
            L += ["### Secret-GUID tokens resolved by alias (shared cast / castGUID)", ""] + ["- `%s`: %d" % kv for kv in sorted(x["alias"].items(), key=lambda kv: -kv[1])] + [""]
    L += ["## Change alerts", ""]
    if res.get("changes"):
        L += ["| build | cell | old | new | date |", "|---|---|---|---|---|"]
        for c in res["changes"]:
            L.append("| %s | %s | %s | %s | %s |" % (c.get("build"), str(c.get("key")).replace("|", "/"), c.get("old"), c.get("new"), c.get("date")))
    else:
        L.append("none (first capture with the scanner sets the baseline)")
    L.append("")
    if survey and survey.get("families"):
        L += ["## One-shot token survey (v2.2 TokenSurvey, out of combat)", "", "| family | token works? | identity secret when? | values secret when? |", "|---|---|---|---|"]
        for f in survey["families"]:
            s = f["summary"]
            L.append("| %s | %s | %s | %s |" % (f["family"], s["works"], s["identitySecret"], s["valuesSecret"]))
        L.append("")
    return "\n".join(L) + "\n"
