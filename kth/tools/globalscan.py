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
"""List globals read by an addon tree (luac -l GETGLOBAL) that the Forever static dump does not list."""
import sys, json, subprocess, re, os, collections
st = json.load(open(_WROOT + '/kth/tests/forever_static.json'))
G = set(st['globals'])
LUA = set('''assert collectgarbage dofile error getfenv getmetatable ipairs load loadfile loadstring next pairs pcall print rawequal rawget rawset select setfenv setmetatable tonumber tostring type unpack xpcall _G _VERSION coroutine debug io math os package string table bit
strsub strlen strupper strlower strfind strmatch strrep strrev strbyte strchar gsub gmatch format floor ceil abs max min mod sqrt random tinsert tremove sort getn wipe date time
'''.split())
root = sys.argv[1]
files = [os.path.join(d, f) for d, _, fs in os.walk(root) for f in fs if f.endswith('.lua')]
reads = collections.defaultdict(set); sets = set()
for f in files:
    out = subprocess.run(['luac5.1', '-l', '-p', f], capture_output=True, text=True).stdout
    for line in out.splitlines():
        m = re.search(r'\b(GETGLOBAL|SETGLOBAL)\b.*;\s*(\S+)', line)
        if m:
            (reads[m.group(2)].add(os.path.relpath(f, root)) if m.group(1) == 'GETGLOBAL' else sets.add(m.group(2)))
miss = {k: sorted(v) for k, v in reads.items() if k not in G and k not in LUA and k not in sets}
for k in sorted(miss): print(k, miss[k][:4])
