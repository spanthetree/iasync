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

## Data structure invariants

- **`chars` keys are always strings.** `GetCurrentCharacterId()` returns a number; wrap it in `tostring()` everywhere or Lua table key comparison will silently fail.
- **Bag IDs are integers, slot IDs are integers** — but they are stored as Lua table keys, which means they become integer-keyed tables. The Python side receives them as dicts with string keys (JSON serialisation). `data_processor.py` handles this by calling `int(bag_id_raw)` and iterating with string keys from the JSON.
- **`enchantId` is always 0.** `CaptureSlot` captures the enchant display name via `GetItemLinkEnchantInfo` but never populates the `enchantId` field. The Python side derives a numeric enchant ID from the item link decoder instead.
- **`abilityNames` / `cpNames` live under each character entry**, not at the top level. The top-level `iasync_data.abilityNames` and `iasync_data.cpNames` are kept for backwards compatibility only and are no longer written to.
- **`build_mundus` is `nil` when no stone is active**, not an empty table. When stones are active it is a Lua sequential table (e.g. `{ "The Lady" }`), which serialises to JSON as `{"1": "The Lady"}`. `data_processor.py` handles both dict and list forms via `list(build_mundus.values()) if isinstance(..., dict) else list(...)`.
- **House data is keyed by house collectible ID as a string**, e.g. `"738"`. The same house ID is used across sessions and characters.

## Event flow

```
EVENT_ADD_ON_LOADED       → OnAddonLoaded    (initialise iasync_data structure)
EVENT_PLAYER_ACTIVATED    → OnPlayerActivated  (fires on login, /reloadui, and zone changes)
    └─ zo_callLater 2 s   → ScanCharacterBags + ResolveBuildNames
    └─ zo_callLater 3 s   → ScanHouseChests (no-op if not in a house)
EVENT_OPEN_BANK           → ScanBankBags
EVENT_OPEN_GUILD_BANK     → ScanGuildBank
EVENT_INVENTORY_SINGLE_SLOT_UPDATE → OnInventorySlotUpdate → UpdateSlot
```

## Things to watch out for

**API availability.** Some ESO globals (`HOTBAR_CATEGORY_PRIMARY`, `BAG_HOUSE_CONTAINER_1`, `GetDisplayQuality`) were added or renamed across patches. The addon uses `or`-fallbacks throughout (`HOTBAR_CATEGORY_PRIMARY or 1`). When adding new API calls, check whether they exist on the target APIVersion (currently `101049`) and add a guard if needed.

**`GetAbilityName` returns `""` for out-of-session abilities.** If a Templar logs in and their bars contain Sorcerer skills from a previous character, those ability IDs return empty strings. This is expected — names are resolved only for the current character's loaded skill data. Do not attempt to call `GetAbilityName` for IDs stored from other characters.

**Craft bag iteration.** Never iterate `BAG_VIRTUAL` with a numeric loop. `GetBagSize(BAG_VIRTUAL)` may return a value but slot IDs are not contiguous integers — use `GetNextVirtualBagSlotId` only.

**`pcall` wrapping.** Every ESO API call that could error (slot reads, hotbar reads) is wrapped in `pcall`. If you add a new API call inside `CaptureSlot`, `ScanBuild`, or `ResolveBuildNames`, wrap it too. Errors in slot scanning should be logged to chat with `d(...)` and skipped, not propagated.

**`zo_callLater` delay for house chests.** Do not remove or shorten the 3-second delay. The container bag API (`GetBagSize`) returns 0 for house bags immediately after `EVENT_PLAYER_ACTIVATED` fires; the delay gives the game time to populate the data.

**Guild bank multi-guild ambiguity.** `ScanGuildBank` stores data under the first guild's name it finds. If a player is in multiple guilds with guild banks, only the open one is scanned but there is currently no API to identify which guild bank is open. This is a known limitation.

## Making schema changes

If you add a new field to any stored table:
1. Add it in the relevant scan function (`ScanCharacterBags`, `ScanBuild`, `CaptureSlot`, etc.)
2. Initialise it with a safe default (do not leave it `nil` if the Python side expects it to always be present)
3. Update `data_processor.py` to read the new field — use `.get("field", default)` to stay backwards compatible with existing SavedVariables files that predate the change
4. Update the schema section in `README.md`

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
