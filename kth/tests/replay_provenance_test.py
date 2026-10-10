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
"""forever.4 R8: replay provenance. Fails if any real replay carries a placeholder or unbacked name.
- every roster full name in tests/replay/*.truth.json and the matching .lua must be the name tools/realnames.py
  recovers for that player's GUID from the run's own ForeverDump SV (client reads in that match), or be absent;
- a roster is all-real or all-absent (no partial boards);
- the exporter placeholder pattern (the same surname "Synth" on 2+ rows) never appears;
- synthetic unit fixtures live only in tests/regress/ and must say so (meta.synthetic = true)."""
import glob, json, re, sys, os, collections
sys.path.insert(0, _WROOT + '/kth/tools')
import realnames
fail = []
for tf in sorted(glob.glob(_WROOT + '/kth/tests/replay/*.truth.json')):
    run = os.path.basename(tf)[:-len('.truth.json')]
    tr = json.load(open(tf)); ro = tr['roster']
    lua = open(tf[:-len('.truth.json')] + '.lua', encoding='utf-8').read()
    lfull = re.findall(r'\{ first = "([^"]*)", full = (nil|"[^"]*"),', lua)
    if [a for a, _ in lfull] != [r['first'] for r in ro]: fail.append(f'{run}: .lua roster order differs from truth')
    sur = collections.Counter((r.get('full') or '').split(' ', 1)[1] for r in ro if r.get('full') and ' ' in r['full'])
    if sur and sur.most_common(1)[0][1] >= 2: fail.append(f'{run}: surname {sur.most_common(1)[0][0]!r} on {sur.most_common(1)[0][1]} rows (placeholder pattern)')
    have = [bool(r.get('full')) for r in ro]
    if any(have) and not all(have): fail.append(f'{run}: partial board ({sum(have)}/{len(have)})')
    if any(have):
        got, _ = realnames.resolve(run, ro)
        bad = [(r['first'], r['full'], got[r['guid']][0]) for r in ro if got[r['guid']][0] != r['full']]
        lbad = [(a, b) for (a, b), r in zip(lfull, ro) if b.strip('"') != r['full']]
        if bad: fail.append(f'{run}: names not backed by the SV: {bad[:5]}')
        if lbad: fail.append(f'{run}: .lua full names differ from truth: {lbad[:5]}')
        print(f'R8 {run}: real board, {len(ro)}/{len(ro)} names backed by the SV' if not bad else f'R8 {run}: FAIL')
    else:
        if any(b != 'nil' for _, b in lfull): fail.append(f'{run}: board-less truth but .lua has names')
        print(f'R8 {run}: board-less (no full names, no classes)')
# forever.5: meter snapshots (tests/replay/<run>.dm.lua) must be byte-identical to a fresh export from the run's SV
import subprocess, tempfile, shutil
for f in sorted(glob.glob(_WROOT + '/kth/tests/replay/*.dm.lua')):
    run = os.path.basename(f)[:-len('.dm.lua')]
    if not os.path.exists(f'{_WROOT}/foreverdump/real/{run}/sv/ForeverDump.lua'):
        print(f'R8 {run}: meter file present, raw SV not on this machine - provenance not re-checked'); continue
    tf = f'{_WROOT}/kth/tests/replay/{run}.truth.json'
    if not os.path.exists(tf) or not all(r.get('full') for r in json.load(open(tf))['roster']):
        fail.append(f'{run}: meter file for a board-less run (names would be used)')
    tmp = tempfile.mkdtemp(); bak = f + '.r8'
    shutil.copy(f, bak)
    try:
        subprocess.run([sys.executable, _WROOT + '/kth/tools/export_dm.py', run], capture_output=True, check=True)
        same = open(f, 'rb').read() == open(bak, 'rb').read()
    finally:
        shutil.move(bak, f)
    if not same: fail.append(f'{run}: meter file differs from a fresh export of the SV')
    print(f'R8 {run}: meter snapshots ' + ('identical to a fresh SV export' if same else 'DIFFER'))
for f in glob.glob(_WROOT + '/kth/tests/regress/*.lua'):
    s = open(f, encoding='utf-8').read()
    if ('roster' in s or 'snaps' in s) and 'synthetic = true' not in s: fail.append(f'{f}: fixture not labelled synthetic')
for f in glob.glob(_WROOT + '/kth/tests/replay/*.lua'):
    if 'synthetic = true' in open(f, encoding='utf-8').read(): fail.append(f'{f}: synthetic fixture inside tests/replay')
print('R8', 'ok' if not fail else 'FAIL', *fail, sep='\n  ' if fail else ' ')
sys.exit(1 if fail else 0)
