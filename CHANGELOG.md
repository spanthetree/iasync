# Changelog

All notable changes to iasync will be documented here.

## [Unreleased]

## [1.16.0] — 2026-11-19

### Added

- In-game Armory builds per character (`chars[id].armoryBuilds`): name, icon, gear with its current location and state (valid, inaccessible, missing), saved and effective skill bars, slotted Champion stars, Champion points per discipline, attributes, total skill points, Mundus Stone(s), curse and outfit. Rescanned on login and whenever a build is saved, restored or renamed.
- Ability names and icons for skills on Armory build bars.

## [1.15.0] — 2026-11-18

### Added

- Per-character ability icon paths from `GetAbilityIcon`, keyed by ability ID, for ESO Armory 0.2.0-beta.9.
- Name and icon resolution for the logged-in character's saved Wizards Wardrobe skills, including skills absent from equipped bars.

### Fixed

- Retain previously resolved ability names and icons when bars change or an API lookup returns empty or fails.

## [1.14.0] — 2026-11-18

### Added

- Every champion star's name and description, account-wide (top-level `cpNames`, `cpDescriptions`, described at max points), so builds can name stars no scanned character has slotted

## [1.13.0] — 2026-11-18

### Added

- Item icons (`icon` on every captured slot) from `GetItemInfo`, falling back to `GetItemLinkIcon`, in character bags, bank, craft bag, house chests and guild banks

## [1.12.0] — 2026-11-18

### Added

- Currency icons (`currencies[KEY].icon`) from `GetCurrencyKeyboardIcon`, for every currency including character-held ones
- Mundus stone and slotted Champion Point descriptions (`chars[id].mundusDescriptions`, `chars[id].cpDescriptions`), for tooltips

## [1.11.0] — 2026-11-18

### Added

- Activities (`activities`): daily and weekly Endeavors and Tamriel Tome seasonal challenges (`timed`, with progress, max progress, end time and currency reward), per-type reset times (`limits`), Golden Pursuits campaigns (`campaigns`, with each activity's progress, milestones and capstone), and the Tamriel Tome pass (`tome`: level, points, premium ownership, and every tier's free and premium rewards with name, icon and claimed state). Rescanned 2 s after any progress event
- Character details: level, Champion Points, title, zone, riding skill, guild ranks and Alliance War rank
- Every currency (`chars[id].currencies` for character-held, top-level `currencies` for account-held and banked amounts), not only gold, AP, Tel Var and writ vouchers
- Crafting knowledge per character: trait research with research in progress (`research`), known motif chapters (`motifs`) and known recipes (`recipes`)
- Scribing per character (`chars[id].scribing`): grimoires and scripts unlocked
- Antiquities (`antiquities`): leads held with expiry, recoveries and Codex lore entries

## [1.10.0] — 2026-11-18

### Added

- Tales of Tribute patrons (`collectibles.patrons`), only those in the in-game tree (NPC opponents are skipped): name, large/small/suit icons, rarity, neutral flag and patron category (the in-game tree header, e.g. "Patrons" or "Neutral") with its icon and sort order, linked to the patron collectible by `collectibleId`
- Tribute card upgrade rewards now have a `name`, "<upgraded card> (<patron>)"

## [1.9.0] — 2026-11-18

### Added

- Collectibles (`collectibles`): the in-game Collections tree, with each collectible's name, icon, unlocked state and category. Covers mounts, pets, costumes, houses, outfit styles and Tales of Tribute patrons. Each top-level category's `specialization` names its Collections tab

## [1.8.1] — 2026-11-18

### Fixed

- House names (`houses[id].name`) are the house's name, via `GetCollectibleIdForHouse`. Before, the house ID was passed to `GetCollectibleName` as if it were a collectible ID, giving unrelated names such as "Covenant Scout". Re-enter each house to refresh its name
- House chests are scanned only in houses you own (`IsOwnerOfCurrentHouse`). Visiting another player's house used to save it with empty chests; those entries are removed once on load

## [1.8.0] — 2026-11-18

### Fixed

- Guild banks are stored under the guild whose bank is open (`GetSelectedGuildBankId`), not always the first guild
- Guild banks are scanned when their items have loaded (`EVENT_GUILD_BANK_ITEMS_READY`, also after switching guilds), not when the window opens, so the scan is no longer empty or partial
- Every item is captured: guild bank slots are walked with `ZO_GetNextBagSlotIndex` instead of `0..GetBagSize-1`
- Deposits and withdrawals update the right guild bank (rescanned after `EVENT_GUILD_BANK_ITEM_ADDED`/`_REMOVED`/`_UPDATED_QUANTITY`)
- Guild bank data saved by older versions is cleared once, since it was filed under the wrong guild

## [1.7.0] — 2026-11-18

### Added

- Set reconstruction cost (`stickerbook.sets[id].reconCurrency`, `reconCost`), the transmute cost shown in the in-game Sets header
- Set collection piece id and display quality (`pieces[i].id`, `pieces[i].quality`)
- In-game interface colours (`uiColors`: text normal/selected/highlight/disabled/default/contrast/succeeded/second and the XP bar gradient) from `GetInterfaceColor`, as `rrggbb` hex

## [1.6.0] — 2026-11-17

### Added

- Set collection piece icons (`stickerbook.sets[id].pieces[i].icon`) from `GetItemLinkIcon`, so ESO Armory can draw the in-game piece grid
- Top-level set collection category icons (`stickerbook.categoryIcons`)
- Achievement category tree icons (`achievements.categories[i].icon`) from `GetAchievementCategoryKeyboardIcons`

## [1.5.0] — 2026-11-17

### Added

- Maximum Health, Magicka and Stamina (`chars[id].build_pools`) from `GetPlayerStat`, matching the in-game character sheet, including buffs active at scan time such as food

## [1.4.0] — 2026-11-17

### Added

- Character gender (`chars[id].gender`, `"female"` or `"male"`) from `GetUnitGender`, so ESO Armory can show the matching body silhouette. Written on the next login or `/reloadui` per character

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
