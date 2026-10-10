"""Recover pre-v2.2.21 salted IdKeys and rewrite SVs with raw identities.

Background (user decision 2026-10-09, repair request 2026-10-09 20:47 ET):
  IdKey(kind, id) = kind .. ":" .. format("%08x", hash32(tostring(salt) .. "|" .. tostring(id)))
  salt = (floor(GetTime()*1000) % 2147483647) + sessionCounter * 9973
  GetTime() at BeginCapture ≈ replay.sessions[i].hdr.t0; salt itself was not stored.
  hash32 is the Lua 5.1 double mix in ReplayLog.lua (parity-checked against Lua).

Recovery:
  1. Candidate salts from each session's t0 × a small window of sessionCounters (sid suffix and
     ForeverDumpDB.sessionCounter, ± a few) and ±2 ms on floor(t0*1000).
  2. Brute-force fallback (tools/fdump/h32 crack) over the full salt space for the own GUID if needed.
  3. Confirm a salt with ≥3 independent matches of known raw IDs (GUIDs/names from the combat log).
  4. Build hex→raw maps for every kind×id from the matching log (and all other logs as a fallback).
  5. Rewrite a copy of the SV (real/<run>/sv_raw/) substituting kind:hex → kind:<raw>, and write a
     per-run manifest with the recovered salts.
"""
from __future__ import annotations

import collections
import json
import math
import os
import pickle
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
H32 = os.path.join(os.path.dirname(os.path.abspath(__file__)), "h32")
HK = re.compile(r"^([a-z]+):([0-9a-f]{8})$")
GUID = re.compile(r"^(Player|Pet)-\d+-[0-9A-Fa-f]+$")
OWN_GUID = "Player-4618-00EB40D8"
OWN_NAMES = ("Uglaz", "Pally", "Palzy")
KINDS = ("player", "guid", "name", "pet", "guild", "session")

# Unit tokens the old code sometimes hashed under kind "guid" / "player" (WorldCapture / decide / HybridState)
UNIT_TOKENS = ["player", "target", "focus", "mouseover", "pet", "vehicle", "npc", "softenemy", "softfriend",
               "targettarget", "focustarget", "pettarget", "playerpet"]
for i in range(1, 41):
    UNIT_TOKENS += ["party%d" % i, "raid%d" % i, "nameplate%d" % i, "boss%d" % i,
                    "partypet%d" % i, "raidpet%d" % i, "party%dtarget" % i, "raid%dtarget" % i,
                    "nameplate%dtarget" % i]
for i in range(1, 6):
    UNIT_TOKENS += ["arena%d" % i, "arenapet%d" % i, "arena%dtarget" % i]


def sv_strings(path, maxlen=60):
    """Clear strings from an SV file usable as identity preimages (filters SVPack noise)."""
    data = open(path, "rb").read()
    out = set()
    for rx in (rb'"([^"\\]{2,%d})"' % maxlen, rb'\\"([^"\\]{2,%d})\\"' % maxlen):
        for m in re.finditer(rx, data):
            try:
                s = m.group(1).decode("utf-8")
            except Exception:
                continue
            if HK.match(s) or s.startswith(("Player-", "Pet-", "Creature-", "Vehicle-", "Cast-")):
                continue
            if re.match(r"^[a-z]+:", s) or "=" in s or "{" in s or "}" in s:
                continue
            if not re.search(r"[A-Za-z]", s):
                continue
            # allow letters, digits, spaces, hyphens, apostrophes
            if not re.match(r"^[A-Za-z0-9][A-Za-z0-9 '\-:]*$", s):
                continue
            out.add(s)
    return out


def token_ids():
    out = {k: set() for k in KINDS}
    for t in UNIT_TOKENS:
        out["guid"].add(t)
        out["player"].add(t)
        out["name"].add(t)
    return out



# ------------------------------------------------------------------------------------------------ hash32 (Lua parity)
def hash32(s: str) -> int:
    """Exact ReplayLog.lua hash32 (double arithmetic)."""
    h = 2166136261.0
    for b in s.encode("utf-8"):
        h = h + b
        a = h * 16777619.0 + (h - math.floor(h / 65521.0) * 65521.0) * 31.0
        h = a - math.floor(a / 4294967296.0) * 4294967296.0
    return int(h)


def idkey_hex(salt: int, raw: str) -> str:
    return "%08x" % hash32("%d|%s" % (salt, raw))


def idkey(kind: str, salt: int, raw: str) -> str:
    if raw == "player":
        return "player"
    if kind == "npc":
        m = re.match(r"^Creature-\d+-\d+-\d+-\d+-(\d+)-", raw) or re.match(r"^Vehicle-\d+-\d+-\d+-\d+-(\d+)-", raw)
        if m:
            return "npc:" + m.group(1)
    return "%s:%s" % (kind, idkey_hex(salt, raw))


# ------------------------------------------------------------------------------------------------ identity harvest
def log_ids(path: str) -> dict:
    """kind -> set of raw ids that the addon may have hashed from this combat log."""
    out = {k: set() for k in KINDS}
    if not path or not os.path.exists(path):
        return out
    with open(path, encoding="utf-8", errors="replace") as f:
        for ln in f:
            for g, n in re.findall(r'(Player-\d+-[0-9A-Fa-f]+),"([^"]*)"', ln):
                out["player"].add(g)
                out["guid"].add(g)
                base = n.split("-")[0]
                if base:
                    out["name"].add(base)
                if n:
                    out["name"].add(n)
            for g, n in re.findall(r'(Pet-\d+-\d+-\d+-\d+-\d+-[0-9A-Fa-f]+),"([^"]*)"', ln):
                out["pet"].add(g)
                out["guid"].add(g)
                if n:
                    out["name"].add(n.split("-")[0])
                    out["session"].add(n.split("-")[0])
            for g, n in re.findall(r'(Creature-\d+-\d+-\d+-\d+-\d+-[0-9A-Fa-f]+),"([^"]*)"', ln):
                if n:
                    out["name"].add(n)
                    out["session"].add(n)
            for g, n in re.findall(r'(Vehicle-\d+-\d+-\d+-\d+-\d+-[0-9A-Fa-f]+),"([^"]*)"', ln):
                if n:
                    out["name"].add(n)
                    out["session"].add(n)
    out["player"].add(OWN_GUID)
    out["guid"].add(OWN_GUID)
    for n in OWN_NAMES:
        out["name"].add(n)
    return out



def harvest_sv_ids(raw):
    """Pull raw GUIDs / names already stored clear in the SV (meter rows, signals, recorder, identity)."""
    out = {k: set() for k in KINDS}
    GUID_RX = re.compile(r"^(Player|Pet)-[0-9A-Za-z-]+$")
    def add_guid(g):
        if not isinstance(g, str) or not GUID_RX.match(g):
            return
        if g.startswith("Player-"):
            out["player"].add(g); out["guid"].add(g)
        elif g.startswith("Pet-"):
            out["pet"].add(g); out["guid"].add(g)
    def add_name(n):
        if not isinstance(n, str) or not n or n.startswith("<") or HK.match(n):
            return
        if len(n) < 2:
            return
        out["name"].add(n)
        base = n.split("-")[0].split(" ")[0]
        if base and len(base) >= 2:
            out["name"].add(base)
        # Forever "First Last"
        if " " in n:
            for part in n.split():
                if len(part) >= 2:
                    out["name"].add(part)
    def walk(x, d=0):
        if d > 16:
            return
        if isinstance(x, dict):
            # common fields
            for fld in ("sourceGUID", "guid", "playerGUID", "g", "tg"):
                if fld in x:
                    add_guid(x[fld])
            for fld in ("name", "unitName", "creatureName", "fullName", "unitNameWithRealm"):
                if fld in x:
                    add_name(x[fld])
            # identity block
            if "identity" in x and isinstance(x["identity"], dict):
                add_guid(x["identity"].get("guid"))
                add_name(x["identity"].get("name"))
                add_name(x["identity"].get("fullName"))
            for v in x.values():
                walk(v, d + 1)
        elif isinstance(x, list):
            for v in x:
                walk(v, d + 1)
        elif isinstance(x, str) and GUID_RX.match(x):
            add_guid(x)
    walk(raw)
    return out

_ALL_LOG_IDS = {}
def all_log_ids(root: str = ROOT) -> dict:
    if root in _ALL_LOG_IDS:
        return _ALL_LOG_IDS[root]
    out = {k: set() for k in KINDS}
    for p in sorted(__import__("glob").glob(os.path.join(root, "real", "*", "WoWCombatLog*.txt"))):
        ids = log_ids(p)
        for k in KINDS:
            out[k] |= ids[k]
    _ALL_LOG_IDS[root] = out
    return out


# ------------------------------------------------------------------------------------------------ key harvest
def collect_hashed(obj, out=None, depth=0):
    """Return Counter of (kind, hex) occurrences in obj (keys and string values)."""
    if out is None:
        out = collections.Counter()
    if depth > 20:
        return out
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(k, str):
                m = HK.match(k)
                if m and m.group(1) in KINDS:
                    out[(m.group(1), m.group(2))] += 1
            collect_hashed(v, out, depth + 1)
    elif isinstance(obj, (list, tuple)):
        for v in obj:
            collect_hashed(v, out, depth + 1)
    elif isinstance(obj, str):
        m = HK.match(obj)
        if m and m.group(1) in KINDS:
            out[(m.group(1), m.group(2))] += 1
    return out


def sessions(raw):
    rp = ((raw.get("ForeverDumpLogDB") or {}).get("replay") or {})
    return list(rp.get("sessions") or [])


# ------------------------------------------------------------------------------------------------ salt recovery
def candidate_salts(t0, counter_hints, counter_pad=30):
    """Yield candidate salts near t0 × counters in hints ± pad."""
    if t0 is None:
        return
    base = int(math.floor(float(t0) * 1000)) % 2147483647
    counters = set()
    for c in counter_hints:
        if c is None:
            continue
        for d in range(-counter_pad, counter_pad + 1):
            if c + d >= 0:
                counters.add(c + d)
    if not counters:
        counters = set(range(0, 80))
    for c in sorted(counters):
        for b in (base, base - 1, base - 2, base + 1):
            yield b + c * 9973, c, b - base


def score_salt(salt, hashed_hexes, ids_by_kind):
    """Return (n_matches, list of (kind, raw, hex)) for a salt against known ids."""
    hits = []
    for kind, ids in ids_by_kind.items():
        for raw in ids:
            hx = idkey_hex(salt, raw)
            if hx in hashed_hexes.get(kind, set()):
                hits.append((kind, raw, hx))
    return len(hits), hits


def recover_salt(t0, hashed, ids_by_kind, counter_hints, min_hits=None):
    """Best salt for one session. hashed: Counter[(kind,hex)]."""
    by_kind = collections.defaultdict(set)
    for (kind, hx), _ in hashed.items():
        by_kind[kind].add(hx)
    if min_hits is None:
        nhex = len(by_kind.get("player", set()) | by_kind.get("guid", set()) | by_kind.get("pet", set()))
        min_hits = 1 if nhex < 5 else (2 if nhex < 20 else 3)
    # Fast path: only player/guid IDs (combat-log scale ~tens..hundreds) to find the salt;
    # names/guilds are applied later in build_map.
    fast_ids = {k: ids_by_kind.get(k, set()) for k in ("player", "guid", "pet")}
    best = None
    for salt, c, boff in candidate_salts(t0, counter_hints, counter_pad=40):
        n, hits = score_salt(salt, by_kind, fast_ids)
        if n >= min_hits and (best is None or n > best[0]):
            best = (n, salt, c, boff, hits)
            if n >= 10:
                break
    if best:
        n, hits = score_salt(best[1], by_kind, ids_by_kind)  # full score for the report
        best = (n, best[1], best[2], best[3], hits)
    if best:
        return {"salt": best[1], "matches": best[0], "counter": best[2], "t0_off": best[3],
                "sample": best[4][:12], "method": "t0+counter"}
    # Narrow brute-force around t0 (GetTime ms ± 120s, counters 0..120) — full 2^31 is too slow for a gate
    own_hexes = sorted(by_kind.get("player", set()) | by_kind.get("guid", set()))
    if not own_hexes or not os.path.exists(H32) or t0 is None:
        return None
    base = int(math.floor(float(t0) * 1000)) % 2147483647
    lo = max(0, base - 120000)
    hi = base + 120000 + 120 * 9973
    try:
        out = subprocess.check_output(
            [H32, "crack", OWN_GUID, ",".join(own_hexes[:64]), str(lo), str(hi)],
            text=True, timeout=30)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return None
    for ln in out.splitlines():
        salt_s, hx = ln.split("\t")
        salt = int(salt_s)
        n, hits = score_salt(salt, by_kind, ids_by_kind)
        if n >= min_hits:
            return {"salt": salt, "matches": n, "counter": None, "t0_off": None,
                    "sample": hits[:12], "method": "bruteforce-ownGUID", "ownHex": hx}
    return None


# ------------------------------------------------------------------------------------------------ map + rewrite
def build_map(salt, ids_by_kind, extra_ids=None):
    """hex → list of (kind, raw). Collisions recorded when one hex maps to >1 raw for a kind."""
    m = {}  # (kind, hex) -> raw
    collisions = []
    pool = {k: set(v) for k, v in ids_by_kind.items()}
    if extra_ids:
        for k, v in extra_ids.items():
            pool.setdefault(k, set()).update(v)
    for kind, ids in pool.items():
        for raw in ids:
            hx = idkey_hex(salt, raw)
            key = (kind, hx)
            if key in m and m[key] != raw:
                collisions.append((kind, hx, m[key], raw))
            else:
                m[key] = raw
    return m, collisions


def rewrite(obj, amap, stats=None, depth=0, seen=None):
    """Deep-copy obj substituting kind:hex → kind:<raw> using amap[(kind,hex)]=raw."""
    if stats is None:
        stats = collections.Counter()
    if seen is None:
        seen = {}
    if depth > 24:
        return obj
    if isinstance(obj, dict):
        if id(obj) in seen:
            return seen[id(obj)]
        out = {}
        seen[id(obj)] = out
        for k, v in obj.items():
            nk = k
            if isinstance(k, str):
                m = HK.match(k)
                if m and m.group(1) in KINDS:
                    raw = amap.get((m.group(1), m.group(2)))
                    if raw is not None:
                        nk = "%s:%s" % (m.group(1), raw)
                        stats["resolved_keys"] += 1
                    else:
                        stats["unresolved_keys"] += 1
            out[nk] = rewrite(v, amap, stats, depth + 1, seen)
        return out
    if isinstance(obj, list):
        return [rewrite(v, amap, stats, depth + 1, seen) for v in obj]
    if isinstance(obj, str):
        m = HK.match(obj)
        if m and m.group(1) in KINDS:
            raw = amap.get((m.group(1), m.group(2)))
            if raw is not None:
                stats["resolved_values"] += 1
                return "%s:%s" % (m.group(1), raw)
            stats["unresolved_values"] += 1
    return obj


# ------------------------------------------------------------------------------------------------ SV I/O
def load_sv(path):
    from . import dump as dumpmod
    return dumpmod.load_raw(path)


def patch_lua_bytes(src_bytes, amap):
    """Replace every kind:hex token with kind:<raw> in the original SV bytes (handles SVPack escaping).

    Longer hex keys first so prefixes cannot collide. Raw values are GUID / name characters only.
    """
    # sort by hex length then kind so replacements don't overlap (all hexes are 8 chars anyway)
    items = sorted(amap.items(), key=lambda kv: (-len(kv[0][1]), kv[0][0]))
    out = src_bytes
    n = 0
    for (kind, hx), raw in items:
        a = ("%s:%s" % (kind, hx)).encode("utf-8")
        b = ("%s:%s" % (kind, raw)).encode("utf-8")
        c = out.count(a)
        if c:
            out = out.replace(a, b)
            n += c
    return out, n


# ------------------------------------------------------------------------------------------------ per-run
def process_run(run_dir, out_dir=None, all_ids=None, write=True):
    run = os.path.basename(run_dir.rstrip("/"))
    sv = os.path.join(run_dir, "sv", "ForeverDump.lua")
    if not os.path.exists(sv):
        return {"run": run, "ok": False, "error": "no SV"}
    log = None
    for cand in ("WoWCombatLog.txt", "WoWCombatLog-1.txt"):
        p = os.path.join(run_dir, cand)
        if os.path.exists(p):
            log = p
            break
    # guild / name scraps from chat logs (optional)
    chat_names = set()
    for cand in ("WoWChatLog.txt", "WoWChatLog-1.txt"):
        cp = os.path.join(run_dir, cand)
        if not os.path.exists(cp):
            continue
        with open(cp, encoding="utf-8", errors="replace") as f:
            for ln in f:
                for n in re.findall(r'"([^"]{2,40})"', ln):
                    if not n.startswith("Player-") and not HK.match(n):
                        chat_names.add(n)
    raw = load_sv(sv)
    hashed = collect_hashed(raw.get("ForeverDumpLogDB") or {})
    hashed += collect_hashed(raw.get("ForeverDumpDB") or {})
    if not hashed:
        return {"run": run, "ok": True, "salt": None, "note": "no hashed keys (pre-IdKey or already raw)",
                "hashed": 0}
    ids = log_ids(log)
    sv_ids = harvest_sv_ids(raw)
    for k in KINDS:
        ids[k] |= sv_ids.get(k, set())
    ids["guild"] |= chat_names
    ids["name"] |= chat_names
    # v2.2.21 repair: unit tokens hashed as guid/player; SV clear strings as session/guild/name
    tok = token_ids()
    for k in KINDS:
        ids[k] |= tok.get(k, set())
    # Keep all_ids out of the salt-search pool (too large). Merge later for targeted fill only.
    counter = (raw.get("ForeverDumpDB") or {}).get("sessionCounter")
    sess = sessions(raw)
    # Prefer the last session (current LogDB tables were written under its salt)
    salts = []
    for i, s in enumerate(sess):
        h = (s or {}).get("hdr") or {}
        t0 = h.get("t0")
        sid = h.get("sid") or ""
        sid_c = None
        m = re.search(r"-(\d+)$", sid)
        if m:
            sid_c = int(m.group(1))
        hints = [sid_c, counter, (sid_c - 1) if sid_c else None, (counter - 1) if counter else None,
                 (sid_c + 1) if sid_c else None, (counter + 1) if counter else None]
        rec = recover_salt(t0, hashed, ids, hints)
        if not rec and all_ids:
            lean = {k: set(ids.get(k, set())) | set(all_ids.get(k, set())) for k in ("player", "guid", "pet")}
            rec = recover_salt(t0, hashed, lean, hints)
        salts.append({"session": i, "sid": sid, "t0": t0, "version": h.get("addonVersion"),
                      "recovered": rec})
    # merge maps from every session salt that recovered (multi-session SVs keep older keys).
    # Do NOT pass all_ids into build_map — bloated amap makes patch_lua_bytes scan multi-10MB SVs forever.
    recovered = [s for s in salts if s.get("recovered")]
    if not recovered:
        return {"run": run, "ok": False, "error": "salt not recovered", "sessions": salts,
                "hashed": len(hashed)}
    need = set(hashed)
    amap, collisions = {}, []
    for s in recovered:
        m, col = build_map(s["recovered"]["salt"], ids)
        for k, v in m.items():
            if k not in need:
                continue
            if k in amap and amap[k] != v:
                collisions.append((k[0], k[1], amap[k], v, "cross-salt"))
            else:
                amap[k] = v
        collisions.extend(col)
    best = max((s["recovered"] for s in recovered), key=lambda r: r["matches"])
    # Targeted fill: only hash candidates against still-unresolved hexes (fast)
    unresolved = need - set(amap)
    if unresolved:
        by_hex = {}
        for kind, hx in unresolved:
            by_hex.setdefault(kind, set()).add(hx)
        salts_list = [s["recovered"]["salt"] for s in recovered]
        cands = set(UNIT_TOKENS)
        cands |= sv_strings(sv)
        for k in KINDS:
            cands |= ids.get(k, set())
            if all_ids:
                cands |= all_ids.get(k, set())
        for salt in salts_list:
            for raw in cands:
                if not isinstance(raw, str) or not raw:
                    continue
                hx = idkey_hex(salt, raw)
                for kind, hexes in by_hex.items():
                    if hx in hexes:
                        key = (kind, hx)
                        if key not in amap:
                            amap[key] = raw
                        elif amap[key] != raw:
                            collisions.append((kind, hx, amap[key], raw, "fill"))
    amap = {k: v for k, v in amap.items() if k in need}
    resolved = {(k, h) for (k, h) in need if (k, h) in amap}
    unresolved = need - resolved
    # Count how many hashed tokens the map covers (no deep copy of the whole SV — that OOMs/timeouts on 50 MB captures)
    stats = collections.Counter(resolved_keys=len(resolved), unresolved_keys=len(unresolved))
    out_dir = out_dir or os.path.join(run_dir, "sv_raw")
    manifest = {
        "run": run, "ok": True, "salt": best["salt"], "matches": best["matches"],
        "method": best["method"], "counter": best.get("counter"), "t0_off": best.get("t0_off"),
        "hashedDistinct": len(need), "resolved": len(resolved),
        "resolvedPct": round(100.0 * len(resolved) / len(need), 1) if need else 100.0,
        "unresolved": len(unresolved), "unresolvedSample": sorted(unresolved)[:20],
        "collisions": len(collisions), "collisionSample": collisions[:10],
        "rewrite": dict(stats), "sessions": salts, "ownGuidResolved": any(
            amap.get(("player", idkey_hex(best["salt"], OWN_GUID))) == OWN_GUID or
            amap.get(("guid", idkey_hex(best["salt"], OWN_GUID))) == OWN_GUID for _ in [0]),
        "log": log, "out": out_dir if write else None,
    }
    if write:
        os.makedirs(out_dir, exist_ok=True)
        # keep a pickle for fast re-scoring + a Lua SV for the converter
        src_bytes = open(sv, "rb").read()
        patched, nsub = patch_lua_bytes(src_bytes, amap)
        stamp = ("-- ForeverDump unhash repair: salt=%s resolved=%d/%d\n" % (
            best["salt"], len(resolved), len(need))).encode("utf-8")
        open(os.path.join(out_dir, "ForeverDump.lua"), "wb").write(stamp + patched)
        manifest["luaSubstitutions"] = nsub
        # compact pickle: just the hex→raw map + salts (rescoring loads the patched Lua or uses the map)
        with open(os.path.join(out_dir, "unhash-amap.pkl"), "wb") as f:
            pickle.dump({"salt": best["salt"],
                         "salts": [s["recovered"]["salt"] for s in recovered],
                         "amap": amap}, f, protocol=4)
        with open(os.path.join(out_dir, "unhash-manifest.json"), "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=1, default=str)
        # also dump the hex→raw map
        with open(os.path.join(out_dir, "unhash-map.json"), "w", encoding="utf-8") as f:
            json.dump({"%s:%s" % (k, h): v for (k, h), v in amap.items()}, f, indent=1, sort_keys=True)
    return manifest


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("runs", nargs="*", help="run dirs under real/ (default: all with an SV)")
    ap.add_argument("--root", default=ROOT)
    ap.add_argument("--no-write", action="store_true")
    ap.add_argument("--out-json", default=None)
    a = ap.parse_args(argv)
    root = a.root
    if a.runs:
        dirs = [os.path.join(root, "real", r) if not os.path.isdir(r) else r for r in a.runs]
    else:
        dirs = sorted(__import__("glob").glob(os.path.join(root, "real", "*")))
        dirs = [d for d in dirs if os.path.exists(os.path.join(d, "sv", "ForeverDump.lua"))]
    all_ids = all_log_ids(root)
    results = []
    for d in dirs:
        print("==", os.path.basename(d), flush=True)
        m = process_run(d, write=not a.no_write, all_ids=all_ids)
        results.append(m)
        if m.get("ok") and m.get("salt") is not None:
            print("  salt=%s matches=%s resolved=%s/%s (%.1f%%) collisions=%s method=%s" % (
                m["salt"], m["matches"], m["resolved"], m["hashedDistinct"], m["resolvedPct"],
                m["collisions"], m["method"]))
        elif m.get("ok"):
            print("  ", m.get("note"))
        else:
            print("  FAIL", m.get("error"), m.get("sessions", "")[:120])
    if a.out_json:
        with open(a.out_json, "w") as f:
            json.dump(results, f, indent=1, default=str)
    return 0 if all(r.get("ok") for r in results) else 1


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    raise SystemExit(main())
