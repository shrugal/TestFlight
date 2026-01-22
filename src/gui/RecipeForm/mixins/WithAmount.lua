---@class Addon
local Addon = select(2, ...)
local GUI, Orders, Recipes, Util = Addon.GUI, Addon.Orders, Addon.Recipes, Addon.Util

---@class GUI.RecipeForm.WithAmount: GUI.RecipeForm.RecipeForm
---@field amountSpinner NumericInputSpinner
---@field craftingRecipe? CraftingRecipeSchematic
local Self = GUI.RecipeForm.WithAmount

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

    input:SetMinMaxValues(0, 999)
    input:SetWidth(27)
    input.DecrementButton:SetAlpha(0.8)
    input.IncrementButton:SetAlpha(0.8)

    self.amountSpinner = input

    return input
end

function Self:UpdateAmountSpinner()
    local Service, model = self:GetTracking()
    self.amountSpinner:SetShown(model and not model.isRecraft and Service:IsTracked(model))
    self.amountSpinner:SetValue(model and not model.isRecraft and Service:GetTrackedAmount(model) or 1)
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

---@param recipeID number
function Self:OnTradeSkillCraftBegin(recipeID)
    if not self.form:IsVisible() then return end

    local recipe, op = self:GetRecipe(), self:GetOperation()
    if not recipe or recipe.recipeID ~= recipeID then return end

    Self.craftingRecipe, Self.craftingQuality = recipe,  op and op:GetResultQuality()
end

function Self:OnUpdateTradeskillCastStopped()
    Self.craftingRecipe = nil
end

---@param unit UnitToken
---@param castGUID string
---@param spellID number
function Self:OnSpellcastInterrupted(unit, castGUID, spellID)
    if unit ~= "player" or not canaccessvalue(spellID) then return end

    local recipe = Self.craftingRecipe
    if not recipe or recipe.recipeID ~= spellID then return end

    Self.craftingRecipe, Self.craftingQuality = nil, nil
end

---@param unit UnitToken
---@param castGUID string
---@param spellID number
function Self:OnSpellcastSucceeded(unit, castGUID, spellID)
    if unit ~= "player" or not canaccessvalue(spellID) then return end

    local recipe, quality = Self.craftingRecipe, Self.craftingQuality
    if not recipe or recipe.recipeID ~= spellID then return end

    Self.craftingRecipe, Self.craftingQuality = nil, nil

    local Service = self:GetTracking()

    local amount = Service:GetTrackedAmount(recipe, quality)
    if not amount then return end

    amount = amount - 1

    if Service == Recipes and amount == 0 then
        Recipes:SetTracked(recipe, false, quality)
    else
        Service:SetTrackedAmount(recipe, amount, quality)
    end
end

function Self:OnAddonLoaded()
    local Service = self:GetTracking()
    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, self.OnTrackedRecipeUpdated, self)
    Orders:RegisterCallback(Orders.Event.TrackedUpdated, self.OnTrackedOrderUpdated, self)
    Service:RegisterCallback(Service.Event.TrackedAmountUpdated, self.OnTrackedUpdated, self)

    EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_CRAFT_BEGIN", self.OnTradeSkillCraftBegin, self)
    EventRegistry:RegisterFrameEventAndCallback("UPDATE_TRADESKILL_CAST_STOPPED", self.OnUpdateTradeskillCastStopped, self)
    EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_INTERRUPTED", self.OnSpellcastInterrupted, self)
    EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_SUCCEEDED", self.OnSpellcastSucceeded, self)
end