"""Unhash inclusion gate (HARD RULE 2026-10-09): a run is usable only if 100% of hashed IdKeys
restore to raw values. Below 100% → EXCLUDE from offline scoring / master guide / fixtures /
replay tests. Pre-IdKey runs (no hashed keys) stay included. Originals on disk are untouched.
"""
from __future__ import annotations

import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "unhash-inclusion.json")
HK = re.compile(r"(?:^|[^A-Za-z0-9_])(?:player|guid|name|pet|guild|session):[0-9a-f]{8}(?:[^A-Za-z0-9_]|$)")


def load(path: str = MANIFEST) -> dict:
    if not os.path.exists(path):
        return {"rule": "100% hashed IdKeys restored or no hashing", "included": [], "excluded": [], "runs": {}}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save(data: dict, path: str = MANIFEST) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, sort_keys=True)
        f.write("\n")


def is_included(run: str, data: dict | None = None) -> bool:
    data = data or load()
    # Prefer explicit lists; fall back to per-run status
    inc = set(data.get("included") or [])
    exc = set(data.get("excluded") or [])
    name = os.path.basename(run.rstrip("/"))
    if name in exc:
        return False
    if name in inc:
        return True
    st = (data.get("runs") or {}).get(name) or {}
    if st.get("status") == "excluded":
        return False
    if st.get("status") == "included":
        return True
    # Unknown run: allow only if no hashed keys in its SV (conservative: exclude if unknown hashed)
    return st.get("resolvedPct", 0) == 100.0 or st.get("hashedDistinct", None) == 0


def filter_runs(runs, data: dict | None = None):
    data = data or load()
    return [r for r in runs if is_included(r, data)]


def sv_path_for_analysis(run_dir: str, data: dict | None = None) -> str:
    """Prefer sv_raw/ForeverDump.lua for included repaired runs; else sv/ForeverDump.lua."""
    data = data or load()
    name = os.path.basename(run_dir.rstrip("/"))
    raw = os.path.join(run_dir, "sv_raw", "ForeverDump.lua")
    orig = os.path.join(run_dir, "sv", "ForeverDump.lua")
    st = (data.get("runs") or {}).get(name) or {}
    if st.get("status") == "included" and st.get("salt") is not None and os.path.exists(raw):
        return raw
    return orig if os.path.exists(orig) else raw


def assert_no_hashed_keys(run_dir: str, data: dict | None = None) -> None:
    """Raise AssertionError if an included run's analysis SV still contains hashed IdKeys."""
    data = data or load()
    name = os.path.basename(run_dir.rstrip("/"))
    if not is_included(name, data):
        return
    path = sv_path_for_analysis(run_dir, data)
    if not os.path.exists(path):
        return
    # stream scan — SVs can be large
    with open(path, "rb") as f:
        chunk = b""
        while True:
            block = f.read(1 << 20)
            if not block:
                break
            chunk = chunk[-32:] + block
            if HK.search(chunk.decode("utf-8", errors="ignore")):
                raise AssertionError(
                    "included run %s still contains hashed IdKeys in %s" % (name, path))


def build_from_manifests(root: str = ROOT) -> dict:
    """Scan real/*/sv_raw/unhash-manifest.json and classify under the 100% rule."""
    real = os.path.join(root, "real")
    runs = {}
    included, excluded = [], []
    for name in sorted(os.listdir(real)):
        base = os.path.join(real, name)
        if not os.path.isdir(base):
            continue
        sv = os.path.join(base, "sv", "ForeverDump.lua")
        if not os.path.exists(sv):
            continue
        man = os.path.join(base, "sv_raw", "unhash-manifest.json")
        if not os.path.exists(man):
            # no unhash pass yet — treat as unknown/excluded if hashed keys present
            runs[name] = {"status": "excluded", "reason": "no unhash-manifest", "resolvedPct": None}
            excluded.append(name)
            continue
        with open(man, encoding="utf-8") as f:
            m = json.load(f)
        pct = m.get("resolvedPct")
        hashed = m.get("hashedDistinct", m.get("hashed", 0)) or 0
        note = m.get("note") or ""
        if hashed == 0 or "no hashed" in note.lower() or pct == 100.0:
            status = "included"
            included.append(name)
            reason = "no hashing" if hashed == 0 or "no hashed" in note.lower() else "100% restored"
        else:
            status = "excluded"
            excluded.append(name)
            reason = "resolvedPct %.1f < 100" % (pct or 0.0)
        runs[name] = {
            "status": status, "reason": reason, "salt": m.get("salt"),
            "hashedDistinct": hashed, "resolved": m.get("resolved", 0 if hashed == 0 else None),
            "resolvedPct": 100.0 if hashed == 0 else pct,
            "unresolved": m.get("unresolved", 0),
            "unresolvedSample": m.get("unresolvedSample"),
        }
    return {
        "rule": "100% hashed IdKeys restored to raw, or no hashing (pre-IdKey)",
        "included": included,
        "excluded": excluded,
        "runs": runs,
    }
