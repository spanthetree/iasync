# SavedVariables schema

iasync writes one global table, `iasync_data`, to
`Documents\Elder Scrolls Online\live\SavedVariables\iasync.lua`. Lua tables with
integer keys (bag IDs, slot IDs, set IDs, build indexes) become objects with
string keys when converted to JSON.

Per-character data lives under `chars["<charId>"]`; the character ID is the
64-bit value from `GetCurrentCharacterId()`, stored as a string. Everything
else is account-wide.

```
iasync_data = {
  accountName,          -- display name from GetDisplayName()
  chars = {
    ["<charId>"] = {
      name, race, class, alliance,
      gender,               -- "female" or "male" (from GetUnitGender)
      bags = { [bagId] = { [slot] = { link, name, qty, traitType, traitName,
                                      enchantName,        -- display string; enchant ID is not captured
                                      setId, setName,
                                      quality, filterType,
                                      icon,               -- the item's own icon (/esoui/art/icons/...dds)
                                      armorType,          -- "Light"/"Medium"/"Heavy"; nil for non-armor
                                      weaponType,         -- e.g. "Sword", "Inferno Staff"; nil for non-weapons
                                    } } },
      spaceUsed, spaceMax,
      gold, ap, tv, wv,
      build_bars = { primary = { [slot] = abilityId }, backup = { ... },
                    werewolf = { ... } },  -- present only for werewolf characters
      build_attributes = { health, magicka, stamina },
      build_pools = { health, magicka, stamina },  -- max resource pools, as on the character sheet
      level, championPoints, title, zone, zoneId, avaRank, avaRankName,
      riding = { inventory, inventoryMax, stamina, staminaMax, speed, speedMax },
      guilds = { [i] = { name, rankIndex, rankName } },
      currencies = { ["TRANSMUTE_CRYSTALS"] = amount, ... },  -- character-held currencies, keyed by CURT_* suffix
      research = { blacksmithing = { [line] = { name, icon, numTraits, known = { traitType, ... },
                                                researching = { { traitType, endTime }, ... } } }, clothier = ..., woodworking = ..., jewelrycrafting = ... },
      motifs = { [collectionId] = { name, numKnown, total, books = { [i] = { title, known } } } },  -- Lore Library "Crafting Motifs"; styles with at least one book known
      recipes = { [listIndex] = { name, total, known = { "Recipe Name", ... } } },
      scribing = {
        grimoires = { [craftedAbilityId] = { name, icon, abilityId, unlocked, scribed,
                                            scripts = { primary = { scriptId, ... }, secondary = { ... }, tertiary = { ... } } } },
        scripts = { [scriptId] = { name, unlocked } },
        lastUpdate,
      },
      build_mundus = { "Stone Name", ... },   -- nil if none active; Lua sequential table
      build_cp = { earned = N, slots = { [slot] = abilityId } },
      armoryBuilds = {                          -- in-game Armory, logged-in character only; kept if the API reports 0 builds
        [buildIndex] = {
          name, iconIndex, icon,                -- icon = "EsoUI/Art/Armory/BuildIcons/buildIcon_<n>.dds"
          skillPoints,                          -- total only; no per-skill-line breakdown
          curse,                                -- "none" | "vampire" | "werewolf"
          outfitIndex,                          -- nil when no outfit
          outfitName,                           -- as the Armory shows it; nil when no outfit
          gear = { [equipSlot] = {              -- equipSlot = BAG_WORN slot index; empty slots omitted
            state,                              -- "valid" | "inaccessible" (house chest) | "missing" (sold/deconstructed)
            bagId, slotIndex,                   -- where the item is now; absent when missing
            link, name, traitType, ...,         -- CaptureSlot fields, only when the item can be read; never when missing
          } },
          bars = { primary = { [3..8] = abilityId }, backup = { ... } },           -- ids as saved
          effectiveBars = { primary = { [3..8] = abilityId }, backup = { ... } },  -- morphed/scribed ids
          cp = { slots = { [1..12] = championSkillId },
                 disciplines = { [disciplineId] = { name, spent } } },  -- no per-star allocation
          attributes = { health, magicka, stamina },
          mundus = { "Stone Name", ... },       -- nil if none; same shape as build_mundus
          barsUpdate,                           -- unix ts when bars/effectiveBars/cp.slots were last read; nil if never
        },
      },
      armoryBuildsUpdate,                       -- unix timestamp of the last Armory scan
      abilityNames = { [abilityId] = "Name" },  -- equipped, Armory and saved skills, retained across scans
      abilityIcons = { [abilityId] = "/esoui/art/icons/ability_...dds" },
      cpNames      = { [abilityId] = "Name" },
      cpDescriptions = { [championSkillId] = "Description" },  -- slotted stars, from GetChampionSkillDescription at current points
      mundusDescriptions = { ["Stone Name"] = "Description" }, -- keyed as in build_mundus, from GetAbilityDescription of the boon buff
      achievements = {
        [achId] = {
          name, desc, points, icon, complete, cat, subcat,
          completionDate, completionTimestamp,  -- only when complete
          persistenceLevel,
          lineBaseId, linePreviousId, lineNextId,
          completedByCharId, completedByCharName,
          criteria = { [i] = { desc, cur, req } },
          rewards  = { { type, name, id, ... }, ... }, -- item rewards: { type, name, icon } (no qty); includes tribute_card_upgrade entries { type, patronId, cardIndex, name }
        }
      },
      lastUpdate,
    }
  },
  bank = {
    bags = { [bagId] = { [slot] = slotData } },
    gold, ap, tv, wv, lastUpdate,
  },
  guildBanks = {
    ["<GuildName>"] = { slots = { [slot] = slotData }, lastUpdate }
  },
  houses = {  -- owned houses only; storage chests are account-wide, so each house holds the same chests
    ["<houseId>"] = {
      name,
      chests = {
        [bagId] = { slots = { [slot] = slotData }, capacity, chestNum, lastUpdate }
      },
      lastUpdate,
    }
  },
  achievements = {
    account = {
      [achId] = { ... }   -- account-wide achievements (same structure as char achievements)
    },
    categories = {
      [catIdx] = {
        name, icon, total, complete, earnedPts, totalPts, numAchievements, hidesUnearned,  -- icon: keyboard tree icon path
        subcats = { [subIdx] = { name, total, complete, earnedPts, totalPts, numAchievements, hidesUnearned } },
      }
    },
    earnedPts, totalPts, lastUpdate,
  },
  stickerbook = {
    sets = {
      [setId] = {
        name, category, subcategory,
        numCollected, numTotal,
        reconCurrency, reconCost,  -- transmute cost from the in-game set header (CURT_* currency type); nil if unknown
        pieces = { [i] = { id, filterType, collected, name, icon, quality } },  -- icon: /esoui/art/icons/... from GetItemLinkIcon; quality: ITEM_DISPLAY_QUALITY_*
      }
    },
    categoryIcons = { [categoryName] = iconPath },  -- top-level category tree icons
    lastUpdate,
  },
  collectibles = {  -- account-wide; the in-game Collections tree
    categories = {
      [topIdx] = {
        name, icon, specialization,  -- COLLECTIBLE_CATEGORY_SPECIALIZATION_* (NONE, DLC, HOUSING, OUTFIT_STYLES, TRIBUTE_PATRONS)
        numUnlocked, numTotal, hidesLocked,
        subcats = { [subIdx] = { name, icon, numUnlocked, numTotal } },
      }
    },
    items = {
      [collectibleId] = { name, icon, unlocked, categoryType, cat, sub },  -- cat/sub index into categories; sub = 0 for top-level items
    },
    patrons = {  -- Tales of Tribute patrons
      [patronId] = { name, collectibleId, icon, smallIcon, suitIcon, rarity, neutral, category, categoryIcon, categoryOrder },  -- category = in-game tree header ("Patrons", "Neutral")
    },
    lastUpdate,
  },
  currencies = {  -- keyed by CURT_* suffix; account = account-held amount, bank = banked amount of a character-held currency
    ["SEALS"] = { name, icon, account }, ["MONEY"] = { name, icon, bank }, ...  -- icon from GetCurrencyKeyboardIcon
  },
  antiquities = {
    items = { [antiquityId] = { name, icon, quality, setId, zoneId, repeatable, numRecovered, loreAcquired, loreTotal, hasLead, leadExpires } },
    sets = { [setId] = name }, zones = { [zoneId] = name },
    lastUpdate,
  },
  activities = {  -- account-wide snapshot at scan time; times are unix seconds
    timed = {  -- Endeavors and Tamriel Tome seasonal challenges
      [i] = { id, name, description, type, difficulty, progress, maxProgress, endTime, currencyType, currencyQty, timesClaimed, timesClaimable },  -- type: "daily", "weekly" or "seasonal"
    },
    limits = { daily = { resetTime }, weekly = { resetTime }, seasonal = { resetTime } },
    campaigns = {  -- Golden Pursuits
      [i] = {
        id, name, description, numCompleted, capstoneThreshold, capstoneClaimed, endTime,
        activities = { [i] = { id, name, description, progress, maxProgress, claimed } },
        milestones = { [i] = { threshold, claimed } },
      }
    },
    tome = {  -- Tamriel Tome season pass; nil when Tomes are disabled
      id, name, trackId, tier, progressToNext, endTime, premium, premiumPlus,
      access = { primary, secondary },  -- whether this account can claim each reward component
      tiers = { [tier] = { totalProgress, primary = { [i] = reward }, secondary = { [i] = reward } } },
      -- reward = { id, quantity, quality, name, icon, claimed }
    },
    lastUpdate,
  },
  uiColors = {  -- "rrggbb" from GetInterfaceColor; nil if a constant is missing
    textNormal, textSelected, textHighlight, textDisabled, textDefault, textContrast, textSucceeded, textSecondSelected, textSecondNormal,
    xpStart, xpEnd,
  },
  abilityNames = {},   -- legacy; kept for backwards compat, not actively written
  cpNames        = { [championSkillId] = "Name" },         -- every champion star, account-wide
  cpDescriptions = { [championSkillId] = "Description" },  -- every champion star, at max points
}
```

## Notes for consumers

- **Item slots.** Every item entry (`slotData`) has the fields shown under
  `bags`. `enchantId` is always `0`; decode the enchant from the item link if
  you need its ID.
- **Mundus stones.** `build_mundus` and `armoryBuilds[i].mundus` are `nil` when
  no stone is active, otherwise a sequential list, which serialises to JSON as
  `{"1": "The Lady"}`.
- **House chests** are account-wide, so every owned house lists the same
  `chests`. Count each chest bag ID once.
- **Armory bars.** `bars`, `effectiveBars` and `cp.slots` only load after the
  client has visited an Armory station. A scan away from a station keeps the
  last values read; `barsUpdate` says when that was.
- **Snapshots.** `activities` reflects progress at `lastUpdate`. `endTime` and
  `resetTime` are unix seconds, so you can tell when a snapshot has expired.
- **Icons** are game texture paths (`/esoui/art/icons/....dds`), not files on
  disk. [UESP](https://en.uesp.net/) mirrors them as PNG at
  `https://esoicons.uesp.net/esoui/art/icons/<name>.png`.
- **Deleted characters** stay in `chars` until you delete the file.
