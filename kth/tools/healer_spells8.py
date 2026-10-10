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
"""forever.8: user's authoritative healer-only spell list (domain knowledge).
1) resolve every Forever 1.60.1 spell ID per name from the captured DB2 SpellName (build 1.60.1.70245), the FD learned
   refdata (build 70291, observed in play), and every combat log of runs 1-18 (any event, by spell name);
2) per ID: who used it (event types), healer vs DPS by log heal share (logtruth: healer = share >= 0.30 with >= 5 heals on
   others; DPS = share < 0.30 with >= 2000 output; else unknown). Conflicts = DPS users. Output tools/healer_spells8.json."""
import csv, glob, json, os, sys, collections
sys.path.insert(0, os.path.dirname(__file__))
from logtruth import rows, analyze, load_refclass
FD = _WROOT + '/foreverdump/'
DB = FD + 'data/db2/wow_classic_beta/DBFilesClient/'
USER = {'Penance': 'Discipline priest', 'Power Infusion': 'Discipline priest', 'Prayer of Mending': 'Holy priest',
        "Light's Vigil": 'Holy paladin', 'Wild Growth': 'Restoration druid', 'Riptide': 'Restoration shaman'}
OLD = {'Swiftmend': 'removed (user: not a guaranteed healer)', 'Holy Shock': 'removed (not on user list)'}
ALL = dict(USER, **OLD)
def main():
    db2 = collections.defaultdict(list)
    for row in csv.reader(open(DB + 'SpellName.csv', newline='')):
        if len(row) > 1 and row[1] in ALL: db2[row[1]].append(int(row[0]))
    ref = json.load(open(FD + 'tools/fdump/data/refdata.json'))
    refids = collections.defaultdict(list)
    for k, v in ref['spellNames'].items():
        if v in ALL: refids[v].append(int(k))
    use = collections.defaultdict(lambda: collections.defaultdict(lambda: collections.Counter()))  # name -> sid -> event -> n
    casters = collections.defaultdict(dict)  # name -> key -> rec
    first = collections.defaultdict(dict)    # (run, srcname) -> name -> first ts (SPELL_CAST_SUCCESS)
    rc = load_refclass()
    runs = sorted(glob.glob(FD + 'real/*/WoWCombatLog.txt'))
    for path in runs:
        run = path.split('/')[-2]; A = analyze(path, rc)['players']
        for ts, f in rows(path):
            if len(f) < 11 or not f[0].startswith('SPELL_'): continue
            nm = f[10].strip('"')
            if nm not in ALL: continue
            try: sid = int(f[9])
            except ValueError: continue
            use[nm][sid][f[0]] += 1
            src = f[1]
            if not src.startswith('Player-') or f[0] not in ('SPELL_CAST_SUCCESS', 'SPELL_AURA_APPLIED', 'SPELL_HEAL', 'SPELL_DAMAGE', 'SPELL_PERIODIC_HEAL'): continue
            p = A.get(src) or {}
            tot = (p.get('dmg') or 0) + (p.get('healOther') or 0)
            v = 'H' if p.get('healer') else ('D' if tot >= 2000 and (p.get('healShare') or 0) < 0.30 else 'U')
            k = src + '@' + run
            c = casters[nm].setdefault(k, dict(name=p.get('name') or src, run=run, cls=p.get('class'), share=p.get('healShare'), out=tot, v=v, casts=0, events=0, ids=set()))
            c['events'] += 1; c['ids'].add(sid)
            if f[0] == 'SPELL_CAST_SUCCESS': c['casts'] += 1; first[(run, c['name'])].setdefault(nm, ts)
    out = []
    for nm in ALL:
        cs = list(casters[nm].values())
        for c in cs: c['ids'] = sorted(c['ids'])
        out.append(dict(name=nm, spec=ALL[nm], userList=nm in USER, db2Ids=sorted(db2[nm]), refdataIds=sorted(refids[nm]),
                        logIds={str(s): dict(e) for s, e in sorted(use[nm].items())},
                        healers=[c for c in cs if c['v'] == 'H'], dps=[c for c in cs if c['v'] == 'D'], unknown=[c for c in cs if c['v'] == 'U']))
    json.dump(dict(runs=[p.split('/')[-2] for p in runs], spells=out,
                   firstCast={'%s|%s' % k: v for k, v in first.items()}), open(os.path.join(os.path.dirname(__file__), 'healer_spells8.json'), 'w'), indent=1, default=str)
    for s in out:
        print('==', s['name'], '|', s['spec'], '| DB2 ids', len(s['db2Ids']), '| refdata', s['refdataIds'])
        for sid, e in s['logIds'].items(): print('   log id', sid, e)
        for lab in ('healers', 'dps', 'unknown'):
            L = s[lab]
            print('  ', lab, len(L), 'casters', sum(c['casts'] for c in L), 'casts', sum(c['events'] for c in L), 'events',
                  [(c['name'], c['run'][-9:], c['cls'], c['share'], c['casts'], c['ids']) for c in L] if lab != 'healers' else '')
if __name__ == '__main__': main()
