# -*- coding: utf-8 -*-
"""Curated, sourced content for SECRETS-GUIDE.html (imported by build_guide.py).

Inline confidence markup used in every text string here:
    [[v:SRC]]  verified in-game      [[o:SRC]]  official (Blizzard)
    [[d:SRC]]  docs / datamined      [[c:SRC]]  community
    [[p:]]     pending lab           [[i:]]     inference (my reasoning)
Several sources: [[o:B-260410,W-SV]].  Optional note after '|': [[p:|needs /fdump lab]].
build_guide.py turns these into badges + links to the Sources section. These strings are
trusted HTML written here; values read from input files are always escaped by the builder.
"""

DISCORD = "https://discord.com/channels/327414731654692866/"
WIKI_PLAN = "https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes"
W1201 = "https://warcraft.wiki.gg/wiki/Patch_12.0.1/API_changes"
W1205 = "https://warcraft.wiki.gg/wiki/Patch_12.0.5/API_changes"
W1207 = "https://warcraft.wiki.gg/wiki/Patch_12.0.7/API_changes"
W1210 = "https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes"
W1215 = "https://warcraft.wiki.gg/wiki/Patch_12.1.5/API_changes"

def _b(title, chan, date, mirror):
    return (title, DISCORD + chan, date, "official", "Discord (login needed); mirrored verbatim on " + mirror)

# id -> (title, url, date, kind, note); kind in official | docs | community | verified
SOURCES = {
    "B-250603": _b("Blizzard (WoWUIDev Discord): Clarifications on Planned Changes", "1379574033724608542", "2025-06-03", WIKI_PLAN),
    "B-251001": _b("Blizzard: Midnight Public Alpha Addon API Changes", "1422999311410790541", "2025-10-01", WIKI_PLAN),
    "B-251104": _b("Blizzard: Upcoming Restriction Changes (Week 6 and later)", "1435309770860134419", "2025-11-04", WIKI_PLAN),
    "B-251111": _b("Blizzard: Upcoming Restriction Changes (Beta 1 and later)", "1437889756460744735", "2025-11-11", WIKI_PLAN),
    "B-251113": ("Blizzard: Midnight Public Beta Update + news 'Combat Philosophy and Addon Disarmament in Midnight'", "https://worldofwarcraft.blizzard.com/en-us/news/24246290", "2025-11-13", "official", "Discord post " + DISCORD + "1438595756083904614; mirrored on " + WIKI_PLAN),
    "B-ION-NOV": ("Ion Hazzikostas (Reddit): clarification of goals", "https://www.reddit.com/r/wow/comments/1op6acz/comment/nnap3ga/", "2025-11 (between the Nov 5 and Nov 11 entries)", "official", "Quoted on " + WIKI_PLAN),
    "B-ION-1119": ("Ion Hazzikostas (Reddit): 'Addon Disarmament' not 'Addon Removal'", "https://www.reddit.com/r/wow/comments/1p1f3fh/comment/npqsxe3/", "2025-11-19", "official", "Quoted on " + WIKI_PLAN),
    "B-251208": _b("Blizzard: Midnight Beta 4 Changes", "1447679804961853531", "2025-12-08", WIKI_PLAN),
    "B-260112": _b("Blizzard: Midnight Beta 6 Changes", "1460387750480969840", "2026-01-12", WIKI_PLAN),
    "B-260121": _b("Blizzard: Midnight Beta 7 Changes", "1463646352239235259", "2026-01-21", WIKI_PLAN),
    "B-260219": _b("Blizzard: Midnight 12.0.1 AddOn Restrictions Update", "1473839027018010826", "2026-02-19", W1201),
    "B-260224": _b("Blizzard: Midnight 12.0.1 Spell Declassification Update", "1475979247825977595", "2026-02-24", W1201),
    "B-260312": _b("Blizzard: 12.0.5 PTR Changes Episode 1", "1481702172319027331", "2026-03-12", W1205),
    "B-260321": _b("Blizzard: Midnight 12.0.1 Upcoming Restriction Changes (cooldowns)", "1484980480217448540", "2026-03-21", W1201),
    "B-260325": _b("Blizzard: 12.0.5 PTR Changes Episode 2", "1481702172319027331", "2026-03-25", W1205),
    "B-260331": _b("Blizzard: 12.0.5 PTR Changes Episode 3", "1488643216222982267", "2026-03-31", W1205),
    "B-260410": _b("Blizzard: Midnight 12.0.5 Upcoming Restriction Changes", "1492239509264400486", "2026-04-10", W1205),
    "B-260430": _b("Blizzard: Midnight 12.0.7 and Classic PTR Changes I", "1499463604121112707", "2026-04-30", W1207),
    "B-260528": _b("Blizzard: Midnight 12.0.7 PTR Changes II", "1509594073680449650", "2026-05-28", W1207),
    "B-260618": ("Blizzard: Midnight 12.1.0 PTR Changes 1 + forum post 'Addons and Auras in Curse of Ula'tek'", DISCORD + "1517308873093152768", "2026-06-18", "official", "Forum: https://us.forums.blizzard.com/en/wow/t/addons-and-auras-in-curse-of-ula%E2%80%99tek/2317456; mirrored on " + W1210),
    "B-260623": _b("Blizzard: Midnight 12.1.0 PTR Changes 2", "1519131808640536626", "2026-06-23", W1210),
    "B-260630": _b("Blizzard: Midnight 12.1.0 PTR Changes 3", "1521649084996255784", "2026-06-30", W1210),
    "B-260707": _b("Blizzard: Midnight 12.1.0 PTR Changes 4", "1524130973619458170", "2026-07-07", W1210),
    "B-260903": _b("Blizzard: Midnight 12.1.5 PTR Changes 1", "1545113129736871966", "2026-09-03", W1215),
    "B-260916": _b("Blizzard: Midnight 12.1.5 PTR Changes 2", "1549542072816635984", "2026-09-16", W1215),
    "B-260922": _b("Blizzard: Midnight 12.1.5 PTR Changes 3", "1552068745374081104", "2026-09-22", W1215),
    "WH-FOREVER": ("Wowhead: 'WoW: Forever Will Have Addon Changes from Midnight' (quotes Blizzard via the WoW UI Discord)", "https://www.wowhead.com/news/wow-forever-will-have-addon-changes-from-midnight-382921", "2026-09-16", "official", "Blizzard quote relayed by Wowhead"),
    "W-SV": ("Warcraft Wiki: Secret Values", "https://warcraft.wiki.gg/wiki/Secret_Values", "accessed 2026-10-07", "docs", "Community wiki summarising the shipped docs"),
    "W-PLAN": ("Warcraft Wiki: Patch 12.0.0/Planned API changes (collects the Blizzard posts)", WIKI_PLAN, "accessed 2026-10-07", "docs", ""),
    "W-TOKEN": ("Warcraft Wiki: UnitToken", "https://warcraft.wiki.gg/wiki/UnitToken", "accessed 2026-10-07", "docs", "Token families and target-of chains"),
    "DOCS": ("Blizzard API docs + UI code shipped with Forever 1.60.1.70245 (Gethe/wow-ui-source, forever branch)", "https://github.com/Gethe/wow-ui-source/tree/forever", "commit 15666a6, 2026-10-06", "docs", "Blizzard_APIDocumentationGenerated, Blizzard_AuraContainer (CustomAuraContainer.lua), Blizzard_GameTooltip (GameTooltip_AddMoneyLine)"),
    "KETHO": ("Ketho/BlizzardInterfaceResources (forever branch, build 70205): CVars, GlobalAPI, Events", "https://github.com/Ketho/BlizzardInterfaceResources/tree/forever", "2026-10-06", "docs", ""),
    "INV": ("api-secrecy-inventory-forever-70245.tsv (generated from DOCS by src/inventory.lua)", "../api-secrecy-inventory-forever-70245.tsv", "2026-10-07", "docs", "Ground truth for every tag in this guide"),
    "RESEARCH": ("secrets-research.md (research report, this project)", "../secrets-research.md", "2026-10-07", "docs", "Full citations and contradictions"),
    "SV-RUN2": ("User's ForeverDump v2.1 capture on Forever 1.60.1.70245, The Barrens (SavedVariables + run2 outputs: verify.json, restrictions.json, taint.log, WoWCombatLog.txt, Client.log)", "", "captured 2026-10-07 19:48-19:58 ET", "verified", "Box: /workspace/foreverdump/real/2026-10-07-run2/ (counts only, never raw secret values)"),
    "USER-TEST": ("User's manual in-game tests on Forever 70245 (reported in the project conversation)", "", "2026-10-07", "verified", "UnitHealth('player') secret in and out of combat, alive and dead; UnitHealthMax('player') clear (1345); h+0 errors; tostring/print show the value but the string is secret; tonumber(secret string) is nil"),
    "C-KIT": ("Thunderz96/forever-addon-kit README", "https://github.com/Thunderz96/forever-addon-kit", "2026-09-18 to 09-25", "community", ""),
    "C-BUILDS": ("wowforeverbuilds: 'What the WoW Forever beta breaks for addons' (AI-drafted)", "https://wowforeverbuilds.com/news/what-the-wow-forever-beta-breaks-for-addons-secret-health-values-dead-secure-sni", "2026-09-18", "community", ""),
    "C-GUIDES": ("wowforeverguides: addon developer pages", "https://wowforeverguides.com/addons/developers", "2026-09-27 to 10-01", "community", ""),
    "C-DEVGUIDE": ("Nakuromi WoWAddonDevGuide: Secret-safe APIs", "https://raw.githubusercontent.com/Nakuromi/WoWAddonDevGuide/refs/heads/master/12a_Secret_Safe_APIs.md", "accessed 2026-10-07", "community", ""),
    "C-DECURSIVE": ("Decursive issue #51 (taint + secret arithmetic in Blizzard code)", "https://github.com/2072/Decursive/issues/51", "2026-03-17 to 08-27", "community", ""),
    "C-BUGS": ("ClassicWoWCommunity/forever-bugs issue tracker", "https://github.com/ClassicWoWCommunity/forever-bugs/issues", "accessed 2026-10-07", "community", ""),
    "WH-WA": ("Wowhead: 'No WeakAuras Addon for Midnight'", "https://www.wowhead.com/news/no-weakauras-addon-for-midnight-378740", "2025-10-03", "community", ""),
    "WH-ADV": ("Wowhead: 'Addons Continue to Provide a Massive Advantage in Midnight Despite Blizzard's Goals'", "https://www.wowhead.com/news/addons-continue-to-provide-a-massive-advantage-in-midnight-despite-blizzards-379870", "2026-01-13", "community", ""),
    "WH-MINIMAP": ("Wowhead: 'The Power of Using Minimap Rotation for Addons in Season 2 of Midnight'", "https://www.wowhead.com/news/the-power-of-using-minimap-rotation-for-addons-in-season-2-of-midnight-382757", "2026-09-05", "community", ""),
    "SV-RUN5": ("User's ForeverDump v2.2.4 capture on Forever 1.60.1.70245 (run 5: SavedVariables, WoWCombatLog.txt, taint.log)", "", "captured 2026-10-08 ET", "verified", "Box: /workspace/foreverdump/real/2026-10-08-run5/ (counts, codes and ids only; the combat log is read offline as ground truth, never live)"),
    "FD": ("ForeverDump project docs (ADDON-USAGE.md, tools/README.md) and v2.2 Lab.lua / Controls.lua", "", "2026-10-07", "community", "Box: /workspace/foreverdump/ (HSMUI.lua, Inference.lua, Knowledge.lua, Lib/HybridState.lua, Controls.lua, Lab.lua; project code, behaviour not independently verified here)"),
}

# ---------------------------------------------------------------------------- 1) TL;DR
TLDR = [
    "A <b>secret</b> is an opaque box around a normal Lua value. Your addon (tainted code) can <b>hold it, pass it to Blizzard APIs and widgets, and display it</b>, but cannot look inside or compute with it: arithmetic, ordered comparison, <code>#</code>, table keys and string parsing fail [[o:B-251001]] [[d:W-SV]].",
    "Forever runs the Midnight (12.x) system: Blizzard says Forever shares Mainline's UI architecture and 'the vast majority of APIs available in 12.1.5', and 'the addon disarmament changes introduced in Midnight, including secrets, will also be active in Forever' [[o:WH-FOREVER]].",
    "On Forever 70245 <code>UnitHealth('player')</code> is secret <b>even out of combat</b> (alive and dead) while <code>UnitHealthMax('player')</code> is a plain number (1345 in the user's test) [[v:USER-TEST,SV-RUN2]]. Guides saying 'out of combat everything is readable' are wrong for this build [[c:C-DEVGUIDE]].",
    "Many values are <b>conditionally</b> secret: cooldown timing, auras, unit stats (incl. movement speed), threat, damage-meter sessions turn secret when the Combat restriction (or Encounter / M+ / PvP / Map) is active [[d:INV]] [[v:SV-RUN2]].",
    "Unit tokens (<code>party1</code>, <code>target</code>, <code>nameplate3</code>...) still resolve; secrecy attaches to the <b>values returned</b> for a unit, not to the token. Some APIs refuse certain token kinds (compound <code>boss1target</code>, names, nameplate/party mixes) [[o:B-260121,B-260325]] [[d:DOCS]]. See <a href='#tokens'>Unit tokens</a>.",
    "Rule of thumb: <b>display, don't decide.</b> Feed secrets into widgets, use engine-side helpers (UnitHealthPercent + curves, duration objects, AuraContainer), use non-secret neighbours, and drop logic that needs the real number in combat; that is the stated intent [[o:B-251113]] [[i:]].",
]
MENTAL_MODEL = [
    ("Holding", "local h = UnitHealth('player')", "Allowed: h is a box", "ok"),
    ("Passing / displaying", "bar:SetValue(h); fs:SetText(h)", "Allowed: the engine opens the box", "ok"),
    ("Formatting", "s = format('%d', h)", "Allowed, but s is a secret string too", "secret"),
    ("Inspecting", "if h < 100 then ... end; h + 0; t[h] = 1", "Lua error", "err"),
    ("Saving", "MyDB.hp = h", "Written as nil (+ comment) in SavedVariables", "nil"),
]

# ---------------------------------------------------------------------------- 2) What changed
PRE_VS_NOW = [
    ("Combat numbers (health, power, cooldowns, auras)", "Plain Lua values; addons could compute anything.", "Secrets for addon code; untainted Blizzard code still sees real values [[o:B-251001]]."),
    ("Protection model", "Protected functions + taint (InCombatLockdown, secure templates); Private Auras since 10.1 [[o:B-260312]].", "Adds secret values, secret aspects on widgets, restriction types/states, Forbidden Aspects (12.1) [[o:B-260618,B-260623]]."),
    ("Combat log", "COMBAT_LOG_EVENT_UNFILTERED + CombatLogGetCurrentEventInfo.", "Restricted for addons: <code>C_CombatLog.IsCombatLogRestricted()</code> true even out of combat on Forever [[v:SV-RUN2]] [[d:INV]]; the WoWCombatLog file still has full amounts [[v:SV-RUN2]]."),
    ("Unit identity", "Names/GUIDs of everything nearby.", "Secret on instanced maps for anything that isn't you, your pet/vehicle or a group member [[o:B-260410]]."),
    ("Saving data", "Anything could go into SavedVariables.", "Secrets are written as nil with a comment [[o:B-251111]]."),
    ("Cooldown frames", "SetCooldown(start, duration).", "Tainted code must use <code>Cooldown:SetCooldownFromDurationObject</code> [[o:B-260321]]."),
    ("Auras", "UnitAura / C_UnitAuras by index; scan everything.", "While auras are secret, index/slot/instance APIs raise a Lua error; display via AuraContainer/AuraButton [[o:B-260630,B-260707]]."),
]
TIMELINE = [
    ("2025-06-03", "Announcement", "Goals clarified: no addon ban, minimise collateral damage, base UI gains a damage meter and better nameplates [[o:B-250603]]."),
    ("2025-10-01", "Midnight Alpha", "Secret Values introduced ('like black boxes'); compare/arithmetic error; untainted code unrestricted; <code>issecretvalue</code> [[o:B-251001]]."),
    ("2025-11-04", "Alpha 6", "Cross-type <code>==</code> gives non-secret false; <code>nil==nil</code> true; <code>if x then</code> = non-nil test; <code>tonumber</code> on secret strings no longer permitted; UnitHealthMax/UnitPowerMax not secret for player units; player's own casts not secret [[o:B-251104]]."),
    ("2025-11-11", "Beta 1", "Secrets in SavedVariables become nil + comment; spells/auras can be flagged never-secret; identity checked along target chains [[o:B-251111]]."),
    ("2025-11-13", "Beta", "Philosophy: 'Addons should not be able to provide a competitive advantage in combat' [[o:B-251113]]."),
    ("2025-12-08", "Beta 4", "C_Secrets, C_RestrictedActions and the AddOnRestriction enums appear [[o:B-251208]] [[d:RESEARCH]]."),
    ("2026-01-12", "Beta 6", "GetNamePlateForUnit refuses compound tokens from tainted code [[o:B-260112]]."),
    ("2026-01-20", "12.0.0 live", "System listed as 'Added 12.0.0' [[d:W-SV]]."),
    ("2026-01-21", "Beta 7", "New type UnitTokenRestrictedForAddOns: aura/nameplate APIs refuse compound tokens and names (targettarget exempt) [[o:B-260121]]."),
    ("2026-02-19", "12.0.1 hotfix", "Status-bar laundering fixed; APIs refuse secret spell names; compound tokens/names refused in active PvP matches [[o:B-260219]]."),
    ("2026-02-24", "12.0.1", "Spell declassification list (healer HoTs, raid buffs, Hearthstone 8690, Reincarnation 20608, M+ teleports) [[o:B-260224]]. On Forever 70245 these reported ContextuallySecret (2) [[v:SV-RUN2]]."),
    ("2026-03-21", "12.0.1", "Tainted code can't feed secrets to SetCooldown*; SetCooldownFromDurationObject only; non-secret isActive field [[o:B-260321]]."),
    ("2026-03 to 04", "12.0.5", "Predicates table in docs; UnitSpellTargetName players only; UnitIsUnit rules; UnitTokenFromGUID withholds tokens; identity secret on instanced maps; taint-log fixes; CVars renamed to addon*RestrictionsForced [[o:B-260312,B-260325,B-260331,B-260410]] [[d:RESEARCH]]."),
    ("2026-04-30", "12.0.7", "debugstack/debuglocals return secrets if the stack touched one; loot/xp/money chat events no longer secret; GameTooltip_AddMoneyLine replaces SetTooltipMoney [[o:B-260430]]."),
    ("2026-06-18 to 07-07", "12.1.0", "AuraContainer/AuraButton, Forbidden Aspects; UnitAura index/slot/instance APIs error while auras are secret; UNIT_AURA payload fully secret [[o:B-260618,B-260623,B-260630,B-260707]]."),
    ("2026-09-03 to 09-22", "12.1.5", "Castbar IDs unique per token; TimedSignalMap; GetArenaOpponentSpec secret; DamageMeter sourceGUID secret when identity is secret; tostring/dumpobject crash on secret objects fixed [[o:B-260903,B-260916,B-260922]]."),
    ("2026-09-16", "Forever", "Blizzard: Forever shares Mainline UI; secrets and AuraContainer active; game type 'Camelot (to be renamed before launch)' [[o:WH-FOREVER]]."),
    ("2026-10-05", "Forever 70245", "Build date of the client tested (1.60.1.70245, TOC 16001) [[v:SV-RUN2]]."),
]
FOREVER_SPECIFICS = [
    "<b>Project ID:</b> <code>WOW_PROJECT_ID == 18</code> = <code>WOW_PROJECT_CAMELOT</code> on 70245 (<code>WOW_PROJECT_MAINLINE</code> = 1) [[v:SV-RUN2]]. Community notes said 1 on builds 69913/70009 [[c:C-KIT,C-BUILDS,C-GUIDES]], and Blizzard says 'Camelot' will be renamed [[o:WH-FOREVER]]: prefer feature detection (<code>if C_Secrets then</code>) over a hard-coded ID [[i:]].",
    "<b>Client:</b> 1.60.1, build 70245, TOC 16001, product wow_classic_beta, build date Oct 5 2026 [[v:SV-RUN2]].",
    "<b>Combat log:</b> COMBAT_LOG_EVENT(_UNFILTERED) is tagged HasRestrictions [[d:INV]]; <code>C_CombatLog.IsCombatLogRestricted()</code> returned true in and out of combat [[v:SV-RUN2]]. Project notes say registering CLEU fires ADDON_ACTION_FORBIDDEN with the 'disable addon' popup and that CombatLogGetCurrentEventInfo is gone [[c:FD]] [[p:]]. The <code>Logs\\WoWCombatLog*.txt</code> file still records full events with amounts (965 lines incl. SWING_DAMAGE, SPELL_DAMAGE, UNIT_DIED in the user's run) [[v:SV-RUN2]].",
    "<b>Addon chat:</b> <code>C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()</code> returned true out of combat in the open world while the Chat restriction was Inactive [[v:SV-RUN2]].",
    "<b>Whitelist differs from retail:</b> <code>C_Secrets.GetSpellCooldownSecrecy</code> / <code>GetSpellCastSecrecy</code> / <code>GetSpellAuraSecrecy</code> returned 2 (ContextuallySecret) for every probed spell, including 8690 Hearthstone and 1459 Arcane Intellect which retail declassified [[v:SV-RUN2]] vs [[o:B-260224]]; <code>GetPowerTypeSecrecy</code> returned 2 for power types 0-3 [[v:SV-RUN2]].",
    "<b>Docs:</b> Forever's secret doc files match live except whitespace; Forever adds 28 doc files (e.g. LuaValuePredicates, TimedSignalMap) [[d:RESEARCH]].",
    "<b>Missing widget types:</b> login warnings 'Unknown frame type: VectorGraphics', 'Unable to create frame type: MapScene / ModelFFX' [[v:SV-RUN2]].",
]

# ---------------------------------------------------------------------------- 3) Intent
QUOTES = [
    ("B-250603", "We are embarking on this project with the aim of leveling the playing field and making the game more approachable for all players. Currently, addons are able to analyze and \"solve\" combat and coordination mechanics perfectly, and faster than would be possible for an unassisted human player."),
    ("B-250603", "Addons provide a huge amount of value to our players, and we have no intention of banning them or anything like that. We are aiming to cause the least amount of collateral damage possible to addons when these changes go live."),
    ("B-251001", "The easiest way to think of Secret Values (Secrets) is that they are like black boxes, which contain a Lua value of any type (number, string, boolean, etc) inside them. Insecure (tainted) Lua code can receive Secrets from our APIs and pass those Secrets into certain APIs, but it cannot actually see the value that is inside of that box."),
    ("B-251113", "Addons should not be able to provide a competitive advantage in combat. [...] While we have no issue with addons customizing how combat information we show in our UI is presented to players (whether for accessibility or personal preference reasons), players should never feel like they are at a competitive disadvantage if they choose not to use an addon."),
    ("B-ION-NOV", "The overarching goal of the changes in Midnight is to level the playing field and do what we can to make it so that while addons can still thoroughly personalize your experience, they aren't giving you an objective competitive advantage over people using the base UI."),
    ("B-ION-1119", "there's a reason last week's blog was about \"Addon Disarmament\" and not \"Addon Removal.\" The focus has always been on limiting combat performance advantages, and anything else that has been affected was collateral damage that we are working on repairing."),
    ("B-260224", "Ultimately, this design space is mostly about customizing the display of information, rather than objectively advantageous computational solutions"),
    ("B-260618", "These changes focus on preventing auras (whether on the player, enemies, or party and raid members) from leaking important combat information that can be used for combat automation. At the same time, we want addons to continue being able to show auras in a variety of custom ways."),
    ("WH-FOREVER", "WoW Forever shares Mainline WoW's UI architecture, including the vast majority of APIs available in 12.1.5. [...] Forever and modern WoW (Midnight) are two game types within the Mainline code family: Camelot (to be renamed before launch) and Standard, respectively. The addon disarmament changes introduced in Midnight, including secrets, will also be active in Forever."),
]
COMMUNITY_REACTION = [
    "WeakAuras said it does 'not expect to release a WeakAuras version for Midnight' after evaluating the changes [[c:WH-WA]].",
    "Wowhead argued addons still give a large advantage despite the goal; new workarounds (e.g. minimap-rotation aiming lines) keep appearing and Blizzard addresses them case by case [[c:WH-ADV,WH-MINIMAP]].",
    "Blizzard repeatedly closed 'laundering' tricks (status bars, string precision, castbar IDs) [[o:B-260219,B-260321,B-260903]]: treat side channels as exploits that will break [[i:]].",
    "Taint is the most common porting pain: Blizzard code tainted by an addon fails on its own secret maths and the error names that addon [[c:C-DECURSIVE]] [[v:SV-RUN2]].",
    "Forever community kits help but some claims are stale for 70245 (project ID 1, 'range not secret', 'out of combat readable') [[c:C-KIT,C-GUIDES,C-DEVGUIDE]] vs [[v:SV-RUN2]].",
]

# ---------------------------------------------------------------------------- 4) Mechanics
RESTRICTION_TYPES = [
    (0, "Combat", "Player in combat, open world included. Toggled 9 times in The Barrens [[v:SV-RUN2]]."),
    (1, "Encounter", "Boss encounter in progress [[d:DOCS]]."),
    (2, "ChallengeMode", "Mythic+ keystone run [[d:DOCS]]."),
    (3, "PvPMatch", "Active arena/battleground match [[d:DOCS]]."),
    (4, "Map", "Addon-restricted map (dungeon, raid) [[d:DOCS]]."),
    (5, "Chat", "Chat messaging lockdown [[d:DOCS]]."),
]
RESTRICTION_STATES = [
    (0, "Inactive", "No restriction. <code>ADDON_RESTRICTION_STATE_CHANGED(type, 0)</code> fires <b>after</b> deactivation [[d:DOCS]] [[v:SV-RUN2]]."),
    (1, "Activating", "<code>ADDON_RESTRICTION_STATE_CHANGED(type, 1)</code> fires <b>before</b> the restriction applies; <code>IsAddOnRestrictionActive</code> 'will always return false during dispatch' [[d:DOCS]]."),
    (2, "Active", "Enforced. <b>No event is sent for this state</b>: poll <code>C_RestrictedActions.GetAddOnRestrictionState(type)</code> on the next frame [[d:DOCS]] [[v:SV-RUN2|in-combat snapshot read 2]]."),
]
FIELD_TAGS = [
    ("SecretReturns", "Returns are secret unconditionally (19 functions, e.g. UnitHealth, UnitInRange, GetRaidTargetIndex)."),
    ("SecretPayloads", "Event payload always secret (e.g. UNIT_IN_RANGE_UPDATE, RUNE_POWER_UPDATE, MINIMAP_PING)."),
    ("SecretValue", "This field is always secret (e.g. UNIT_AURA_BLOCKED.auraInstanceID)."),
    ("SecretWhen* / SecretIn* / SecretOn*", "Conditionally secret; the predicate says when. Applies to every return/field without NeverSecret."),
    ("NeverSecret = true", "Never secret even when the function is (GetSpellCooldown isEnabled/isActive/isOnGCD, castBarID). 965 fields."),
    ("ConditionalSecret = true", "Only this field may be secret (UnitClass className, UNIT_SPELLCAST_SENT target)."),
    ("SecretArguments", "May you pass a secret INTO the API? AllowedWhenTainted (addons may), AllowedWhenUntainted (Blizzard code only), NotAllowed."),
    ("SecretArgumentsAddAspect", "Passing a secret gives the widget a secret aspect (SetText adds Text, SetValue adds BarValue); its getters then return secrets."),
    ("Requires* (Precondition)", "The call fails (Error / ReturnNothing / ReturnWithError / nil) if unmet, e.g. RequiresUnitAuraAccess, RequiresComparableUnitTokens."),
    ("HasRestrictions", "Restricted/protected for addons (e.g. COMBAT_LOG_EVENT_UNFILTERED)."),
]
TAINT_EXAMPLE = """10/7 19:57:40.890  Execution tainted by TweaksForever while reading field info (<table: ...>) - Interface/AddOns/Blizzard_MoneyFrame/Mainline/MoneyFrame.lua:226 MoneyFrame_Update()
10/7 19:57:40.890      Interface/AddOns/Blizzard_MoneyFrame/Shared/MoneyFrame.lua:652 SetTooltipMoney()
10/7 19:57:40.890      Interface/AddOns/TweaksForever/UI/Spellbook.lua:402
10/7 19:57:40.890  An attempt to perform arithmetic on a secret value was blocked because of taint from TweaksForever - Interface/AddOns/Blizzard_MoneyFrame/Mainline/MoneyFrame.lua:340 MoneyFrame_Update()"""
MECH_NOTES = [
    "<b>Containers.</b> Struct returns are plain tables whose <i>fields</i> may be secret [[d:RESEARCH]]; duration objects, curves and widgets are containers too. <code>issecretvalue(obj)</code> is false for them: ask <code>obj:HasSecretValues()</code> (duration objects, widgets) or <code>hasanysecretvalues(t)</code> / <code>canaccesstable(t)</code> [[d:DOCS]]. GetSpellCooldown's table was clear while startTime/duration/modRate were secret in combat [[v:SV-RUN2]].",
    "<b>Secret strings.</b> <code>tostring(secret)</code>, <code>format()</code> and <code>..</code> give secret strings; <code>tonumber(secretString)</code> returned nil in the user's test [[v:USER-TEST]] (Blizzard: 'no longer permitted' [[o:B-251104]]). Width/precision specifiers like <code>%.1s</code> are ignored for secret strings [[o:B-260312,B-260321]].",
    "<b>Taint interaction.</b> Secrets only restrict tainted code. If your addon taints Blizzard code (writing its tables/globals, calling into it from tainted paths), Blizzard's own secret maths fails and blames you; real example below [[v:SV-RUN2]] [[c:C-DECURSIVE]]. Blizzard recommends <code>GameTooltip_AddMoneyLine</code> over <code>SetTooltipMoney</code> for exactly this money-frame case [[o:B-260430]].",
    "<b>/run and /script.</b> Chat-typed scripts execute force-tainted ('ForceTaint_Strong'), so <code>/run print(UnitHealth('player')+0)</code> behaves like addon code [[v:USER-TEST]] [[c:FD]]. Good for quick tests, not a way around secrets [[i:]].",
    "<b>SavedVariables.</b> A secret written to SV is serialised as nil with a comment [[o:B-251111]]; store a classification ('secret'/'clear') instead [[i:]].",
    "<b>Debug output.</b> <code>/dump</code> and Event Trace show secret contents/state to you [[d:RESEARCH]]; <code>print(secret)</code> shows the value in chat [[v:USER-TEST]]. Since 12.0.7 <code>debugstack()</code>/<code>debuglocals()</code> return secrets if the stack touched one [[o:B-260430]].",
    "<b>Untainted code.</b> Blizzard's secure code operates on secrets normally [[o:B-251001]].",
]

SOURCES.update({
    "W-1200": ("Warcraft Wiki: Patch 12.0.0/API changes", "https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes", "accessed 2026-10-07", "docs", "Notes 'COMBAT_LOG_EVENT and COMBAT_LOG_EVENT_UNFILTERED will error when trying to register them'"),
    "B-251011": _b("Blizzard: Upcoming Restriction Changes (Week 3 and later)", "1426652212200996874", "2025-10-11", WIKI_PLAN),
    "B-260714": _b("Blizzard: Midnight 12.1.0 PTR Changes 5", "1526663208918712340", "2026-07-14", W1210),
    "B-260721": _b("Blizzard: Midnight 12.1.0 PTR Changes 6 (incl. Aura Classifications)", "1529209785658900634", "2026-07-21", W1210),
})

# ---------------------------------------------------------------------------- 5) Operations matrix
# (operation, example, result, kind ok|err|secret|nil|pending, confidence markup, lab key or None)
# lab key = (subject in the Controls ops matrix, op name, field) - filled from --lab when present
OPS = [
    ("Store in a local / table value", "local h = UnitHealth('player'); t.hp = h", "Allowed", "ok", "[[o:B-251001]] [[d:W-SV]]", None),
    ("Pass to a Lua function", "myFunc(h)", "Allowed", "ok", "[[d:W-SV]]", None),
    ("Pass to an API", "bar:SetValue(h)", "Allowed if the API's SecretArguments permits tainted secrets", "ok", "[[d:DOCS]]", None),
    ("Arithmetic", "h + 0, h * 2, -h", "Lua error", "err", "[[v:USER-TEST]] [[o:B-251001]]", ("UnitHealth(player)", "arith", "ok")),
    ("Ordered comparison", "h > 0, h <= x", "Lua error", "err", "[[o:B-251001]]", ("UnitHealth(player)", "compare", "ok")),
    ("Equality, same type", "h == 0", "Lua error (comparison)", "err", "[[o:B-251001]] [[p:]]", ("UnitHealth(player)", "equal", "ok")),
    ("Equality, different types", "h == 'x'", "Non-secret false", "ok", "[[o:B-251104]]", None),
    ("nil test", "if h then ... / h == nil", "Acts like type(h) ~= 'nil' (non-secret result)", "ok", "[[o:B-251104]]", ("UnitHealth(player)", "truthy", "ok")),
    ("Truth-test a secret boolean", "if UnitInRange('party1') then", "Lua error (only non-boolean secrets may be truth-tested)", "err", "[[d:W-SV]] [[p:]]", None),
    ("type()", "type(h)", "Real type ('number')", "ok", "[[d:W-SV]]", None),
    ("issecretvalue()", "issecretvalue(h)", "true", "ok", "[[v:SV-RUN2]] [[d:DOCS]]", None),
    ("tostring()", "s = tostring(h)", "A secret string (it displays the number)", "secret", "[[v:USER-TEST]]", ("UnitHealth(player)", "tostring", "resultSecret")),
    ("tonumber() of that string", "tonumber(s)", "nil, no error (user's test); Blizzard: 'no longer permitted'", "nil", "[[v:USER-TEST]] [[o:B-251104]]", ("UnitHealth(player)", "tostring", "tonumberNil")),
    ("print()", "print(h)", "Prints the value to chat (display only)", "ok", "[[v:USER-TEST]]", ("UnitHealth(player)", "print", "ok")),
    ("string.format", "format('%d', h)", "Secret string; width/precision not honoured for secret strings", "secret", "[[d:W-SV]] [[o:B-260312]]", ("UnitHealth(player)", "format", "resultSecret")),
    ("Concatenation", "'HP: '..h", "Secret string", "secret", "[[d:W-SV]]", ("UnitHealth(player)", "concat", "resultSecret")),
    ("Length", "#s", "Lua error", "err", "[[d:W-SV]]", None),
    ("String library on a secret string", "s:sub(1,1), s:find('1'), s:gsub(..), s:upper()", "Not documented per function; Blizzard closed declassification tricks", "pending", "[[o:B-260219]] [[p:|Lab 'secret-string' item]]", None),
    ("Table key", "t[h] = true", "Lua error", "err", "[[d:W-SV]]", ("UnitHealth(player)", "tableKey", "ok")),
    ("Index / call", "h.x, h()", "Lua error", "err", "[[d:W-SV]]", None),
    ("FontString:SetText / SetFormattedText", "fs:SetText(h)", "Allowed (AllowedWhenTainted); adds the Text aspect, GetText then returns a secret", "ok", "[[d:DOCS]]", ("UnitHealth(player)", "setText", "ok")),
    ("StatusBar:SetMinMaxValues / SetValue", "bar:SetValue(h)", "Allowed (AllowedWhenTainted); adds BarValue; GetValue returns a secret (bar laundering was fixed)", "ok", "[[d:DOCS]] [[o:B-260219]]", ("UnitHealth(player)", "statusBar", "ok")),
    ("Texture:SetVertexColor / StatusBar:SetStatusBarColor", "tex:SetVertexColor(secret r,g,b,a)", "Allowed (AllowedWhenTainted); adds VertexColor/Alpha aspects", "ok", "[[d:DOCS]]", None),
    ("Cooldown:SetCooldown(secret, secret)", "cd:SetCooldown(s, d)", "Not allowed from tainted code: use SetCooldownFromDurationObject", "err", "[[o:B-260321]]", None),
    ("Write to SavedVariables", "MyDB.hp = h", "Saved as nil + comment", "nil", "[[o:B-251111]]", None),
    ("debugstack() after touching a secret", "debugstack()", "Returns a secret string", "secret", "[[o:B-260430]]", None),
    ("tostring / dumpobject on a secret object", "tostring(secretObj)", "Crash fixed in 12.1.5", "ok", "[[o:B-260916]] [[p:]]", None),
]

# ---------------------------------------------------------------------------- COMBAT SECRETS
UNIT_CLASSES = [
    ("player", "Player (you)"),
    ("target_hostile_npc", "Hostile NPC (target)"),
    ("friendly_npc", "Friendly NPC"),
    ("other_player", "Other player (not grouped)"),
    ("party_raid", "Party / raid member"),
    ("nameplate", "Nameplate unit (NPC)"),
]
CONTEXTS = [
    ("ooc", "Out of combat"),
    ("combat", "In combat"),
    ("restricted", "Restriction active"),
]
ANY = "any"

def _all(code, why):
    return {uc: {cx: (code, why) for cx, _ in CONTEXTS} for uc, _ in UNIT_CLASSES}

def _by_unit(m, default=None):
    return {uc: {cx: m.get(uc, default) for cx, _ in CONTEXTS} for uc, _ in UNIT_CLASSES}

def _by_ctx(m):
    return {uc: {cx: m[cx] for cx, _ in CONTEXTS} for uc, _ in UNIT_CLASSES}

def _grid(fn):
    return {uc: {cx: fn(uc, cx) for cx, _ in CONTEXTS} for uc, _ in UNIT_CLASSES}

def _identity(uc, cx):
    if uc in ("player", "party_raid"):
        return ("C", "you and group members are never identity-restricted")
    if cx == "restricted":
        return ("S", "identity secret on instanced maps for non-group units (12.0.5)")
    return ("C", "open world: not identity-restricted (12.0.5 rule)")

def _threat(uc, cx):
    if cx == "ooc":
        return ("C", "no threat out of combat")
    if uc in ("target_hostile_npc", "nameplate", "player"):
        return ("C?", "single token, or player vs target/nameplate: 'generally not secret'")
    return ("S?", "other token pairs may be secret")

AURA_EXPECT = _by_ctx({
    "ooc": ("C", "auras not restricted out of combat"),
    "combat": ("E", "index/slot/instance APIs raise a Lua error while auras are secret (12.1.0)"),
    "restricted": ("E", "same during encounter / M+ / PvP"),
})

COMBAT_ITEMS = [
    {"id": "health.current", "title": "Current health", "apis": ["UnitHealth", "UnitHealthMissing"],
     "expect": _all("S", "SecretReturns: unconditional"), "observe": ["UnitHealth"],
     "summary": "Always secret for every unit and context, including you out of combat [[d:INV]] [[v:USER-TEST,SV-RUN2]].", "pattern": "pat-healthbar"},
    {"id": "health.max", "title": "Max health", "apis": ["UnitHealthMax"],
     "expect": _by_unit({"player": ("C", "player-controlled"), "other_player": ("C", "player-controlled"), "party_raid": ("C", "player-controlled"),
                         "target_hostile_npc": ("S", "not player-controlled"), "friendly_npc": ("S", "not player-controlled"), "nameplate": ("S", "NPC")}),
     "observe": ["UnitHealthMax"],
     "summary": "Secret only for units that aren't player-controlled (SecretWhenUnitHealthMaxRestricted) [[d:INV]]; your own is plain (1345 in the user's test) [[v:USER-TEST]], matching 'no longer return secrets for player units' [[o:B-251104]].", "pattern": "pat-healthbar"},
    {"id": "health.percent", "title": "Health percent", "apis": ["UnitHealthPercent"],
     "expect": _all("S", "SecretReturns (+ SecretWhenCurveSecret)"), "observe": ["UnitHealthPercent"],
     "summary": "Secret, but it is the engine-side helper: pass a curve to get a value ready for a widget [[d:INV]] [[v:SV-RUN2]].", "pattern": "pat-healthbar"},
    {"id": "health.absorbs", "title": "Absorbs (total / heal absorbs)", "apis": ["UnitGetTotalAbsorbs", "UnitGetTotalHealAbsorbs"],
     "expect": _all("S", "SecretReturns"), "observe": ["UnitGetTotalAbsorbs"],
     "summary": "Always secret [[d:INV]] [[v:SV-RUN2]]; draw with a second StatusBar [[i:]].", "pattern": "pat-healthbar"},
    {"id": "health.incomingHeals", "title": "Incoming heals", "apis": ["UnitGetIncomingHeals", "UnitGetDetailedHealPrediction"],
     "expect": _all("S", "SecretReturns (nil when nothing incoming)"), "observe": ["UnitGetIncomingHeals"], "nilable": True,
     "summary": "Secret when present, nil when nothing is incoming [[d:INV]] [[v:SV-RUN2]].", "pattern": "pat-healthbar"},
    {"id": "cast.info", "title": "Spell cast name / info", "apis": ["UnitCastingInfo", "UnitChannelInfo"],
     "expect": _by_unit({"player": ("C", "your (and your pet's) casts are not secret")}, ("S", "not you or your pet (SecretWhenUnitSpellCastRestricted)")),
     "observe": ["UnitCastingInfo"], "nilable": True,
     "summary": "Secret for anyone but you and your pet, in every context: the predicate is unit-based, not combat-based [[d:INV]]; your own casts are not secret [[o:B-251104]]. isTradeskill / isEmpowered / castBarID are NeverSecret [[d:INV]]. Instant secret casts no longer fire UNIT_SPELLCAST_SUCCEEDED for other units [[o:B-260410]].", "pattern": "pat-castbar"},
    {"id": "cast.timeLeft", "title": "Cast time left", "apis": ["UnitCastingDuration", "UnitCastingInfo"],
     "expect": _by_unit({"player": ("X", "duration object; tagged SecretReturns although your casts are non-secret: check HasSecretValues")}, ("X", "duration object with secret contents")),
     "observe": ["UnitCastingDuration"], "container": True,
     "summary": "Use <code>UnitCastingDuration(unit)</code>, a duration object for a StatusBar or text binding, instead of <code>endTimeMs/1000 - GetTime()</code> (endTimeMs is secret for other units) [[d:INV]] [[o:B-260528]].", "pattern": "pat-castbar"},
    {"id": "channel.timeLeft", "title": "Channel time left", "apis": ["UnitChannelDuration", "UnitEmpoweredChannelDuration", "UnitChannelInfo"],
     "expect": _by_unit({"player": ("X", "duration object (your channel)")}, ("X", "duration object; UnitChannelDuration has no secrecy tag")),
     "observe": [], "container": True,
     "summary": "UnitChannelDuration returns a duration object and has no secrecy tag in the 70245 docs [[d:INV]]; treat its contents like cast info and check <code>HasSecretValues()</code> [[i:]] [[p:]].", "pattern": "pat-castbar"},
    {"id": "movement.speed", "title": "Movement speed", "apis": ["GetUnitSpeed"],
     "expect": _by_ctx({"ooc": ("C", "stats not restricted"), "combat": ("S", "ShouldUnitStatsBeSecret() true in combat"), "restricted": ("S", "stats restricted")}),
     "observe": ["GetUnitSpeed"],
     "summary": "SecretWhenUnitStatsRestricted [[d:INV]]: clear out of combat, secret in combat, for you and your target [[v:SV-RUN2]]; <code>C_Secrets.ShouldUnitStatsBeSecret()</code> flipped false to true with combat [[v:SV-RUN2]].", "pattern": "pat-neighbour"},
    {"id": "unit.name", "title": "Player and unit names (UnitName, UnitGUID, UnitClass)", "apis": ["UnitName", "UnitNameUnmodified", "UnitGUID", "UnitClass"],
     "expect": _grid(_identity), "observe": ["UnitName"],
     "summary": "Identity is secret on instanced maps for anything that isn't you, your pet/vehicle or a group member [[o:B-260410]]; UnitName stays readable for players in PvP (SecretWhenUnitNameIdentityRestricted) [[d:INV]]. Open world: clear for you and your target in The Barrens [[v:SV-RUN2]]. Display with <code>fs:SetText(UnitName(unit))</code> either way.", "pattern": "pat-name"},
    {"id": "aura.buffs", "title": "Buffs (yours and others')", "apis": ["C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetAuraDataByAuraInstanceID", "C_UnitAuras.GetUnitAuras"],
     "expect": AURA_EXPECT, "observe": [],
     "summary": "SecretWhenUnitAuraRestricted + RequiresUnitAuraAccess (FailureMode Error) [[d:INV]]. Since 12.1.0 index/slot/instance APIs raise a Lua error while auras are secret, UNIT_AURA payloads and AuraData are fully secret; spell-ID/name lookups still work for never-secret spells [[o:B-260630]]. <code>ShouldAurasBeSecret()</code> flipped false to true with combat [[v:SV-RUN2]]; community: 'Auras cannot be accessed when secret while tainted' in combat [[c:C-KIT]].", "pattern": "pat-aura"},
    {"id": "aura.debuffs", "title": "Debuffs (yours and others')", "apis": ["C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetDebuffDataByIndex", "C_UnitAuras.GetUnitAuraInstanceIDs"],
     "expect": AURA_EXPECT, "observe": [],
     "summary": "Same rules as buffs [[d:INV]] [[o:B-260630]]. Most encounter debuffs are additionally Private Auras [[o:B-260312]].", "pattern": "pat-aura"},
    {"id": "aura.dispel", "title": "Dispels (dispelName / debuff type)", "apis": ["C_UnitAuras.GetAuraDispelTypeColor"],
     "expect": _by_ctx({"ooc": ("C", "auras readable"), "combat": ("S", "colour is secret, sink-only"), "restricted": ("S", "same")}),
     "observe": [],
     "summary": "Documented path: <code>C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, colorCurve)</code> 'remaps it to a color via a curve, with the dispel type ID used as the x value' [[d:DOCS]]; Blizzard's CustomAuraButton uses it [[d:DOCS]]. AuraButton borders accept colour curves/maps [[o:B-260721]]; filters DISPELLABLE and RAID_PLAYER_DISPELLABLE exist [[o:B-260714]]. dispelName lives in AuraData, fully secret while auras are secret [[o:B-260630]].", "pattern": "pat-dispel"},
    {"id": "threat", "title": "Threat", "apis": ["UnitThreatSituation", "UnitDetailedThreatSituation"],
     "expect": _grid(_threat), "observe": ["UnitThreatSituation"],
     "summary": "Depends on the token pair: single-token queries or player/pet/ally vs target/nameplate are 'generally not secret' [[d:INV]]; some pairs became secret to stop unit comparison [[o:B-260219]]. One secret sample in combat, otherwise clear [[v:SV-RUN2]].", "pattern": "pat-neighbour"},
    {"id": "range", "title": "Range", "apis": ["UnitInRange", "C_Spell.IsSpellInRange", "UnitDistanceSquared", "CheckInteractDistance"],
     "expect": _all("S", "UnitInRange: SecretReturns (other range APIs untagged)"), "observe": ["UnitInRange"],
     "summary": "<code>UnitInRange</code> is SecretReturns and was secret in every sample, including you, out of combat [[d:INV]] [[v:SV-RUN2]], contradicting 'range checks are not secret' [[c:C-KIT]]. <code>C_Spell.IsSpellInRange</code>, <code>UnitDistanceSquared</code>, <code>CheckInteractDistance</code> carry no secrecy tag [[d:INV]] [[p:]]. UNIT_IN_RANGE_UPDATE / UNIT_DISTANCE_CHECK_UPDATE are SecretPayloads [[d:INV]].", "pattern": "pat-neighbour"},
    {"id": "raidMarker", "title": "Raid markers", "apis": ["GetRaidTargetIndex"],
     "expect": _all("S", "SecretReturns (nil when no marker)"), "observe": ["GetRaidTargetIndex"], "nilable": True,
     "summary": "SecretReturns [[d:INV]]; nil when unmarked. All 19 samples in the user's run were unmarked [[v:SV-RUN2]], so the marked case is [[p:]]. Setting markers works through secure actions; 12.0.7 added <code>set-unmarked</code> and <code>/tm ~4</code> [[o:B-260528]].", "pattern": "pat-name"},
    {"id": "damageMeter", "title": "Damage meter (C_DamageMeter)", "apis": ["C_DamageMeter.GetCombatSessionFromType", "C_DamageMeter.GetCombatSessionSourceFromType", "C_DamageMeter.GetCombatSessionFromID"],
     "unitless": True,
     "expect": {ANY: {"ooc": ("C", "SecretWhenInCombat"), "combat": ("S", "SecretWhenInCombat"), "restricted": ("S?", "secret while in combat; sourceGUID secret when identity is secret")}},
     "observe": ["C_DamageMeter.GetCombatSessionFromType"],
     "summary": "SecretWhenInCombat [[d:INV]]: read totals after combat. Clear out of combat in 110 samples [[v:SV-RUN2]]; <code>sourceGUID</code> secret when identity is secret [[o:B-260916]]. The sanctioned replacement for CLEU meters [[o:B-250603]] [[i:]].", "pattern": "pat-damagemeter"},
]

COMBAT_PATTERNS = [
    ("pat-castbar", "Cast bar: duration objects instead of endTime - GetTime()",
     """-- BEFORE (pre-12): maths on cast times
local name, _, tex, startMs, endMs = UnitCastingInfo(unit)
if name then
  bar:SetMinMaxValues(0, (endMs - startMs) / 1000)        -- error: secret for non-player units
  bar:SetValue(GetTime() - startMs / 1000)
  timeText:SetFormattedText("%.1f", endMs / 1000 - GetTime())
  nameText:SetText(name)
end""",
     """-- AFTER (12.x / Forever): let the engine animate a duration object
local function UpdateCast(unit)
  local d = UnitCastingDuration(unit)                        -- LuaDurationObject, may return nothing
  local dir = Enum.StatusBarTimerDirection.ElapsedTime
  if not d then
    d = UnitChannelDuration(unit)                            -- channels count down
    dir = Enum.StatusBarTimerDirection.RemainingTime
  end
  if not d then bar:Hide() return end
  bar:SetTimerDuration(d, Enum.StatusBarInterpolation.Immediate, dir)
  binding:SetDuration(d)                                     -- DurationTextBinding writes the countdown
  nameText:SetText(UnitCastingInfo(unit) or UnitChannelInfo(unit))  -- may be secret: display only
  bar:Show()
end
-- one-time setup (Blizzard's 12.0.7 example)
binding = C_DurationUtil.CreateDurationTextBinding()
local fmt = C_StringUtil.CreateSecondsFormatter()
fmt:SetMillisecondsThreshold(5)
binding:SetFontString(timeText); binding:SetFormatter(fmt); binding:SetEnabled(true)""",
     "Docs: StatusBar:SetTimerDuration(duration, interpolation, direction); Enum.StatusBarTimerDirection ElapsedTime / RemainingTime; UnitCastingDuration / UnitChannelDuration return LuaDurationObject [[d:DOCS]]. DurationTextBinding example [[o:B-260528]]. SetTimerDuration's SecretArguments is AllowedWhenUntainted, but a duration object is not itself a secret value; whether one holding secrets is accepted from addon code is [[p:]]."),
    ("pat-healthbar", "Health bar: StatusBar passthrough",
     """-- BEFORE
local hp, maxHp = UnitHealth(unit), UnitHealthMax(unit)
bar:SetMinMaxValues(0, maxHp); bar:SetValue(hp)
text:SetText(math.floor(hp / maxHp * 100) .. "%")            -- error: arithmetic on a secret
if hp / maxHp < 0.35 then bar:SetStatusBarColor(1, 0, 0) end -- error: comparison""",
     """-- AFTER: pass values through; curves do the maths
bar:SetMinMaxValues(0, UnitHealthMax(unit))                   -- may be secret for NPCs: still allowed
bar:SetValue(UnitHealth(unit))                                -- SetValue: AllowedWhenTainted
text:SetFormattedText("%d%%", UnitHealthPercent(unit, true, pctCurve))
local c = UnitHealthPercent(unit, true, colorCurve)           -- secret colour
bar:SetStatusBarColor(c:GetRGBA())                            -- [pending lab] GetRGBA on a secret colour
-- setup
pctCurve = C_CurveUtil.CreateCurve(); pctCurve:AddPoint(0, 0); pctCurve:AddPoint(1, 100)
colorCurve = C_CurveUtil.CreateColorCurve()
colorCurve:AddPoint(0, CreateColor(1, 0, 0, 1)); colorCurve:AddPoint(1, CreateColor(0, 1, 0, 1))""",
     "SetMinMaxValues / SetValue / SetStatusBarColor / SetFormattedText accept tainted secrets [[d:DOCS]]; UnitHealthPercent(unit, usePredicted, curve) [[d:DOCS]]. Lab items 'statusbar', 'healthpercent-curve', 'colorcurve' confirm on Forever [[p:]]."),
    ("pat-aura", "Aura tracking: auraInstanceID + UNIT_AURA updateInfo while readable; AuraContainer when secret",
     """-- BEFORE: full rescan by index on every UNIT_AURA
for i = 1, 40 do
  local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")  -- 12.1+: Lua error while auras are secret
  if not a then break end
  if a.spellId == TRACKED and a.expirationTime - GetTime() < 3 then Alert() end
end""",
     """-- AFTER (a) while readable: incremental cache keyed by auraInstanceID
local cache = {}
f:RegisterUnitEvent("UNIT_AURA", "player")
f:SetScript("OnEvent", function(_, _, unit, info)
  if C_Secrets.ShouldAurasBeSecret() then return end          -- secret now: (b) does the display
  if not info or info.isFullUpdate then
    wipe(cache)
    for _, id in ipairs(C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HELPFUL")) do
      cache[id] = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
    end
    return
  end
  for _, a in ipairs(info.addedAuras or {}) do cache[a.auraInstanceID] = a end
  for _, id in ipairs(info.updatedAuraInstanceIDs or {}) do
    cache[id] = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
  end
  for _, id in ipairs(info.removedAuraInstanceIDs or {}) do cache[id] = nil end
end)
-- AFTER (b) in combat: an AuraContainer tracks, filters and lays out auras
local c = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
c:SetPoint("CENTER"); c:SetUnit("player")
c:AddAuraGroup("mine", "HELPFUL|PLAYER", { maxFrameCount = 8 })""",
     "UnitAuraUpdateInfo fields isFullUpdate / addedAuras / updatedAuraInstanceIDs / removedAuraInstanceIDs and GetUnitAuraInstanceIDs(unit, filter) [[d:DOCS]]; AuraContainer + AddAuraGroup(groupKey, filterString, options) [[o:B-260618,B-260707]] [[d:DOCS]]. Aura instance IDs re-randomise on entering an encounter/M+/PvP match [[o:B-260331]]; while auras are secret the index/instance APIs error and the payload is fully secret [[o:B-260630]]. ShouldAurasBeSecret() was false out of combat and true in combat [[v:SV-RUN2]]. <code>CustomAuraContainerTemplate</code>, <code>AuraContainer:SetUnit</code> and <code>AddAuraGroup(groupKey, filterString, options)</code> (options: maxFrameCount, sortMethod, layout, candidateFilters...) exist in the Forever UI source [[d:DOCS]]; behaviour on 70245 [[p:]]."),
    ("pat-dispel", "Dispel highlighting: the documented dispel colour curve",
     """-- BEFORE
local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
if a and a.dispelName == "Magic" and canDispelMagic then border:SetVertexColor(0.2, 0.6, 1) end""",
     """-- AFTER: map the (secret) dispel type to a colour on the engine side
local dispelCurve = C_CurveUtil.CreateColorCurve()
-- x = dispel type ID; the IDs are not listed in the 70245 generated docs: confirm with /fdump lab
dispelCurve:AddPoint(DISPEL_MAGIC_ID,   CreateColor(0.2, 0.6, 1.0, 1))
dispelCurve:AddPoint(DISPEL_CURSE_ID,   CreateColor(0.6, 0.0, 1.0, 1))
dispelCurve:AddPoint(DISPEL_DISEASE_ID, CreateColor(0.6, 0.4, 0.0, 1))
dispelCurve:AddPoint(DISPEL_POISON_ID,  CreateColor(0.0, 0.6, 0.0, 1))
local function PaintDispel(unit, auraInstanceID, border)
  local color = C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, dispelCurve)
  border:SetVertexColor(color:GetRGBA())     -- SetVertexColor accepts tainted secrets
end
-- Or let AuraButtons draw it: SetAuraBorder with a colour curve/map (12.1.0), AddDispelTypeTexture (12.1.5);
-- filter with "HARMFUL|RAID_PLAYER_DISPELLABLE" or "HARMFUL|DISPELLABLE" in an AuraContainer group.""",
     "GetAuraDispelTypeColor(auraInstanceUnit, auraInstanceID, LuaColorCurveObject) [[d:DOCS]]; Blizzard_CustomAuraButton.lua uses it with options.customDispelColorCurve [[d:DOCS]]; borders with colour curves/maps [[o:B-260721]]; AddDispelTypeTexture [[o:B-260903]]; DISPELLABLE filter [[o:B-260714]]. Getting an auraInstanceID in combat needs an AuraContainer context because index APIs error [[o:B-260630]] [[i:]]. Dispel type IDs and GetRGBA on a secret colour are [[p:]]."),
    ("pat-name", "Name display: SetText, never compare",
     """-- BEFORE
local name = UnitName(unit)
if name == MY_FRIEND then frame.Name:SetTextColor(0, 1, 0) end   -- secret on instanced maps: error
frame.Name:SetText(name:sub(1, 12))                               -- string parsing of a secret""",
     """-- AFTER
frame.Name:SetText(UnitName(unit))           -- SetText accepts secrets; truncate with the FontString
frame.Name:SetWidth(90); frame.Name:SetWordWrap(false)
if not C_Secrets.ShouldUnitIdentityBeSecret(unit) then
  if UnitName(unit) == MY_FRIEND then frame.Name:SetTextColor(0, 1, 0) end  -- readable now
end
-- raid marker icon: SetRaidTargetIconTexture(tex, GetRaidTargetIndex(unit))   [pending lab]""",
     "FontString:SetText is AllowedWhenTainted and adds the Text aspect [[d:DOCS]]; ShouldUnitIdentityBeSecret(unit) [[d:DOCS]]; identity secret on instanced maps [[o:B-260410]]; secret strings ignore width/precision truncation [[o:B-260312]]."),
    ("pat-damagemeter", "Damage meter: C_DamageMeter after combat, not CLEU",
     """-- BEFORE: sum CLEU amounts per source
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")   -- Forever: restricted for addons""",
     """-- AFTER: read Blizzard's meter session when combat ends
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function()
  C_Timer.After(0, function()
    local ok, s = pcall(C_DamageMeter.GetCombatSessionFromType, SESSION_TYPE, METER_TYPE)
    if ok and s and not issecretvalue(s.totalAmount) then
      Render(s.combatSources, s.totalAmount, s.durationSeconds)
    end
  end)
end)""",
     "GetCombatSessionFromType is SecretWhenInCombat and returns DamageMeterCombatSession {combatSources, maxAmount, totalAmount, durationSeconds} [[d:INV]]; clear out of combat [[v:SV-RUN2]]. ForeverDump v2.2.6 deep-reads every type/source/spell/detail post-combat (raw GUIDs and names since v2.2.21), tapes every DAMAGE_METER_* in capture, and self-reconciles liveEst vs meter vs CLEU offline [[c:FD]]."),
    ("pat-neighbour", "Non-secret neighbours (speed, threat, range, state)",
     """-- BEFORE
if GetUnitSpeed("player") == 0 then StartCastHelper() end      -- secret in combat
if UnitInRange("party1") then ... end                            -- SecretReturns""",
     """-- AFTER: pick untagged / NeverSecret values, or events
if not IsPlayerMoving() then ... end                             -- untagged in 70245 docs [pending lab]
local inRange = C_Spell.IsSpellInRange(SPELL_ID, "party1")      -- untagged [pending lab]
local dead = UnitIsDeadOrGhost("party1")                         -- untagged
local status = UnitThreatSituation("player", "target")          -- player vs target: 'generally not secret'
if issecretvalue(status) then status = nil end                   -- never branch on a secret""",
     "Tags from the inventory [[d:INV]]; threat predicate text [[d:DOCS]]. Anything marked [[p:]] needs the lab run first."),
]

# ---------------------------------------------------------------------------- UNIT TOKENS
TOKEN_ANSWER = [
    ("(a) Do tokens still resolve?",
     "Yes. Tokens are plain strings you pass in; <code>UnitExists</code> has no secrecy tag and takes the generic UnitToken type [[d:INV]]. Blizzard's changes are about which tokens an API <i>accepts</i>, not tokens ceasing to resolve [[o:B-260121,B-260325]]. Secure attributes and macro conditionals (<code>/cast [@party1]</code>) run in Blizzard's secure environment, which secrets don't restrict [[o:B-251001]] [[i:]] [[p:|no in-game macro test yet]]. Nameplate tokens can't be targeted by spells or commands (long-standing) [[d:W-TOKEN]]."),
    ("(b) Are UnitExists / UnitIsUnit / UnitGUID / UnitName secret?",
     "No secrecy tag: <code>UnitExists</code>, <code>UnitIsPlayer</code>, <code>UnitCanAttack</code>, <code>UnitIsEnemy</code>, <code>UnitReaction</code>, <code>UnitIsDeadOrGhost</code>, <code>UnitLevel</code>, <code>UnitClassification</code>, <code>UnitPlayerControlled</code> [[d:INV]]. SecretWhenUnitIdentityRestricted: <code>UnitGUID</code>, <code>UnitNameUnmodified</code>, <code>UnitClass</code>, <code>UnitCreatureID</code>, <code>UnitInRaid</code>, <code>UnitIsGroupLeader</code>, <code>UnitTokenFromGUID</code>; <code>UnitName</code> uses SecretWhenUnitNameIdentityRestricted (players readable in PvP) [[d:INV]]. 12.1.0 made more unit APIs secret when identity is secret (UnitClass, UnitRace, UnitSex, UnitGroupRolesAssigned, UnitIsPVP...) [[o:B-260721]]. Identity is secret on instanced maps for anything that isn't you, your pet/vehicle or a raid/party member [[o:B-260410]]; check <code>C_Secrets.ShouldUnitIdentityBeSecret(unit)</code> [[d:DOCS]]. <code>UnitIsUnit</code> is SecretWhenUnitComparisonRestricted + RequiresComparableUnitTokens: disallowed pairs return nil; call <code>C_Secrets.CanCompareUnitTokens(u1, u2)</code> first [[d:DOCS]] [[o:B-260331]]. Open world: UnitGUID/UnitName/UnitClass clear for you and your target [[v:SV-RUN2]]."),
    ("(c) Compound 'target of' tokens",
     "Restricted in several ways: identity is checked along the whole chain, so <code>UnitName('boss1target')</code> fails if boss1 is secret [[o:B-251111]]; UnitIsUnit with a compound token, a nameplate token, or targettarget/focustarget against party/raid is disallowed (nil) [[o:B-260331]]; aura/nameplate APIs (UnitTokenRestrictedForAddOns) refuse compound tokens and names except <code>targettarget</code> [[o:B-260121]]; GetNamePlateForUnit refuses compound tokens [[o:B-260112]]; UnitTokenNamePlate APIs refuse party/raid/targettarget [[o:B-260325]]; GetGuildInfo refuses compound tokens [[o:B-260721]]; UnitTokenFromGUID won't return target-of-target tokens when identity is secret [[o:B-260325]]. The comparison predicate says it 'only applies when the player is on an addon-restricted map' [[d:INV]], which the 12.0.5 UnitIsUnit rules don't repeat: open-world behaviour [[p:]]."),
    ("(d) Arena tokens in PvP",
     "In an active PvP match 'various APIs no longer accept compound unit tokens or unit names' [[o:B-260219]]. Health/power/cast/GUID APIs take <code>UnitTokenPvPRestrictedForAddOns</code> and since 12.0.7 return nil/default instead of erroring on unsupported tokens [[d:DOCS]] [[o:B-260430]]. <code>GetArenaOpponentSpec</code> returns secrets (12.1.5) and UnitFrameUtil offers secret-safe spec/role display helpers [[o:B-260922]]. UnitName stays readable for players in PvP [[d:INV]]; arena GUIDs follow the instanced-map identity rule [[o:B-260410]] [[p:]]. UnitTokenFromGUID won't return arena tokens when identity is secret [[o:B-260325]]."),
    ("(e) Token vs value",
     "Secrecy attaches to the <b>values returned for the unit</b> (health, name, GUID, cast info...), not to the token you pass [[o:B-251001]] [[d:INV]]. Exceptions: (1) some APIs <i>refuse</i> certain token kinds (ReturnNothing / nil), see (c) and (d); (2) a token string can itself be secret if it came from a secret source (e.g. UnitTokenFromGUID under identity restriction), and <code>UnitName</code> no longer accepts secret unit tokens [[o:B-260331]]; (3) castbar IDs are unique per token (case-sensitive) so they can't be used to compare units [[o:B-260903]]. Events deliver lowercase tokens [[o:B-260903]]; UNIT_AURA's unitTarget was observed clear in combat [[v:SV-RUN2]]."),
]
# family, resolves?, identity secret when?, values secret when?, macro/secure OK?, confidence
TOKEN_TABLE = [
    ("player, pet, vehicle", "Yes", "Never [[o:B-260410]]", "Health / percent / absorbs / UnitInRange always (SecretReturns) [[v:SV-RUN2]]; max health/power plain [[o:B-251104]]; own casts plain [[o:B-251104]]; stats/speed in combat [[v:SV-RUN2]]", "Yes [[i:]]", "[[v:SV-RUN2]] [[o:B-260410]]"),
    ("target, focus, mouseover", "Yes", "If not you / your group: on instanced maps [[o:B-260410]]; open world clear [[v:SV-RUN2]]", "Per value: health always; max health if NPC; casts unless you/pet; auras, cooldowns, stats when restricted [[d:INV]]", "Yes [[i:]]", "[[d:INV]] [[o:B-260410]]"),
    ("softenemy, softfriend, softinteract", "Yes", "As target [[o:B-260410]]; PLAYER_SOFT_INTERACT_CHANGED payload SecretWhenUnitIdentityRestricted [[d:INV]]", "As target [[d:INV]]", "Yes; UnitIsUnit comparisons with them permitted [[o:B-260331]]", "[[o:B-260331]] [[d:INV]]"),
    ("party1-4, partypet1-4, raid1-40, raidpet1-40", "Yes", "Never for group members [[o:B-260410]]", "Health always; max health plain for players [[d:INV]]; casts secret (not you) [[d:INV]]; auras when restricted [[d:INV]]", "Yes, e.g. /cast [@party1] [[i:]] [[p:]]", "[[o:B-260410]] [[d:INV]]"),
    ("arena1-5", "Yes (in arenas)", "Instanced-map rule [[o:B-260410]]; UnitName readable for players in PvP [[d:INV]]", "PvP-restricted-token APIs may return nil/default [[o:B-260430]]; GetArenaOpponentSpec secret [[o:B-260922]]", "Yes [[i:]] [[p:]]", "[[o:B-260219,B-260430,B-260922]]"),
    ("boss1-8", "Yes (in encounters)", "Secret (NPC on an instanced map) [[o:B-260410]]", "Health always; max health secret (NPC) [[d:INV]]; ENCOUNTER_END reports creatureID / name / remaining % as non-secrets [[o:B-260430]]", "Yes [[i:]]", "[[o:B-260410,B-260430]] [[d:INV]]"),
    ("nameplate1-40", "Yes (not targetable)", "Instanced-map rule for non-group units [[o:B-260410]]", "As the underlying unit [[d:INV]]; UnitTokenNamePlate APIs refuse party/raid/targettarget [[o:B-260325]]", "No targeting by spells/commands [[d:W-TOKEN]]", "[[d:W-TOKEN]] [[o:B-260325]]"),
    ("npc, questnpc", "Yes (while interacting)", "NPC rule; 'npc' not secret during an active item interaction [[o:B-260528]]", "Per value [[d:INV]]", "n/a", "[[o:B-260528]]"),
    ("Compound: targettarget, focustarget, raidNtarget, party1target, arena1target, boss1target...", "Yes", "Secret if any unit in the chain is secret [[o:B-251111]] [[d:INV]]", "Per value; refused by aura/nameplate APIs (targettarget exempt) [[o:B-260121]]; refused in PvP matches [[o:B-260219]]; UnitIsUnit nil [[o:B-260331]]", "[[p:]]", "[[o:B-251111,B-260121,B-260219,B-260331]]"),
    ("Player names as tokens ('Name', 'Name-target')", "Yes (group members only) [[d:W-TOKEN]]", "Group members declassified [[o:B-260410]]", "Refused by aura/nameplate APIs [[o:B-260121]] and in PvP matches [[o:B-260219]]", "[[p:]]", "[[o:B-260121,B-260219]]"),
]
TOKEN_TYPES_NOTE = "Argument types in the 70245 docs [[d:DOCS]]: generic <code>UnitToken</code> (277 uses); <code>UnitTokenPvPRestrictedForAddOns</code> (28 uses: C_TooltipInfo.GetUnit, GetComboPoints, UnitCastingDuration, UnitCastingInfo, UnitChannelDuration, UnitChannelInfo, UnitGUID, UnitGetDetailedHealPrediction, UnitGetIncomingHeals, UnitGetTotalAbsorbs, UnitGetTotalHealAbsorbs, UnitHasPowerType, UnitHealth, UnitHealthMax, UnitHealthMissing, UnitHealthPercent, UnitOwnerGUID, UnitPartialPower, UnitPower, UnitPowerMax, UnitPowerMissing, UnitPowerPercent, UnitPowerType, UnitPvpClassification, UnitStagger); <code>UnitTokenRestrictedForAddOns</code> (20 uses: C_UnitAuras.* and C_TooltipInfo aura getters); <code>UnitTokenNamePlate</code> (C_NamePlate.GetNamePlateForUnit, C_NamePlateManager.IsNamePlateUnitBehindCamera / SetNamePlateSimplified)."

# ---------------------------------------------------------------------------- TOOLTIPS / SPELL TEXT (research ask)
TOOLTIP_FINDINGS = [
    "<b>C_Spell.GetSpellDescription</b> has no secrecy tag (only MayReturnNothing) [[d:INV]]. In the user's run it returned <b>clear text with numbers in combat</b>, e.g. Fireball 'causes 16 to 25 Fire damage and an additional 2 Fire damage over 4 sec.' [[v:SV-RUN2]]. The very first out-of-combat probe returned nothing for every spell (description data not cached yet), later probes returned text: treat 'nothing' as 'not loaded', not 'secret' [[v:SV-RUN2]] [[i:]].",
    "<b>C_TooltipInfo.GetSpellByID</b> has no secrecy tag [[d:INV]], but in combat the tooltip gains a cooldown line (line type 0) whose <code>leftText</code> and <code>leftColor</code> are secret, and <code>hasDynamicData</code> is secret, for <b>every</b> probed spell (8 spells, including ones with no cooldown running). The spell name, cost/range, cast time and the SpellDescription line (type 34) stayed clear in combat [[v:SV-RUN2]]. Out of combat the same slot read 'Cooldown remaining: 16 min' for Hearthstone [[v:SV-RUN2]]. So: description numbers clear in open-world combat; cooldown text secret; the line is always present, so its presence says nothing [[i:]].",
    "<b>Unit tooltips</b> (C_TooltipInfo.GetUnit, AllowedWhenUntainted args) showed name/level/type and a UnitThreat line ('100% Threat') clear in open-world combat [[v:SV-RUN2]]. Aura tooltips (GetUnitAura*) are SecretWhenUnitAuraRestricted + RequiresUnitAuraAccess and error from addons while auras are secret [[d:INV]] [[o:B-260630]].",
    "Blizzard fixed tooltip lines staying secret permanently and tooltips wrongly turning secret when textures were added [[o:B-260325,B-260331]]: older reports of 'all-secret tooltips' may be bugs [[i:]].",
    "<b>Restricted contexts (Encounter / M+ / PvP / instanced Map)</b> were not covered by the run: description and tooltip secrecy there is [[p:|Knowledge.lua re-checks in 'enc' context]]. Parsing numbers from <i>clear</i> description text out of combat and caching them is fine; never parse secret text (it errors, and it is the kind of laundering Blizzard closes) [[o:B-260219]] [[i:]].",
]

# ---------------------------------------------------------------------------- DETECTING STATE
# id, signal, unit label, apis/tags, {ctx: (code, note)}
DETECT = [
    ("det.cast.self", "Casting? + which spell", "player / pet",
     "UnitCastingInfo, UNIT_SPELLCAST_* (SecretWhenUnitSpellCastRestricted)",
     {"ooc": ("C", "your casts aren't secret [[o:B-251104]]"), "combat": ("C", "events + spellID clear in combat [[v:SV-RUN2]]"), "restricted": ("C?", "same rule; not captured [[p:]]")}),
    ("det.cast.other", "Casting? (yes/no)", "target / party / nameplate",
     "UNIT_SPELLCAST_START/STOP timing; UnitCastingInfo non-nil test; castBarID NeverSecret",
     {"ooc": ("C", "event arrival + nil test are non-secret [[o:B-251104]] [[d:INV]]"), "combat": ("C?", "no NPC casts in the run [[p:]]"), "restricted": ("C?", "[[p:]]")}),
    ("det.cast.otherSpell", "Which spell / time left", "target / party / nameplate",
     "UnitCastingInfo name/spellID/endTimeMs; UnitCastingDuration",
     {"ooc": ("S", "unit-based predicate: not you [[d:INV]]"), "combat": ("S", "[[d:INV]]"), "restricted": ("S", "[[d:INV]]; display via duration object")}),
    ("det.aura.present.self", "Has aura X?", "player",
     "GetPlayerAuraBySpellID (RequiresNonSecretAura), GetAuraSlots, UNIT_AURA",
     {"ooc": ("C", "auras readable ooc [[v:SV-RUN2]]"), "combat": ("S/E", "ShouldAurasBeSecret true; payload fields secret [[v:SV-RUN2]]; only never-secret spells answer [[o:B-260630]]"), "restricted": ("S/E", "[[o:B-260630]]")}),
    ("det.aura.present.other", "Has aura X?", "target / party / nameplate",
     "same APIs + RequiresUnitAuraAccess",
     {"ooc": ("C", "[[d:INV]]"), "combat": ("S/E", "payload secret for target/nameplate/softenemy [[v:SV-RUN2]]"), "restricted": ("S/E", "[[o:B-260630]]")}),
    ("det.aura.change", "Did auras change? (added / removed / updated)", "any unit",
     "UNIT_AURA arrival; which updateInfo keys are present",
     {"ooc": ("C", "full payload clear [[v:SV-RUN2]]"), "combat": ("C*", "event + unit clear; key presence visible, values secret [[v:SV-RUN2]]"), "restricted": ("C*?", "[[p:]]")}),
    ("det.aura.stacks", "Stack count", "any unit",
     "AuraData.applications; GetAuraApplicationDisplayCount (secret string)",
     {"ooc": ("C", "[[d:INV]]"), "combat": ("S", "display via AuraButton / SetText [[d:INV]]"), "restricted": ("S", "[[d:INV]]")}),
    ("det.aura.duration", "Duration / time left", "any unit",
     "AuraData.expirationTime; GetAuraDuration (duration object); DoesAuraHaveExpirationTime",
     {"ooc": ("C", "[[d:INV]]"), "combat": ("X", "duration object for widgets; numbers secret [[d:INV]]"), "restricted": ("X", "[[d:INV]]")}),
    ("det.aura.dispellable", "Dispellable by me?", "party / raid",
     "dispelName (AuraData); RAID_PLAYER_DISPELLABLE filter; GetAuraDispelTypeColor",
     {"ooc": ("C", "[[d:INV]]"), "combat": ("S", "colour/filter in widgets only [[o:B-260714]]"), "restricted": ("S", "[[o:B-260714]]")}),
    ("det.aura.mine", "Applied by me?", "any unit",
     "isFromPlayerOrPlayerPet (AuraData); PLAYER filter in AuraContainer",
     {"ooc": ("C", "[[d:INV]]"), "combat": ("S", "AuraData fully secret in 12.1+ [[o:B-260630]]; filter works in containers"), "restricted": ("S", "[[o:B-260630]]")}),
    ("det.combat", "In combat?", "player / unit",
     "UnitAffectingCombat, PLAYER_REGEN_*, ADDON_RESTRICTION_STATE_CHANGED",
     {"ooc": ("C", "untagged [[d:INV]]"), "combat": ("C", "restriction flips observed [[v:SV-RUN2]]"), "restricted": ("C", "[[d:DOCS]]")}),
    ("det.move", "Moving?", "player",
     "IsPlayerMoving, PLAYER_STARTED/STOPPED_MOVING (untagged) vs GetUnitSpeed",
     {"ooc": ("C", "[[d:INV]]"), "combat": ("C", "26 PLAYER_STARTED_MOVING events recorded in the run [[v:SV-RUN2]]; GetUnitSpeed secret"), "restricted": ("C?", "[[p:]]")}),
]
DETECT_CODES = {
    "C": "clear", "C?": "probably clear (pending)", "C*": "clear, partial", "C*?": "partial, pending",
    "S": "secret", "S/E": "secret or Lua error", "E": "Lua error", "X": "container (check HasSecretValues)",
    "P": "pending lab", "N": "nil / nothing",
}

INFERENCE = [
    {"id": "inf-own-aura", "title": "Your own buff from your own cast",
     "signals": "UNIT_SPELLCAST_SUCCEEDED (player, spellID clear) + UNIT_AURA arrival on the target within a short window + duration learned out of combat",
     "sketch": """-- learn out of combat (clear values only)
KNOW[spellID] = { duration = aura.duration }            -- from AuraData while readable
-- in combat
local lastCast
function OnSpellcastSucceeded(unit, castGUID, spellID)
  if unit == "player" and not issecretvalue(spellID) then lastCast = { id = spellID, t = GetTime() } end
end
function OnUnitAura(unit, info)
  if lastCast and GetTime() - lastCast.t < 0.6 and info and info.addedAuras ~= nil then  -- presence only
    local k = KNOW[lastCast.id]
    if k then Predict(unit, lastCast.id, GetTime() + k.duration, "inferred") end
  end
end""",
     "pre": "Own casts not secret [[o:B-251104]] [[v:SV-RUN2]]; duration cached while readable; haste/talents unchanged since learning.",
     "fail": "Refreshes/pandemic, procs that extend, another player's identical buff, early dispel/cancel, a different aura landing in the same window.",
     "acc": "High for fixed-duration self buffs; medium on others [[i:]].",
     "note": "Use a 0.4-0.8 s window [[i:]]; show the result yellow ('inferred') and let the real AuraButton/duration object stay the source of truth."},
    {"id": "inf-cd", "title": "Your cooldown end from cast time + known cooldown",
     "signals": "UNIT_SPELLCAST_SUCCEEDED (player) + base cooldown learned out of combat; GetSpellCooldown isActive / isOnGCD are NeverSecret",
     "sketch": """local cd = C_Spell.GetSpellCooldown(id)          -- table is clear; startTime/duration secret in combat
if cd and cd.isActive and not cd.isOnGCD then     -- NeverSecret fields: OK to branch on
  local base = KNOW_CD[id]                         -- learned ooc: GetSpellBaseCooldown / clear duration
  if base and lastCastAt[id] then
    ShowPredicted(id, lastCastAt[id] + base)       -- yellow; Cooldown frame shows the real one:
  end
end
cdFrame:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(id))""",
     "pre": "isActive/isEnabled/isOnGCD clear in combat (24 samples) while startTime/duration/modRate were secret [[v:SV-RUN2]] [[d:INV]].",
     "fail": "Cooldown resets/reductions (procs, talents, haste-scaled CDs), charges, modRate changes.",
     "acc": "High for static cooldowns; low for spells with resets [[i:]].",
     "note": "isActive tells you whether it is ready, which is usually what logic needs; the time left only needs display."},
    {"id": "inf-cast-other", "title": "Enemy is casting (yes/no) and roughly how long",
     "signals": "UNIT_SPELLCAST_START/STOP/INTERRUPTED/CHANNEL_* arrival on target/focus/nameplate; UnitCastingInfo(unit) ~= nil",
     "sketch": """f:RegisterUnitEvent("UNIT_SPELLCAST_START", "target", "focus")
f:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "target", "focus")
f:SetScript("OnEvent", function(_, ev, unit)
  if ev == "UNIT_SPELLCAST_START" then casting[unit] = GetTime()   -- arrival time is yours
  else casting[unit] = nil end
  castBar:SetTimerDuration(UnitCastingDuration(unit))             -- real progress via the engine
end)""",
     "pre": "Events still fire for other units; payload fields (spellID, maybe unitTarget) secret [[d:INV]]. Instant secret casts no longer fire SUCCEEDED for others [[o:B-260410]].",
     "fail": "No spell identity; with secret unitTarget you rely on RegisterUnitEvent's unit filter [[p:]].",
     "acc": "High for 'is casting', none for 'which spell' [[i:]].",
     "note": "Enough for a 'casting!' highlight. Choosing an interrupt by spell is what Blizzard intends to stop [[o:B-251113]]."},
    {"id": "inf-combat-phase", "title": "Combat / encounter phase from restriction events",
     "signals": "ADDON_RESTRICTION_STATE_CHANGED (Activating/Inactive) + next-frame GetAddOnRestrictionState; ENCOUNTER_START/END",
     "sketch": """f:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
f:SetScript("OnEvent", function(_, _, rtype, state)
  state = state                                       -- 0 Inactive (after), 1 Activating (before)
  C_Timer.After(0, function()                          -- 'Active' (2) is never sent: poll next frame
    phase[rtype] = C_RestrictedActions.GetAddOnRestrictionState(rtype)
  end)
end)""",
     "pre": "Documented event semantics [[d:DOCS]]; observed 9 Combat toggles with Activating/Inactive only [[v:SV-RUN2]].",
     "fail": "Missed edges after /reload: re-poll all six types on PLAYER_ENTERING_WORLD [[i:]].",
     "acc": "Exact [[d:DOCS]].",
     "note": "Switch your addon between 'readable' and 'display-only' modes on these edges."},
    {"id": "inf-aura-count", "title": "How many of my buffs are on a unit (count only)",
     "signals": "Number of auras an AuraContainer group shows / UNIT_AURA added-vs-removed key presence",
     "sketch": """-- Prefer letting the container lay out the icons. If you only need 'some debuff of mine is up',
-- watch UNIT_AURA arrival and re-ask at combat end.
local hadChange = info and (info.addedAuras ~= nil or info.removedAuraInstanceIDs ~= nil)  -- presence""",
     "pre": "Key presence in updateInfo was visible in combat while values were secret [[v:SV-RUN2]].",
     "fail": "Blizzard may make the payload table itself secret; key presence is not a documented contract [[i:]].",
     "acc": "Low-medium [[i:]].",
     "note": "Treat as a hint only. Do not combine with timing to reverse-engineer which spell it was (side channel, below)."},
]
SIDE_CHANNELS = [
    "Reading values back from widgets you fed secrets to (StatusBar:GetValue, FontString width/GetText, texture coordinates): GetValue returns a secret and laundering via bars was fixed [[o:B-260219]].",
    "Measuring rendered text width/height or string precision tricks to recover digits: precision specifiers ignored for secret strings [[o:B-260312,B-260321]].",
    "Castbar ID comparisons to identify units: castBarIDs are now unique per token [[o:B-260903]].",
    "Minimap/arrow rotation, pixel sampling, screen-reading external tools: outside the API, case-by-case closures [[c:WH-MINIMAP]].",
    "Parsing the WoWCombatLog file live from an external app to feed an addon: the addon can't read files; external automation risks ToS [[i:]].",
    "Timing-correlating secret events across units to recover identities or spell IDs Blizzard hides on purpose [[o:B-260410]] [[i:]].",
]

# ---------------------------------------------------------------------------- HSM
HSM_INTRO = "A <b>hybrid state machine</b> keeps two layers per unit: <span class='hsm g'>observed</span> facts from readable inputs and <span class='hsm y'>inferred</span> predictions from rules over those inputs and knowledge cached while things were readable. Anything else is <span class='hsm k'>unknown</span>. When later readable evidence disagrees with a prediction, it records a <span class='hsm r'>contradiction</span> and the rule loses confidence. ForeverDump v2.2 ships one (Lib/HybridState.lua, Inference.lua, Knowledge.lua) plus a live window [[c:FD]]."
HSM_WINDOW = [
    "<b>Open it:</b> <code>/fdump hsm</code> toggles the window. Turning the <b>FD_Logs</b> capture ON opens it automatically (setting <code>hsm.autoShow</code>, default true) and OFF closes it. If no capture is running the window says 'HSM not running'; <code>/fdump hsm start</code> starts the HSM without a capture [[c:FD]].",
    "<b>Window:</b> a plain insecure frame (no secure templates, no hooks on Blizzard frames); drag to move, corner grip to resize, Escape closes; position/size saved in <code>ForeverDumpDB.hsmUI</code>; refreshed every 0.2 s (<code>hsm.updateInterval</code>) only while shown [[c:FD]].",
    "<b>Colours:</b> <span class='hsm g'>green = observed</span> (read from a non-secret value or event), <span class='hsm y'>yellow = inferred</span> (rule output; the rule and confidence are printed next to it), <span class='hsm k'>grey = unknown / cached / unverified</span>, <span class='hsm r'>red = contradiction</span>. The restriction line reuses the palette: green Inactive, yellow Activating, red Active [[c:FD]].",
    "<b>Engine passthrough rows:</b> secret values are shown <b>only</b> through sanctioned widgets so you can compare by eye: 'player/target cast (secret, engine)' bars driven by <code>StatusBar:SetTimerDuration(UnitCastingDuration(unit))</code> (or UnitChannelDuration), 'player/target HP (secret, engine)' bars via <code>SetMinMaxValues(0, UnitHealthMax)</code> + <code>SetValue(UnitHealth)</code>, a 'real cooldown' Cooldown frame via <code>SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(id))</code>, and an HP FontString via <code>SetText</code>. The addon never reads these back (no GetValue/GetText) [[c:FD]] [[d:DOCS]].",
    "<b>Text body:</b> restriction states for all six types plus the always-on flags (combat log, addon chat); counters (predictions, inferences, contradictions, unreadable inputs, casts, aura events); player/target cast state; known/predicted auras per unit (source, rule, confidence, stacks, remaining); cooldown predictions; the last 8 predictions with outcome (green verified, red contradicted, grey unverified); the last 4 contradictions with how early and which rule [[c:FD]].",
]
HSM_VERIFY = [
    ("Pair the bars", "Each yellow 'pred' bar sits above its white engine bar. Cast a spell with a known cast time: both should fill together and end together. A yellow bar that ends early or late shows the error of your cast-time knowledge (haste, pushback)."),
    ("Watch a cooldown", "Cast a spell with a static cooldown, then compare 'cooldown (pred)' with the real Cooldown swipe on the right. They should finish within a GCD. Persistent drift = wrong base cooldown or a modRate you didn't learn."),
    ("Check aura rows", "Buff yourself in combat. The aura should appear yellow (inferred via the cast-aura window rule) and turn green after combat when the readable data confirms it. A red line means it vanished more than the tolerance (1.5 s) before the predicted end."),
    ("Read the counters", "After a fight: contradictions should be near 0; 'unreadable inputs' tells you how much the HSM had to guess. A high number with zero predictions means the rules lacked knowledge: run <code>/fdump</code> out of combat first so Knowledge.lua caches durations."),
    ("Score offline", "Turn FD_Logs OFF (saves via /reload). The converter step (tools/fdump.py, HSM scoring in progress) replays every logged prediction against the WoWCombatLog file and writes the <code>--hsm</code> JSON this guide renders under Verified vs pending. Until then every rule shows as pending."),
    ("Repeat per context", "Do a dummy (Combat only), a dungeon (Map + Encounter) and, if possible, a battleground (PvPMatch): readability of rule inputs is logged per context, so the same prediction can be verified in one and pending in another."),
]
HSM_STATES = [
    ("unknown", "k", "No readable input yet, or knowledge missing."),
    ("observed", "g", "Read directly: player casts, ooc aura data, NeverSecret fields, event arrival."),
    ("inferred", "y", "Rule fired (cast-aura window, cooldown = cast + base CD); carries rule id + confidence (low/medium/high)."),
    ("verified", "g", "A later readable source agreed (post-combat aura data, combat-log replay)."),
    ("contradicted", "r", "Evidence disagreed beyond tolerance; rule confidence drops."),
    ("expired", "k", "Predicted end passed or unit lost; entry pruned on Tick()."),
]
HSM_FAILURES = [
    "Knowledge gaps: a spell never seen readable has no duration/cooldown, so nothing is predicted (grey) [[c:FD]].",
    "Haste, talents, set bonuses or procs changing durations after the knowledge was cached [[i:]].",
    "auraInstanceIDs re-randomise when an encounter / M+ / PvP match starts, so instance-keyed state is invalid across that edge [[o:B-260331]].",
    "Key = GUID only while UnitGUID is readable; on instanced maps it falls back to the token, which can point to a new unit (target swaps) [[o:B-260410]] [[c:FD]].",
    "Other players' identical buffs land in the same correlation window (false positives) [[i:]].",
    "Event payload changes in later builds (e.g. updateInfo becoming fully secret) silently remove inputs: watch 'unreadable inputs' [[i:]].",
    "/reload mid-combat loses in-memory state; restriction states must be re-polled [[i:]].",
    "Passthrough widgets: SetTimerDuration is AllowedWhenUntainted for secret args [[d:DOCS]]; if it rejects a secret-holding duration object from addon code the engine bar stays empty (the window catches the error and shows 0) [[c:FD]] [[p:]].",
]
HSM_SKELETON = """-- Minimal HSM skeleton (readable inputs only). Full version: ForeverDump/Lib/HybridState.lua
local HSM = { units = {}, know = {}, preds = {}, window = 0.6, tolerance = 1.5 }
local f = CreateFrame("Frame")

local function key(unit)                                    -- GUID while readable, else token
  local g = UnitGUID(unit)
  if g ~= nil and not issecretvalue(g) then return g end
  return unit
end

function HSM:Learn(id)                                      -- call out of combat
  if C_Secrets.ShouldAurasBeSecret() then return end
  local a = C_UnitAuras.GetPlayerAuraBySpellID(id)
  if a and not issecretvalue(a.duration) then self.know[id] = { duration = a.duration } end
end

function HSM:OnCast(unit, id)
  if unit ~= "player" or issecretvalue(id) then return end  -- observed
  self.last = { id = id, t = GetTime() }
end

function HSM:OnAura(unit, info)
  local u = self.units[key(unit)] or {}; self.units[key(unit)] = u
  if not C_Secrets.ShouldAurasBeSecret() and info and not info.isFullUpdate then
    for _, a in ipairs(info.addedAuras or {}) do               -- readable: observed
      u[a.auraInstanceID] = { spell = a.spellId, ends = a.expirationTime, state = "observed" }
    end
    return
  end
  local L = self.last                                           -- secret: infer
  if L and GetTime() - L.t <= self.window and self.know[L.id] then
    local p = { unit = key(unit), spell = L.id, ends = GetTime() + self.know[L.id].duration,
                state = "inferred", rule = "cast-aura-window" }
    table.insert(self.preds, p)
  end
end

function HSM:Verify(unit, id, endedAt)                         -- later readable evidence
  for _, p in ipairs(self.preds) do
    if p.unit == key(unit) and p.spell == id and p.state == "inferred" then
      p.state = (p.ends - endedAt > self.tolerance) and "contradicted" or "verified"
    end
  end
end

f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterUnitEvent("UNIT_AURA", "player", "target")
f:SetScript("OnEvent", function(_, ev, unit, a2, a3)
  if ev == "UNIT_SPELLCAST_SUCCEEDED" then HSM:OnCast(unit, a3) else HSM:OnAura(unit, a2) end
end)"""

# ---------------------------------------------------------------------------- PORTING PATTERNS (general)
PATTERNS = [
    ("pat-guard", "Guard every read with issecretvalue",
     """local v = UnitHealthMax(unit)
if issecretvalue(v) then
  bar:SetMinMaxValues(0, v)            -- display path
else
  maxCache[unit] = v                   -- logic path: plain number
end
-- tables: issecretvalue(t) is false for containers
local cd = C_Spell.GetSpellCooldown(id)
if cd and not issecretvalue(cd.duration) then ... end
-- duration objects / widgets
if dur and dur:HasSecretValues() then ... end""",
     "issecretvalue / HasSecretValues / hasanysecretvalues / canaccesstable [[d:DOCS]]; GetSpellCooldown table clear, fields secret [[v:SV-RUN2]]."),
    ("pat-modes", "Two modes: readable vs display-only",
     """local function Readable() return not C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat) end
-- better: ask the specific predicate you depend on
local function CooldownsReadable() return not C_Secrets.ShouldCooldownsBeSecret() end
local function AurasReadable() return not C_Secrets.ShouldAurasBeSecret() end
local function StatsReadable() return not C_Secrets.ShouldUnitStatsBeSecret() end""",
     "C_Secrets.Should*BeSecret predicates and IsAddOnRestrictionActive [[d:DOCS]]; ShouldAurasBeSecret / ShouldUnitStatsBeSecret flipped with combat [[v:SV-RUN2]]. UnitHealth ignores all of these (SecretReturns) [[v:USER-TEST]]."),
    ("pat-cooldown", "Cooldown frames from duration objects",
     """-- BEFORE
local s, d = GetSpellCooldown(id); cd:SetCooldown(s, d)
-- AFTER
cd:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(id))
local info = C_Spell.GetSpellCooldown(id)
icon:SetDesaturated(info and info.isActive and not info.isOnGCD)   -- NeverSecret fields""",
     "SetCooldown with secrets refused for tainted code; isActive added [[o:B-260321]]; NeverSecret fields [[d:INV]] [[v:SV-RUN2]]."),
    ("pat-sv", "SavedVariables: store classifications, not values",
     """-- BEFORE
MyDB.lastHP = UnitHealth("player")             -- becomes nil + comment
-- AFTER
local v = UnitHealth("player")
MyDB.hpWasSecret = issecretvalue(v)          -- booleans/strings you computed are fine""",
     "SV serialises secrets as nil + comment [[o:B-251111]]."),
    ("pat-pcall", "Call refusing APIs safely",
     """local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HELPFUL")
if not ok then  -- 12.1+: errors while auras are secret
  -- fall back to AuraContainer display
end
if C_Secrets.CanCompareUnitTokens("target", "party1") then
  same = UnitIsUnit("target", "party1")       -- otherwise nil
end""",
     "Lua error while auras secret [[o:B-260630]]; CanCompareUnitTokens [[d:DOCS]] [[o:B-260331]]."),
    ("pat-taint", "Avoid tainting Blizzard code",
     """-- BEFORE: writing Blizzard tables / calling legacy money helpers from tainted paths
SetTooltipMoney(GameTooltip, cost)               -- taints MoneyFrame maths -> 'blocked because of taint from YourAddon'
-- AFTER
GameTooltip_AddMoneyLine(GameTooltip, cost)
-- and: hooksecurefunc instead of replacing Blizzard functions; never assign into Blizzard mixins/globals""",
     "Taint example from the user's run (TweaksForever) [[v:SV-RUN2]]; GameTooltip_AddMoneyLine [[o:B-260430]]; Decursive case [[c:C-DECURSIVE]]."),
    ("pat-detect", "Feature-detect the client",
     """local HAS_SECRETS = C_Secrets ~= nil and issecretvalue ~= nil
local IS_FOREVER = WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or -1)   -- name will change before launch
if not issecretvalue then issecretvalue = function() return false end end  -- older clients""",
     "WOW_PROJECT_ID 18 = CAMELOT on 70245 [[v:SV-RUN2]]; rename announced [[o:WH-FOREVER]]."),
]
PITFALLS = [
    "Testing <code>if x then</code> on a value you think is secret: it is a nil test and passes; the error only appears later when you compare or add [[o:B-251104]].",
    "<code>issecretvalue(tbl)</code> is false for struct tables and duration objects; check the fields or <code>HasSecretValues()</code> [[d:DOCS]] [[v:SV-RUN2]].",
    "Treating 'nil' as 'clear': UnitGetIncomingHeals, UnitCastingInfo and GetRaidTargetIndex return nil when there is nothing, so a nil sample proves nothing about secrecy [[v:SV-RUN2]] [[d:RESEARCH]].",
    "Waiting for ADDON_RESTRICTION_STATE_CHANGED with state 2: it is never sent; poll on the next frame [[d:DOCS]] [[v:SV-RUN2]].",
    "Copying retail whitelists (Hearthstone, raid buffs) to Forever: 70245 reported them ContextuallySecret [[v:SV-RUN2]].",
    "<code>tostring(secret)</code> looks like it works (prints fine) but the string is secret; <code>tonumber</code> of it is nil [[v:USER-TEST]].",
    "Hard-coding <code>WOW_PROJECT_ID == 1</code> from Forever beta notes [[c:C-KIT]] vs 18 on 70245 [[v:SV-RUN2]].",
    "Registering COMBAT_LOG_EVENT_UNFILTERED: restricted (HasRestrictions) [[d:INV]]; project notes report an ADDON_ACTION_FORBIDDEN popup [[c:FD]] [[p:]].",
    "Assuming the error names the real culprit: taint errors blame the addon that tainted the path, which may be a library or a different addon [[c:C-DECURSIVE]].",
]
CHECKLIST = [
    ("Inventory", "List every API/event your addon calls; join it with the inventory TSV (SecretReturns / SecretWhen* / NeverSecret / Requires*) [[d:INV]]."),
    ("Classify", "For each value: display-only, logic-needed-ooc, logic-needed-in-combat. The last group needs a non-secret neighbour, an engine helper, or removal [[i:]]."),
    ("Guard", "Add issecretvalue / HasSecretValues checks before any arithmetic, comparison, table key, #, string parsing [[d:DOCS]]."),
    ("Widgets", "Move displays to passthrough: StatusBar SetValue, FontString SetText, SetTimerDuration, SetCooldownFromDurationObject, curves, AuraContainer [[d:DOCS]] [[o:B-260618]]."),
    ("Events", "Re-check every event payload (UNIT_AURA, UNIT_SPELLCAST_*, threat, range) for SecretPayloads / SecretWhen* [[d:INV]]."),
    ("Tokens", "Replace compound tokens and names in aura/nameplate calls; gate UnitIsUnit with CanCompareUnitTokens [[o:B-260121,B-260331]]."),
    ("Taint", "Remove writes into Blizzard tables/globals; use hooksecurefunc; switch to GameTooltip_AddMoneyLine [[o:B-260430]]; turn on /console taintLog 1 while testing [[d:RESEARCH]]."),
    ("SavedVariables", "Never save secrets; save classifications [[o:B-251111]]."),
    ("Combat log", "Drop CLEU parsing; use C_DamageMeter, UNIT_* events, or post-combat summaries [[d:INV]] [[o:B-250603]]."),
    ("Detect", "Feature-detect C_Secrets / issecretvalue / WOW_PROJECT_CAMELOT instead of project-ID literals [[v:SV-RUN2]] [[o:WH-FOREVER]]."),
    ("Test", "Test out of combat, in combat (dummy), in a dungeon (Map + Encounter), in PvP; capture with ForeverDump FD_Logs and compare against the docs [[c:FD]]."),
    ("Ship", "Mark features that can't survive (combat automation) as removed; explain why in the changelog with Blizzard's intent quote [[o:B-251113]]."),
]
DIAG = [
    ("Is it secret right now?", "<code>/dump issecretvalue(X)</code>; for tables <code>/dump hasanysecretvalues(t)</code>; for duration objects <code>/dump d:HasSecretValues()</code> [[d:DOCS]]."),
    ("Which restriction is on?", "<code>/dump C_RestrictedActions.GetAddOnRestrictionState(0)</code> (0..5) and <code>C_Secrets.ShouldAurasBeSecret()</code> / <code>ShouldCooldownsBeSecret()</code> / <code>ShouldUnitStatsBeSecret()</code> [[d:DOCS]]."),
    ("Why did Blizzard code error?", "<code>/console taintLog 1</code> (or 2), reproduce, read <code>Logs/taint.log</code>: lines 'Execution tainted by X' + 'blocked because of taint from X' [[v:SV-RUN2]]."),
    ("Forced restrictions for testing", "CVars <code>addon*RestrictionsForced</code> (renamed in 12.0.5) force a restriction type on so you can test without a boss [[o:B-260410]] [[d:RESEARCH]]."),
    ("See the payloads", "<code>/etrace</code> (Event Trace) shows secret payloads to you as a player [[d:RESEARCH]]."),
    ("Capture everything", "ForeverDump: <code>/fdump logs macro</code>, click FD_Logs ON, play, click OFF (reload); run the converter (verify, restrictions, taint log, client log, combat log) [[c:FD]]."),
    ("Watch predictions live", "<code>/fdump hsm</code> (see <a href='#hsm'>HSM</a>) [[c:FD]]."),
]

# ---------------------------------------------------------------------------- FLOWCHARTS (rendered to inline SVG by build_guide.py)
# nodes: id -> (col, row, text, kind) kind: start | q | ok | bad | act ; edges: (from, to, label)
FLOW_SECRET = {
    "title": "Can my addon use this value?",
    "nodes": {
        "a": (1, 0, "Value from an API / event", "start"),
        "b": (1, 1, "issecretvalue(v)? (or HasSecretValues)", "q"),
        "c": (0, 2, "Use it normally", "ok"),
        "d": (2, 2, "Only need to show it?", "q"),
        "e": (1, 3, "Pass to widget: SetText / SetValue / SetTimerDuration / Cooldown", "ok"),
        "f": (2, 3, "NeverSecret neighbour or engine helper?", "q"),
        "g": (2, 4, "Use isActive / curves / duration object / AuraContainer", "ok"),
        "h": (1, 4, "Readable after combat?", "q"),
        "i": (0, 5, "Defer: cache on PLAYER_REGEN_ENABLED", "act"),
        "j": (2, 5, "Drop the feature (intended restriction)", "bad"),
    },
    "edges": [("a", "b", ""), ("b", "c", "no"), ("b", "d", "yes"), ("d", "e", "yes"), ("d", "f", "no, logic"),
              ("f", "g", "yes"), ("f", "h", "no"), ("h", "i", "yes"), ("h", "j", "no")],
}
FLOW_RESTRICT = {
    "title": "Restriction state lifecycle (per type)",
    "nodes": {
        "a": (0, 0, "Inactive (0)", "ok"),
        "b": (1, 0, "event (type, 1) Activating: fires BEFORE", "act"),
        "c": (2, 0, "Active (2): NO event, poll next frame", "bad"),
        "d": (1, 1, "event (type, 0): fires AFTER deactivation", "act"),
        "e": (0, 1, "IsAddOnRestrictionActive false during dispatch", "q"),
    },
    "edges": [("a", "b", "enter combat"), ("b", "c", "next frame"), ("c", "d", "leave"), ("d", "a", ""), ("b", "e", "")],
}
FLOW_INFER = {
    "title": "Inference: may I reason about this?",
    "nodes": {
        "a": (1, 0, "I want state X during combat", "start"),
        "b": (1, 1, "Is X itself readable now?", "q"),
        "c": (0, 2, "Observed: use it (green)", "ok"),
        "d": (2, 2, "Non-secret inputs (own casts, event arrival, NeverSecret, ooc cache)?", "q"),
        "e": (1, 3, "Rule over those inputs: inferred (yellow) + confidence", "ok"),
        "f": (2, 3, "Needs widget readback / pixel / timing tricks?", "q"),
        "g": (2, 4, "Side channel: don't (will be closed)", "bad"),
        "h": (1, 4, "Unknown (grey): display via widget only", "act"),
        "i": (0, 4, "Verify later: ooc data / combat log replay", "act"),
    },
    "edges": [("a", "b", ""), ("b", "c", "yes"), ("b", "d", "no"), ("d", "e", "yes"), ("d", "f", "no"),
              ("f", "g", "yes"), ("f", "h", "no"), ("e", "i", "")],
}
FLOW_HSM = {
    "title": "HSM architecture (ForeverDump v2.2)",
    "nodes": {
        "a": (0, 0, "Readable inputs: UNIT_SPELLCAST_*, UNIT_AURA, counts, restriction state", "start"),
        "b": (0, 1, "Knowledge.lua: spell durations / CDs cached out of combat", "start"),
        "c": (1, 0, "Inference.lua: logs signals + per-context readability", "act"),
        "d": (1, 1, "HybridState lib: units, casts, cooldowns, predictions", "act"),
        "e": (2, 0, "HSM window (/fdump hsm): yellow pred bars vs white engine bars", "ok"),
        "f": (2, 1, "ForeverDumpLogDB.inference (SavedVariables)", "q"),
        "g": (3, 1, "Converter replays vs WoWCombatLog: --hsm JSON", "ok"),
        "h": (3, 0, "Engine passthrough: SetTimerDuration, SetValue, Cooldown duration object", "q"),
    },
    "edges": [("a", "c", ""), ("b", "d", ""), ("c", "d", ""), ("d", "e", ""), ("d", "f", ""), ("f", "g", "FD_Logs OFF"), ("h", "e", "secrets")],
}


# v2.2.2 partial secrets (run 3, Forever 70245, shaman, solo: no party/raid/pet observed)
PARTIAL_AURA_NOTE = (
    "Observed on Forever 70245 (run 3): **out of combat** every aura field is clear for the player and for yourself via other "
    "tokens (auraInstanceID, isFromPlayerOrPlayerPet, sourceUnit, applications, expirationTime, duration, dispelName, spellId, "
    "name, icon), and counts are clear (`GetAuraSlots` slot lists, `GetUnitAuras` lists). Hostile NPCs had no auras out of combat, "
    "so their fields are unobserved. **In combat** there is no partial-secret aura table for addon code: `GetAuraDataByIndex`, "
    "`GetAuraSlots` and `GetUnitAuras` raise *Auras cannot be accessed when secret while tainted by 'ForeverDump'* for every unit "
    "class (player, self via target/focus, target NPC, nameplates), so neither the identity fields nor a count are available from "
    "the API. What remains is the **UNIT_AURA payload**: a readable container (`T`) whose `isFullUpdate` is secret and whose "
    "`addedAuras` / `removedAuraInstanceIDs` / `updatedAuraInstanceIDs` are each either **nil or a wholly secret list**. The "
    "nil-vs-secret distinction is a clear yes/no ('something was added / removed / updated on this unit'), but not a count or an "
    "identity. Party/raid and pet were not observed (solo shaman).")


# ---------------------------------------------------------------------------- v2.2.4: tracker, learned data, drift rule
DRIFT_RULE = ("<b>Standing design rule: every value is a starting point.</b> Any learned or static value (GCD per spell, base "
              "cooldowns, cast durations, NPC kits, the token secrecy matrix, the knowledge DB) is <i>keyed by build</i>, "
              "<i>re-verified live</i> whenever a readable signal allows, <i>decayed</i> when it is not re-confirmed, and "
              "<i>drift-flagged</i> with a changelog entry when live evidence disagrees. Nothing is hard-coded without an override "
              "path: the shipped seed (<code>Data/spell-timing.lua</code>, <code>Data/learned-seed.lua</code>) loses to the live "
              "learned value, and a confirmed conflict is proposed as a seed update by <code>fdump.py analyze</code> "
              "(<code>--write-seed</code> applies it; merges are idempotent per evidence id) [[c:FD]].")
DRIFT_STEPS = [
    ("Key by build", "learned tables are stored under the client build; a build or patch change is detected automatically, logged, and every seed value is treated as unverified until re-observed (Drift.lua)."),
    ("Re-verify live", "each value records the evidence that last confirmed it (cast pair, fail reason, clear API read) and when."),
    ("Decay", "agree/disagree evidence decays (older evidence fades); values from another build or older than 30/90 days lose confidence and are shown as inferred, never as fact."),
    ("Flag drift", "a live reading that contradicts a confident value writes a changelog entry (old, new, evidence, build) and an analyze lead."),
    ("Propose", "<code>fdump.py analyze</code> merges captures into <code>spell-timing.proposed.json</code> / <code>learned-seed.proposed.json</code>; <code>--write-seed</code> writes the Lua seeds."),
    ("Override", "a flagged item uses the observed value at runtime (<code>Drift.Value</code>) while the seed stays untouched; seeds are data files (<code>Data/*.lua</code>), regenerated by <code>--write-seed</code>, never constants in code."),
]
CDTRACK_INTRO = ("HybridState MINOR 5 tracks each of my spells as <span class='hsm g'>ready</span>, <span class='hsm y'>gcd</span> or "
                 "<span class='hsm y'>cooling</span> from clear signals only: my own <code>UNIT_SPELLCAST_SUCCEEDED</code> (spell id clear for the "
                 "player), the base cooldown and category from the knowledge DB (cached out of combat), the per-spell GCD from the timing seed, "
                 "and a <code>UNIT_SPELLCAST_FAILED</code> of a spell the tracker holds as cooling as a confirmation. Where "
                 "<code>C_Spell.GetSpellCooldown</code> is readable it is the truth; in combat on 70245 its result was secret in run 5, so the tracker "
                 "carries the state. The display shows the tracker value as inferred (yellow) and the engine widget stays the source of truth [[v:SV-RUN5]].")
CDTRACK_POINTS = [
    "O(1) per event: a dense active list with swap-remove, a lazy min-heap of end times, and a 2 s due set; idle spells cost nothing.",
    "Round-robin re-reads at most once per second per far-off spell, with a budget of 4 reads per update and no OnUpdate when nothing is active.",
    "Shared cooldowns (same category, e.g. the shocks) are scheduled together; the latest cast is tracked by pointer for the HSM step line.",
    "The HSM window caps cooldown lines at 8 and shows '+N more tracked'; redraws happen only when a line changes (dirty-only).",
    "Known answers check the GCD table on every capture: totems 1.0 s, Lightning Shield 1.5 s. A mismatch is a high-severity analyze lead.",
]
LEARNED_POINTS = [
    "<b>Learned DB</b> (Learned.lua + Data/learned-seed.lua): spell cast times, GCDs, cooldowns and NPC kits (npc id to spell ids, cast durations) "
    "learned from clear signals, keyed by build, seeded from earlier runs. Player names and GUIDs are stored raw where they are "
    "captured (v2.2.21: nothing is anonymised).",
    "<b>Group-aware token scanner</b> (Tokens.lua): scans party/raid/nameplate tokens in budgeted slices (0.12 ms per 0.1 s slice, soft "
    "deadline per field, resumable) and records only secrecy codes per token family and context. Alias and duplicate detection keeps a "
    "40-player raid inside the budget. <code>fdump.py analyze</code> renders the matrix and change alerts as TOKENS.md.",
    "<b>Ledger</b> (HybridState): clear facts cached while readable (token to GUID, aura instance, cast GUID) with LRU caps and "
    "fresh/stale/maybe-removed confidence. 'maybe-removed' is a doubt, never a claim.",
    "<b>Knowledge checklist</b> (Knowledge.lua): base cooldown, cast time, range, every power cost and tooltip header parse, linted against "
    "the APIs and cross-checked against the combat log offline (fdump knowlint).",
    "<b>Verification loop</b> (verify ring): live verdicts (V verified / C contradicted / U unverifiable) for cooldowns, cast ends, damage "
    "ranges, interrupts and DM totals, joined with the combat log offline (VERIFY.md) and turned into a knowledge patch for the next build.",
]
CDLINE_INTRO = ("<b>Hypothesis:</b> in combat the spell tooltip gains an extra line while the spell is on cooldown, so the line "
                "<i>count</i> (never the text) could signal a cooldown when the cooldown API is secret. Rule: the signal stays "
                "<b>disabled unless proven</b>: at least 10 known-answer samples per phase, 100% agreement with the log, at least 2 "
                "sample times. Only line counts and line types are recorded; no secret text is parsed [[i:]].")
