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
"""forever.6 early-read simulation (OPTIMISTIC, flagged; never used in the primary scores or tests).
The FD ring kept only the last 21 meter snapshots, so earlier PLAYER_REGEN_ENABLED reads are lost. Meter amounts equal
the combat-log amounts (dm_match.py), so this rebuilds what a Current-session read WOULD have shown at hypothetical read
times every 30 s from the gates, using a session window equal to the median durationSeconds of the real snapshots.
Assumptions not in the data: the player left combat at those times, and the session spans that window."""
import json, statistics, sys
sys.path.insert(0, _WROOT + '/kth/tools')
import dm_match
from forensics6_meter import verdict
RUNS = ['2026-10-09-run16-bg', '2026-10-10-run17-bg', '2026-10-10-run18-bg']
for run in RUNS:
    tr = json.load(open(f'tests/replay/{run}.truth.json')); ro = tr['roster']; m = tr['meta']
    rost = {r['guid']: r for r in ro}
    durs = []
    for l in open(f'dm/{run}.dm.jsonl'):
        d = json.loads(l)['byType'].get('HealingDone', {}).get('durationSeconds')
        if isinstance(d, (int, float)): durs.append(d)
    W = statistics.median(durs)
    S, _ = dm_match.series(f'{_WROOT}/foreverdump/real/{run}/WoWCombatLog.txt')
    cls = lambda r: r.get('cls') or r.get('cls_log')
    E = [r for r in ro if r['side'] == 'E']
    groups = {}
    for r in E: groups.setdefault(cls(r), []).append(r)
    first_all = {}; first_none = {}
    # real-snapshot first-read times, for comparison
    snap0 = json.loads(open(f'dm/{run}.dm.jsonl').readline())['time']
    gate = m['g0_epoch'] if 'g0_epoch' in m else None
    t0 = min(t for L in S.values() for t, *_ in L)
    t1 = max(t for L in S.values() for t, *_ in L)
    T = t0 + 60
    while T <= t1:
        win = dm_match.window(S, T - W, T)
        for c, P in groups.items():
            if c not in ('PRIEST', 'PALADIN', 'DRUID', 'SHAMAN'): continue
            gs = {r['guid'] for r in P}
            h = sorted([win[g][0] for g in win if g in gs and win[g][0] > 0], reverse=True)
            d = sorted([win[g][1] for g in win if g in gs and win[g][1] > 0], reverse=True)
            if len(P) == 1:  # forever.5 single-row rule (share >= 60 and heal >= 1000; median clause omitted)
                hh, dd = (h[0] if h else 0), (d[0] if d else 0)
                v = 'ALL' if hh >= 1000 and hh * 100 >= 60 * (hh + dd) else '-'
            else:
                v, _ = verdict(h, d, len(P))
            if v == 'ALL': first_all.setdefault(c, round(T - m['e0']))
            if v == 'NONE': first_none.setdefault(c, round(T - m['e0']))
        T += 30
    print(f"{run[11:16]} window {W:.0f}s, first real snapshot at t={snap0 - m['e0']:.0f}s (same clock as forensics6_meter.py)")
    for c, P in sorted(groups.items()):
        if c not in ('PRIEST', 'PALADIN', 'DRUID', 'SHAMAN'): continue
        print(f"   {c:8s} n={len(P)} healers={sum(r['healer'] for r in P)}  sim first ALL t={first_all.get(c)}  first NONE t={first_none.get(c)}")
