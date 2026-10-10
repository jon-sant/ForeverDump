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
"""Mine heal spells (id, name, class) from Forever combat logs of runs NOT used for scoring.
Scored holdout: run10-13, run16. run9 is excluded because run10's log overlaps it.
Output: KillTheHealer_Forever/Data/HealSpells.lua (raw ids + enUS names, per build)."""
import sys, collections, json
sys.path.insert(0, _WROOT + '/kth/tools')
from logtruth import rows, load_refclass, analyze
REAL = _WROOT + '/foreverdump/real/'
MINE = ['2026-10-07', '2026-10-07-run2', '2026-10-07-run3', '2026-10-07-run4', '2026-10-08-run5', '2026-10-08-run6',
        '2026-10-08-run6b', '2026-10-08-run7', '2026-10-08-run8-bg', '2026-10-09-run14-bg', '2026-10-09-run15-bg']
rc = load_refclass()
S = collections.defaultdict(lambda: {'name': None, 'other': 0, 'self': 0, 'periodic': 0, 'byHealer': 0, 'casters': set(), 'cls': collections.Counter()})
for r in MINE:
    truth = analyze(REAL + r + '/WoWCombatLog.txt', rc)['players']
    for ts, f in rows(REAL + r + '/WoWCombatLog.txt'):
        if f[0] not in ('SPELL_HEAL', 'SPELL_PERIODIC_HEAL') or len(f) < 12: continue
        src, dst = f[1], f[5]
        if not src.startswith('Player-'): continue
        try: sid = int(f[9])
        except ValueError: continue
        s = S[sid]; s['name'] = f[10]
        if f[0] == 'SPELL_PERIODIC_HEAL': s['periodic'] += 1
        if dst != src and dst.startswith('Player-'):
            s['other'] += 1; s['casters'].add(src)
            if truth.get(src, {}).get('healer'): s['byHealer'] += 1
            c = truth.get(src, {}).get('class')
            if c: s['cls'][c] += 1
        else:
            s['self'] += 1
HC = {'PRIEST', 'PALADIN', 'SHAMAN', 'DRUID'}
out = []
for sid, s in sorted(S.items()):
    cls = rc.get(sid) or (s['cls'].most_common(1)[0][0] if s['cls'] else None)
    if cls not in HC: kind = 'generic'      # bandage, potion, racial, item, hunter/warlock pet heals
    elif s['other'] == 0: kind = 'selfonly'
    else: kind = 'healer'
    out.append((sid, s['name'], cls or '', kind, s['other'], s['self'], s['periodic'] > 0, len(s['casters']), s['byHealer']))
json.dump(out, open(_WROOT + '/kth/healspells_mined.json', 'w'))
for o in out: print(o)
