K.T.H. (Kill The Healer)
========================

*In World of Warcraft, healers have to die. This add-on helps you identify and
mark healers on both sides so your team can focus targets effectively in PvP.*

**K.T.H. is a modernized fork of H.H.T.D. (Healers Have To Die) by John Wellesz,
rebuilt for WoW 12.0 (Midnight).**

WoW 12.0 introduced "secret values" in instanced PvP: enemy player names and
GUIDs are no longer accessible to add-ons. K.T.H. works around this by using
Class + PowerType + DPS-power-exclusion matching on nameplates, cross-referenced
against scoreboard data.


**Current features:**

- Automatically places healer indicators above player nameplates in PvP
  battlegrounds and arenas. Friendly healers are identified by name via the
  scoreboard; enemy healers are identified by class, power type, and
  DPS-power-exclusion (so Ret Paladins, Shadow Priests, etc. are filtered out).

- Separate indicator icons and colors for friendly vs enemy healers. Both are
  fully customizable through the in-game settings panel or slash commands.

- Multiple icon presets: cross, skull, star, circle, diamond, triangle, moon,
  and square (all standard raid-target icons with custom vertex coloring).

- Adjustable Y-offset and indicator size so you can position the marker exactly
  where you want it relative to the nameplate.

- Inherits H.H.T.D.'s announcer module for posting healer lists to raid chat,
  sound alerts on healer mouse-over/targeting, and friendly-healer-under-attack
  warnings.

- Custom marks module: apply persistent personal markers to any unit's
  nameplate (visible only to you, persists across sessions).

- Integrates with the DebugLog add-on for diagnostic output. Toggle diagnostics
  with `/kthdebug` or run a one-shot dump with `/kthdiag`. All diagnostic data
  is routed to DebugLog's scrollable viewer instead of cluttering your chat.

**IMPORTANT: You must enable nameplates or you will not see any healer indicators!**


How it works (Midnight / WoW 12.0)
-----------------------------------

In WoW 12.0 instanced PvP, `UnitName()` and `UnitGUID()` return secret values
for enemy players. K.T.H. uses a multi-strategy approach:

1. **Scoreboard scan**: `C_PvP.GetScoreInfo()` provides each player's name,
   class, and talent spec. K.T.H. identifies which players are healers and
   tracks them by name (for friendlies) and by class (for enemies).

2. **Nameplate matching (friendly)**: Friendly names are still accessible, so
   K.T.H. matches friendly nameplates directly against the scoreboard.

3. **Nameplate matching (enemy)**: `UnitClass()` and `UnitPowerType()` remain
   accessible on enemy nameplates even when names are secret. K.T.H. checks:
   - Is the class healer-capable? (Priest, Paladin, Druid, Shaman, Monk, Evoker)
   - Does the scoreboard confirm an enemy healer of that class?
   - Is the unit's primary power type Mana?
   - Does the unit lack DPS-exclusive power resources? (e.g. Holy Power for
     Ret/Prot Paladin, Insanity for Shadow Priest, Astral Power for Balance
     Druid, Maelstrom for Ele/Enh Shaman, Energy for Windwalker/Brewmaster Monk)

   Only if all four conditions are met is the unit marked as a healer.


Commands
--------

- `/kth` -- Show current K.T.H. nameplate indicator settings
- `/kth help` -- Full command reference
- `/kth offset <number>` -- Set Y-offset above nameplate
- `/kth size <number>` -- Set indicator size (8-128 pixels)
- `/kth icon friend|enemy <preset>` -- Choose icon for friendly or enemy healers
- `/kth icons` -- List available icon presets
- `/kth glow on|off` -- Toggle glow halo behind indicators
- `/kth reset` -- Restore all settings to defaults
- `/kthdebug` -- Toggle diagnostic output (routed to DebugLog)
- `/kthdiag` -- One-shot diagnostic dump
- `/hhtdp` -- Announce healers to raid chat (requires message configuration)
- `/hhtdg` -- Open the legacy H.H.T.D. options panel

The K.T.H. settings panel is also available in the WoW Interface > AddOns menu.


Credits
-------

K.T.H. is built on the H.H.T.D. framework by John Wellesz
(2072productions.com). The original add-on provided healer detection via combat
log events, nameplate hooking, and the announcer/custom-marks modules. K.T.H.
adapts this for WoW 12.0's secret-value system with a new nameplate indicator
engine and scoreboard-based healer identification.

- **Original author**: John Wellesz (hhtd@2072productions.com)
- **Midnight adaptation**: Scone (sconed42@gmail.com)
- **Original project**: https://www.wowace.com/projects/h-h-t-d
