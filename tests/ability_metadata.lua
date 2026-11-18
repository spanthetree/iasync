-- Run from the repository root with Lua 5.1.
local file = assert(io.open("iasync.lua", "r"))
local source = file:read("*a")
file:close()
local resolver = assert(source:match("local function ResolveBuildNames%(%)\n(.-)\nend\n"))
local calls = {}
function GetCurrentCharacterId() return 123 end
function GetDisplayName() return "@test" end
function GetTimeStamp() return 1 end
function d() end
function GetAbilityName(id)
    calls[id] = (calls[id] or 0) + 1
    if id == 5 then error("unavailable") end
    if id == 4 then return "" end
    return "Skill " .. id
end
function GetAbilityIcon(id)
    if id == 5 then error("unavailable") end
    if id == 4 then return "" end
    return "/esoui/art/icons/ability_" .. id .. ".dds"
end
iasync_data = { chars = {
    ["123"] = {
        build_bars = { primary = { [3] = 1, [4] = 4, [5] = 5 }, werewolf = { [3] = 2 } },
        abilityNames = { [4] = "Saved name", [5] = "Saved after error", [99] = "Previously slotted" },
        abilityIcons = { [4] = "/esoui/art/icons/saved.dds" },
    },
    ["456"] = { abilityNames = { [6] = "Other character" } },
} }
WizardsWardrobeSV = { Default = { ["@test"] = {
    ["123"] = { setups = { zone = { [1] = { [1] = { skills = { [0] = { [3] = 3, [4] = 1, [5] = 0 } } } } } } },
    ["456"] = { setups = { zone = { [1] = { [1] = { skills = { [0] = { [3] = 6 } } } } } } },
} } }
local resolve = assert((loadstring or load)(resolver))
resolve()
local c = iasync_data.chars["123"]
assert(c.abilityNames[3] == "Skill 3")
assert(c.abilityIcons[3] == "/esoui/art/icons/ability_3.dds")
assert(c.abilityIcons[2] == "/esoui/art/icons/ability_2.dds")
assert(c.abilityNames[4] == "Saved name" and c.abilityIcons[4] == "/esoui/art/icons/saved.dds")
assert(c.abilityNames[5] == "Saved after error")
assert(c.abilityNames[99] == "Previously slotted")
assert(calls[1] == 1 and calls[6] == nil)
assert(iasync_data.chars["456"].abilityNames[6] == "Other character")
WizardsWardrobeSV = nil
GetAbilityIcon = nil
c.build_bars = {}
resolve()
assert(c.abilityIcons[3] == "/esoui/art/icons/ability_3.dds")
print("Ability metadata tests passed")
