"""Growing generated aura LIBRARY for the aura-presence candidate list (v2.2.28):
ForeverDump/Data/LearnedAuras.lua, GENERATED - never hand-edited - by `python3 tools/fdump.py learned-auras`.

Merged from every stored capture that passes the unhash inclusion gate (real/<run>/):
  * combat log (WoWCombatLog.txt): every aura applied (incl. enemy debuffs / other classes' buffs never readable live):
    n, median duration (applied -> removed on the same unit, <= 1 h), name; cast -> aura pairs (a SPELL_CAST_SUCCESS
    followed <= PAIR_WINDOW s by an aura applied BY THE SAME SOURCE; self / target counted);
  * SV (ForeverDumpDB): refLearned[build].auraDur (OOC-enumerated durations), refLearned[build].spellClass (class),
    knowledge[build] parsed aura durations (own spellbook), auraLearned / auraPairs (live learned, v2.2.27+).
Every entry records the client builds that confirmed it ("70334,70338"); the addon treats an entry not confirmed on
the running build as provisional. Ranks: entries sharing a spell name get base = the lowest spellID of that name, so
the addon probes only the plausible ranks of one ability (AuraPresence rank grouping).
Deterministic (sorted, no timestamps; inputs named by sha256 prefix): tests/test_learnedauras.py regenerates and
compares byte for byte, so the file is refreshed with every stored run. Optional: delete it or auraPresence.offline=false."""
import argparse
import collections
import hashlib
import os
import re
import sys

from . import refdata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "ForeverDump", "Data", "LearnedAuras.lua")
SCHEMA = 2
GENERATOR = "tools/fdump/learnedauras.py v2"
MAX_DUR = 3600.0
PAIR_WINDOW = 0.6
BUILD_RE = re.compile(r'lastClientBuild\W{0,8}(\d{5,})')   # plain SV and SVPack-packed (lastClientBuild=\"70338\")
META_BUILD_RE = re.compile(r'\["build"\]\s*=\s*"(\d{5,})"')


def run_build(run_dir):
    sv = os.path.join(run_dir, "sv", "ForeverDump.lua")
    if not os.path.exists(sv):
        return None
    with open(sv, errors="replace") as f:
        head = f.read()
    m = BUILD_RE.search(head) or META_BUILD_RE.search(head)
    return m.group(1) if m else None


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def _entry(lib, sid, name=None):
    r = lib["spells"].get(sid)
    if r is None:
        r = lib["spells"][sid] = {"n": 0, "durs": [], "name": None, "builds": set(), "cls": collections.Counter(), "src": set()}
    if name and not r["name"]:
        r["name"] = name
    return r


EARLY = 0.05   # s an aura row may precede its cast row


def _pair(lib, cast, aura, slf, build):
    pr = lib["pairs"][cast].setdefault(aura, {"n": 0, "self": 0, "target": 0, "builds": set()})
    pr["n"] += 1
    pr["self" if slf else "target"] += 1
    pr["builds"].add(build)


def mine_log(path, build, lib):
    open_ = {}
    last_cast = {}                     # source guid -> (t, castSid)
    recent = collections.defaultdict(list)   # source guid -> [(t, auraSid, self)]: the log writes the aura up to a few ms
    #                                          BEFORE the cast row (run 22: 1238931 at .243, 17364 cast at .245)
    for t, p in refdata.lines(path):
        if t is None or not p or len(p) < 11:
            continue
        ev = p[0]
        if ev == "SPELL_CAST_SUCCESS":
            try:
                c = int(p[9])
            except ValueError:
                continue
            last_cast[p[1]] = (t, c)
            for ta, a, slf in recent.pop(p[1], []):
                if t - ta <= EARLY:
                    _pair(lib, c, a, slf, build)
            continue
        if ev not in ("SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED"):
            continue
        try:
            sid = int(p[9])
        except ValueError:
            continue
        key = (sid, p[5])
        if ev == "SPELL_AURA_APPLIED":
            r = _entry(lib, sid, p[10])
            r["n"] += 1
            r["builds"].add(build)
            r["src"].add("cl")
            open_[key] = t
            lc = last_cast.get(p[1])
            if lc and 0 <= t - lc[0] <= PAIR_WINDOW:
                _pair(lib, lc[1], sid, p[5] == p[1], build)
            else:
                rc = recent[p[1]]
                rc.append((t, sid, p[5] == p[1]))
                del rc[:-4]
        else:
            t0 = open_.pop(key, None)
            if t0 is not None and 0 < t - t0 <= MAX_DUR:
                _entry(lib, sid, p[10])["durs"].append(t - t0)


def mine_sv(path, build, lib):
    from .svcache import parse_file
    try:
        raw = parse_file(path)
    except Exception:
        return
    db = (raw or {}).get("ForeverDumpDB") or {}
    for b, L in ((db.get("refLearned") or {}).items()):
        if not isinstance(L, dict):
            continue
        for sid, r in (L.get("auraDur") or {}).items():
            e = _entry(lib, int(sid))
            e["builds"].add(str(b))
            e["src"].add("sv:ooc")
            if isinstance(r, dict) and isinstance(r.get("min"), (int, float)):
                e["durs"].append(float(r["min"]))
        for sid, by in (L.get("spellClass") or {}).items():
            if int(sid) in lib["spells"] and isinstance(by, dict):
                for cls, n in by.items():
                    lib["spells"][int(sid)]["cls"][cls] += n if isinstance(n, (int, float)) else 1
    for b, K in ((db.get("knowledge") or {}).items()):
        for sid, v in ((K or {}).get("spells") or {}).items():
            d = (v or {}).get("data") or {}
            pa = d.get("parsed") or {}
            if isinstance(pa.get("auraDuration"), (int, float)) and pa["auraDuration"] > 0:
                e = _entry(lib, int(sid), d.get("info.name") if isinstance(d.get("info.name"), str) else None)
                e["builds"].add(str(b))
                e["src"].add("sv:spellbook")
                e["durs"].append(float(pa["auraDuration"]))
    for b, L in ((db.get("auraLearned") or {}).items()):
        if isinstance(L, dict):
            for sid, r in L.items():
                if isinstance(r, dict) and not r.get("prov"):
                    e = _entry(lib, int(sid), r.get("name"))
                    e["builds"].add(str(b))
                    e["src"].add("sv:live")


def collect(root=ROOT, gate=True):
    from . import inclusion
    real = os.path.join(root, "real")
    runs = sorted(n for n in os.listdir(real) if os.path.isfile(os.path.join(real, n, "WoWCombatLog.txt")))
    if gate:
        runs = inclusion.filter_runs(runs)   # unhash inclusion gate (HARD RULE 2026-10-09)
    lib = {"spells": {}, "pairs": collections.defaultdict(dict)}
    inputs, skipped = [], []
    for run in runs:
        b = run_build(os.path.join(real, run))
        if not b:
            skipped.append(run)
            continue
        log = os.path.join(real, run, "WoWCombatLog.txt")
        mine_log(log, b, lib)
        mine_sv(os.path.join(real, run, "sv", "ForeverDump.lua"), b, lib)
        inputs.append((run, b, sha(log)[:16]))
    # ranks: entries sharing a name -> base = lowest spellID of that name
    by_name = collections.defaultdict(list)
    for sid, r in lib["spells"].items():
        if r["name"]:
            by_name[r["name"]].append(sid)
    for name, sids in by_name.items():
        base = min(sids)
        for s in sids:
            lib["spells"][s]["base"] = base
    return lib, inputs, skipped


def _lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def render(lib, inputs, skipped):
    out = ["-- GENERATED by %s - DO NOT EDIT. Regenerate: python3 tools/fdump.py learned-auras" % GENERATOR,
           "-- Growing aura library merged from every stored capture (combat logs + SVs). spells[spellID] = { n (applications",
           "-- in the logs), dur (median s), name, builds (confirmed on), base (lowest spellID of that name = rank group),",
           "-- cls (class seen casting) }; pairs[castID][auraID] = { n, self, target, builds }. Optional learned data for",
           "-- AuraPresence (source 'offline'); delete this file or set auraPresence.offline = false to switch it off.",
           "local _, ns = ...",
           "ns.LearnedAuras = {",
           "    schema = %d," % SCHEMA,
           "    generator = %s," % _lua_str(GENERATOR),
           "    inputs = {"]
    for run, b, h in inputs:
        out.append("        { %s, %s, %s }," % (_lua_str(run), _lua_str(b), _lua_str(h)))
    out.append("    },")
    out.append("    skipped = { %s }," % ", ".join(_lua_str(s) for s in skipped))
    out.append("    spells = {")
    for sid in sorted(lib["spells"]):
        r = lib["spells"][sid]
        d = sorted(r["durs"])
        parts = ["n = %d" % r["n"]]
        if d:
            parts.append("dur = %s" % round(d[len(d) // 2], 1))
        if r["name"]:
            parts.append("name = %s" % _lua_str(r["name"]))
        parts.append("builds = %s" % _lua_str(",".join(sorted(r["builds"]))))
        if r.get("base") and r["base"] != sid:
            parts.append("base = %d" % r["base"])
        if r["cls"]:
            parts.append("cls = %s" % _lua_str(sorted(r["cls"].items(), key=lambda kv: (-kv[1], kv[0]))[0][0]))
        out.append("        [%d] = { %s }," % (sid, ", ".join(parts)))
    out.append("    },")
    out.append("    pairs = {")
    for c in sorted(lib["pairs"]):
        m = lib["pairs"][c]
        items = ", ".join("[%d] = { n = %d, self = %d, target = %d, builds = %s }" % (a, pr["n"], pr["self"], pr["target"],
                          _lua_str(",".join(sorted(pr["builds"])))) for a, pr in sorted(m.items()) if pr["n"] >= 2)
        if items:
            out.append("        [%d] = { %s }," % (c, items))
    out.append("    },")
    out.append("}")
    return "\n".join(out) + "\n"


def measure(lib, builds, extra=None, per_name=2):
    """candidate count for a build set: all library spells confirmed on those builds (+ extra IDs) vs grouped by rank
    (<= per_name IDs per base, most-seen first)"""
    ids = {s for s, r in lib["spells"].items() if r["builds"] & set(builds)} | set(extra or ())
    groups = collections.defaultdict(list)
    for s in ids:
        r = lib["spells"].get(s) or {}
        groups[r.get("base", s)].append((-(r.get("n") or 0), s))
    grouped = sum(min(per_name, len(v)) for v in groups.values())
    return len(ids), grouped, len(groups)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--root", default=ROOT)
    ap.add_argument("--no-gate", action="store_true", help="tests only: skip the inclusion manifest (synthetic runs)")
    a = ap.parse_args(argv)
    lib, inputs, skipped = collect(a.root, gate=not a.no_gate)
    text = render(lib, inputs, skipped)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(text)
    per_build = collections.Counter(b for r in lib["spells"].values() for b in r["builds"])
    print("learned auras: %d spells (%s), %d cast->aura pair sources; %d inputs, skipped %s -> %s" % (
        len(lib["spells"]), ", ".join("%s: %d" % kv for kv in sorted(per_build.items())),
        sum(1 for m in lib["pairs"].values() if any(p["n"] >= 2 for p in m.values())), len(inputs), skipped or "none", a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
