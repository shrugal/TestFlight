---@class Addon
local Addon = select(2, ...)
local GUI, Orders, Recipes, Util = Addon.GUI, Addon.Orders, Addon.Recipes, Addon.Util

---@class GUI.RecipeForm.AmountForm: GUI.RecipeForm.RecipeForm
---@field amountSpinner NumericInputSpinner
---@field craftingRecipe? CraftingRecipeSchematic
local Self = GUI.RecipeForm.AmountForm

-- Amount spinner

---@param frame NumericInputSpinner
function Self:AmountSpinnerOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Set number of tracked recipe crafts.")
    GameTooltip:Show()
end

---@param frame NumericInputSpinner
---@param value number
function Self:AmountSpinnerOnChange(frame, value)
    local recipe = self:GetRecipe()
    if not recipe or not self.form.transaction then return end

    self:GetTracking():SetTrackedAmount(recipe, value)
end

---@return NumericInputSpinner
function Self:InsertAmountSpinner(...)
    local input = GUI:InsertNumericSpinner(self.form, Util:FnBind(self.AmountSpinnerOnEnter, self), Util:FnBind(self.AmountSpinnerOnChange, self), ...)

    input:SetMinMaxValues(0, math.huge)
    self.amountSpinner = input

    return input
end

function Self:UpdateAmountSpinner()
    local Service, model = self:GetTracking()
    self.amountSpinner:SetShown(model and Service:IsTracked(model))
    self.amountSpinner:SetValue(model and Service:GetTrackedAmount(model) or 1)
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnTrackedUpdated()
    if not self.form:IsVisible() then return end
    self:UpdateAmountSpinner()
end

function Self:OnTrackedRecipeUpdated()
    if self:GetTracking() ~= Recipes then return end
    self:OnTrackedUpdated()
end

function Self:OnTrackedOrderUpdated()
    if self:GetTracking() ~= Orders then return end
    self:OnTrackedUpdated()
end

function Self:OnTradeSkillCraftBegin()
    if not self.form:IsVisible() then return end
    Self.craftingRecipe = self:GetRecipe()
end

function Self:OnUpdateTradeskillCastStopped()
    Self.craftingRecipe = nil
end

function Self:OnSpellcastInterruptedOrSucceeded()
    local recipe = Self.craftingRecipe
    if not recipe then return end

    Self.craftingRecipe = nil

    local amount = self:GetTracking():GetTrackedAmount(recipe)
    if not amount then return end

    self:GetTracking():SetTrackedAmount(recipe, amount - 1)
end

function Self:OnAddonLoaded()
    local Service = self:GetTracking()
    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, self.OnTrackedRecipeUpdated, self)
    Orders:RegisterCallback(Orders.Event.TrackedUpdated, self.OnTrackedOrderUpdated, self)
    Service:RegisterCallback(Service.Event.TrackedAmountUpdated, self.OnTrackedUpdated, self)

    EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_CRAFT_BEGIN", self.OnTradeSkillCraftBegin, self)
    EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_INTERRUPTED", self.OnSpellcastInterruptedOrSucceeded, self)
    EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_SUCCEEDED", self.OnSpellcastInterruptedOrSucceeded, self)
end

EventRegistry:RegisterFrameEventAndCallback("UPDATE_TRADESKILL_CAST_STOPPED", Self.OnUpdateTradeskillCastStopped, Self)
