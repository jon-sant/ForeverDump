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
"""forever.5: what C_DamageMeter rows (OOC, raw) say about each player vs log truth. Explore the verdict rules."""
import json, sys, collections, statistics
def num(v): return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None
def rows(sess): return [r for r in (sess.get('combatSources') or []) if isinstance(r, dict)]
def analyze(run, verbose=False):
    tr = json.load(open(f'{_WROOT}/kth/tests/replay/{run}.truth.json'))
    R = tr['roster']; e0 = tr['meta']['e0']
    cls = lambda r: r.get('cls') or r.get('cls_log')
    ecount = collections.Counter(cls(r) for r in R if r['side'] == 'E')
    byname = {r['full']: r for r in R if r.get('full')}
    out = []
    for snap in (json.loads(l) for l in open(f'{_WROOT}/kth/dm/{run}.dm.jsonl')):
        H = rows(snap['byType'].get('HealingDone', {})); Dm = rows(snap['byType'].get('DamageDone', {}))
        hv = [num(r.get('totalAmount')) for r in H]
        if any(v is None for v in hv) or not H: continue
        allh = sorted(hv); med = statistics.median(allh); mean = sum(allh) / max(1, len(R))
        def side(r): return 'F' if r.get('sourceDisplayType') == 1 else 'E'
        for r in H + Dm:
            pass
        ent = collections.defaultdict(lambda: {'h': [], 'd': []})
        for r in H: ent[(side(r), r.get('name') if side(r) == 'F' else r.get('classFilename'))]['h'].append(num(r.get('totalAmount')))
        for r in Dm: ent[(side(r), r.get('name') if side(r) == 'F' else r.get('classFilename'))]['d'].append(num(r.get('totalAmount')))
        for (sd, who), v in ent.items():
            if sd == 'E':
                players = [p for p in R if p['side'] == 'E' and cls(p) == who]
            else:
                players = [byname[who]] if who in byname else []
            truthH = [p['healer'] for p in players]
            for i, h in enumerate(sorted(v['h'], reverse=True)):
                d = v['d'][0] if (len(v['d']) == 1 and len(players) == 1) else None
                out.append(dict(run=run, t=snap['time'] - e0, side=sd, who=who, n=len(players), h=h, d=d, med=med, mean=mean,
                                share=(h / (h + d)) if d is not None and h + d > 0 else None, truth=truthH))
    return out
if __name__ == '__main__':
    for run in sys.argv[1:]:
        for o in analyze(run):
            if o['side'] == 'E':
                print('%s t=%4d %s %-8s n=%d h=%6d d=%s med=%5d x_med=%5.1f x_mean=%5.1f share=%s truth=%s' % (o['run'][11:16], o['t'], o['side'], o['who'], o['n'], o['h'], o['d'], o['med'], o['h'] / max(1, o['med']), o['h'] / max(1, o['mean']), None if o['share'] is None else round(o['share'], 2), o['truth']))
