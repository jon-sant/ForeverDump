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
"""forever.7: healer-only spell list, derived and verified on raw data.
Candidates: spells whose Forever 1.60.1 DB2 SpellEffect rows heal or absorb (Effect HEAL 10 / HEAL_PCT 136, aura
PERIODIC_HEAL 8 / SCHOOL_ABSORB 69) AND whose name is a known talent- or rune-gated healing spell (NAMES below; the
talent/rune gating itself is not in the captured DB2 tables, so it is a stated assumption). Evidence: every combat log
of runs 1-18. ZERO TOLERANCE: a spell is kept only if no known DPS (heals on others < 30 % of output, with >= 2000 output) ever
cast it, in any run. Casters with too little output to judge are reported as unknown. Output: tools/healer_spells.json (+ report)."""
import csv, glob, json, os, sys, collections, re
sys.path.insert(0, os.path.dirname(__file__))
from logtruth import rows, analyze, load_refclass
DB = _WROOT + '/foreverdump/data/db2/wow_classic_beta/DBFilesClient/'
NAMES = ['Holy Shock', 'Swiftmend', 'Penance', 'Riptide', 'Earth Shield', 'Lifebloom', 'Wild Growth', 'Beacon of Light',
         'Circle of Healing', 'Prayer of Mending', 'Mana Tide Totem', 'Lightwell', 'Divine Favor', 'Nourish',
         'Tree of Life', 'Guardian Spirit', 'Pain Suppression', 'Divine Hymn', 'Healing Rain', 'Ancestral Guidance',
         'Empowered Renew', 'Serendipity', 'Regrowth', 'Rejuvenation', 'Healing Touch', 'Chain Heal', 'Flash Heal',
         'Greater Heal', 'Prayer of Healing', 'Holy Light', 'Flash of Light', 'Lesser Healing Wave', 'Healing Wave',
         'Renew', 'Power Word: Shield', 'Heal', 'Lesser Heal', 'Tranquility', 'Holy Nova', 'Desperate Prayer',
         'Lay on Hands', 'Divine Light', 'Word of Glory', 'Holy Radiance', 'Flash Heal']
TALENT_OR_RUNE = {'Holy Shock', 'Swiftmend', 'Penance', 'Riptide', 'Earth Shield', 'Lifebloom', 'Wild Growth',
                  'Beacon of Light', 'Circle of Healing', 'Prayer of Mending', 'Mana Tide Totem', 'Lightwell',
                  'Divine Favor', 'Nourish', 'Tree of Life', 'Guardian Spirit', 'Pain Suppression', 'Divine Hymn',
                  'Healing Rain', 'Ancestral Guidance', 'Empowered Renew', 'Serendipity'}
def heal_effect_ids():
    ids = set()
    with open(DB + 'SpellEffect.csv', newline='') as f:
        r = csv.reader(f); hdr = next(r); iE = hdr.index('Effect'); iA = hdr.index('EffectAura'); iS = len(hdr) - 1
        for row in r:
            try: e, a, s = int(row[iE]), int(row[iA]), int(row[iS])
            except (ValueError, IndexError): continue
            if e in (10, 136) or (e == 6 and a in (8, 69)): ids.add(s)
    return ids
def names():
    out = {}
    with open(DB + 'SpellName.csv', newline='') as f:
        r = csv.reader(f); next(r)
        for row in r:
            try: out[int(row[0])] = row[1]
            except (ValueError, IndexError): pass
    return out
def main():
    HE, NM = heal_effect_ids(), names()
    rc = load_refclass()
    casters = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, None, None, None]))  # sid -> guid -> [n, healer, class, run]
    runs = sorted(glob.glob(_WROOT + '/foreverdump/real/*/WoWCombatLog.txt'))
    for path in runs:
        run = path.split('/')[-2]
        A = analyze(path, rc)['players']
        for ts, f in rows(path):
            if len(f) < 10 or f[0] not in ('SPELL_CAST_SUCCESS', 'SPELL_HEAL', 'SPELL_AURA_APPLIED'): continue
            src = f[1]
            if not src.startswith('Player-'): continue
            try: sid = int(f[9])
            except ValueError: continue
            if sid not in HE: continue
            p = A.get(src) or {}
            c = casters[sid][src + '@' + run]
            tot = (p.get('dmg') or 0) + (p.get('healOther') or 0)
            # verdict: H healer (log30), D known DPS (share < 0.30 with >= 2000 output), U unknown (too little output)
            c[0] += 1; c[1] = 'H' if p.get('healer') else ('D' if tot >= 2000 and (p.get('healShare') or 0) < 0.30 else 'U'); c[2] = p.get('class'); c[3] = (p.get('name'), p.get('healShare'), run)
    rep = []
    for sid, cs in casters.items():
        nm = NM.get(sid, '?')
        H = {k: v for k, v in cs.items() if v[1] == 'H'}; N = {k: v for k, v in cs.items() if v[1] == 'D'}
        U = {k: v for k, v in cs.items() if v[1] == 'U'}
        rep.append(dict(spellID=sid, name=nm, healerCasters=len(H), healerCasts=sum(v[0] for v in H.values()),
                        dpsCasters=len(N), dpsCasts=sum(v[0] for v in N.values()), unknownCasters=len(U), unknownCasts=sum(v[0] for v in U.values()),
                        talentOrRune=nm in TALENT_OR_RUNE,
                        classes=sorted({v[2] for v in cs.values() if v[2]}),
                        dps=[v[3] for v in N.values()][:5], keep=(nm in TALENT_OR_RUNE and len(N) == 0 and len(H) >= 1)))
    rep.sort(key=lambda x: (not x['keep'], not x['talentOrRune'], x['dpsCasters'] > 0, -x['healerCasts']))
    json.dump(dict(runs=[p.split('/')[-2] for p in runs], spells=rep), open(os.path.join(os.path.dirname(__file__), 'healer_spells.json'), 'w'), indent=1)
    for x in rep:
        if not (x['talentOrRune'] or x['dpsCasters'] == 0): continue
        print(('KEEP ' if x['keep'] else 'DROP ') + json.dumps(x))
if __name__ == '__main__': main()
