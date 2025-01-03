---@class Addon
local Addon = select(2, ...)
local GUI, Prices, Recipes, Restock, Util = Addon.GUI, Addon.Prices, Addon.Recipes, Addon.Restock, Addon.Util
local NS = GUI.RecipeForm

local Parent = NS.WithAmount

---@class GUI.RecipeForm.WithRestock: GUI.RecipeForm.RecipeForm, GUI.RecipeForm.WithAmount
---@field form RecipeCraftingForm
---@field restockCheckbox CheckButton
---@field restockAmountSpinner NumericInputSpinner
---@field craftingRecipe? CraftingRecipeSchematic
local Self = Mixin(NS.WithRestock, Parent)

function Self:Init()
    if not self.form.UpdateRequiredTools then return end
    if not self.restockMinProfitSpinner then return end

    hooksecurefunc(self.form, "UpdateRequiredTools", function ()
        if not self.restockMinProfitSpinner:IsShown() then return end
        local fontString = self.form.RequiredTools
        GUI:SetTextToFit(fontString, fontString:GetText(), 300, true)
    end)
end

-- Restock checkbox

---@param frame CheckButton
function Self:RestockCheckboxOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Enable restocking this item and quality to a set amount.")
    GameTooltip:Show()
end

---@param frame CheckButton
function Self:RestockCheckboxOnChange(frame)
    local operation = self:GetOperation()
    if not operation then return end

    local recipe, quality = operation.recipe, operation:GetResultQuality()

    Restock:SetTracked(recipe, quality, frame:GetChecked() and 1 or 0)
end

-- Restock amount spinner

---@param frame NumericInputSpinner
function Self:RestockAmountSpinnerOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Set target restock amount.")
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

-- Restock profit spinner

---@param frame NumericInputSpinner
function Self:RestockMinProfitSpinnerOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Set minimum gold profit per craft to restock this item.")
    GameTooltip:Show()
end

---@param frame NumericInputSpinner
---@param value number
function Self:RestockMinProfitSpinnerOnChange(frame, value)
    local operation = self:GetOperation()
    if not operation then return end

    local recipe, quality = operation.recipe, operation:GetResultQuality()
    if not Restock:IsTracked(recipe, quality) then return end

    Restock:SetTrackedMinProfit(recipe, quality, value * 10000)
end

-- Insert/Update restock elements

function Self:InsertRestockElements(...)
    local input = GUI:InsertCheckbox(self.form, Util:FnBind(self.RestockCheckboxOnEnter, self), Util:FnBind(self.RestockCheckboxOnChange, self), ...)

    input:SetSize(26, 26)
    input.text:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode("Restock"))

    self.restockCheckbox =  input

    local input = GUI:InsertNumericSpinner(
        self.form, Util:FnBind(self.RestockAmountSpinnerOnEnter, self), Util:FnBind(self.RestockAmountSpinnerOnChange, self),
        "RIGHT", self.restockCheckbox, "LEFT", -30, 1
    )

    input:SetMinMaxValues(1, 999)
    input:SetWidth(27)
    input.DecrementButton:SetAlpha(0.8)
    input.IncrementButton:SetAlpha(0.8)

    self.restockAmountSpinner = input

    if Prices:IsSourceInstalled() then
        local input = GUI:InsertNumericSpinner(
            self.form, Util:FnBind(self.RestockMinProfitSpinnerOnEnter, self), Util:FnBind(self.RestockMinProfitSpinnerOnChange, self),
            "RIGHT", self.restockAmountSpinner.DecrementButton, "LEFT", -30, 0
        )

        input:SetMinMaxValues(-9999, 9999)
        input:SetMaxLetters(5)
        input:SetWidth(37)
        input.DecrementButton:SetAlpha(0.8)
        input.IncrementButton:SetAlpha(0.8)

        -- Enable negative numbers
        input:SetNumeric(false)
        input:SetScript("OnTextChanged", function (self)
            local str = self:GetText() --[[@as string]]
            local num = tonumber(str)
            if not num and str ~= "" and str ~= "-" then
                self:SetText("0")
            elseif str:find("%.") then
                self:SetText(str:gsub("%.", ""))
            else
                self:SetValue(self:GetNumber())
            end
        end)

        self.restockMinProfitSpinner = input
    end

    self:UpdateRestockElements()
end

function Self:UpdateRestockElements()
    local shown, checked, amount, minProfit = false, false, 1, 0

    local operation = self:GetOperation()
    if operation then
        local recipe, quality = operation.recipe, operation:GetResultQuality()
        shown = self:ShouldShowElement() and not operation.applyConcentration and operation:HasProfit()
        checked = shown and Restock:IsTracked(recipe, quality) or false
        amount = checked and Restock:GetTrackedAmount(recipe, quality) or 1
        minProfit = checked and Restock:GetTrackedMinProfit(recipe, quality) or 0
    end

    self.restockCheckbox:SetShown(shown)
    self.restockCheckbox:SetChecked(checked)
    self.restockAmountSpinner:SetShown(checked)
    self.restockAmountSpinner:SetValue(amount)

    if not self.restockMinProfitSpinner then return end

    self.restockMinProfitSpinner:SetShown(checked)
    self.restockMinProfitSpinner:SetValue(floor(minProfit / 10000))

    if not self.form.UpdateRequiredTools then return end

    self.form.UpdateRequiredTools()
end

-- Track quality checkbox

---@param frame CheckButton
function Self:TrackQualityCheckboxOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Track craft qualities separately.")
    GameTooltip:Show()
end

---@param frame CheckButton
function Self:TrackQualityCheckboxOnChange(frame)
    local recipe = self:GetRecipe()
    if not recipe then return end

    Recipes:SetTrackedPerQuality(recipe, frame:GetChecked())
end

-- Insert/Update track quality checkbox

function Self:InsertTrackQualityCheckbox()
    local input = GUI:InsertCheckbox(
        self.form, Util:FnBind(self.TrackQualityCheckboxOnEnter, self), Util:FnBind(self.TrackQualityCheckboxOnChange, self),
        "RIGHT", self.amountSpinner, "LEFT", -50, -1
    )

    input:SetSize(26, 26)
    input.text:SetText(C_Texture.GetCraftingReagentQualityChatIcon(5))

    self.trackQualiyCheckbox = input

    self:UpdateTrackQualityCheckbox()
end

function Self:UpdateTrackQualityCheckbox()
    local shown, checked = false, false

    local recipeInfo = self.form:GetRecipeInfo()
    if recipeInfo then
        shown = Recipes:IsTracked(recipeInfo) and recipeInfo.supportsQualities
        checked = Recipes:IsTrackedPerQuality(recipeInfo.recipeID, recipeInfo.isRecraft)
    end

    self.trackQualiyCheckbox:SetShown(shown)
    self.trackQualiyCheckbox:SetChecked(checked)
end

-- Amount spinner

function Self:InsertAmountSpinner(...)
    Parent.InsertAmountSpinner(self, ...)

    self:InsertTrackQualityCheckbox()
end

---@param frame NumericInputSpinner
---@param value number
function Self:AmountSpinnerOnChange(frame, value)
    local recipe = self:GetRecipe()
    if not recipe or not self.form.transaction then return end

    self:GetTracking():SetTrackedAmount(recipe, value)
end

function Self:UpdateAmountSpinner()
    Parent.UpdateAmountSpinner(self)

    self:UpdateTrackQualityCheckbox()
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnTrackedRestockUpdated()
    if not self.form:IsVisible() then return end
    self:UpdateRestockElements()
end

function Self:OnTrackedPerQualityChanged()
    if not self.form:IsVisible() then return end
    self:UpdateRestockElements()
end

function Self:OnAllocationModified()
    if not self.form:IsVisible() then return end
    self:UpdateAmountSpinner()
    self:UpdateRestockElements()
end

function Self:OnTransactionUpdated()
    if not self.form:IsVisible() then return end
    self:UpdateAmountSpinner()
    self:UpdateRestockElements()
end

function Self:OnAddonLoaded()
    Parent.OnAddonLoaded(self)

    self.form:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, self.OnAllocationModified, self)
    EventRegistry:RegisterCallback("Professions.TransactionUpdated", self.OnTransactionUpdated, self)

    Restock:RegisterCallback(Restock.Event.TrackedUpdated, self.OnTrackedRestockUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedPerQualityChanged, self.OnTrackedPerQualityChanged, self)
end
