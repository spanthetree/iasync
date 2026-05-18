# Changelog

All notable changes to iasync will be documented here.

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
