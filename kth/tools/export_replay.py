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
"""Export a ForeverDump BG capture (raw SV, never scrubbed) + its combat log into a replay stream for the KTH Forever
Lua harness, and the per-BG truth used for scoring.
- token identity: tools/resolve.py (UNIT_COMBAT amount join to the log; unresolved tokens stay nameless)
- scoreboard (forever.4): REAL full names only. tools/realnames.py recovers "First Surname" for each roster player from
  the run's own FD SV (guid-linked meter/identity records, scoreboard records, plate name-realm). If 100% of the
  roster gets a real name the replay carries a real board (name, faction by hostility, classToken = the scoreboard's
  class, which must agree with the log-voted class); otherwise the replay has NO board: no full names, no classes,
  first names only as logged (board = "none"). Nothing is synthesized.
- truth: restricted to the capture window, dedicated healer = heal on others (direct + HoT ticks) >= 30% of
  (dmg + heal on others) and >= 5 heal events on others INCLUDING HoT ticks (truth v2, 2026-10-10 user decision: HoT
  healers count; v1 required >= 5 direct heals and is kept as healer_v1)"""
import sys, os, json, collections, bisect
sys.path.insert(0, os.path.dirname(__file__))
from resolve import resolve, token_at, first_name
from logtruth import rows, load_refclass, analyze
import realnames

KEEP = {'UNIT_SPELLCAST_SUCCEEDED': 'C', 'UNIT_COMBAT': 'U', 'NAME_PLATE_UNIT_ADDED': 'A', 'NAME_PLATE_UNIT_REMOVED': 'R',
        'UNIT_POWER_UPDATE': 'P', 'UNIT_POWER_FREQUENT': 'P', 'UPDATE_BATTLEFIELD_SCORE': 'S', 'PLAYER_TARGET_CHANGED': 'T'}

def lua(v):
    if v is None: return 'nil'
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, (int, float)): return repr(v)
    return '"' + str(v).replace('\\', '\\\\').replace('"', '\\"') + '"'

def export(run, outdir):
    d = _WROOT + '/foreverdump/real/' + run
    R = resolve(d)
    evs, off, e0, g0 = R['evs'], R['off'], R['e0'], R['g0']
    owner = R['owner']
    t_first, t_last = evs[0]['t'], evs[-1]['t']
    ep = lambda t: e0 + (t - g0) + off
    w0, w1 = ep(t_first), ep(t_last)
    # hostility + class from the full log
    rc = load_refclass()
    full = analyze(d + '/WoWCombatLog.txt', rc)['players']
    host = collections.defaultdict(collections.Counter)
    for ts, f in rows(d + '/WoWCombatLog.txt'):
        if len(f) < 8: continue
        for g, fl in ((f[1], f[3]), (f[5], f[7])):
            if g.startswith('Player-'):
                try: host[g]['E' if int(fl, 16) & 0x40 else 'F'] += 1
                except ValueError: pass
    # truth inside the capture window
    P = collections.defaultdict(lambda: {'hoN': 0, 'hoEv': 0, 'ho': 0, 'dmg': 0, 'first': None, 'firstHO': None, 'firstHOany': None})
    for x in R['L']:
        t, kind, src, dst, amt, sid, sn, dn, per = x
        if t < w0 or t > w1: continue
        for g in (src, dst):
            if g.startswith('Player-') and P[g]['first'] is None: P[g]['first'] = t
        if not src.startswith('Player-'): continue
        if kind == 'heal' and dst != src and dst.startswith('Player-'):
            P[src]['ho'] += amt
            P[src]['hoEv'] += 1
            if P[src]['firstHOany'] is None: P[src]['firstHOany'] = t
            if not per:
                P[src]['hoN'] += 1
                if P[src]['firstHO'] is None: P[src]['firstHO'] = t
        elif kind == 'dmg':
            P[src]['dmg'] += max(0, amt)
    names = {g: (full.get(g, {}).get('name') or R['names'].get(g)) for g in P}
    roster = []
    gidx = {}
    for g, p in sorted(P.items()):
        nm = names.get(g)
        if not nm or g == owner: continue
        tot = p['dmg'] + p['ho']
        share = p['ho'] / tot if tot > 0 else 0.0
        side = host[g].most_common(1)[0][0] if host[g] else 'F'
        gidx[g] = len(roster) + 1
        roster.append(dict(guid=g, first=first_name(nm), full=first_name(nm) + ' Synth', side=side,
                           cls=full.get(g, {}).get('class'), healer=share >= 0.30 and p['hoEv'] >= 5, healer_v1=share >= 0.30 and p['hoN'] >= 5,
                           anyHO=p['hoN'] > 0, share=round(share, 3), hoN=p['hoN'], first_t=p['first'], firstHO=p['firstHO'],
                           ho=p['ho'], dmg=p['dmg'], hoEv=p['hoEv'], firstHOany=p['firstHOany']))
    # forever.4: real names or no board
    names_real, _src = realnames.resolve(run, roster)
    board = all(v[0] for v in names_real.values()) and len(roster) > 0
    for r in roster:
        if board:
            r['full'] = names_real[r['guid']][0]; r['fullHow'] = names_real[r['guid']][1]
        else:
            r['full'] = None
        r['cls_log'] = r.pop('cls')
    if owner: gidx[owner] = 0
    # events
    out = []
    unresolved = collections.Counter(); resolved = collections.Counter()
    for e in evs:
        k = KEEP.get(e.get('e'))
        if not k: continue
        a = e.get('a') or []
        if k == 'S' or k == 'T':
            out.append((e['t'], k, None, None, None)); continue
        if not a or not isinstance(a[0], str): continue
        tok = a[0]
        if tok == 'player': gi = 0
        else:
            g = token_at(R, tok, e['t'])
            gi = gidx.get(g) if g else None
        if gi is None: unresolved[k] += 1
        else: resolved[k] += 1
        arg = None
        if k == 'C': arg = a[2] if len(a) > 2 and isinstance(a[2], int) else 'SECRET'
        elif k == 'U': arg = a[1] if len(a) > 1 else None
        elif k == 'P': arg = a[1] if len(a) > 1 and isinstance(a[1], str) else None
        out.append((e['t'], k, tok, gi, arg))
    meta = dict(run=run, owner=owner, off=off, e0=e0, g0=g0, w0=w0, w1=w1, resolved=dict(resolved), unresolved=dict(unresolved),
                nRoster=len(roster), nHealers=sum(r['healer'] for r in roster),
                board=('real: full names from this run\'s FD SV (tools/realnames.py), 100 percent of the roster' if board
                       else 'none: no real scoreboard names in this run\'s FD SV; first names as logged only, no classes'))
    with open(os.path.join(outdir, run + '.lua'), 'w') as f:
        f.write('-- generated by tools/export_replay.py from raw capture + combat log (%s); board: %s\nreturn {\n' % (run, meta['board']))
        f.write(' meta = { run = %s, e0 = %s, g0 = %s, off = %s, board = %s },\n' % (lua(run), lua(e0), lua(g0), lua(off), lua(board)))
        f.write(' roster = {\n')
        for r in roster:
            f.write('  { first = %s, full = %s, side = %s, class = %s },\n' % (lua(r['first']), lua(r['full']), lua(r['side']), lua(r['cls_log'] if board else None)))
        f.write(' },\n ev = {\n')
        for t, k, tok, gi, arg in out:
            f.write('  {%s,%s,%s,%s,%s},\n' % (lua(t), lua(k), lua(tok), lua(gi), lua(arg)))
        f.write(' },\n}\n')
    json.dump(dict(meta=meta, roster=roster), open(os.path.join(outdir, run + '.truth.json'), 'w'), indent=1, default=str)
    return meta

if __name__ == '__main__':
    outdir = sys.argv[1]
    for run in sys.argv[2:]:
        print(json.dumps(export(run, outdir), default=str))
