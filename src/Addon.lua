---@type string
local Name = ...
---@class TestFlight
local Addon = select(2, ...)
local GUI = Addon.GUI

---@class TestFlight
local Self = Addon

---@type boolean
Self.DEBUG = false
---@type boolean
Self.enabled = false
---@type number
Self.extraSkill = 0

--@do-not-package@
Self.DEBUG = true
--@end-do-not-package@

if Self.DEBUG then TestFlight = Self end

---@param data any
---@param name? string
function Self:Debug(data, name)
    if not DevTool or not self.DEBUG then return end
    DevTool:AddData(data, name)
end

---@param msg string
function Self:Print(msg)
    print("|cff00bbbb[TestFlight]|r " .. msg)
end

---------------------------------------
--             Lifecycle
---------------------------------------

function Self:Enable()
    if Self.enabled then return end
    Self.enabled = true

    GUI:OnEnable()
end

function Self:Disable()
    if not Self.enabled then return end
    Self.enabled = false

    Self.extraSkill = 0

    GUI:OnDisable()
end

function Self:Toggle()
    if Self.enabled then Self:Disable() else Self:Enable() end
end
---------------------------------------
--              Commands
---------------------------------------

SLASH_TESTFLIGHT1 = "/testflight"
SLASH_TESTFLIGHT2 = "/tf"

local function ParseArgs(input)
    input = " " .. input

    local args = {}
    local link = 0

    for s in input:gmatch("[| ]+[^| ]+") do
        if link == 0 and s:sub(1, 1) == " " then
            s = s:gsub("^ +", "")
            tinsert(args, s)
        else
            args[#args] = args[#args] .. s
        end

        if s:sub(1, 2) == "|H" then link = 1 end
        if s:sub(1, 2) == "|h" then link = (link + 1) % 3 end
    end

    return args
end

---@param link string
local function GetItemId(link) return link and tonumber(link:match("|Hitem:(%d+)")) end

---@param input string
function SlashCmdList.TESTFLIGHT(input)
    local args = ParseArgs(input)
    local cmd = args[1]

    if cmd == "recraft" or cmd == "rc" then
        -- Get item ID
        local id = GetItemId(args[2])
        if not id then
            Self:Print("Recraft: First parameter must be an item link.")
            return
        end

        -- Make sure the crafting frame is open
        local frameOpen = ProfessionsFrame and ProfessionsFrame:IsShown()
        if not frameOpen then
            Self:Print("Recraft: Please open the crafting window first.")
            return
        end

        for _, recipeId in pairs(C_TradeSkillUI.GetAllRecipeIDs()) do
            local link = C_TradeSkillUI.GetRecipeItemLink(recipeId) --[[@as string ]]
            if id == GetItemId(link) then
                Self:Enable()
                GUI:SetRecraftRecipe(recipeId, args[2], true)
                return
            end
        end

        Self:Print("Recraft: No recipe for link found.")
    else
        Self:Print("Help")
        Self:Print("|cffcccccc/testflight recraft [link]|r: Set recraft UI to an item given by link")
    end
end
