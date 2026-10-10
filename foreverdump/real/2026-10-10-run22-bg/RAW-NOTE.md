# run 22 (BG, 2026-10-10 ~13:39-13:56 ET) - raw storage
- raw/: both user zips byte-identical (sha256 = file names) + their unzipped contents (names as received).
- sv/ForeverDump.lua = raw/"ForeverDump - Copy.lua" byte-identical (sha256 01b8d1b2...8d74). No KTH SV in the upload.
- WoWCombatLog.original.txt = raw combat log byte-identical (sha256 0d8dbbd9...0314; spans 10:24-13:56, runs 18-22).
- WoWCombatLog.txt = lines 33884..end of the original (from the 13:39:25.879 COMBAT_LOG_VERSION header; Darkspear
  Islands BG session). Lines are unmodified; only the earlier sessions (runs 18-21, stored under their own runs) are cut.
