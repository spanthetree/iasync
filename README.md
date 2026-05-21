<div align="center">
  <img src="header.svg" alt="iasync" width="860"/>
</div>

An Elder Scrolls Online addon that exports character inventory, bank, house chest, and build data to `SavedVariables` so the [ESO Armory](https://github.com/spanthetree/eso-armory) web app can read it without requiring any external upload.

## How this differs from Inventory Insight (iifa)

[Inventory Insight](https://www.esoui.com/downloads/info1545-InventoryInsight.html) and iasync solve different problems.

| | Inventory Insight | iasync |
|---|---|---|
| **Where you see the data** | In-game panels and search UI | ESO Armory web app |
| **Primary use** | Quickly find which character has an item without logging in | Browse gear, builds, and currencies from a browser |
| **Build data** | No | Yes — skill bars, CP stars, attributes, Mundus Stone |
| **In-game UI** | Yes | None — invisible in-game |
| **Scope** | General-purpose inventory manager | Purpose-built exporter for ESO Armory |

If you want a searchable in-game item list, use Inventory Insight. If you want to browse your characters' gear and builds in a web app, use iasync. They can run side-by-side without conflict.

## What it captures

**On every character activation — login, /reloadui, or zone change (per character)**
- Equipped gear (`BAG_WORN`) and backpack (`BAG_BACKPACK`) — item link, name, quantity, trait type (integer) and resolved trait name, enchant display name, set name and set ID, quality, filter type, armor weight (`armorType`), weapon type (`weaponType`)
- Skill bars (primary and backup) — ability IDs for slots 3–7 (skills) and slot 8 (ultimate), with crafted/scribing ability resolved to base ID via `GetAbilityIdForCraftedAbilityId`
- Champion Point stars — total earned points and the 12 slotted star IDs (`HOTBAR_CATEGORY_CHAMPION`, slots 1–12)
- Attribute point allocations (Health / Magicka / Stamina)
- Active Mundus Stone(s) — detected via buff scan; supports multiple stones (e.g. Steed of the North set)
- Currencies — Gold, Alliance Points, Tel Var Stones, Writ Vouchers (character location)
- Character identity — name, race, class, alliance
- Inventory capacity (used / max backpack slots)
- Resolved ability names and CP star names for the current character's build, stored per-character so logins never overwrite another character's names

**On bank open**
- Personal bank (`BAG_BANK`)
- ESO Plus overflow bank (`BAG_SUBSCRIBER_BANK`)
- Craft bag (`BAG_VIRTUAL`) — uses the virtual bag iterator (`GetNextVirtualBagSlotId`), not numeric slots
- Bank currencies — Gold, Alliance Points, Tel Var Stones, Writ Vouchers (bank location)

**On house entry** (3 s after zone transition)
- Up to 10 house storage chests per house, keyed by house collectible ID
- Per-chest: slot contents, capacity, 1-based chest number, and last-update timestamp

**On guild bank open**
- Contents of BAG_GUILDBANK, stored under the guild's name
- Note: `guildBanks` data is captured in SavedVariables but is not currently read by the ESO Armory `data_processor.py` and will not appear in the web app.

**Stickerbook** (7 s after zone transition)
- Item set collection state via `ITEM_SET_COLLECTIONS_DATA_MANAGER`
- Per set: name, category, subcategory, collected piece count, and total piece count
- Per piece: display name (e.g. `"Mara's Balm Greaves"` via `GetItemSetCollectionPieceItemLink` + `GetItemLinkName`), collected status, and equipment filter type
- Stored in `iasync_data.stickerbook.sets` keyed by set ID

**Achievements** (5 s after zone transition, and on real-time award)
- Full achievement scan across all categories and subcategories
- Per-achievement: name, description, points, icon, completion status, completion date and Unix timestamp, persistence level, line chain IDs, completion attribution, criteria progress, and any rewards (title, dye, collectible, item, tribute card upgrade)
- Account-wide achievements stored in `iasync_data.achievements.account`; character-specific achievements stored under `chars[charId].achievements`
- Category and subcategory point summaries (earned/total), achievement counts, and hidden-progress flags pulled directly from the ESO API to match the in-game UI exactly
- Real-time update via `EVENT_ACHIEVEMENT_AWARDED` and `EVENT_ACHIEVEMENTS_UPDATED` for achievements earned or refreshed mid-session

**Real-time** — any `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` fires `UpdateSlot`, keeping inventory data current without a full re-scan.

## Installation

1. Copy the `iasync` folder into:
   ```
   %USERPROFILE%\Documents\Elder Scrolls Online\live\AddOns\
   ```
2. Launch ESO and enable **iasync** in the AddOn Manager.
3. Log into each character you want tracked — the first login triggers the initial scan.

## SavedVariables location

```
%USERPROFILE%\Documents\Elder Scrolls Online\live\SavedVariables\iasync.lua
```

The ESO Armory server reads this file directly and watches it for changes.

## SavedVariables schema

```
iasync_data = {
  accountName,          -- display name from GetDisplayName()
  chars = {
    ["<charId>"] = {
      name, race, class, alliance,
      bags = { [bagId] = { [slot] = { link, name, qty, traitType, traitName,
                                      enchantName,        -- display string; enchant ID is not captured
                                      setId, setName,
                                      quality, filterType,
                                      armorType,          -- "Light"/"Medium"/"Heavy"; nil for non-armor
                                      weaponType,         -- e.g. "Sword", "Inferno Staff"; nil for non-weapons
                                    } } },
      spaceUsed, spaceMax,
      gold, ap, tv, wv,
      build_bars = { primary = { [slot] = abilityId }, backup = { ... } },
      build_attributes = { health, magicka, stamina },
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
          rewards  = { { type, name, id, ... }, ... }, -- includes tribute_card_upgrade entries
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
  houses = {
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
        name, total, complete, earnedPts, totalPts, numAchievements, hidesUnearned,
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
        pieces = { [i] = { filterType, collected, name } },
      }
    },
    lastUpdate,
  },
  abilityNames = {},   -- legacy; kept for backwards compat, not actively written
  cpNames      = {},   -- legacy; kept for backwards compat, not actively written
}
```

## Manual rescan

Open the in-game chat and run:
```
/script iasync_scan()
```
This re-runs the character bag scan and ability name resolution for the currently logged-in character.

## Design notes

- **Ability names are per-character.** `GetAbilityName` can only resolve abilities available in the current game session (i.e., loaded class). Each character's names are stored under `chars[charId].abilityNames` so a login as one character never overwrites another's resolved names.
- **Craft bag uses a linked-list iterator.** `BAG_VIRTUAL` cannot be iterated with numeric slots; `GetNextVirtualBagSlotId` must be used instead.
- **House chests need a delay.** Container bag data is not immediately available after a zone transition, so scanning is deferred 3 seconds via `zo_callLater`.
- **Crafted abilities are resolved to their base ID.** Scribing abilities on skill bars use a crafted ability ID; `GetAbilityIdForCraftedAbilityId` converts them before storage so the web app can look up names and icons consistently.
- **All ESO API calls are `pcall`-wrapped.** Slot reads, hotbar reads, and buff queries are wrapped in `pcall`. Errors are logged to chat via `d(...)` and skipped rather than propagated, so a single bad slot never aborts a full bag scan.
- **Achievement attribution is best-effort.** `GetCharIdForCompletedAchievement` / `GetCharacterNameById` are used when ESO can resolve them; if not, the current character is used as a fallback for completion attribution.
- **API availability guards.** Some ESO globals (`HOTBAR_CATEGORY_PRIMARY`, `BAG_HOUSE_CONTAINER_1`, `GetItemDisplayQuality`) were added or renamed across patches. The addon uses `or`-fallbacks throughout (e.g. `HOTBAR_CATEGORY_PRIMARY or 1`) to stay compatible with older API versions.
- **Guild bank multi-guild limitation.** `ScanGuildBank` stores data under the first guild found via `GetGuildId`. If a player is in multiple guilds with guild banks there is currently no ESO API to identify which guild bank is open, so only the open bank is captured.
