-- forever.7 R12 fixture (SYNTHETIC unit-test input, not a capture): a LOW-LEVEL enemy healer (level 22, no talent or
-- rune spells, so no healer-only cast ever) is still marked by the other layers (meter row, one priest on the team),
-- and the absence of healer-only casts counts for nothing. Meter rows in lowlevel_healer_stream.dm.lua.
return {
 meta = { run = "regress-lowlevel-healer", synthetic = true },
 roster = {
  { first = "Novice", full = "Novice Mender", side = "E", class = "PRIEST", level = 22 },
  { first = "Brute", full = "Brute Axe", side = "E", class = "WARRIOR", level = 22 },
  { first = "Ally", full = "Ally Friend", side = "F", class = "MAGE", level = 22 },
 },
 ev = {
  {100.0, "S", nil, nil, nil},
  {101.0, "A", "nameplate1", 1, nil}, {101.0, "P", "nameplate1", 1, "MANA"},
  {101.0, "A", "nameplate2", 2, nil}, {101.0, "P", "nameplate2", 2, "RAGE"},
  {105.0, "S", nil, nil, nil}, {106.0, "C", "nameplate1", 1, "SECRET"}, {107.0, "P", "nameplate2", 2, "RAGE"},
  {112.0, "S", nil, nil, nil}, {115.0, "P", "nameplate1", 1, "MANA"},
 },
}
