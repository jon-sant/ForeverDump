#!/usr/bin/env python3
"""Restore original file mtimes from MANIFEST.tsv (git clone sets every mtime to checkout time; the master-guide
staleness check compares guide vs run-data mtimes). Only files whose size matches are touched."""
import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
n = 0
for l in list(open(os.path.join(ROOT, "MANIFEST.tsv")))[1:]:
    part, size, sha, mt, rel = l.rstrip("\n").split("\t")
    p = os.path.join(ROOT, rel)
    if sha.startswith("symlink:") or not os.path.isfile(p) or os.path.getsize(p) != int(size):
        continue
    os.utime(p, (int(mt), int(mt))); n += 1
print("restore_mtimes: %d files" % n)
