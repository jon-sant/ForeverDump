"""Score replay results (tests/results/<run>.<variant>.json) against truth (tests/replay/<run>.truth.json)."""
import json, sys, statistics
import glob, os
# forever.4: real data only. Runs 16, 17, 18 carry the real scoreboard (full names backed by their own FD SV, R8).
# Runs 10-13 have no real scoreboard names (board-less replays): every score here depends on the scoreboard (class
# join, D5b, mouse-over resolver, post-match), so they are dropped from all scores.
RUNS = ['run16', 'run17', 'run18']
REAL = set(RUNS)
VARS = sys.argv[1:] or ['orig', 'port2', 'port3']
def truth(run): return json.load(open(glob.glob(f'tests/replay/*-{run}-bg.truth.json')[0]))
def med(x): return round(statistics.median(x), 1) if x else None
tot = {}
rows = []
for v in VARS:
    A = dict(pm=0, pTP=0, pH=0, pTTI=[], cm=0, cTP=0, cH=0, cTTI=[], cHE=0, cHF=0, cTPE=0, cTPF=0)
    for run in RUNS:
        d = json.load(open(f'tests/results/{run}.{v}.json'))
        tr = truth(run)
        ro, m = tr['roster'], tr['meta']
        ep = lambda t: m['e0'] + (t - m['g0']) + m['off']
        seen = {int(k): t for k, t in d['seen'].items()} if isinstance(d['seen'], dict) else {}
        marks = {int(k): x for k, x in (d['marks'] or {}).items()} if isinstance(d['marks'], dict) else {}
        # plate level (only enemies have plates in these captures)
        pH = [i for i in seen if ro[i-1]['healer']]
        pTP = [i for i in marks if ro[i-1]['healer']]
        A['pm'] += len(marks); A['pTP'] += len(pTP); A['pH'] += len(pH)
        A['pTTI'] += [marks[i]['t'] - seen[i] for i in pTP]
        # claim level (heal evidence registry, both sides)
        recs = d.get('recs') if isinstance(d.get('recs'), dict) else {}
        key = {('F:' if r['side'] == 'F' else 'E:') + r['first']: i for i, r in enumerate(ro, 1)}
        key.update({('F:' if r['side'] == 'F' else 'E:') + r['full']: i for i, r in enumerate(ro, 1)})
        cl = {key[k]: r for k, r in recs.items() if r.get('claim') == 'HEALER' and k in key}
        cH = [i for i, r in enumerate(ro, 1) if r['healer']]
        A['cm'] += len(cl); A['cTP'] += sum(1 for i in cl if ro[i-1]['healer']); A['cH'] += len(cH)
        A['cHE'] += sum(1 for i in cH if ro[i-1]['side'] == 'E'); A['cHF'] += sum(1 for i in cH if ro[i-1]['side'] == 'F')
        A['cTPE'] += sum(1 for i in cl if ro[i-1]['healer'] and ro[i-1]['side'] == 'E')
        A['cTPF'] += sum(1 for i in cl if ro[i-1]['healer'] and ro[i-1]['side'] == 'F')
        for i, r in cl.items():
            if ro[i-1]['healer']:
                t_stream = r['claimT'] - 1000 + d['t0']
                A['cTTI'].append(ep(t_stream) - max(ro[i-1]['first_t'] or m['w0'], m['w0']))
        mo = d.get('mouseover') or {}
        A.setdefault('moV', 0); A.setdefault('moA', 0); A.setdefault('moM', 0)
        A['moV'] += mo.get('verdictTrue', 0) - mo.get('onTarget', 0); A['moA'] += mo.get('alerted', 0); A['moM'] += mo.get('missed', 0)
        fl = d.get('flips') if isinstance(d.get('flips'), dict) else {}
        hfl = sum(x['n'] for k, x in fl.items() if ro[int(k)-1]['healer'])
        nfl = sum(x['n'] for k, x in fl.items() if not ro[int(k)-1]['healer'])
        pl = d.get('platelog') or {}
        rows.append((v, run, len(marks), len(pTP), len(pH), len(cl), sum(1 for i in cl if ro[i-1]['healer']), len(cH),
                     f"{mo.get('alerted', 0)}/{mo.get('verdictTrue', 0) - mo.get('onTarget', 0)}", f"{hfl}/{nfl}", f"{pl.get('healerNoIcon', '-')}/{pl.get('iconNoHealer', '-')}"))
    tot[v] = A
print('| variant | run | plate marks | plate TP | enemy healers seen on plates | evidence claims | claim TP | truth healers | mouse-over alerts / healer-verdict hovers (not target) | verdict flips healer/non-healer | plate log healerNoIcon/iconNoHealer |')
print('|---|---|---|---|---|---|---|---|---|---|---|')
for r in rows: print('| ' + ' | '.join(map(str, r)) + ' |')
print()
print('| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | claim precision | claim recall all | claim recall F | claim recall E | claim TTI median s | mouse-over alert rate |')
print('|---|---|---|---|---|---|---|---|---|---|')
for v, A in tot.items():
    f = lambda a, b: f'{a}/{b}' + (f' = {100*a/b:.0f}%' if b else '')
    print(f"| {v} | {f(A['pTP'], A['pm'])} | {f(A['pTP'], A['pH'])} | {med(A['pTTI'])} | {f(A['cTP'], A['cm'])} | {f(A['cTP'], A['cH'])} | {f(A['cTPF'], A['cHF'])} | {f(A['cTPE'], A['cHE'])} | {med(A['cTTI'])} | {f(A['moA'], A['moV'])} |")
