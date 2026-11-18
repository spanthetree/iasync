# AGENTS.md — iasync coding guide

This file is for AI coding agents working on the iasync addon. Read it before making any changes.

## What this addon is and is not

iasync is a **read-only data exporter**. It never modifies the player's inventory, builds, or any game state — it only reads ESO APIs and writes to `iasync_data` (the SavedVariables table). Keep it that way.

The SavedVariables file is read by the ESO Armory web app (`server.py` / `data_processor.py`). Any schema change here must be reflected there too. `process_iasync` handles character bags, bank, and houses. `process_iasync_builds` reads equipped gear and build data per character.

`process_iasync` also reads `guildBanks` (items with location type `guild_bank`).

## File layout

```
iasync.lua    — entire addon, single file
iasync.txt    — addon manifest (title, version, APIVersion, SavedVariables declaration)
```

## Key ESO API functions used

| Function | Purpose |
|----------|---------|
| `GetItemName(bagId, slot)` | Item name; returns `""` for empty slots |
| `GetItemLink(bagId, slot, LINK_STYLE_BRACKETS)` | Full item link for decoding |
| `GetItemTrait(bagId, slot)` | Returns trait type integer |
| `GetItemLinkEnchantInfo(link)` | `(hasEnchant, enchantName)` |
| `GetItemLinkSetInfo(link)` | `(hasSet, name, bonuses, equipped, max, id)` |
| `GetItemFilterTypeInfo(bagId, slot)` | First return = filter type integer |
| `GetItemInfo(bagId, slot)` | Second return = stack count (works on all bag types) |
| `GetBagSize(bagId)` | Slot count; returns 0 for bags that are absent or inaccessible |
| `GetNextVirtualBagSlotId(prev)` | Craft bag iterator; pass `nil` for the first slot |
| `GetSlotBoundId(slot, hotbarCategory)` | Ability ID bound to a skill bar slot (slots 3–7 = skills, slot 8 = ultimate) |
| `GetSlotType(slot, hotbarCategory)` | Returns `ACTION_TYPE_CRAFTED_ABILITY` for scribing skills |
| `GetAbilityIdForCraftedAbilityId(id)` | Resolves crafted/scribing ID to base ability ID |
| `GetAbilityName(id)` | Ability display name; may return `""` if not loaded this session |
| `GetChampionSkillName(id)` | CP star display name |
| `GetAttributeSpentPoints(attrConst)` | Attribute points allocated by the player |
| `GetPlayerStat(STAT_*_MAX, STAT_BONUS_OPTION_APPLY_BONUS)` | Max Health/Magicka/Stamina as on the character sheet (includes buffs active at scan time); stored as `build_pools` |
| `GetNumBuffs("player")` / `GetUnitBuffInfo(...)` | Used to detect active Mundus stone(s) |
| `GetCurrencyAmount(type, location)` | Currency value; location = `CHARACTER` or `BANK` |
| `GetCurrentCharacterId()` | Returns a 64-bit integer; always `tostring()` before using as a table key |
| `GetUnitName/Race/Class/Alliance("player")` | Character identity |
| `GetUnitGender("player")` | `GENDER_FEMALE` / `GENDER_MALE` / `GENDER_NEUTER`; stored as `"female"` or `"male"` |
| `GetCurrentZoneHouseId()` | Non-zero when inside a house; used to key house data |
| `GetCollectibleIdForHouse(houseId)` | House ID (from `GetCurrentZoneHouseId`) to its collectible ID. A house ID is **not** a collectible ID |
| `GetCollectibleName(id)` | Resolves a collectible ID (e.g. from `GetCollectibleIdForHouse`) to display name |
| `zo_callLater(fn, ms)` | Deferred execution; used for house chest scan (3 000 ms) |
| `GetNumAchievementCategories()` | Total number of top-level achievement categories (confirmed: returns 47) |
| `GetAchievementCategoryInfo(categoryIndex)` | Takes a **1-based index**, not an ID. Returns `(name, numSubCategories, numAchievements, earnedPts, totalPts, hidesPoints)`. r4/r5 are confirmed to match the in-game summary UI (e.g. CHARACTER: 3120/5325). **`GetAchievementCategoryId` does not exist** — confirmed nil at runtime. |
| `GetAchievementSubCategoryInfo(categoryIndex, subCategoryIndex)` | Returns `(name, numAchievements, earnedPts, totalPts)`. r2 is the achievement count to iterate; r3/r4 are API-provided earned/total points for the subcategory. |
| `GetAchievementId(categoryIndex, subCategoryIndex, achievementIndex)` | **3-param, all indices.** `subCategoryIndex=0` returns `achId=0` (confirmed in-game) — all achievements live in subcategories (subIdx ≥ 1). |
| `GetAchievementInfo(achievementId)` | `(name, description, points, icon, complete, date)` |
| `GetAchievementNumCriteria(achievementId)` | Number of criteria for an achievement. **`GetNumAchievementCriteria` does not exist** (confirmed nil). |
| `GetAchievementCriterion(achievementId, criterionIndex)` | `(description, numCompleted, numRequired)`. **`GetAchievementCriteriaInfo` and `GetAchievementCriterionInfo` do not exist** (confirmed nil). |
| `IsAchievementAccountWide` | **Does not exist** in this API version (confirmed nil). Use `GetAchievementPersistenceLevel` instead. |
| `GetAchievementPersistenceLevel(achievementId)` | Returns an integer persistence level. Compare against `ACHIEVEMENT_PERSISTENCE_ACCOUNT` (101051 name; `ACHIEVEMENT_PERSISTENCE_LEVEL_ACCOUNT` does not exist) to identify account-wide achievements. Routing goes through `IsAccountWideAchievement(achId)`. |
| `GetAchievementTimestamp(achievementId)` | Returns a numeric Unix-style timestamp for when the achievement was completed, or 0/nil if incomplete. More reliable than the date string returned by `GetAchievementInfo` r6 for sorting and comparison. |
| `GetCategoryInfoFromAchievementId(achievementId)` | Returns `(categoryIndex, subCategoryIndex)` for an achievement. Useful for resolving display names when handling real-time award events. |
| `GetFirstAchievementInLine(achievementId)` / `GetPreviousAchievementInLine(achievementId)` / `GetNextAchievementInLine(achievementId)` | Line-chain navigation helpers. Use these to preserve base/previous/next IDs for grouped achievements. |
| `GetCharIdForCompletedAchievement(achievementId)` | Returns the character ID that completed a character-specific achievement when ESO can resolve it. `GetCharacterNameById(id)` can be used to turn that into a display name. |
| `GetAchievementRewardTributeCardUpgradeInfo(achievementId)` | Returns tribute card upgrade reward data when present. Store it as a reward entry rather than trying to flatten it into item/title/dye/collectible. |
| `GetAchievementNumRewards()` | **Does NOT take an achievementId.** Returns a global reward count (confirmed: calling with an achId arg still returns the same large global value). Do not use to iterate per-achievement rewards — use this only to check if the rewards system is available. |
| `GetAchievementRewardTitle(achievementId)` | Returns `(hasReward, titleName)`. Call once per achievement — does NOT take a reward index. |
| `GetAchievementRewardDye(achievementId)` | Returns `(hasReward, dyeId)`. Call once per achievement. |
| `GetAchievementRewardCollectible(achievementId)` | Returns `(hasReward, collectibleId)`. Resolve to name via `pcall(GetCollectibleName, cId)` — must be pcall'd. |
| `GetAchievementRewardItem(achievementId)` | Returns `(hasReward, itemName, iconTexture, displayQuality)`. No count. Call once per achievement. |
| `GetAchievementRewardPoints(achievementId)` | Returns point value for the reward. |
| `ITEM_SET_COLLECTIONS_DATA_MANAGER` | Global ZOS singleton for stickerbook data. Check existence before use — absent on older API versions. |
| `ITEM_SET_COLLECTIONS_DATA_MANAGER:TopLevelItemSetCollectionCategoryIterator()` | Iterates top-level stickerbook categories (e.g. "Dungeons", "Cyrodiil"). Each item is a category object. |
| `catData:GetName()` | Category/subcategory display name. Must be `pcall`'d. |
| `catData:HasSubcategories()` | Returns true if the category has subcategories. Must be `pcall`'d. |
| `catData:SubcategoryIterator()` | Iterates subcategory objects. |
| `catData:CollectionIterator()` | Iterates collection (set) objects within a leaf category. |
| `collData:GetId()` | Returns setId for the collection. Must be `pcall`'d. |
| `GetNumItemSetCollectionPieces(setId)` | Total piece count for a set. |
| `GetNumItemSetCollectionSlotsUnlocked(setId)` | How many pieces the account has collected. |
| `GetItemSetCollectionPieceInfo(setId, index)` | `(pieceId, slot)` — 1-based index. `slot` is an id64 userdata; pass directly to other API calls, never convert to integer. |
| `IsItemSetCollectionSlotUnlocked(setId, slot)` | True if the account has collected this piece slot. |
| `GetItemSetName(setId)` | Display name of the set (e.g. "Mara's Balm"). |
| `collData:GetReconstructionCurrencyOptionInfo(1)` | `(currencyType, cost)` transmute cost for reconstructing a piece; the in-game header only shows option 1. Must be `pcall`'d. |
| `GetItemLinkDisplayQuality(link)` | `ITEM_DISPLAY_QUALITY_*` integer for a piece link. |
| `GetItemSetCollectionPieceItemLink(pieceId, linkStyle, traitType)` | Returns an item link string. Use `LINK_STYLE_DEFAULT or 1` and `ITEM_TRAIT_TYPE_NONE or 0`. Must be `pcall`'d. |
| `GetEquipmentFilterTypeForItemSetCollectionSlot(slot)` | Returns an armor/weapon type integer — **NOT** an `ITEM_FILTER_TYPE_*` value despite the name. Unreliable for display; use piece names from `GetItemLinkName` instead. |
| `GetItemLinkName(link)` | Extracts display name from an item link (e.g. "Abyssal Brace Helm"). Must be `pcall`'d. |
| `GetNumCollectibleCategories()` | Top-level Collections categories. Houses, outfit styles and Tales of Tribute patrons are collectibles too |
| `GetCollectibleCategoryInfo(topIdx)` | `(name, numSubCategories, numCollectibles, unlocked, total, hidesLocked)`. `numCollectibles` counts only items directly under the top level |
| `GetCollectibleSubCategoryInfo(topIdx, subIdx)` | `(name, numCollectibles, unlocked, total)` |
| `GetCollectibleId(topIdx, subIdx, idx)` | `subIdx` may be `nil` for items directly under the top level |
| `GetCollectibleInfo(id)` | `(name, description, icon, lockedIcon, unlocked, purchasable, isActive, categoryType, hint)` |
| `GetCollectibleCategorySpecialization(topIdx)` | `COLLECTIBLE_CATEGORY_SPECIALIZATION_*`: which in-game Collections tab the category belongs to |

## Data structure invariants

- **`chars` keys are always strings.** `GetCurrentCharacterId()` returns a number; wrap it in `tostring()` everywhere or Lua table key comparison will silently fail.
- **Bag IDs are integers, slot IDs are integers** — but they are stored as Lua table keys, which means they become integer-keyed tables. The Python side receives them as dicts with string keys (JSON serialisation). `data_processor.py` handles this by calling `int(bag_id_raw)` and iterating with string keys from the JSON.
- **`enchantId` is always 0.** `CaptureSlot` captures the enchant display name via `GetItemLinkEnchantInfo` but never populates the `enchantId` field. The Python side derives a numeric enchant ID from the item link decoder instead.
- **`abilityNames` / `cpNames` live under each character entry**, not at the top level. The top-level `iasync_data.abilityNames` and `iasync_data.cpNames` are kept for backwards compatibility only and are no longer written to.
- **`iasync_data.stickerbook` is account-wide** (not per-character). Schema:
  ```
  iasync_data.stickerbook = {
      lastUpdate = <unix timestamp>,
      categoryIcons = { ["Dungeons"] = "/esoui/art/...dds" },  -- top-level category:GetKeyboardIcons()
      sets = {
          [setId] = {
              name         = "Mara's Balm",
              category     = "Cyrodiil",          -- top-level category name
              subcategory  = "Cyrodiil Rewards",  -- "" if same as category
              numCollected = 7,
              numTotal     = 12,
              reconCurrency = 5,     -- CURT_* currency type (transmute crystals); nil if unknown
              reconCost     = 25,
              pieces = {
                  [i] = {
                      id         = <integer>,   -- piece id from GetItemSetCollectionPieceInfo
                      filterType = <integer>,   -- EQUIPMENT_FILTER_TYPE_* (1 light .. 11 bow)
                      collected  = true/false,
                      name       = "Mara's Balm Greaves",  -- from GetItemLinkName
                      icon       = "/esoui/art/icons/gear_...dds",  -- from GetItemLinkIcon; nil if unavailable
                      quality    = 5,           -- ITEM_DISPLAY_QUALITY_* from GetItemLinkDisplayQuality
                  }
              }
          }
      }
  }
  ```
  The `sets` table is keyed by numeric setId but serialises to JSON with string keys. `data_processor.py` reads this via `process_iasync_stickerbook(raw)` and serves it at `GET /api/stickerbook`.

- **`iasync_data.collectibles` is account-wide.** `items` is keyed by collectibleId (string keys in JSON); each item's `cat`/`sub` index into `categories[cat].subcats[sub]` (`sub = 0` means directly under the top level). Use `categories[i].specialization` to split the Collections tabs (housing, outfit styles, Tales of Tribute). `patrons[patronId]` adds Tales of Tribute patron names, icons and category; join to `items` through `collectibleId`. Tribute card upgrade rewards carry `name` = "<upgraded card> (<patron>)" from `GetTributePatronDockCardInfoByIndex` + `GetTributeCardName`.
- **`iasync_data.activities` is a snapshot.** Progress is as of `lastUpdate`; `endTime`/`resetTime` are unix seconds, so a consumer can tell when a snapshot has expired. Golden Pursuits campaign keys are id64 userdata: pass them straight back to the API and never store them. Reward `claimed` flags come from `BitAnd(flags, PROMOTIONAL_EVENTS_REWARD_FLAG_CLAIMED)`. `tome` is the `REWARD_TRACK_TYPE_TAMRIEL_TOMES` reward track; reward names and icons come from `REWARDS_MANAGER:GetInfoForReward(id, qty)` (pcall'd). Which component (`primary`/`secondary`) is the free track is inferred from `access`, not documented by ZOS.
- **Character details, currencies, research, motifs and recipes are per character** (`ScanCharacterDetails`, run right after `ScanCharacterBags`). Account-held currencies (e.g. Seals, Tome Points) and banked amounts go in the top-level `currencies`. `c.gold/ap/tv/wv` stay for backwards compatibility.
- **Motif chapters** come from `IsSmithingStyleKnown(styleId, ITEM_STYLE_CHAPTER_*)`. The doc names the 2nd parameter `patternIndex`, so the chapter mapping must be checked in game against a known motif.
- **`scribing` and `antiquities` are account-wide** (`ScanScribing`, `ScanAntiquities`, 6 s after login). Antiquity `leadExpires` is unix seconds.
- **`build_mundus` is `nil` when no stone is active**, not an empty table. When stones are active it is a Lua sequential table (e.g. `{ "The Lady" }`), which serialises to JSON as `{"1": "The Lady"}`. `data_processor.py` handles both dict and list forms via `list(build_mundus.values()) if isinstance(..., dict) else list(...)`.
- **House data is keyed by house ID (from `GetCurrentZoneHouseId`) as a string**, e.g. `"66"`. Only houses the player owns are scanned (`IsOwnerOfCurrentHouse`). House storage bags are account-wide, so every owned house holds the same `chests`; consumers must count each chest bag ID once. The same house ID is used across sessions and characters.
- **Achievement entries now keep line-chain and attribution metadata.** Store `lineBaseId`, `linePreviousId`, `lineNextId`, `completedByCharId`, and `completedByCharName` with the existing achievement payload so the web app can group lines and show who earned a completion.

## Event flow

```
EVENT_ADD_ON_LOADED       → OnAddonLoaded    (initialise iasync_data structure, init stickerbook table)
EVENT_PLAYER_ACTIVATED    → OnPlayerActivated  (fires on login, /reloadui, and zone changes)
    └─ zo_callLater 2 s   → ScanCharacterBags + ResolveBuildNames + ScanCharacterDetails
    └─ zo_callLater 3 s   → ScanHouseChests (no-op if not in a house)
    └─ zo_callLater 7 s   → ScanStickerbook (account-wide; 7 s gives ITEM_SET_COLLECTIONS_DATA_MANAGER time to populate)
    └─ zo_callLater 4 s   → ScanActivities (account-wide)
    └─ zo_callLater 6 s   → ScanScribing + ScanAntiquities (account-wide)
    └─ zo_callLater 9 s   → ScanCollectibles (account-wide)
EVENT_ACHIEVEMENTS_UPDATED → ScanAchievements (refresh achievement state when ESO rebuilds it mid-session)
EVENT_ACHIEVEMENT_AWARDED → OnAchievementAwarded (args: eventCode, name, points, achievementId, link)
EVENT_OPEN_BANK           → ScanBankBags
EVENT_TIMED_ACTIVIT* / EVENT_PROMOTIONAL_EVENTS_* → OnActivityChanged (ScanActivities 2 s after the burst)
EVENT_GUILD_BANK_ITEMS_READY → ScanGuildBank (selected guild's items loaded; again after switching guilds)
EVENT_GUILD_BANK_ITEM_ADDED / _REMOVED / _UPDATED_QUANTITY → OnGuildBankChanged (rescan 500 ms after the burst)
EVENT_INVENTORY_SINGLE_SLOT_UPDATE → OnInventorySlotUpdate → UpdateSlot
```

## Lua version

ESO runs **Lua 5.1**. Do not use any Lua 5.2+ features:

- **No `goto` / `::labels::`** — use helper functions with early `return` to skip loop iterations instead.
- No integer division operator `//`, no bitwise operators (`&`, `|`, `~`, `<<`, `>>`), no `<const>` / `<close>` attributes.

When you need to skip to the next iteration of an outer loop, extract the loop body into a local function and use `return` to bail early. See `scanCategory()` inside `ScanAchievements` for the established pattern.

## Things to watch out for

**API availability.** Some ESO globals (`HOTBAR_CATEGORY_PRIMARY`, `BAG_HOUSE_BANK_ONE`, `GetItemDisplayQuality`) were added or renamed across patches. The addon uses `or`-fallbacks throughout (`HOTBAR_CATEGORY_PRIMARY or 1`). When adding new API calls, check whether they exist on the target APIVersion (currently `101051`; authoritative list: `ESOUIDocumentation.txt` on the **`live`** branch of github.com/esoui/esoui; `master` is stale at 101041 and lacks Golden Pursuits) and add a guard if needed.

**`GetAbilityName` returns `""` for out-of-session abilities.** If a Templar logs in and their bars contain Sorcerer skills from a previous character, those ability IDs return empty strings. This is expected — names are resolved only for the current character's loaded skill data. Do not attempt to call `GetAbilityName` for IDs stored from other characters.

**Craft bag iteration.** Never iterate `BAG_VIRTUAL` with a numeric loop. `GetBagSize(BAG_VIRTUAL)` may return a value but slot IDs are not contiguous integers — use `GetNextVirtualBagSlotId` only.

**`pcall` wrapping.** Every ESO API call that could error (slot reads, hotbar reads) is wrapped in `pcall`. If you add a new API call inside `CaptureSlot`, `ScanBuild`, or `ResolveBuildNames`, wrap it too. Errors in slot scanning should be logged to chat with `d(...)` and skipped, not propagated.

**Achievement API shape.** `ScanAchievements` now uses `GetCategoryInfoFromAchievementId`, `GetFirstAchievementInLine`, `GetPreviousAchievementInLine`, `GetNextAchievementInLine`, `GetCharIdForCompletedAchievement`, and `GetAchievementRewardTributeCardUpgradeInfo`. Keep those calls guarded and treat `completedByCharId` / `completedByCharName` as best-effort metadata, not guaranteed values.

**`zo_callLater` delay for house chests.** Do not remove or shorten the 3-second delay. The container bag API (`GetBagSize`) returns 0 for house bags immediately after `EVENT_PLAYER_ACTIVATED` fires; the delay gives the game time to populate the data.

**`GetEquipmentFilterTypeForItemSetCollectionSlot` is misnamed.** Despite the name, it does NOT return `ITEM_FILTER_TYPE_*` values (which map to "Armor", "Weapons", etc.). It returns armor/weapon sub-type integers that are not useful for user-facing display. Always use the piece name from `GetItemLinkName` instead.

**Stickerbook two-level category hierarchy.** `ITEM_SET_COLLECTIONS_DATA_MANAGER` exposes a two-level hierarchy: TopLevelCategories (e.g. "Dungeons") → Subcategories (e.g. "Elden Hollow") → Sets. When recursing through `SubcategoryIterator`, thread both `topName` (the top-level category) and `subName` (the current sub-level) separately. Do NOT overwrite `topName` during recursion — all sets in a top category must share the same category name for the UI grouping to work correctly.

**Two `/reloadui` cycles needed after adding new scan code.** The first `/reloadui` loads the new Lua file but writes the *old* SavedVariables structure (from the prior session). The second `/reloadui` actually writes the results of the new scan. Verify output after the *second* reloadui.

**`slot` from `GetItemSetCollectionPieceInfo` is id64 userdata.** Never store it as an integer or call `tostring()` on it for use as a key. Pass it directly to `IsItemSetCollectionSlotUnlocked` and `GetEquipmentFilterTypeForItemSetCollectionSlot`.

**Guild bank slots.** Guild bank slot ids are not `0..GetBagSize-1`; walk them with `ZO_GetNextBagSlotIndex(BAG_GUILDBANK, slot)`. The open bank's guild is `GetSelectedGuildBankId()`. `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` does not cover guild banks; use the `EVENT_GUILD_BANK_*` events.

## Making schema changes

If you add a new field to any stored table:
1. Add it in the relevant scan function (`ScanCharacterBags`, `ScanBuild`, `CaptureSlot`, etc.)
2. Initialise it with a safe default (do not leave it `nil` if the Python side expects it to always be present)
3. Update `data_processor.py` to read the new field — use `.get("field", default)` to stay backwards compatible with existing SavedVariables files that predate the change
4. Update the schema section in `README.md`

## Git and release policy

Git actions (branch, add, commit, push, pull) are allowed. **Open a pull request only when the user says to.** Never force-push, rewrite published history, or tag by hand.

- Make every change on a new branch. Pull `master` first, then branch off it (`git checkout master && git pull && git checkout -b <branch>`). Never commit straight to `master`.
- One pull request per issue. Land each phase of the work as its own commit, and put the whole issue in a single PR.
- Before you open the PR, the branch's last commit must:
  - **Update `CHANGELOG.md`.** Add a dated `## [x.y.z] — YYYY-MM-DD` section under `[Unreleased]`, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
  - **Update `README.md`** wherever features, the SavedVariables schema, or setup changed.
  - **Bump the version** in `iasync.txt` (the `## Version:` line) under [Semantic Versioning](https://semver.org/spec/v2.0.0.html). A fix is a patch, a feature a minor. Not sure? Ask in the PR.

When the user asks only for a **pre-commit** / release preparation, do those three steps and stop.

## Testing

The fastest feedback loop is the in-game chat command:
```
/script iasync_scan()
```
This re-runs `ScanCharacterBags` + `ResolveBuildNames` for the current character and prints a summary line to chat. The SavedVariables file is written on logout or `/reloadui`.

To force a write without logging out:
```
/reloadui
```

To verify the output, open the SavedVariables file and inspect `iasync_data.chars["<yourCharId>"]`.
