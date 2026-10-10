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
"""forever.5: compare each C_DamageMeter snapshot (tools/dm_extract.lua) with the combat log over the same session
window, to learn (a) which rows are friendly/enemy, (b) whether enemy rows (secret name/guid, clear class+amount) can be
attributed. Raw values only; nothing is altered."""
import json, sys, collections, bisect
sys.path.insert(0, _WROOT + '/kth/tools')
import logtruth

def series(path):
    S = collections.defaultdict(list)  # guid -> [(t, heal_eff, dmg)]
    names = {}
    for ts, f in logtruth.rows(path):
        if len(f) < 10: continue
        ev = f[0]; src = f[1]
        if not src.startswith('Player-'): continue
        names[src] = f[2]
        t = logtruth.parse_ts(ts)
        if ev in logtruth.HEAL_EV:
            try: amount, over = int(f[-5]), int(f[-3])
            except ValueError: continue
            S[src].append((t, max(0, amount - over), 0, f[5] != src))
        elif ev in logtruth.DMG_EV:
            try:
                base = 9 if ev == 'SWING_DAMAGE' else 12
                amount = int(f[base + 19])
            except (ValueError, IndexError): continue
            S[src].append((t, 0, max(0, amount), False))
    return S, names

def window(S, a, b):
    out = {}
    for g, L in S.items():
        h = d = ho = 0
        for t, he, de, other in L:
            if a <= t <= b: h += he; d += de; ho += he if other else 0
        if h or d: out[g] = (h, d, ho)
    return out

if __name__ == '__main__':
    run = sys.argv[1]
    tr = json.load(open(f'{_WROOT}/kth/tests/replay/{run}.truth.json'))
    rost = {r['guid']: r for r in tr['roster']}
    S, names = series(f'{_WROOT}/foreverdump/real/{run}/WoWCombatLog.txt')
    for snap in (json.loads(l) for l in open(f'{_WROOT}/kth/dm/{run}.dm.jsonl')):
        hd = snap['byType'].get('HealingDone', {}); dur = hd.get('durationSeconds')
        if not isinstance(dur, (int, float)): continue
        b = snap['time'] + 0.999; a = b - dur - 1.5
        W = window(S, a, b)
        print('snap t=%d dur=%s reason=%s' % (snap['time'] - tr['meta']['e0'], dur, snap['reason']))
        for r in sorted(hd.get('combatSources') or [], key=lambda r: -(r.get('totalAmount') or 0)):
            cls, amt, dt = r.get('classFilename'), r.get('totalAmount'), r.get('sourceDisplayType')
            cands = [(g, W[g][0]) for g in W if rost.get(g) and (rost[g].get('cls') or rost[g].get('cls_log')) == cls]
            cands.sort(key=lambda x: abs(x[1] - (amt if isinstance(amt, (int, float)) else 0)))
            best = ['%s/%s/%s %d' % (rost[g]['first'], rost[g]['side'], 'H' if rost[g]['healer'] else '-', h) for g, h in cands[:3]]
            print('   dt=%s fac=%s %-8s %-7s name=%s  ->  %s' % (dt, r.get('factionGroup'), cls, amt, r.get('name'), best))
        break
