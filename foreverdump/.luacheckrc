-- luacheck config for the ForeverDump addon (WoW Forever, Lua 5.1)
std = "lua51"
max_line_length = 160
exclude_files = { "ref/**", "tests/out/**", "tools/**" }
files["ForeverDump/Data/**"] = { max_line_length = false }   -- generated data tables (spell timing seed, knowledge patch)
files["tests/**"] = { std = "+max", globals = { "_G" }, allow_defined_top = true, ignore = { "111", "112", "113", "131", "121", "122", "142", "143", "212", "213", "311", "542", "631" } }
globals = {
    "ForeverDumpDB", "ForeverDumpStaticDB", "ForeverDumpDocsDB", "ForeverDumpStringsDB", "ForeverDumpRecordDB", "ForeverDumpLogDB", "ForeverDumpCombatLogDB",
    "SLASH_FOREVERDUMP1", "SLASH_FOREVERDUMP2",
    SlashCmdList = { other_fields = true },
    UISpecialFrames = { other_fields = true },
}
read_globals = {
    "C_AddOns", "C_CVar", "C_EventUtils", "C_Timer", "C_XMLUtil", "C_TooltipInfo", "C_UnitAuras",
    "C_Item", "C_Spell", "C_Map", "C_Secrets",
    "CreateFrame", "CreateFont", "UIParent", "DEFAULT_CHAT_FRAME", "GameFontHighlightSmall",
    "GetBuildInfo", "GetTime", "InCombatLockdown", "issecurevariable", "issecretvalue", "issecrettable",
    "canaccessvalue", "hooksecurefunc", "debugprofilestop", "EnumerateFrames", "ConsoleGetAllCommands",
    "GetCVarInfo", "GetCVar", "GetCVarDefault", "UnitExists", "UnitName", "UnitIsPlayer", "GetRealmName",
    "CombatLogGetCurrentEventInfo", "Enum", "Constants", "wipe", "date", "time",
}
