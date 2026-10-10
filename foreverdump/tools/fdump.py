#!/usr/bin/env python3
"""ForeverDump converter CLI. Run `python3 tools/fdump.py -h` for subcommands.
DUMP may be a SavedVariables ForeverDump.lua (parsed safely, never executed), a dump.json written by
`fdump.py json`, or the folder containing that dump.json."""
import argparse
import collections
import json
import os
import datetime
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fdump import characters as charmod  # noqa: E402
from fdump import probes, drift as driftmod, inference as infmod, guidejson  # noqa: E402
from fdump import unhash as unhashmod, apicheck, combatlog, diff as diffmod, export_json, ketho, luacheck_gen, luals, mocks, secrets as secretsmod, taintlog, xref as xrefmod, migrate as migratemod, fixturepack, restrictions as restrmod, clientlog, svsize, verify22, perfcheck, perf as perfmod, replay as replaymod  # noqa: E402
from fdump.expect import Inventory  # noqa: E402
from fdump.dump import Dump  # noqa: E402
from fdump.luasv import as_list  # noqa: E402



# v2.2.7: own call sites of known ADDON_ACTION_BLOCKED regressions (v2.2.6 run 6)
KNOWN_BLOCK_SITES = {
    "Tokens.lua:296": " -> TokenScan readToken: CheckInteractDistance(range28) in combat (fixed 2.2.7: ns.CombatGuard)",
    "WorldCapture.lua:141": " -> WorldCapture range10: CheckInteractDistance in combat (fixed 2.2.7: ns.CombatGuard)",
    "WorldCapture.lua:143": " -> WorldCapture range28: CheckInteractDistance in combat (fixed 2.2.7: ns.CombatGuard)",
}


def blocked_site(own):
    """First ForeverDump frame of a blocked record's ownStack that is not the Perf wrapper -> 'File.lua:line'."""
    import re as _re
    for line in str(own or "").splitlines():
        if "Perf.lua" in line:
            continue
        m = _re.search(r"ForeverDump/([\w/]+\.lua)\]?:(\d+)", line)
        if m:
            return "%s:%s" % (m.group(1), m.group(2))
    return None


def _write(path, text):
    d = os.path.dirname(path)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def info(dump):
    m = dump.meta()
    consts = m.get("projectConstants") or {}
    names = [k for k, v in consts.items() if v == m.get("projectID") and k != "WOW_PROJECT_ID"]
    lines = ["build:     %s" % dump.build_label(),
             "project:   WOW_PROJECT_ID=%s (%s)" % (m.get("projectID"), m.get("projectName") or ",".join(names) or "unknown"),
             "constants: %s" % ", ".join("%s=%s" % kv for kv in sorted(consts.items())),
             "scriptsDisallowedForBeta: %s" % m.get("scriptsDisallowedForBeta"),
             "locale:    %s, dumped %s" % (m.get("locale"), m.get("date")),
             "sections:  %s" % ", ".join(sorted(dump.sections)),
             "docs:      %s systems" % len(dump.doc_systems()),
             "strings:   %d" % len(dump.strings),
             "recorder:  %d session(s); combat log: %d session(s)" % (
                 len(as_list(dump.record.get("sessions"))), len(as_list(dump.combatlog.get("sessions")))),
             "errors:    %d unique, %d blocked/forbidden/warnings" % (
                 len(as_list(dump.log.get("errors"))), len(as_list(dump.log.get("blocked"))))]
    return "\n".join(lines)


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _latest_baseline(exclude_source=None, folder=None):
    folder = folder or os.path.join(ROOT, "fixtures", "baselines")
    if not os.path.isdir(folder):
        return None
    builds = sorted((d for d in os.listdir(folder) if os.path.exists(os.path.join(folder, d, "baseline.json"))),
                    key=lambda d: int(d) if d.isdigit() else 0)
    return os.path.join(folder, builds[-1], "baseline.json") if builds else None


def _combat(dump, out, inv):
    res = probes.combat(dump, inv)
    export_json.write_json(os.path.join(out, "combat-matrix.json"), probes.combat_json(res))
    export_json.write_json(os.path.join(out, "combat.json"),
                           guidejson.combat(dump, guidejson.build_label(dump), guidejson.captured(dump)))
    _write(os.path.join(out, "COMBAT-SECRETS.md"), probes.combat_markdown(res))
    print("combat: %d item(s), %d detectability context(s); wrote combat.json (guide --combat), combat-matrix.json, "
          "COMBAT-SECRETS.md to %s" % (len(res["matrix"]), len(res["detectability"]), out))
    return res


def _tokens(dump, out):
    res = probes.tokens(dump)
    export_json.write_json(os.path.join(out, "tokens.json"), res)
    _write(os.path.join(out, "UNIT-TOKENS.md"), probes.tokens_markdown(res))
    from fdump import tokenscan
    scan = tokenscan.analyze(dump)
    export_json.write_json(os.path.join(out, "tokenscan.json"), scan)
    _write(os.path.join(out, "TOKENS.md"), tokenscan.markdown(scan, res))
    print("tokens: %d famil(ies), scanner matrix %d row(s), %d change alert(s); wrote tokens.json, UNIT-TOKENS.md, tokenscan.json, TOKENS.md to %s" % (
        len(res["families"]), sum(len(x["rows"]) for x in scan["builds"].values()), len(scan["changes"]), out))
    return res


def _containers(dump, out, baseline=None, write_baseline=None):
    from fdump import containers as ctmod
    if baseline is None:
        b = _latest_baseline()
        cand = os.path.join(os.path.dirname(b), "containers.json") if b else None
        baseline = cand if cand and os.path.exists(cand) else None
    r = ctmod.report(dump, baseline)
    export_json.write_json(os.path.join(out, "containers.json"), ctmod.guide_json(r))
    export_json.write_json(os.path.join(out, "containers-schema.json"), r["raw"])
    _write(os.path.join(out, "CONTAINERS.md"), ctmod.markdown(r))
    d = r.get("diff")
    print("containers: source %s, %d context(s), %d unit class(es), %d partial-secret container(s)%s; wrote containers.json "
          "(guide --containers), containers-schema.json, CONTAINERS.md to %s" % (
              r["source"].split(":")[0], len(r["contexts"]), len(r["unitClasses"]), len(r["partial"]),
              (", vs baseline: %d state change(s), %d new, %d gone" % (len(d["changed"]), d["new"], d["gone"])) if d else ", no baseline", out))
    if write_baseline:
        path = os.path.join(write_baseline, str(r.get("build") or "unknown"), "containers.json")
        export_json.write_json(path, r["raw"])
        print("container baseline ->", path)
    return r


def _resolve_player(fx, player, logfile=None, dump=None):
    """GUID | 'First Last' | first name | Name-Realm | None (auto: SV identity GUID -> SV name -> characters.json -> 0x511)"""
    guid, info = charmod.resolve(player, fx, dump)
    return guid, charmod.describe(guid, info)


def _inference(dump, out, logfile, player, year, utc_offset):
    fx = combatlog.parse_file(logfile, year=year, utc_offset_sec=None if utc_offset is None else utc_offset * 3600) if logfile else None
    guid, note = _resolve_player(fx, player, logfile, dump)
    print(note)
    res = infmod.analyze(dump, fx, guid)
    res["playerNote"] = note
    export_json.write_json(os.path.join(out, "inference.json"), res)
    _write(os.path.join(out, "INFERENCE.md"), infmod.inference_markdown(res))
    _write(os.path.join(out, "HSM.md"), infmod.hsm_markdown(res))
    hj = infmod.hsm_guide_json(res, guidejson.build_label(dump), guidejson.captured(dump))
    export_json.write_json(os.path.join(out, "hsm.json"), hj)
    print("inference: addon data %s, replay modes %s, %d guide rule row(s); wrote inference.json, INFERENCE.md, hsm.json "
          "(guide --hsm), HSM.md to %s" % (bool(res.get("addon")), ",".join(res.get("replay") or {}) or "-", len(hj["rules"]), out))
    return res, hj


def _coverage(dump, out, logfile, player, year, utc_offset=None):
    from fdump import coverage as covmod
    if not logfile:
        print("coverage: skipped (needs --file WoWCombatLog)")
        return None
    fx = combatlog.parse_file(logfile, year=year, utc_offset_sec=None if utc_offset is None else utc_offset * 3600)
    guid, note = _resolve_player(fx, player, logfile, dump)
    res = covmod.analyze(dump, fx, guid)
    os.makedirs(out, exist_ok=True)
    export_json.write_json(os.path.join(out, "coverage.json"), {k: v for k, v in res.items() if not str(k).startswith("_")})   # _ctx: in-memory only
    export_json.write_json(os.path.join(out, "coverage-guide.json"), covmod.guide_json(res, guidejson.build_label(dump), guidejson.captured(dump)))
    _write(os.path.join(out, "COVERAGE.md"), covmod.markdown(res))
    a = ((res.get("replay") or {}).get("after") or {}).get("scores") or {}
    d = a.get("damage-on-target") or {}
    print("coverage: %d matrix row(s), %d fight(s); damage-on-target attribution after %s%% (falseSelf %s); wrote coverage.json, "
          "coverage-guide.json (guide --coverage), COVERAGE.md to %s" % (len(res["matrix"]), len(res["fights"]), d.get("accuracy"),
                                                                       d.get("falseSelf", 0), out))
    return res


def _fx(logfile, year, utc_offset=None):
    return combatlog.parse_file(logfile, year=year, utc_offset_sec=None if utc_offset is None else utc_offset * 3600) if logfile else None


def _knowledge(dump, out, logfile, player, year, utc_offset=None):
    from fdump import knowlint
    res = probes.knowledge(dump)
    fx = _fx(logfile, year, utc_offset)
    guid = _resolve_player(fx, player, logfile, dump)[0] if fx else None
    kl = knowlint.analyze(dump, fx, guid)
    out_json = {"builds": res, "lint": {k: v for k, v in kl.items() if k != "reparse"}, "reparse": kl.get("reparse")}
    export_json.write_json(os.path.join(out, "knowledge.json"), out_json)
    _write(os.path.join(out, "KNOWLEDGE.md"), probes.knowledge_markdown(res) + "\n" + knowlint.markdown(kl))
    sev = collections.Counter(r["severity"] for r in kl["data"] + kl.get("log", []))
    print("knowledge: %d build(s), lint %s, cd-line hypothesis %s; wrote knowledge.json + KNOWLEDGE.md to %s" % (
        len(res), dict(sev), kl["cdLine"]["verdict"].split(" (")[0], out))
    return res, kl


def _captures(specs, year=None):
    caps = []
    for spec in specs:
        label, _, rest = spec.partition("=")
        sv, _, log = rest.partition("::")
        d = Dump.load(sv)
        fx = _fx(log, year)
        caps.append((label, d, fx, _resolve_player(fx, None, log, d)[0]))
    return caps


def _verify_live(dump, a):
    from fdump import coverage as covmod, knowlint, verify_live
    fx = _fx(a.file, a.year, a.utc_offset)
    guid, note = _resolve_player(fx, a.player, a.file, dump)
    cov = covmod.analyze(dump, fx, guid)
    kl = knowlint.analyze(dump, fx, guid)
    res = verify_live.analyze(dump, fx, guid, cov, kl, cov["_ctx"]["cls"], replay_verdicts=cov.get("verdicts"))
    res["patch"]["build"] = str((dump.db.get("meta") or {}).get("build") or "") or None
    os.makedirs(a.out, exist_ok=True)
    export_json.write_json(os.path.join(a.out, "verify.json"), res)
    export_json.write_json(os.path.join(a.out, "knowledge-patch.json"), res["patch"])
    _write(os.path.join(a.out, "KnowledgePatch.lua"), verify_live.patch_lua(res["patch"]))
    _write(os.path.join(a.out, "VERIFY.md"), verify_live.markdown(res))
    if a.write_patch:
        _write(a.write_patch, verify_live.patch_lua(res["patch"]))
    print("verify-live: source %s, %d verdict(s), %s; patch %d spell(s) %d npc(s); wrote VERIFY.md, verify.json, knowledge-patch.json, "
          "KnowledgePatch.lua to %s" % (res["source"], res["verdicts"], ", ".join("%s %s%%" % (k, v["accuracy"]) for k, v in sorted(res["accuracy"].items())),
                                        len(res["patch"]["spells"]), len(res["patch"]["npcCasts"]), a.out))
    return res


def _correlate(dump, a):
    from fdump import correlate
    fx = _fx(a.file, a.year)
    guid = _resolve_player(fx, a.player, a.file, dump)[0]
    caps = _captures(a.with_, a.year) + [(a.label, dump, fx, guid)]
    profile = "quick" if getattr(a, "quick", False) else "full"
    res = correlate.run(caps, min_support=a.min_support, profile=profile, higher=not getattr(a, "no_higher", False))
    os.makedirs(a.out, exist_ok=True)
    export_json.write_json(os.path.join(a.out, "correlate.json"), res)
    _write(os.path.join(a.out, "CORRELATE.md"), correlate.markdown(res))
    el = res.get("elapsedSec") or {}
    print("correlate: %d capture(s), %d rule(s) (%d new), %d rare, %d higher-order, %d duration(s); "
          "elapsed mine=%ss higher=%ss total=%ss (profile %s); wrote CORRELATE.md + correlate.json to %s" % (
        len(caps), len(res["rules"]), sum(1 for r in res["rules"] if not r["known"]), len(res["rare"]),
        len(res.get("higher") or []), len(res["durations"]), el.get("mine", "?"), el.get("higher", "skip"),
        el.get("total", "?"), res.get("profile"), a.out))
    return res


def _analyze(dump, a):
    from fdump import analysis, verify_live
    fx = _fx(a.file, a.year, a.utc_offset)
    guid, note = _resolve_player(fx, a.player, a.file, dump)
    print(note)
    ctx = analysis.run(dump, fx, guid, label=a.label, taint=a.taint, baseline=a.baseline or _latest_baseline(),
                       history_caps=_captures(a.history, a.year),
                       correlate_profile=("quick" if getattr(a, "quick", False) else "full"),
                       correlate_higher=not getattr(a, "no_higher", False))
    os.makedirs(a.out, exist_ok=True)
    ctx["verify"]["patch"]["build"] = str((dump.db.get("meta") or {}).get("build") or "") or None
    export_json.write_json(os.path.join(a.out, "analysis.json"), analysis.public(ctx))
    _write(os.path.join(a.out, "ANALYSIS.md"), analysis.markdown(ctx))
    _write(os.path.join(a.out, "VERIFY.md"), ctx["verifyMd"])
    export_json.write_json(os.path.join(a.out, "knowledge-patch.json"), ctx["verify"]["patch"])
    _write(os.path.join(a.out, "KnowledgePatch.lua"), verify_live.patch_lua(ctx["verify"]["patch"]))
    _write(os.path.join(a.out, "TOKENS.md"), ctx["tokensMd"])
    export_json.write_json(os.path.join(a.out, "spell-timing.proposed.json"), ctx["timing"]["seed"])
    export_json.write_json(os.path.join(a.out, "learned-seed.proposed.json"), ctx["learned"]["seed"])
    if a.write_seed:
        from fdump import timing as timingmod, learned as learnedmod
        timingmod.write_seed(ctx["timing"]["seed"])
        learnedmod.write_seed(ctx["learned"]["seed"])
        print("analyze: --write-seed: wrote %s (+ .json), %s (+ .json)" % (os.path.relpath(timingmod.SEED_LUA), os.path.relpath(learnedmod.SEED_LUA)))
    if a.write_patch:
        _write(a.write_patch, verify_live.patch_lua(ctx["verify"]["patch"]))
    sev = collections.Counter(x["severity"] for x in ctx["leads"])
    print("analyze: %d lead(s) (%s); wrote ANALYSIS.md, analysis.json, VERIFY.md, TOKENS.md, knowledge-patch.json, KnowledgePatch.lua, "
          "spell-timing/learned-seed .proposed.json to %s" % (
        len(ctx["leads"]), ", ".join("%s %d" % (k, sev.get(k, 0)) for k in ("high", "medium", "low", "info")), a.out))
    return ctx


def _perf(dump, out):
    rep = perfmod.analyze(dump)
    os.makedirs(out, exist_ok=True)
    export_json.write_json(os.path.join(out, "perf.json"), rep)
    _write(os.path.join(out, "PERF.md"), perfmod.markdown(rep))
    flags = [f for s in rep["sessions"] for f in s["flags"]] + [f for p in rep["legacy"] for f in p.get("flags", [])]
    print("perf: %s, %d capture(s), %d flag(s)%s -> %s" % (rep["source"], len(rep["sessions"]), len(flags),
                                                         (": " + "; ".join(flags[:3])) if flags else "", os.path.join(out, "PERF.md")))
    return rep


def _guide(dump, a):
    import subprocess
    gen = os.path.join(ROOT, "tools", "guide", "build_guide.py")
    os.makedirs(a.out, exist_ok=True)
    export_json.write_json(os.path.join(a.out, "lab.json"), guidejson.lab(dump))
    _combat(dump, a.out, Inventory())
    _tokens(dump, a.out)
    _containers(dump, a.out)
    _inference(dump, a.out, a.file, a.player, a.year, None)
    _coverage(dump, a.out, a.file, a.player, a.year, None)
    smap = secretsmod.build(dump)
    inv = Inventory()
    rep = verify22.reconcile(dump, inv) if inv else secretsmod.verify_report(smap)
    export_json.write_json(os.path.join(a.out, "verify.json"), rep)
    html = a.html or os.path.join(a.out, "SECRETS-GUIDE.html")
    helptext = subprocess.run([sys.executable, gen, "-h"], capture_output=True, text=True).stdout
    cmd = [sys.executable, gen, "--inventory", os.path.join(ROOT, "tools", "fdump", "data", "api-secrecy-inventory-forever-70245.tsv"),
           "--research", os.path.join(ROOT, "tools", "guide", "secrets-research.md"), "--verify", os.path.join(a.out, "verify.json"),
           "--lab", os.path.join(a.out, "lab.json"), "--combat", os.path.join(a.out, "combat.json"),
           "--hsm", os.path.join(a.out, "hsm.json"), "--out", html]
    for flag, fn in (("--tokens", "tokens.json"), ("--inference", "inference.json"), ("--containers", "containers.json"),
                     ("--coverage", "coverage-guide.json")):
        if flag in helptext and os.path.exists(os.path.join(a.out, fn)):   # newer generators may accept these directly
            cmd += [flag, os.path.join(a.out, fn)]
    an = getattr(a, "analysis", None) or os.path.join(os.path.dirname(os.path.abspath(a.out)), "analysis", "analysis.json")
    if "--analysis" in helptext and os.path.exists(an):
        cmd += ["--analysis", an]
    r = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(r.stdout[-2000:])
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-2000:])
        raise SystemExit("guide generator failed")
    print("wrote", html)


def main(argv=None):
    p = argparse.ArgumentParser(prog="fdump.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    def add(name, help_, dump=True, out=None):
        sp = sub.add_parser(name, help=help_)
        if dump:
            sp.add_argument("dump")
        if out:
            sp.add_argument("-o", "--out", default=out)
        return sp

    add("info", "print build / project / what the dump contains")
    add("json", "(1) JSON per section", out="out/json")
    add("luals", "(2) LuaLS ---@meta annotation stubs", out="out/luals")
    sp = add("luacheck", "(3) luacheck config with std 'forever'", out="out/.luacheckrc")
    sp.add_argument("--std", default="forever")
    add("mocks", "(4) busted mocks + replay helper + fixtures", out="out/mocks")
    sp = add("check", "(5) API-check an addon folder against the dump")
    sp.add_argument("addon")
    sp.add_argument("--json", help="also write findings as JSON")
    sp.add_argument("--strict", action="store_true", help="exit non-zero on warnings too")
    sp = add("diff", "(6) diff two dumps (OLD NEW)", dump=False, out=None)
    sp.add_argument("old")
    sp.add_argument("new")
    sp.add_argument("-o", "--out", help="markdown output (default stdout)")
    sp.add_argument("--json", help="also write JSON")
    add("all", "json + luals + luacheck + mocks into one folder", out="out")
    sp = add("combatlog", "parse Logs/WoWCombatLog*.txt into CLEU replay fixtures (.json and/or .lua)", dump=False)
    sp.add_argument("logfile")
    sp.add_argument("-o", "--out", default="out/combatlog_file.json", help=".json or .lua (Lua fixture for replay.lua)")
    sp.add_argument("--year", type=int, help="year for logs whose timestamps lack one")
    sp.add_argument("--utc-offset", type=float, help="hours east of UTC for timestamps without a zone (default: box zone)")
    sp.add_argument("--shape", choices=["cleu", "raw"], default="cleu")
    sp.add_argument("--limit", type=int)
    sp.add_argument("--subevents", help="comma-separated subevent filter")
    sp.add_argument("--forever-player", metavar="PLAYER",
                    help="also synthesize Forever-style events (UNIT_SPELLCAST_*, UNIT_COMBAT, PLAYER_SWING) for this player: GUID, "
                         "'First Last', first name, Name-Realm, or 'auto' (log owner / characters.json)")
    sp.add_argument("--sv", help="SavedVariables whose player identity picks the player for --forever-player auto/name")
    sp = add("cl-compare", "cross-check a parsed file fixture against a /fdump cl session in DUMP", dump=False)
    sp.add_argument("fixture")
    sp.add_argument("dump")
    sp.add_argument("--session", type=int, default=0, help="1-based session index (default: last)")
    sp.add_argument("--json")
    sp.add_argument("--player", help="player (GUID, 'First Last', first name, Name-Realm): match UNIT_COMBAT(player) against file "
                    "damage/heal when the session has no CLEU (default: the SV identity / log owner)")
    sp = add("taint", "parse Logs/taint.log", dump=False)
    sp.add_argument("logfile")
    sp.add_argument("-o", "--out", help="JSON output")
    sp = add("errors", "summarize captured Lua errors / blocked actions in DUMP")
    sp.add_argument("--json")
    sp = add("ketho", "optional: compare against Ketho/BlizzardInterfaceResources (forever branch)")
    sp.add_argument("--ref", help="local checkout of the Resources folder (default: download from GitHub)")
    sp.add_argument("--branch", default="forever")
    sp.add_argument("--ui-source", help="wow-ui-source Interface dir: drop dump-only names that are Lua-defined there")
    sp.add_argument("--json")

    add("secrets", "secrets map: secrets.json + SECRETS.md (documented secrecy + runtime observations)", out="out/secrets")
    sp = add("migrate", "scan a legacy addon: per call site status, replacement, secrecy; TOC, events, taint patterns -> MIGRATION.md")
    sp.add_argument("addon")
    sp.add_argument("-o", "--out", default="out/migrate")
    sp = add("perfcheck", "static performance lint of an addon folder (PERFORMANCE.md rule): idle/unthrottled OnUpdate, _G walks, "
             "O(n) queue shifts, sorts in handlers, uncancelled tickers -> PERFCHECK.md", dump=False)
    sp.add_argument("addon")
    sp.add_argument("-o", "--out", help="markdown output (default stdout)")
    sp.add_argument("--json")
    sp.add_argument("--strict", action="store_true", help="exit non-zero on warnings too (errors always fail)")
    sp = add("unhash", "recover pre-v2.2.21 salted IdKeys from a capture (brute-force salt via known GUIDs) and write "
             "real/<run>/sv_raw/ with raw identities; originals untouched", dump=False)
    sp.add_argument("runs", nargs="*", help="run names under real/ (default: all)")
    sp.add_argument("--no-write", action="store_true")
    sp.add_argument("--out-json")
    sp = add("fixtures", "write a RAW fixture pack (api surface, env, combat/taint log verbatim, secrets map)")
    sp.add_argument("-o", "--out", default="fixtures/forever")
    sp.add_argument("--file", help="WoWCombatLog*.txt to copy (raw)")
    sp.add_argument("--taint", help="taint.log to copy (raw)")
    sp.add_argument("--max-lines", type=int, default=2000)
    sp = add("migrate-db", "rebuild tools/fdump/data/migration_shims.json from Blizzard_Deprecated* sources", dump=False)
    sp.add_argument("dirs", nargs="+", help="BRANCH=path/to/Interface/AddOns (e.g. forever=.cache/wus-forever/Interface/AddOns)")
    sp = add("verify", "secrets verifier: reconcile expected secrecy (70245 inventory) with observations -> verify.json + VERIFY.md",
             out="out/verify")
    sp.add_argument("--inventory", help="api-secrecy inventory TSV (default tools/fdump/data/api-secrecy-inventory-forever-70245.tsv)")
    sp.add_argument("--legacy", action="store_true", help="v2.1 verifier (dump docs, nil counted as clear)")
    sp = add("xref", "merge addon event log, CL sessions, verifier data and WoWCombatLog into timeline.jsonl + TIMELINE.md",
             out="out/xref")
    sp.add_argument("--file", help="Logs/WoWCombatLog*.txt (optional)")
    sp.add_argument("--player", help="your character: GUID, 'First Last', first name or Name-Realm (default: automatic from the SV's player identity, then tools/fdump/characters.json, then the log owner by unit flags 0x511)")
    sp.add_argument("--window-ms", type=int, default=750)
    sp.add_argument("--year", type=int)
    sp.add_argument("--client-log", help="Logs/Client.log: add client Lua errors to the timeline")
    add("perf", "ForeverDump self-performance (v2.2.3 perf monitor; legacy: profile snapshots) -> PERF.md + perf.json", out="out/perf")
    add("restrictions", "addon restriction flips + context + flip probe deltas -> restrictions.json + RESTRICTIONS.md", out="out/restrictions")
    sp = add("clientlog", "parse Logs/Client.log: Lua errors by call site, warnings, addon lines (DUMP optional: capture windows)",
             dump=False, out="out/clientlog")
    sp.add_argument("logfile")
    sp.add_argument("--dump", help="ForeverDump.lua: split errors inside/outside FD_Logs capture windows")
    sp.add_argument("--year", type=int)
    sp = add("size", "SavedVariables size per section (estimated bytes per subtree)")
    sp.add_argument("--depth", type=int, default=3)
    sp.add_argument("-o", "--out", help="text output file")

    add("ops", "operations matrix 'what you can do with a secret' -> ops.json + OPS.md", out="out/ops")
    add("lab", "workarounds lab -> lab.json + LAB.md (incl. 'Porting patterns for secret values')", out="out/lab")
    sp = add("combat", "combat probe set + detectability -> combat.json (guide --combat) + COMBAT-SECRETS.md", out="out/combat")
    sp.add_argument("--inventory")
    add("tokens", "unit token survey + scanner matrix -> tokens.json, UNIT-TOKENS.md, tokenscan.json, TOKENS.md", out="out/tokens")
    sp = add("knowledge", "spell knowledge per build + parser lint/regression + reality cross-check vs the combat log (--file) + "
             "tooltip cooldown-line evidence -> knowledge.json + KNOWLEDGE.md", out="out/knowledge")
    sp.add_argument("--file", help="Logs/WoWCombatLog*.txt (cross-check aura durations, cooldowns, amounts; aura id map)")
    sp.add_argument("--player", help="GUID / name (default automatic)")
    sp.add_argument("--year", type=int)
    sp.add_argument("--utc-offset", type=float, help="hours east of UTC for the file timestamps (default: box zone)")
    sp = add("verify-live", "join the live verification ring (ForeverDumpDB.verify; replay verdicts for older captures) with the combat "
             "log -> VERIFY.md, verify.json, knowledge-patch.json, KnowledgePatch.lua", out="out/verify-live")
    sp.add_argument("--file", required=True, help="Logs/WoWCombatLog*.txt")
    sp.add_argument("--player", help="GUID / name (default automatic)")
    sp.add_argument("--year", type=int)
    sp.add_argument("--utc-offset", type=float)
    sp.add_argument("--write-patch", metavar="LUA", help="also write the patch here (e.g. ForeverDump/Data/KnowledgePatch.lua)")
    sp = add("replay", "sealed replay tape (ForeverDumpLogDB.replay) -> REPLAY.md + replay.json; optional CLEU join",
             out="out/replay")
    sp.add_argument("--file", help="Logs/WoWCombatLog*.txt for cast-sync anchor join")
    sp = add("correlate", "data-driven co-occurrence miner + higher-order chains (v2.2.5) -> CORRELATE.md + correlate.json",
             out="out/correlate")
    sp.add_argument("--file", required=True, help="Logs/WoWCombatLog*.txt for DUMP")
    sp.add_argument("--with", dest="with_", action="append", default=[], metavar="LABEL=SV::LOG", help="more captures (holdout)")
    sp.add_argument("--label", default="capture")
    sp.add_argument("--player", help="GUID / name (default automatic)")
    sp.add_argument("--year", type=int)
    sp.add_argument("--min-support", type=int, default=3)
    sp.add_argument("--quick", action="store_true", help="v2.2.5: tight beams/windows/shuffles for fast iteration (default: full)")
    sp.add_argument("--no-higher", action="store_true", help="v2.2.5: skip higher-order chain mining")
    sp = add("analyze", "whole offline pipeline -> ANALYSIS.md (ranked leads with severity/evidence/timestamps), analysis.json, "
             "VERIFY.md, knowledge patch", out="out/analysis")
    sp.add_argument("--log", "--file", dest="file", required=True, help="Logs/WoWCombatLog*.txt")
    sp.add_argument("--taint", help="Logs/taint.log")
    sp.add_argument("--history", action="append", default=[], metavar="LABEL=SV::LOG", help="earlier captures (trending + miner holdout)")
    sp.add_argument("--label", default="capture")
    sp.add_argument("--baseline", help="baseline.json for secrecy flips (default: newest fixtures/baselines/<build>)")
    sp.add_argument("--player", help="GUID / name (default automatic)")
    sp.add_argument("--year", type=int)
    sp.add_argument("--utc-offset", type=float)
    sp.add_argument("--write-patch", metavar="LUA", help="also write the knowledge patch here (e.g. ForeverDump/Data/KnowledgePatch.lua)")
    sp.add_argument("--write-seed", action="store_true", help="adopt the merged seeds: ForeverDump/Data/spell-timing.lua + learned-seed.lua "
                    "(+ JSON mirrors). Idempotent per capture; conflicts stay flagged, never overwritten")
    sp.add_argument("--quick", action="store_true", help="v2.2.5: correlate higher-order in quick profile (default: full, heavy)")
    sp.add_argument("--no-higher", action="store_true", help="v2.2.5: skip higher-order chain mining in analyze")
    sp = add("containers", "container-state schema (field-by-field five-state codes, flags, keys; partial secrets) -> "
             "CONTAINERS.md + containers.json (guide --containers), diffed against fixtures/baselines/<build>/containers.json",
             out="out/containers")
    sp.add_argument("--baseline", help="containers.json baseline (default: next to the newest fixtures/baselines/<build>/baseline.json)")
    sp.add_argument("--write-baseline", metavar="DIR", help="also store this schema as DIR/<build>/containers.json")
    sp = add("inference", "inference rules + hybrid state machine vs the file combat log -> inference.json, INFERENCE.md, hsm.json "
             "(guide --hsm), HSM.md", out="out/inference")
    sp.add_argument("--file", help="Logs/WoWCombatLog*.txt (ground truth; also used for the offline HSM replay)")
    sp.add_argument("--player", help="GUID, 'First Last', first name or Name-Realm (default: automatic from the SV's player identity, then tools/fdump/characters.json, then the log owner by unit flags 0x511)")
    sp.add_argument("--year", type=int)
    sp.add_argument("--utc-offset", type=float, help="hours east of UTC for the file timestamps (default: box zone)")
    sp = add("coverage", "combat-event coverage matrix (log truth vs live events/API) + HSM attribution before/after + C_DamageMeter "
             "reconciliation -> COVERAGE.md, coverage.json, coverage-guide.json (guide --coverage)", out="out/coverage")
    sp.add_argument("--file", help="Logs/WoWCombatLog*.txt (ground truth)")
    sp.add_argument("--player", help="GUID / name (default automatic)")
    sp.add_argument("--year", type=int)
    sp.add_argument("--utc-offset", type=float, help="hours east of UTC for the file timestamps (default: box zone)")
    sp = add("drift", "drift between two baselines / SVs (OLD NEW) -> DRIFT.md + drift.json", dump=False)
    sp.add_argument("old")
    sp.add_argument("new")
    sp.add_argument("-o", "--out", default="out/drift")
    sp = add("baseline", "write the baseline signature of DUMP to fixtures/baselines/<build>/baseline.json")
    sp.add_argument("-o", "--out", default="fixtures/baselines")
    sp = add("guide", "regenerate SECRETS-GUIDE.html from the converted SV (lab/verify/combat/hsm/tokens/inference JSON)",
             out="out/guide")
    sp.add_argument("--file", help="WoWCombatLog for the --hsm JSON (inference scoring / replay)")
    sp.add_argument("--player", help="GUID, 'First Last', first name or Name-Realm (default: automatic from the SV's player identity, then tools/fdump/characters.json, then the log owner by unit flags 0x511)")
    sp.add_argument("--year", type=int)
    sp.add_argument("--html", help="output HTML (default <out>/SECRETS-GUIDE.html)")
    sp.add_argument("--analysis", help="analysis.json from fdump.py analyze (tracker / known-answer / verification / cd-line sections)")

    sp = add("master-guide", "cumulative master secrets guide from every run under real/ -> docs/SECRETS-GUIDE.html + .md + "
             "docs/secrets-guide-state.json (value x unit family x context; HSM status; changed since last run)", dump=False)
    sp.add_argument("--root", default=None, help="repo root holding real/ and docs/ (default: this checkout)")
    sp.add_argument("--check", action="store_true", help="do not write; exit 1 if the guide is stale (differs from the generator "
                    "output or is older than the newest run data)")

    sp = add("learned-auras", "regenerate ForeverDump/Data/LearnedAuras.lua (GENERATED per-build learned auras from every "
             "stored combat log; optional offline source for the aura-presence candidate list)", dump=False)
    sp.add_argument("--root", default=None)

    a = p.parse_args(argv)

    if a.cmd == "learned-auras":
        from fdump import learnedauras as la
        return la.main(["--root", a.root] if a.root else [])

    if a.cmd == "master-guide":
        from fdump import master_guide as mg
        root = a.root or mg.ROOT
        if a.check:
            probs = mg.check(root)
            for x in probs:
                print("STALE: " + x)
            print("master guide: %s" % ("OK (fresh)" if not probs else "STALE (%d problem(s)); run python3 tools/fdump.py master-guide" % len(probs)))
            return 1 if probs else 0
        files, st = mg.write(root)
        print("master guide: %d rows from %d run(s) (newest %s); status %s; %d change(s) since the previous run; wrote %s" % (
            st["rowCount"], len(st["runs"]), st["newestRun"], ", ".join("%s=%d" % kv for kv in st["tally"].items()),
            len(st["changes"]), ", ".join(sorted(files))))
        return 0

    if a.cmd == "drift":
        old, new = driftmod.load(a.old), driftmod.load(a.new)
        r = driftmod.compare(old, new)
        os.makedirs(a.out, exist_ok=True)
        export_json.write_json(os.path.join(a.out, "drift.json"), r)
        _write(os.path.join(a.out, "DRIFT.md"), driftmod.markdown(r))
        print(json.dumps({k: (len(v) if isinstance(v, list) else v) for k, v in r.items() if k not in ("old", "new", "coverage")}, indent=1))
        print("wrote drift.json + DRIFT.md to", a.out)
        return 0

    if a.cmd == "diff":
        r = diffmod.diff(Dump.load(a.old), Dump.load(a.new))
        md = diffmod.markdown(r)
        if a.out:
            _write(a.out, md)
            print("wrote", a.out)
        else:
            print(md)
        if a.json:
            export_json.write_json(a.json, r)
        return 0
    if a.cmd == "combatlog":
        fx = combatlog.parse_file(a.logfile, year=a.year,
                                  utc_offset_sec=None if a.utc_offset is None else a.utc_offset * 3600,
                                  shape=a.shape, limit=a.limit,
                                  subevents=set(a.subevents.split(",")) if a.subevents else None)
        if a.forever_player:
            pg, pinfo = charmod.resolve(None if a.forever_player == "auto" else a.forever_player, fx,
                                        Dump.load(a.sv) if a.sv else None)
            print(charmod.describe(pg, pinfo))
            fx = combatlog.synthesize_forever(fx, pg)
        if a.out.endswith(".lua"):
            mocks.write_lua(a.out, "WoWCombatLog fixture from %s" % os.path.basename(a.logfile), fx)
        else:
            export_json.write_json(a.out, fx)
        print("wrote %s: %d CLEU events (%s), %d non-CLEU lines, header %s" % (
            a.out, fx["total"], ", ".join("%s=%d" % kv for kv in sorted(fx["counts"].items(), key=lambda x: -x[1])[:8]),
            len(fx["events"]) - fx["total"], fx["header"]))
        return 0
    if a.cmd == "cl-compare":
        with open(a.fixture, encoding="utf-8") as f:
            fx = json.load(f)
        d = Dump.load(a.dump)
        sessions = as_list(d.combatlog.get("sessions"))
        if not sessions:
            print("no /fdump cl sessions in", a.dump)
            return 2
        if a.session:
            sess = sessions[a.session - 1]
        else:  # newest session with legacy CLEU entries, else the newest session
            with_cleu = [s_ for s_ in sessions if (s_.get("cleuTotal") or 0) > 0]
            sess = (with_cleu or sessions)[-1]
        if (sess.get("cleuTotal") or 0) == 0:
            pg, pinfo = charmod.resolve(a.player, fx, d)
            if not pg:
                print("session has no legacy CLEU entries and no player was found; pass --player")
                return 2
            print(charmod.describe(pg, pinfo))
            r = combatlog.compare_forever(fx, sess, pg)
            print("forever mode: %(addonUnitCombat)d addon UNIT_COMBAT(player), %(fileDamageHealOnPlayer)d file damage/heal "
                  "on player, matched %(matched)d (%(secretAmounts)d secret amounts), addon-only %(addonOnly)d, "
                  "file-only %(fileOnly)d" % r)
            if a.json:
                export_json.write_json(a.json, r)
            return 0
        r = combatlog.compare(fx, sess)
        print("matched %d, addon-only %d, file-only %d" % (r["matched"], r["addonOnly"], r["fileOnly"]))
        for subev, d_ in r["arityMismatch"].items():
            print("  arity %s: %s" % (subev, d_))
        for fd in r["fieldDiffs"][:20]:
            print("  diff %s arg %d: addon=%r file=%r" % (fd["sub"], fd["pos"], fd["addon"], fd["file"]))
        if a.json:
            export_json.write_json(a.json, r)
        return 0
    if a.cmd == "perfcheck":
        fs = perfcheck.scan(a.addon)
        md = perfcheck.markdown(fs, "Performance lint: %s" % os.path.basename(os.path.abspath(a.addon)))
        if a.out:
            _write(a.out, md)
            print("wrote", a.out)
        else:
            sys.stdout.write(md)
        if a.json:
            export_json.write_json(a.json, {"rule": perfcheck.RULE, "counts": perfcheck.summary(fs), "findings": fs})
        c = perfcheck.summary(fs)
        print("perfcheck: %d error(s), %d warning(s), %d note(s)" % (c["error"], c["warn"], c["note"]))
        return 1 if c["error"] or (a.strict and c["warn"]) else 0
    if a.cmd == "migrate-db":
        dirs = [tuple(d.split("=", 1)) for d in a.dirs]
        db = migratemod.build_shim_db(dirs)
        path = os.path.join(migratemod.DATA, "migration_shims.json")
        export_json.write_json(path, {"_about": "parsed from Blizzard_Deprecated* (%s)" % ", ".join(b for b, _ in dirs), "functions": db})
        print("wrote %d shim entries to %s" % (len(db), path))
        return 0
    if a.cmd == "taint":
        r = taintlog.parse(a.logfile)
        print(taintlog.text_summary(r))
        if a.out:
            export_json.write_json(a.out, r)
            print("wrote", a.out)
        return 0

    if a.cmd == "unhash":
        raise SystemExit(unhashmod.main((a.runs or []) + (["--no-write"] if a.no_write else []) + (
            ["--out-json", a.out_json] if a.out_json else [])))

    dump = Dump.load(a.dump)
    if a.cmd == "info":
        print(info(dump))
    elif a.cmd == "json":
        files = export_json.export(dump, a.out)
        print("wrote %d JSON files to %s" % (len(files), a.out))
    elif a.cmd == "luals":
        files = luals.generate(dump, a.out)
        print("wrote %d LuaLS stub files to %s (add it to workspace.library; see .luarc.json.example)" % (len(files), a.out))
    elif a.cmd == "luacheck":
        _write(a.out, luacheck_gen.generate(dump, std_name=a.std))
        print("wrote", a.out)
    elif a.cmd == "mocks":
        files = mocks.generate(dump, a.out)
        print("wrote %d mock files to %s" % (len(files), a.out))
    elif a.cmd == "all":
        print(info(dump))
        export_json.export(dump, os.path.join(a.out, "json"))
        luals.generate(dump, os.path.join(a.out, "luals"))
        _write(os.path.join(a.out, ".luacheckrc"), luacheck_gen.generate(dump))
        mocks.generate(dump, os.path.join(a.out, "mocks"))
        smap = secretsmod.build(dump)
        export_json.write_json(os.path.join(a.out, "secrets", "secrets.json"), smap)
        _write(os.path.join(a.out, "secrets", "SECRETS.md"), secretsmod.to_markdown(smap))
        print("wrote json/, luals/, .luacheckrc, mocks/, secrets/ under", a.out)
        # v2.2 reports + automatic drift against the newest stored baseline (fixtures/baselines/<build>/)
        rows = probes.ops(dump)
        _write(os.path.join(a.out, "ops", "OPS.md"), probes.ops_markdown(rows))
        export_json.write_json(os.path.join(a.out, "lab", "lab.json"), guidejson.lab(dump))
        _write(os.path.join(a.out, "lab", "LAB.md"), probes.lab_markdown(probes.lab(dump)))
        _combat(dump, os.path.join(a.out, "combat"), Inventory())
        _tokens(dump, os.path.join(a.out, "tokens"))
        _containers(dump, os.path.join(a.out, "containers"))
        _perf(dump, os.path.join(a.out, "perf"))
        _knowledge(dump, os.path.join(a.out, "knowledge"), None, None, None)
        new = driftmod.from_dump(dump)
        ref = _latest_baseline(exclude_source=None)
        if ref:
            r = driftmod.compare(driftmod.load(ref), new)
            export_json.write_json(os.path.join(a.out, "drift", "drift.json"), r)
            _write(os.path.join(a.out, "drift", "DRIFT.md"), driftmod.markdown(r))
            print("drift vs %s: build bump %s, newly secret %d, newly clear %d, APIs +%d/-%d -> %s" % (
                ref, r["buildBump"], len(r["newlySecret"]), len(r["newlyClear"]), len(r["apisAdded"]), len(r["apisRemoved"]),
                os.path.join(a.out, "drift", "DRIFT.md")))
        else:
            print("drift: no stored baseline under fixtures/baselines/ (fdump.py baseline DUMP)")
    elif a.cmd == "ops":
        rows = probes.ops(dump)
        export_json.write_json(os.path.join(a.out, "ops.json"), rows)
        _write(os.path.join(a.out, "OPS.md"), probes.ops_markdown(rows))
        print("ops matrix: %d row(s); wrote ops.json + OPS.md to %s" % (len(rows), a.out))
    elif a.cmd == "lab":
        items = probes.lab(dump)
        export_json.write_json(os.path.join(a.out, "lab.json"), guidejson.lab(dump))
        _write(os.path.join(a.out, "LAB.md"), probes.lab_markdown(items))
        print("lab: %d approach(es); wrote lab.json + LAB.md to %s" % (len(items), a.out))
    elif a.cmd == "combat":
        _combat(dump, a.out, Inventory(a.inventory) if a.inventory else Inventory())
    elif a.cmd == "tokens":
        _tokens(dump, a.out)
    elif a.cmd == "containers":
        _containers(dump, a.out, a.baseline, a.write_baseline)
    elif a.cmd == "knowledge":
        _knowledge(dump, a.out, a.file, a.player, a.year, getattr(a, "utc_offset", None))
    elif a.cmd == "verify-live":
        _verify_live(dump, a)
    elif a.cmd == "replay":
        dump = Dump.load(a.dump)
        out = a.out or "out/replay"
        res = replaymod.write(dump, out, combatlog_path=getattr(a, "file", None))
        sm = res.get("summary") or {}
        print("replay: %d session(s), %s records; rawIds=%s conflicts=%s; wrote REPLAY.md + replay.json to %s"
              % (res.get("sessionCount") or 0, sm.get("totalRecords"), sm.get("rawIdentities"),
                 sm.get("decideConflicts"), out))
    elif a.cmd == "correlate":
        _correlate(dump, a)
    elif a.cmd == "analyze":
        _analyze(dump, a)
    elif a.cmd == "inference":
        _inference(dump, a.out, a.file, a.player, a.year, getattr(a, "utc_offset", None))
    elif a.cmd == "coverage":
        _coverage(dump, a.out, a.file, a.player, a.year, getattr(a, "utc_offset", None))
    elif a.cmd == "baseline":
        base = driftmod.from_dump(dump)
        path = driftmod.save(base, os.path.join(a.out, str(base.get("build"))))
        print("baseline for build %s (docs %s, %d secrecy keys, %d present APIs) -> %s" % (
            base.get("build"), (base.get("docs") or {}).get("hash"), len(base["secrecy"]), len(base["present"]), path))
    elif a.cmd == "guide":
        _guide(dump, a)
    elif a.cmd == "check":
        r = apicheck.run(dump, a.addon)
        print(apicheck.text(r))
        if a.json:
            export_json.write_json(a.json, r)
        if r["counts"]["error"] or (a.strict and r["counts"]["warn"]):
            return 1
    elif a.cmd == "errors":
        errs, blocked = as_list(dump.log.get("errors")), as_list(dump.log.get("blocked"))
        addon_re = re.compile(r"[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\]")

        def attribute(e):
            # skip ForeverDump's own handler frames (v2.0 recorded them as the culprit)
            for text in (e.get("message"), e.get("stack")):
                for name in addon_re.findall(str(text or "")):
                    if name != "ForeverDump":
                        return name
            return e.get("addon")

        for e in sorted(errs, key=lambda e: -(e.get("count") or 0)):
            e["attributedAddon"] = attribute(e)
            note = "  (addon %s)" % e["attributedAddon"] if e.get("attributedAddon") else ""
            if e.get("addon") and e.get("addon") != e.get("attributedAddon"):
                note += "  [dump said %s: its own handler frames, fixed in 2.1]" % e["addon"]
            print("[%dx] %s%s" % (e.get("count", 1), e.get("message"), note))
            tr = re.search(r"\[C\]: \?\n\[C\]: in function [`'](\w+)'", str(e.get("stack") or ""))
            if tr and "attempt to call a nil value" in str(e.get("message")):
                e["class"] = "c-trampoline-nil-call"
                print("    class: nil call raised inside the C function %s (hooksecurefunc trampoline; see CHANGES 2.2)" % tr.group(1))
            if e.get("duringCapture") or e.get("taintLog"):
                print("    during capture: %s, taintLog=%s" % (e.get("duringCapture"), e.get("taintLog")))
            if e.get("origins"):
                print("    origins (%d):" % len(e["origins"]))
                for o, n in sorted(e["origins"].items(), key=lambda x: -x[1]):
                    print("      %4dx %s" % (n, o))
            if e.get("stack"):
                print("    " + str(e["stack"]).replace("\n", "\n    "))
        for b in blocked:
            ts = b.get("time")
            from fdump import timefmt
            when = timefmt.clock(ts, "%Y-%m-%d %H:%M:%S") if isinstance(ts, (int, float)) else ts
            res_ = b.get("resolved")
            if not res_ and (b.get("args") or {}).get("addon") == "ForeverDump" and "UNKNOWN" in str((b.get("args") or {}).get("function")):
                site = b.get("site") or blocked_site(b.get("ownStack"))
                if site:
                    # v2.2.7: attribute from the own call site (run 6: Tokens.lua:296 / WorldCapture.lua:141 = CheckInteractDistance)
                    res_ = "site %s%s" % (site, KNOWN_BLOCK_SITES.get(site, ""))
                else:
                    res_ = "unattributed (no own stack); run-3 analysis: CombatProbe record() -> CheckInteractDistance on a friendly/self unit in combat (protected for non-hostile units)"
            print("%s %s %s%s%s" % (when, b.get("event"), b.get("args"), " (in combat)" if b.get("inCombat") else "",
                                  (" = " + res_) if res_ else ""))
        bp = (dump.db.get("blockedPaths") if isinstance(getattr(dump, "db", None), dict) else None) or {}
        for build, paths in (bp.items() if isinstance(bp, dict) else []):
            for path, r in (paths or {}).items():
                print("learned combat-blocked path [%s] %s: %sx, units %s" % (build, path, r.get("n"), r.get("units")))
        per = {}
        for e in errs:
            per.setdefault(e.get("attributedAddon") or "?", [0, 0])[0] += e.get("count") or 1
        for b in blocked:
            if "_ACTION_" in str(b.get("event")):
                per.setdefault((b.get("args") or {}).get("addon") or "?", [0, 0])[1] += 1
        print("per addon (errors, blocked actions): " + ", ".join("%s %d/%d" % (k, v[0], v[1]) for k, v in sorted(per.items())))
        print("%d unique errors, %d blocked/forbidden/warning events" % (len(errs), len(blocked)))
        if a.json:
            export_json.write_json(a.json, {"errors": errs, "blocked": blocked, "perAddon": per})
    elif a.cmd == "secrets":
        smap = secretsmod.build(dump)
        export_json.write_json(os.path.join(a.out, "secrets.json"), smap)
        _write(os.path.join(a.out, "SECRETS.md"), secretsmod.to_markdown(smap))
        print(json.dumps(smap["headline"], indent=1))
        print("wrote secrets.json + SECRETS.md to", a.out)
    elif a.cmd == "fixtures":
        # v2.2.21: raw fixture pack (no anonymization; user decision 2026-10-09)
        os.makedirs(a.out, exist_ok=True)
        written = []
        fixturepack.write_json(os.path.join(a.out, "environment.json"), fixturepack.environment(dump))
        fixturepack.write_json(os.path.join(a.out, "api-surface.json"), fixturepack.api_surface(dump))
        smap = secretsmod.build(dump)
        for k in ("observations", "liveContradictions", "sessions", "fieldVerify"):
            smap.pop(k, None)  # runtime data can carry unit/context info: keep the documented map only
        def _interesting(e):
            e.pop("verify", None)
            if e.get("secrecy") not in (None, "unspecified") or e.get("restrictions") or e.get("conditions"):
                return True
            if e.get("secretArguments") == "NotAllowed" or any(x.get("secrecy") not in (None, "unspecified")
                                                                for x in (e.get("returns") or []) + (e.get("payload") or [])):
                return True
            return any(k not in ("SecretArguments",) for k in (e.get("flags") or {}))
        dropped = {}
        for sect in ("functions", "widgetMethods", "events"):
            tab = smap.get(sect) or {}
            keep = {k: v for k, v in tab.items() if isinstance(v, dict) and _interesting(v)}
            dropped[sect] = len(tab) - len(keep)
            smap[sect] = keep
        smap["fixtureNote"] = "secrecy-relevant entries only; dropped (no secrecy/restriction data): %s" % dropped
        with open(os.path.join(a.out, "secrets-documented.json"), "w", encoding="utf-8") as f:
            json.dump(smap, f, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        written += ["environment.json", "api-surface.json", "secrets-documented.json"]
        if a.file:
            nl = fixturepack.combat_log(a.file, os.path.join(a.out, "WoWCombatLog.txt"), a.max_lines)
            fx = combatlog.parse_file(os.path.join(a.out, "WoWCombatLog.txt"))
            mocks.write_lua(os.path.join(a.out, "combatlog_file.lua"), "raw WoWCombatLog fixture (%s)" % dump.build_label(), fx)
            written += ["WoWCombatLog.txt (%d lines)" % nl, "combatlog_file.lua (%d CLEU events)" % fx["total"]]
        if a.taint:
            fixturepack.taint_log(a.taint, os.path.join(a.out, "taint.log"))
            written.append("taint.log")
        fixturepack.write_json(os.path.join(a.out, "pack.json"), {"build": dump.build_label(), "files": written, "raw": True})
        print("wrote", ", ".join(written), "to", a.out, "(raw)")
    elif a.cmd == "migrate":
        rep = migratemod.Migrator(dump).scan(a.addon)
        export_json.write_json(os.path.join(a.out, "migration.json"), rep)
        _write(os.path.join(a.out, "MIGRATION.md"), migratemod.markdown(rep))
        print(json.dumps({k: rep[k] for k in ("apiCounts", "callSiteCounts", "eventCounts")}, indent=1))
        print("TOC findings %d, taint patterns %d, secret-flow findings %d" % (len(rep["toc"]), len(rep["taint"]), len(rep["secretFlow"])))
        print("wrote migration.json + MIGRATION.md to", a.out)
    elif a.cmd == "verify":
        smap = secretsmod.build(dump)
        legacy = secretsmod.verify_report(smap)
        inv = Inventory(a.inventory) if a.inventory else Inventory()
        if a.legacy or not inv:
            rep = legacy
            export_json.write_json(os.path.join(a.out, "verify.json"), rep)
            _write(os.path.join(a.out, "VERIFY.md"), secretsmod.verify_markdown(rep))
        else:
            rep = verify22.reconcile(dump, inv)
            rep["legacyStatusCounts"] = legacy["statusCounts"]
            export_json.write_json(os.path.join(a.out, "verify.json"), rep)
            _write(os.path.join(a.out, "VERIFY.md"), verify22.markdown(rep, before=legacy["statusCounts"]))
        print(json.dumps({"statusCounts": rep["statusCounts"], "legacyVerifier": legacy["statusCounts"], "coverage": rep["coverage"],
                          "liveContradictions": len(rep["liveContradictions"])}, indent=1))
        print("wrote verify.json + VERIFY.md to", a.out)
    elif a.cmd == "xref":
        fx = combatlog.parse_file(a.file, year=a.year) if a.file else None
        guid, pinfo = charmod.resolve(a.player, fx, dump)
        note = charmod.describe(guid, pinfo) if guid else pinfo.get("note")
        client = clientlog.parse(a.client_log, year=a.year or clientlog.anchor_year(dump), utc_offset_sec=clientlog.anchor_offset(dump)) if a.client_log else None
        if not guid:
            for sess in as_list(dump.combatlog.get("sessions")):
                guid = guid or sess.get("playerGUID") or (sess.get("meta") or {}).get("playerGUID")
        res = xrefmod.build(dump, fx, guid, a.window_ms, client=client)
        if note:
            res["playerNote"] = note
            print(note)
        os.makedirs(a.out, exist_ok=True)
        xrefmod.write_jsonl(os.path.join(a.out, "timeline.jsonl"), res)
        _write(os.path.join(a.out, "TIMELINE.md"), xrefmod.markdown(res))
        print(json.dumps({"bySource": res["bySource"], "matches": res["stats"], "segments": len(res["segments"]),
                          "player": guid}, indent=1))
        print("wrote timeline.jsonl + TIMELINE.md to", a.out)
    elif a.cmd == "perf":
        _perf(dump, a.out)
    elif a.cmd == "restrictions":
        r = restrmod.summarize(dump)
        off = None
        for sess in as_list(dump.combatlog.get("sessions")) + as_list(dump.record.get("sessions")):
            if isinstance(sess.get("anchor"), dict):
                off = sess["anchor"].get("utcOffset")
                break
        os.makedirs(a.out, exist_ok=True)
        export_json.write_json(os.path.join(a.out, "restrictions.json"), {k: v for k, v in r.items() if k not in ("items", "markerItems")})
        _write(os.path.join(a.out, "RESTRICTIONS.md"), restrmod.markdown(r, off))
        print(json.dumps({"origin": r["origin"], "flips": r["flips"], "byType": {k: {"flips": v["flips"], "states": v["states"],
                          "activeSec": v["activeSec"]} for k, v in r["byType"].items()}, "markers": r["markers"],
                          "probeDeltas": len(r["probeDeltas"])}, indent=1, default=str))
    elif a.cmd == "clientlog":
        d = Dump.load(a.dump) if a.dump else None
        off = clientlog.anchor_offset(d)
        entries = clientlog.parse(a.logfile, year=a.year or clientlog.anchor_year(d), utc_offset_sec=off)
        s2 = clientlog.summarize(entries, clientlog.capture_windows(d))
        s2["utcOffsetSec"] = off
        os.makedirs(a.out, exist_ok=True)
        export_json.write_json(os.path.join(a.out, "clientlog.json"), s2)
        _write(os.path.join(a.out, "CLIENTLOG.md"), clientlog.markdown(s2))
        print(json.dumps({k: s2[k] for k in ("lines", "first", "last", "kinds", "luaErrors", "cTrampolineNilCalls")}, indent=1))
        print("wrote clientlog.json + CLIENTLOG.md to", a.out)
    elif a.cmd == "size":
        r = svsize.breakdown(dump.raw, a.dump, depth=a.depth)
        t = svsize.text(r)
        print(t)
        if a.out:
            _write(a.out, t + "\n")
    elif a.cmd == "ketho":
        r = ketho.compare(dump, ref=a.ref, branch=a.branch, ui_source=a.ui_source)
        print(ketho.text(r))
        if a.json:
            export_json.write_json(a.json, r)
    return 0


if __name__ == "__main__":
    sys.exit(main())
