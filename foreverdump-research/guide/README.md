# SECRETS-GUIDE generator

`build_guide.py` writes `SECRETS-GUIDE.html`, a static, self-contained (inline CSS/SVG, ~30 lines of optional inline JS for the
function filter) guide to WoW Forever / 12.x secret values. Python 3 standard library only.

```
python3 build_guide.py                                   # defaults below
python3 build_guide.py --lab lab.json --combat combat.json --hsm hsm.json --out SECRETS-GUIDE.html
```

| Option | Default | Used for |
|---|---|---|
| `--inventory` | `../api-secrecy-inventory-forever-70245.tsv` | Tags for every API in the guide; the impacted-functions section; predicate table |
| `--research` | `../secrets-research.md` | Linked as a source (date shown in "Inputs") |
| `--verify` | `/workspace/foreverdump/real/2026-10-07-run2/out/verify/verify.json` if present | "obs:" marks in Combat secrets, the Observed section, Observed column of the function table |
| `--lab` | none | Ops-matrix "Lab" column and a lab results table (JSON), or verbatim markdown (`.md`) |
| `--combat` | none | Extra observations for Combat secrets cells and Detecting-state cells |
| `--hsm` | none | HSM "Verified vs pending" table |
| `--out` | `./SECRETS-GUIDE.html` | Output |

Curated text lives in `guide_data.py`: trusted HTML with confidence markup `[[v:SRC]]` verified, `[[o:SRC]]` official,
`[[d:SRC]]` docs, `[[c:SRC]]` community, `[[p:]]` pending lab, `[[i:]]` inference (several ids: `[[o:A,B]]`, note: `[[p:|text]]`).
Unknown source ids print a warning. Everything read from input files is HTML-escaped.

Context names used everywhere: `ooc` (no restriction), `combat` (Combat restriction active), `restricted`
(Encounter / ChallengeMode / PvPMatch / Map active). Inputs may also say `enc`, `encounter`, `pvp`, `mplus`: anything that is
not `ooc`/`combat` is folded into `restricted`.

Unit classes: `player`, `target_hostile_npc`, `friendly_npc`, `other_player`, `party_raid`, `nameplate`, plus `any` for
unit-less items (damage meter) and all `det.*` rows.

Cell codes: `C` clear, `S` secret, `E` Lua error / refused, `X` container (duration object etc.; report `S` if
`HasSecretValues()` was true), `N` nil / nothing returned, `P` pending. A trailing `?` marks a weak observation.
Never put secret values themselves (or anything derived from them) in these files: codes and counts only.

## `--combat` JSON (schema `foreverdump.combat/1`)

```json
{
  "schema": "foreverdump.combat/1",
  "build": "1.60.1.70245",
  "captured": "2026-10-08T20:15:00-04:00",
  "source": "ForeverDump v2.2 CombatProbe, Deadmines",
  "items": {
    "health.max":    { "nameplate": { "restricted": { "code": "S", "n": 14, "api": "UnitHealthMax", "note": "boss1 + trash" } } },
    "cast.info":     { "target_hostile_npc": { "combat": { "code": "S", "n": 6 } } },
    "det.cast.other":{ "any": { "combat": { "code": "C", "n": 9, "note": "UNIT_SPELLCAST_START arrival" } } }
  },
  "observations": [
    { "item": "raidMarker", "unit": "party_raid", "context": "combat", "code": "S", "n": 3, "api": "GetRaidTargetIndex" }
  ]
}
```

* `items[itemId][unitClass][context] = {code, n?, api?, note?}`; or the flat `observations` list (same fields plus
  `item`, `unit`, `context`). Both may be used; later entries win.
* Item ids are the `id`s in `guide_data.COMBAT_ITEMS` (`health.current`, `health.max`, `health.percent`,
  `health.absorbs`, `health.incomingHeals`, `cast.info`, `cast.timeLeft`, `channel.timeLeft`, `movement.speed`,
  `unit.name`, `aura.buffs`, `aura.debuffs`, `aura.dispel`, `threat`, `range`, `raidMarker`, `damageMeter`) and the
  `det.*` ids in `guide_data.DETECT` (`det.cast.self`, `det.cast.other`, `det.cast.otherSpell`, `det.aura.present.self`,
  `det.aura.present.other`, `det.aura.change`, `det.aura.stacks`, `det.aura.duration`, `det.aura.dispellable`,
  `det.aura.mine`, `det.combat`, `det.move`; use unit `any`). Other ids are listed in an "Other --combat observations" table.
* Cells whose documented expectation is a firm `C`/`S` and whose observations are all the opposite are drawn red.

## `--hsm` JSON (schema `foreverdump.hsm/1`)

```json
{
  "schema": "foreverdump.hsm/1",
  "build": "1.60.1.70245",
  "captured": "2026-10-08T20:15:00-04:00",
  "rules": [
    { "id": "cast-aura-window", "context": "combat", "predictions": 42, "verified": 39, "contradicted": 2,
      "pending": 1, "meanErrorSec": 0.31, "status": "verified" }
  ],
  "inputs": { "combat": { "UNIT_AURA.addedAuras": { "r": 0, "u": 57 }, "UNIT_SPELLCAST_SUCCEEDED.spellID(player)": { "r": 31, "u": 0 } } },
  "predictions": [
    { "t": 1045260.2, "unit": "player", "spell": 1459, "kind": "aura", "rule": "cast-aura-window", "conf": "high",
      "outcome": "verified", "errorSec": 0.2 }
  ]
}
```

* `rules[]`: one row per rule and context. `status` is one of `verified`, `pending`, `failing` (or `contradicted`).
  Rule ids should match the HybridState / Inference rule names; the guide's own pattern ids are `inf-own-aura`,
  `inf-cd`, `inf-cast-other`, `inf-combat-phase`, `inf-aura-count`.
* `inputs[context][signal] = {r: readable count, u: unreadable count}` (same shape as `ForeverDumpLogDB.inference.inputs`).
* `predictions[]`: optional sample, the first 40 are shown. `outcome` = `verified` | `contradicted` | `unverified`.

## `--lab` JSON

Either a list of lab runs, or an object `{ "lab": [...], "controls": [...] }`, i.e. the `lab` and `controls` arrays
of `ForeverDumpLogDB` converted to JSON as-is:

* `lab[] = { ctx, reason, items: [ { group, id, approach, available, ok, err?, absent?, ...codes } ] }` (Lab.lua).
* `controls[] = { ctx, ops: { "UnitHealth(player)": { arith: {ok, err?}, tostring: {ok, resultSecret, tonumberNil}, ... } } }`
  (Controls.lua `OpsMatrix`). The ops matrix rows in the guide look up `(subject, op, field)` here and turn red when
  the observation contradicts the documented result.

A `.md` file is embedded verbatim (escaped) in the Observed section instead.

## Checks

* `html5lib` parse (venv in `.venv/`): `.venv/bin/python -c "import html5lib; p=html5lib.HTMLParser(); p.parse(open('SECRETS-GUIDE.html','rb').read()); print(p.errors)"`
* Screenshots: `google-chrome --headless=new --no-sandbox --window-size=1400,2400 --screenshot=shots/top.png file://$PWD/SECRETS-GUIDE.html`

## Samples

`samples/*.sample.json` are made-up fixtures that exercise every input path (incl. one contradiction each and an unknown item id). They are not real data; never ship a guide built from them.
