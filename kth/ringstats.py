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
import sys, pickle, collections, re, os
sys.path.insert(0,_WROOT + '/foreverdump/tools')
from fdump.bgreplay import load_raw, main_capture
from fdump.luasv import as_list
for run in sys.argv[1:]:
    d=_WROOT + '/foreverdump/real/'+run
    p=d+'/sv_raw/ForeverDump.pkl' if os.path.exists(d+'/sv_raw/ForeverDump.pkl') else (d+'/sv_raw/ForeverDump.lua' if os.path.exists(d+'/sv_raw/ForeverDump.lua') else d+'/sv/ForeverDump.lua')
    raw=load_raw(p)
    cs,rs=main_capture(raw)
    c=collections.Counter(); sc=collections.Counter()
    for src,sess in (('ring',cs),('rec',rs)):
        if not sess: continue
        for e in as_list(sess.get('events')):
            a=e.get('a') or []
            if not a or not isinstance(a[0],str): continue
            fam=re.sub(r'\d+','N',a[0])
            if e['e'].startswith('UNIT_SPELLCAST') and fam not in ('player','raidN','partyN'):
                c[(src,e['e'],fam)]+=1
                if len(a)>2: sc[(src,fam,'sid-secret' if a[2]=='<secret>' else 'sid-clear')]+=1
            if e['e']=='UNIT_COMBAT' and len(a)>1 and a[1]=='HEAL' and fam not in ('player','raidN','partyN'):
                c[(src,'UC_HEAL',fam)]+=1
            if e['e'] in ('NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','UPDATE_BATTLEFIELD_SCORE'):
                c[(src,e['e'],fam)]+=1
    print('=====',run,os.path.basename(p), 'regs', sorted(as_list(cs.get('registered')))[:80] if cs else None)
    for k,v in sorted(c.items()): print(' ',k,v)
    for k,v in sorted(sc.items()): print(' ',k,v)
