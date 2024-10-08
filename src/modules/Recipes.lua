---@class TestFlight
local Addon = select(2, ...)
local GUI, Optimization, Reagents, Util = Addon.GUI, Addon.Optimization, Addon.Reagents, Addon.Util

---@class Recipes
local Self = Addon.Recipes

---@type table<boolean, RecipeAllocation[]>
Self.trackedAllocations = { [false] = {}, [true] = {} }

---------------------------------------
--              Tracking
---------------------------------------

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
function Self:IsTracked(recipeOrOrder)
    return C_TradeSkillUI.IsRecipeTracked(self:GetRecipeInfo(recipeOrOrder))
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param amount? number
function Self:SetTrackedAmount(recipeOrOrder, amount)
    if amount and amount < 0 then amount = 0 end

    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder)
    Addon.DB.Char.amounts[isRecraft][recipeID] = amount

    GUI:UpdateObjectiveTrackers(true, true)

    return amount
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
function Self:GetTrackedAmount(recipeOrOrder)
    if not self:IsTracked(recipeOrOrder) then return end
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder)
    return Addon.DB.Char.amounts[isRecraft][recipeID] or 1
end

function Self:GetTrackedResultItems()
    ---@type number[]
    local items = {}
    for recipeID,amount in pairs(Addon.DB.Char.amounts[false]) do
        local quality = self:GetTrackedQuality(recipeID)
        local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, false, quality)
        local output = C_TradeSkillUI.GetRecipeOutputItemData(recipeID, nil, nil, quality)

        if recipe and output and output.itemID then
            items[output.itemID] = (items[output.itemID] or 0) + amount * recipe.quantityMin
        end
    end
    return items
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param quality? number
function Self:SetTrackedQuality(recipeOrOrder, quality)
    if quality then quality = floor(quality) end

    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder)
    Addon.DB.Char.qualities[isRecraft][recipeID] = quality

    GUI:UpdateObjectiveTrackers(true, true)

    return quality
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
function Self:GetTrackedQuality(recipeOrOrder)
    if not self:IsTracked(recipeOrOrder) then return end
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder)
    return Addon.DB.Char.qualities[isRecraft][recipeID]
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param allocation? RecipeAllocation
function Self:SetTrackedAllocation(recipeOrOrder, allocation)
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder)
    self.trackedAllocations[isRecraft][recipeID] = allocation

    GUI:UpdateObjectiveTrackers(true, true)

    return allocation
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
function Self:GetTrackedAllocation(recipeOrOrder)
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder)
    return self.trackedAllocations[isRecraft][recipeID]
end

---@param form RecipeForm
function Self:SetTrackedByForm(form)
    local recipe = form.transaction:GetRecipeSchematic()
    if not recipe then return end

    local amount, quality, allocation

    if self:IsTracked(recipe) then
        local order = GUI:GetFormOrder(form)

        -- Amount
        amount = self:GetTrackedAmount(recipe) or 1

        -- Quality
        ---@diagnostic disable-next-line: undefined-field
        if form.GetRecipeOperationInfo then ---@cast form RecipeCraftingForm
            local op = form:GetRecipeOperationInfo()
            if op.isQualityCraft then quality = floor(op.quality) end
        elseif order then
            quality = floor(order.minQuality)
        end

        -- Allocation
        if order and order.orderID and order.orderState ~= Enum.CraftingOrderState.Claimed then ---@cast form RecipeCraftingForm
            local recipeInfo, operationInfo, tx = form.currentRecipeInfo, form:GetRecipeOperationInfo(), form.transaction
            local optionalReagents, recraftItemGUID = tx:CreateOptionalOrFinishingCraftingReagentInfoTbl(), tx:GetRecraftAllocation()
            local allocations = Optimization:GetRecipeAllocations(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)
            local quality = tx:IsApplyingConcentration() and order.minQuality - 1 or order.minQuality

            allocation = allocations and allocations[math.max(quality, Util:TblMinKey(allocations))]
        else
            allocation = form.transaction.allocationTbls
        end
    end

    self:SetTrackedAmount(recipe, amount)
    self:SetTrackedQuality(recipe, quality)
    self:SetTrackedAllocation(recipe, allocation)
end

---@param recipeID number
function Self:CheckUnsetTracked(recipeID)
    for isRecraft in pairs(self.trackedAllocations) do
        if not C_TradeSkillUI.IsRecipeTracked(recipeID, isRecraft) then
            Addon.DB.Char.amounts[isRecraft][recipeID] = nil
            Addon.DB.Char.qualities[isRecraft][recipeID] = nil
            self.trackedAllocations[isRecraft][recipeID] = nil

            GUI:UpdateObjectiveTrackers(true, true)
        end
    end
end

---------------------------------------
--              Util
---------------------------------------

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@return number, boolean
function Self:GetRecipeInfo(recipeOrOrder)
    local recipeID = type(recipeOrOrder) == "number" and recipeOrOrder or recipeOrOrder.recipeID or recipeOrOrder.spellID
    local isRecraft = type(recipeOrOrder) == "table" and recipeOrOrder.isRecraft or false
    return recipeID, isRecraft
end

---@param recipe CraftingRecipeSchematic
function Self:LoadAllocation(recipe)
    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipe.recipeID)
    if not recipeInfo then return end

    local qualityReagents = Reagents:GetQualityReagents(recipe)
    local infos = Reagents:CreateCraftingInfosFromSchematics(qualityReagents)
    local operationInfo = C_TradeSkillUI.GetCraftingOperationInfo(recipe.recipeID, infos, nil, false)
    if not operationInfo then return end

    local quality = self:GetTrackedQuality(recipe) or 1
    local allocations = Optimization:GetRecipeAllocations(recipe, recipeInfo, operationInfo)
    local allocation = allocations and allocations[max(quality, Util:TblMinKey(allocations))]
    if not allocation then return end

    self:SetTrackedAllocation(recipe, allocation)
end

---@todo Recraft allocations
---@todo Background task queue
function Self:LoadAllocations()
    local n = 0
    for i=0,0 do
        local isRecraft = i == 1
        local tracked = C_TradeSkillUI.GetRecipesTracked(isRecraft)

        for _,recipeID in pairs(tracked) do
            local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)
            local hasQualityReagents = Util:TblFind(recipe.reagentSlotSchematics, Reagents.IsQualityReagent, false, Reagents)

            if hasQualityReagents then
                C_Timer.After(n * 0.2, function () self:LoadAllocation(recipe) end)
                n = n + 1
            end
        end
    end
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnAddonLoaded(addonName)
    if Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then
        -- ProfessionsFrame.CraftingPage

        local craftingForm = ProfessionsFrame.CraftingPage.SchematicForm
        craftingForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, self.SetTrackedByForm, self, craftingForm)

        -- ProfessionsFrame.OrdersPage

        local ordersForm = ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm
        ordersForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, self.SetTrackedByForm, self, ordersForm)

        -- Restore allocations
        C_Timer.After(1, Util:FnBind(self.LoadAllocations, self))
    end

    if Util:IsAddonLoadingOrLoaded("Blizzard_ProfessionsCustomerOrders", addonName) then
        -- ProfessionsCustomerOrdersFrame

        local customerOrderForm = ProfessionsCustomerOrdersFrame.Form
        hooksecurefunc(customerOrderForm, "UpdateListOrderButton", Util:FnBind(self.SetTrackedByForm, self))
    end
end

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    local form = GUI:GetVisibleForm()
    if not tracked then
        self:CheckUnsetTracked(recipeID)
    elseif form and form then
        self:SetTrackedByForm(form.form)
    end
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)