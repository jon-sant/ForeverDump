# idTip for WoW Forever: changes

Based on silverwind's idTip **12.1.3** (GitHub tag `12.1.3`, released 2026-09-16; repo HEAD `4df162c` has
the same `idTip.lua` and `idTip.toc`). Source: https://github.com/silverwind/idTip. BSD license kept in `LICENSE`.

## Target
WoW Forever is Blizzard's official WoW: Forever beta. Build line 1.60.1 (69893 to 70009), Battle.net
product `wow_classic_beta`, TOC interface **16001**. The client runs the modern Mainline (retail 12.x) API, *not*
the Classic Era or 3.3.5a API. `TooltipDataProcessor`, `C_TooltipInfo`, `C_Item`, `C_Spell`, `C_UnitAuras` and
Midnight's secret values are all present. The old globals `GetItemInfo`, `GetSpellInfo` and `UnitAura` are gone.

## What changed
1. **Base version: 12.1.3 instead of the CurseForge download.** CurseForge's newest file is 12.0.19
   (2026-08-12). Its TOC does not list 16001 (so Forever marks it out of date). A scan against the Forever API
   dump also finds calls to `GetMouseFocus` and `GetSpellBookItemInfo` that are not checked first; neither
   exists on Forever. 12.1.3 lists 16001 and checks every API before using it (the same scan finds 0 problems).
2. **`idTip.lua`: a secret id is dropped at the top of `add()`.** Forever inherits Midnight's secret values
   (aura data can be secret in combat). Upstream already skipped writing a secret id, but it still passed that id
   on to `C_Item.GetItemIconByID` / `C_Item.GetItemSpell`. Blizzard documents both as
   `SecretArguments = "AllowedWhenUntainted"`, so a call from addon code with a secret id could throw. This is a
   precaution: nobody has hit the error in-game yet. Four lines changed.
3. **`idTip.toc`:** Version is now `12.1.3-wowforever1` and the Notes credit the original. The Interface line is
   unchanged and already includes 16001. Author is still silverwind.
4. **Tests (dev only, not in the zip):** added an upstream-style test so that a secret item id never reaches the
   C_Item lookups. It fails without change 2. All 67 tests pass.

## What did NOT need changing (and why)
- There is no `GetBuildInfo()`/`WOW_PROJECT_ID` version gate. That matters because Forever reports interface 16001
  but `WOW_PROJECT_ID == 1` (Mainline), and that combination breaks many retail ports.
- Feature detection (`GameTooltip.ProcessInfo` present) picks the retail `TooltipDataProcessor` path, which is
  correct on Forever's Mainline client.
- I checked against the API dump from a live Forever client (forever-addon-kit, build 1.60.1.69893, interface 16001):
  0 missing global functions, 0 missing `C_*` functions, 0 missing frames.

Not tested in-game.
