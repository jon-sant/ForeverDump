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
import sys, json
sys.path.insert(0,'tools')
from logtruth import analyze, load_refclass
rc=load_refclass()
runs=['2026-10-08-run8-bg','2026-10-08-run9-bg','2026-10-09-run10-bg','2026-10-09-run11-bg','2026-10-09-run12-bg','2026-10-09-run13-bg','2026-10-09-run14-bg','2026-10-09-run15-bg','2026-10-09-run16-bg']
T={}
for r in runs:
    a=analyze(_WROOT + '/foreverdump/real/%s/WoWCombatLog.txt'%r, rc)
    T[r]={g:{k:v for k,v in p.items() if k!='healSpells'} | {'healSpells':p['healSpells']} for g,p in a['players'].items()}
    T[r]['_owner']=a['owner']
json.dump(T,open(_WROOT + '/kth/truth_all.json','w'),default=str)
seen={}
for r in runs:
    pl={g:p for g,p in T[r].items() if g!='_owner' and (p['dmg']+p['healOther'])>0}
    h=[g for g,p in pl.items() if p['healer']]
    prior=[g for g in h if g in seen]
    priorH=[g for g in h if seen.get(g)=='H']
    fp=[g for g,p in pl.items() if not p['healer'] and seen.get(g)=='H']
    print(r,'players',len(pl),'healers',len(h),'healers seen before',len(prior),'seen before AS healer',len(priorH),'nonhealers previously healer',len(fp))
    for g,p in pl.items():
        seen[g]='H' if p['healer'] else seen.get(g,'D') if seen.get(g)=='H' else 'D'
