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
"""forever.4: recover REAL full names ("First Surname") for a replay roster from that run's own ForeverDump SV.
Sources, strongest first (all are client reads recorded during the match; nothing is inferred):
  G  guid-linked: a flat table holding both guid="Player-..." and name="First Surname" (C_DamageMeter sources,
     FD identity records with guids={...} and names={...})
  S  scoreboard row strings / plate name-realm "First-Surname" whose first word is unique among the run's names
A roster player gets a real full name only if exactly one candidate exists for its guid (G) or, failing that, for its
first name (S) with no other roster player sharing that first name."""
import re, sys, json, glob, collections

def sv_path(run):
    for sub in ('sv_raw', 'sv'):
        p = f'{_WROOT}/foreverdump/real/{run}/{sub}/ForeverDump.lua'
        try:
            if open(p, 'rb').read(64): return p
        except OSError: pass

FULL = r'([^"\\\-\s][^"\\\-]*?)'
def candidates(s):
    byGuid = collections.defaultdict(set); byFirst = collections.defaultdict(set); src = collections.Counter()
    # G1: flat tables with name + guid (any order)
    for m in re.finditer(r'\{([^{}]*)\}', s):
        body = m.group(1)
        g = re.search(r'guid=\\"(Player-\d+-[0-9A-F]+)\\"', body)
        n = re.search(r'\bname=\\"([^"\\]+ [^"\\]+)\\"', body)
        if g and n:
            byGuid[g.group(1)].add(n.group(1)); src['G:name+guid'] += 1
    # G2: FD identity records: guids={["Player-.."]=true,...} ... names={["A-B"]=true,["A B"]=true}
    for m in re.finditer(r'names=\{([^{}]*)\}[^{}]{0,400}?guids=\{([^{}]*)\}|guids=\{([^{}]*)\}[^{}]{0,400}?names=\{([^{}]*)\}', s):
        names = m.group(1) or m.group(4); guids = m.group(2) or m.group(3)
        gs = re.findall(r'(Player-\d+-[0-9A-F]+)', guids)
        ns = set(x.replace('-', ' ', 1) for x in re.findall(r'\[\\"([^"\\]+[ \-][^"\\]+)\\"\]=true', names))
        if len(gs) == 1 and len(ns) == 1:
            byGuid[gs[0]] |= ns; src['G:identity'] += 1
    # S: plate name-realm values and scoreboard strings
    for m in re.finditer(r'v=\\"([^"\\\s]+)-([^"\\]+)\\",src=\\"(\w+)\\"', s):
        byFirst[m.group(1)].add(m.group(1) + ' ' + m.group(2)); src['S:plate'] += 1
    # S2: FD scoreboard records (GetScoreInfo name + classToken): key="name:First Surname",class="CLS",...,via="score"
    byFirstClass = collections.defaultdict(set)
    for m in re.finditer(r'key=\\"name:([^"\\\s]+) ([^"\\]+)\\",class=\\"(\w+)\\",[^{}]*?via=\\"score\\"', s):
        a, b, c = m.groups()
        byFirst[a].add(a + ' ' + b); byFirstClass[(a, c)].add(a + ' ' + b); src['S:score'] += 1
    return byGuid, byFirst, byFirstClass, src

def resolve(run, roster):
    s = open(sv_path(run), encoding='utf-8', errors='replace').read()
    byGuid, byFirst, byFirstClass, src = candidates(s)
    firstCount = collections.Counter(r['first'] for r in roster)
    out = {}
    for r in roster:
        g = byGuid.get(r['guid'], set())
        g = {x for x in g if x.split(' ', 1)[0] == r['first']}
        if len(g) == 1: out[r['guid']] = (next(iter(g)), 'G'); continue
        f = byFirst.get(r['first'], set())
        if len(f) == 1 and firstCount[r['first']] == 1: out[r['guid']] = (next(iter(f)), 'S'); continue
        # same first name on the roster: the scoreboard row with the same first name AND class, minus names already
        # guid-linked to the other player
        taken = {v[0] for gg, v in out.items() if v[0]} | {next(iter(x)) for gg, x in byGuid.items() if len(x) == 1 and gg != r['guid']}
        fc = byFirstClass.get((r['first'], r.get('cls') or r.get('cls_log')), set()) - taken
        if len(fc) == 1: out[r['guid']] = (next(iter(fc)), 'S2'); continue
        out[r['guid']] = (None, 'none' if not (g or f) else f'ambiguous:{sorted(g or f)[:4]}')
    return out, src

if __name__ == '__main__':
    rep = {}
    for run in sys.argv[1:]:
        tr = json.load(open(glob.glob(f'{_WROOT}/kth/tests/replay/{run}.truth.json')[0]))
        out, src = resolve(run, tr['roster'])
        ok = sum(1 for v in out.values() if v[0]); n = len(out)
        rep[run] = dict(sv=sv_path(run), roster=n, real=ok, how=collections.Counter(v[1] if v[0] else 'missing' for v in out.values()),
                        missing=[(r['first'], out[r['guid']][1]) for r in tr['roster'] if not out[r['guid']][0]], src=dict(src),
                        names={r['guid']: out[r['guid']][0] for r in tr['roster']})
        print(run, f'{ok}/{n}', dict(rep[run]['how']), 'missing:', rep[run]['missing'][:12], 'src', dict(src))
    json.dump(rep, open(_WROOT + '/kth/tests/replay/realnames-report.json', 'w'), indent=1, default=str)
