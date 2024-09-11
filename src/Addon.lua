---@type string
local Name = ...
---@class TestFlight
local Addon = select(2, ...)
local GUI, Prices, Util = Addon.GUI, Addon.Prices, Addon.Util

---@class TestFlightDB
TestFlightDB = {
    ---@type number[]
    amounts = {},
    ---@type boolean
    tooltip = false,
    ---@type string?
    priceSource = nil
}

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
    DevTool:AddData(data or "nil", name or "---")
end

---@param msg string
function Self:Print(msg, ...)
    print("|cff00bbbb[TestFlight]|r " .. msg:format(...))
end

function Self:Error(msg, ...)
    print("|cffff3333[TestFlight]|r " .. msg:format(...))
end

---------------------------------------
--             Lifecycle
---------------------------------------

function Self:Load()
    Self.DB = TestFlightDB
end

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

    if cmd == "tooltip" or cmd == "tt" then
        if not args[2] then
            args[2] = Self.DB.tooltip and "off" or "on"
        end

        if args[2] ~= "on" and args[2] ~= "off" then
            Self:Print("Tooltip: Please pass 'on', 'off' or nothing as second parameter.")
            return
        end

        Self.DB.tooltip = args[2] == "on"

        Self:Print("Tooltip: Reagent info %s", Self.DB.tooltip and "enabled" or "disabled")
    elseif cmd == "recraft" or cmd == "rc" then
        -- Get item ID
        local id = GetItemId(args[2])
        if not id then
            Self:Error("Recraft: First parameter must be an item link.")
            return
        end

        -- Make sure the crafting frame is open
        local frameOpen = ProfessionsFrame and ProfessionsFrame:IsShown()
        if not frameOpen then
            Self:Error("Recraft: Please open the crafting window first.")
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

        Self:Error("Recraft: No recipe for link found.")
    elseif cmd == "pricesource" or cmd == "ps" then
        if args[2] ~= "auto" and not Prices.SOURCES[args[2]] then
            if args[2] then Self:Error("Price source: Unknown source '%s'", args[2]) end

            Self:Print("Price sources:")
            for name in pairs(Prices.SOURCES) do
                Self:Print(" - %s%s", name, C_AddOns.IsAddOnLoaded(name) and " (installed)" or "")
            end

            return
        end

        Self.DB.priceSource = args[2] ~= "auto" and args[2] or nil
        Prices.SOURCE = nil

        Self:Print("Price source: Set to %s", args[2])
    else
        Self:Print("Help")
        Self:Print("|cffcccccc/testflight recraft||rc <link>|r: Set recraft UI to an item given by link.")
        Self:Print("|cffcccccc/testflight tooltip||tt on|off|r: Toggle reagent tooltip info. (Current: %s)", Self.DB.tooltip and "on" or "off")
        Self:Print("|cffcccccc/testflight pricesource||ps <name>||auto|r: Set preferred price source. (Current: %s)", Self.DB.priceSource or "auto")
    end
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if addonName ~= Name then return end
    self:Load()
end

EventRegistry:RegisterFrameEventAndCallback("ADDON_LOADED", Self.OnAddonLoaded, Self)