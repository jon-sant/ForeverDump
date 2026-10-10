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
"""Methods called with ':' in an addon tree that are neither defined by the addon nor a Forever widget method."""
import sys, json, re, os, collections
st = json.load(open(_WROOT + '/kth/tests/forever_static.json'))
M = set(m for ms in st['widgets'].values() for m in ms)
root = sys.argv[1]
files = [os.path.join(d, f) for d, _, fs in os.walk(root) for f in fs if f.endswith('.lua')]
src = {f: open(f, encoding='utf-8', errors='replace').read() for f in files}
defined = set()
for s in src.values():
    defined |= set(re.findall(r'function\s+[\w\.]+[:\.](\w+)\s*\(', s))
    defined |= set(re.findall(r'\b(\w+)\s*=\s*function', s))
    defined |= set(re.findall(r'\[\s*"(\w+)"\s*\]\s*=', s))
    defined |= set(re.findall(r'^\s*(\w+)\s*=', s, re.M))
calls = collections.defaultdict(set)
for f, s in src.items():
    s2 = re.sub(r'--\[\[.*?\]\]', '', s, flags=re.S); s2 = re.sub(r'--[^\n]*', '', s2)
    for m in re.finditer(r':(\w+)\s*\(', s2): calls[m.group(1)].add(os.path.relpath(f, root))
for k in sorted(calls):
    if k not in M and k not in defined: print(k, sorted(calls[k])[:4])
