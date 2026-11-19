# Changelog

All notable changes to iasync are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.17.0] — 2026-11-19

### Added

- `lastKnown` on missing Armory gear: the item an earlier scan saw in that slot (link, name, set, trait and the other item fields), since the game gives no details for a missing item. Absent if iasync never saw the item.

## [1.16.1] — 2026-11-19

### Fixed

- Armory gear in the `missing` state was saved with the item in backpack slot 0, because the game reports a placeholder location for missing items. Missing slots now hold only `state = "missing"`. Rebuilt on the next scan.

## [1.16.0] — 2026-11-19

### Added

- **Armory builds** (`chars[id].armoryBuilds`): every build saved at an in-game Armory station, with name, icon, gear (current location and state: `valid`, `inaccessible` or `missing`), saved and effective skill bars, slotted Champion stars, Champion points per discipline, attributes, total skill points, Mundus Stone(s), curse and outfit (index and name). Rescanned on login and whenever a build is saved, restored or renamed.
- Skill names and icons for abilities on Armory build bars.
- `barsUpdate` on each Armory build. Skill bars and Champion stars only load at an Armory station, so scans elsewhere keep the last ones read.
- A [FAQ](docs/faq.md) on what iasync does and how it works, and a [game API reference](docs/api.md) mapping each part of the file to the ESO functions and events behind it.

### Changed

- Documentation restructured: a shorter README, the SavedVariables schema in [docs/schema.md](docs/schema.md), and a consistent changelog.
- The addon description in `iasync.txt` covers everything iasync exports, not only builds.

## [1.15.0] — 2026-11-18

### Added

- Per-character ability icon paths from `GetAbilityIcon`, keyed by ability ID, for ESO Armory 0.2.0-beta.9.
- Name and icon resolution for the logged-in character's saved [Wizard's Wardrobe](https://www.esoui.com/downloads/info3170-WizardsWardrobe.html) skills, including skills absent from equipped bars.

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

- Set collection pieces carry their display name (`name`, from `GetItemSetCollectionPieceItemLink` and `GetItemLinkName`), e.g. "Mara's Balm Greaves".
- `filterName` removed from pieces: `GetEquipmentFilterTypeForItemSetCollectionSlot` returns armor and weapon sub-types, not display categories.

## [1.2.0] — 2026-05-20

### Added

- Armor weight (`armorType`: "Light", "Medium" or "Heavy") and weapon type (`weaponType`, e.g. "Inferno Staff") on every item slot, `nil` where they don't apply.
- Set collections (`stickerbook.sets`, keyed by set ID): name, category, subcategory, pieces collected and total, and each piece's collected state. Scanned 7 s after login.

## [1.1.0] — 2026-05-19

### Added

- Achievements: every achievement with name, description, points, icon, completion date and timestamp, persistence level, criteria progress and rewards (title, dye, collectible, item). Account-wide achievements go in `achievements.account`, the rest under each character. Category and subcategory point totals match the in-game summary. Scanned 5 s after login and on `EVENT_ACHIEVEMENT_AWARDED`.
- Account name (`accountName`).

## [1.0.0] — 2026-05-19

Initial release.

### Added

- Character scan on login, `/reloadui` and zone change: equipped gear and backpack (link, name, quantity, trait, enchant, set, quality, filter type), backpack capacity, name, race, class, alliance, and Gold, Alliance Points, Tel Var Stones and Writ Vouchers.
- Build: front and back bars (scribed skills resolved to their base ability), Champion Points earned and slotted stars, attributes, and active Mundus Stone(s), with skill and star names per character.
- Bank, ESO Plus bank and craft bag when the bank opens, with banked currencies.
- House storage chests, 3 s after entering a house.
- Guild bank contents when it opens.
- Real-time slot updates from `EVENT_INVENTORY_SINGLE_SLOT_UPDATE`.
- `/script iasync_scan()` to rescan on demand.
