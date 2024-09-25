---@type string
local Name = ...
---@class TestFlight
local Addon = select(2, ...)
local GUI, Optimization, Util = Addon.GUI, Addon.Optimization, Addon.Util

---@class Recipes
local Self = Addon.Recipes

---@type table<boolean, RecipeAllocation[]>
Self.trackedAllocations = { [false] = {}, [true] = {} }

-- Blizzard frames

---@type ObjectiveTrackerModuleMixin?
local recipeTracker = ProfessionsRecipeTracker

---------------------------------------
--              Tracking
---------------------------------------

---@param recipe CraftingRecipeSchematic
function Self:IsTracked(recipe)
    return C_TradeSkillUI.IsRecipeTracked(recipe.recipeID, recipe.isRecraft)
end

---@param recipe CraftingRecipeSchematic
---@param amount? number
function Self:SetTrackedAmount(recipe, amount)
    if amount and amount <= 1 then amount = nil end
    Addon.DB.Char.amounts[recipe.isRecraft or false][recipe.recipeID] = amount

    if recipeTracker then recipeTracker:MarkDirty() end
    if GUI.reagentsTracker then GUI.reagentsTracker:MarkDirty() end

    return amount
end

---@param recipe CraftingRecipeSchematic
function Self:GetTrackedAmount(recipe)
    if not Self:IsTracked(recipe) then return end
    return Addon.DB.Char.amounts[recipe.isRecraft or false][recipe.recipeID] or 1
end

---@param recipe CraftingRecipeSchematic
---@param allocation? RecipeAllocation
function Self:SetTrackedAllocation(recipe, allocation)
    Self.trackedAllocations[recipe.isRecraft or false][recipe.recipeID] = allocation

    GUI:UpdateObjectiveTrackers(true, true)

    return allocation
end

---@param form RecipeForm
function Self:SetTrackedAllocationByForm(form)
    local recipe = form.recipeSchematic
    if not recipe then return end

    local order, allocation = GUI:GetFormOrder(form), nil
    if not self:IsTracked(recipe) then
        allocation = nil
    elseif order and order.orderState ~= Enum.CraftingOrderState.Claimed then ---@cast form RecipeCraftingForm
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
    for isRecraft in pairs(Self.trackedAllocations) do
        if not C_TradeSkillUI.IsRecipeTracked(recipeID, isRecraft) then
            Self.trackedAllocations[isRecraft][recipeID] = nil

            GUI:UpdateObjectiveTrackers(true, true)
        end
    end
end

---@param recipe CraftingRecipeSchematic
function Self:GetTrackedAllocation(recipe)
    return Self.trackedAllocations[recipe.isRecraft or false][recipe.recipeID]
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnAddonLoaded(addonName)
    local isSelf = addonName == Name

    if addonName == "Blizzard_Professions" or isSelf and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
        local craftingForm = ProfessionsFrame.CraftingPage.SchematicForm
        local ordersForm = ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm

        craftingForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, Self.SetTrackedAllocationByForm, Self, craftingForm)
        ordersForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, Self.SetTrackedAllocationByForm, Self, ordersForm)
    end
end

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    local form = GUI:GetVisibleForm()
    if not tracked then
        Self:CheckUnsetTrackedAllocations(recipeID)
    elseif form then
        Self:SetTrackedAllocationByForm(form)
    end
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)