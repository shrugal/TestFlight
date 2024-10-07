---@class TestFlight
local Addon = select(2, ...)
local GUI, Recipes, Util = Addon.GUI, Addon.Recipes, Addon.Util

---@class GUI.RecipeForm.AmountForm
---@field form RecipeForm
---@field GetTrackCheckbox fun(self: self): CheckButton
local Self = GUI.RecipeForm.AmountForm

---@type table<RecipeForm, NumericInputSpinner>
Self.amountSpinners = {}
---@type CraftingRecipeSchematic?
Self.craftingRecipe = nil

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
    local recipe = self.form.transaction:GetRecipeSchematic()
    if not recipe then return end
    Recipes:SetTrackedAmount(recipe, value)
end

---@return NumericInputSpinner
function Self:InsertAmountSpinner(...)
    local input = GUI:InsertNumericSpinner(self.form, Util:FnBind(self.AmountSpinnerOnEnter, self), Util:FnBind(self.AmountSpinnerOnChange, self), ...)

    input:SetMinMaxValues(1, math.huge)

    Self.amountSpinners[self.form] = input

    return input
end

function Self:UpdateAmountSpinner()
    local recipe = self.form.transaction:GetRecipeSchematic()
    local amountSpinner = Self.amountSpinners[self.form]
    local trackBox = self:GetTrackCheckbox()

    amountSpinner:SetShown(trackBox:IsShown() and trackBox:GetChecked())
    amountSpinner:SetValue(recipe and Recipes:GetTrackedAmount(recipe) or 1)
end

---------------------------------------
--              Events
---------------------------------------

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    for form,amountSpinner in pairs(Self.amountSpinners) do
        local recipe = form.transaction and form.transaction:GetRecipeSchematic()
        if recipe and recipe.recipeID == recipeID then
            amountSpinner:SetShown(Recipes:IsTracked(recipe) and not ProfessionsUtil.IsCraftingMinimized())
            amountSpinner:SetValue(Recipes:GetTrackedAmount(recipe) or 1)
        end
    end
end

function Self:OnTradeSkillCraftBegin()
    local form = GUI:GetVisibleForm()
    if not form or not form.form.transaction then return end
    Self.craftingRecipe = form.form.transaction:GetRecipeSchematic()
end

function Self:OnUpdateTradeskillCastStopped()
    Self.craftingRecipe = nil
end

function Self:OnSpellcastStoppedOrSucceeded()
    local recipe = Self.craftingRecipe
    if not recipe then return end

    Self.craftingRecipe = nil

    local amount = recipe and Recipes:GetTrackedAmount(recipe)
    if not recipe or not amount then return end

    amount = Recipes:SetTrackedAmount(recipe, max(1, amount - 1)) or 1

    for form,amountSpinner in pairs(Self.amountSpinners) do
        local formRecipe = form.transaction and form.transaction:GetRecipeSchematic()
        if formRecipe and formRecipe.recipeID == recipe.recipeID and formRecipe.isRecraft == recipe.isRecraft then
            amountSpinner:SetValue(amount)
        end
    end
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)
EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_CRAFT_BEGIN", Self.OnTradeSkillCraftBegin, Self)
EventRegistry:RegisterFrameEventAndCallback("UPDATE_TRADESKILL_CAST_STOPPED", Self.OnUpdateTradeskillCastStopped, Self)
EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_INTERRUPTED", Self.OnSpellcastStoppedOrSucceeded, Self)
EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_SUCCEEDED", Self.OnSpellcastStoppedOrSucceeded, Self)