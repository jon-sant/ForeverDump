-- run 22 (2026-10-10 BG, FD 2.2.27, build 70338): the ForeverDumpDB slices the aura-presence candidate list reads,
-- extracted from real/2026-10-10-run22-bg/sv/ForeverDump.lua (spell data only; knowledge spells + refLearned auraDur as stored).
return {
  ["auraLearned"] = {
    ["70338"] = {},
  },
  ["auraPairs"] = {
    ["70338"] = {},
  },
  ["knowledge"] = {
    ["70338"] = {
      ["spells"] = {
        [81] = {
          ["data"] = {
            ["description"] = "Gives a chance to dodge enemy melee attacks.",
            ["info.name"] = "Dodge",
            ["parsed"] = {},
          },
        },
        [107] = {
          ["data"] = {
            ["description"] = "Gives a chance to block enemy melee and ranged attacks.",
            ["info.name"] = "Block",
            ["parsed"] = {},
          },
        },
        [324] = {
          ["data"] = {
            ["description"] = "The caster is surrounded by 3 balls of lightning.  When a spell, melee or ranged attack hits the caster, the attacker will be struck for 17 Nature damage.  This expends one lightning ball.  Only one ball will fire every few seconds.  Lasts 10 min.",
            ["info.name"] = "Lightning Shield",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 17,
              ["amountMin"] = 17,
              ["auraDuration"] = 600,
              ["consumable"] = true,
              ["durations"] = "[{'kind': 'aura', 'n': 600}]",
            },
          },
        },
        [325] = {
          ["data"] = {
            ["description"] = "The caster is surrounded by 3 balls of lightning.  When a spell, melee or ranged attack hits the caster, the attacker will be struck for 28 Nature damage.  This expends one lightning ball.  Only one ball will fire every few seconds.  Lasts 10 min.",
            ["info.name"] = "Lightning Shield",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 28,
              ["amountMin"] = 28,
              ["auraDuration"] = 600,
              ["consumable"] = true,
              ["durations"] = "[{'kind': 'aura', 'n': 600}]",
            },
          },
        },
        [331] = {
          ["data"] = {
            ["description"] = "Heals a friendly target for 39 to 50.",
            ["info.name"] = "Healing Wave",
            ["parsed"] = {
              ["amountKind"] = "heal",
              ["amountMax"] = 50,
              ["amountMin"] = 39,
            },
          },
        },
        [332] = {
          ["data"] = {
            ["description"] = "Heals a friendly target for 74 to 89.",
            ["info.name"] = "Healing Wave",
            ["parsed"] = {
              ["amountKind"] = "heal",
              ["amountMax"] = 89,
              ["amountMin"] = 74,
            },
          },
        },
        [370] = {
          ["data"] = {
            ["description"] = "Purges the enemy target, removing 1 magic effect.",
            ["info.name"] = "Purge",
            ["parsed"] = {
              ["dispel"] = true,
            },
          },
        },
        [403] = {
          ["data"] = {
            ["description"] = "Casts a bolt of lightning at the target for 20 to 23 Nature damage.",
            ["info.name"] = "Lightning Bolt",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 23,
              ["amountMin"] = 20,
              ["school"] = "Nature",
            },
          },
        },
        [526] = {
          ["data"] = {
            ["description"] = "Cures 1 poison effect on the target.",
            ["info.name"] = "Cure Poison",
            ["parsed"] = {
              ["dispel"] = true,
            },
          },
        },
        [529] = {
          ["data"] = {
            ["description"] = "Casts a bolt of lightning at the target for 34 to 39 Nature damage.",
            ["info.name"] = "Lightning Bolt",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 39,
              ["amountMin"] = 34,
              ["school"] = "Nature",
            },
          },
        },
        [546] = {
          ["data"] = {
            ["description"] = "Allows the friendly target to walk across water for 10 min. Any damage will cancel the effect.",
            ["info.name"] = "Water Walking",
            ["parsed"] = {
              ["auraDuration"] = 600,
              ["durations"] = "[{'kind': 'aura', 'n': 600}]",
            },
          },
        },
        [547] = {
          ["data"] = {
            ["description"] = "Heals a friendly target for 136 to 161.",
            ["info.name"] = "Healing Wave",
            ["parsed"] = {
              ["amountKind"] = "heal",
              ["amountMax"] = 161,
              ["amountMin"] = 136,
            },
          },
        },
        [548] = {
          ["data"] = {
            ["description"] = "Casts a bolt of lightning at the target for 53 to 62 Nature damage.",
            ["info.name"] = "Lightning Bolt",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 62,
              ["amountMin"] = 53,
              ["school"] = "Nature",
            },
          },
        },
        [556] = {
          ["data"] = {
            ["description"] = "Yanks the caster through the twisting nether back to The Crossroads.  Speak to an Innkeeper in a different place to change your home location.",
            ["info.name"] = "Astral Recall",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'header', 'n': 10}]",
            },
          },
        },
        [905] = {
          ["data"] = {
            ["description"] = "The caster is surrounded by 3 balls of lightning.  When a spell, melee or ranged attack hits the caster, the attacker will be struck for 44 Nature damage.  This expends one lightning ball.  Only one ball will fire every few seconds.  Lasts 10 min.",
            ["info.name"] = "Lightning Shield",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 44,
              ["amountMin"] = 44,
              ["auraDuration"] = 600,
              ["consumable"] = true,
              ["durations"] = "[{'kind': 'aura', 'n': 600}]",
            },
          },
        },
        [913] = {
          ["data"] = {
            ["description"] = "Heals a friendly target for 259 to 302.",
            ["info.name"] = "Healing Wave",
            ["parsed"] = {
              ["amountKind"] = "heal",
              ["amountMax"] = 302,
              ["amountMin"] = 259,
            },
          },
        },
        [915] = {
          ["data"] = {
            ["description"] = "Casts a bolt of lightning at the target for 69 to 78 Nature damage.",
            ["info.name"] = "Lightning Bolt",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 78,
              ["amountMin"] = 69,
              ["school"] = "Nature",
            },
          },
        },
        [2008] = {
          ["data"] = {
            ["description"] = "Returns the spirit to the body, restoring a dead target to life with 65 health and 120 mana.  Cannot be cast when in combat.",
            ["info.name"] = "Ancestral Spirit",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'header', 'n': 10}]",
            },
          },
        },
        [2484] = {
          ["data"] = {
            ["description"] = "Summons an Earthbind Totem with 5 health at the feet of the caster for 45 sec that slows the movement speed of enemies within 10 yards.",
            ["info.name"] = "Earthbind Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 45}]",
              ["summon"] = true,
              ["summonDuration"] = 45,
              ["summonName"] = "Earthbind Totem",
            },
          },
        },
        [2870] = {
          ["data"] = {
            ["description"] = "Cures 1 disease on the target.",
            ["info.name"] = "Cure Disease",
            ["parsed"] = {},
          },
        },
        [3599] = {
          ["data"] = {
            ["description"] = "Summons a Searing Totem with 5 health at your feet for 30 sec that repeatedly attacks an enemy within 20 yards for 9 to 12 Fire damage.",
            ["info.name"] = "Searing Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 30}]",
              ["summon"] = true,
              ["summonDuration"] = 30,
              ["summonName"] = "Searing Totem",
              ["summonPulse"] = {
                ["kind"] = "damage",
                ["max"] = 12,
                ["min"] = 9,
              },
            },
          },
        },
        [5394] = {
          ["data"] = {
            ["description"] = "Summons a Healing Stream Totem with 5 health at the feet of the caster for 5 min that heals group members within 30 yards for 5 every 2 seconds.",
            ["info.name"] = "Healing Stream Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}, {'kind': 'period', 'n': 2}]",
              ["period"] = 2,
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Healing Stream Totem",
              ["summonPulse"] = {
                ["kind"] = "heal",
                ["max"] = 5,
                ["min"] = 5,
                ["period"] = 2,
              },
            },
          },
        },
        [5675] = {
          ["data"] = {
            ["description"] = "Summons a Mana Spring Totem with 5 health at the feet of the caster for 5 min that restores 4 mana every 2 seconds to group members within 30 yards.",
            ["info.name"] = "Mana Spring Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}, {'kind': 'period', 'n': 2}]",
              ["period"] = 2,
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Mana Spring Totem",
            },
          },
        },
        [5730] = {
          ["data"] = {
            ["description"] = "Summons a Stoneclaw Totem with 116 health at the feet of the caster for 15 sec that taunts creatures within 8 yards to attack it.",
            ["info.name"] = "Stoneclaw Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 15}]",
              ["summon"] = true,
              ["summonDuration"] = 15,
              ["summonName"] = "Stoneclaw Totem",
            },
          },
        },
        [6363] = {
          ["data"] = {
            ["description"] = "Summons a Searing Totem with 5 health at your feet for 35 sec that repeatedly attacks an enemy within 20 yards for 13 to 18 Fire damage.",
            ["info.name"] = "Searing Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 35}]",
              ["summon"] = true,
              ["summonDuration"] = 35,
              ["summonName"] = "Searing Totem",
              ["summonPulse"] = {
                ["kind"] = "damage",
                ["max"] = 18,
                ["min"] = 13,
              },
            },
          },
        },
        [6364] = {
          ["data"] = {
            ["description"] = "Summons a Searing Totem with 5 health at your feet for 40 sec that repeatedly attacks an enemy within 20 yards for 19 to 26 Fire damage.",
            ["info.name"] = "Searing Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 40}]",
              ["summon"] = true,
              ["summonDuration"] = 40,
              ["summonName"] = "Searing Totem",
              ["summonPulse"] = {
                ["kind"] = "damage",
                ["max"] = 26,
                ["min"] = 19,
              },
            },
          },
        },
        [6371] = {
          ["data"] = {
            ["description"] = nil,
            ["info.name"] = nil,
            ["parsed"] = {},
          },
        },
        [6375] = {
          ["data"] = {
            ["description"] = "Summons a Healing Stream Totem with 5 health at the feet of the caster for 5 min that heals group members within 30 yards for 6 every 2 seconds.",
            ["info.name"] = "Healing Stream Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}, {'kind': 'period', 'n': 2}]",
              ["period"] = 2,
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Healing Stream Totem",
              ["summonPulse"] = {
                ["kind"] = "heal",
                ["max"] = 6,
                ["min"] = 6,
                ["period"] = 2,
              },
            },
          },
        },
        [6390] = {
          ["data"] = {
            ["description"] = "Summons a Stoneclaw Totem with 186 health at the feet of the caster for 15 sec that taunts creatures within 8 yards to attack it.",
            ["info.name"] = "Stoneclaw Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 15}]",
              ["summon"] = true,
              ["summonDuration"] = 15,
              ["summonName"] = "Stoneclaw Totem",
            },
          },
        },
        [6391] = {
          ["data"] = {
            ["description"] = "Summons a Stoneclaw Totem with 226 health at the feet of the caster for 15 sec that taunts creatures within 8 yards to attack it.",
            ["info.name"] = "Stoneclaw Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 15}]",
              ["summon"] = true,
              ["summonDuration"] = 15,
              ["summonName"] = "Stoneclaw Totem",
            },
          },
        },
        [6533] = {
          ["data"] = {
            ["description"] = nil,
            ["info.name"] = "Net",
            ["parsed"] = {},
          },
        },
        [6603] = {
          ["data"] = {
            ["description"] = "",
            ["info.name"] = "Attack",
            ["parsed"] = {},
          },
        },
        [8004] = {
          ["data"] = {
            ["description"] = "Heals a friendly target for 156 to 179.",
            ["info.name"] = "Lesser Healing Wave",
            ["parsed"] = {
              ["amountKind"] = "heal",
              ["amountMax"] = 179,
              ["amountMin"] = 156,
            },
          },
        },
        [8008] = {
          ["data"] = {
            ["description"] = "Heals a friendly target for 220 to 249.",
            ["info.name"] = "Lesser Healing Wave",
            ["parsed"] = {
              ["amountKind"] = "heal",
              ["amountMax"] = 249,
              ["amountMin"] = 220,
            },
          },
        },
        [8017] = {
          ["data"] = {
            ["description"] = "Imbue the Shaman's weapon, increasing melee attack power by 59 and allowing melee attacks to cause additional threat when using that weapon.  Lasts for 60 minutes.",
            ["info.name"] = "Rockbiter Weapon",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'imbue', 'n': 3600}]",
              ["imbueDuration"] = 3600,
              ["weaponImbue"] = true,
            },
          },
        },
        [8018] = {
          ["data"] = {
            ["description"] = "Imbue the Shaman's weapon, increasing melee attack power by 94 and allowing melee attacks to cause additional threat when using that weapon.  Lasts for 60 minutes.",
            ["info.name"] = "Rockbiter Weapon",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'imbue', 'n': 3600}]",
              ["imbueDuration"] = 3600,
              ["weaponImbue"] = true,
            },
          },
        },
        [8019] = {
          ["data"] = {
            ["description"] = "Imbue the Shaman's weapon, increasing melee attack power by 141 and allowing melee attacks to cause additional threat when using that weapon.  Lasts for 60 minutes.",
            ["info.name"] = "Rockbiter Weapon",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'imbue', 'n': 3600}]",
              ["imbueDuration"] = 3600,
              ["weaponImbue"] = true,
            },
          },
        },
        [8024] = {
          ["data"] = {
            ["description"] = "Imbue the Shaman's weapon with fire. Each hit causes 6 to 19 additional Fire damage, based on the speed of the weapon. Slower weapons cause more fire damage per swing. When applied to main hand, disables any benefit you personally receive from Flametongue Totem. Lasts for 60 minutes.",
            ["info.name"] = "Flametongue Weapon",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'imbue', 'n': 3600}]",
              ["imbueDuration"] = 3600,
              ["weaponImbue"] = true,
            },
          },
        },
        [8027] = {
          ["data"] = {
            ["description"] = "Imbue the Shaman's weapon with fire. Each hit causes 9 to 28 additional Fire damage, based on the speed of the weapon. Slower weapons cause more fire damage per swing. When applied to main hand, disables any benefit you personally receive from Flametongue Totem. Lasts for 60 minutes.",
            ["info.name"] = "Flametongue Weapon",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'imbue', 'n': 3600}]",
              ["imbueDuration"] = 3600,
              ["weaponImbue"] = true,
            },
          },
        },
        [8030] = {
          ["data"] = {
            ["description"] = "Imbue the Shaman's weapon with fire. Each hit causes 12 to 37 additional Fire damage, based on the speed of the weapon. Slower weapons cause more fire damage per swing. When applied to main hand, disables any benefit you personally receive from Flametongue Totem. Lasts for 60 minutes.",
            ["info.name"] = "Flametongue Weapon",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'imbue', 'n': 3600}]",
              ["imbueDuration"] = 3600,
              ["weaponImbue"] = true,
            },
          },
        },
        [8033] = {
          ["data"] = {
            ["description"] = "Imbue the Shaman's weapon with frost.  Each hit has a chance of causing 53 additional Frost damage and slowing the target's movement speed by 25% for 8 sec.  Lasts for 60 minutes.",
            ["info.name"] = "Frostbrand Weapon",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'imbue', 'n': 8}, {'kind': 'imbue', 'n': 3600}]",
              ["imbueDuration"] = 8,
              ["weaponImbue"] = true,
            },
          },
        },
        [8042] = {
          ["data"] = {
            ["description"] = "Instantly shocks the target with concussive force, causing 25 to 28 Nature damage.  It also interrupts spellcasting and prevents any spell in that school from being cast for 2 sec.  Causes a high amount of threat.",
            ["info.name"] = "Earth Shock",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 28,
              ["amountMin"] = 25,
              ["durations"] = "[{'kind': 'lockout', 'n': 2}]",
              ["interrupt"] = true,
              ["lockout"] = 2,
              ["school"] = "Nature",
            },
          },
        },
        [8044] = {
          ["data"] = {
            ["description"] = "Instantly shocks the target with concussive force, causing 41 to 44 Nature damage.  It also interrupts spellcasting and prevents any spell in that school from being cast for 2 sec.  Causes a high amount of threat.",
            ["info.name"] = "Earth Shock",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 44,
              ["amountMin"] = 41,
              ["durations"] = "[{'kind': 'lockout', 'n': 2}]",
              ["interrupt"] = true,
              ["lockout"] = 2,
              ["school"] = "Nature",
            },
          },
        },
        [8045] = {
          ["data"] = {
            ["description"] = "Instantly shocks the target with concussive force, causing 57 to 62 Nature damage.  It also interrupts spellcasting and prevents any spell in that school from being cast for 2 sec.  Causes a high amount of threat.",
            ["info.name"] = "Earth Shock",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 62,
              ["amountMin"] = 57,
              ["durations"] = "[{'kind': 'lockout', 'n': 2}]",
              ["interrupt"] = true,
              ["lockout"] = 2,
              ["school"] = "Nature",
            },
          },
        },
        [8046] = {
          ["data"] = {
            ["description"] = "Instantly shocks the target with concussive force, causing 89 to 96 Nature damage.  It also interrupts spellcasting and prevents any spell in that school from being cast for 2 sec.  Causes a high amount of threat.",
            ["info.name"] = "Earth Shock",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 96,
              ["amountMin"] = 89,
              ["durations"] = "[{'kind': 'lockout', 'n': 2}]",
              ["interrupt"] = true,
              ["lockout"] = 2,
              ["school"] = "Nature",
            },
          },
        },
        [8050] = {
          ["data"] = {
            ["description"] = "Instantly sears the target with fire, causing 27 Fire damage immediately and 34 Fire damage over 12 sec.",
            ["info.name"] = "Flame Shock",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 27,
              ["amountMin"] = 27,
              ["auraDuration"] = 12,
              ["durations"] = "[{'kind': 'aura', 'n': 12}]",
              ["overTime"] = 12,
            },
          },
        },
        [8052] = {
          ["data"] = {
            ["description"] = "Instantly sears the target with fire, causing 41 Fire damage immediately and 38 Fire damage over 12 sec.",
            ["info.name"] = "Flame Shock",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 41,
              ["amountMin"] = 41,
              ["auraDuration"] = 12,
              ["durations"] = "[{'kind': 'aura', 'n': 12}]",
              ["overTime"] = 12,
            },
          },
        },
        [8053] = {
          ["data"] = {
            ["description"] = "Instantly sears the target with fire, causing 48 Fire damage immediately and 62 Fire damage over 12 sec.",
            ["info.name"] = "Flame Shock",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 48,
              ["amountMin"] = 48,
              ["auraDuration"] = 12,
              ["durations"] = "[{'kind': 'aura', 'n': 12}]",
              ["overTime"] = 12,
            },
          },
        },
        [8056] = {
          ["data"] = {
            ["description"] = "Instantly shocks the target with frost, causing 74 to 79 Frost damage and slowing movement speed by 50%.  Lasts 8 sec.",
            ["info.name"] = "Frost Shock",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 79,
              ["amountMin"] = 74,
              ["auraDuration"] = 8,
              ["durations"] = "[{'kind': 'aura', 'n': 8}]",
              ["school"] = "Frost",
            },
          },
        },
        [8071] = {
          ["data"] = {
            ["description"] = "Summons a Stoneskin Totem with 5 health at the feet of the caster.  The totem protects party members within 30 yards, reducing Physical damage taken by 4.  Lasts 5 min.",
            ["info.name"] = "Stoneskin Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}]",
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Stoneskin Totem",
            },
          },
        },
        [8075] = {
          ["data"] = {
            ["description"] = "Summons a Strength of Earth Totem with 5 health at the feet of the caster.  The totem increases the strength of party members within 30 yards by 7.  Lasts 5 min.",
            ["info.name"] = "Strength of Earth Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}]",
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Strength of Earth Totem",
            },
          },
        },
        [8143] = {
          ["data"] = {
            ["description"] = "Summons a Tremor Totem with 5 health at the feet of the caster that shakes the ground around it, removing Fear, Charm and Sleep effects from party members within 30 yards.  Lasts 5 min.",
            ["info.name"] = "Tremor Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}]",
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Tremor Totem",
            },
          },
        },
        [8154] = {
          ["data"] = {
            ["description"] = "Summons a Stoneskin Totem with 5 health at the feet of the caster.  The totem protects party members within 30 yards, reducing Physical damage taken by 7.  Lasts 5 min.",
            ["info.name"] = "Stoneskin Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}]",
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Stoneskin Totem",
            },
          },
        },
        [8155] = {
          ["data"] = {
            ["description"] = "Summons a Stoneskin Totem with 5 health at the feet of the caster.  The totem protects party members within 30 yards, reducing Physical damage taken by 11.  Lasts 5 min.",
            ["info.name"] = "Stoneskin Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}]",
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Stoneskin Totem",
            },
          },
        },
        [8160] = {
          ["data"] = {
            ["description"] = "Summons a Strength of Earth Totem with 5 health at the feet of the caster.  The totem increases the strength of party members within 30 yards by 14.  Lasts 5 min.",
            ["info.name"] = "Strength of Earth Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}]",
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Strength of Earth Totem",
            },
          },
        },
        [8162] = {
          ["data"] = {
            ["description"] = nil,
            ["info.name"] = nil,
            ["parsed"] = {},
          },
        },
        [8166] = {
          ["data"] = {
            ["description"] = "Summons a Poison Cleansing Totem with 5 health at the feet of the caster that attempts to remove 1 poison effect from party members within 30 yards every 5 seconds.  Lasts 5 min.",
            ["info.name"] = "Poison Cleansing Totem",
            ["parsed"] = {
              ["dispel"] = true,
              ["durations"] = "[{'kind': 'period', 'n': 5}, {'kind': 'summon', 'n': 300}]",
              ["period"] = 5,
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Poison Cleansing Totem",
            },
          },
        },
        [8177] = {
          ["data"] = {
            ["description"] = "Summons a Grounding Totem with 5 health at the feet of the caster that will redirect one harmful spell cast on a nearby party member to itself every 10 seconds.  Will not redirect area of effect spells.  Lasts 45 sec.",
            ["info.name"] = "Grounding Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'period', 'n': 10}, {'kind': 'summon', 'n': 45}]",
              ["period"] = 10,
              ["summon"] = true,
              ["summonDuration"] = 45,
              ["summonName"] = "Grounding Totem",
            },
          },
        },
        [8181] = {
          ["data"] = {
            ["description"] = "Summons a Frost Resistance Totem with 5 health at the feet of the caster for 5 min.  The totem increases party and raid members' frost resistance by 30, if within 30 yards.",
            ["info.name"] = "Frost Resistance Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}]",
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Frost Resistance Totem",
            },
          },
        },
        [8184] = {
          ["data"] = {
            ["description"] = "Summons a Fire Resistance Totem with 5 health at the feet of the caster for 5 min that increases the fire resistance of party and raid members within 30 yards by 30.",
            ["info.name"] = "Fire Resistance Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}]",
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Fire Resistance Totem",
            },
          },
        },
        [8227] = {
          ["data"] = {
            ["description"] = "Summons a Flametongue Totem with 5 health at the feet of the caster. The totem enchants all party members' main-hand weapons with fire if they are within 30 yards. Each hit causes 6 to 22 additional Fire damage, based on the speed of the weapon. Slower weapons cause more fire damage per swing. Lasts 5 min.",
            ["info.name"] = "Flametongue Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}]",
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Flametongue Totem",
            },
          },
        },
        [8232] = {
          ["data"] = {
            ["description"] = "Imbue the Shaman's weapon with wind.  Each hit has a 20% chance of granting you 2 extra attacks with 64 extra melee attack power. When applied to main hand, disables any benefit you personally receive from Windfury Totem. Lasts for 60 minutes.",
            ["info.name"] = "Windfury Weapon",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'imbue', 'n': 3600}]",
              ["imbueDuration"] = 3600,
              ["weaponImbue"] = true,
            },
          },
        },
        [10399] = {
          ["data"] = {
            ["description"] = "Imbue the Shaman's weapon, increasing melee attack power by 213 and allowing melee attacks to cause additional threat when using that weapon.  Lasts for 60 minutes.",
            ["info.name"] = "Rockbiter Weapon",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'imbue', 'n': 3600}]",
              ["imbueDuration"] = 3600,
              ["weaponImbue"] = true,
            },
          },
        },
        [10595] = {
          ["data"] = {
            ["description"] = "Summons a Nature Resistance Totem with 5 health at the feet of the caster for 5 min that increases the nature resistance of party and raid members within 30 yards by 30.",
            ["info.name"] = "Nature Resistance Totem",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'summon', 'n': 300}]",
              ["summon"] = true,
              ["summonDuration"] = 300,
              ["summonName"] = "Nature Resistance Totem",
            },
          },
        },
        [17364] = {
          ["data"] = {
            ["description"] = "Instantly strike for normal weapon damage and increase the damage you deal to the target with your next Lightning Bolt, Chain Lightning, or Earth Shock spell by 20% for 12 sec.",
            ["info.name"] = "Stormstrike",
            ["parsed"] = {
              ["auraDuration"] = 12,
              ["durations"] = "[{'kind': 'aura', 'n': 12}]",
            },
          },
        },
        [18848] = {
          ["data"] = {
            ["description"] = "Gives a chance to parry enemy melee attacks.",
            ["info.name"] = "Parry",
            ["parsed"] = {},
          },
        },
        [20572] = {
          ["data"] = {
            ["description"] = "Increases Attack Power and Spell Power by 10% for 15 sec.",
            ["info.name"] = "Blood Fury",
            ["parsed"] = {
              ["auraDuration"] = 15,
              ["durations"] = "[{'kind': 'aura', 'n': 15}]",
            },
          },
        },
        [20573] = {
          ["data"] = {
            ["description"] = "Duration of Stun effects on you reduced by 20%.",
            ["info.name"] = "Hardiness",
            ["parsed"] = {},
          },
        },
        [20574] = {
          ["data"] = {
            ["description"] = "Increases your critical strike chance with all spells and abilities by 1% while you have an axe or a two-handed axe equipped.",
            ["info.name"] = "Axe Specialization",
            ["parsed"] = {},
          },
        },
        [20608] = {
          ["data"] = {
            ["description"] = "Allows you to resurrect yourself upon death with 20% health and mana.",
            ["info.name"] = "Reincarnation",
            ["parsed"] = {},
          },
        },
        [36936] = {
          ["data"] = {
            ["description"] = "Returns your totems to the earth, giving you 25% of the mana required to cast each totem destroyed by Totemic Recall.",
            ["info.name"] = "Totemic Recall",
            ["parsed"] = {},
          },
        },
        [66842] = {
          ["data"] = {
            ["description"] = "Simultaneously places up to 4 totems specified in the Totem Bar.",
            ["info.name"] = "Call of the Elements",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'header', 'n': 3}]",
            },
          },
        },
        [66843] = {
          ["data"] = {
            ["description"] = "Simultaneously places up to 4 totems specified in the Totem Bar. Can call different totems than Call of the Elements.",
            ["info.name"] = "Call of the Ancestors",
            ["parsed"] = {
              ["durations"] = "[{'kind': 'header', 'n': 3}]",
            },
          },
        },
        [408341] = {
          ["data"] = {
            ["description"] = "Instantly inflicts 55 to 63 fire damage to enemies within 10 yd of your active Fire totem.",
            ["info.name"] = "Fire Nova",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 63,
              ["amountMin"] = 55,
              ["school"] = "fire",
            },
          },
        },
        [408342] = {
          ["data"] = {
            ["description"] = "Instantly inflicts 112 to 127 fire damage to enemies within 10 yd of your active Fire totem.",
            ["info.name"] = "Fire Nova",
            ["parsed"] = {
              ["amountKind"] = "damage",
              ["amountMax"] = 127,
              ["amountMin"] = 112,
              ["school"] = "fire",
            },
          },
        },
        [437009] = {
          ["data"] = {
            ["description"] = "Relocates your active totems to the specified location.",
            ["info.name"] = "Totemic Projection",
            ["parsed"] = {},
          },
        },
        [1238640] = {
          ["data"] = {
            ["description"] = "Turns the Shaman into a Ghost Wolf, increasing speed by 40%.",
            ["info.name"] = "Ghost Wolf",
            ["parsed"] = {},
          },
        },
        [1293657] = {
          ["data"] = {
            ["description"] = "You are fluent in the following languages:\r\n|cffffffffOrcish|r",
            ["info.name"] = "Languages",
            ["parsed"] = {},
          },
        },
        [1293712] = {
          ["data"] = {
            ["description"] = "You are proficient in the use of the following armor types:\r\n|cffffffffCloth|r\r\n|cffffffffLeather|r",
            ["info.name"] = "Armor Proficiency",
            ["parsed"] = {},
          },
        },
        [1299026] = {
          ["data"] = {
            ["description"] = "Instantly removes and grants immunity to all Curses and Banes, and reduces all Magical damage taken by 15% for 8 sec.",
            ["info.name"] = "Shatter Curse",
            ["parsed"] = {
              ["auraDuration"] = 8,
              ["durations"] = "[{'kind': 'aura', 'n': 8}]",
            },
          },
        },
      },
    },
  },
  ["refLearned"] = {
    ["70338"] = {
      ["auraDur"] = {
        [122] = {
          ["max"] = 8,
          ["min"] = 8,
          ["n"] = 4,
        },
        [770] = {
          ["max"] = 40,
          ["min"] = 40,
          ["n"] = 6,
        },
        [778] = {
          ["max"] = 40,
          ["min"] = 40,
          ["n"] = 8,
        },
        [905] = {
          ["max"] = 600,
          ["min"] = 600,
          ["n"] = 16,
        },
        [1075] = {
          ["max"] = 600,
          ["min"] = 600,
          ["n"] = 31,
        },
        [1079] = {
          ["max"] = 12,
          ["min"] = 12,
          ["n"] = 6,
        },
        [1086] = {
          ["max"] = 1800,
          ["min"] = 1800,
          ["n"] = 33,
        },
        [1245] = {
          ["max"] = 3600,
          ["min"] = 3600,
          ["n"] = 151,
        },
        [1461] = {
          ["max"] = 3600,
          ["min"] = 3600,
          ["n"] = 25,
        },
        [1735] = {
          ["max"] = 30,
          ["min"] = 30,
          ["n"] = 30,
        },
        [1822] = {
          ["max"] = 9,
          ["min"] = 9,
          ["n"] = 6,
        },
        [2091] = {
          ["max"] = 12,
          ["min"] = 12,
          ["n"] = 3,
        },
        [3600] = {
          ["max"] = 5,
          ["min"] = 5,
          ["n"] = 1,
        },
        [5234] = {
          ["max"] = 3600,
          ["min"] = 3600,
          ["n"] = 109,
        },
        [6217] = {
          ["max"] = 24,
          ["min"] = 24,
          ["n"] = 27,
        },
        [6223] = {
          ["max"] = 18,
          ["min"] = 18,
          ["n"] = 8,
        },
        [6533] = {
          ["max"] = 10,
          ["min"] = 10,
          ["n"] = 5,
        },
        [6756] = {
          ["max"] = 3600,
          ["min"] = 3600,
          ["n"] = 17,
        },
        [7302] = {
          ["max"] = 1800,
          ["min"] = 1800,
          ["n"] = 25,
        },
        [7321] = {
          ["max"] = 5,
          ["min"] = 5,
          ["n"] = 2,
        },
        [8052] = {
          ["max"] = 12,
          ["min"] = 12,
          ["n"] = 27,
        },
        [8406] = {
          ["max"] = 7,
          ["min"] = 7,
          ["n"] = 4,
        },
        [8450] = {
          ["max"] = 600,
          ["min"] = 600,
          ["n"] = 9,
        },
        [8494] = {
          ["max"] = 60,
          ["min"] = 60,
          ["n"] = 3,
        },
        [8940] = {
          ["max"] = 21,
          ["min"] = 21,
          ["n"] = 11,
        },
        [12579] = {
          ["max"] = 15,
          ["min"] = 15,
          ["n"] = 4,
        },
        [14752] = {
          ["max"] = 3600,
          ["min"] = 3600,
          ["n"] = 24,
        },
        [16257] = {
          ["max"] = 15,
          ["min"] = 15,
          ["n"] = 28,
        },
        [18070] = {
          ["max"] = 30,
          ["min"] = 30,
          ["n"] = 26,
        },
        [18265] = {
          ["max"] = 30,
          ["min"] = 30,
          ["n"] = 3,
        },
        [19742] = {
          ["max"] = 3600.002,
          ["min"] = 3600.002,
          ["n"] = 56,
        },
        [19850] = {
          ["max"] = 3600,
          ["min"] = 3600,
          ["n"] = 7,
        },
        [20050] = {
          ["max"] = 30,
          ["min"] = 30,
          ["n"] = 7,
        },
        [20217] = {
          ["max"] = 3600,
          ["min"] = 3600,
          ["n"] = 5,
        },
        [20305] = {
          ["max"] = 30,
          ["min"] = 30,
          ["n"] = 7,
        },
        [24974] = {
          ["max"] = 12,
          ["min"] = 12,
          ["n"] = 5,
        },
        [25771] = {
          ["max"] = 60,
          ["min"] = 60,
          ["n"] = 7,
        },
        [408510] = {
          ["max"] = 600,
          ["min"] = 600,
          ["n"] = 7,
        },
        [415407] = {
          ["max"] = 20,
          ["min"] = 20,
          ["n"] = 13,
        },
        [440667] = {
          ["max"] = 30,
          ["min"] = 30,
          ["n"] = 5,
        },
        [1238931] = {
          ["max"] = 15,
          ["min"] = 15,
          ["n"] = 63,
        },
        [1242512] = {
          ["max"] = 15,
          ["min"] = 15,
          ["n"] = 8,
        },
        [1248406] = {
          ["max"] = 900,
          ["min"] = 900,
          ["n"] = 3,
        },
        [1261483] = {
          ["max"] = 10,
          ["min"] = 10,
          ["n"] = 24,
        },
        [1262243] = {
          ["max"] = 120,
          ["min"] = 120,
          ["n"] = 3,
        },
        [1262307] = {
          ["max"] = 120,
          ["min"] = 120,
          ["n"] = 7,
        },
        [1262315] = {
          ["max"] = 120,
          ["min"] = 120,
          ["n"] = 10,
        },
        [1262317] = {
          ["max"] = 120,
          ["min"] = 120,
          ["n"] = 7,
        },
        [1299346] = {
          ["max"] = 1800,
          ["min"] = 1800,
          ["n"] = 13,
        },
        [1309728] = {
          ["max"] = 15,
          ["min"] = 15,
          ["n"] = 2,
        },
        [1311676] = {
          ["max"] = 300,
          ["min"] = 300,
          ["n"] = 8,
        },
      },
    },
  },
  ["spellCache"] = {
    ["70338"] = {},
  },
}
