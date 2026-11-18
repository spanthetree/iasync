<div align="center">
  <img src="header.svg" alt="iasync" width="860"/>
</div>

iasync is an Elder Scrolls Online addon that exports your account's inventory, builds, achievements and set collection to a local `SavedVariables` file. It is the data source for [ESO Armory](https://github.com/spanthetree/eso-armory), a companion web app that lets you browse every character's gear and builds from a browser.

## Why it exists

ESO does not offer an API for reading character data outside the game. The only supported way to get data out is through an addon's `SavedVariables` file, which the game writes to disk on logout and `/reloadui`.

iasync reads the game's APIs and writes a complete, structured snapshot of your account to that file. Nothing is uploaded and nothing leaves your machine; any tool that can read a Lua table can use the output.

iasync is read-only. It never changes your inventory, builds or any other game state, and it adds no in-game UI.

## Features

- **Characters**: equipped gear and backpack, with trait, enchant, set, quality, armor weight and weapon type for every item. Also currencies, backpack capacity, and name, race, class, alliance and gender.
- **Builds**: front, back and werewolf skill bars (scribed skills resolved to their base ability), slotted Champion Point stars, attribute allocation, and active Mundus Stone(s).
- **Storage**: personal bank, ESO Plus bank, craft bag, house storage chests and guild bank.
- **Achievements**: every achievement with criteria progress, rewards, completion date and the character who earned it, split into account-wide and per-character. Includes category point totals that match the in-game summary.
- **Set collections**: collected pieces for every set in the stickerbook.
- **Activities**: daily and weekly Endeavors, Tamriel Tome seasonal challenges and Golden Pursuits campaigns, with progress toward each.
- **Collectibles**: the in-game Collections tree with unlocked state, including mounts, pets, costumes, houses, outfit styles and Tales of Tribute patrons.

## Requirements

- The Elder Scrolls Online, API version `101051` (Update 51) or later
- No library dependencies

## Installation

1. Copy the `iasync` folder into `Documents\Elder Scrolls Online\live\AddOns\`.
2. Start ESO and enable **iasync** in the AddOns menu.
3. Log in to each character you want exported. Bank contents are captured when you open it, each guild bank when you view it, and house chests when you enter a house.

## Usage

iasync runs automatically. Data is written to:

```
Documents\Elder Scrolls Online\live\SavedVariables\iasync.lua
```

ESO only writes this file on logout, character switch or `/reloadui`.

To rescan the current character without reloading, run this in chat:

```
/script iasync_scan()
```

### When data is captured

| Trigger | Data |
|---|---|
| Login, `/reloadui`, zone change | Character bags, build, currencies (after 2 s), house chests if in a house (3 s), achievements (5 s), set collections (7 s) |
| Opening the bank | Bank, ESO Plus bank, craft bag, bank currencies |
| Viewing a guild bank (and depositing or withdrawing) | That guild's bank contents |
| Any inventory change | The changed slot, in real time |
| Earning an achievement | That achievement, in real time |

## Output format

<details>
<summary><code>iasync_data</code> schema</summary>

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
                                      armorType,          -- "Light"/"Medium"/"Heavy"; nil for non-armor
                                      weaponType,         -- e.g. "Sword", "Inferno Staff"; nil for non-weapons
                                    } } },
      spaceUsed, spaceMax,
      gold, ap, tv, wv,
      build_bars = { primary = { [slot] = abilityId }, backup = { ... },
                    werewolf = { ... } },  -- present only for werewolf characters
      build_attributes = { health, magicka, stamina },
      build_pools = { health, magicka, stamina },  -- max resource pools, as on the character sheet
      build_mundus = { "Stone Name", ... },   -- nil if none active; Lua sequential table
      build_cp = { earned = N, slots = { [slot] = abilityId } },
      abilityNames = { [abilityId] = "Name" },
      cpNames      = { [abilityId] = "Name" },
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
  activities = {  -- account-wide snapshot at scan time; times are unix seconds
    timed = {  -- Endeavors and Tamriel Tome seasonal challenges
      [i] = { id, name, description, type, difficulty, progress, maxProgress, endTime, currencyType, currencyQty },  -- type: "daily", "weekly" or "seasonal"
    },
    limits = { daily = { limit, completed, resetTime }, weekly = { ... }, seasonal = { ... } },
    campaigns = {  -- Golden Pursuits
      [i] = {
        id, name, description, numCompleted, capstoneThreshold, capstoneClaimed, endTime,
        activities = { [i] = { id, name, description, progress, maxProgress, claimed } },
        milestones = { [i] = { threshold, claimed } },
      }
    },
    lastUpdate,
  },
  uiColors = {  -- "rrggbb" from GetInterfaceColor; nil if a constant is missing
    textNormal, textSelected, textHighlight, textDisabled, textDefault, textContrast, textSucceeded, textSecondSelected, textSecondNormal,
    xpStart, xpEnd,
  },
  abilityNames = {},   -- legacy; kept for backwards compat, not actively written
  cpNames      = {},   -- legacy; kept for backwards compat, not actively written
}
```

</details>

Lua tables with integer keys (bag IDs, slot IDs, set IDs) become string keys when converted to JSON.

## Known limitations

- **Guild banks**: each guild bank is captured only after you view it, and only if you have permission to see its contents.
- **Ability names**: names are resolved only for the logged-in character, because `GetAbilityName` cannot resolve another class's abilities.
- **Achievement attribution**: the character who earned an account-wide achievement is reported only when ESO can resolve it.

## Design notes

- **Ability names are per-character.** `GetAbilityName` can only resolve abilities available in the current game session (i.e., loaded class). Each character's names are stored under `chars[charId].abilityNames` so a login as one character never overwrites another's resolved names.
- **Craft bag uses a linked-list iterator.** `BAG_VIRTUAL` cannot be iterated with numeric slots; `GetNextVirtualBagSlotId` must be used instead.
- **House chests need a delay.** Container bag data is not immediately available after a zone transition, so scanning is deferred 3 seconds via `zo_callLater`.
- **Crafted abilities are resolved to their base ID.** Scribing abilities on skill bars use a crafted ability ID; `GetAbilityIdForCraftedAbilityId` converts them before storage so the web app can look up names and icons consistently.
- **All ESO API calls are `pcall`-wrapped.** Slot reads, hotbar reads, and buff queries are wrapped in `pcall`. Errors are logged to chat via `d(...)` and skipped rather than propagated, so a single bad slot never aborts a full bag scan.
- **API availability guards.** Some ESO globals (`HOTBAR_CATEGORY_PRIMARY`, `BAG_HOUSE_BANK_ONE`, `GetItemDisplayQuality`) were added or renamed across patches. The addon uses `or`-fallbacks throughout (e.g. `HOTBAR_CATEGORY_PRIMARY or 1`) to stay compatible with older API versions. Targets APIVersion `101051` (Update 51); `ESOUIDocumentation.txt` in [esoui/esoui](https://github.com/esoui/esoui) is the reference for available globals.

## License

[MIT](LICENSE)
