-- iasync: Inventory Armory Sync for ESO Armory web app.
-- Scans character bags, bank (on open), house chests (when in house), and guild bank (on open).
-- Captures trait/enchant/set enrichment and resolves skill/CP ability names.

iasync = {}
iasync_data = {}

local ADDON_NAME = "iasync"

-- ── Trait name lookup ────────────────────────────────────────────────────────
-- Mirrors item_link_decoder.py TRAIT_NAMES so Python needs no extra resolution.

local TRAIT_NAMES = {
    [1]  = "Powered",       [2]  = "Charged",       [3]  = "Precise",
    [4]  = "Infused",       [5]  = "Defending",      [6]  = "Training",
    [7]  = "Sharpened",     [8]  = "Decisive",       [9]  = "Intricate",
    [10] = "Ornate",        [26] = "Nirnhoned",
    [11] = "Sturdy",        [12] = "Impenetrable",   [13] = "Reinforced",
    [14] = "Well-Fitted",   [15] = "Training",       [16] = "Infused",
    [17] = "Prosperous",    [18] = "Divines",        [19] = "Ornate",
    [20] = "Intricate",     [25] = "Nirnhoned",
    [21] = "Healthy",       [22] = "Arcane",         [23] = "Robust",
    [24] = "Ornate",        [27] = "Intricate",      [28] = "Swift",
    [29] = "Harmony",       [30] = "Triune",         [31] = "Bloodthirsty",
    [32] = "Protective",    [33] = "Infused",
    [52] = "Quickened",     [53] = "Prolific",       [54] = "Focused",
    [55] = "Shattering",    [56] = "Aggressive",     [57] = "Soothing",
    [58] = "Augmented",     [59] = "Bolstered",      [60] = "Vigorous",
}

-- ── Bag configuration ────────────────────────────────────────────────────────

-- Resolve quality function once at load time; fall back through two API names.
local _qualityFn = GetItemDisplayQuality or GetItemQuality or function() return 1 end

local CHAR_BAGS  = { BAG_WORN, BAG_BACKPACK }
-- BAG_VIRTUAL is the craft bag. It uses a different iterator (GetNextVirtualBagSlotId)
-- so it is handled separately in ScanVirtualBag rather than included in BANK_BAGS.
local BANK_BAGS  = { BAG_BANK, BAG_SUBSCRIBER_BANK }

local IS_CHAR_BAG = {}
for _, b in ipairs(CHAR_BAGS) do IS_CHAR_BAG[b] = true end
local IS_BANK_BAG = {}
for _, b in ipairs(BANK_BAGS) do IS_BANK_BAG[b] = true end
IS_BANK_BAG[BAG_VIRTUAL] = true  -- craft bag slot updates share the bank storage key

-- House container bag IDs start at 7 (chest 1 = bag 7, chest 2 = bag 8, ...).
-- ESO allows up to 10 containers per house. We probe via GetBagSize to confirm
-- which IDs are actually present rather than assuming a fixed count.
-- Use BAG_HOUSE_CONTAINER_1 constant if defined; fall back to literal 7.
local HOUSE_BAG_START = (type(BAG_HOUSE_CONTAINER_1) == "number") and BAG_HOUSE_CONTAINER_1 or 7
local HOUSE_BAG_COUNT = 10

local function IsHouseBag(bagId)
    return bagId >= HOUSE_BAG_START and bagId < HOUSE_BAG_START + HOUSE_BAG_COUNT
end

-- ── Per-slot capture (used for every bag type) ───────────────────────────────

local function CaptureSlot(bagId, slot)
    local itemName = GetItemName(bagId, slot)
    if not itemName or itemName == "" then return nil end

    local link = GetItemLink(bagId, slot, LINK_STYLE_BRACKETS)

    -- Trait
    local traitType = GetItemTrait(bagId, slot)
    local traitName = TRAIT_NAMES[traitType]

    -- Enchantment: GetItemLinkEnchantInfo returns (hasEnchant, enchantName).
    -- The second return is the display name string directly, not an ability ID.
    local enchantId   = 0
    local enchantName = nil
    local hasEnchant, enchantStr = GetItemLinkEnchantInfo(link)
    if hasEnchant and type(enchantStr) == "string" and enchantStr ~= "" then
        enchantName = enchantStr
    end

    -- Set membership: GetItemLinkSetInfo returns (hasSet, name, bonuses, equipped, max, id)
    local setName = nil
    local setId   = nil
    local hasSet, sName, _, _, _, sId = GetItemLinkSetInfo(link)
    if hasSet and sName and sName ~= "" then
        setName = sName
        setId   = sId
    end

    -- Quality and filter type (first return of GetItemFilterTypeInfo)
    local quality    = _qualityFn(bagId, slot)
    local filterType = GetItemFilterTypeInfo(bagId, slot)

    -- GetItemInfo returns (icon, stackCount, sellPrice, ...). The second value is
    -- the stack count and works correctly for all bag types including BAG_VIRTUAL.
    local qty = select(2, GetItemInfo(bagId, slot)) or 1

    return {
        link        = link,
        name        = itemName,
        traitType   = traitType,
        traitName   = traitName,
        enchantId   = enchantId,
        enchantName = enchantName,
        setName     = setName,
        setId       = setId,
        quality     = quality,
        filterType  = filterType,
        qty         = qty,
    }
end

local function ScanBag(bagId)
    local slots = {}
    for slot = 0, GetBagSize(bagId) - 1 do
        local ok, data = pcall(CaptureSlot, bagId, slot)
        if ok and data then
            slots[slot] = data
        elseif not ok then
            d(string.format("[iasync] slot error bag=%d slot=%d: %s", bagId, slot, tostring(data)))
        end
    end
    return slots
end

-- ── Character build snapshot (bars, attributes, mundus, CP) ─────────────────

local function ScanBuild(c)
    -- Action bars: slots 3-7 = skills, slot 8 = ultimate.
    -- HOTBAR_CATEGORY_PRIMARY/BACKUP are ESO globals; fall back to 1/2 if undefined.
    local primaryCat = HOTBAR_CATEGORY_PRIMARY or 1
    local backupCat  = HOTBAR_CATEGORY_BACKUP  or 2
    local buildBars  = {}
    for _, cfg in ipairs({ { "primary", primaryCat }, { "backup", backupCat } }) do
        local barName, cat = cfg[1], cfg[2]
        local bar = {}
        for slot = 3, 8 do
            local ok, aid = pcall(GetSlotBoundId, slot, cat)
            if ok and aid and aid ~= 0 then
                local ok2, aType = pcall(GetSlotType, slot, cat)
                if ok2 and aType == ACTION_TYPE_CRAFTED_ABILITY then
                    local ok3, baseId = pcall(GetAbilityIdForCraftedAbilityId, aid)
                    if ok3 and baseId and baseId ~= 0 then aid = baseId end
                end
                bar[slot] = aid
            end
        end
        buildBars[barName] = bar
    end
    c.build_bars = buildBars

    -- Attribute points spent by the player (not including base stats from race/class).
    local attrs = {}
    for _, pair in ipairs({
        { "health",  ATTRIBUTE_HEALTH  or 1 },
        { "magicka", ATTRIBUTE_MAGICKA or 2 },
        { "stamina", ATTRIBUTE_STAMINA or 3 },
    }) do
        local attrName, attrConst = pair[1], pair[2]
        local ok, pts = pcall(GetAttributeSpentPoints, attrConst)
        attrs[attrName] = (ok and pts) or 0
    end
    c.build_attributes = attrs

    -- Mundus stone (boon): permanent buff whose icon path contains "mundus".
    -- ESO prefixes the buff name with "Boon: "; strip it for clean storage.
    -- A player with the Steed of the North set may have two active stones.
    local mundusStones = {}
    if GetNumBuffs then
        local ok, numBuffs = pcall(GetNumBuffs, "player")
        if ok and numBuffs then
            for i = 1, numBuffs do
                local ok2, bName, _, _, _, _, bIcon = pcall(GetUnitBuffInfo, "player", i)
                if ok2 and bIcon and bIcon ~= "" and bIcon:lower():find("mundus") then
                    local stoneName = bName:gsub("^Boon:%s*", "")
                    mundusStones[#mundusStones + 1] = stoneName
                end
            end
        end
    end
    c.build_mundus = (#mundusStones > 0) and mundusStones or nil

    -- Champion points: slotted skills live on HOTBAR_CATEGORY_CHAMPION, slots 1-12.
    -- Confirmed via ESO API: GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION), slots 1-12.
    local cpEarned = 0
    local ok0, pts = pcall(GetPlayerChampionPointsEarned)
    if ok0 and pts then cpEarned = pts end

    local cpSlots = {}
    local cpCat = HOTBAR_CATEGORY_CHAMPION
    for slot = 1, 12 do
        local ok, aid = pcall(GetSlotBoundId, slot, cpCat)
        if ok and aid and aid ~= 0 then
            local ok2, aType = pcall(GetSlotType, slot, cpCat)
            if ok2 and aType == ACTION_TYPE_CRAFTED_ABILITY then
                local ok3, baseId = pcall(GetAbilityIdForCraftedAbilityId, aid)
                if ok3 and baseId and baseId ~= 0 then aid = baseId end
            end
            cpSlots[slot] = aid
        end
    end
    c.build_cp = { earned = cpEarned, slots = cpSlots }
end

-- ── Character bags (on login) ────────────────────────────────────────────────

local function ScanCharacterBags()
    local charId = tostring(GetCurrentCharacterId())
    d(string.format("[iasync] Scanning character bags (id=%s)...", charId))
    iasync_data.chars[charId] = iasync_data.chars[charId] or {}
    local c = iasync_data.chars[charId]

    c.name     = GetUnitName("player")
    c.race     = (GetUnitRace("player"))
    c.class    = (GetUnitClass("player"))
    c.alliance = GetAllianceName(GetUnitAlliance("player"))
    c.bags = {}

    for _, bagId in ipairs(CHAR_BAGS) do
        c.bags[bagId] = ScanBag(bagId)
    end

    local backpackSize = GetBagSize(BAG_BACKPACK)
    local used = 0
    for _ in pairs(c.bags[BAG_BACKPACK] or {}) do used = used + 1 end
    c.spaceUsed = used
    c.spaceMax  = backpackSize

    c.gold = GetCurrencyAmount(CURT_MONEY,           CURRENCY_LOCATION_CHARACTER) or 0
    c.ap   = GetCurrencyAmount(CURT_ALLIANCE_POINTS, CURRENCY_LOCATION_CHARACTER) or 0
    c.tv   = GetCurrencyAmount(CURT_TELVAR_STONES,   CURRENCY_LOCATION_CHARACTER) or 0
    c.wv   = GetCurrencyAmount(CURT_WRIT_VOUCHERS,   CURRENCY_LOCATION_CHARACTER) or 0
    c.lastUpdate = GetTimeStamp()

    ScanBuild(c)

    local equippedCount = 0
    for _ in pairs(c.bags[BAG_WORN]     or {}) do equippedCount = equippedCount + 1 end
    local invCount = 0
    for _ in pairs(c.bags[BAG_BACKPACK] or {}) do invCount = invCount + 1 end
    local mundusStr = (c.build_mundus and table.concat(c.build_mundus, ", ")) or "none"
    local cpSlotCount = 0
    for _ in pairs(c.build_cp and c.build_cp.slots or {}) do cpSlotCount = cpSlotCount + 1 end
    d(string.format("[iasync] '%s' scanned · equipped: %d · inventory: %d/%d · mundus: %s · CP: %d pts / %d slotted",
        c.name, equippedCount, invCount, backpackSize, mundusStr,
        c.build_cp and c.build_cp.earned or 0, cpSlotCount))
end

-- ── Personal bank (on open) ──────────────────────────────────────────────────
-- Bank bags are inaccessible at login; scan only when the player opens the bank UI.

-- BAG_VIRTUAL (craft bag) uses a linked-list iterator instead of numeric slots.
-- GetNextVirtualBagSlotId(nil) returns the first slot; subsequent calls advance it.
local function ScanVirtualBag()
    local slots = {}
    local slotId = GetNextVirtualBagSlotId(nil)
    while slotId ~= nil do
        local data = CaptureSlot(BAG_VIRTUAL, slotId)
        if data then slots[slotId] = data end
        slotId = GetNextVirtualBagSlotId(slotId)
    end
    return slots
end

local function ScanBankBags()
    local bank = iasync_data.bank
    bank.bags = bank.bags or {}

    for _, bagId in ipairs(BANK_BAGS) do
        bank.bags[bagId] = ScanBag(bagId)
    end

    -- Craft bag (BAG_VIRTUAL) requires its own iterator
    bank.bags[BAG_VIRTUAL] = ScanVirtualBag()

    -- Bank currency is readable while the bank is open
    bank.gold = GetCurrencyAmount(CURT_MONEY,           CURRENCY_LOCATION_BANK) or bank.gold or 0
    bank.ap   = GetCurrencyAmount(CURT_ALLIANCE_POINTS, CURRENCY_LOCATION_BANK) or bank.ap   or 0
    bank.tv   = GetCurrencyAmount(CURT_TELVAR_STONES,   CURRENCY_LOCATION_BANK) or bank.tv   or 0
    bank.wv   = GetCurrencyAmount(CURT_WRIT_VOUCHERS,   CURRENCY_LOCATION_BANK) or bank.wv   or 0
    bank.lastUpdate = GetTimeStamp()
    local craftCount = 0
    for _ in pairs(bank.bags[BAG_VIRTUAL] or {}) do craftCount = craftCount + 1 end
    d(string.format("[iasync] Bank scanned · craft bag: %d items", craftCount))
end

-- ── House chests (when entering a house) ─────────────────────────────────────
-- House container bags are only accessible while in the house. We probe each
-- bag ID in the house range and store only those with GetBagSize > 0.
-- A short delay is used so container data has time to load after zone transition.

local function GetHouseKey()
    -- GetCurrentZoneHouseId() returns the collectible ID of the current house.
    -- GetCollectibleName() resolves it to a display string (e.g. "Mournhold Suite").
    if GetCurrentZoneHouseId then
        local houseId = GetCurrentZoneHouseId()
        if houseId and houseId > 0 then
            local name = GetCollectibleName and GetCollectibleName(houseId) or ("House " .. houseId)
            return tostring(houseId), name
        end
    end
    -- Fallback: use current zone ID if housing API is unavailable
    local zoneId = GetCurrentZoneId and GetCurrentZoneId() or 0
    return tostring(zoneId), "House"
end

local function ScanHouseChests()
    -- Use GetCurrentZoneHouseId() as the house detection; returns 0 when not in a house.
    -- IsPlayerInHouse() is not a standard ESO API function.
    local houseKey, houseName = GetHouseKey()
    if houseKey == "0" then return end
    iasync_data.houses[houseKey] = iasync_data.houses[houseKey] or {}
    local houseData = iasync_data.houses[houseKey]
    houseData.name   = houseName
    houseData.chests = {}

    local chestCount = 0
    for i = 0, HOUSE_BAG_COUNT - 1 do
        local bagId   = HOUSE_BAG_START + i
        local bagSize = GetBagSize(bagId)
        if bagSize and bagSize > 0 then
            houseData.chests[bagId] = {
                slots      = ScanBag(bagId),
                capacity   = bagSize,
                chestNum   = i + 1,   -- 1-based chest number
                lastUpdate = GetTimeStamp(),
            }
            chestCount = chestCount + 1
        end
    end

    houseData.lastUpdate = GetTimeStamp()
    d(string.format("[iasync] House '%s': %d chest(s) scanned", houseName, chestCount))
end

-- ── Guild bank (on open) ─────────────────────────────────────────────────────

local function ScanGuildBank()
    -- Walk guilds to find an ID; currently stores under first guild found.
    -- TODO: improve multi-guild detection once a GetInteractingGuildId API exists.
    local guildName = "GuildBank"
    for i = 1, GetNumGuilds() do
        local id = GetGuildId(i)
        if id then
            guildName = GetGuildName(id) or ("Guild " .. i)
            break
        end
    end

    iasync_data.guildBanks[guildName] = {
        slots      = ScanBag(BAG_GUILDBANK),
        lastUpdate = GetTimeStamp(),
    }
    d(string.format("[iasync] Guild bank '%s' scanned", guildName))
end

-- ── Build name resolution ────────────────────────────────────────────────────
-- Resolves ability/CP names for the CURRENT character only and stores them on
-- that character's entry. Names are never shared across characters so each login
-- only overwrites its own data, preserving other characters' resolved names.

local function ResolveBuildNames()
    local charId = tostring(GetCurrentCharacterId())
    local c = iasync_data.chars[charId]
    if not c then return end

    local abilityNames, cpNames = {}, {}
    local abilityCount, cpCount = 0, 0

    local bars = c.build_bars or {}
    for _, bar in pairs(bars) do
        if type(bar) == "table" then
            for _, id in pairs(bar) do
                if type(id) == "number" and id > 0 then
                    local name = GetAbilityName(id)
                    if name and name ~= "" then
                        abilityNames[id] = name
                        abilityCount = abilityCount + 1
                    end
                end
            end
        end
    end

    local buildCp = c.build_cp or {}
    local cpSlots = buildCp.slots or {}
    for _, id in pairs(cpSlots) do
        if type(id) == "number" and id > 0 then
            local name = GetChampionSkillName(id)
            if name and name ~= "" then
                cpNames[id] = name
                cpCount = cpCount + 1
            end
        end
    end

    c.abilityNames = abilityNames
    c.cpNames      = cpNames
    iasync_data.lastUpdate = GetTimeStamp()
    d(string.format("[iasync] %d abilities · %d CP stars resolved", abilityCount, cpCount))
end

-- ── Real-time slot updates ───────────────────────────────────────────────────

local function UpdateSlot(bagId, slotIndex)
    local data = CaptureSlot(bagId, slotIndex)  -- nil if slot is now empty

    if IS_CHAR_BAG[bagId] then
        local charId = tostring(GetCurrentCharacterId())
        local c = iasync_data.chars[charId]
        if not c then return end
        c.bags[bagId] = c.bags[bagId] or {}
        c.bags[bagId][slotIndex] = data
        if bagId == BAG_BACKPACK then
            local used = 0
            for _ in pairs(c.bags[BAG_BACKPACK]) do used = used + 1 end
            c.spaceUsed = used
        end

    elseif IS_BANK_BAG[bagId] then
        local bank = iasync_data.bank
        -- BAG_VIRTUAL slot updates use the same slotId key space as ScanVirtualBag
        bank.bags[bagId] = bank.bags[bagId] or {}
        bank.bags[bagId][slotIndex] = data

    elseif bagId == BAG_GUILDBANK then
        for _, gbData in pairs(iasync_data.guildBanks) do
            gbData.slots = gbData.slots or {}
            gbData.slots[slotIndex] = data
            gbData.lastUpdate = GetTimeStamp()
            break
        end

    elseif IsHouseBag(bagId) then
        local houseKey = GetHouseKey()
        if houseKey == "0" then return end
        local houseData = iasync_data.houses[houseKey]
        if not houseData then return end
        houseData.chests[bagId] = houseData.chests[bagId] or { slots = {}, capacity = GetBagSize(bagId) or 0, chestNum = bagId - HOUSE_BAG_START + 1 }
        houseData.chests[bagId].slots[slotIndex] = data
        houseData.chests[bagId].lastUpdate = GetTimeStamp()
    end
end

-- ── Event handlers ───────────────────────────────────────────────────────────

local function OnPlayerActivated()
    zo_callLater(function()
        ScanCharacterBags()
        ResolveBuildNames()
    end, 2000)
    zo_callLater(ScanHouseChests, 3000)
end

local function OnInventorySlotUpdate(_, bagId, slotIndex)
    if IS_CHAR_BAG[bagId] or IS_BANK_BAG[bagId]
        or bagId == BAG_GUILDBANK or IsHouseBag(bagId)
    then
        UpdateSlot(bagId, slotIndex)
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    iasync_data = iasync_data or {}
    iasync_data.chars        = iasync_data.chars        or {}
    iasync_data.bank         = iasync_data.bank         or {}
    iasync_data.bank.bags    = iasync_data.bank.bags    or {}
    iasync_data.guildBanks   = iasync_data.guildBanks   or {}
    iasync_data.houses       = iasync_data.houses       or {}
    iasync_data.abilityNames = iasync_data.abilityNames or {}
    iasync_data.cpNames      = iasync_data.cpNames      or {}
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_Load", EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Load",      EVENT_ADD_ON_LOADED,                OnAddonLoaded)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Player",    EVENT_PLAYER_ACTIVATED,             OnPlayerActivated)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Inv",       EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Bank",      EVENT_OPEN_BANK,                    ScanBankBags)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_GuildBank", EVENT_OPEN_GUILD_BANK,              ScanGuildBank)

-- Manual trigger for testing: /script iasync_scan()
function iasync_scan()
    ScanCharacterBags()
    ResolveBuildNames()
end
