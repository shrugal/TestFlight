---@type string
local Name = ...
---@class TestFlight
local Addon = select(2, ...)
local GUI = Addon.GUI

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

---@param recipeOrForm CraftingRecipeSchematic | RecipeForm
---@param allocation? RecipeAllocation
function Self:SetTrackedAllocation(recipeOrForm, allocation)
    local recipe = recipeOrForm.recipeSchematic or recipeOrForm

    if not allocation and recipeOrForm.transaction and Self:IsTracked(recipe) then
        allocation = recipeOrForm.transaction.allocationTbls
    end

    Self.trackedAllocations[recipe.isRecraft or false][recipe.recipeID] = allocation

    if recipeTracker then recipeTracker:MarkDirty() end
    if GUI.reagentsTracker then GUI.reagentsTracker:MarkDirty() end

    return allocation
end

---@param recipeID number
function Self:CheckUnsetTrackedAllocations(recipeID)
    for isRecraft in pairs(Self.trackedAllocations) do
        if not C_TradeSkillUI.IsRecipeTracked(recipeID, isRecraft) then
            Self.trackedAllocations[isRecraft][recipeID] = nil
        end
    end

    if recipeTracker then recipeTracker:MarkDirty() end
    if GUI.reagentsTracker then GUI.reagentsTracker:MarkDirty() end
end

---@param recipe CraftingRecipeSchematic
function Self:GetTrackedAllocation(recipe)
    return Self.trackedAllocations[recipe.isRecraft or false][recipe.recipeID]
end

function Self:OnAddonLoaded(addonName)
    local isSelf = addonName == Name

    if addonName == "Blizzard_Professions" or isSelf and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
        local craftingForm = ProfessionsFrame.CraftingPage.SchematicForm
        local ordersForm = ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm

        craftingForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, Self.SetTrackedAllocation, Self, craftingForm)
        ordersForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, Self.SetTrackedAllocation, Self, ordersForm)
    end
end