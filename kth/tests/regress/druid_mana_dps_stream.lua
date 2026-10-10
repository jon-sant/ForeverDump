-- forever.5 R9 fixture (SYNTHETIC unit-test input, not a capture). User decision: "heal and feral druids both have mana.
-- having mana does not make one a healer ... balance druids have mana too". Two enemy DPS druids (feral in caster form,
-- balance) show MANA on their plates the whole time, cast, and damage friendly players; they never heal anyone else.
-- Expected: never marked (forever.3's CLASS+PWR marked both). The meter rows are in druid_mana_dps_stream.dm.lua.
return {
 meta = { run = "regress-druid-mana-dps", synthetic = true },
 roster = {
  { first = "Kitty", full = "Kitty Claws", side = "E", class = "DRUID" },
  { first = "Moon", full = "Moon Fire", side = "E", class = "DRUID" },
  { first = "Ally", full = "Ally Friend", side = "F", class = "MAGE" },
 },
 ev = {
  {100.0, "S", nil, nil, nil},
  {101.0, "A", "nameplate1", 1, nil}, {101.0, "P", "nameplate1", 1, "MANA"},
  {101.0, "A", "nameplate2", 2, nil}, {101.0, "P", "nameplate2", 2, "MANA"},
  {101.5, "P", "raid1", 3, "MANA"},
  {102.0, "C", "nameplate1", 1, "SECRET"}, {102.0, "U", "raid1", 3, "WOUND"},
  {103.0, "C", "nameplate2", 2, "SECRET"}, {103.0, "U", "raid1", 3, "WOUND"},
  {104.0, "C", "nameplate1", 1, "SECRET"}, {104.0, "U", "nameplate1", 1, "HEAL"},
  {105.0, "S", nil, nil, nil}, {106.0, "P", "nameplate1", 1, "MANA"}, {107.0, "P", "nameplate2", 2, "MANA"},
  {108.0, "C", "nameplate2", 2, "SECRET"}, {108.0, "U", "raid1", 3, "WOUND"},
  {112.0, "S", nil, nil, nil}, {115.0, "P", "nameplate1", 1, "MANA"},
 },
}
