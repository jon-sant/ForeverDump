"""forever.5 scores on real data only (runs 16-18: real scoreboards + real C_DamageMeter snapshots + combat-log truth).
Truth: tools/logtruth.py healer flag (heals on other players >= 30% of output and >= 5 direct heals), and the user's
definition checked alongside (heals on others = majority of output, share >= 50%)."""
import json, sys, glob, statistics, collections, os
RUNS = os.environ.get('KTH_RUNS', 'run16,run17,run18').split(',')  # run19: held-out (KTH_RUNS=run19)
VARS = sys.argv[1:] or ['orig', 'port3', 'port5-nometer', 'port5']
DETAIL = VARS[-1]
def truth(run): return json.load(open(glob.glob(f'tests/replay/*-{run}-bg.truth.json')[0]))
def med(x): return round(statistics.median(x), 1) if x else None
def cls(r): return r.get('cls') or r.get('cls_log')
PH = [(0, 120, '0-2 min'), (120, 300, '2-5 min'), (300, 600, '5-10 min'), (600, 1e9, '10 min+')]
summary, phase, detail = [], {}, []
for v in VARS:
    A = collections.Counter(); tti = []; flipsH = []; flipsN = []
    ph = collections.Counter(); nEH = 0
    for run in RUNS:
        d = json.load(open(f'tests/results/{run}.{v}.json')); tr = truth(run); ro, m = tr['roster'], tr['meta']
        seen = {int(k): t for k, t in d['seen'].items()} if isinstance(d['seen'], dict) else {}
        marks = {int(k): x for k, x in d['marks'].items()} if isinstance(d['marks'], dict) else {}
        fl = {int(k): x.get('off', x['why'].count('off:')) for k, x in d['flips'].items()} if isinstance(d['flips'], dict) else {}
        for i in seen:
            r = ro[i-1]; H = r['healer']; H50 = r['share'] >= 0.5 and r.get('hoEv', r['hoN']) >= 5
            A['seen'] += 1; A['seenH'] += H; A['seenH50'] += H50
            if i in marks:
                A['mark'] += 1; A['TP'] += H; A['TP50'] += H50
                if H: tti.append(marks[i]['t'] - seen[i])
            if cls(r) == 'DRUID':
                if H: A['druidH'] += 1; A['druidHmissed'] += (i not in marks)
                else: A['druidN'] += 1; A['druidNmarked'] += (i in marks)
            (flipsH if H else flipsN).append(fl.get(i, 0))
            if H:
                nEH += 1
                tm = marks[i]['t'] - m['g0'] if i in marks else None
                lab = 'never' if tm is None else next(l for a, b, l in PH if a <= tm < b)
                ph[lab] += 1
                if v == DETAIL:
                    rec = (d.get('recs') or {}).get('E:' + r['full']) or (d.get('recs') or {}).get('E:' + r['first']) or {}
                    detail.append((run, r['first'], cls(r), round(r['share'], 2), round(seen[i] - m['g0']), None if tm is None else round(tm), rec.get('why'), rec.get('heal'), rec.get('dmg'), rec.get('offs')))
        # claims (both sides)
        recs = d.get('recs') if isinstance(d.get('recs'), dict) else {}
        key = {}
        for i, r in enumerate(ro, 1):
            for nm in (r['first'], r.get('full')):
                if nm: key[('F:' if r['side'] == 'F' else 'E:') + nm] = i
        cl = {key[k] for k, r in recs.items() if (r.get('claim') == 'HEALER' or r.get('firstClaimT')) and k in key}
        A['claims'] += len(cl); A['claimTP'] += sum(1 for i in cl if ro[i-1]['healer'])
        A['claimHF'] += sum(1 for r in ro if r['healer'] and r['side'] == 'F'); A['claimHE'] += sum(1 for r in ro if r['healer'] and r['side'] == 'E')
        A['claimTPF'] += sum(1 for i in cl if ro[i-1]['healer'] and ro[i-1]['side'] == 'F')
        A['claimTPE'] += sum(1 for i in cl if ro[i-1]['healer'] and ro[i-1]['side'] == 'E')
        A['claimFP_druid'] += sum(1 for i in cl if not ro[i-1]['healer'] and cls(ro[i-1]) == 'DRUID')
        mo = d.get('mouseover') or {}
        A['moA'] += mo.get('alerted', 0); A['moV'] += mo.get('verdictTrue', 0) - mo.get('onTarget', 0)
    f = lambda a, b: f'{a}/{b}' + (f' = {100*a/b:.0f}%' if b else '')
    summary.append(f"| {v} | {f(A['TP'], A['mark'])} | {f(A['TP'], A['seenH'])} | {med(tti)} | {sum(flipsH)}/{len(flipsH)} | {sum(flipsN)}/{len(flipsN)} | {A['druidNmarked']}/{A['druidN']} | {A['druidHmissed']}/{A['druidH']} | {f(A['TP50'], A['seenH50'])} | {f(A['claimTP'], A['claims'])} | {f(A['claimTPF'], A['claimHF'])} | {f(A['claimTPE'], A['claimHE'])} | {A['claimFP_druid']} | {f(A['moA'], A['moV'])} |")
    phase[v] = (nEH, ph)
print('| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | icon on->off flips, healers (sum/units) | on->off flips, non-healers | non-healer druids marked | healer druids missed | plate recall, user definition (heal share >= 50%) | claim precision | claim recall F | claim recall E | non-healer druid claims | mouse-over alerts / healer-verdict hovers |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
print('\n'.join(summary))
print('\nEnemy healers (seen on plates) first marked, by match phase (match time from the gates):')
print('| variant | ' + ' | '.join(l for _, _, l in PH) + ' | never |'); print('|---|' + '---|' * (len(PH) + 1))
for v, (n, ph) in phase.items():
    acc = 0; cells = []
    for _, _, l in PH: acc += ph[l]; cells.append(f'{ph[l]} (cum {acc}/{n})')
    print(f'| {v} | ' + ' | '.join(cells) + f" | {ph['never']} |")
print('\n' + DETAIL + ' per enemy healer: run, name, class, log heal share, first seen s, first mark s, why, heal links, dmg links, revokes')
for x in detail: print(' ', x)
