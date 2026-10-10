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
"""forever.7: reconstruct C_DamageMeter Current-session rows (HealingDone / DamageDone per player) from the run's raw
combat log for a given session window, and VALIDATE the reconstruction against every real FD snapshot (exact row
multisets per side+class). Output is DERIVED data: used only for the secondary backtest, never as a test fixture."""
import json, sys, collections
sys.path.insert(0, _WROOT + '/kth/tools')
import dm_match
RUNS = ['2026-10-09-run16-bg', '2026-10-10-run17-bg', '2026-10-10-run18-bg']
_S = {}
def series(run):
    if run not in _S: _S[run] = dm_match.series(f'{_WROOT}/foreverdump/real/{run}/WoWCombatLog.txt')[0]
    return _S[run]
def rows(run, a, b, ro):
    W = dm_match.window(series(run), a, b)
    out = []
    for g, (h, d, ho) in W.items():
        r = ro.get(g)
        if not r: continue
        out.append(dict(guid=g, side=r['side'], cls=r.get('cls') or r.get('cls_log'), first=r['first'], full=r['full'], h=h, d=d))
    return out
def validate(run):
    tr = json.load(open(f'tests/replay/{run}.truth.json')); ro = {r['guid']: r for r in tr['roster']}; e0 = tr['meta']['e0']
    ok = bad = 0; worst = []
    for l in open(f'dm/{run}.dm.jsonl'):
        s = json.loads(l); hd = s['byType'].get('HealingDone', {}); dur = hd.get('durationSeconds')
        if not isinstance(dur, (int, float)): continue
        b = s['time'] + 0.999; a = b - dur - 1.5
        R = rows(run, a, b, ro)
        for ty, key in (('HealingDone', 'h'), ('DamageDone', 'd')):
            real = collections.Counter()
            for x in s['byType'].get(ty, {}).get('combatSources') or []:
                if x.get('isLocalPlayer') is True: continue
                amt = x.get('totalAmount')
                if not isinstance(amt, (int, float)): continue
                side = 'F' if x.get('sourceDisplayType') == 1 else 'E'
                real[(side, x.get('classFilename'), int(amt))] += 1
            rec = collections.Counter((r['side'], r['cls'], int(r[key])) for r in R if r[key] > 0)
            # local player excluded on both sides
            me = [r for r in R if r['guid'] == tr['meta'].get('owner')]
            for r in me: rec[(r['side'], r['cls'], int(r[key]))] -= 1
            rec = +rec
            if real == rec: ok += 1
            else:
                bad += 1; worst.append((round(s['time'] - e0), ty, sorted((real - rec).items())[:4], sorted((rec - real).items())[:4]))
    return ok, bad, worst
if __name__ == '__main__':
    for run in RUNS:
        ok, bad, worst = validate(run)
        print(run, 'snapshot x type exact', ok, 'mismatch', bad)
        for w in worst[:6]: print('   ', w)
