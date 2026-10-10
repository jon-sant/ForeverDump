# Run 3 findings (Forever 1.60.1.70245, addon 2.2.1 capture, Uglaz Doomaxe, level-30 Orc shaman, solo)

Sources: `real/2026-10-07-run3/` (SV, taint.log, WoWCombatLog). Reports: `out/` (all.log, verify/, ops, lab, combat, tokens,
knowledge, inference/, hsm, drift, restrictions, errors.txt, taint.txt, xref, combatlog, containers/, guide/).
Codes: N nil, S secret, K clear container, T container with secret contents, C clear, E error.

## Identity (SV meta, new in 2.2.1)
- **Present, `anySecret=false`:** no own-identity field was secret.
  - GUID `Player-4618-00EB40D8`, SHAMAN, Orc, level 30.
  - Realm "Classic Beta PvE" / "ClassicBetaPvE".
- **Forever quirk:** `UnitName`/`UnitFullName("player")` return **("Uglaz", "Doomaxe")**, i.e. (first name, last name).
  - `GetUnitName("player", true)` returns "Uglaz Doomaxe".
  - 2.2.1 therefore split out no last name. This is fixed in the addon (2.2.2) and in the converter (`identity_from_dump`), which now shows "Uglaz Doomaxe".
- **Log owner:** the combat log owner was picked automatically (`auto:sv-meta guid`); 1856 CLEU events.

## ADDON_ACTION_BLOCKED "UNKNOWN()" (36x, all in combat, all ForeverDump)
- **Source:** CombatProbe `record()` → `pcall(f, ...)` at CombatProbe.lua:163, called from the ITEMS loop at :412 (taint.log stack).
- **Pattern:** exactly one block per friendly/self unit class per in-combat probe run. None for hostile units, none out of combat.
- **Root cause: `CheckInteractDistance`.**
  - It is protected in combat for insecure code (hotfix 2023-11-16), and enemy units were allowed again on 2023-12-11 (warcraft.wiki.gg/wiki/API_CheckInteractDistance).
  - That matches the friendly-only pattern. When blocked it still returns false, so it was classified C.
- **Why the name was UNKNOWN():** the client names no function, and 2.2.1 dropped every ForeverDump stack frame.
- **Fixes (2.2.2):**
  - Every probe call is wrapped in `ns.ProbeMark(module, path, unit)` / `ns.ProbeDone()`. ADDON_ACTION_BLOCKED fires synchronously inside the blocked call, so Errors.lua records `resolved = "CombatProbe:CheckInteractDistance(party1)"` and prints `... (now skipped in combat)`. Our own frames are kept as `ownStack`.
  - The path is learned in `ForeverDumpDB.blockedPaths[build]` and skipped in combat from then on.
  - `CheckInteractDistance` is skipped up front in combat for non-hostile units (`CP.COMBAT_SKIP`). Docs rows tagged Protected/HasRestrictions/RequiresNonCombat are skipped in lockdown too.
  - The same skip covers the new Containers probes. `fdump errors` labels the old 2.2.1 UNKNOWN() lines with this analysis.

## Taint log, classified (43 entries; `out/taint.txt`)

| Class | Count | Source |
|---|---|---|
| expected (ForeverDump probe) | 36 | Ops matrix / lab ops touching secrets inside pcall |
| contained | 3 | Lab.lua:182 AddPoint (our own curve) ×2; Core.lua:441 utcOffset (our own `date("*t")` isdst). ForeverDump tables only, no Blizzard frame involved |
| probe-blocked | 3 | CheckInteractDistance (taint.log covers only part of the session) |
| blizzard-frame | 1 | `ChatFrame1:UpdateFading`, from the ops matrix's `print(secret)` into the default chat frame |
| unexpected | 0 | |

- **ChatFrame1:** 2.2.2 never prints secrets there. The test writes with `AddMessage` to our own hidden ScrollingMessageFrame and then calls Clear; `secrets.opsPrint="chat"` restores the old behaviour.
- **Gating:** the ops matrix and lab were already gated to once per context per session.

## Empirical secrecy (combat probe, run 3)

| What | Player / self | Hostile NPC |
|---|---|---|
| Health | `UnitHealth` S everywhere (also out of combat); `UnitHealthMax` C | `UnitHealth` S; `UnitHealthMax` **S** |
| Power | `UnitPower` S; `UnitPowerMax` C | S / S |
| Heal prediction / absorbs | `UnitGetIncomingHeals` S; `UnitGetTotalAbsorbs` S | incoming heals N; absorbs S |
| Speed | `GetUnitSpeed` C out of combat, **S in combat** | same |
| Identity | `UnitName`, `UnitGUID`, `UnitClass`, `UnitLevel`, `UnitReaction`, `UnitIsFriend` C | same (realm N) |
| Range | `UnitInRange` S; `CheckInteractDistance` C but blocked in combat | `CheckInteractDistance` C, allowed in combat |
| Position | `UnitPosition` C | N |
| Threat | `UnitThreatSituation` N | C in combat |
| Raid target icon | - | `GetRaidTargetIndex` sometimes S |
| Own cast info in combat | all fields C | - |
| Auras | C out of combat; **E in combat** (see below) | E in combat |

- **Spell knowledge:** tooltip, description, cooldown and GetSpellInfo are clear in combat; `GetSpell*Secrecy` return 2.
- **Tokens:** nameplates resolved 1/40 out of combat and 2/40 in combat. Identity was clear; values were secret.
- **Drift vs the 70245 baseline (run 2):** newly secret 4, newly clear 8, APIs −12.
- **Verify:** 1 CONTRADICTED. In UNIT_AURA payload pos 1, `C_Secrets.ShouldAurasBeSecret` was true in 74 of 80 cases while the value was clear.
- **xref (SV vs combat log):** exact 72, time+amount 258, time-only (amount differs) 124, unmatched 888, 6 segments.
- **Dispel colour:** `GetAuraDispelTypeColor` needs `(unit, auraInstanceID, curve)`. 2.2.2 passes a `C_CurveUtil.CreateColorCurve()` curve or skips the call.

## Partial secrets: aura count and fields (observed only)
Full matrix: `out/containers/CONTAINERS.md` and the guide's "Partial secrets and containers" section.

| Field / count | Out of combat: player, self via other tokens | Out of combat: target NPC | In combat: player / self / target NPC | Party / raid / pet |
|---|---|---|---|---|
| aura table | K | N (no auras) | E (GetAuraDataByIndex errors) | unobserved |
| auraInstanceID, isFromPlayerOrPlayerPet, applications, expirationTime, duration, dispelName | C | unobserved | E | unobserved |
| sourceUnit | C (present in only 2 observations) | unobserved | E | unobserved |
| spellId, name, icon | C | unobserved | E | unobserved |
| points | K | unobserved | E | unobserved |
| count: GetAuraSlots, GetUnitAuras (incl. HELPFUL\|PLAYER, HARMFUL\|PLAYER) | clear (K / readable) | N | E | unobserved |
| UNIT_AURA payload | - | - | T: isFullUpdate S; added / removed / updated each S or N (e.g. player addedAuras S15 N10) | unobserved |

- **Answer:** no. In combat, tainted addon code gets neither a count nor any fields, not even with HELPFUL|PLAYER. Every aura API errors with "Auras cannot be accessed when secret while tainted by 'ForeverDump'".
- **No mixed aura table** was observed. The only signal left is the UNIT_AURA payload: nil vs secret list gives a clear yes/no ("something added/removed/updated now"), but no count or identity.
- **Partial containers that were observed:** `event:UNIT_AURA` (combat, 7 unit classes), and `C_DamageMeter.GetCombatSessionFromType` in combat, where durationSeconds, maxAmount and totalAmount are secret.
- **Permanent probe from 2.2.2 on:** the Containers module walks every probed return.
  - Coverage: depth 3, per context (including restriction states) and per unit class.
  - Stored per field and flag: issecrettable, canaccesstable, hasanysecretvalues, HasSecretValues(), the clear count/length and the key lists. Classifications only, never values.
  - The schema is diffed against `fixtures/baselines/70245/containers.json`, which was written from run 3.
  - Baseline: 2 contexts, 11 unit classes, 8 partial containers, 0 diff.

## HSM
- **Live (2.2.1):** 1 session kept, 0 live contradictions.
  - Recall was 0/15, because combat aura reads error and the payload is secret.
  - Aura checks were 0/4: totems were predicted as auras on the creature target.
  - Amount: 1 ok + 4 pending. Cooldown: 2 pending.
- **Fixes in 2.2.2:**
  - Totems become summon predictions on the player, with the tooltip lifetime. They are verified live through `PLAYER_TOTEM_UPDATE` + `GetTotemInfo`; when the engine duration is readable it is compared and contradicts outside the tolerance.
  - Purge is a dispel prediction. Self, helpful and summon spells cast with a hostile target are attributed to the player.
  - Knowledge parsing: "health" is no longer treated as a heal, and totem durations are no longer treated as aura durations.
  - Up to 4 sessions are kept in `inference.history`.
- **Offline scoring of the "unverified" predictions:**
  - Summons are scored by SPELL_SUMMON (presence). Lifetimes cannot be verified: Forever logs no UNIT_DESTROYED for totems (0/7 have an end event).
  - Dispels are scored by SPELL_DISPEL / _FAILED / STOLEN; there were 0 in this log (Purge removed nothing).
  - A cooldown is only judged if a recast falls within predicted end + max(10 s, cd). Recast gaps over 180 s are ignored; the run 2 → run 3 gap had inflated the learned cooldown to 2963 s.
- **Offline replay** (truth: casts 33, auras 45, amounts 30, summons 7, dispels 0):

| Mode | Recall | Detail |
|---|---|---|
| clear | 100% | cooldown 3 bad, mean error 15.3 s (online min-gap learning) |
| secret | 33.3% | same cooldown issue |
| secret-pretrained (SV knowledge seed) | 60% | aura 6/6 combat (mean 11.1 s) + 4/4 out of combat (2.0 s); amount 8/10 (2 crits); cooldown 8/8 judged, mean 2.18 s, 11 pending; summon 7/7 present |

- **HSM window:**
  - Fixed 190 px label column, so bars no longer overlap labels; right-side value text on each bar.
  - Default 640×480 (minimum 560×300).
  - HP bars pass the engine values straight through: `UnitHealthMax` clear for the player and secret for NPCs, `UnitHealth` secret. They now reset when the unit is absent.
  - The engine cooldown check was sane: Stoneclaw predicted 23.3 s vs 23 s from the engine.
