# Hardcoded ID lists (audit for v2.2.27, 2026-10-10)

Grep: table literals with >= 5 ID-like numbers in `ForeverDump/**/*.lua` and `tools/**/*.py`.

## Converted in v2.2.27
| where | what | now |
|---|---|---|
| AuraPresence.lua `AP.SPELLS` | 43 curated aura IDs | removed; learned OOC / own-cast pairs / spellbook cache |
| Data/AuraSeed.lua (+ tools/fdump/auraseed.py) | 96 mined aura IDs + cast->aura map | removed |
| Core.lua `combatProbe.dispelSpells` | 10 dispel IDs (all classes) | spellbook cache (description: dispel/remove/purge/cleanse/cure); config override kept |

## Remaining (proposals, not converted: larger change or not a collection list)
| where | size | used for | proposal |
|---|---|---|---|
| Data/RefData.lua `spells` / `summons` / `classLevelHP` | 725 / 30 / 165 | Derive class evidence (inference, not collection) | replace by per-build learned class evidence (spell -> class from own + party casts OOC) and ship empty |
| Data/learned-seed.lua | 453 spells, 27 npcs | Learned.lua priors | let Learned start empty per build; keep the generator offline for comparison only |
| Data/spell-timing.lua | 426 spells | Timing.lua GCD/cast priors | observed per build (Timing already learns; seed only speeds up) |
| Data/SelfLinkSeed.lua | 35 spells | Inference self-link | learn from own clear casts (same pattern as auraPairs) |
| Data/KnowledgePatch.lua | 8 spells | Inference patch for build 70245 | build-gated already; drop when 70245 support ends |
| Core.lua `probe.items` / `probe.spells` / `quests` | 6 / 8 / 3 | API probe arguments; spells only a fallback when the spellbook is empty | items: bag scan; quests: quest log; spells: keep as fallback |
| Derive.lua `DV.PREP_AURAS` | 2 | BG phase "prep" by Preparation aura presence (GetPlayerAuraBySpellID) | phase already falls back to GetBattlefieldInstanceRunTime < 120 s; learn the prep aura ID from the first clear prep read |
| tools/fdump/timing.py `TOTEMS` / `LIGHTNING_SHIELD` | 22 / 3 | offline known-answer check (user-stated GCDs) | tie to spellbook cache names ("Totem") when a cache is in the dump |

Non-ID numeric tables (ringCaps, defaults, LP.BINS, UnitCache.TTL, derivation.py measurements, guide_data dates) are
configuration / measurements, not ID lists.

## Generated data (v2.2.28, not hand-maintained)
`ForeverDump/Data/LearnedAuras.lua` is regenerated from the stored combat logs by `python3 tools/fdump.py learned-auras`
(deterministic; tests/test_learnedauras.py fails when stale). It is learned data, not a curated list: no entry is
written by hand, and it is optional (`auraPresence.offline = false` or delete the file). It is a growing library
(schema 2): every new stored run adds entries and confirms builds; an entry not confirmed on the running client build
is provisional (`offline-prov`, lower priority). Ranks are grouped by name in the addon; since v2.2.29 every rank is checked (tiers decide how often, nothing is dropped).
