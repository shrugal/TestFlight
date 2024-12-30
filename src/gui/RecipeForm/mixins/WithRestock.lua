---@class Addon
local Addon = select(2, ...)
local GUI, Recipes, Restock, Util = Addon.GUI, Addon.Recipes, Addon.Restock, Addon.Util

---@class GUI.RecipeForm.WithRestock: GUI.RecipeForm.RecipeForm
---@field form RecipeCraftingForm
---@field restockCheckbox CheckButton
---@field restockAmountSpinner NumericInputSpinner
---@field craftingRecipe? CraftingRecipeSchematic
local Self = GUI.RecipeForm.WithRestock

-- Elements

---@param frame CheckButton
function Self:RestockCheckboxOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Enable restocking this item to a set quantity.")
    GameTooltip:Show()
end

---@param frame CheckButton
function Self:RestockCheckboxOnChange(frame)
    local operation = self:GetOperation()
    if not operation then return end

    local recipe, quality = operation.recipe, operation:GetResultQuality()

    Restock:SetTracked(recipe, quality, frame:GetChecked() and 1 or 0)
end

---@param frame NumericInputSpinner
function Self:RestockAmountSpinnerOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Set target restock quantity.")
    GameTooltip:Show()
end

---@param frame NumericInputSpinner
---@param value number
function Self:RestockAmountSpinnerOnChange(frame, value)
    local operation = self:GetOperation()
    if not operation then return end

    local recipe, quality = operation.recipe, operation:GetResultQuality()
    if not Restock:IsTracked(recipe, quality) then return end

    Restock:SetTracked(recipe, quality, value)
end

function Self:InsertRestockElements(...)
    local input = GUI:InsertCheckbox(self.form, Util:FnBind(self.RestockCheckboxOnEnter, self), Util:FnBind(self.RestockCheckboxOnChange, self), ...)

    input:SetSize(26, 26)
    input.text:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode("Restock"))

    self.restockCheckbox =  input

    local input = GUI:InsertNumericSpinner(
        self.form, Util:FnBind(self.RestockAmountSpinnerOnEnter, self), Util:FnBind(self.RestockAmountSpinnerOnChange, self),
        "RIGHT", self.restockCheckbox, "LEFT", -30, 1
    )

    input:SetMinMaxValues(1, math.huge)

    self.restockAmountSpinner = input

    self:UpdateRestockElements()
end

function Self:UpdateRestockElements()
    local operation = self:GetOperation()
    if not operation then return end

    local recipe, quality = operation.recipe, operation:GetResultQuality()

    local shown = not recipe.isRecraft and Util:OneOf(recipe.recipeType, Enum.TradeskillRecipeType.Item, Enum.TradeskillRecipeType.Enchant) or false
    local checked = shown and Restock:IsTracked(recipe, quality) or false
    local amount = checked and Restock:GetTrackedAmount(recipe, quality) or 1

    self.restockCheckbox:SetShown(shown)
    self.restockCheckbox:SetChecked(checked)
    self.restockAmountSpinner:SetShown(checked)
    self.restockAmountSpinner:SetValue(amount)
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnTrackedRestockUpdated()
    if not self.form:IsVisible() then return end
    self:UpdateRestockElements()
end

function Self:OnAllocationModified()
    if not self.form:IsVisible() then return end
    self:UpdateRestockElements()
end

function Self:OnTransactionUpdated()
    if not self.form:IsVisible() then return end
    self:UpdateRestockElements()
end

function Self:OnAddonLoaded()
    self.form:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, self.OnAllocationModified, self)
    EventRegistry:RegisterCallback("Professions.TransactionUpdated", self.OnTransactionUpdated, self)

    Restock:RegisterCallback(Recipes.Event.TrackedUpdated, self.OnTrackedRestockUpdated, self)
end
