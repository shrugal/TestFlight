---@class Addon
local Addon = select(2, ...)
local GUI, Recipes, Util = Addon.GUI, Addon.Recipes, Addon.Util

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
    if not self.form.transaction then return end
    local recipe = self:GetRecipe()
    if not recipe then return end
    Recipes:SetTrackedAmount(recipe, value)
end

---@return NumericInputSpinner
function Self:InsertAmountSpinner(...)
    local input = GUI:InsertNumericSpinner(self.form, Util:FnBind(self.AmountSpinnerOnEnter, self), Util:FnBind(self.AmountSpinnerOnChange, self), ...)

    input:SetMinMaxValues(0, math.huge)
    self.amountSpinner = input

    return input
end

function Self:UpdateAmountSpinner()
    local recipe = self:GetRecipe()
    local trackBox = self:GetTrackCheckbox()

    self.amountSpinner:SetShown(trackBox:IsShown() and trackBox:GetChecked())
    self.amountSpinner:SetValue(recipe and Recipes:GetTrackedAmount(recipe) or 1)
end

---------------------------------------
--              Events
---------------------------------------

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdated(recipeID, tracked)
    if not self.form:IsVisible() then return end

    local recipe = self:GetRecipe()
    if not recipe or recipe.recipeID ~= recipeID then return end

    self.amountSpinner:SetShown(tracked and not ProfessionsUtil.IsCraftingMinimized())
    self.amountSpinner:SetValue(Recipes:GetTrackedAmount(recipe) or 1)
end

---@param recipeID number
---@param isRecraft boolean
---@param amount number?
function Self:OnTrackedRecipeAmountUpdated(recipeID, isRecraft, amount)
    if not self.form:IsVisible() then return end

    local recipe = self:GetRecipe()
    if not recipe or recipe.recipeID ~= recipeID or recipe.isRecraft ~= isRecraft then return end

    self.amountSpinner:SetValue(amount or 1)
end

function Self:OnTradeSkillCraftBegin()
    if not self.form:IsVisible() then return end

    Self.craftingRecipe = self:GetRecipe()
end

function Self:OnUpdateTradeskillCastStopped()
    Self.craftingRecipe = nil
end

function Self:OnSpellcastStoppedOrSucceeded()
    local recipe = Self.craftingRecipe
    if not recipe then return end

    Self.craftingRecipe = nil

    local amount = Recipes:GetTrackedAmount(recipe)
    if not amount then return end

    Recipes:SetTrackedAmount(recipe, amount - 1)
end

function Self:OnAddonLoaded()
    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, self.OnTrackedRecipeUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedAmountUpdated, self.OnTrackedRecipeAmountUpdated, self)

    EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_CRAFT_BEGIN", self.OnTradeSkillCraftBegin, self)
end

EventRegistry:RegisterFrameEventAndCallback("UPDATE_TRADESKILL_CAST_STOPPED", Self.OnUpdateTradeskillCastStopped, Self)
EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_INTERRUPTED", Self.OnSpellcastStoppedOrSucceeded, Self)
EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_SUCCEEDED", Self.OnSpellcastStoppedOrSucceeded, Self)
