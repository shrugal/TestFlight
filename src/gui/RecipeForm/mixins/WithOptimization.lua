---@class Addon
local Addon = select(2, ...)
local GUI, Optimization, Prices, Promise, Util = Addon.GUI, Addon.Optimization, Addon.Prices, Addon.Promise, Addon.Util

---@class GUI.RecipeForm.WithOptimization: GUI.RecipeForm.RecipeForm
---@field form RecipeCraftingForm
---@field decreaseBtn ButtonFitToText
---@field optimizeBtn ButtonFitToText
---@field increaseBtn ButtonFitToText
---@field optimizationMethodBtn GUI.RecipeForm.OptimizationMethodDropdown
---@field optimizationMethod Optimization.Method
---@field isOptimizing? boolean
local Self = GUI.RecipeForm.WithOptimization

---@param method Optimization.Method
function Self:SetOptimizationMethod(method)
    self.optimizationMethod = method

    self:UpdateConcentrationCostSpinner()
end

-- Optimization buttons

function Self:DecreaseQualityButtonOnClick()
    self:ChangeQualityBy(-1)
end

function Self:OptimizeQualityButtonOnClick()
    self:SetQuality()
end

function Self:IncreaseQualityButtonOnClick()
    self:ChangeQualityBy(1)

end

---@param parent Frame
function Self:InsertOptimizationButtons(parent, ...)
    if not Prices:IsSourceInstalled() then return end

    self.decreaseBtn = GUI:InsertButton("<",        parent, nil, Util:FnBind(self.DecreaseQualityButtonOnClick, self), ...)
    self.optimizeBtn = GUI:InsertButton("Optimize", parent, nil, Util:FnBind(self.OptimizeQualityButtonOnClick, self), "LEFT", self.decreaseBtn, "RIGHT")
    self.increaseBtn = GUI:InsertButton(">",        parent, nil, Util:FnBind(self.IncreaseQualityButtonOnClick, self), "LEFT", self.optimizeBtn, "RIGHT")

    self.decreaseBtn.tooltipText = "Decrease quality"
    self.optimizeBtn.tooltipText = "Optimize for current quality"
    self.increaseBtn.tooltipText = "Increase quality"

    self.optimizationMethodBtn = GUI:InsertElement("DropdownButton", parent, "TestFlightOptimizationMethodDropdownButton", nil, "LEFT", self.increaseBtn, "RIGHT", 5, 0) --[[@as GUI.RecipeForm.OptimizationMethodDropdown]]
    self.optimizationMethodBtn.form = self
end

function Self:UpdateOptimizationButtons()
    if not Prices:IsSourceInstalled() then return end
    if self.isOptimizing then return end

    local op = self.form:GetRecipeOperationInfo()
    local order = self:GetOrder()

    local show = self:ShouldShowElement()
        and op and op.craftingQuality
        and not (order and order.orderState ~= Enum.CraftingOrderState.Claimed)

    self.decreaseBtn:SetShown(show)
    self.optimizeBtn:SetShown(show)
    self.increaseBtn:SetShown(show)
    self.optimizationMethodBtn:SetShown(show)

    if not show then return end

    local canDecrease, canIncrease = false, false

    local operation = self:GetOperation()
    if operation then
        canDecrease, canIncrease = operation:CanChangeQuality()
    end

    self.decreaseBtn:SetEnabled(canDecrease)
    self.increaseBtn:SetEnabled(canIncrease)
end

-- Concentration cost spinner

---@param frame NumericInputSpinner
function Self:ConcentrationCostSpinnerOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddColoredLine(GameTooltip, "Cost per Concentration", HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, "Amount of gold you are willing to spend to save one concentration point.")
    GameTooltip:Show()
end

---@param frame NumericInputSpinner
---@param value number
function Self:ConcentrationCostSpinnerOnChange(frame, value)
    Addon:SetConcentrationCost(value * 10000)
end

---@param parent Frame
function Self:InsertConcentrationCostSpinner(parent, ...)
    self.concentrationCostSpinner = GUI:InsertNumericSpinner(
        parent,
        Util:FnBind(self.ConcentrationCostSpinnerOnEnter, self),
        Util:FnBind(self.ConcentrationCostSpinnerOnChange, self),
        ...
    )

    self.concentrationCostSpinner:SetWidth(26)
    self.concentrationCostSpinner.DecrementButton:SetAlpha(0.8)
    self.concentrationCostSpinner.IncrementButton:SetAlpha(0.8)

    self:UpdateConcentrationCostSpinner()

    self.concentrationCostSpinner:SetMinMaxValues(0, 999)
end

function Self:UpdateConcentrationCostSpinner()
    self.concentrationCostSpinner:SetShown(
        self:ShouldShowElement()
        and self.optimizationMethod == Optimization.Method.CostPerConcentration
        and self.form:GetRecipeOperationInfo().concentrationCost > 0
    )
    self.concentrationCostSpinner:SetValue(floor(Addon.DB.Account.concentrationCost / 10000))
end

---------------------------------------
--               Util
---------------------------------------

---@param quality? number
---@param exact? boolean
function Self:SetQuality(quality, exact)
    if self.isOptimizing then return end

    local tx, op = self.form.transaction, self.form:GetRecipeOperationInfo()

    if not quality then quality = tx:IsApplyingConcentration() and op.craftingQuality - 1 or op.craftingQuality end

    local recipe = self.form.recipeSchematic
    local orderOrRecraftGUID = self:GetOrder() or tx:GetRecraftAllocation()

    Promise:Create(function ()
        return Optimization:GetTransactionAllocations(recipe, self.optimizationMethod, tx, orderOrRecraftGUID, true)
    end):Done(function (operations)
        if not operations then return end

        local operation = operations[quality] or not exact and operations[quality + 1]
        if not operation then return end

        self:SetOperation(operation)
    end):Start(function ()
        self.isOptimizing = true
        self.increaseBtn:SetEnabled(false)
        self.optimizeBtn:SetEnabled(false)
        self.decreaseBtn:SetEnabled(false)

        return function ()
            self.isOptimizing = nil
            self.optimizeBtn:SetEnabled(true)
            self:UpdateOptimizationButtons()
        end
    end)
end

---@param by number
function Self:ChangeQualityBy(by)
    local tx, op = self.form.transaction, self.form:GetRecipeOperationInfo()

    local quality = tx:IsApplyingConcentration() and op.craftingQuality - 1 or op.craftingQuality

    self:SetQuality(quality + by, true)
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnConcentrationCostUpdated()
    if not self.form or not self.form:IsVisible() then return end

    self:UpdateConcentrationCostSpinner()
end

function Self:OnAddonLoaded()
    Addon:RegisterCallback(Addon.Event.ConcentrationCostUpdated, self.OnConcentrationCostUpdated, self)
end