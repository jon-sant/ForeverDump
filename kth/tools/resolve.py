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
"""Resolve capture unit tokens to combat-log identities (offline only) and export a replay stream for the KTH Forever
addon test harness. Live, the addon reads UnitName(token) (clear on every hostile/friendly player token in BG per the
ForeverDump secrets guide); the capture ring does not store names per event, so the replay reconstructs the name behind
each token by joining UNIT_COMBAT (token, action, amount) to the combat log (dest, amount) within a small window.
Unresolved tokens stay unnamed (the addon then cannot attribute -> recall is a lower bound)."""
import sys, os, re, json, bisect, collections, pickle, datetime
sys.path.insert(0, _WROOT + '/foreverdump/tools')
sys.path.insert(0, os.path.dirname(__file__))
from fdump.bgreplay import load_raw, stream as fd_stream, main_capture
from fdump.luasv import as_list
from logtruth import rows, parse_ts, load_refclass, analyze

HEAL_EV = ('SPELL_HEAL', 'SPELL_PERIODIC_HEAL')
DMG_EV = ('SWING_DAMAGE', 'SPELL_DAMAGE', 'SPELL_PERIODIC_DAMAGE', 'RANGE_DAMAGE', 'DAMAGE_SHIELD')

def log_events(path):
    """[(epoch, kind, src, dst, amount, spellId, srcName, dstName)] kind in heal/dmg/cast"""
    out = []
    for ts, f in rows(path):
        ev = f[0]
        if len(f) < 9: continue
        if ev in HEAL_EV:
            try: amt = int(f[-5])
            except ValueError: continue
            out.append((parse_ts(ts), 'heal', f[1], f[5], amt, int(f[9]), f[2], f[6], ev == 'SPELL_PERIODIC_HEAL'))
        elif ev in DMG_EV:
            base = 9 if ev == 'SWING_DAMAGE' else 12
            try: amt = int(f[base + 19])
            except (ValueError, IndexError): continue
            sid = int(f[9]) if ev != 'SWING_DAMAGE' else 0
            out.append((parse_ts(ts), 'dmg', f[1], f[5], amt, sid, f[2], f[6], False))
        elif ev == 'SPELL_CAST_SUCCESS':
            try: sid = int(f[9])
            except ValueError: continue
            out.append((parse_ts(ts), 'cast', f[1], f[5], 0, sid, f[2], f[6], False))
    out.sort(key=lambda x: x[0])
    return out

def first_name(n):
    if not isinstance(n, str): return None
    return n.split('-')[0]

def resolve(run_dir):
    svp = run_dir + '/sv_raw/ForeverDump.pkl'
    if not os.path.exists(svp):
        svp = run_dir + '/sv_raw/ForeverDump.lua' if os.path.exists(run_dir + '/sv_raw/ForeverDump.lua') else run_dir + '/sv/ForeverDump.lua'
    raw = load_raw(svp)
    cs, rs = main_capture(raw)
    anc = cs.get('anchor') or {}
    e0, g0 = anc.get('epoch'), anc.get('gameTime')
    meta, evs = fd_stream(raw)
    L = log_events(run_dir + '/WoWCombatLog.txt')
    lt = [x[0] for x in L]
    owner = None
    for ts, f in rows(run_dir + '/WoWCombatLog.txt'):
        if len(f) > 3 and f[1].startswith('Player-'):
            try:
                if int(f[3], 16) & 0x511 == 0x511: owner = f[1]; break
            except ValueError: pass
    # 1) clock offset: player UNIT_COMBAT vs log events on the owner (same amount) -> median diff
    diffs = []
    for e in evs:
        if e.get('e') == 'UNIT_COMBAT' and (e.get('a') or [None])[0] == 'player':
            a = e['a']; amt = a[3] if len(a) > 3 else None
            if not isinstance(amt, int): continue
            ep = e0 + (e['t'] - g0)
            i = bisect.bisect_left(lt, ep - 3)
            kind = 'heal' if a[1] == 'HEAL' else 'dmg'
            while i < len(L) and L[i][0] <= ep + 3:
                x = L[i]
                if x[1] == kind and x[3] == owner and x[4] == amt: diffs.append(x[0] - ep)
                i += 1
    diffs.sort()
    off = diffs[len(diffs) // 2] if diffs else 0.0
    # 2) token observations
    obs = collections.defaultdict(list)   # token -> [(t, guid)]
    names = {}
    W = 0.15
    for e in evs:
        if e.get('e') != 'UNIT_COMBAT': continue
        a = e.get('a') or []
        if len(a) < 4 or not isinstance(a[0], str) or not isinstance(a[3], int): continue
        if a[1] not in ('HEAL', 'WOUND'): continue
        ep = e0 + (e['t'] - g0) + off
        kind = 'heal' if a[1] == 'HEAL' else 'dmg'
        i = bisect.bisect_left(lt, ep - W)
        cands = set()
        while i < len(L) and L[i][0] <= ep + W:
            x = L[i]
            if x[1] == kind and x[4] == a[3]: cands.add(x[3]); names[x[3]] = x[7]
            i += 1
        if len(cands) == 1:
            obs[a[0]].append((e['t'], cands.pop()))
    if owner: obs['player'].append((evs[0]['t'], owner))
    return dict(raw=raw, evs=evs, L=L, lt=lt, off=off, e0=e0, g0=g0, obs=obs, names=names, owner=owner, ndiff=len(diffs))

def token_at(R, tok, t, maxgap=8.0):
    """guid behind tok at game time t: nearest observation within maxgap s, only if no conflicting obs closer"""
    o = R['obs'].get(tok)
    if not o: return None
    ts = [x[0] for x in o]
    i = bisect.bisect_left(ts, t)
    best = None
    for j in (i - 1, i):
        if 0 <= j < len(o):
            d = abs(o[j][0] - t)
            if d <= maxgap and (best is None or d < best[0]): best = (d, o[j][1])
    if not best: return None
    # conflict check: both neighbours must agree when both are within maxgap
    nb = [o[j][1] for j in (i - 1, i) if 0 <= j < len(o) and abs(o[j][0] - t) <= maxgap]
    if len(set(nb)) > 1: return None
    return best[1]

if __name__ == '__main__':
    R = resolve(sys.argv[1])
    print('offset', R['off'], 'n', R['ndiff'], 'tokens', len(R['obs']), 'owner', R['owner'])
    for tok, o in sorted(R['obs'].items(), key=lambda x: -len(x[1]))[:25]:
        c = collections.Counter(g for _, g in o)
        print(tok, len(o), [(R['names'].get(g, g), n) for g, n in c.most_common(3)])
