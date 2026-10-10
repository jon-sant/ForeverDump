-- forever.5 R9 fixture (SYNTHETIC unit-test input, not a capture): meter rows for druid_mana_dps_stream.lua. Both enemy
-- druids: damage only, a little self-healing (as DPS druids show in the real meter rows, e.g. run 18: 329 and 543).
return {
 meta = { run = "regress-druid-mana-dps", synthetic = true, n = 2 },
 snaps = {
  { g = 106.0, inCombat = false, byType = {
    HealingDone = { durationSeconds = 40, combatSources = {
      { name = "Ally Friend", sourceGUID = "Player-1-0000AAAA", classFilename = "MAGE", sourceDisplayType = 1, totalAmount = 120, isLocalPlayer = false },
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "DRUID", sourceDisplayType = 0, totalAmount = 543, isLocalPlayer = false },
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "DRUID", sourceDisplayType = 0, totalAmount = 329, isLocalPlayer = false } } },
    DamageDone = { durationSeconds = 40, combatSources = {
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "DRUID", sourceDisplayType = 0, totalAmount = 4100, isLocalPlayer = false },
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "DRUID", sourceDisplayType = 2, totalAmount = 3600, isLocalPlayer = false },
      { name = "Ally Friend", sourceGUID = "Player-1-0000AAAA", classFilename = "MAGE", sourceDisplayType = 1, totalAmount = 2500, isLocalPlayer = false } } } } },
  { g = 113.0, inCombat = false, byType = {
    HealingDone = { durationSeconds = 47, combatSources = {
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "DRUID", sourceDisplayType = 0, totalAmount = 700, isLocalPlayer = false },
      { name = "Ally Friend", sourceGUID = "Player-1-0000AAAA", classFilename = "MAGE", sourceDisplayType = 1, totalAmount = 120, isLocalPlayer = false } } },
    DamageDone = { durationSeconds = 47, combatSources = {
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "DRUID", sourceDisplayType = 0, totalAmount = 6000, isLocalPlayer = false },
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "DRUID", sourceDisplayType = 2, totalAmount = 5200, isLocalPlayer = false } } } } },
 },
}
