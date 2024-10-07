---@class TestFlight
local Addon = select(2, ...)
local GUI, Optimization, Util = Addon.GUI, Addon.Optimization, Addon.Util

---@class Recipes
local Self = Addon.Recipes

---@type table<boolean, RecipeAllocation[]>
Self.trackedAllocations = { [false] = {}, [true] = {} }

---------------------------------------
--              Tracking
---------------------------------------

---@param recipeOrOrder CraftingRecipeSchematic | CraftingOrderInfo
function Self:IsTracked(recipeOrOrder)
    return C_TradeSkillUI.IsRecipeTracked(recipeOrOrder.recipeID or recipeOrOrder.spellID, recipeOrOrder.isRecraft)
end

---@param recipeOrOrder CraftingRecipeSchematic | CraftingOrderInfo
---@param amount? number
function Self:SetTrackedAmount(recipeOrOrder, amount)
    if amount and amount <= 1 then amount = nil end
    Addon.DB.Char.amounts[recipeOrOrder.isRecraft or false][recipeOrOrder.recipeID or recipeOrOrder.spellID] = amount

    GUI:UpdateObjectiveTrackers(true, true)

    return amount
end

---@param recipeOrOrder CraftingRecipeSchematic | CraftingOrderInfo
function Self:GetTrackedAmount(recipeOrOrder)
    if not self:IsTracked(recipeOrOrder) then return end
    return Addon.DB.Char.amounts[recipeOrOrder.isRecraft or false][recipeOrOrder.recipeID or recipeOrOrder.spellID] or 1
end

---@param recipeOrOrder CraftingRecipeSchematic | CraftingOrderInfo
---@param allocation? RecipeAllocation
function Self:SetTrackedAllocation(recipeOrOrder, allocation)
    self.trackedAllocations[recipeOrOrder.isRecraft or false][recipeOrOrder.recipeID or recipeOrOrder.spellID] = allocation

    GUI:UpdateObjectiveTrackers(true, true)

    return allocation
end

---@param form RecipeForm
function Self:SetTrackedAllocationByForm(form)
    local recipe = form.transaction:GetRecipeSchematic()
    if not recipe then return end

    local order, allocation = GUI:GetFormOrder(form), nil
    if not self:IsTracked(recipe) then
        allocation = nil
    elseif order and order.orderID and order.orderState ~= Enum.CraftingOrderState.Claimed then ---@cast form RecipeCraftingForm
        local recipeInfo, operationInfo, tx = form.currentRecipeInfo, form:GetRecipeOperationInfo(), form.transaction
        local optionalReagents, recraftItemGUID = tx:CreateOptionalOrFinishingCraftingReagentInfoTbl(), tx:GetRecraftAllocation()
        local allocations = Optimization:GetRecipeAllocations(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)
        local quality = tx:IsApplyingConcentration() and order.minQuality - 1 or order.minQuality
        allocation = allocations and allocations[math.max(quality, Util:TblMinKey(allocations))]
    else
        allocation = form.transaction.allocationTbls
    end

    return self:SetTrackedAllocation(recipe, allocation)
end

---@param recipeID number
function Self:CheckUnsetTrackedAllocations(recipeID)
    for isRecraft in pairs(self.trackedAllocations) do
        if not C_TradeSkillUI.IsRecipeTracked(recipeID, isRecraft) then
            self.trackedAllocations[isRecraft][recipeID] = nil

            GUI:UpdateObjectiveTrackers(true, true)
        end
    end
end

---@param recipeOrOrder CraftingRecipeSchematic | CraftingOrderInfo
function Self:GetTrackedAllocation(recipeOrOrder)
    return self.trackedAllocations[recipeOrOrder.isRecraft or false][recipeOrOrder.recipeID or recipeOrOrder.spellID]
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnAddonLoaded(addonName)
    if Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then
        -- ProfessionsFrame.CraftingPage

        local craftingForm = ProfessionsFrame.CraftingPage.SchematicForm
        craftingForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, self.SetTrackedAllocationByForm, self, craftingForm)

        -- ProfessionsFrame.OrdersPage

        local ordersForm = ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm
        ordersForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, self.SetTrackedAllocationByForm, self, ordersForm)
    end

    if Util:IsAddonLoadingOrLoaded("Blizzard_ProfessionsCustomerOrders", addonName) then
        -- ProfessionsCustomerOrdersFrame

        local customerOrderForm = ProfessionsCustomerOrdersFrame.Form

        hooksecurefunc(customerOrderForm, "UpdateListOrderButton", Util:FnBind(self.SetTrackedAllocationByForm, self))
    end
end

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    local form = GUI:GetVisibleForm()
    if not tracked then
        self:CheckUnsetTrackedAllocations(recipeID)
    elseif form and form then
        self:SetTrackedAllocationByForm(form.form)
    end
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)