"""forever.7: per enemy healer timeline on the real replays (runs 16-18): first heal on another player (combat log),
first plate sighting, first heal link, first claim, first plate mark, and the readable-meter context (regen times,
first kept FD snapshot). Usage: python3 tools/tti7.py <variant>   (tests/results/<run>.<variant>.json)"""
import json, sys, pickle, os
V = sys.argv[1] if len(sys.argv) > 1 else 'port7'
RUNS = [('run16', '2026-10-09-run16-bg'), ('run17', '2026-10-10-run17-bg'), ('run18', '2026-10-10-run18-bg')]
rows = []
for run, R in RUNS:
    d = json.load(open(f'tests/results/{run}.{V}.json')); tr = json.load(open(f'tests/replay/{R}.truth.json')); m = tr['meta']
    ro = tr['roster']; recs = d.get('recs') or {}
    marks = {int(k): v for k, v in (d['marks'] or {}).items()} if isinstance(d['marks'], dict) else {}
    seen = {int(k): v for k, v in (d['seen'] or {}).items()} if isinstance(d['seen'], dict) else {}
    snap0 = json.loads(open(f'dm/{R}.dm.jsonl').readline())['time'] - m['e0']
    for i, r in enumerate(ro, 1):
        if r['side'] != 'E' or not r['healer']: continue
        rec = recs.get('E:' + r['full']) or recs.get('E:' + r['first']) or {}
        fh = (r['firstHO'] - m['e0'] - m['off']) if r.get('firstHO') else None
        mk = (marks[i]['t'] - m['g0']) if i in marks else None
        cl = (rec['firstClaimT'] - 1000) if rec.get('firstClaimT') else None
        hl = (rec['healT1'] - 1000) if rec.get('healT1') else None
        sn = (seen[i] - m['g0']) if i in seen else None
        rows.append((run, r['first'], r.get('cls'), round(r['share'], 2), None if fh is None else round(fh), None if sn is None else round(sn),
                     None if hl is None else round(hl), None if cl is None else round(cl), None if mk is None else round(mk),
                     None if (mk is None or fh is None) else round(mk - fh), round(snap0), rec.get('why')))
print('| run | healer | class | log share | first heal on other s | first plate s | first heal link s | claim s | plate mark s | mark - first heal s | first kept meter snapshot s | why |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|')
for x in rows: print('| ' + ' | '.join('-' if v is None else str(v) for v in x) + ' |')
lat = sorted(x[9] for x in rows if x[9] is not None)
if lat: print(f'\nmedian mark - first heal: {lat[len(lat)//2]} s; min {lat[0]} s; max {lat[-1]} s; n={len(lat)}')
