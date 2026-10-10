#!/usr/bin/env python3
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
"""forever.11 frame-time estimate for K.T.H. (mock timing x worst-case BG event rates).

1. Per-handler CPU cost: tests/replay_score.lua with KTH_PERF=1 (os.clock around every event K.T.H. receives, each
   C_Timer ticker and the plate-log tick) on the real replays of runs 16-19, debug off and on. The mock's Lua API stubs
   are part of the measured time (an upper bound: the real client's C API is not slower than the Lua mock).
2. Worst-case event rates: the raw combat logs of runs 16-19 (ForeverDump real/<run>/WoWCombatLog.txt), max events in
   any 1 s window and in any 1/60 s frame: combat events (damage/heal/miss incl. periodic) -> UNIT_COMBAT, cast
   successes -> UNIT_SPELLCAST_SUCCEEDED. Each combat event is counted x3 (a unit can be nameplateN + raidN + target)
   and each cast x2 (nameplateN + target/raidN): deliberately pessimistic. Replay streams give the measured lower rate.
3. Cost/s = sum(rate x mean cost) + tickers; % of a 60 fps frame = cost per frame / 16.67 ms.
"""
import json, os, re, subprocess, sys, collections
from datetime import datetime
K = _WROOT + '/kth'
RUNS = ['2026-10-09-run16-bg', '2026-10-10-run17-bg', '2026-10-10-run18-bg', '2026-10-10-run19-bg']
COMBAT = re.compile(r'^(SWING_DAMAGE|SWING_MISSED|RANGE_DAMAGE|RANGE_MISSED|SPELL_DAMAGE|SPELL_MISSED|SPELL_PERIODIC_DAMAGE|SPELL_PERIODIC_MISSED|SPELL_HEAL|SPELL_PERIODIC_HEAL|ENVIRONMENTAL_DAMAGE|DAMAGE_SHIELD)$')
env = dict(os.environ, FORE_DOCS=_WROOT + '/foreverdump/ref/wusf/Interface/AddOns', KTH_PERF='1')

def perf(run, dbg):
    out = f'/tmp/perf11.{run}.{dbg}.json'
    subprocess.run(['lua5.1', 'tests/replay_score.lua', 'port/KTH/KTH.toc', f'tests/replay/{run}.lua', out, 'port'],
                   cwd=K, env=dict(env, KTH_SETTINGS=f'debug={dbg}'), check=True, stdout=subprocess.DEVNULL)
    d = json.load(open(out)); return d['perf'], d['t1'] - d['t0']

def rates(run):
    sec, frame = collections.Counter(), collections.Counter()
    csec, cframe = collections.Counter(), collections.Counter()
    for line in open(f'{_WROOT}/foreverdump/real/{run}/WoWCombatLog.txt', encoding='utf-8', errors='replace'):
        m = re.match(r'(\d+)/(\d+)/(\d+) (\d+):(\d+):(\d+)\.(\d+)[-+]?\d*\s+([A-Z_]+),', line)
        if not m: continue
        mo, dd, yy, hh, mi, ss, ms, ev = m.groups()
        t = ((int(hh) * 60 + int(mi)) * 60 + int(ss)) + int(ms) / (10 ** len(ms))
        s, f = int(t), int(t * 60)
        if COMBAT.match(ev): sec[s] += 1; frame[f] += 1
        elif ev == 'SPELL_CAST_SUCCESS': csec[s] += 1; cframe[f] += 1
    mx = lambda c: max(c.values()) if c else 0
    return {'combat_s': mx(sec), 'combat_f': mx(frame), 'cast_s': mx(csec), 'cast_f': mx(cframe)}

def stream_rates(run):
    txt = open(f'{K}/tests/replay/{run}.lua', encoding='utf-8').read()
    c, u = collections.Counter(), collections.Counter()
    for t, k in re.findall(r'\{\s*([\d.]+)\s*,\s*"([CU])"', txt):
        (c if k == 'C' else u)[int(float(t))] += 1
    return max(u.values() or [0]), max(c.values() or [0])

rows, agg = [], {0: collections.defaultdict(lambda: [0, 0.0, 0.0]), 1: collections.defaultdict(lambda: [0, 0.0, 0.0])}
dur = {}
for run in RUNS:
    for dbg in (0, 1):
        P, d = perf(run, dbg); dur[run] = d
        for k, v in P.items():
            a = agg[dbg][k]; a[0] += v['n']; a[1] += v['total']; a[2] = max(a[2], v['max'])
R = {run: rates(run) for run in RUNS}
S = {run: stream_rates(run) for run in RUNS}
W = {k: max(R[r][k] for r in RUNS) for k in ('combat_s', 'combat_f', 'cast_s', 'cast_f')}
total_dur = sum(dur.values())
lines = ['# forever.11 frame-time estimate (tools/perf11.py)', '',
         'Per-handler CPU cost, runs 16-19 replays (sum %.0f s of match), mock timing (os.clock). Mean / max per call.' % total_dur, '',
         '| handler | calls | mean us (debug off) | max ms (off) | mean us (debug on) | max ms (on) | total ms off / on |', '|---|---|---|---|---|---|---|']
keys = sorted(set(agg[0]) | set(agg[1]), key=lambda k: -(agg[0][k][1]))
for k in keys:
    a, b = agg[0][k], agg[1][k]
    lines.append('| %s | %d | %.1f | %.2f | %.1f | %.2f | %.1f / %.1f |' % (k, a[0], a[1] / max(a[0], 1) * 1e6, a[2] * 1e3, b[1] / max(b[0], 1) * 1e6, b[2] * 1e3, a[1] * 1e3, b[1] * 1e3))
lines += ['', 'Whole-match average: K.T.H. CPU per second of match = %.3f ms (debug off), %.3f ms (debug on) = %.4f%% / %.4f%% of one CPU second.' % (
    sum(v[1] for v in agg[0].values()) / total_dur * 1e3, sum(v[1] for v in agg[1].values()) / total_dur * 1e3,
    sum(v[1] for v in agg[0].values()) / total_dur * 100, sum(v[1] for v in agg[1].values()) / total_dur * 100), '']
lines += ['Worst-case event rates (combat logs; replay streams = what K.T.H. was measured to receive):', '',
          '| run | combat events max/s | max/frame | casts max/s | max/frame | replay UNIT_COMBAT max/s | replay casts max/s |', '|---|---|---|---|---|---|---|']
for r in RUNS:
    lines.append('| %s | %d | %d | %d | %d | %d | %d |' % (r[11:16], R[r]['combat_s'], R[r]['combat_f'], R[r]['cast_s'], R[r]['cast_f'], S[r][0], S[r][1]))
def est(dbg):
    A = agg[dbg]; m = lambda k: (A[k][1] / A[k][0]) if A.get(k) and A[k][0] else 0.0
    uc, sc = m('event:UNIT_COMBAT'), m('event:UNIT_SPELLCAST_SUCCEEDED')
    per_s = 3 * W['combat_s'] * uc + 2 * W['cast_s'] * sc
    per_s += m('ticker:1s') + m('ticker:2s') / 2 + m('event:UPDATE_MOUSEOVER_UNIT') * 5 + m('event:NAME_PLATE_UNIT_ADDED') * 10 + m('event:UPDATE_BATTLEFIELD_SCORE') * 1
    per_f = 3 * W['combat_f'] * uc + 2 * W['cast_f'] * sc
    spike = max(A[k][2] for k in A)
    return per_s, per_f, spike
lines += ['', 'Estimate at the worst second / worst frame of runs 16-19 (pessimistic token fan-out x3 / x2, plus 5 hovers, 10 plate adds and 1 scoreboard update per second):', '',
          '| debug | busiest second: K.T.H. ms per s | = average per 60 fps frame | % of 16.67 ms budget | busiest frame (event burst) ms | % of budget | largest single call ms (meter read / scoreboard / scan) |', '|---|---|---|---|---|---|---|']
for dbg in (0, 1):
    ps, pf, sp = est(dbg)
    lines.append('| %s | %.2f | %.3f ms | %.2f%% | %.3f | %.2f%% | %.2f |' % ('on' if dbg else 'off', ps * 1e3, ps * 1e3 / 60, ps * 1e3 / 60 / 16.667 * 100, pf * 1e3, pf * 1e3 / 16.667 * 100, sp * 1e3))
print('\n'.join(lines))
