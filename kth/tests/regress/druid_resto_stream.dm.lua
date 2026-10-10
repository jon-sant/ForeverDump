-- forever.5 R9 control fixture (SYNTHETIC unit-test input, not a capture): meter rows for druid_resto_stream.lua.
return {
 meta = { run = "regress-druid-resto", synthetic = true, n = 1 },
 snaps = {
  { g = 106.0, inCombat = false, byType = {
    HealingDone = { durationSeconds = 40, combatSources = {
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "DRUID", sourceDisplayType = 2, totalAmount = 2944, isLocalPlayer = false },
      { name = "Ally Friend", sourceGUID = "Player-1-0000AAAA", classFilename = "MAGE", sourceDisplayType = 1, totalAmount = 120, isLocalPlayer = false },
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "WARRIOR", sourceDisplayType = 2, totalAmount = 300, isLocalPlayer = false } } },
    DamageDone = { durationSeconds = 40, combatSources = {
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "WARRIOR", sourceDisplayType = 2, totalAmount = 4100, isLocalPlayer = false },
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "DRUID", sourceDisplayType = 2, totalAmount = 208, isLocalPlayer = false },
      { name = "Ally Friend", sourceGUID = "Player-1-0000AAAA", classFilename = "MAGE", sourceDisplayType = 1, totalAmount = 2500, isLocalPlayer = false } } } } },
 },
}
