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
import sys, json, re, collections
sys.path.insert(0,_WROOT + '/foreverdump/tools')
from fdump.luasv import parse_savedvariables
src=open(sys.argv[1],encoding='utf-8').read()
sv=parse_savedvariables(src)
DB=sv['KTHForeverDiagDB']
json.dump(DB,open(sys.argv[2],'w'),default=str,indent=0)
PH=['world','prep','ooc','combat','post']
def table(section, pred, label):
    agg=collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
    for k,v in DB.get(section,{}).items():
        m=re.match(r'^(.*)\|(\w+)\|p(-?\d+)$',k)
        if not m: continue
        key,ph,_=m.groups()
        if not pred(key): continue
        for c,n in v.items(): agg[key][ph][c]+=n
    print('\n### '+label)
    print('| key | '+' | '.join(PH)+' |'); print('|---|'+'---|'*len(PH))
    def sk(k):
        m=re.search(r'\.(\d+)$',k); return (re.sub(r'\.\d+$','',k), int(m.group(1)) if m else -1, k)
    for key in sorted(agg,key=sk):
        cells=[]
        for ph in PH:
            c=agg[key].get(ph)
            cells.append(' '.join('%s%d'%(x,c[x]) for x in sorted(c)) if c else '-')
        print('| %s | %s |'%(key,' | '.join(cells)))
table('score', lambda k: k.startswith('GetScoreInfo'), 'C_PvP.GetScoreInfo (table code, then field@tableCode)')
table('score', lambda k: k.startswith('GetBattlefieldScore') or k.startswith('GetNum'), 'GetBattlefieldScore positions')
table('units', lambda k: True, 'unit reads (family:side:API.return)')
table('spells', lambda k: True, 'UNIT_SPELLCAST_SUCCEEDED spellID')
print('\nsessions', json.dumps(DB.get('sessions'),default=str)[:1500])
print('\nblocked', json.dumps(DB.get('blocked'),default=str))
print('\nerrors', len(DB.get('errors') or []))
for e in (DB.get('errors') or [])[:20]: print('  ', json.dumps(e,default=str)[:700])
print('\nkthPrints', json.dumps(DB.get('kthPrints'),default=str)[:1500])
print('\nlastZone', DB.get('lastZone'), 'phaseNow', DB.get('phaseNow'))
