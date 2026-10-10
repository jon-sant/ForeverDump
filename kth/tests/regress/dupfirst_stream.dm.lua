-- forever.5 regression fixture (SYNTHETIC unit-test input, not a capture): the meter rows for dupfirst_stream.lua.
-- Shapes follow the measured FD rows (enemy name/GUID "<secret>", class clear, amounts clear out of combat). Expected:
-- the only enemy PRIEST heals far above the group (meter vote) -> "Johnny Snowden" marked by exact name+surname join;
-- the WARRIOR "Johnny Morningwind" never.
return {
 meta = { run = "regress-dupfirst", synthetic = true, n = 1 },
 snaps = {
  { g = 102.0, inCombat = false, byType = {
    HealingDone = { durationSeconds = 30, combatSources = {
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "PRIEST", sourceDisplayType = 2, totalAmount = 4000, isLocalPlayer = false },
      { name = "Ally Friend", sourceGUID = "Player-1-0000AAAA", classFilename = "MAGE", sourceDisplayType = 1, totalAmount = 200, isLocalPlayer = false },
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "WARRIOR", sourceDisplayType = 2, totalAmount = 150, isLocalPlayer = false } } },
    DamageDone = { durationSeconds = 30, combatSources = {
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "WARRIOR", sourceDisplayType = 2, totalAmount = 5000, isLocalPlayer = false },
      { name = "Ally Friend", sourceGUID = "Player-1-0000AAAA", classFilename = "MAGE", sourceDisplayType = 1, totalAmount = 3000, isLocalPlayer = false },
      { name = "<secret>", sourceGUID = "<secret>", classFilename = "PRIEST", sourceDisplayType = 2, totalAmount = 300, isLocalPlayer = false } } } } },
 },
}
