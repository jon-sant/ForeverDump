# Reference sources (Blizzard UI source, API docs, client data) - origin and location

All trees are included in the repo as plain files (their `.git` folders were replaced by `_git-bundles/`). To re-fetch
the exact upstream commits: `handoff-tools/fetch_reference.sh`. For a newer client build: `foreverdump/tools/refresh/refresh_all.sh`.

| in repo | what | origin | branch / commit | client build |
|---|---|---|---|---|
| `foreverdump/ref/wusf/` | Blizzard UI source (FrameXML, AddOns incl. `Blizzard_APIDocumentationGenerated`) for **Forever**; the mock client (`tests/wowenv.lua`) reads the API docs from here (`FORE_DOCS`) | https://github.com/Gethe/wow-ui-source | `forever` @ 15666a6e67938a1ab5caf041406464251db111ca (2026-10-06) | 1.60.1.70245 |
| `foreverdump/ref/wus/` | Blizzard UI source, retail **live** (comparison) | https://github.com/Gethe/wow-ui-source | `live` @ 09b9db7948abc9b9648dedaab51eb0cf3ee67b31 (2026-09-22) | 12.1.0.69933 |
| `foreverdump/ref/Blizzard_APIDocumentation*`, `Blizzard_DebugTools`, `blizzard_addons*.txt` | API doc addons copied out of the Forever tree + addon lists | same as wusf | | 70245 |
| `foreverdump/data/community/wow-ui-source/` | same Forever UI source (refresh output) | Gethe/wow-ui-source | `forever` @ 15666a6e | 70245 |
| `foreverdump/data/community/BlizzardInterfaceResources/` | KethoDoc in-game API dump, GlobalStrings, AtlasInfo, CVars | https://github.com/Ketho/BlizzardInterfaceResources | `forever` @ ec7e5ff11a3400cd67483f68ae59aadc0afe6a14 (2026-10-06) | 1.60.1 (70205) |
| `foreverdump/data/community/db2csv-wago/wow_classic_beta/` | DB2 tables as CSV (SpellName, Spell, SpellMisc, ChrClasses, Map, ...) | https://wago.tools/db2/<table>/csv?branch=wow_classic_beta | version.txt | 1.60.1.70245 |
| `foreverdump/data/ui-source/wow_classic_beta/` | UI source extracted **directly from Blizzard's CDN** (`extract_ui_cdn.sh`, TACTSharp) - local git repo, 1 commit "1.60.1.70245", history in `_git-bundles/` | Blizzard CDN, product `wow_classic_beta` | | 1.60.1.70245 |
| `foreverdump/data/db2/wow_classic_beta/DBFilesClient/` | DB2 extracted from the CDN (`extract_db2_cdn.sh`, DBC2CSV + WoWDBDefs) | Blizzard CDN | | 1.60.1.70245 |
| `foreverdump/fixtures/forever-70245/` | the user's raw in-game API/env dump (ForeverDump capture) | own capture | | 70245 |
| `foreverdump/.cache/wus-forever`, `.cache/wus-live` | test-time caches of the same Gethe trees | Gethe/wow-ui-source | forever 15666a6e / live 09b9db79 | |
| `foreverdump/.cache/idtip-src` | idTip upstream | https://github.com/silverwind/idTip | master @ 4df162c8 | |
| `foreverdump/.cache/sil-v19`, `sil.tgz` | SimpleItemLevel addon snapshot (a third-party addon used as a migration/check sample; not referenced by the runner) | | | |
| `foreverdump/.cache/wowlua/lua-5.1.5.tar.gz` | official Lua 5.1.5 source (sha256 2640fc56...5333) for the WoW-like test interpreter | https://www.lua.org/ftp/lua-5.1.5.tar.gz | | |
| `foreverdump-research/src/gethe-forever`, `tmp-forever` | Forever UI source snapshots used for the 70245 secrecy inventory | Gethe/wow-ui-source | forever @ 15666a6e | 70245 |
| `foreverdump-research/src/tmp-live`, `tmp-ptr`, `live` | retail live / ptr UI source for comparison | Gethe/wow-ui-source | live @ 09b9db79, ptr @ a89e9d0c | |
| `foreverdump-research/src/ketho-forever` | Ketho resources | Ketho/BlizzardInterfaceResources | forever @ ec7e5ff1 | |
| `foreverdump-research/src/forever-addon-kit`, `idtip-wowforever/kit` | community Forever addon kit | https://github.com/Thunderz96/forever-addon-kit | main @ 8dc29768 | |
| `foreverdump-research/src/wiki`, `blueposts.txt`, `devguide_12a.md` | Warcraft wiki pages / Blizzard blue posts / 12.0 addon dev guide notes about secret values | web (fetched 2026-10-07) | | |
| `foreverdump-research/api-secrecy-inventory-forever-70245.tsv` | 7,767 rows: every function/event/predicate in the Forever 70245 docs with its secrecy flags | generated from wusf docs | | 70245 |
| `foreverdump/tools/refresh/.cache/` (optional zip part) | CDN tooling + work cache: TACTSharp @ de24db87, DBC2CSV @ 1e4aaa46, WoWDBDefs @ e3df3707, community listfile.csv, CASC data | github.com/wowdev, Marlamin | | 70245 |

Current client is **70338** (runs 19-22). The reference trees above are 70245; the addon caches per-build reference
data in-game (`/fdump static run`, automatic spellCache, `knowledge[build]`). Refresh the trees when Gethe's `forever`
branch or wago.tools publishes a newer build (`tools/refresh/check_build.py` reports the latest).
