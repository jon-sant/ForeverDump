"""forever.6 forensics: per enemy player of a can-heal class (and every earlier false mark/claim), which signals the
addon could read and when. Sources: tests/replay/<run>.lua (plate/power/cast/UNIT_COMBAT events as captured),
tests/replay/<run>.dm.lua via kth/dm/<run>.dm.jsonl (meter rows), tests/results/<run>.{port3,port5}.json, truth."""
import json, re, glob, collections, statistics, sys
CANHEAL = {'PRIEST', 'PALADIN', 'DRUID', 'SHAMAN', 'MONK', 'EVOKER'}
def ev(run):
    s = open(f'tests/replay/{run}.lua', encoding='utf-8').read()
    for m in re.finditer(r'\{([\d.]+),"(\w)",(nil|"[^"]*"),(nil|\d+),(nil|"[^"]*")\}', s):
        t, k, tok, gi, a = m.groups()
        yield float(t), k, None if tok == 'nil' else tok.strip('"'), None if gi == 'nil' else int(gi), None if a == 'nil' else a.strip('"')
def rows(run):
    for l in open(f'dm/{run}.dm.jsonl'):
        yield json.loads(l)
def analyze(run):
    tr = json.load(open(f'tests/replay/{run}.truth.json')); ro = tr['roster']; g0 = tr['meta']['g0']; e0 = tr['meta']['e0']
    cls = lambda r: r.get('cls') or r.get('cls_log')
    P = collections.defaultdict(lambda: {'pw': collections.Counter(), 'first': None, 'sight': 0, 'C': 0, 'Uh': 0, 'Uw': 0})
    for t, k, tok, gi, a in ev(run):
        if not gi: continue
        p = P[gi]
        if tok and tok.startswith('nameplate'):
            if k == 'A': p['sight'] += 1; p['first'] = p['first'] if p['first'] is not None else round(t - g0)
        if k == 'P' and a in ('MANA', 'RAGE', 'ENERGY', 'FOCUS', 'RUNIC_POWER'): p['pw'][a] += 1
        if k == 'C': p['C'] += 1
        if k == 'U': p['Uh' if a == 'HEAL' else 'Uw'] += (a in ('HEAL', 'WOUND'))
    d3 = json.load(open(f'tests/results/{run[11:16]}.port3.json')); d5 = json.load(open(f'tests/results/{run[11:16]}.port5.json'))
    m3 = d3['marks'] if isinstance(d3['marks'], dict) else {}; m5 = d5['marks'] if isinstance(d5['marks'], dict) else {}
    out = []
    for i, r in enumerate(ro, 1):
        c = cls(r)
        k = ('E:' if r['side'] == 'E' else 'F:') + r['full']
        rec = (d5.get('recs') or {}).get(k) or {}
        rec3 = (d3.get('recs') or {}).get(k) or (d3.get('recs') or {}).get(k.split(' ')[0]) or {}
        p = P[i]
        out.append(dict(run=run[11:16], side=r['side'], name=r['first'], cls=c, healer=r['healer'], share=r['share'], hoN=r['hoN'],
            plateFirst=p['first'], sightings=p['sight'], power=dict(p['pw']), casts=p['C'], combatHeal=p['Uh'], combatWound=p['Uw'],
            links=(rec.get('heal'), rec.get('dmg')), f3mark=(round(m3[str(i)]['t'] - g0), m3[str(i)]['method']) if str(i) in m3 else None,
            f3claim=rec3.get('claim'), f5mark=round(m5[str(i)]['t'] - g0) if str(i) in m5 else None, f5why=rec.get('why'),
            nClass=sum(1 for x in ro if x['side'] == r['side'] and cls(x) == c), healersInClass=sum(1 for x in ro if x['side'] == r['side'] and cls(x) == c and x['healer'])))
    return out
if __name__ == '__main__':
    for run in ['2026-10-09-run16-bg', '2026-10-10-run17-bg', '2026-10-10-run18-bg']:
        for o in analyze(run):
            if (o['side'] == 'E' and o['cls'] in CANHEAL) or o['f3claim'] == 'HEALER' and not o['healer']:
                print(json.dumps(o, ensure_ascii=False))
