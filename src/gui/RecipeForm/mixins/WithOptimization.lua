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

    local recipe, op, tx = self.form.recipeSchematic, self.form:GetRecipeOperationInfo(), self.form.transaction
    local isSalvage, isMinimized = recipe.recipeType == Enum.TradeskillRecipeType.Salvage, ProfessionsUtil.IsCraftingMinimized()
    local order = self:GetOrder()

    local show = op and op.quality and not isSalvage and not isMinimized
        and not (order and order.orderState ~= Enum.CraftingOrderState.Claimed)

    self.decreaseBtn:SetShown(show)
    self.optimizeBtn:SetShown(show)
    self.increaseBtn:SetShown(show)
    self.optimizationMethodBtn:SetShown(show)

    if not show then return end

    local quality = tx:IsApplyingConcentration() and op.quality - 1 or op.quality

    local canDecrease, canIncrease = Optimization:CanChangeCraftQuality(
        recipe,
        floor(quality),
        tx:CreateOptionalOrFinishingCraftingReagentInfoTbl(),
        order,
        tx:GetRecraftAllocation()
    )

    self.decreaseBtn:SetEnabled(canDecrease)
    self.increaseBtn:SetEnabled(canIncrease)
end

-- Concentration cost spinner

---@param frame NumericInputSpinner
function Self:ConcentrationCostSpinnerOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddColoredLine(GameTooltip, "Cost per Concentration", HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, "Set the max. amount of gold you are willing to spend to save one concentration point.")
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
    self:UpdateConcentrationCostSpinner()
    self.concentrationCostSpinner:SetWidth(26)
    self.concentrationCostSpinner:SetMinMaxValues(0, 999)
    self.concentrationCostSpinner.DecrementButton:SetAlpha(0.7)
    self.concentrationCostSpinner.IncrementButton:SetAlpha(0.7)
end

function Self:UpdateConcentrationCostSpinner()
    self.concentrationCostSpinner:SetShown(
        not ProfessionsUtil.IsCraftingMinimized() and self:IsCraftingRecipe()
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
---@param method? Optimization.Method
function Self:SetQuality(quality, exact, method)
    if self.isOptimizing then return end

    local tx, op = self.form.transaction, self.form:GetRecipeOperationInfo()

    if not quality then quality = floor(tx:IsApplyingConcentration() and op.quality - 1 or op.quality) end

    local recipe = self.form.recipeSchematic
    local orderOrRecraftGUID = self:GetOrder() or tx:GetRecraftAllocation()

    Promise:Create(function ()
        return Optimization:GetRecipeAllocations(recipe, method or self.optimizationMethod, tx, orderOrRecraftGUID)
    end):Done(function (operations)
        local operation = operations and (operations[quality] or not exact and operations[quality + 1])
        if not operation then return end

        self:AllocateReagents(operation.allocation)
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
    local quality = tx:IsApplyingConcentration() and op.quality - 1 or op.quality

    self:SetQuality(floor(quality) + by, true)
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