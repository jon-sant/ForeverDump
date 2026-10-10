"""forever.6 forensics: per enemy class group (runs 16-18), the forever.6 class-meter verdict at every readable
snapshot (all = all healers, none, possible, -), with the raw heal/damage rows. Real data only (dm/*.dm.jsonl)."""
import json, statistics
RUNS = ['2026-10-09-run16-bg', '2026-10-10-run17-bg', '2026-10-10-run18-bg']
DMMIN, SHARE, GRP, OFFMIN = 1000, 60, 63, 2000
def verdict(h, d, n):
    sd = sum(d); sh = sum(h); dmin = min(d) if len(d) >= n else 0
    possible = any(x >= DMMIN and x * 100 >= SHARE * (x + dmin) for x in h)
    if len(h) >= n and sh >= DMMIN * n and sh * 100 >= GRP * (sh + sd): return 'ALL', possible
    if len(d) >= n and not possible and dmin >= OFFMIN: return 'NONE', possible
    return ('possible' if possible else '-'), possible
def main():
  for run in RUNS:
      tr = json.load(open(f'tests/replay/{run}.truth.json')); ro = tr['roster']; e0 = tr['meta']['e0']; g0 = tr['meta']['g0']
      cls = lambda r: r.get('cls') or r.get('cls_log')
      groups = {}
      for r in ro:
          if r['side'] == 'E': groups.setdefault(cls(r), []).append(r)
      for c, P in sorted(groups.items()):
          if c not in ('PRIEST', 'PALADIN', 'DRUID', 'SHAMAN') or len(P) < 2: continue
          print(f"\n{run[11:16]} {c} n={len(P)}: " + ', '.join(f"{r['first']}({r['share']:.2f}{' H' if r['healer'] else ''})" for r in P))
          for l in open(f'dm/{run}.dm.jsonl'):
              s = json.loads(l)
              H = s['byType'].get('HealingDone', {}).get('combatSources') or []; D = s['byType'].get('DamageDone', {}).get('combatSources') or []
              eh = sorted([x['totalAmount'] for x in H if x.get('name') == '<secret>' and x.get('sourceDisplayType') != 1 and x.get('classFilename') == c and isinstance(x.get('totalAmount'), (int, float))], reverse=True)
              ed = sorted([x['totalAmount'] for x in D if x.get('name') == '<secret>' and x.get('sourceDisplayType') != 1 and x.get('classFilename') == c and isinstance(x.get('totalAmount'), (int, float))], reverse=True)
              if not eh and not ed: continue
              v, _ = verdict(eh, ed, len(P)); sh = sum(eh); sd = sum(ed)
              print(f"  t={s['time']-e0:6.0f}s heal {eh} dmg {ed} share {sh/(sh+sd) if sh+sd else 0:.2f} -> {v}")

if __name__ == '__main__': main()
