---@class Addon
local Addon = select(2, ...)
local Optimization, Orders, Reagents, Util = Addon.Optimization, Addon.Orders, Addon.Reagents, Addon.Util

---@class Recipes: CallbackRegistryMixin
---@field Event Recipes.Event
local Self = Mixin(Addon.Recipes, CallbackRegistryMixin)

---@type table<boolean, RecipeAllocation[]>
Self.trackedAllocations = { [false] = {}, [true] = {} }

---------------------------------------
--              Tracking
---------------------------------------

-- Get

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param isRecraft? boolean
function Self:IsTracked(recipeOrOrder, isRecraft)
    return C_TradeSkillUI.IsRecipeTracked(self:GetRecipeInfo(recipeOrOrder, isRecraft))
end

---@param isRecraft boolean
function Self:GetTrackedIDs(isRecraft)
    return C_TradeSkillUI.GetRecipesTracked(isRecraft)
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param isRecraft? boolean
function Self:GetTrackedAmount(recipeOrOrder, isRecraft)
    if not self:IsTracked(recipeOrOrder) then return end
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    return Addon.DB.Char.amounts[isRecraft][recipeID] or 1
end

function Self:GetTrackedReagentAmounts()
    ---@type number[]
    local reagents = {}
    for i=0,1 do
        local isRecraft = i == 1
        local recipeIDs = self:GetTrackedIDs(isRecraft)

        for _,recipeID in pairs(recipeIDs) do
            local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)
            local amount = self:GetTrackedAmount(recipe)
            local allocation = self:GetTrackedAllocation(recipe)
            local order = Orders:GetTracked(recipe)

            if amount > 0 then
                for slotIndex,reagent in pairs(recipe.reagentSlotSchematics) do
                    local missing = reagent.required and reagent.quantityRequired or 0

                    -- Account for allocated items
                    if allocation and allocation[slotIndex] then
                        for _, alloc in allocation[slotIndex]:Enumerate() do
                            missing = missing - alloc.quantity

                            local amount, itemID = amount, alloc.reagent.itemID ---@cast itemID -?

                            -- Account for reagents provided by customer
                            if order and order.reagents and Util:TblWhere(order.reagents, "reagent.itemID", itemID) then
                                amount = amount - 1
                            end

                            if amount > 0 then
                                reagents[itemID] = (reagents[itemID] or 0) + amount * alloc.quantity
                            end
                        end
                    end

                    local itemID = reagent.reagents[1].itemID ---@cast itemID -?

                    -- Account for reagents provided by crafter
                    if Orders:IsCreating(order) then
                        missing = missing - (Orders.creatingProvidedReagents[itemID] or 0)
                    end

                    -- Fill up with lowest quality reagents
                    if missing > 0 then
                        reagents[itemID] = (reagents[itemID] or 0) + amount * missing
                    end
                end
            end
        end
    end
    return reagents
end

function Self:GetTrackedResultAmounts()
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
---@param isRecraft? boolean
function Self:GetTrackedQuality(recipeOrOrder, isRecraft)
    if not self:IsTracked(recipeOrOrder) then return end
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    return Addon.DB.Char.qualities[isRecraft][recipeID]
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param isRecraft? boolean
function Self:GetTrackedAllocation(recipeOrOrder, isRecraft)
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    return self.trackedAllocations[isRecraft][recipeID]
end

-- Set

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param value? boolean
---@param isRecraft? boolean
function Self:SetTracked(recipeOrOrder, value, isRecraft)
    value = value ~= false
    if self:IsTracked(recipeOrOrder, isRecraft) == value then return end

    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    C_TradeSkillUI.SetRecipeTracked(recipeID, value, isRecraft)
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param amount? number
---@param isRecraft? boolean
function Self:SetTrackedAmount(recipeOrOrder, amount, isRecraft)
    if amount and amount < 0 then amount = 0 end
    if self:GetTrackedAmount(recipeOrOrder, isRecraft) == amount then return end

    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    Addon.DB.Char.amounts[isRecraft][recipeID] = amount

    self:TriggerEvent(Self.Event.TrackedAmountUpdated, recipeID, isRecraft, amount)

    return amount
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param quality? number
---@param isRecraft? boolean
function Self:SetTrackedQuality(recipeOrOrder, quality, isRecraft)
    if quality then quality = floor(quality) end
    if self:GetTrackedQuality(recipeOrOrder, isRecraft) == quality then return end

    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    Addon.DB.Char.qualities[isRecraft][recipeID] = quality

    self:TriggerEvent(Self.Event.TrackedQualityUpdated, recipeID, isRecraft, quality)

    return quality
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param allocation? RecipeAllocation
---@param isRecraft? boolean
function Self:SetTrackedAllocation(recipeOrOrder, allocation, isRecraft)
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    self.trackedAllocations[isRecraft][recipeID] = allocation

    self:TriggerEvent(Self.Event.TrackedAllocationUpdated, recipeID, isRecraft, allocation)

    return allocation
end

---@param form GUI.RecipeForm.RecipeForm
function Self:SetTrackedByForm(form)
    local recipe = form:GetRecipe()
    if not recipe then return end

    local amount, quality, allocation
    if self:IsTracked(recipe) then
        amount, quality, allocation = self:GetTrackedAmount(recipe) or 1, form:GetQuality(), form:GetAllocation()
    end

    self:SetTrackedAmount(recipe, amount)
    self:SetTrackedQuality(recipe, quality)
    self:SetTrackedAllocation(recipe, allocation)
end

-- Clear

---@param recipeID number
function Self:ClearTrackedByRecipeID(recipeID)
    for i=0,1 do
        local isRecraft = i == 1
        if not self:IsTracked(recipeID, isRecraft) then
            self:SetTrackedAmount(recipeID, nil, isRecraft)
            self:SetTrackedQuality(recipeID, nil, isRecraft)
            self:SetTrackedAllocation(recipeID, nil, isRecraft)
        end
    end
end

---------------------------------------
--              Util
---------------------------------------

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param isRecraft? boolean
---@return number, boolean
function Self:GetRecipeInfo(recipeOrOrder, isRecraft)
    if type(recipeOrOrder) == "number" then
        return recipeOrOrder, isRecraft or false
    else
        return recipeOrOrder.recipeID or recipeOrOrder.spellID, recipeOrOrder.isRecraft or false
    end
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

---@class Recipes.Event
---@field TrackedUpdated "TrackedUpdated"
---@field TrackedAmountUpdated "TrackedAmountUpdated"
---@field TrackedQualityUpdated "TrackedQualityUpdated"
---@field TrackedAllocationUpdated "TrackedAllocationUpdated" 

Self:GenerateCallbackEvents({ "TrackedUpdated", "TrackedAmountUpdated", "TrackedQualityUpdated", "TrackedAllocationUpdated" })
Self:OnLoad()

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    if not tracked then
        self:ClearTrackedByRecipeID(recipeID)
    end

    self:TriggerEvent(Self.Event.TrackedUpdated, recipeID, tracked)
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)