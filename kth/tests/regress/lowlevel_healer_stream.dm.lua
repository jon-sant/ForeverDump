-- forever.7 R12 fixture (SYNTHETIC unit-test input, not a capture): meter rows for lowlevel_healer_stream.lua.
return {
 meta = { run = "regress-lowlevel-healer", synthetic = true, n = 1 },
 snaps = {
  { g = 108.0, inCombat = false, byType = {
    HealingDone = { durationSeconds = 40, combatSources = {
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "PRIEST", sourceDisplayType = 2, totalAmount = 1450, isLocalPlayer = false },
      { name = "Ally Friend", sourceGUID = "Player-1-0000AAAA", classFilename = "MAGE", sourceDisplayType = 1, totalAmount = 60, isLocalPlayer = false },
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "WARRIOR", sourceDisplayType = 2, totalAmount = 90, isLocalPlayer = false } } },
    DamageDone = { durationSeconds = 40, combatSources = {
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "WARRIOR", sourceDisplayType = 2, totalAmount = 1900, isLocalPlayer = false },
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "PRIEST", sourceDisplayType = 2, totalAmount = 120, isLocalPlayer = false },
      { name = "Ally Friend", sourceGUID = "Player-1-0000AAAA", classFilename = "MAGE", sourceDisplayType = 1, totalAmount = 1300, isLocalPlayer = false } } } } },
 },
}
