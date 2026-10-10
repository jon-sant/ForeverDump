#!/usr/bin/env python3
"""Build ForeverDump-v<version>.zip: addon, converter, guide generator, tests, fixtures, docs, and
SECRETS-GUIDE.html at the zip root (regenerate it first with `fdump.py guide ... -o real/<run>/out/guide`).
Excludes real/ (user captures), ref/, data/, .cache/, tests/out/, __pycache__ and any guide samples/ (synthetic).
v2.2.21 (user decision 2026-10-09): NO scrubbing / anonymization. Every file is stored byte-for-byte as it is on disk
(names and GUIDs included); the build verifies each zip entry against its source file (sha256) and fails on any change."""
import argparse
import json
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INCLUDE = ["ForeverDump", "tools", "tests", "fixtures", "README.md", "ADDON-USAGE.md", "CHANGES.md",
           "INSTRUCTIONS-console.md", "SELF-HOSTING.md", "PERFORMANCE.md", ".luacheckrc", "docs"]
SKIP_DIRS = {"__pycache__", ".cache", "out", "samples", ".venv", "shots"}
SKIP_TOP = {"real", "ref", "data"}


def version():
    m = re.search(r'ns\.VERSION = "([^"]+)"', open(os.path.join(ROOT, "ForeverDump", "Core.lua")).read())
    return m.group(1)


def sha(path):
    import hashlib
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def main():
    v = version()
    short = v[:-2] if v.endswith(".0") else v   # 2.2.0 -> v2.2, 2.2.1 -> v2.2.1
    p = argparse.ArgumentParser()
    p.add_argument("--guide", default=os.path.join(ROOT, "real", "2026-10-08-run5", "out", "guide", "SECRETS-GUIDE.html"))
    p.add_argument("--findings", default=os.path.join(ROOT, "real", "2026-10-08-run5", "out", "FINDINGS.md"),
                   help="latest run findings, shipped as FINDINGS-run5.md (stored raw)")
    # one full zip per release (user decision 2026-10-09: no addon-only / -dev split)
    p.add_argument("-o", "--out", default=os.path.join(ROOT, "ForeverDump-v%s.zip" % short))
    a = p.parse_args()
    if not os.path.exists(a.guide):
        sys.exit("missing %s: run fdump.py guide first" % a.guide)
    n = 0
    src = {}
    with zipfile.ZipFile(a.out, "w", zipfile.ZIP_DEFLATED) as z:
        for top in INCLUDE:
            path = os.path.join(ROOT, top)
            if os.path.isfile(path):
                add(z, path, top, src)
                n += 1
                continue
            for dp, dns, fns in os.walk(path):
                dns[:] = sorted(d for d in dns if d not in SKIP_DIRS and not (dp == path and d in SKIP_TOP))
                for fn in sorted(fns):
                    if fn.endswith((".pyc", ".zip")) or fn == "SECRETS-GUIDE.html":
                        continue
                    full = os.path.join(dp, fn)
                    add(z, full, os.path.relpath(full, ROOT), src)
                    n += 1
        add(z, a.guide, "SECRETS-GUIDE.html", src)
        n += 1
        if a.findings and os.path.exists(a.findings):
            add(z, a.findings, "FINDINGS-run5.md", src)
            n += 1
    # raw check: every entry must be byte-identical to its source file (nothing scrubbed or rewritten)
    import hashlib
    bad = []
    with zipfile.ZipFile(a.out) as z:
        for info in z.infolist():
            if hashlib.sha256(z.read(info.filename)).hexdigest() != sha(src[info.filename]):
                bad.append(info.filename)
    if bad:
        os.remove(a.out)
        sys.exit("zip entries differ from their source files: %s" % bad[:10])
    print("wrote %s (%d files, %d KB); raw (no scrubbing), %d entries byte-identical to source" % (
        a.out, n, os.path.getsize(a.out) // 1024, len(src)))


def add(z, path, arc, src):
    src[arc] = path
    z.write(path, arc)


if __name__ == "__main__":
    main()
