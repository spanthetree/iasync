-- iasync: Inventory Armory Sync for ESO Armory web app.
-- Scans character bags, bank (on open), house chests (when in house), and each guild bank (when viewed).
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

-- ── Armor weight & weapon type name lookups ─────────────────────────────────

local ARMOR_TYPE_NAMES = {
    [ARMORTYPE_LIGHT   or 1] = "Light",
    [ARMORTYPE_MEDIUM  or 2] = "Medium",
    [ARMORTYPE_HEAVY   or 3] = "Heavy",
}

local WEAPON_TYPE_NAMES = {
    [WEAPONTYPE_SWORD]             = "Sword",
    [WEAPONTYPE_AXE]               = "Axe",
    [WEAPONTYPE_HAMMER]            = "Hammer",
    [WEAPONTYPE_DAGGER]            = "Dagger",
    [WEAPONTYPE_TWO_HANDED_SWORD]  = "Two-Handed Sword",
    [WEAPONTYPE_TWO_HANDED_AXE]    = "Two-Handed Axe",
    [WEAPONTYPE_TWO_HANDED_HAMMER] = "Two-Handed Hammer",
    [WEAPONTYPE_FIRE_STAFF]        = "Inferno Staff",
    [WEAPONTYPE_FROST_STAFF]       = "Ice Staff",
    [WEAPONTYPE_LIGHTNING_STAFF]   = "Lightning Staff",
    [WEAPONTYPE_HEALING_STAFF]     = "Restoration Staff",
    [WEAPONTYPE_BOW]               = "Bow",
    [WEAPONTYPE_SHIELD]            = "Shield",
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
local HOUSE_BAG_START = BAG_HOUSE_BANK_ONE or 7
local HOUSE_BAG_COUNT = 10

local function IsHouseBag(bagId)
    return bagId >= HOUSE_BAG_START and bagId < HOUSE_BAG_START + HOUSE_BAG_COUNT
end

-- ── Per-slot capture (used for every bag type) ───────────────────────────────

local function CaptureSlot(bagId, slot)
    local itemName = GetItemName(bagId, slot)
    if not itemName or itemName == "" then return nil end

    local link = GetItemLink(bagId, slot, LINK_STYLE_BRACKETS)

    local traitType = GetItemTrait(bagId, slot)
    local traitName = TRAIT_NAMES[traitType]

    -- GetItemLinkEnchantInfo returns (hasEnchant, enchantName) — the name directly, not an ID.
    local enchantId   = 0
    local enchantName = nil
    local hasEnchant, enchantStr = GetItemLinkEnchantInfo(link)
    if hasEnchant and type(enchantStr) == "string" and enchantStr ~= "" then
        enchantName = enchantStr
    end

    local setName = nil
    local setId   = nil
    local hasSet, sName, _, _, _, sId = GetItemLinkSetInfo(link)
    if hasSet and sName and sName ~= "" then
        setName = sName
        setId   = sId
    end

    local quality    = _qualityFn(bagId, slot)
    local filterType = GetItemFilterTypeInfo(bagId, slot)
    -- select(2, ...) = stackCount; works for all bag types including BAG_VIRTUAL.
    local qty = select(2, GetItemInfo(bagId, slot)) or 1

    local armorType  = ARMOR_TYPE_NAMES[GetItemLinkArmorType(link)]
    local weaponType = WEAPON_TYPE_NAMES[GetItemLinkWeaponType(link)]

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
        armorType   = armorType,
        weaponType  = weaponType,
    }
end

local function ResolveAchievementCategoryNames(achId)
    if not GetCategoryInfoFromAchievementId then return nil, nil end

    local ok, catIdx, subIdx = pcall(GetCategoryInfoFromAchievementId, achId)
    if not ok or not catIdx or catIdx <= 0 then return nil, nil end

    local catName = nil
    local ok2, name = pcall(GetAchievementCategoryInfo, catIdx)
    if ok2 and type(name) == "string" and name ~= "" then
        catName = name
    end

    local subName = nil
    if subIdx and subIdx > 0 then
        local ok3, sName = pcall(GetAchievementSubCategoryInfo, catIdx, subIdx)
        if ok3 and type(sName) == "string" and sName ~= "" then
            subName = sName
        end
    end

    return catName, subName
end

local function CaptureAchievementLineInfo(achId, entry)
    if not entry then return end

    entry.lineBaseId = achId
    entry.linePreviousId = 0
    entry.lineNextId = 0

    if GetFirstAchievementInLine then
        local ok, baseId = pcall(GetFirstAchievementInLine, achId)
        if ok and type(baseId) == "number" and baseId > 0 then
            entry.lineBaseId = baseId
        end
    end

    if GetPreviousAchievementInLine then
        local ok, prevId = pcall(GetPreviousAchievementInLine, achId)
        if ok and type(prevId) == "number" and prevId > 0 then
            entry.linePreviousId = prevId
        end
    end

    if GetNextAchievementInLine then
        local ok, nextId = pcall(GetNextAchievementInLine, achId)
        if ok and type(nextId) == "number" and nextId > 0 then
            entry.lineNextId = nextId
        end
    end
end

local function CaptureAchievementCompletionInfo(achId, entry)
    if not entry or not entry.complete then return end

    if GetAchievementTimestamp then
        local ok, ts = pcall(GetAchievementTimestamp, achId)
        if ok and ts and ts > 0 then
            entry.completionTimestamp = ts
        end
    end

    if GetCharIdForCompletedAchievement then
        local ok, completedCharId = pcall(GetCharIdForCompletedAchievement, achId)
        if ok and completedCharId then
            local completedCharIdStr = tostring(completedCharId)
            if completedCharIdStr and completedCharIdStr ~= "" then
                entry.completedByCharId = completedCharIdStr
                if GetCharacterNameById then
                    local ok2, completedCharName = pcall(GetCharacterNameById, completedCharId)
                    if ok2 and type(completedCharName) == "string" and completedCharName ~= "" then
                        entry.completedByCharName = completedCharName
                    end
                end
            end
        end
    end
end

local function IsAccountWideAchievement(achId)
    if not (GetAchievementPersistenceLevel and ACHIEVEMENT_PERSISTENCE_ACCOUNT) then return false end
    local ok, lvl = pcall(GetAchievementPersistenceLevel, achId)
    return ok and lvl == ACHIEVEMENT_PERSISTENCE_ACCOUNT
end

-- "<upgraded card> (<patron>)" for a tribute card upgrade reward; nil if the API can't resolve it.
local function TributeCardUpgradeName(patronId, cardIndex)
    local function call(fn, ...)
        if not fn then return nil end
        local ok, a, b = pcall(fn, ...)
        if ok then return a, b end
    end
    local patron = call(GetTributePatronName, patronId)
    local baseId, upgradeId = call(GetTributePatronDockCardInfoByIndex, patronId, cardIndex)
    local card = call(GetTributeCardName, (upgradeId and upgradeId > 0) and upgradeId or baseId)
    if card and card ~= "" and patron and patron ~= "" then return card .. " (" .. patron .. ")" end
    if card and card ~= "" then return card end
    return nil
end

local function CaptureAchievementRewards(achId)
    local rewards = {}

    if GetAchievementRewardTitle then
        local ok, a, b = pcall(GetAchievementRewardTitle, achId)
        if ok then
            local tId   = type(a) == "number" and a or nil
            local tName = type(b) == "string" and b ~= "" and b
                       or type(a) == "string" and a ~= "" and a or nil
            if tName then rewards[#rewards + 1] = { type = "title", name = tName, id = tId } end
        end
    end

    if GetAchievementRewardDye then
        local ok, a, b, c = pcall(GetAchievementRewardDye, achId)
        if ok then
            local dId   = type(a) == "number" and a or (type(b) == "number" and b or nil)
            local dName = (type(c) == "string" and c ~= "") and c
                       or (type(b) == "string" and b ~= "") and b or nil
            if dId and dId > 0 then
                rewards[#rewards + 1] = { type = "dye", id = dId, name = dName }
            end
        end
    end

    if GetAchievementRewardCollectible then
        local ok, a, b = pcall(GetAchievementRewardCollectible, achId)
        if ok then
            local cId = type(a) == "number" and a or (type(b) == "number" and b or nil)
            if cId and cId > 0 then
                local ok2, cName = pcall(GetCollectibleName, cId)
                rewards[#rewards + 1] = {
                    type = "collectible",
                    id = cId,
                    name = (ok2 and type(cName) == "string" and cName ~= "") and cName or nil,
                }
            end
        end
    end

    if GetAchievementRewardItem then
        local ok, hasItem, iName, iIcon = pcall(GetAchievementRewardItem, achId)
        if ok and hasItem and type(iName) == "string" and iName ~= "" then
            rewards[#rewards + 1] = {
                type = "item",
                name = iName,
                icon = (type(iIcon) == "string" and iIcon ~= "") and iIcon or nil,
            }
        end
    end

    if GetAchievementRewardTributeCardUpgradeInfo then
        local ok, a, b, c = pcall(GetAchievementRewardTributeCardUpgradeInfo, achId)
        if ok then
            local tributePatronId = nil
            local tributeCardIndex = nil
            if type(a) == "number" and a > 0 and type(b) == "number" and b > 0 then
                tributePatronId = a
                tributeCardIndex = b
            elseif type(b) == "number" and b > 0 and type(c) == "number" and c > 0 then
                tributePatronId = b
                tributeCardIndex = c
            end
            if tributePatronId and tributeCardIndex then
                rewards[#rewards + 1] = {
                    type = "tribute_card_upgrade",
                    patronId = tributePatronId,
                    cardIndex = tributeCardIndex,
                    name = TributeCardUpgradeName(tributePatronId, tributeCardIndex),
                }
            end
        end
    end

    return rewards
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
    -- slots 3-7 = skills, slot 8 = ultimate; HOTBAR_CATEGORY_* fall back to 1/2 if absent.
    local primaryCat   = HOTBAR_CATEGORY_PRIMARY  or 1
    local backupCat    = HOTBAR_CATEGORY_BACKUP   or 2
    local werewolfCat  = HOTBAR_CATEGORY_WEREWOLF
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
    -- Werewolf bar: only present for characters with the werewolf skill line.
    if werewolfCat then
        local wwBar = {}
        for slot = 3, 8 do
            local ok, aid = pcall(GetSlotBoundId, slot, werewolfCat)
            if ok and aid and aid ~= 0 then
                wwBar[slot] = aid
            end
        end
        if next(wwBar) then
            buildBars["werewolf"] = wwBar
        end
    end
    c.build_bars = buildBars

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

    -- Maximum Health/Magicka/Stamina as the in-game character sheet shows them
    -- (attributes, gear, CP and any buffs active at scan time, e.g. food).
    local pools = {}
    for _, pair in ipairs({
        { "health",  STAT_HEALTH_MAX },
        { "magicka", STAT_MAGICKA_MAX },
        { "stamina", STAT_STAMINA_MAX },
    }) do
        local ok, value = pcall(GetPlayerStat, pair[2], STAT_BONUS_OPTION_APPLY_BONUS)
        pools[pair[1]] = (ok and value) or 0
    end
    c.build_pools = pools

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
    iasync_data.chars[charId] = iasync_data.chars[charId] or {}
    local c = iasync_data.chars[charId]

    iasync_data.accountName = GetDisplayName()

    c.name     = GetUnitName("player")
    c.race     = (GetUnitRace("player"))
    c.class    = (GetUnitClass("player"))
    c.alliance = GetAllianceName(GetUnitAlliance("player"))
    -- "female" or "male" (GENDER_NEUTER and unknown values fall back to "male").
    c.gender   = (GetUnitGender("player") == (GENDER_FEMALE or 1)) and "female" or "male"
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

-- BAG_VIRTUAL uses a linked-list iterator — slot IDs are not contiguous integers.
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

    bank.bags[BAG_VIRTUAL] = ScanVirtualBag()

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

local function GetHouseKey()
    -- GetCurrentZoneHouseId returns the house ID (the storage key); its name comes from the house's collectible.
    if GetCurrentZoneHouseId then
        local houseId = GetCurrentZoneHouseId()
        if houseId and houseId > 0 then
            local name = "House " .. houseId
            local ok, cId = pcall(GetCollectibleIdForHouse, houseId)
            if ok and cId and cId > 0 then
                local okName, cName = pcall(GetCollectibleName, cId)
                if okName and cName and cName ~= "" then name = cName end
            end
            return tostring(houseId), name
        end
    end
    return "0", "House"
end

local function ScanHouseChests()
    local houseKey, houseName = GetHouseKey()
    if houseKey == "0" then return end
    -- Storage chests only open in your own houses; elsewhere the scan would save empty chests.
    if IsOwnerOfCurrentHouse and not IsOwnerOfCurrentHouse() then return end
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

-- ── Guild bank (when its items load) ────────────────────────────────────────
-- EVENT_OPEN_GUILD_BANK fires before the selected guild's items arrive; EVENT_GUILD_BANK_ITEMS_READY fires once they
-- have (again after switching guilds). Guild bank slot ids are not 0..size-1, so walk them like the game UI does.

local function ScanGuildBank()
    local guildId = GetSelectedGuildBankId()
    if not guildId or guildId == 0 then return end
    local guildName = GetGuildName(guildId)
    if not guildName or guildName == "" then return end

    local slots, count = {}, 0
    local slot = ZO_GetNextBagSlotIndex(BAG_GUILDBANK)
    while slot do
        local ok, data = pcall(CaptureSlot, BAG_GUILDBANK, slot)
        if ok and data then
            slots[slot] = data
            count = count + 1
        end
        slot = ZO_GetNextBagSlotIndex(BAG_GUILDBANK, slot)
    end

    iasync_data.guildBanks[guildName] = {
        slots      = slots,
        lastUpdate = GetTimeStamp(),
    }
    d(string.format("[iasync] Guild bank '%s': %d item stacks scanned", guildName, count))
end

-- Deposits and withdrawals: rescan once the burst of item events settles.
local guildBankRescanPending = false
local function OnGuildBankChanged()
    if guildBankRescanPending then return end
    guildBankRescanPending = true
    zo_callLater(function()
        guildBankRescanPending = false
        ScanGuildBank()
    end, 500)
end

-- ── Build name resolution ────────────────────────────────────────────────────

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
        bank.bags[bagId] = bank.bags[bagId] or {}
        bank.bags[bagId][slotIndex] = data

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

-- ── Achievements ─────────────────────────────────────────────────────────────

local function CaptureAchievement(achId, catName, subcatName)
    local name, desc, points, icon, complete, date = GetAchievementInfo(achId)
    if not name or name == "" then return nil end

    local entry = {
        name     = name,
        desc     = desc,
        points   = points or 0,
        icon     = (icon and icon ~= "") and icon or nil,
        complete = complete and true or false,
        cat      = catName,
    }
    if subcatName then entry.subcat = subcatName end
    if complete and date and date ~= "" then entry.completionDate = date end

    -- Persistence level — stored so Python can distinguish account-wide vs char without
    -- relying on routing logic that depends on ESO constants being present.
    if GetAchievementPersistenceLevel then
        local ok, lvl = pcall(GetAchievementPersistenceLevel, achId)
        if ok and lvl then entry.persistenceLevel = lvl end
    end

    CaptureAchievementLineInfo(achId, entry)
    CaptureAchievementCompletionInfo(achId, entry)

    local numCrit = 0
    if GetAchievementNumCriteria then
        local ok, critCount = pcall(GetAchievementNumCriteria, achId)
        if ok and critCount then numCrit = critCount end
    end
    if numCrit > 0 then
        local criteria = {}
        for i = 1, numCrit do
            local ok, critDesc, cur, req = pcall(GetAchievementCriterion, achId, i)
            if ok and critDesc and critDesc ~= "" then
                criteria[i] = { desc = critDesc, cur = cur or 0, req = req or 1 }
            end
        end
        if next(criteria) then entry.criteria = criteria end
    end

    local rewards = CaptureAchievementRewards(achId)
    if #rewards > 0 then entry.rewards = rewards end

    return entry
end

local function ScanAchievements()
    local charId = tostring(GetCurrentCharacterId())
    local c = iasync_data.chars[charId]
    if not c then return end

    local accountAchs, charAchs = {}, {}
    local accountCount, charCount = 0, 0
    local catSummaries = {}

    local function storeAch(achId, catName, subcatName, catSumm, subcatSumm)
        local ok, entry = pcall(CaptureAchievement, achId, catName, subcatName)
        if not (ok and entry) then return end

        -- earnedPts/totalPts come from the API; only accumulate counts here.
        catSumm.total = catSumm.total + 1
        if entry.complete then catSumm.complete = catSumm.complete + 1 end
        if subcatSumm then
            subcatSumm.total = subcatSumm.total + 1
            if entry.complete then subcatSumm.complete = subcatSumm.complete + 1 end
        end

        if IsAccountWideAchievement(achId) then
            if not accountAchs[achId] then accountCount = accountCount + 1 end
            accountAchs[achId] = entry
        else
            if not charAchs[achId] then charCount = charCount + 1 end
            charAchs[achId] = entry
        end
    end

    local function scanCategory(catIdx)
        local ok1, catName, numSubCats, numAchs, apiEarnedPts, apiTotalPts, hidesUnearned = pcall(GetAchievementCategoryInfo, catIdx)
        if not ok1 or not catName then return end
        numSubCats = numSubCats or 0

        -- earnedPts/totalPts come from the API (match game UI exactly); counts are computed.
        local catSumm = {
            name           = catName,
            total          = 0,
            complete       = 0,
            earnedPts      = apiEarnedPts or 0,
            totalPts       = apiTotalPts  or 0,
            numAchievements = numAchs or 0,
            hidesUnearned  = hidesUnearned and true or false,
            subcats        = {},
        }
        -- Keyboard tree icon (e.g. /esoui/art/treeicons/achievements_indexicon_dungeons_up.dds)
        if GetAchievementCategoryKeyboardIcons then
            local okI, icon = pcall(GetAchievementCategoryKeyboardIcons, catIdx)
            if okI and icon and icon ~= "" then catSumm.icon = icon end
        end
        catSummaries[catIdx] = catSumm

        for subIdx = 1, numSubCats do
            local ok2, subName, subNumAchs, apiSubEarned, apiSubTotal, subHidesUnearned = pcall(GetAchievementSubCategoryInfo, catIdx, subIdx)
            if ok2 and subName then
                subNumAchs = subNumAchs or 0
                local subcatSumm = {
                    name           = subName,
                    total          = 0,
                    complete       = 0,
                    earnedPts      = apiSubEarned or 0,
                    totalPts       = apiSubTotal  or 0,
                    numAchievements = subNumAchs or 0,
                    hidesUnearned  = subHidesUnearned and true or false,
                }
                catSumm.subcats[subIdx] = subcatSumm
                for achIdx = 1, subNumAchs do
                    local ok3, achId = pcall(GetAchievementId, catIdx, subIdx, achIdx)
                    if ok3 and achId and achId > 0 then storeAch(achId, catName, subName, catSumm, subcatSumm) end
                end
            end
        end
    end

    local numCats = 0
    local ok0, n = pcall(GetNumAchievementCategories)
    if ok0 and n then numCats = n end

    for catIdx = 1, numCats do
        scanCategory(catIdx)
    end

    local totalEarned, totalPts = 0, 0
    for _, cs in pairs(catSummaries) do
        totalEarned = totalEarned + cs.earnedPts
        totalPts    = totalPts    + cs.totalPts
    end

    iasync_data.achievements = {
        account    = accountAchs,
        categories = catSummaries,
        earnedPts  = totalEarned,
        totalPts   = totalPts,
        lastUpdate = GetTimeStamp(),
    }
    c.achievements = charAchs
    for _, entry in pairs(c.achievements) do
        if entry and entry.complete then
            entry.completedByCharId = entry.completedByCharId or charId
            entry.completedByCharName = entry.completedByCharName or GetUnitName("player")
        end
    end
    d(string.format("[iasync] Achievements: %d account-wide · %d character-specific · %d/%d pts",
        accountCount, charCount, totalEarned, totalPts))
end

local function OnAchievementAwarded(_, _, _, achId)
    local ok, entry = pcall(CaptureAchievement, achId)
    if not ok or not entry then return end
    local name = entry.name
    local catName, subcatName = ResolveAchievementCategoryNames(achId)
    if catName then entry.cat = catName end
    if subcatName then entry.subcat = subcatName end
    entry.complete = true
    CaptureAchievementLineInfo(achId, entry)
    CaptureAchievementCompletionInfo(achId, entry)
    if IsAccountWideAchievement(achId) then
        iasync_data.achievements = iasync_data.achievements or { account = {}, lastUpdate = 0 }
        if not entry.completedByCharId then entry.completedByCharId = tostring(GetCurrentCharacterId()) end
        if not entry.completedByCharName then entry.completedByCharName = GetUnitName("player") end
        iasync_data.achievements.account[achId] = entry
        iasync_data.achievements.lastUpdate = GetTimeStamp()
    else
        local charId = tostring(GetCurrentCharacterId())
        local c = iasync_data.chars[charId]
        if c then
            c.achievements = c.achievements or {}
            if not entry.completedByCharId then entry.completedByCharId = charId end
            if not entry.completedByCharName then entry.completedByCharName = GetUnitName("player") end
            c.achievements[achId] = entry
        end
    end
    d(string.format("[iasync] Achievement earned: %s", name))
end

-- ── Stickerbook (set collection) ─────────────────────────────────────────────

local function ScanStickerbook()
    if not ITEM_SET_COLLECTIONS_DATA_MANAGER then
        d("[iasync] Stickerbook: ITEM_SET_COLLECTIONS_DATA_MANAGER unavailable")
        return
    end

    local sets = {}
    local categoryIcons = {}
    local totalSets, collectedSets = 0, 0

    local function processCategory(catData, topName, subName)
        local ok, hasSubs = pcall(function() return catData:HasSubcategories() end)
        if ok and hasSubs then
            for _, subcat in catData:SubcategoryIterator() do
                local nameOk, sName = pcall(function() return subcat:GetName() end)
                processCategory(subcat, topName, (nameOk and sName) or subName)
            end
            return
        end
        for _, collData in catData:CollectionIterator() do
            local ok2, setId = pcall(function() return collData:GetId() end)
            if ok2 and setId then
                local numTotal    = GetNumItemSetCollectionPieces(setId)        or 0
                local numUnlocked = GetNumItemSetCollectionSlotsUnlocked(setId) or 0
                totalSets = totalSets + 1
                if numTotal > 0 and numUnlocked >= numTotal then collectedSets = collectedSets + 1 end

                local pieces = {}
                for i = 1, numTotal do
                    local pieceId, slot = GetItemSetCollectionPieceInfo(setId, i)
                    if slot then
                        local filterType = GetEquipmentFilterTypeForItemSetCollectionSlot(slot) or 0
                        local collected  = IsItemSetCollectionSlotUnlocked(setId, slot) and true or false
                        local pieceName  = ""
                        local pieceIcon  = nil
                        local pieceQuality = nil
                        if pieceId then
                            local ok3, link = pcall(GetItemSetCollectionPieceItemLink, pieceId,
                                LINK_STYLE_DEFAULT or 1, ITEM_TRAIT_TYPE_NONE or 0)
                            if ok3 and link and link ~= "" then
                                local ok4, n = pcall(GetItemLinkName, link)
                                if ok4 and n then pieceName = n end
                                local ok5, ic = pcall(GetItemLinkIcon, link)
                                if ok5 and ic and ic ~= "" then pieceIcon = ic end
                                local ok6, q = pcall(GetItemLinkDisplayQuality, link)
                                if ok6 and type(q) == "number" then pieceQuality = q end
                            end
                        end
                        pieces[i] = {
                            id         = pieceId,
                            filterType = filterType,
                            collected  = collected,
                            name       = pieceName,
                            icon       = pieceIcon,
                            quality    = pieceQuality,
                        }
                    end
                end

                -- Transmute cost shown in the in-game set header (the UI only uses currency option 1).
                local reconCurrency, reconCost
                local ok7, cType, cCost = pcall(function() return collData:GetReconstructionCurrencyOptionInfo(1) end)
                if ok7 and type(cCost) == "number" then reconCurrency, reconCost = cType, cCost end

                sets[setId] = {
                    name          = GetItemSetName(setId) or "",
                    category      = topName or "",
                    subcategory   = (subName ~= topName) and subName or "",
                    numCollected  = numUnlocked,
                    numTotal      = numTotal,
                    pieces        = pieces,
                    reconCurrency = reconCurrency,
                    reconCost     = reconCost,
                }
            end
        end
    end

    local scanOk = pcall(function()
        for _, catData in ITEM_SET_COLLECTIONS_DATA_MANAGER:TopLevelItemSetCollectionCategoryIterator() do
            local nameOk, catName = pcall(function() return catData:GetName() end)
            local name = (nameOk and catName) or "Unknown"
            local iconOk, icon = pcall(function() return catData:GetKeyboardIcons() end)
            if iconOk and icon and icon ~= "" then categoryIcons[name] = icon end
            processCategory(catData, name, name)
        end
    end)

    if not scanOk then
        d("[iasync] Stickerbook: scan failed")
        return
    end

    iasync_data.stickerbook = {
        sets          = sets,
        categoryIcons = categoryIcons,
        lastUpdate    = GetTimeStamp(),
    }
    d(string.format("[iasync] Stickerbook: %d sets · %d fully collected", totalSets, collectedSets))
end

-- ── Collectibles (account-wide) ─────────────────────────────────────────────
-- The in-game Collections tree: mounts, pets, costumes, houses (HOUSING), outfit styles
-- (OUTFIT_STYLES), Tales of Tribute patrons (TRIBUTE_PATRONS) and so on. Every one is a collectible.

local function ScanCollectibles()
    if not GetNumCollectibleCategories then return end
    local categories, items = {}, {}
    local total, unlocked = 0, 0

    local function addItems(topIdx, subIdx, count)
        for i = 1, count or 0 do
            local okId, id = pcall(GetCollectibleId, topIdx, subIdx, i)
            if okId and id and id > 0 then
                local ok, name, _, icon, _, isUnlocked, _, _, categoryType = pcall(GetCollectibleInfo, id)
                if ok then
                    items[id] = {
                        name         = name or "",
                        icon         = (icon ~= "" and icon) or nil,
                        unlocked     = isUnlocked and true or false,
                        categoryType = categoryType,
                        cat          = topIdx,
                        sub          = subIdx or 0,  -- 0 = directly under the top-level category
                    }
                    total = total + 1
                    if isUnlocked then unlocked = unlocked + 1 end
                end
            end
        end
    end

    local function icon(topIdx, subIdx)
        if not GetCollectibleCategoryKeyboardIcons then return nil end
        local ok, normal = pcall(GetCollectibleCategoryKeyboardIcons, topIdx, subIdx)
        return (ok and normal ~= "" and normal) or nil
    end

    for topIdx = 1, GetNumCollectibleCategories() do
        local ok, name, numSubs, numItems, numUnlocked, numTotal, hidesLocked = pcall(GetCollectibleCategoryInfo, topIdx)
        if ok then
            local spec
            if GetCollectibleCategorySpecialization then
                local okSpec, sp = pcall(GetCollectibleCategorySpecialization, topIdx)
                if okSpec then spec = sp end
            end
            local cat = {
                name           = name or "",
                icon           = icon(topIdx, nil),
                specialization = spec,  -- COLLECTIBLE_CATEGORY_SPECIALIZATION_*: which Collections tab it belongs to
                numUnlocked    = numUnlocked or 0,
                numTotal       = numTotal or 0,
                hidesLocked    = hidesLocked and true or false,
                subcats        = {},
            }
            addItems(topIdx, nil, numItems)
            for subIdx = 1, numSubs or 0 do
                local okSub, sName, sItems, sUnlocked, sTotal = pcall(GetCollectibleSubCategoryInfo, topIdx, subIdx)
                if okSub then
                    cat.subcats[subIdx] = {
                        name        = sName or "",
                        icon        = icon(topIdx, subIdx),
                        numUnlocked = sUnlocked or 0,
                        numTotal    = sTotal or 0,
                    }
                    addItems(topIdx, subIdx, sItems)
                end
            end
            categories[topIdx] = cat
        end
    end

    -- Tales of Tribute patrons: names and art the collectible entries lack (the Patrons category has no icon).
    local patrons = {}
    if GetNumTributePatrons and GetTributePatronIdAtIndex then
        local function call(fn, ...)
            if not fn then return nil end
            local ok, a = pcall(fn, ...)
            if ok and a ~= "" then return a end
        end
        local okNum, numPatrons = pcall(GetNumTributePatrons)
        for i = 1, (okNum and numPatrons) or 0 do
            local patronId = call(GetTributePatronIdAtIndex, i)
            local categoryId = patronId and patronId > 0 and call(GetTributePatronCategoryId, patronId)
            local category = categoryId and categoryId > 0 and call(GetTributePatronCategoryName, categoryId)
            -- Uncategorised patrons are NPC opponents and duplicate variants, not in the in-game tree.
            if category then
                patrons[patronId] = {
                    name          = call(GetTributePatronName, patronId) or "",
                    collectibleId = call(GetTributePatronCollectibleId, patronId),  -- 0/nil for patrons every player has
                    icon          = call(GetTributePatronLargeIcon, patronId),
                    smallIcon     = call(GetTributePatronSmallIcon, patronId),
                    suitIcon      = call(GetTributePatronSuitIcon, patronId),
                    rarity        = call(GetTributePatronRarity, patronId),
                    neutral       = call(IsTributePatronNeutral, patronId) and true or false,
                    category      = category,
                    categoryIcon  = call(GetTributePatronCategoryKeyboardIcons, categoryId),
                    categoryOrder = call(GetTributePatronCategorySortOrder, categoryId),
                }
            end
        end
    end

    iasync_data.collectibles = {
        categories = categories,
        items      = items,
        patrons    = patrons,
        lastUpdate = GetTimeStamp(),
    }
    d(string.format("[iasync] Collectibles: %d / %d unlocked", unlocked, total))
end

-- ── UI colours ──────────────────────────────────────────────────────────────
-- Interface colours live in the client, not in the UI source; ESO Armory uses
-- them to draw its Achievements and Collections tabs in the in-game colours.

local function ScanUiColors()
    if not GetInterfaceColor then return end
    local function hex(colorType, field)
        if colorType == nil or field == nil then return nil end
        local ok, r, g, b = pcall(GetInterfaceColor, colorType, field)
        if not ok or type(r) ~= "number" then return nil end
        return string.format("%02x%02x%02x", zo_round(r * 255), zo_round(g * 255), zo_round(b * 255))
    end
    local TEXT = INTERFACE_COLOR_TYPE_TEXT_COLORS
    local PROG = INTERFACE_COLOR_TYPE_PROGRESSION
    iasync_data.uiColors = {
        textNormal    = hex(TEXT, INTERFACE_TEXT_COLOR_NORMAL),
        textSelected  = hex(TEXT, INTERFACE_TEXT_COLOR_SELECTED),
        textHighlight = hex(TEXT, INTERFACE_TEXT_COLOR_HIGHLIGHT),
        textDisabled  = hex(TEXT, INTERFACE_TEXT_COLOR_DISABLED),
        textDefault   = hex(TEXT, INTERFACE_TEXT_COLOR_DEFAULT_TEXT),
        textContrast  = hex(TEXT, INTERFACE_TEXT_COLOR_CONTRAST),
        textSucceeded = hex(TEXT, INTERFACE_TEXT_COLOR_SUCCEEDED),
        textSecondSelected = hex(TEXT, INTERFACE_TEXT_COLOR_SECOND_SELECTED),
        textSecondNormal   = hex(TEXT, INTERFACE_TEXT_COLOR_SECOND_NORMAL),
        xpStart       = hex(PROG, PROGRESSION_COLOR_XP_START),
        xpEnd         = hex(PROG, PROGRESSION_COLOR_XP_END),
    }
end

-- ── Event handlers ───────────────────────────────────────────────────────────

local function OnPlayerActivated()
    zo_callLater(function()
        ScanCharacterBags()
        ResolveBuildNames()
    end, 2000)
    zo_callLater(ScanHouseChests, 3000)
    zo_callLater(ScanAchievements, 5000)
    zo_callLater(ScanStickerbook, 7000)
    zo_callLater(ScanCollectibles, 9000)
    ScanUiColors()
end

local function OnInventorySlotUpdate(_, bagId, slotIndex)
    if IS_CHAR_BAG[bagId] or IS_BANK_BAG[bagId]
        or IsHouseBag(bagId)
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
    -- Before 1.8.0 every guild bank was filed under the first guild's name, often with empty or partial contents.
    if (iasync_data.guildBankFormat or 1) < 2 then
        iasync_data.guildBanks      = {}
        iasync_data.guildBankFormat = 2
    end
    iasync_data.houses       = iasync_data.houses       or {}
    -- Before 1.8.1 visiting another player's house saved it with empty chests; drop entries holding no items.
    if (iasync_data.houseFormat or 1) < 2 then
        for key, house in pairs(iasync_data.houses) do
            local hasItems = false
            for _, chest in pairs(house.chests or {}) do
                if next(chest.slots or {}) then hasItems = true end
            end
            if not hasItems then iasync_data.houses[key] = nil end
        end
        iasync_data.houseFormat = 2
    end
    iasync_data.abilityNames = iasync_data.abilityNames or {}
    iasync_data.cpNames      = iasync_data.cpNames      or {}
    iasync_data.achievements = iasync_data.achievements or { account = {} }
    iasync_data.stickerbook  = iasync_data.stickerbook  or { sets = {} }
    iasync_data.collectibles = iasync_data.collectibles or { categories = {}, items = {} }
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_Load", EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Load",      EVENT_ADD_ON_LOADED,                OnAddonLoaded)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Player",    EVENT_PLAYER_ACTIVATED,             OnPlayerActivated)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Inv",       EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Bank",      EVENT_OPEN_BANK,                    ScanBankBags)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_GuildBank", EVENT_GUILD_BANK_ITEMS_READY,       ScanGuildBank)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_GBAdd",     EVENT_GUILD_BANK_ITEM_ADDED,        OnGuildBankChanged)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_GBRemove",  EVENT_GUILD_BANK_ITEM_REMOVED,      OnGuildBankChanged)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_GBQty",     EVENT_GUILD_BANK_UPDATED_QUANTITY,  OnGuildBankChanged)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Ach",       EVENT_ACHIEVEMENT_AWARDED,          OnAchievementAwarded)
if EVENT_ACHIEVEMENTS_UPDATED then
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AchUpd", EVENT_ACHIEVEMENTS_UPDATED, ScanAchievements)
end

-- Manual trigger for testing: /script iasync_scan()
function iasync_scan()
    ScanCharacterBags()
    ResolveBuildNames()
    ScanAchievements()
    ScanStickerbook()
    ScanCollectibles()
    ScanUiColors()
end
