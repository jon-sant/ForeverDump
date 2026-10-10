-- forever.8 R11 fixture (SYNTHETIC unit-test input, not a capture). No capture has a clear spellID for another unit
-- (FD runs 6-18: always secret), so this models the case K.T.H. handles if a client ever returns one. One enemy per
-- spell on the user's healer-only list casts it once (rank-1 ability ID from wowhead.com/forever + FD DB2) -> marked at
-- once. Penance uses 402289, the ID the combat logs record for SPELL_CAST_SUCCESS. Swiftmend (18562) and Holy Shock
-- (1311606, the logged cast ID) are no longer instant flags; Riptide 22419 is an unrelated NPC "Disarmed" spell; Quiet casts nothing. Each cast is followed by a power update on the same plate 1 s later (a plate refresh).
return {
 meta = { run = "regress-healonly-spell", synthetic = true },
 roster = {
  { first = "Pen", full = "Pen Disc", side = "E", class = "PRIEST" },
  { first = "Infuse", full = "Infuse Disc", side = "E", class = "PRIEST" },
  { first = "Mend", full = "Mend Holy", side = "E", class = "PRIEST" },
  { first = "Vigil", full = "Vigil Holy", side = "E", class = "PALADIN" },
  { first = "Grove", full = "Grove Resto", side = "E", class = "DRUID" },
  { first = "Tide", full = "Tide Resto", side = "E", class = "SHAMAN" },
  { first = "Swift", full = "Swift Mend", side = "E", class = "DRUID" },
  { first = "Shock", full = "Shock Holy", side = "E", class = "PALADIN" },
  { first = "Naga", full = "Naga Disarm", side = "E", class = "SHAMAN" },
  { first = "Quiet", full = "Quiet Druid", side = "E", class = "DRUID" },
 },
 ev = {
  {100.0, "A", "nameplate1", 1, nil}, {100.0, "A", "nameplate2", 2, nil}, {100.0, "A", "nameplate3", 3, nil},
  {100.0, "A", "nameplate4", 4, nil}, {100.0, "A", "nameplate5", 5, nil}, {100.0, "A", "nameplate6", 6, nil},
  {100.0, "A", "nameplate7", 7, nil}, {100.0, "A", "nameplate8", 8, nil}, {100.0, "A", "nameplate9", 9, nil},
  {100.0, "A", "nameplate10", 10, nil},
  {110.0, "C", "nameplate1", 1, 402289}, {111.0, "P", "nameplate1", 1, "MANA"},
  {120.0, "C", "nameplate2", 2, 10060}, {121.0, "P", "nameplate2", 2, "MANA"},
  {130.0, "C", "nameplate3", 3, 401859}, {131.0, "P", "nameplate3", 3, "MANA"},
  {140.0, "C", "nameplate4", 4, 1310911}, {141.0, "P", "nameplate4", 4, "MANA"},
  {150.0, "C", "nameplate5", 5, 408120}, {151.0, "P", "nameplate5", 5, "MANA"},
  {160.0, "C", "nameplate6", 6, 408521}, {161.0, "P", "nameplate6", 6, "MANA"},
  {170.0, "C", "nameplate7", 7, 18562}, {171.0, "P", "nameplate7", 7, "MANA"},
  {175.0, "C", "nameplate8", 8, 1311606}, {176.0, "P", "nameplate8", 8, "MANA"},
  {178.0, "C", "nameplate9", 9, 22419}, {179.0, "P", "nameplate9", 9, "MANA"},
  {185.0, "P", "nameplate1", 1, "MANA"}, {185.0, "P", "nameplate7", 7, "MANA"}, {185.0, "P", "nameplate8", 8, "MANA"},
  {185.0, "P", "nameplate9", 9, "MANA"}, {185.0, "P", "nameplate10", 10, "MANA"},
  {200.0, "P", "nameplate1", 1, "MANA"},
 },
}
