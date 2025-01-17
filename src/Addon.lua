---@type string
local Name = ...
---@class Addon
local Addon = select(2, ...)
local C, GUI, Prices, Util = Addon.Constants, Addon.GUI, Addon.Prices, Addon.Util

---@class Addon: CallbackRegistryMixin
---@field Event Addon.Event
local Self = Mixin(Addon, CallbackRegistryMixin)

---@class AddonDB
TestFlightDB = {
    v = 3,
    ---@type boolean
    tooltip = false,
    ---@type boolean
    reagents = true,
    ---@type string?
    priceSource = nil,
    ---@type number
    concentrationCost = 50000,
    ---@type number
    knowledgeCost = 0,
    ---@type number
    currencyCost = 0,
    ---@type string?
    tsmPriceString = nil
}

---@class AddonCharDB
TestFlightCharDB = {
    v = 3,
    ---@type table<boolean, number[]>
    qualities = { [false] = {}, [true] = {} },
    ---@type table<boolean, table<number, number | number[]>>
    tracked = { [false] = {}, [true] = {} },
    ---@type table<number, number[]>
    restock = {},
    restockMinProfits = {}
}

---@type boolean
Self.enabled = false
---@type number
Self.extraSkill = 0

---@param value number
function Self:SetExtraSkill(value)
    value = max(0, value)

    if self.extraSkill == value then return end

    self.extraSkill = value

    self:TriggerEvent(self.Event.ExtraSkillUpdated)
end

---@param value number
function Self:SetConcentrationCost(value)
    value = max(0, value)

    if self.DB.Account.concentrationCost == value then return end

    self.DB.Account.concentrationCost = value

    self:TriggerEvent(self.Event.ConcentrationCostUpdated)
end

---@param value number
function Self:SetKnowledgeCost(value)
    value = max(0, value)

    if self.DB.Account.knowledgeCost == value then return end

    self.DB.Account.knowledgeCost = value

    self:TriggerEvent(self.Event.KnowledgeCostUpdated)
end

---@param value number
function Self:SetCurrencyCost(value)
    value = max(0, value)

    if self.DB.Account.currencyCost == value then return end

    self.DB.Account.currencyCost = value

    self:TriggerEvent(self.Event.CurrencyCostUpdated)
end

---------------------------------------
--             Lifecycle
---------------------------------------

function Self:Load()
    self.DB = {
        Account = TestFlightDB,
        Char = TestFlightCharDB,
    }

    -- Migrations

    -- Account
    if not self.DB.Account.v then
        self.DB.Account.amounts = nil
        self.DB.Account.reagents = true
        self.DB.Account.v = 1
    end
    if self.DB.Account.v < 2 then
        self.DB.Account.concentrationCost = 50000
        self.DB.Account.v = 2
    end
    if self.DB.Account.v < 3 then
        self.DB.Account.knowledgeCost = 0
        self.DB.Account.currencyCost = 0
        self.DB.Account.v = 3
    end

    -- Char
    if self.DB.Char.v < 2 then
        self.DB.Char.qualities = { [false] = {}, [true] = {} }
        self.DB.Char.v = 2
    end
    if self.DB.Char.v < 3 then
        self.DB.Char.tracked = self.DB.Char.amounts
        self.DB.Char.restock = {}
        self.DB.Char.restockMinProfits = {}
        self.DB.Char.amounts = nil
        self.DB.Char.v = 3
    end

    self:TriggerEvent(self.Event.Loaded)
end

function Self:Enable()
    if self.enabled then return end
    self.enabled = true

    self:TriggerEvent(self.Event.Enabled)
    self:TriggerEvent(self.Event.Toggled, true)
end

function Self:Disable()
    if not self.enabled then return end
    self.enabled = false

    self:SetExtraSkill(0)

    self:TriggerEvent(self.Event.Disabled)
    self:TriggerEvent(self.Event.Toggled, false)
end

function Self:Toggle()
    if self.enabled then self:Disable() else self:Enable() end
end

---------------------------------------
--              Console
---------------------------------------

---@type boolean
Self.DEBUG = false
--@do-not-package@
Self.DEBUG = true
--@end-do-not-package@

---@param data any
---@param name? string | number
---@param scroll? boolean
function Self:Debug(data, name, scroll)
    if not DevTool or not self.DEBUG then return end

    if data == false then data = "false" end
    if data == nil then data = "nil" end

    DevTool:AddData(data, name or "---")

    if not scroll or not DevTool.MainWindow:IsVisible() then return end

    local frame = DevTool.MainWindow.scrollFrame
    HybridScrollFrame_ScrollToIndex(frame, #DevTool.list, Util:FnVal(frame.buttonHeight))
end

---@param msg string
function Self:Print(msg, ...)
    print("|cff00bbbb[TestFlight]|r " .. msg:format(...))
end

function Self:Error(msg, ...)
    print("|cffff3333[TestFlight]|r " .. msg:format(...))
end

---@param cmd string
---@param short? string
---@param opts string
---@param desc string
---@param curr? string
---@param ... any
function Self:PrintOption(cmd, short, opts, desc, curr, ...)
    local s = {}
    if short then tinsert(s, ("Short: |cffcccccc%s|r"):format(short)) end
    if curr then tinsert(s, ("Current: |cffcccccc%s|r"):format(curr)) end
    s = Util(s):Join(", "):Wrap(" (", ")")()

    Self:Print("  |cff00ccff%s|r |cffcccccc%s|r: %s%s", cmd, opts, desc:format(...), s)
end

---@param name string
---@param desc string
function Self:PrintLegend(name, desc)
    Self:Print("  |cffcccccc%s|r: %s", name, desc)
end

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

    -- Shorthands
    if cmd == "tt" then cmd = "tooltip" end
    if cmd == "re" then cmd = "reagents" end
    if cmd == "rc" then cmd = "recraft" end
    if cmd == "ps" then cmd = "pricesource" end

    if cmd == "tooltip" or cmd == "reagents" then
        local name = Util:StrUcFirst(cmd)

        if not args[2] then
            args[2] = Self.DB.Account[cmd] and "off" or "on"
        end

        if args[2] ~= "on" and args[2] ~= "off" then
            Self:Print("%s: Please pass 'on', 'off' or nothing as second parameter.", name)
            return
        end

        local enabled = args[2] == "on"
        Self.DB.Account[cmd] = enabled

        Self:Print("%s: %s", name, enabled and "enabled" or "disabled")

        local reagentsTracker = GUI.ObjectiveTracker.ReagentsTracker.module

        if cmd == "reagents" and reagentsTracker then
            if enabled then
                reagentsTracker:UpdatePosition()
            else
                reagentsTracker:RemoveFromParent()
            end
        end
    elseif cmd == "recraft" then
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
                GUI.RecipeForm.CraftingForm:SetRecraftRecipe(recipeId, args[2], true)
                return
            end
        end

        Self:Error("Recraft: No recipe for link found.")
    elseif cmd == "pricesource" then
        if args[2] ~= "auto" and not Prices.SOURCES[args[2]] then
            if args[2] then Self:Error("Price source: Unknown source '%s'", args[2]) end

            Self:Print("Price sources:")
            for name in pairs(Prices.SOURCES) do
                Self:Print(" - %s%s", name, C_AddOns.IsAddOnLoaded(name) and " (installed)" or "")
            end

            return
        end

        Self.DB.Account.priceSource = args[2] ~= "auto" and args[2] or nil
        Self.Prices.SOURCE = nil

        Self:Print("Price source: Set to %s", args[2])
    elseif cmd == "tsmprice" and Prices.SOURCES.TradeSkillMaster:IsAvailable() then
        local priceStr

        if args[2] ~= "default" then
            priceStr = string.trim(input:sub(cmd:len() + 1))

            local _, err = TSM_API.GetCustomPriceValue(priceStr, "i:2589")
            if err then
                Self:Error("TSM price: %s", err or "Invalid string")
                return
            end
        end

        Self.DB.Account.tsmPriceString = priceStr

        Self:Print("TSM price: Set to \"%s\"", priceStr or C.TSM_PRICE_STRING)
    else
        Self:Print("Command:")
        Self:Print("  |cffcccccc/tf|r or |cffcccccc/testflight|r")

        Self:Print("Options:")
        Self:PrintOption("recraft", "rc", "<link>", "Set recraft UI to an item given by link.")
        Self:PrintOption("tooltip", "tt", "on||off", "Toggle reagent tooltip info.", Self.DB.Account.tooltip and "on" or "off")
        Self:PrintOption("reagents", "re", "on||off", "Toggle reagents tracker.", Self.DB.Account.reagents and "on" or "off")
        Self:PrintOption("pricesource", "ps", "<name>||auto", "Set price source.", Self.DB.Account.priceSource or "auto")

        if Prices.SOURCES.TradeSkillMaster:IsAvailable() then
           Self:PrintOption("tsmprice", nil, "<string>||default", "Set TSM custom price string.", Self.DB.Account.tsmPriceString or "default")
        end

        Self:Print("Legend:")
        Self:PrintLegend("x||y", "Either x or y.")
        Self:PrintLegend("<x>", "Item link or value.")
    end
end

---------------------------------------
--              Events
---------------------------------------

---@class Addon.Event
---@field AddonLoaded "AddonLoaded"
---@field Loaded "Loaded"
---@field Enabled "Enabled"
---@field Disabled "Disabled"
---@field Toggled "Toggled"
---@field ExtraSkillUpdated "ExtraSkillUpdated"
---@field ConcentrationCostUpdated "ConcentrationCostUpdated"
---@field KnowledgeCostUpdated "KnowledgeCostUpdated"
---@field CurrencyCostUpdated "CurrencyCostUpdated"

Self:GenerateCallbackEvents({ "AddonLoaded", "Loaded", "Enabled", "Disabled", "Toggled", "ExtraSkillUpdated", "ConcentrationCostUpdated", "KnowledgeCostUpdated", "CurrencyCostUpdated" })
Self:OnLoad()

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if addonName == Name then self:Load() end

    self:TriggerEvent(self.Event.AddonLoaded, addonName)
end

EventRegistry:RegisterFrameEventAndCallback("ADDON_LOADED", Self.OnAddonLoaded, Self)