---@class Addon
local Addon = select(2, ...)
local C, GUI, Optimization, Orders, Prices, Recipes, Util = Addon.Constants, Addon.GUI, Addon.Optimization, Addon.Orders, Addon.Prices, Addon.Recipes, Addon.Util
local NS = GUI.RecipeForm

---@type GUI.RecipeForm.WithExperimentation | GUI.RecipeForm.WithSkill | GUI.RecipeForm.WithOptimization | GUI.RecipeForm.WithDetails
local Parent = Util:TblCombineMixins(NS.WithExperimentation, NS.WithSkill, NS.WithOptimization, NS.WithDetails)

---@class GUI.RecipeForm.WithCrafting: GUI.RecipeForm.RecipeForm, GUI.RecipeForm.WithExperimentation, GUI.RecipeForm.WithSkill, GUI.RecipeForm.WithOptimization, GUI.RecipeForm.WithDetails
---@field form RecipeCraftingForm
---@field container GUI.RecipeFormContainer.WithTools
local Self = Mixin(NS.WithCrafting, Parent)

Self.optimizationMethod = Optimization.Method.Cost

---------------------------------------
--               Hooks
---------------------------------------

function Self:GetRecipeOperationInfo()
    local GetRecipeOperationInfo = Util:TblGetHooks(self.form).GetRecipeOperationInfo

    if not Addon.enabled and not self:GetTool() then return GetRecipeOperationInfo(self.form) end

    local op = self:GetOperation()
    if not op then return GetRecipeOperationInfo(self.form) end

    local opInfo = op:GetOperationInfo()
    local maxQuality = self.form:GetRecipeInfo().maxQuality ---@cast maxQuality -?

    -- Forms expect quality and skill values to change when applying concentration
    if op.applyConcentration and opInfo.craftingQuality < maxQuality then
        local breakpoints = C.QUALITY_BREAKPOINTS[maxQuality]
        local difficulty = opInfo.baseDifficulty + opInfo.bonusDifficulty
        local quality = opInfo.craftingQuality + 1
        local lower, upper = breakpoints[quality], breakpoints[quality + 1] or 1

        opInfo = Util:TblCopy(opInfo)
        opInfo.craftingQuality = quality
        opInfo.craftingQualityID = op:GetRecipeInfo().qualityIDs[quality]
        opInfo.quality = quality
        opInfo.bonusSkill = opInfo.upperSkillTreshold - opInfo.baseSkill
        opInfo.lowerSkillThreshold = difficulty * lower
        opInfo.upperSkillTreshold = difficulty * upper
    end

    return opInfo
end

---@param recipe CraftingRecipeSchematic
function Self:Init(_, recipe)
    if not recipe then return end

    self:Refresh()
    self:UpdateOutputIcon()

    if not self.isRefreshing then
        self.container:SetTool()
    end

    if not self:CanAllocateReagents() then return end

    -- Set or update tracked allocation
    if not self.isRefreshing then
        local Service, model = self:GetTracking()
        local operation = model and Service:GetTrackedAllocation(model)

        if operation then
            self:SetOperation(operation)
            return
        end
    end

    self:UpdateTracking()
end

function Self:Refresh()
    self:UpdateExperimentBox()
    self:UpdateSkillSpinner()
    self:UpdateConcentrationCostSpinner()
    self:UpdateOptimizationButtons()
end

function Self:UpdateOutputIcon()
    local origOnEnter = self.form.OutputIcon:GetScript("OnEnter")

    self.form.OutputIcon:SetScript("OnEnter", function (...)
        local item = self.form.transaction:GetEnchantAllocation()
        if not item or not item:IsStackable() then return origOnEnter(...) end

        local operation = self:GetOperation()
        if not operation then return origOnEnter(...) end

		GameTooltip:SetOwner(self.form.OutputIcon, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(operation:GetResult())
    end)
end

-- Stats

function Self:UpdateDetailsStats()
    self:UpdateSkillSpinner()
    self:UpdateConcentrationCostSpinner()
    self:UpdateOptimizationButtons()
end

---------------------------------------
--               Util
---------------------------------------

function Self:GetTrackRecipeCheckbox()
    return self.form.TrackRecipeCheckbox
end

function Self:GetQuality()
    local op = self.form:GetRecipeOperationInfo()
    if op then return op.craftingQuality end
end

function Self:CanAllocateReagents()
    if not Professions.InLocalCraftingMode() or C_TradeSkillUI.IsRuneforging() then return false end

    local recipe = self:GetRecipe()
    if not recipe or not Recipes:IsTracked(recipe) then return false end

    local order = self:GetOrder()
    if order then
        -- The order is not claimed
        if order.orderState ~= Enum.CraftingOrderState.Claimed then return false end
        -- Order is already crafted
        if order.isFulfillable then return false end
        -- The order is not tracked
        if not Orders:IsTracked(order) then return false end
    else
        -- The recipe has a tracked order
        if Orders:GetTracked(recipe) then return false end
    end

    return true
end

function Self:GetTool()
    return self.container.toolGUID
end

function Self:GetOperation(refresh)
    local op = NS.RecipeForm.GetOperation(self, refresh)
    if not op or not op:GetRecipeInfo().supportsCraftingStats then return op end

    -- Don't cache operations without proper bonus stats
    local stats = op:GetOperationInfo().bonusStats ---@cast stats -?
    local statsMissing =
        -- Resourcefulness
        not Util:TblSomeWhere(stats, "bonusStatName", C.STATS.RC.NAME)
        -- Multicraft
        or op.recipe.recipeType == Enum.TradeskillRecipeType.Item
            and op:GetResult() and Prices:HasItemPrice(op:GetResult())
            and not Util:TblSomeWhere(stats, "bonusStatName", C.STATS.MC.NAME)

    if statsMissing then
        self.operationCache:Unset(self.operationCache:Key(self))
    end

    return op
end

---@param operation Operation
function Self:SetOperation(operation)
    self.container:SetTool(operation.toolGUID, true)

    NS.RecipeForm.SetOperation(self, operation)
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnEnabled()
    if not self.form then return end

    Util:TblHook(self.form.Concentrate.ConcentrateToggleButton, "HasEnoughConcentration", Util.FnTrue)
    Util:TblHook(self.form.Details.CraftingChoicesContainer.ConcentrateContainer.ConcentrateToggleButton, "HasEnoughConcentration", Util.FnTrue)

    self.form.Concentrate.ConcentrateToggleButton:UpdateState()
    self.form.Details.CraftingChoicesContainer.ConcentrateContainer.ConcentrateToggleButton:UpdateState()
end

function Self:OnDisabled()
    if not self.form then return end

    Util:TblUnhook(self.form.Concentrate.ConcentrateToggleButton, "HasEnoughConcentration")
    Util:TblUnhook(self.form.Details.CraftingChoicesContainer.ConcentrateContainer.ConcentrateToggleButton, "HasEnoughConcentration")

    self.form.Concentrate.ConcentrateToggleButton:UpdateState()
    self.form.Details.CraftingChoicesContainer.ConcentrateContainer.ConcentrateToggleButton:UpdateState()
end

function Self:OnRefresh()
    Parent.OnRefresh(self)

    if not self.form:IsVisible() then return end

    self.isRefreshing = true
    self.form:Refresh()
    self.isRefreshing = nil
end

function Self:OnExtraSkillUpdated()
    if not self.form:IsVisible() then return end

    self.form:UpdateDetailsStats()
    self.form:UpdateRecraftSlot()
end

function Self:OnAllocationModified()
    if not self.form:IsVisible() then return end
    self:UpdateTracking()
end

function Self:OnTransactionUpdated()
    if not self.form:IsVisible() then return end
    self:UpdateTracking()
end

function Self:OnAddonLoaded()
    Parent.OnAddonLoaded(self)

    -- Elements

    -- Insert experiment checkbox
    self:InsertExperimentBox(
        self.form,
        "LEFT", self.form.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
    )

    -- Insert skill points spinner
    self:InsertSkillSpinner(
        self.form.Details.StatLines.SkillStatLine,
        "RIGHT", -50, 1
    )

    -- Insert concentration cost spinner
    self:InsertConcentrationCostSpinner(
        self.form.Details.StatLines.ConcentrationStatLine,
        "RIGHT", -50, 1
    )

    -- Hooks

    Util:TblHook(self.form, "GetRecipeOperationInfo", self.GetRecipeOperationInfo, self)

    hooksecurefunc(self.form, "Init", Util:FnBind(self.Init, self))
    hooksecurefunc(self.form, "Refresh", Util:FnBind(self.Refresh, self))
    hooksecurefunc(self.form, "UpdateDetailsStats", Util:FnBind(self.UpdateDetailsStats, self))

    -- Events

    self.form:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, self.OnAllocationModified, self)
    EventRegistry:RegisterCallback("Professions.TransactionUpdated", self.OnTransactionUpdated, self)

    Addon:RegisterCallback(Addon.Event.Enabled, self.OnEnabled, self)
    Addon:RegisterCallback(Addon.Event.Disabled, self.OnDisabled, self)
    Addon:RegisterCallback(Addon.Event.ExtraSkillUpdated, self.OnExtraSkillUpdated, self)
end