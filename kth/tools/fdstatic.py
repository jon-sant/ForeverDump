import os as _wos  # portable root (handoff): WOWDEV_ROOT or the nearest parent dir holding foreverdump/
def _wowdev_root():
    r = _wos.environ.get("WOWDEV_ROOT")
    if r:
        return r
    d = _wos.path.dirname(_wos.path.abspath(__file__))
    while d != _wos.path.dirname(d) and not _wos.path.isdir(_wos.path.join(d, "foreverdump")):
        d = _wos.path.dirname(d)
    return d
_WROOT = _wowdev_root()
"""Extract Forever global-name lists and widget method lists from a ForeverDump SV (raw)."""
import sys, json, pickle
sys.path.insert(0, _WROOT + '/foreverdump/tools')
from fdump.luasv import parse_savedvariables
sv = parse_savedvariables(open(sys.argv[1], encoding='utf-8', errors='replace').read())
hits = []
def walk(o, path):
    if isinstance(o, dict):
        for k, v in o.items(): walk(v, path + [str(k)])
    elif isinstance(o, list):
        if o and all(isinstance(x, str) for x in o[:50]) and len(o) > 20:
            hits.append(('/'.join(path), len(o), o))
        else:
            for i, v in enumerate(o[:5000]): walk(v, path + [str(i)])
walk(sv, [])
for p, n, o in hits:
    if n > 50: print(n, p, o[:4])
pickle.dump(hits, open(sys.argv[2], 'wb'))
