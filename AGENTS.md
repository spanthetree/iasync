# AGENTS.md — iasync coding guide

This file is for AI coding agents working on the iasync addon. Read it before making any changes.

## What this addon is and is not

iasync is a **read-only data exporter**. It never modifies the player's inventory, builds, or any game state — it only reads ESO APIs and writes to `iasync_data` (the SavedVariables table). Keep it that way.

The SavedVariables file is read by the ESO Armory web app (`server.py` / `data_processor.py`). Any schema change here must be reflected there too. `process_iasync` handles character bags, bank, and houses. `process_iasync_builds` reads equipped gear and build data per character.

**Currently not consumed by eso-armory:** `guildBanks` — the data is captured but `data_processor.py` does not read it, so it will not appear in the web app.

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
| `GetNumBuffs("player")` / `GetUnitBuffInfo(...)` | Used to detect active Mundus stone(s) |
| `GetCurrencyAmount(type, location)` | Currency value; location = `CHARACTER` or `BANK` |
| `GetCurrentCharacterId()` | Returns a 64-bit integer; always `tostring()` before using as a table key |
| `GetUnitName/Race/Class/Alliance("player")` | Character identity |
| `GetCurrentZoneHouseId()` | Non-zero when inside a house; used to key house data |
| `GetCollectibleName(id)` | Resolves house collectible ID to display name |
| `zo_callLater(fn, ms)` | Deferred execution; used for house chest scan (3 000 ms) |
| `GetNumAchievementCategories()` | Total number of top-level achievement categories (confirmed: returns 47) |
| `GetAchievementCategoryInfo(categoryIndex)` | Takes a **1-based index**, not an ID. Returns `(name, numSubCategories, ???, earnedPts, totalPts)`. r4/r5 are confirmed to match the in-game summary UI (e.g. CHARACTER: 3120/5325). r3 purpose unknown. **`GetAchievementCategoryId` does not exist** — confirmed nil at runtime. |
| `GetAchievementSubCategoryInfo(categoryIndex, subCategoryIndex)` | Returns `(name, numAchievements, earnedPts, totalPts)`. r2 is the achievement count to iterate; r3/r4 are API-provided earned/total points for the subcategory. |
| `GetAchievementId(categoryIndex, subCategoryIndex, achievementIndex)` | **3-param, all indices.** `subCategoryIndex=0` returns `achId=0` (confirmed in-game) — all achievements live in subcategories (subIdx ≥ 1). |
| `GetAchievementInfo(achievementId)` | `(name, description, points, icon, complete, date)` |
| `GetAchievementNumCriteria(achievementId)` | Number of criteria for an achievement. **`GetNumAchievementCriteria` does not exist** (confirmed nil). |
| `GetAchievementCriterion(achievementId, criterionIndex)` | `(description, numCompleted, numRequired)`. **`GetAchievementCriteriaInfo` and `GetAchievementCriterionInfo` do not exist** (confirmed nil). |
| `IsAchievementAccountWide` | **Does not exist** in this API version (confirmed nil). Use `GetAchievementPersistenceLevel` instead. |
| `GetAchievementPersistenceLevel(achievementId)` | Returns an integer persistence level. Compare against `ACHIEVEMENT_PERSISTENCE_LEVEL_ACCOUNT` to identify account-wide achievements. Both the function and the constant may be absent on older API versions — guard with existence checks before using for routing. |
| `GetAchievementTimestamp(achievementId)` | Returns a numeric Unix-style timestamp for when the achievement was completed, or 0/nil if incomplete. More reliable than the date string returned by `GetAchievementInfo` r6 for sorting and comparison. |
| `GetCategoryInfoFromAchievementId(achievementId)` | Returns `(categoryIndex, subCategoryIndex)` for an achievement. Useful for resolving display names when handling real-time award events. |
| `GetFirstAchievementInLine(achievementId)` / `GetPreviousAchievementInLine(achievementId)` / `GetNextAchievementInLine(achievementId)` | Line-chain navigation helpers. Use these to preserve base/previous/next IDs for grouped achievements. |
| `GetCharIdForCompletedAchievement(achievementId)` | Returns the character ID that completed a character-specific achievement when ESO can resolve it. `GetCharacterNameById(id)` can be used to turn that into a display name. |
| `GetAchievementRewardTributeCardUpgradeInfo(achievementId)` | Returns tribute card upgrade reward data when present. Store it as a reward entry rather than trying to flatten it into item/title/dye/collectible. |
| `GetAchievementNumRewards()` | **Does NOT take an achievementId.** Returns a global reward count (confirmed: calling with an achId arg still returns the same large global value). Do not use to iterate per-achievement rewards — use this only to check if the rewards system is available. |
| `GetAchievementRewardTitle(achievementId)` | Returns `(titleId, titleName)` or similar for the title reward. Call once per achievement — does NOT take a reward index. Returns nil/empty if no title reward. |
| `GetAchievementRewardDye(achievementId)` | Returns `(dyeId, dyeName)`. Call once per achievement. |
| `GetAchievementRewardCollectible(achievementId)` | Returns `collectibleId`. Resolve to name via `pcall(GetCollectibleName, cId)` — must be pcall'd. |
| `GetAchievementRewardItem(achievementId)` | Returns `(icon, name, count)` or similar. Call once per achievement. |
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
| `GetItemSetCollectionPieceItemLink(pieceId, linkStyle, traitType)` | Returns an item link string. Use `LINK_STYLE_DEFAULT or 1` and `ITEM_TRAIT_TYPE_NONE or 0`. Must be `pcall`'d. |
| `GetEquipmentFilterTypeForItemSetCollectionSlot(slot)` | Returns an armor/weapon type integer — **NOT** an `ITEM_FILTER_TYPE_*` value despite the name. Unreliable for display; use piece names from `GetItemLinkName` instead. |
| `GetItemLinkName(link)` | Extracts display name from an item link (e.g. "Abyssal Brace Helm"). Must be `pcall`'d. |

## Data structure invariants

- **`chars` keys are always strings.** `GetCurrentCharacterId()` returns a number; wrap it in `tostring()` everywhere or Lua table key comparison will silently fail.
- **Bag IDs are integers, slot IDs are integers** — but they are stored as Lua table keys, which means they become integer-keyed tables. The Python side receives them as dicts with string keys (JSON serialisation). `data_processor.py` handles this by calling `int(bag_id_raw)` and iterating with string keys from the JSON.
- **`enchantId` is always 0.** `CaptureSlot` captures the enchant display name via `GetItemLinkEnchantInfo` but never populates the `enchantId` field. The Python side derives a numeric enchant ID from the item link decoder instead.
- **`abilityNames` / `cpNames` live under each character entry**, not at the top level. The top-level `iasync_data.abilityNames` and `iasync_data.cpNames` are kept for backwards compatibility only and are no longer written to.
- **`iasync_data.stickerbook` is account-wide** (not per-character). Schema:
  ```
  iasync_data.stickerbook = {
      lastUpdate = <unix timestamp>,
      sets = {
          [setId] = {
              name         = "Mara's Balm",
              category     = "Cyrodiil",          -- top-level category name
              subcategory  = "Cyrodiil Rewards",  -- "" if same as category
              numCollected = 7,
              numTotal     = 12,
              pieces = {
                  [i] = {
                      filterType = <integer>,   -- armor/weapon type; unreliable, prefer name
                      collected  = true/false,
                      name       = "Mara's Balm Greaves",  -- from GetItemLinkName
                  }
              }
          }
      }
  }
  ```
  The `sets` table is keyed by numeric setId but serialises to JSON with string keys. `data_processor.py` reads this via `process_iasync_stickerbook(raw)` and serves it at `GET /api/stickerbook`.

- **`build_mundus` is `nil` when no stone is active**, not an empty table. When stones are active it is a Lua sequential table (e.g. `{ "The Lady" }`), which serialises to JSON as `{"1": "The Lady"}`. `data_processor.py` handles both dict and list forms via `list(build_mundus.values()) if isinstance(..., dict) else list(...)`.
- **House data is keyed by house collectible ID as a string**, e.g. `"738"`. The same house ID is used across sessions and characters.
- **Achievement entries now keep line-chain and attribution metadata.** Store `lineBaseId`, `linePreviousId`, `lineNextId`, `completedByCharId`, and `completedByCharName` with the existing achievement payload so the web app can group lines and show who earned a completion.

## Event flow

```
EVENT_ADD_ON_LOADED       → OnAddonLoaded    (initialise iasync_data structure, init stickerbook table)
EVENT_PLAYER_ACTIVATED    → OnPlayerActivated  (fires on login, /reloadui, and zone changes)
    └─ zo_callLater 2 s   → ScanCharacterBags + ResolveBuildNames
    └─ zo_callLater 3 s   → ScanHouseChests (no-op if not in a house)
    └─ zo_callLater 7 s   → ScanStickerbook (account-wide; 7 s gives ITEM_SET_COLLECTIONS_DATA_MANAGER time to populate)
EVENT_ACHIEVEMENTS_UPDATED → ScanAchievements (refresh achievement state when ESO rebuilds it mid-session)
EVENT_OPEN_BANK           → ScanBankBags
EVENT_OPEN_GUILD_BANK     → ScanGuildBank
EVENT_INVENTORY_SINGLE_SLOT_UPDATE → OnInventorySlotUpdate → UpdateSlot
```

## Lua version

ESO runs **Lua 5.1**. Do not use any Lua 5.2+ features:

- **No `goto` / `::labels::`** — use helper functions with early `return` to skip loop iterations instead.
- No integer division operator `//`, no bitwise operators (`&`, `|`, `~`, `<<`, `>>`), no `<const>` / `<close>` attributes.

When you need to skip to the next iteration of an outer loop, extract the loop body into a local function and use `return` to bail early. See `scanCategory()` inside `ScanAchievements` for the established pattern.

## Things to watch out for

**API availability.** Some ESO globals (`HOTBAR_CATEGORY_PRIMARY`, `BAG_HOUSE_CONTAINER_1`, `GetDisplayQuality`) were added or renamed across patches. The addon uses `or`-fallbacks throughout (`HOTBAR_CATEGORY_PRIMARY or 1`). When adding new API calls, check whether they exist on the target APIVersion (currently `101049`) and add a guard if needed.

**`GetAbilityName` returns `""` for out-of-session abilities.** If a Templar logs in and their bars contain Sorcerer skills from a previous character, those ability IDs return empty strings. This is expected — names are resolved only for the current character's loaded skill data. Do not attempt to call `GetAbilityName` for IDs stored from other characters.

**Craft bag iteration.** Never iterate `BAG_VIRTUAL` with a numeric loop. `GetBagSize(BAG_VIRTUAL)` may return a value but slot IDs are not contiguous integers — use `GetNextVirtualBagSlotId` only.

**`pcall` wrapping.** Every ESO API call that could error (slot reads, hotbar reads) is wrapped in `pcall`. If you add a new API call inside `CaptureSlot`, `ScanBuild`, or `ResolveBuildNames`, wrap it too. Errors in slot scanning should be logged to chat with `d(...)` and skipped, not propagated.

**Achievement API shape.** `ScanAchievements` now uses `GetCategoryInfoFromAchievementId`, `GetFirstAchievementInLine`, `GetPreviousAchievementInLine`, `GetNextAchievementInLine`, `GetCharIdForCompletedAchievement`, and `GetAchievementRewardTributeCardUpgradeInfo`. Keep those calls guarded and treat `completedByCharId` / `completedByCharName` as best-effort metadata, not guaranteed values.

**`zo_callLater` delay for house chests.** Do not remove or shorten the 3-second delay. The container bag API (`GetBagSize`) returns 0 for house bags immediately after `EVENT_PLAYER_ACTIVATED` fires; the delay gives the game time to populate the data.

**`GetEquipmentFilterTypeForItemSetCollectionSlot` is misnamed.** Despite the name, it does NOT return `ITEM_FILTER_TYPE_*` values (which map to "Armor", "Weapons", etc.). It returns armor/weapon sub-type integers that are not useful for user-facing display. Always use the piece name from `GetItemLinkName` instead.

**Stickerbook two-level category hierarchy.** `ITEM_SET_COLLECTIONS_DATA_MANAGER` exposes a two-level hierarchy: TopLevelCategories (e.g. "Dungeons") → Subcategories (e.g. "Elden Hollow") → Sets. When recursing through `SubcategoryIterator`, thread both `topName` (the top-level category) and `subName` (the current sub-level) separately. Do NOT overwrite `topName` during recursion — all sets in a top category must share the same category name for the UI grouping to work correctly.

**Two `/reloadui` cycles needed after adding new scan code.** The first `/reloadui` loads the new Lua file but writes the *old* SavedVariables structure (from the prior session). The second `/reloadui` actually writes the results of the new scan. Verify output after the *second* reloadui.

**`slot` from `GetItemSetCollectionPieceInfo` is id64 userdata.** Never store it as an integer or call `tostring()` on it for use as a key. Pass it directly to `IsItemSetCollectionSlotUnlocked` and `GetEquipmentFilterTypeForItemSetCollectionSlot`.

**Guild bank multi-guild ambiguity.** `ScanGuildBank` stores data under the first guild's name it finds. If a player is in multiple guilds with guild banks, only the open one is scanned but there is currently no API to identify which guild bank is open. This is a known limitation.

## Making schema changes

If you add a new field to any stored table:
1. Add it in the relevant scan function (`ScanCharacterBags`, `ScanBuild`, `CaptureSlot`, etc.)
2. Initialise it with a safe default (do not leave it `nil` if the Python side expects it to always be present)
3. Update `data_processor.py` to read the new field — use `.get("field", default)` to stay backwards compatible with existing SavedVariables files that predate the change
4. Update the schema section in `README.md`

## Git and release policy

**Never perform any git actions** (commit, add, push, tag, reset, etc.). Do not stage files or create commits under any circumstances.

When the user requests a **pre-commit** / release preparation:
1. Update `README.md` with any relevant changes
2. Update `CHANGELOG.md` (create it if absent) with a new entry for the version
3. Bump the version number in `iasync.txt` (the `## Version:` line)

Stop there. Do not run any git commands after completing those three steps.

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
