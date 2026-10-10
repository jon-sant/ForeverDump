-- forever.7 R13 fixture (SYNTHETIC unit-test input, not a capture; no arena run exists). Spec shortcut: arena1 reports
-- spec 105 (Restoration druid) -> marked at once; arena2 reports 71 (not a healer spec) -> not marked, and never
-- counted against anyone; arena3 reports no spec (absence) -> not marked by spec. Friendly group role test separate.
return {
 meta = { run = "regress-spec-arena", synthetic = true, arenaSpecs = { {1, 105}, {2, 71}, {3, 0} } },
 roster = {
  { first = "Tree", full = "Tree Bark", side = "E", class = "DRUID" },
  { first = "Arms", full = "Arms Blade", side = "E", class = "WARRIOR" },
  { first = "Unknown", full = "Unknown Spec", side = "E", class = "PRIEST" },
 },
 ev = {
  {100.0, "A", "nameplate1", 1, nil}, {100.0, "P", "nameplate1", 1, "MANA"},
  {100.0, "A", "nameplate2", 2, nil}, {100.0, "P", "nameplate2", 2, "RAGE"},
  {100.0, "A", "nameplate3", 3, nil}, {100.0, "P", "nameplate3", 3, "MANA"},
  {102.0, "P", "nameplate1", 1, "MANA"}, {103.0, "P", "nameplate2", 2, "RAGE"}, {104.0, "P", "nameplate3", 3, "MANA"},
 },
}
