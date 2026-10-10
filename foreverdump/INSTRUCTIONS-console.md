# ForeverDump companion: collecting what an addon can't

This guide covers the WoW Forever beta (client **1.60.1**, TOC `## Interface: 16001`, Battle.net product `wow_classic_beta`). Forever runs the **modern (Mainline) API**. The wiki's TOC page says Forever "includes all Modern changes up to 12.1.5".

ForeverDump v2 already collects in-game API, docs, globals, widgets, templates, CVars, fixtures and event recordings (step 3). Everything else here comes from the console, the game folder, or the web.

Notation:
- **Verified** means checked against warcraft.wiki.gg, Blizzard forums, or Forever's own UI source and data (Gethe `forever` branch, Ketho `forever` branch). Source links are in the last section.
- **UNVERIFIED** means it couldn't be confirmed for Forever. Treat those lines as best guesses and check them on your machine.

Time needed: about 30–45 minutes, mostly waiting on exports and zips.

---

## 0. Before you start (2 minutes)

1. **Confirm your build.** In chat, type `/dump select(4, GetBuildInfo())`. It should print `16001`. `/dump GetBuildInfo()` prints all four values (version, build, date, interface). Write the build number down, for example `70245`.
   - If `/dump` (or `/run`) does **nothing at all**, Forever's beta flag is blocking user scripts. In Forever's `SlashCommands.lua`, `/dump`, `/run` and `/tinspect` return early when `C_AddOns.GetScriptsDisallowedForBeta()` is true. ForeverDump itself is unaffected, because addon code doesn't go through that check. You can skip every `/run` line below.
   - The first time you use `/run` or `/dump`, the game may show a "dangerous scripts" warning popup. Accept it. That gate is `AreDangerousScriptsAllowed()`, verified in the source.
2. **Don't use "Exit Now" or Alt+F4** when this guide says to log out. Use **Game Menu → Log Out**, or `/reload`. SavedVariables and `config-cache.wtf` are only written on a clean reload or logout. The forever-addon-kit reports that "Exit Now" skips writing the account-level `config-cache.wtf`.
3. **Make sure you're on build 70009 or later.** Earlier Forever builds had a confirmed bug where SavedVariables were written but never loaded back. Blizzard forum thread and forever-addon-kit both report it fixed in 1.60.1.70009.

---

## 1. Find the Forever game folder

**Verified:** Forever installs as product `wow_classic_beta` in the folder **`_classic_beta_`**. The executable is **`WowB.exe`** on Windows and **`World of Warcraft Beta.app`** on macOS. Sources: wago.tools lists "Classic Beta | wow_classic_beta | _classic_beta_ | 1.60.1.70245", the Blizzard EU forum bug report header reads "1.60.1.69913 / Build 16001 - `_classic_beta_`", and forever-addon-kit and mmonster.co agree.

Note: the launch-day (Nov 4) folder name hasn't been announced, so this may change.

| What | Windows (default install) | macOS (default install) |
|---|---|---|
| Product root | `C:\Program Files (x86)\World of Warcraft\_classic_beta_\` | `/Applications/World of Warcraft/_classic_beta_/` |
| AddOns | `...\_classic_beta_\Interface\AddOns\` | `.../_classic_beta_/Interface/AddOns/` |
| Settings and SavedVariables | `...\_classic_beta_\WTF\` | `.../_classic_beta_/WTF/` |
| Logs | `...\_classic_beta_\Logs\` | `.../_classic_beta_/Logs/` |
| Server data cache | `...\_classic_beta_\Cache\` | `.../_classic_beta_/Cache/` |
| Crash reports | `...\_classic_beta_\Errors\` | `.../_classic_beta_/Errors/` |
| Interface export (step 2) | `...\_classic_beta_\BlizzardInterfaceCode\` and `...\BlizzardInterfaceArt\` | same, under `_classic_beta_/` |

- Since patch 8.1, each product folder holds its own `Interface`, `WTF`, `Logs`, `Cache`, `Errors` and `Screenshots`; only `Data` is shared (Blizzard forum PSA). The beta is no exception.
- If you installed the game somewhere else, open the Battle.net app, pick the **WoW Forever / Classic Beta** game version, then go to **⚙ → Show in Explorer** (Windows) or **Show in Finder** (macOS) to jump to the right folder.
- `Cache\WDB\<locale>\` (for example `Cache\WDB\enUS\questcache.wdb`) holds server-sent records. forever-addon-kit reads `questcache.wdb` from it. **UNVERIFIED:** the exact `WDB\<locale>` subpath on Forever, so check what's on disk.

---

## 2. Export Blizzard's interface code and art (console, glue screen only)

**Verified (warcraft.wiki.gg):** this command only works in the **real console (~)** on the **login or character-select screen**. If you type it while logged into a character, or through `/console`, you'll get "Unknown Command".

1. If you're in the world, log out to **character select** with Game Menu → Log Out.
2. Press **`~`** (or `` ` ``) to open the console. If it doesn't open, see step 4.1.
3. Type this and press Enter:
   ```
   ExportInterfaceFiles code
   ```
   The client freezes while it writes. That's normal; don't kill it. The command is case-insensitive (`exportInterfaceFiles code` also works, per the wiki and community scripts).
4. When it's done, optionally run:
   ```
   ExportInterfaceFiles art
   ```
   This one takes much longer and is much bigger. Community reports range from at least 2.8 GB (patch 8.2) to about 7 GB (2023). **UNVERIFIED for Forever:** the exact size and time; expect several GB and several minutes.
5. Output appears in the **product folder**, as `_classic_beta_\BlizzardInterfaceCode\Interface\...` and `_classic_beta_\BlizzardInterfaceArt\Interface\...`.
   - **UNVERIFIED for Forever specifically.** The wiki says "World of Warcraft directory". Current community instructions (wind-addons/BlizzardInterfaceCode) say the patch directory (`_retail_`, `_ptr_`, ...). If you don't see it in `_classic_beta_`, check the `World of Warcraft` root.
6. **What to send me:** zip **`BlizzardInterfaceCode`** (all of it). Expect it to be in the low hundreds of MB uncompressed; **UNVERIFIED** size. Don't send `BlizzardInterfaceArt` unless I ask, since it's mostly `.blp` textures and only matters for art and atlas work.

**Shortcut check:** Gethe/wow-ui-source has a **`forever`** branch whose head is `1.60.1 (70245)`, committed 2026-10-06. If your build from step 0 is **70245**, I already have identical code, so the code export just confirms it. Do it anyway if your build number differs.

---

## 3. Run the ForeverDump addon (in-game, out of combat)

ForeverDump handles everything that can be read from inside the game. Full details are in the addon's README.

1. Install `ForeverDump` to `_classic_beta_\Interface\AddOns\ForeverDump\` and enable it at character select.
2. Log in, stay **out of combat**, and run `/fdump static run` (v2.2.11: the only way the static client data is collected; it stays in the saved file until `/fdump static clear`) and `/fdump all` (live sections). Then use `/fdump record start|stop`, `/fdump probe` and `/fdump probe combat` as its README describes. A capture with the **FD_Logs** macro wipes the previous capture data at ON (learned data and static data are kept), so copy `ForeverDump.lua` off before starting the next one.
3. Run `/reload`, or log out cleanly. **This is when the file actually gets written:**
   `WTF\Account\<ACCOUNT>\SavedVariables\ForeverDump.lua`

---

## 4. Console access, debug commands and CVars

### 4.1 Turning the console on (if `~` does nothing)

- **Battle.net app (easiest, verified on the wiki):** Settings → Game Settings → expand the **WoW Forever / Classic Beta** entry → tick **Additional command line arguments** → type `-console` → Done. Then relaunch.
- **Windows shortcut:** add ` -console` after the closing quote of the `WowB.exe` target.
- **macOS (wiki):** `open "/Applications/World of Warcraft/World of Warcraft Launcher.app" --args -console`. This is the wiki's retail example. **UNVERIFIED:** whether launching the Beta.app directly this way honors `-console`; the Battle.net checkbox is the reliable route.
- **Non-US keyboard:** run `/run SetConsoleKey("z")`, which lasts this session only (wiki; `SetConsoleKey` is present in Forever's API docs). The `ConsoleKey` CVar (default `` ` ``) exists on Forever and stores the key.
- The wiki also notes that `/console enable` turns the console on without the launch argument.

### 4.2 Slash commands, verified against Forever's own source

These slash strings come from Forever's GlobalStrings (Ketho `forever` branch); the handlers are in Forever's `SlashCommands.lua` and `SlashCommandsOverrides.lua`.

| Command | What it does on Forever | Notes |
|---|---|---|
| `/fstack` or `/framestack` | Toggles the frame-stack tooltip under the mouse. Takes optional `showHidden showRegions showAnchors` booleans, e.g. `/fstack true true true` | Defaults come from CVars `fstack_showhidden`, `fstack_showregions`, `fstack_showanchors` |
| `/etrace` or `/eventtrace` | Toggles the Event Trace window (live event log with payloads) | `/etrace mark some text` drops a marker line into the log, which helps when you reproduce a bug |
| `/tinspect <expr>` or `/tableinspect` | Opens the Table Inspector on a Lua expression, or on the frame under the mouse if you give none | **Blocked if** `C_AddOns.GetScriptsDisallowedForBeta()` is true |
| `/dump <expr>` | Prints a value to chat | Same beta block as above |
| `/run <lua>` or `/script` | Runs Lua | Same beta block |
| `/api` | Blizzard's in-game API doc browser: `/api search <text>`, `/api system list`, `/api stats` | ForeverDump already exports all of this |
| `/console <cmd>` | Runs a console command from chat (`ConsoleExec`) | Can't run `ExportInterfaceFiles`. Secure CVars can't be set this way, only with `SetCVar`, and not in combat |
| `/reload` | Reloads the UI | The kit reports that **`ReloadUI()` called from addon code is protected on Forever**, so type `/reload` yourself |
| `/chatlog`, `/combatlog` | Toggle writing chat and combat logs to `Logs\` | Addons can't read the combat log on Forever (`COMBAT_LOG_EVENT_UNFILTERED` is restricted). The text file is written by the client, not an addon. See SELF-HOSTING.md §5. |

### 4.3 CVars to turn on for a dev session

All of these exist in Forever's CVar dump (Ketho `BlizzardInterfaceResources`, `forever` branch, build 70205). Type them in chat as shown, or drop the `/console ` prefix in the `~` console.

```
/console scriptErrors 1
/console scriptWarnings 1
/console taintLog 2
/console addonLoadDebugging 1
/console fstack_showhidden 1
/reload
```

| CVar | Value | Why |
|---|---|---|
| `scriptErrors` | `1` | Shows a popup on Lua errors (default 0). The kit reports that Forever **stops reporting errors after 100 in a session** ("Error reporting is now paused"), so fix floods first. |
| `scriptWarnings` | `1` | Shows Lua warnings, such as deprecated calls (default 0). |
| `taintLog` | `1`, then `2` if needed | Writes `Logs\taint.log`. Levels: 1 = blocked actions plus the taint that led to them, 2 = tainted global reads and writes, 3 = upvalues, 4 = table fields (wiki, and Forever's own CVar description). The wiki adds **5** = writes of secret values (added in 12.0.1), which would matter on Forever because of secret values. **UNVERIFIED on Forever:** level 5, since Forever's CVar description only lists 0–4. Try `5` while reproducing a secret-value issue. Level 11 gives no extra detail on live clients. The log is written periodically and at logout. Levels 3 and 4 get huge, so disable other addons first. |
| `addonLoadDebugging` | `1` | Writes `Logs\AddOnLoad.log`, the addon load log (Forever CVar description). |
| `scriptProfile` | `1` (only while profiling) | **Still present on Forever.** It enables the legacy CPU counters (`GetAddOnCPUUsage`, `GetFunctionCPUUsage`, `UpdateAddOnCPUUsage`, `ResetCPUUsage` are all in Forever's PerformanceDocumentation). It needs `/reload` and adds overhead, so **turn it off afterwards.** Example: `/run UpdateAddOnCPUUsage() print(GetAddOnCPUUsage("ForeverDump"))`. |
| *(no CVar)* `C_AddOnProfiler` | n/a | The modern always-available profiler is also on Forever: `IsEnabled`, `GetAddOnMetric(name, metric)`, `GetOverallMetric`, `GetApplicationMetric`, `GetTopKAddOnsForMetric`, `MeasureCall`. Metrics are `Enum.AddOnProfilerMetric` (`SessionAverageTime` 0, `RecentAverageTime` 1, `PeakTime` 4, `CountTimeOver5Ms` 6, ...). Example: `/run print(C_AddOnProfiler.GetAddOnMetric("ForeverDump", Enum.AddOnProfilerMetric.PeakTime))` |
| `fstack_showhidden` / `fstack_showregions` / `fstack_showanchors` / `fstack_preferParentKeys` | as you like | Defaults for `/fstack`. |
| `frameScriptFunctionInheritanceWarningMode` | `1` (optional) | Lua errors for script handlers that use inheritance incorrectly. |
| `addonCombatRestrictionsForced` (and the `addon*RestrictionsForced` family) | `1` (optional, testing) | "APIs guarded in combat will be restricted, or may return secrets." This lets you **test secret-value behavior out of combat.** Turn it back to `0` when done. |
| `developerLog` (+ `developerLogWriteToFile`) | `1` (optional) | Enables the client's Developer Log. **UNVERIFIED:** the file name and location it writes to. |
| `consoleShowDebugMessages` | `1` (optional) | Shows Debug-priority log lines in the `~` console. |

**Turn off afterwards:** `scriptProfile 0`, `taintLog 0`, `addonCombatRestrictionsForced 0`. Taint and profiling slow the client down.

**Not relevant here:** `gxRestart` and other graphics commands. **Not available on Forever:** `FrameXML_Debug` and `C_Debug.FrameXMLDebug`, the APIs that turn on the verbose `FrameXML.log`. Neither is in Forever's API dump or docs, so verbose FrameXML logging can't be switched on from Lua.

---

## 5. The Logs folder (`_classic_beta_\Logs\`)

**Do this:** after a session with the CVars above, **log out cleanly**, then look in `Logs\`.

| File | Useful? | Notes |
|---|---|---|
| `taint.log` | **Yes** | Created when `taintLog` ≥ 1 (wiki). Search for `blocked` first. |
| `AddOnLoad.log` | **Yes** | Created when `addonLoadDebugging` = 1 (Forever CVar description). |
| `FrameXML.log`, `GlueXML.log` | Yes, if present | The UI XML and load log; the wiki documents both. **UNVERIFIED on Forever:** whether they're written without `FrameXML_Debug`, which Forever lacks. Send them if they exist. |
| `WoWCombatLog*.txt` | When asked | Only if you used `/combatlog`. This is the one place full combat data still reaches us, because addons can't read it on Forever. Contains other players' names; see SELF-HOSTING.md §5. |
| `WoWChatLog.txt` | No | Contains other players' names and chat. Don't send it. |
| Other files (client/gx/developer logs) | Maybe | **UNVERIFIED** names. Include any `.log` modified during your session, but open each one first and remove anything personal. |

Errors folder (`_classic_beta_\Errors\`): after a **crash**, the client writes a `.txt` crash report and sometimes a `.dmp` minidump (Blizzard support and forum posts). Send the newest `.txt` only if you hit a crash. **The header contains `User:` (your Windows username) and `Computer:` (PC name), so delete those two lines first.** Don't send `.dmp` files; they can contain memory contents.

---

## 6. WTF files worth copying, and how to sanitize them

**⚠ Never share passwords, authenticator codes, Battle.net tokens, or anything from the Battle.net app's own folders. None of what I need contains credentials, but the files below do contain identifying names, so sanitize them.**

Paths (wiki, Blizzard forums):

| File | Send? | Why |
|---|---|---|
| `WTF\Account\<ACCOUNT>\SavedVariables\ForeverDump.lua` | **Yes (main deliverable)** | Everything ForeverDump collected |
| `WTF\Config.wtf` | **Yes, sanitized** | Startup and system CVars (graphics, locale, and so on) |
| `WTF\Account\<ACCOUNT>\config-cache.wtf` | Optional, sanitized | Account-scope CVars (server-synced when `synchronizeConfig` = 1, which is on by default on Forever) |
| `WTF\Account\<ACCOUNT>\bindings-cache.wtf` | Optional | Account key bindings, which help with keybinding-aware code |
| `WTF\Account\<ACCOUNT>\<Realm>\<Character>\...` | **No** | Per-character files; not needed |
| `macros-cache.txt` | No | Not needed (and macros can contain names) |

**Sanitize copies, never the originals.** Close the game first, because WoW overwrites these files on logout. Then:

1. Copy the files into a new folder, for example `Desktop\ForeverPack\`.
2. **Rename the account folder** in your copy to `ACCOUNT`. The real name may be your account name or a number like `12345678#1`. Do the same for any realm or character folder names.
3. In the copied **`Config.wtf`**, delete every line containing any of: `accountName`, `accountList`, `lastAccount`, `portal`, `realmList`, `realmName`, `lastCharacterIndex`, `agentUID`. `portal` is a real Forever CVar ("Name of Battle.net portal to use"). **UNVERIFIED:** whether all of the other keys appear in your file; deleting a line that isn't there does no harm.
   - Windows PowerShell (in the copy folder):
     ```powershell
     (Get-Content .\Config.wtf) | Where-Object { $_ -notmatch 'accountName|accountList|lastAccount|portal|realmList|realmName|lastCharacterIndex|agentUID' } | Set-Content .\Config.wtf
     ```
   - macOS Terminal (in the copy folder):
     ```bash
     grep -viE 'accountName|accountList|lastAccount|portal|realmList|realmName|lastCharacterIndex|agentUID' Config.wtf > Config.clean && mv Config.clean Config.wtf
     ```
4. Open the copied `ForeverDump.lua` in a text editor and **search for your character name, realm name and BattleTag**. Replace any hits with `PLAYER`, `REALM` and `BTAG`. Unit probes and event recordings can capture names and GUIDs.
5. Skim each file one last time. If you see anything that looks like an email address, a long random token, or a password, delete that line.

---

## 7. External sources (nothing for you to do; I'll pull these)

> To fetch or regenerate all of this yourself when a new build drops (with no game client needed for most of it), see **[SELF-HOSTING.md](SELF-HOSTING.md)** and the scripts in `tools/refresh/`.

These are for reference, so you don't have to collect them yourself.

| Source | What it gives | Forever status (checked 2026-10-07) |
|---|---|---|
| [Gethe/wow-ui-source, branch `forever`](https://github.com/Gethe/wow-ui-source/tree/forever) | Blizzard UI source mirror | **Matches Forever:** head is `1.60.1 (70245)`, 2026-10-06. Don't use `classic_beta`: it's stale (last commit Nov 2025, from an earlier Classic beta). `live` is retail 12.1.0. |
| [Ketho/BlizzardInterfaceResources, branch `forever`](https://github.com/Ketho/BlizzardInterfaceResources/tree/forever) | GlobalAPI, CVars, Events, Frames, Templates, Mixins, WidgetAPI, GlobalStrings (all locales), LuaEnum | Dumped from build 70205. README shows `WOW_PROJECT_ID => WOW_PROJECT_CAMELOT (18)`, `TOC [Game] => "Camelot"`, `[Family] => "Mainline"` |
| [Ketho/vscode-wow-api](https://github.com/Ketho/vscode-wow-api) | VS Code / LuaLS annotations for the WoW API | Mainline-based; the README doesn't mention a Forever flavor. Use it together with ForeverDump-generated annotations. |
| [wago.tools](https://wago.tools/) ([builds](https://wago.tools/builds)) | Build list, DB2 browser and CSV export | **Listed** as product `wow_classic_beta` ("Classic Beta", flavor `_classic_beta_`), latest `1.60.1.70245`, plus `wow_cn_beta` (CN). DB2 example: `https://wago.tools/db2/SpellName?branch=wow_classic_beta`; append `/csv` before `?` for CSV (tested working). |
| [foreverdiff.com](https://foreverdiff.com) | Spell, item and talent diffs, Forever vs Classic Era | Live, built from client data |
| [warcraft.wiki.gg API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API), [TOC format](https://warcraft.wiki.gg/wiki/TOC_format), [CVars](https://warcraft.wiki.gg/wiki/Console_variables) | API reference | TOC page lists Forever Beta = `16001`, game type `camelot`, `_Camelot.toc` suffix (may change at launch) |
| [Thunderz96/forever-addon-kit](https://github.com/Thunderz96/forever-addon-kit) | Measured Forever findings (secret values, protected `ReloadUI`, 100-error cap, unknown-event `RegisterEvent` errors), `data/forever_api.json`, porting and API-scan tools | Last updated 2026-09-24 (build 70009 era). Note: it says `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE`, while Ketho's newer dump shows `WOW_PROJECT_CAMELOT (18)`. ForeverDump records the real value. |
| [ClassicWoWCommunity/forever-bugs](https://github.com/ClassicWoWCommunity/forever-bugs) | Community Forever bug tracker | Active |
| [Blizzard: Forever beta known issues](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-known-issues-september-17/2352687), [dev notes (Sep 24)](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-september-24/2360696) | Official notes | |

---

## 8. Package and send

1. **Log out cleanly** (Game Menu → Log Out) so ForeverDump's SavedVariables and logs are flushed. Then **quit the game**.
2. Build a folder `ForeverPack` laid out like this:
   ```
   ForeverPack\
     BUILD.txt                      <- one line: your /dump GetBuildInfo() output
     ForeverDump.lua                <- from WTF\Account\<ACCOUNT>\SavedVariables\ (sanitized, step 6.4)
     Config.wtf                     <- sanitized copy (step 6.3)
     bindings-cache.wtf             <- optional
     Logs\taint.log                 <- if it exists
     Logs\AddOnLoad.log             <- if it exists
     Logs\FrameXML.log, GlueXML.log <- if they exist
     Errors\<newest>.txt            <- only if you crashed; User:/Computer: lines removed
   ```
3. Zip the pack and, separately, the exported code:
   - **Windows PowerShell** (run from the folder containing them):
     ```powershell
     Compress-Archive -Path .\ForeverPack\* -DestinationPath .\ForeverPack.zip
     Compress-Archive -Path "C:\Program Files (x86)\World of Warcraft\_classic_beta_\BlizzardInterfaceCode" -DestinationPath .\BlizzardInterfaceCode-<build>.zip
     ```
     Or right-click the folder → **Send to → Compressed (zipped) folder**.
   - **macOS Terminal:**
     ```bash
     cd ~/Desktop && zip -r ForeverPack.zip ForeverPack
     cd "/Applications/World of Warcraft/_classic_beta_" && zip -r ~/Desktop/BlizzardInterfaceCode-<build>.zip BlizzardInterfaceCode
     ```
     Or right-click → **Compress**.
4. **Send them to me:** attach `ForeverPack.zip` and `BlizzardInterfaceCode-<build>.zip` in this chat from your computer. If your build is 70245, the code zip is optional (see step 2). Don't send `BlizzardInterfaceArt` unless I ask; it's several GB.
5. Afterwards, turn the heavy CVars back off with `/console scriptProfile 0`, `/console taintLog 0` and `/console addonCombatRestrictionsForced 0`.

---

### Verification sources

- warcraft.wiki.gg: *Viewing Blizzard's interface code*, *Console*, *Console variables*, *CVar taintLog*, *CVar scriptErrors*, *CVar scriptProfile*, *TOC format*, *API FrameXML_Debug* / *C_Debug.FrameXMLDebug*.
- Forever UI source: Gethe/wow-ui-source `forever` @ 1.60.1.70245, including `Blizzard_ChatFrameBase/Shared/SlashCommands.lua`, `Mainline/SlashCommandsOverrides.lua`, `Blizzard_EventTrace.lua`, `Blizzard_DebugTools.lua`, and `Blizzard_APIDocumentationGenerated` (`AddOnProfiler`, `Performance`, `Console`, `AddOns` docs).
- Forever data dump: Ketho/BlizzardInterfaceResources `forever` (`Resources/CVars.lua`, `GlobalAPI.lua`, `GlobalStrings/enUS.lua`).
- wago.tools `/api/builds` and the home page product table.
- Blizzard forums: EU SavedVariables bug thread (fixed in 70009), US "PSA 8.1 New folder structure", crash and Errors-folder support threads.
- Thunderz96/forever-addon-kit README; mmonster.co and foreverwisp.com install guides (`_classic_beta_`, `WowB.exe`, `World of Warcraft Beta.app`).
