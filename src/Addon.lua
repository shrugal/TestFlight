---@type string
local Name = ...
---@class Addon
local Addon = select(2, ...)
local GUI, Options, Util = Addon.GUI, Addon.Options, Addon.Util

---@class Addon: CallbackRegistryMixin
---@field Event Addon.Event
local Self = Mixin(Addon, CallbackRegistryMixin)

---@class CostDB
---@field knowledgeCost number
---@field currencyCost number
---@field payoutCost number

---@class AddonDB: CostDB
TestFlightDB = {
    v = 6,
    ---@type boolean Enable reagent weight in tooltip
    tooltip = false,
    ---@type boolean Enable reagents tracker
    reagents = true,
    ---@type string? Preferred price source addon
    priceSource = nil,
    ---@type number Cost per concentration point (in copper)
    concentrationCost = 50000,
    ---@type number Cost per knowledge point (in copper)
    knowledgeCost = 0,
    ---@type number Cost per artisan currency unit (in copper)
    currencyCost = 0,
    ---@type number Cost per artisan payout bag (in copper)
    payoutCost = 0,
    ---@type number[] Default auras and their quality/stack levels
    auras = {},
    ---@type string? String used to lookup TSM prices
    tsmPriceString = nil,
    ---@type boolean Automatically enable experimentation mode when needed
    autoEnable = true,
}

---@class AddonCharDB
TestFlightCharDB = {
    v = 4,
    ---@type table<boolean, number[]>
    qualities = { [false] = {}, [true] = {} },
    ---@type table<boolean, table<number, number | number[]>>
    tracked = { [false] = {}, [true] = {} },
    ---@type table<number, number[]>
    restock = {},
    ---@type number[][]
    restockMinProfits = {},
    ---@type table<Enum.Profession, CostDB>
    costs = {}
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

---@param profession? Enum.Profession
---@return CostDB
function Self:GetCosts(profession)
    if not profession then profession = C_TradeSkillUI.GetBaseProfessionInfo().profession end
    return profession and self.DB.Char.costs[profession] or self.DB.Account
end

---@param value number
function Self:SetConcentrationCost(value)
    value = max(0, value)

    local db = self.DB.Account

    if db.concentrationCost == value then return end

    db.concentrationCost = value

    self:TriggerEvent(self.Event.ConcentrationCostUpdated)
end

---@param value number
function Self:SetKnowledgeCost(value)
    value = max(0, value)

    local db = self:GetCosts()

    if db.knowledgeCost == value then return end

    db.knowledgeCost = value

    self:TriggerEvent(self.Event.KnowledgeCostUpdated)
end

---@param value number
function Self:SetCurrencyCost(value)
    value = max(0, value)

    local db = self:GetCosts()

    if db.currencyCost == value then return end

    db.currencyCost = value

    self:TriggerEvent(self.Event.CurrencyCostUpdated)
end

---@param value number
function Self:SetPayoutCost(value)
    value = max(0, value)

    local db = self:GetCosts()

    if db.payoutCost == value then return end

    db.payoutCost = value

    self:TriggerEvent(self.Event.PayoutCostUpdated)
end

---@param value boolean
---@param profession? Enum.Profession
function Self:SetCostsPerCharacter(value, profession)
    if not profession then profession = C_TradeSkillUI.GetBaseProfessionInfo().profession end
    if not profession then return end

    if (not self.DB.Char.costs[profession]) == (not value) then return end

    if value then
        local db = self.DB.Account

        self.DB.Char.costs[profession] = {
            knowledgeCost = db.knowledgeCost,
            currencyCost = db.currencyCost,
            payoutCost = db.payoutCost
        }
    else
        self.DB.Char.costs[profession] = nil
    end

    self:TriggerEvent(self.Event.CostPerCharacterUpdated)
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
    if self.DB.Account.v < 4 then
        self.DB.Account.auras = {}
        self.DB.Account.v = 4
    end
    if self.DB.Account.v < 5 then
        self.DB.Account.autoEnable = true
        self.DB.Account.v = 5
    end
    if self.DB.Account.v < 6 then
        self.DB.Account.payoutCost = 0
        self.DB.Account.v = 6
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
    if self.DB.Char.v < 4 then
        self.DB.Char.costs = {}
        self.DB.Char.v = 4
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
---@param opts? string
---@param desc string
---@param curr? string | boolean
---@param ... any
function Self:PrintOption(cmd, short, opts, desc, curr, ...)
    if type(curr) == "boolean" then curr = curr and "on" or "off" end

    local s = {}
    if short then tinsert(s, ("Short: |cffcccccc%s|r"):format(short)) end
    if curr then tinsert(s, ("Current: |cffcccccc%s|r"):format(curr)) end
    local s = Util(s):Join(", "):Wrap(" (", ")")()

    if opts and opts ~= "" then opts = (" |cffcccccc%s|r"):format(opts) end

    Self:Print("  |cff00ccff%s|r%s: %s%s", cmd, opts or "", desc:format(...), s)
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
    if cmd == "rc" then cmd = "recraft" end

    if cmd == "config" then
        Settings.OpenToCategory(Options.category:GetID())
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
    else
        Self:Print("Command:")
        Self:Print("  |cffcccccc/tf|r or |cffcccccc/testflight|r")

        Self:Print("Options:")
        Self:PrintOption("config", nil, nil, "Open addon settings.")
        Self:PrintOption("recraft", "rc", "<link>", "Set recraft UI to an item given by link.")
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
---@field PayoutCostUpdated "PayoutCostUpdated"
---@field CostPerCharacterUpdated "CostPerCharacterUpdated"

Self:GenerateCallbackEvents({ "AddonLoaded", "Loaded", "Enabled", "Disabled", "Toggled", "ExtraSkillUpdated", "ConcentrationCostUpdated", "KnowledgeCostUpdated", "CurrencyCostUpdated", "PayoutCostUpdated", "CostPerCharacterUpdated" })
Self:OnLoad()

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if addonName == Name then self:Load() end

    self:TriggerEvent(self.Event.AddonLoaded, addonName)
end

EventRegistry:RegisterFrameEventAndCallback("ADDON_LOADED", Self.OnAddonLoaded, Self)