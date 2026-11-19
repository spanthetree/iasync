-- Run from the repository root with Lua 5.1.
local file = assert(io.open("iasync.lua", "r"))
local source = file:read("*a")
file:close()
local block = assert(source:match("\n(local ARMORY_SLOT_STATES.-\nlocal function ScanArmoryBuilds%(%).-\nend\n)"))

ARMORY_BUILD_EQUIP_SLOT_STATE_EMPTY, ARMORY_BUILD_EQUIP_SLOT_STATE_INACCESSIBLE = 0, 1
ARMORY_BUILD_EQUIP_SLOT_STATE_MISSING, ARMORY_BUILD_EQUIP_SLOT_STATE_VALID = 2, 3
CURSE_TYPE_NONE, CURSE_TYPE_VAMPIRE, CURSE_TYPE_WEREWOLF = 0, 1, 2
HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP, HOTBAR_CATEGORY_CHAMPION = 0, 1, 3
MUNDUS_STONE_INVALID, BAG_WORN = 0, 0
iasync_data = { chars = { ["123"] = { armoryBuilds = { "old" } } } }
function GetCurrentCharacterId() return 123 end
function GetTimeStamp() return 7 end
function d() end
function GetBagSize() return 4 end
function IsHouseBag(bagId) return bagId == 7 end
function CaptureSlot(bagId, slot) return { name = "Item " .. bagId .. "/" .. slot, link = "|H1:item|h" } end
function GetString(_, stone) return ({ [1] = "The Lady", [2] = "The Lover" })[stone] or "" end

local numBuilds = 2
function GetNumUnlockedArmoryBuilds() return numBuilds end
function GetArmoryBuildName(i) return "Build " .. i end
function GetArmoryBuildIconIndex() return 5 end
function GetArmoryBuildSkillsTotalSpentPoints() return 400 end
function GetArmoryBuildCurseType(i) return i == 1 and CURSE_TYPE_VAMPIRE or CURSE_TYPE_NONE end
function GetArmoryBuildEquippedOutfitIndex() return nil end
function GetArmoryBuildEquipSlotInfo(i, slot)
    if i == 2 then error("unavailable") end
    if slot == 0 then return ARMORY_BUILD_EQUIP_SLOT_STATE_VALID, 1, 12 end
    if slot == 1 then return ARMORY_BUILD_EQUIP_SLOT_STATE_VALID, 7, 3 end
    if slot == 2 then return ARMORY_BUILD_EQUIP_SLOT_STATE_MISSING end
    return ARMORY_BUILD_EQUIP_SLOT_STATE_EMPTY
end
function GetArmoryBuildSlotBoundId(_, slot, cat)
    if cat == HOTBAR_CATEGORY_PRIMARY and slot == 3 then return 100 end
    if cat == HOTBAR_CATEGORY_CHAMPION and slot == 1 then return 9 end
    return 0
end
function GetEffectiveAbilityIdForAbilityOnHotbarForArmoryBuild(id) return id + 1 end
function GetNumChampionDisciplines() return 1 end
function GetChampionDisciplineId() return 4 end
function GetChampionDisciplineName() return "Warfare" end
function GetArmoryBuildChampionSpentPointsByDiscipline() return 210 end
function GetArmoryBuildAttributeSpentPoints(_, attr) return attr == 2 and 64 or 0 end
function GetArmoryBuildPrimaryMundusStone() return 1 end
function GetArmoryBuildSecondaryMundusStone() return MUNDUS_STONE_INVALID end

local scan = assert((loadstring or load)(block .. "\nreturn ScanArmoryBuilds"))()
scan()
local builds = iasync_data.chars["123"].armoryBuilds
local b = builds[1]
assert(b.name == "Build 1" and b.icon == "EsoUI/Art/Armory/BuildIcons/buildIcon_5.dds")
assert(b.curse == "vampire" and b.skillPoints == 400 and b.outfitIndex == nil)
assert(b.gear[0].state == "valid" and b.gear[0].name == "Item 1/12" and b.gear[0].bagId == 1)
assert(b.gear[1].state == "inaccessible")
assert(b.gear[2].state == "missing" and b.gear[2].link == nil)
assert(b.gear[3] == nil)
assert(b.bars.primary[3] == 100 and b.effectiveBars.primary[3] == 101 and b.bars.primary[4] == nil)
assert(b.cp.slots[1] == 9 and b.cp.disciplines[4].spent == 210 and b.cp.disciplines[4].name == "Warfare")
assert(b.attributes.magicka == 64 and b.attributes.health == 0)
assert(#b.mundus == 1 and b.mundus[1] == "The Lady")
assert(builds[2].name == "Build 2" and next(builds[2].gear) == nil)
assert(iasync_data.chars["123"].armoryBuildsUpdate == 7)

numBuilds = 0
scan()
assert(iasync_data.chars["123"].armoryBuilds[1].name == "Build 1")
print("Armory build tests passed")
