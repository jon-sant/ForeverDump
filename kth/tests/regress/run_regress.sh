#!/bin/sh
WOWDEV_ROOT="${WOWDEV_ROOT:-$(d="$(cd "$(dirname "$0")" && pwd)"; while [ "$d" != / ] && [ ! -d "$d/foreverdump" ]; do d="$(dirname "$d")"; done; echo "$d")}"  # portable root (handoff)
# forever.3 regressions. Exit 1 on any failure.
set -e
cd $WOWDEV_ROOT/kth
fail=0
# R1 (F1): /kthg, /hhtd, /hhtdg open the AceConfig dialogs with no Lua error under Forever API strictness
out=$(lua5.1 tests/load_smoke.lua port/KTH/KTH.toc 2>&1 || true)
if echo "$out" | grep -q "^errors:.0$" && echo "$out" | grep -q "^blizzChat lines:.0$" && echo "$out" | grep -q "^options UIs opened:.3$"; then echo "R1 ok: /kthg /hhtd /hhtdg open, 0 errors, 0 Blizzard chat lines"; else echo "R1 FAIL"; echo "$out" | tail -8; fail=1; fi
# R2 (D5b): duplicate first names joined exactly by name+realm(surname)
KTH_TARGET_TEST=1 lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/regress/dupfirst_stream.lua /tmp/regress_dup.json port >/dev/null
python3 - <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/regress_dup.json')); m=d['marks'] if isinstance(d['marks'],dict) else {}
ok = set(m)=={'1'} and not d['errors']
print('R2', 'ok' if ok else 'FAIL', 'marks', sorted(m), 'errors', len(d['errors']))
mo=d['mouseover']; ok2 = mo['alerted']>0 and mo['alertedNoVerdict']==0 and mo['missed']==0 and mo.get('targetLocked',0)==mo['alerted']
print('R3', 'ok' if ok2 else 'FAIL', 'mouse-over on the healer plays the announcer sound, clicking it plays the target-lock sound:', mo)
sys.exit(0 if ok and ok2 else 1)
PY
# R4 (F3): on every real replay the mouse-over alert fires for every healer-verdict hover (not on target);
# R5 (F2/F6): icon state == verdict in the plate log
# real-board replays only (runs 10-13 are board-less, see R8)
for r in tests/replay/2026-10-09-run16-bg.lua tests/replay/2026-10-10-run17-bg.lua tests/replay/2026-10-10-run18-bg.lua; do
  lua5.1 tests/replay_score.lua port/KTH/KTH.toc $r /tmp/regress_r.json port >/dev/null
  python3 - "$r" <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/regress_r.json')); mo=d['mouseover']; pl=d['platelog']
ok = mo['missed']==0 and mo['alertedNoVerdict']==0 and pl['healerNoIcon']==0 and pl['iconNoHealer']==0 and not d['errors']
print('R4/R5', 'ok' if ok else 'FAIL', sys.argv[1].split('/')[-1], 'mo', mo, 'platelog', pl, 'errors', len(d['errors']))
sys.exit(0 if ok else 1)
PY
done
# R9 (forever.5, user decision "having mana does not make one a healer"): two enemy DPS druids on MANA with damage only
# are never marked - BG with meter rows, and with the class clear in arena / open world; a healing druid (control) is.
for z in pvp arena none; do
  KTH_ZONE=$z KTH_ENEMY_CLASS=clear lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/regress/druid_mana_dps_stream.lua /tmp/r9.json port >/dev/null
  python3 - $z <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/r9.json')); m=d['marks'] if isinstance(d['marks'],dict) else {}
ok = not m and not d['errors'] and d['mouseover']['alerted']==0
print('R9', 'ok' if ok else 'FAIL', 'zone', sys.argv[1], 'DPS druids on MANA marked:', len(m), 'alerts', d['mouseover']['alerted'], 'errors', len(d['errors']))
sys.exit(0 if ok else 1)
PY
done
lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/regress/druid_resto_stream.lua /tmp/r9c.json port >/dev/null
python3 - <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/r9c.json')); m=d['marks'] if isinstance(d['marks'],dict) else {}
ok = set(m)=={'1'} and not d['errors']
print('R9', 'ok' if ok else 'FAIL', 'control: healing druid marked:', sorted(m))
sys.exit(0 if ok else 1)
PY
# R9b (real data): on runs 16-18 no enemy druid without healing output is ever marked (run 18: Joff, Tatusera show MANA)
for r in 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg; do
  lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua /tmp/r9b.json port >/dev/null
  python3 - $r <<'PY' || fail=1
import json,sys
r=sys.argv[1]; d=json.load(open('/tmp/r9b.json')); tr=json.load(open(f'tests/replay/{r}.truth.json'))['roster']
m=d['marks'] if isinstance(d['marks'],dict) else {}
bad=[tr[int(i)-1]['first'] for i in m if (tr[int(i)-1].get('cls') or tr[int(i)-1].get('cls_log'))=='DRUID' and not tr[int(i)-1]['healer']]
dr=[x['first'] for x in tr if x['side']=='E' and (x.get('cls') or x.get('cls_log'))=='DRUID' and not x['healer']]
print('R9b', 'ok' if not bad else 'FAIL', r, 'non-healer enemy druids', dr, 'marked', bad)
sys.exit(0 if not bad else 1)
PY
done
# R10 (forever.6, real data, named cases): every enemy healer of runs 16-18 is marked on its plate with no on->off
# flip; every earlier false mark (forever.3: Joff, Tatusera) and false friendly claim (forever.3: Ganon, Romsly, Vale)
# stays unmarked/unclaimed; Torvian (ret paladin, self-heals; early-read simulation risk) stays unmarked.
for r in 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg; do
  lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua /tmp/r10.json port >/dev/null
  python3 - $r <<'PY' || fail=1
import json,sys
r=sys.argv[1]; d=json.load(open('/tmp/r10.json')); tr=json.load(open(f'tests/replay/{r}.truth.json'))['roster']
HEAL={'run16':['Bleep','Frobby','Invictusap'],'run17':['Gorrotar','Aerie','Brocky'],'run18':['Randess','Ank','Karen']}
NOMARK={'run17':[],'run16':[],'run18':['Joff','Tatusera','Torvian']}
NOCLAIM={'run17':['Ganon','Romsly','Vale'],'run16':[],'run18':['Joff','Tatusera','Torvian']}
run=[k for k in HEAL if k in r][0]
m=d['marks'] if isinstance(d['marks'],dict) else {}
fl=d['flips'] if isinstance(d['flips'],dict) else {}
recs=d['recs'] if isinstance(d['recs'],dict) else {}
idx={x['first']:i+1 for i,x in enumerate(tr)}
ok=True
# forever.7: time-to-mark ceilings (s from capture start) = forever.6's plate-mark times on the same replays: no healer
# may be marked later than forever.6 marked them
MAXT={'Bleep':749,'Frobby':530,'Invictusap':584,'Gorrotar':1106,'Aerie':359,'Brocky':459,'Randess':715,'Ank':1052,'Karen':1036}
g0=json.load(open(f'tests/replay/{r}.truth.json'))['meta']['g0']
for n in HEAL[run]:
    i=str(idx[n]); tm = (m[i]['t']-g0) if i in m else None
    good = i in m and (fl.get(i,{}).get('off',0)==0) and tm <= MAXT[n] + 0.5
    print('R10', 'ok' if good else 'FAIL', run, 'healer', n, ('marked at %.0f s (ceiling %d s)' % (tm, MAXT[n])) if i in m else 'NOT marked', 'offFlips', fl.get(i,{}).get('off',0)); ok&=good
for n in NOMARK[run]:
    i=str(idx[n]); good = i not in m
    print('R10', 'ok' if good else 'FAIL', run, 'not-healer', n, 'unmarked' if good else 'MARKED'); ok&=good
for n in NOCLAIM[run]:
    x=tr[idx[n]-1]; k=('F:' if x['side']=='F' else 'E:')
    c=[v for kk,v in recs.items() if kk in (k+x['full'],k+x['first']) and v.get('firstClaimT')]
    print('R10', 'ok' if not c else 'FAIL', run, 'never claimed', n, 'claims', len(c)); ok&=not c
sys.exit(0 if ok else 1)
PY
done
# R11 (forever.8, SYNTHETIC): the user's healer-only list. One cast of Penance (402289), Power Infusion (10060), Prayer
# of Mending (401859), Light's Vigil (1310911), Wild Growth (408120), Riptide (408521) marks that enemy within 1 s of the
# cast (cast at 110/120/.../160) in open world, arena and BG, class clear or secret. Swiftmend 18562 and Holy Shock 1311606
# (no longer instant flags), Riptide-named NPC spell 22419 and no cast -> no mark.
for z in none arena pvp; do for c in secret clear; do
  KTH_ZONE=$z KTH_ENEMY_CLASS=$c lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/regress/healonly_spell_stream.lua /tmp/r11.json port >/dev/null
  python3 - $z $c <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/r11.json')); m=d['marks'] if isinstance(d['marks'],dict) else {}
CAST={'1':(110,'Penance'),'2':(120,'Power Infusion'),'3':(130,'Prayer of Mending'),'4':(140,"Light's Vigil"),'5':(150,'Wild Growth'),'6':(160,'Riptide')}
ok = set(m)==set(CAST) and not d['errors']
for k,(t,n) in CAST.items():
    good = k in m and m[k]['t'] <= t+1
    ok &= good
    print('R11', 'ok' if good else 'FAIL', sys.argv[1], 'class', sys.argv[2], n, ('marked %+d s after the cast' % (m[k]['t']-t)) if k in m else 'NOT marked')
extra = sorted(set(m)-set(CAST))
print('R11', 'ok' if not extra else 'FAIL', sys.argv[1], 'class', sys.argv[2], 'Swiftmend / Holy Shock / Riptide-NPC 22419 / no cast: marked', extra)
sys.exit(0 if ok else 1)
PY
done; done
# R12 (forever.7, SYNTHETIC): a level-22 healer with no healer-only spell is still marked by the meter layer; absence of
# healer-only casts is never evidence against
lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/regress/lowlevel_healer_stream.lua /tmp/r12.json port >/dev/null
python3 - <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/r12.json')); m=d['marks'] if isinstance(d['marks'],dict) else {}; rec=d['recs'].get('E:Novice Mender',{})
ok = set(m)=={'1'} and rec.get('spec') is None and (rec.get('why') or '').startswith('meter') and not d['errors']
print('R12', 'ok' if ok else 'FAIL', 'low-level healer without healer-only spells marked by', rec.get('why'))
sys.exit(0 if ok else 1)
PY
# R13 (forever.7, SYNTHETIC): spec shortcut. Arena opponent spec 105 (Restoration) -> marked within 2 s; spec 71 and no
# spec -> not marked by spec; friendly group role HEALER -> claimed at once, DAMAGER role -> nothing against anyone
KTH_ZONE=arena lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/regress/spec_arena_stream.lua /tmp/r13.json port >/dev/null
python3 - <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/r13.json')); m=d['marks'] if isinstance(d['marks'],dict) else {}
ok = set(m)=={'1'} and m['1']['t'] <= 102 and not d['errors'] and all(v.get('spec')!='DPS' for v in d['recs'].values())
print('R13', 'ok' if ok else 'FAIL', 'arena spec: marked', sorted(m), 'recs', {k:v.get('spec') for k,v in d['recs'].items()})
sys.exit(0 if ok else 1)
PY
lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/regress/spec_role_stream.lua /tmp/r13b.json port >/dev/null
python3 - <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/r13b.json')); r=d['recs']
ok = (r.get('F:Mend Well') or {}).get('claim')=='HEALER' and not (r.get('F:Stab Back') or {}).get('claim') and not d['errors']
print('R13', 'ok' if ok else 'FAIL', 'group role HEALER claimed:', (r.get('F:Mend Well') or {}).get('why'))
sys.exit(0 if ok else 1)
PY
# R14 (forever.9): H.H.T.D. sprite icons on the Midnight path. K.T.H.'s ApplyIndicatorStyle must use NamePlateHooker's
# Marker_Textures["default"] + ICONS_COORDS[isFriend][class] (class not known / not on the sheet / secret -> [false]),
# with only plain numbers reaching SetTexCoord; on runs 16-18 count marks drawn with the class-less fallback.
for r in 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg; do
  lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua /tmp/r14.json port >/dev/null
  python3 - $r <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/r14.json')); I=d.get('icons') or {}
F={'NONE':(0,0),'DRUID':(1,0),'MONK':(2,0),'PALADIN':(3,0),'PRIEST':(0,1),'SHAMAN':(1,1),'EVOKER':(0,3)}
E={'NONE':(2,1),'DRUID':(3,1),'MONK':(0,2),'PALADIN':(1,2),'PRIEST':(2,2),'SHAMAN':(3,2),'EVOKER':(1,3)}
ok = len(I)==18 and not d['errors']
for k,v in I.items():
    side,c=k.split(':'); M=F if side=='F' else E; want=M.get(c,M['NONE'])
    tc=v.get('tc') or [0,0,0,0]; got=(round(tc[0]*4),round(tc[2]*4)); size=(round((tc[1]-tc[0])*4),round((tc[3]-tc[2])*4))
    good = v['ok'] and not v.get('badTc') and (v.get('path') or '').endswith('healers_icons.tga') and got==want and size==(1,1)
    ok &= good
    if not good: print('R14 FAIL', k, v)
m=d['marks']; fb=sum(1 for x in m.values() if not x.get('iconClass'))
print('R14', 'ok' if ok else 'FAIL', sys.argv[1][-9:], '18 side x class cells = NamePlateHooker ICONS_COORDS; marks', len(m), 'class icon', len(m)-fb, 'plain-cross fallback', fb, sorted(set(str(x.get('iconClass')) for x in m.values())))
sys.exit(0 if ok else 1)
PY
done
# R15 (forever.9b): /kthg GUI. All 8 icon selects (friend, enemy, 6 per-class overrides) offer hhtd + hhtdmin; set()
# through the widgets reaches MidnightNameplates' live settings: friend hhtdmin -> minimal sheet, friendly druid cell (1,0);
# enemy skull + PRIEST override hhtd -> enemy priest drawn on the HHTD sheet at (2,2), other classes keep the skull.
lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/regress/healonly_spell_stream.lua /tmp/r15.json port >/dev/null
python3 - <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/r15.json')); G=d.get('gui') or {}; R=G.get('roundtrip') or {}
chk=lambda k,tail,cell: (R.get(k,{}).get('path') or '').endswith(tail) and R.get(k,{}).get('cell')==cell
ok = (G.get('selects')==8 and not G.get('missing') and not d['errors']
      and G.get('saved')=={'friendIcon':'hhtdmin','enemyIcon':'skull','priestOverride':'hhtd'}
      and chk('friendDruid','healers_icons_minimal.tga',[1,0]) and chk('enemyPriest','healers_icons.tga',[2,2])
      and chk('enemyShaman','UI-RaidTargetingIcon_8',[0,0]) and chk('enemyNone','UI-RaidTargetingIcon_8',[0,0])
      and G.get('reset')=={'friendIcon':'hhtd','enemyIcon':'hhtd','priestOverride':False})
print('R15', 'ok' if ok else 'FAIL', 'GUI selects', G.get('selects'), 'missing hhtd', G.get('missing'), 'round-trip', {k:(v.get('path','').split(chr(92))[-1], v.get('cell')) for k,v in R.items()})
sys.exit(0 if ok else 1)
PY
# R16 (run19 fix): post-match scoreboard talentSpec on Forever is the CLASS name ("Priest"); only known spec names vote
lua5.1 tests/regress/specname_test.lua port/KTH/KTH.toc || fail=1
# R18 (forever.10): meter minimum healer count (real rows), elimination, druid form share
lua5.1 tests/regress/kmin_test.lua port/KTH/KTH.toc || fail=1
# R19 (forever.11): healer threshold setting (defaults = forever.10, GUI -> verdict code, precedence, clamp, reset) and
# the single debug switch (checkbox, /kthdebug alias, migration)
lua5.1 tests/regress/threshold_test.lua port/KTH/KTH.toc || fail=1
# R21 (forever.12): General-tab detection settings (remove-mark, meter minimum, heals needed, elimination, druid
# tie-break) reach the verdict code; remove-mark clamp; teamMax gone; Reset tab resets everything (live) + debug default
lua5.1 tests/regress/settings12_test.lua port/KTH/KTH.toc || fail=1
# R22 (forever.12): runs 16-19 with defaults and with every forever.12 setting set explicitly to its default: identical
# to forever.11 (tests/results/run*.port11.json; teamMax removal changes nothing). Toggles reach the replay: elimination
# off -> run 19 Moun never claimed; druid tie-break off -> run 19 feral 梦之旅程 claimed.
for v in "" "removeSharePct=35,meterMinHeal=1000,healsNeeded=2,elimEnabled=1,formTieEnabled=1"; do for r in 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg 2026-10-10-run19-bg; do
  run=$(echo $r | grep -o 'run[0-9]*')
  KTH_SETTINGS="$v" lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua /tmp/r22.json port >/dev/null
  python3 - "$v" $run <<'PY' || fail=1
import json,sys
v,run=sys.argv[1:3]
def sig(d):
    recs={k:(r.get('claim'),r.get('firstClaimT'),r.get('why'),r.get('offs'),r.get('heal'),r.get('dmg')) for k,r in d['recs'].items()}
    return json.dumps([d['marks'], d['flips'], recs, d.get('mouseover')],sort_keys=True)
a=json.load(open(f'tests/results/{run}.port11.json')); b=json.load(open('/tmp/r22.json'))
ok = sig(a)==sig(b) and not b['errors']
print('R22', 'ok' if ok else 'FAIL', run, 'settings', v or '(defaults)', 'detection == forever.11' if ok else 'DIFFERS')
sys.exit(0 if ok else 1)
PY
done; done
for v in elimEnabled=0 formTieEnabled=0; do
  KTH_SETTINGS="$v" lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/2026-10-10-run19-bg.lua /tmp/r22.json port >/dev/null
  python3 - "$v" <<'PY' || fail=1
import json,sys
v=sys.argv[1]; d=json.load(open('/tmp/r22.json'))
cl=lambda p: any(k.startswith('E:'+p+' ') and (x.get('claim')=='HEALER' or x.get('firstClaimT')) for k,x in d['recs'].items())
ok = (not cl('Moun')) if v=='elimEnabled=0' else cl('梦之旅程')
print('R22', 'ok' if ok else 'FAIL', 'run19', v, 'Moun claimed' if v=='elimEnabled=0' else '梦之旅程 claimed', cl('Moun') if v=='elimEnabled=0' else cl('梦之旅程'))
sys.exit(0 if ok else 1)
PY
done
# R20 (forever.11): detection identical to forever.10 (tests/results/run*.port10.json) on runs 16-19 with default
# settings, with the global threshold explicitly 60%, and with debug on and off; debug off captures nothing
for v in "" "healerSharePct=60" "debug=1" "debug=0"; do for r in 2026-10-09-run16-bg 2026-10-10-run17-bg 2026-10-10-run18-bg 2026-10-10-run19-bg; do
  run=$(echo $r | grep -o 'run[0-9]*')
  KTH_SETTINGS="$v" lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/$r.lua /tmp/r20.json port >/dev/null
  python3 - "$v" $run <<'PY' || fail=1
import json,sys
v,run=sys.argv[1:3]
def sig(d):
    recs={k:(r.get('claim'),r.get('firstClaimT'),r.get('why'),r.get('offs'),r.get('heal'),r.get('dmg')) for k,r in d['recs'].items()}
    return [d['marks'], d['flips'], recs, d.get('mouseover')]
a=json.load(open(f'tests/results/{run}.port10.json')); b=json.load(open('/tmp/r20.json'))
same = json.dumps(sig(a),sort_keys=True)==json.dumps(sig(b),sort_keys=True) and not b['errors']
cap=b.get('debugCapture') or {}
capok = (cap.get('meterReads',0)==0 and cap.get('plateLogRows',0)==0) if v=='debug=0' else cap.get('meterReads',0)>0
ok = same and capok
print('R20', 'ok' if ok else 'FAIL', run, 'settings', v or '(defaults)', 'detection == forever.10' if same else 'DIFFERS', 'debug capture', cap)
sys.exit(0 if ok else 1)
PY
done; done
# R17 (run19). NO LONGER HELD OUT: forever.10 used run 19 (user decisions 2026-10-10: truth v2, druid form tie-break,
# meter minimum count + elimination). Hard: every truth-v2 enemy healer (Danukeru, 汇源, Moun) claimed, and plate-marked
# whenever its plate was up after the claim (Moun's plate is last up at t+91, his first proof is the t+488 meter read);
# 0 false marks / claims on either side (梦之旅程, Aurelís, Suikoden explicitly); every friendly truth healer claimed;
# 0 on->off flips.
lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/2026-10-10-run19-bg.lua /tmp/r17.json port >/dev/null
python3 - <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/r17.json')); ro=json.load(open('tests/replay/2026-10-10-run19-bg.truth.json'))['roster']
t0=d['t0']; m={int(k) for k in d['marks']}
offs=sum(v.get('off',0) for v in d['flips'].values())
def rec(r):
    for k,x in d['recs'].items():
        if k.startswith(('E:' if r['side']=='E' else 'F:')+r['first']+' ') or k==('E:' if r['side']=='E' else 'F:')+r['first']: return x
    return {}
bad=[]
for i,r in enumerate(ro,1):
    x=rec(r); cl=x.get('claim')=='HEALER' or bool(x.get('firstClaimT'))
    if r['healer']:
        if not cl: bad.append('unclaimed '+r['first'])
        if r['side']=='E' and str(i) in d['lastSeen'] and cl and d['lastSeen'][str(i)]-t0 >= x['firstClaimT']-1000 and i not in m: bad.append('plate unmarked '+r['first'])
    else:
        if cl: bad.append('false claim '+r['first'])
        if i in m: bad.append('false mark '+r['first'])
for n in ('梦之旅程','Aurelís','Suikoden'):
    if not any(r['first']==n for r in ro): bad.append('missing roster '+n)
if offs: bad.append('on->off flips %d'%offs)
if d['errors']: bad.append('errors')
ok=not bad
print('R17', 'ok' if ok else 'FAIL', 'run19 (training run since forever.10): marked', sorted(ro[i-1]['first'] for i in m), 'claims E/F all truth healers, 0 false' if ok else bad)
sys.exit(0 if ok else 1)
PY
# R7 (F7): non-BG zones. Same real event stream (run18) replayed as arena / open world / party, enemy UnitClass
# secret (as measured in BGs) and clear (world/arena readability not captured yet): no Lua error anywhere, no
# scoreboard join outside BGs, no class-based mark even when the class is clear (forever.5: healing-output verdict
# only), evidence engine off in party when K.T.H.'s Pve option is off.
for z in arena none party; do for c in secret clear; do
  KTH_ZONE=$z KTH_ENEMY_CLASS=$c lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/2026-10-10-run18-bg.lua /tmp/r7.json port >/dev/null
  python3 - $z $c <<'PY' || fail=1
import json,sys
z,c=sys.argv[1:3]; d=json.load(open('/tmp/r7.json')); m=d['marks'] if isinstance(d['marks'],dict) else {}
meth={x['method'] for x in m.values()}
ok = not d['errors'] and d['rosterSize']==0 and meth<={'HEAL'} and d['mouseover']['missed']==0
print('R7', 'ok' if ok else 'FAIL', z, 'enemyClass='+c, 'marks', len(m), sorted(meth), 'roster', d['rosterSize'], 'errors', len(d['errors']), 'mo', d['mouseover'])
sys.exit(0 if ok else 1)
PY
done; done
KTH_ZONE=party KTH_PVE=off lua5.1 tests/replay_score.lua port/KTH/KTH.toc tests/replay/2026-10-10-run18-bg.lua /tmp/r7.json port >/dev/null
python3 - <<'PY' || fail=1
import json,sys
d=json.load(open('/tmp/r7.json')); n=len(d['recs']) if isinstance(d['recs'],dict) else 0
print('R7', 'ok' if n==0 and not d['errors'] else 'FAIL', 'party with Pve off: evidence records', n)
sys.exit(0 if n==0 and not d['errors'] else 1)
PY
# R8 (forever.4): replay provenance: no placeholder or SV-unbacked name in any replay; synthetic fixtures labelled
python3 tests/replay_provenance_test.py || fail=1
# R6 (F1 static): every global function the addon calls exists on Forever or is guarded
python3 tests/api_scan_test.py || fail=1
exit $fail
