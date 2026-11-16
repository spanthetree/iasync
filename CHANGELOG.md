# Changelog

All notable changes to iasync will be documented here.

## [Unreleased]

## [1.3.4] — 2026-11-16

### Added

- MIT license

### Changed

- README rewritten for a public audience
- `.gitignore` excludes local `.claude/` settings

## [1.3.3] — 2026-11-16

### Changed

- `APIVersion` bumped from `101049` to `101051` (Update 51); all globals verified against the 101051 `ESOUIDocumentation.txt`

### Fixed

- Account-wide achievements were never detected — routing checked the nonexistent `ACHIEVEMENT_PERSISTENCE_LEVEL_ACCOUNT`; now uses `ACHIEVEMENT_PERSISTENCE_ACCOUNT` via `IsAccountWideAchievement`. Existing data will move from `chars[id].achievements` to `achievements.account` on next scan
- Real-time achievement awards were never recorded — `EVENT_ACHIEVEMENT_AWARDED` handler read the name arg as the ID; now reads `(eventCode, name, points, id)`
- Daggers labelled "Restoration Staff" and resto staffs unlabelled — `WEAPONTYPE_RUNESTAFF` no longer exists and its fallback (11) is the dagger ID; now uses `WEAPONTYPE_HEALING_STAFF` and drops the incorrect numeric fallbacks
- Item rewards stored the icon path as `name` and display quality as `qty` — now parsed per the documented `(hasReward, itemName, icon, quality)` shape; `qty` removed
- House bag start constant renamed `BAG_HOUSE_CONTAINER_1` → `BAG_HOUSE_BANK_ONE`; removed dead fallbacks to nonexistent `GetCurrentZoneId` and `IsAchievementAccountWide`

## [1.3.2] — 2026-06-11

### Added

- Werewolf skill bar capture — `ScanBuild` now reads `HOTBAR_CATEGORY_WEREWOLF` (slots 3–8) and stores it as `build_bars.werewolf`; omitted entirely for non-werewolf characters

## [1.3.1] — 2026-05-21

### Changed

- Achievement capture now preserves line chain IDs, completion attribution, hidden-progress category flags, achievement counts, and tribute card upgrade rewards.
- `EVENT_ACHIEVEMENTS_UPDATED` now triggers a rescan so achievement data can refresh when ESO rebuilds the achievement state mid-session.

## [1.3.0] — 2026-05-20

### Changed

**Stickerbook piece names**
- `ScanStickerbook` now captures each piece's display name via `GetItemSetCollectionPieceItemLink` + `GetItemLinkName` (e.g. `"Mara's Balm Greaves"`)
- `filterName` field removed from pieces — `GetEquipmentFilterTypeForItemSetCollectionSlot` returns armor/weapon sub-type integers that are not reliable for display; piece names are used instead
- Each piece entry now: `{ filterType, collected, name }`

---

## [1.2.0] — 2026-05-20

### Added

**Armor weight and weapon type per slot**
- `CaptureSlot` now calls `GetItemLinkArmorType` and `GetItemLinkWeaponType` on the item link and resolves each to a display string via inline lookup tables (`ARMOR_TYPE_NAMES`, `WEAPON_TYPE_NAMES`)
- `armorType` field: `"Light"`, `"Medium"`, or `"Heavy"` — `nil` for non-armor items
- `weaponType` field: `"Sword"`, `"Axe"`, `"Hammer"`, `"Dagger"`, `"Two-Handed Sword"`, `"Two-Handed Axe"`, `"Two-Handed Hammer"`, `"Inferno Staff"`, `"Ice Staff"`, `"Lightning Staff"`, `"Restoration Staff"`, `"Bow"`, or `"Shield"` — `nil` for non-weapon items
- Uses per-element destruction staff constants (`WEAPONTYPE_FIRE_STAFF`, `WEAPONTYPE_FROST_STAFF`, `WEAPONTYPE_LIGHTNING_STAFF`) with sequential fallbacks (8–13) covering Restoration Staff (11), Bow (12), and Shield (13)

**Stickerbook (item set collection)**
- `ScanStickerbook()` iterates all item set collection categories via `ITEM_SET_COLLECTIONS_DATA_MANAGER`
- Per-set capture: name, category, subcategory, `numCollected`, `numTotal`, and per-piece collected status + filter type
- Stored in `iasync_data.stickerbook.sets` keyed by set ID
- Called from `OnPlayerActivated` (7 s delay) and from `iasync_scan()`
- `iasync_data.stickerbook` initialised in `OnAddonLoaded`

## [1.1.0] — 2026-05-19

### Added

**Achievement scanning**
- `ScanAchievements()` iterates all categories and subcategories via `GetNumAchievementCategories` / `GetAchievementCategoryInfo` / `GetAchievementSubCategoryInfo` / `GetAchievementId`
- Per-achievement capture: name, description, points, icon, completion status, completion date, Unix completion timestamp (`GetAchievementTimestamp`), persistence level (`GetAchievementPersistenceLevel`), criteria progress (`GetAchievementNumCriteria` / `GetAchievementCriterion`), and rewards (title, dye, collectible, item)
- Account-wide achievements routed to `iasync_data.achievements.account`; character-specific achievements stored under `chars[charId].achievements`
- Category and subcategory summaries with API-provided `earnedPts` / `totalPts` (match in-game UI) plus computed `total` / `complete` counts
- `EVENT_ACHIEVEMENT_AWARDED` handler (`OnAchievementAwarded`) for real-time updates on mid-session unlocks
- `ScanAchievements` called from `OnPlayerActivated` (5 s delay) and from `iasync_scan()`
- `iasync_data.achievements` initialised in `OnAddonLoaded`

**Account name capture**
- `iasync_data.accountName` populated via `GetDisplayName()` on every character scan

### Changed

- Removed multi-line block comments that restated what the code already said; retained only non-obvious constraint comments

## [1.0.0] — 2026-05-19

Initial release.

### Added

**Character scanning (on login / `/reloadui` / zone change)**
- Equipped gear (`BAG_WORN`) and backpack (`BAG_BACKPACK`) — item link, name, quantity, trait type + resolved trait name, enchant display name, set name + set ID, quality, filter type
- Inventory capacity tracking (`spaceUsed` / `spaceMax`)
- Character identity — name, race, class, alliance
- Currency snapshot — Gold, Alliance Points, Tel Var Stones, Writ Vouchers (character location)
- Skill bars (primary and backup) — ability IDs for slots 3–7 and ultimate slot 8, with crafted/scribing ability resolution via `GetAbilityIdForCraftedAbilityId`
- Champion Point snapshot — total earned points and 12 slotted star IDs
- Attribute point allocations (Health / Magicka / Stamina)
- Active Mundus Stone detection via buff scan (supports multiple stones, e.g. Steed of the North set)
- Per-character ability name resolution (`abilityNames`) and CP star name resolution (`cpNames`) — stored under each character entry so logins never overwrite another character's resolved names

**Bank scanning (on bank open)**
- Personal bank (`BAG_BANK`) and ESO Plus overflow bank (`BAG_SUBSCRIBER_BANK`)
- Craft bag (`BAG_VIRTUAL`) using `GetNextVirtualBagSlotId` linked-list iterator
- Bank currency snapshot — Gold, Alliance Points, Tel Var Stones, Writ Vouchers (bank location)

**House chest scanning (3 s after house entry)**
- Up to 10 storage chests per house, probed via `GetBagSize`
- Houses keyed by collectible ID (from `GetCurrentZoneHouseId`) with display name via `GetCollectibleName`
- Per-chest metadata: slot contents, capacity, 1-based chest number, `lastUpdate` timestamp

**Guild bank scanning (on guild bank open)**
- Full contents of `BAG_GUILDBANK`, stored under the guild name
- Note: guild bank data is captured in SavedVariables but is not currently read by the ESO Armory web app

**Real-time updates**
- `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` handler keeps all bag types current without a full re-scan; routes updates to the correct storage key (character / bank / guild bank / house chest)

**Trait name lookup table**
- Inline `TRAIT_NAMES` table covering all weapon, armor, jewelry, and scribing traits (indices 1–33, 52–60), eliminating the need for Python-side resolution

**Manual rescan command**
- `/script iasync_scan()` re-runs character bag scan and ability name resolution for the current character

**Error protection and compatibility**
- All ESO API calls inside `CaptureSlot`, `ScanBuild`, and `ResolveBuildNames` are wrapped in `pcall`; slot-scan errors are logged to chat via `d(...)` and skipped without aborting the full scan
- API availability guards throughout — ESO globals that were added or renamed across patches (`HOTBAR_CATEGORY_PRIMARY`, `BAG_HOUSE_CONTAINER_1`, `GetItemDisplayQuality`) use `or`-fallbacks so the addon runs on any API version at or below `101049`

**Backward compatibility**
- Legacy top-level `iasync_data.abilityNames` and `iasync_data.cpNames` tables initialised on load and preserved in SavedVariables; no longer actively written to (per-character entries are used instead)

**Addon manifest**
- `APIVersion: 101049`, `SavedVariables: iasync_data`

**Documentation**
- `README.md` — installation, full SavedVariables schema, design notes, iifa comparison
- `AGENTS.md` — coding guide for AI agents: invariants, event flow, known pitfalls, schema change checklist
