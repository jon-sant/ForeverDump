-- forever.5 R9 control fixture (SYNTHETIC unit-test input, not a capture): the same shape with ONE enemy druid who heals
-- (meter rows in druid_resto_stream.dm.lua, heal far above the group, little damage). Expected: marked - proves R9 is
-- not passing only because nothing can ever be marked.
return {
 meta = { run = "regress-druid-resto", synthetic = true },
 roster = {
  { first = "Leafy", full = "Leafy Bloom", side = "E", class = "DRUID" },
  { first = "Rage", full = "Rage Axe", side = "E", class = "WARRIOR" },
  { first = "Ally", full = "Ally Friend", side = "F", class = "MAGE" },
 },
 ev = {
  {100.0, "S", nil, nil, nil},
  {101.0, "A", "nameplate1", 1, nil}, {101.0, "P", "nameplate1", 1, "MANA"},
  {101.0, "A", "nameplate2", 2, nil}, {101.0, "P", "nameplate2", 2, "RAGE"},
  {105.0, "S", nil, nil, nil}, {106.0, "P", "nameplate1", 1, "MANA"}, {107.0, "P", "nameplate2", 2, "RAGE"},
  {112.0, "S", nil, nil, nil}, {115.0, "P", "nameplate1", 1, "MANA"},
 },
}
