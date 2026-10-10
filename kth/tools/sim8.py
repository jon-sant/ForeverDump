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
"""forever.8 COMBAT-LOG SIMULATION (not live): if enemy spellIDs were readable, when would the user's healer-only list
flag each player? Per run and player: first heal on another player (SPELL_HEAL/SPELL_PERIODIC_HEAL, src != dst) vs first
SPELL_CAST_SUCCESS with a listed ID. Live BG reality: spellIDs are secret (FD runs 6-18), so this path never fires there."""
import glob, os, re, sys, json
sys.path.insert(0, os.path.dirname(__file__))
from logtruth import rows, analyze, load_refclass, parse_ts
src = open(os.path.join(os.path.dirname(__file__), '../port/KTH/ForeverEvidence.lua')).read()
blk = src[src.index('local L = {'):src.index('for _, e in ipairs(L)')]
ID = {}
for m in re.finditer(r'\{ "([^"]+)", "[^"]+",([^}]*)\}', blk):
    for i in re.findall(r'\d+', m[2]): ID[int(i)] = m[1]
rc = load_refclass(); out = []
for path in sorted(glob.glob(_WROOT + '/foreverdump/real/*/WoWCombatLog.txt')):
    run = path.split('/')[-2]; A = analyze(path, rc)['players']; fh = {}; fc = {}
    for ts, f in rows(path):
        if len(f) < 11 or not f[1].startswith('Player-'): continue
        if f[0] in ('SPELL_HEAL', 'SPELL_PERIODIC_HEAL') and f[5] != f[1]: fh.setdefault(f[1], ts)
        if f[0] == 'SPELL_CAST_SUCCESS':
            try: sid = int(f[9])
            except ValueError: continue
            if sid in ID: fc.setdefault(f[1], (ts, ID[sid], sid))
    for g, (t, nm, sid) in fc.items():
        p = A.get(g) or {}; tot = (p.get('dmg') or 0) + (p.get('healOther') or 0)
        v = 'healer' if p.get('healer') else ('DPS' if tot >= 2000 and (p.get('healShare') or 0) < 0.30 else 'unknown')
        h = fh.get(g)
        out.append(dict(run=run, name=(p.get('name') or g).split('-')[0], cls=p.get('class'), share=p.get('healShare'), label=v,
                        spell=nm, id=sid, flagMinusFirstHeal=None if h is None else round(parse_ts(t) - parse_ts(h))))
json.dump(out, open(os.path.join(os.path.dirname(__file__), 'sim8.json'), 'w'), indent=1)
print('| run | player | class | log heal share | label | first listed cast | ID | flag - first heal s |'); print('|---|---|---|---|---|---|---|---|')
for o in sorted(out, key=lambda o: (o['run'], o['name'])):
    print('| %s | %s | %s | %s | %s | %s | %s | %s |' % (o['run'].replace('2026-', ''), o['name'], o['cls'], o['share'], o['label'], o['spell'], o['id'], o['flagMinusFirstHeal']))
