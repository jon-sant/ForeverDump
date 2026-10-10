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
"""run19 follow-up (offline, NOT shipped): per enemy class group with n >= 2, at every recorded meter snapshot, the
minimum / maximum number of healers consistent with the class's anonymous rows (enemy rows: name secret, class clear).
A player is a healer under a pairing when heal >= dmMin and heal*100 >= dmSharePct*(heal+dmg). Brute force over every
assignment of heal rows and damage rows to the n players (missing rows = 0). Compared with forever.6's class-all rule
(sum share >= grpSharePct and >= n heal rows) and with log truth (strict: truth.json healer; inclusive: share >= .5
and >= 5 heal events incl. periodic -> passed in via --incl). Ranking feature: share of RAGE+ENERGY power samples
from the replay stream up to the snapshot (druid forms)."""
import json, itertools, re, sys, collections, glob
dmMin, dmShare, grpShare = 1000, 60, 63
RUNS = sys.argv[1:] or ['2026-10-09-run16-bg', '2026-10-10-run17-bg', '2026-10-10-run18-bg', '2026-10-10-run19-bg']
def rows(snap, ty):
    out = collections.defaultdict(list)
    for x in (snap['byType'].get(ty) or {}).get('combatSources') or []:
        if x.get('name') == '<secret>' and x.get('sourceDisplayType') != 1 and isinstance(x.get('totalAmount'), (int, float)):
            out[x['classFilename']].append(x['totalAmount'])
    return out
def kminmax(n, H, D):
    H = (H + [0] * n)[:max(n, len(H))][:n] if len(H) <= n else H
    D = (D + [0] * n)[:n] if len(D) <= n else D
    if len(H) > n or len(D) > n: return None
    H = H + [0] * (n - len(H)); D = D + [0] * (n - len(D))
    ks = set()
    for p in set(itertools.permutations(D)):
        ks.add(sum(1 for h, d in zip(H, p) if h >= dmMin and h * 100 >= dmShare * (h + d)))
    return min(ks), max(ks)
for run in RUNS:
    tr = json.load(open(f'{_WROOT}/kth/tests/replay/{run}.truth.json')); ro = tr['roster']
    g = collections.defaultdict(list)
    for i, r in enumerate(ro, 1):
        if r['side'] == 'E': g[r.get('cls_log') or r.get('cls') or r.get('class')].append((i, r))
    s = open(f'{_WROOT}/kth/tests/replay/{run}.lua', encoding='utf-8').read()
    pw = [(float(m.group(1)), int(m.group(2)), m.group(3)) for m in re.finditer(r'\{([0-9.]+),"P","[a-z0-9]+",(\d+),"([A-Z_]+)"\}', s)]
    snaps = sorted((json.loads(l) for l in open(f'{_WROOT}/kth/dm/{run}.dm.jsonl')), key=lambda x: x['gameTime'])
    print(f'== {run}: {len(snaps)} snapshots')
    for cls, pl in sorted(g.items()):
        if len(pl) < 2 or cls not in ('DRUID', 'PRIEST', 'PALADIN', 'SHAMAN'): continue
        n = len(pl); truthH = [r['first'] for _, r in pl if r['healer']]
        print(f'  {cls} n={n} truth healers {truthH} players {[r["first"] for _, r in pl]}')
        for sn in snaps:
            H, D = rows(sn, 'HealingDone')[cls], rows(sn, 'DamageDone')[cls]
            km = kminmax(n, sorted(H, reverse=True), sorted(D, reverse=True))
            sh, sd = sum(H), sum(D)
            f6 = len(H) >= n and sh >= dmMin * n and sh * 100 >= grpShare * (sh + sd)
            t = sn['gameTime']
            form = {}
            for i, r in pl:
                c = collections.Counter(p for tt, gi, p in pw if gi == i and tt <= t and p in ('MANA', 'RAGE', 'ENERGY'))
                tot = sum(c.values()); form[r['first']] = round((c['RAGE'] + c['ENERGY']) / tot, 2) if tot else None
            print(f'    t+{t - tr["meta"]["g0"]:6.0f}s H={sorted(H, reverse=True)} D={sorted(D, reverse=True)} kmin/kmax={km} f6all={f6} formShare={form}')
