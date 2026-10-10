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
"""Parse a Forever (advanced) combat log -> per-player heal/damage stats and healer truth.
Truth (dedicated healer): heals on OTHER players >= 30% of (damage + heals on others) and >= 5 direct heals on others.
Also T_any: any direct heal on another player. Raw names/GUIDs are kept (store raw rule)."""
import re, sys, csv, io, json, collections, datetime

HEAL_EV = ('SPELL_HEAL', 'SPELL_PERIODIC_HEAL')
DMG_EV = ('SWING_DAMAGE', 'SPELL_DAMAGE', 'SPELL_PERIODIC_DAMAGE', 'RANGE_DAMAGE', 'DAMAGE_SHIELD')

def parse_ts(s):
    """'10/9/2026 22:53:08.931-4' -> epoch. Time audit 2026-10-10: the log's own zone suffix (-4) decides; the naive
    datetime().timestamp() used the BOX zone, so on a box not in the client's zone every SV-epoch join (resolve.py
    clock offset, +-3 s window) was off by hours. Without a suffix the box zone is still the fallback."""
    m = re.match(r'(\d+)/(\d+)/(\d+) (\d+):(\d+):(\d+)\.(\d+)([+-]\d+(?:\.\d+)?)?', s)
    mo, d, y, H, M, S, ms = map(int, m.groups()[:7])
    frac = int(m.group(7)) / 10.0 ** len(m.group(7))
    if m.group(8) is None:
        return datetime.datetime(y, mo, d, H, M, S).timestamp() + frac
    off = float(m.group(8)) * 3600
    return datetime.datetime(y, mo, d, H, M, S, tzinfo=datetime.timezone.utc).timestamp() - off + frac

def rows(path):
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            i = line.find('  ')
            if i < 0: continue
            ts = line[:i]
            try:
                fields = next(csv.reader(io.StringIO(line[i + 2:].rstrip('\n'))))
            except Exception:
                continue
            yield ts, fields

def analyze(path, refclass=None):
    P = collections.defaultdict(lambda: {'name': None, 'healOther': 0, 'healOtherN': 0, 'healSelf': 0, 'dmg': 0,
                                         'hotOther': 0, 'spells': collections.Counter(), 'healSpells': collections.Counter(),
                                         'firstHealOther': None, 'firstSeen': None, 'castClass': collections.Counter(),
                                         'casts': collections.Counter()})
    healEvents = []  # (t, src, dst, spellId, amount, periodic)
    owner = 'unknown'
    t0 = None
    for ts, f in rows(path):
        ev = f[0]
        if ev in ('COMBAT_LOG_VERSION', 'ZONE_CHANGE', 'MAP_CHANGE', 'ENCOUNTER_START', 'ENCOUNTER_END', 'COMBATANT_INFO'):
            continue
        if len(f) < 9: continue
        t = parse_ts(ts)
        if t0 is None: t0 = t
        src, sname, sflags, dst, dname = f[1], f[2], f[3], f[5], f[6]
        if src.startswith('Player-'):
            p = P[src]; p['name'] = sname
            if p['firstSeen'] is None: p['firstSeen'] = t
            try:
                if int(sflags, 16) & 0x511 == 0x511 and owner == 'unknown': owner = src
            except ValueError: pass
        if dst.startswith('Player-'):
            q = P[dst]; q['name'] = q['name'] or dname
            if q['firstSeen'] is None: q['firstSeen'] = t
        if not src.startswith('Player-'): continue
        p = P[src]
        if ev in ('SPELL_CAST_SUCCESS', 'SPELL_CAST_START') and len(f) > 9:
            try: sid = int(f[9])
            except ValueError: continue
            p['casts'][sid] += 1
            if refclass and sid in refclass: p['castClass'][refclass[sid]] += 1
        elif ev in HEAL_EV and len(f) > 9:
            sid = int(f[9]); amt = 0
            try: amt = int(f[-5]) - int(f[-3]) if False else int(f[-5])
            except ValueError: pass
            # advanced: ..., amount, baseAmount, overheal, absorbed, critical -> amount at -5 in v22
            try:
                amount, overheal = int(f[-5]), int(f[-3])
                eff = max(0, amount - overheal)
            except ValueError:
                amount, eff = 0, 0
            periodic = ev == 'SPELL_PERIODIC_HEAL'
            if refclass and sid in refclass: p['castClass'][refclass[sid]] += 1
            if dst != src and dst.startswith('Player-'):
                p['healOther'] += amount
                p['healSpells'][sid] += 1
                if periodic: p['hotOther'] += 1
                else:
                    p['healOtherN'] += 1
                    if p['firstHealOther'] is None: p['firstHealOther'] = t
            elif dst == src:
                p['healSelf'] += amount
            healEvents.append((t, src, dst, sid, amount, periodic))
        elif ev in DMG_EV and len(f) > 9:
            # amount is the first field after the advanced block; for SWING it follows the 17 advanced fields at index 9
            try:
                base = 9 if ev == "SWING_DAMAGE" else 12
                amount = int(f[base + 19])
            except (ValueError, IndexError):
                amount = 0
            if dst.startswith('Player-') or dst.startswith('Creature-') or dst.startswith('Pet-'):
                p['dmg'] += max(0, amount)
    out = {}
    for g, p in P.items():
        tot = p['dmg'] + p['healOther']
        share = (p['healOther'] / tot) if tot > 0 else 0.0
        cls = p['castClass'].most_common(1)[0][0] if p['castClass'] else None
        out[g] = {'name': p['name'], 'class': cls, 'healOther': p['healOther'], 'healOtherN': p['healOtherN'],
                  'hotOtherN': p['hotOther'], 'healSelf': p['healSelf'], 'dmg': p['dmg'], 'healShare': round(share, 3),
                  'healer': share >= 0.30 and p['healOtherN'] >= 5, 'anyHealOther': p['healOtherN'] > 0,
                  'firstHealOther': p['firstHealOther'], 'firstSeen': p['firstSeen'],
                  'healSpells': dict(p['healSpells'].most_common(12))}
    return {'owner': owner, 't0': t0, 'players': out, 'healEvents': len(healEvents)}

def load_refclass():
    src = open(_WROOT + '/foreverdump/ForeverDump/Data/RefData.lua', encoding='utf-8').read()
    classes = re.search(r'classes\s*=\s*\{([^}]*)\}', src).group(1)
    classes = re.findall(r'"([A-Z]+)"', classes)
    rc = {}
    for m in re.finditer(r'\[(\d+)\]=\{(\d+),', src):
        code = int(m.group(2))
        if 0 < code <= len(classes): rc[int(m.group(1))] = classes[code - 1]
    return rc

if __name__ == '__main__':
    rc = load_refclass()
    r = analyze(sys.argv[1], rc)
    pl = sorted(r['players'].values(), key=lambda x: -x['healShare'])
    for p in pl:
        if p['dmg'] + p['healOther'] == 0: continue
        print('%-32s %-8s share=%.2f healOtherN=%4d hot=%4d dmg=%8d healO=%8d healer=%s' % (p['name'], p['class'], p['healShare'], p['healOtherN'], p['hotOtherN'], p['dmg'], p['healOther'], p['healer']))
