---@class Addon
local Addon = select(2, ...)
local Optimization, Orders, Promise, Reagents, Util = Addon.Optimization, Addon.Orders, Addon.Promise, Addon.Reagents, Addon.Util

---@class Recipes: CallbackRegistryMixin
---@field Event Recipes.Event
local Self = Mixin(Addon.Recipes, CallbackRegistryMixin)

-- Profession stat base multipliers
Self.STAT_BASE_RESOURCEFULNESS = 0.3
Self.STAT_BASE_MULTICRAFT = 2.5

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

function Self:GetTrackedReagentAmounts()
    ---@type number[]
    local reagents = {}
    for i=0,1 do
        local isRecraft = i == 1
        local recipeIDs = self:GetTrackedIDs(isRecraft)

        for _,recipeID in pairs(recipeIDs) do repeat
            local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)

            local amount = self:GetTrackedAmount(recipe)
            if amount <= 0 then break end

            local allocation = self:GetTrackedAllocation(recipe)
            local order = Orders:GetTracked(recipe)

            for slotIndex,reagent in pairs(recipe.reagentSlotSchematics) do repeat
                -- Account for reagents provided by crafter
                if Orders:IsCreatingProvided(order, slotIndex) then break end

                local required = reagent.required and reagent.quantityRequired or 0
                local missing = amount * required

                local isProvidedByCustomer = order and order.reagents and Util:TblWhere(order.reagents, "slotIndex", slotIndex)

                if allocation and allocation[slotIndex] then
                    -- Account for allocated items
                    for _, alloc in allocation[slotIndex]:Enumerate() do repeat
                        missing = missing - amount * alloc.quantity

                        local amount, itemID = amount, alloc.reagent.itemID ---@cast itemID -?

                        -- Account for allocated reagents provided by customer
                        if isProvidedByCustomer then amount = amount - 1 end
                        if amount <= 0 then break end

                        reagents[itemID] = (reagents[itemID] or 0) + amount * alloc.quantity
                    until true end
                elseif isProvidedByCustomer then
                    -- Account for unallocated reagents provided by customer
                    missing = missing - required
                end

                if missing <= 0 then break end

                -- Fill up with lowest quality reagents
                local itemID = reagent.reagents[1].itemID ---@cast itemID -?
                reagents[itemID] = (reagents[itemID] or 0) + missing
            until true end
        until true end
    end
    return reagents
end

function Self:GetTrackedResultAmounts()
    ---@type number[]
    local items = {}
    for _,recipeID in pairs(self:GetTrackedIDs(false)) do repeat
        local quality = self:GetTrackedQuality(recipeID)

        local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, false, quality)
        if not recipe then break end

        local order = Orders:GetTracked(recipeID)
        if order then break end

        local output = C_TradeSkillUI.GetRecipeOutputItemData(recipeID, nil, nil, quality)
        if not output or not output.itemID then break end

        local amount = self:GetTrackedAmount(recipeID)
        items[output.itemID] = (items[output.itemID] or 0) + amount * recipe.quantityMin
    until true end
    return items
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
    if amount == 1 then amount = nil end

    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    if Addon.DB.Char.amounts[isRecraft][recipeID] == amount then return end

    Addon.DB.Char.amounts[isRecraft][recipeID] = amount

    self:TriggerEvent(Self.Event.TrackedAmountUpdated, recipeID, isRecraft, amount)
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param quality? number
---@param isRecraft? boolean
function Self:SetTrackedQuality(recipeOrOrder, quality, isRecraft)
    if quality then quality = floor(quality) end

    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    if Addon.DB.Char.qualities[isRecraft][recipeID] == quality then return end

    Addon.DB.Char.qualities[isRecraft][recipeID] = quality

    self:TriggerEvent(Self.Event.TrackedQualityUpdated, recipeID, isRecraft, quality)
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
---@param allocation? RecipeAllocation
---@param isRecraft? boolean
function Self:SetTrackedAllocation(recipeOrOrder, allocation, isRecraft)
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    self.trackedAllocations[isRecraft][recipeID] = allocation

    self:TriggerEvent(Self.Event.TrackedAllocationUpdated, recipeID, isRecraft, allocation)
end

---@param form GUI.RecipeForm.RecipeForm
function Self:SetTrackedByForm(form)
    local recipe = form:GetRecipe()
    if not recipe then return end

    local amount, quality, allocation
    if self:IsTracked(recipe) then
        amount, quality, allocation = self:GetTrackedAmount(recipe), form:GetQuality(), form:GetAllocation()
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
--              Stats
---------------------------------------

---@param recipe CraftingRecipeSchematic
---@param stat "mc" | "rf"
function Self:GetPerkStats(recipe, stat)
    local val = 0

    local perks = Addon.PERKS.recipes[recipe.recipeID]
    if perks then
        local professionInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipe.recipeID)
        local configID = C_ProfSpecs.GetConfigIDForSkillLine(professionInfo.professionID)

        for _,perkID in pairs(perks) do
            local perk = Addon.PERKS.nodes[perkID]
            if perk[stat] and C_ProfSpecs.GetStateForPerk(perkID, configID) == Enum.ProfessionsSpecPerkState.Earned then
                val = val + perk[stat] / 100
            end
        end
    end

    return val
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
function Self:GetResourcefulnessFactor(recipe, operationInfo)
    local stat = Util:TblWhere(operationInfo.bonusStats, "bonusStatName", ITEM_MOD_RESOURCEFULNESS_SHORT)
    if not stat then return 0 end

    local chance = stat.ratingPct / 100
    local yield = Addon.RESOURCEFULNESS_YIELD + self:GetPerkStats(recipe, "rf")

    return chance * yield
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
function Self:GetMulticraftFactor(recipe, operationInfo)
    local stat = Util:TblWhere(operationInfo.bonusStats, "bonusStatName", ITEM_MOD_MULTICRAFT_SHORT)
    if not stat then return 0 end

    local chance = stat.ratingPct / 100
    local baseYield = Addon.MULTICRAFT_YIELD[recipe.quantityMax] or Addon.MULTICRAFT_YIELD[0]
    local yield = (1 + baseYield * recipe.quantityMax * (1 + self:GetPerkStats(recipe, "mc"))) / 2

    return chance * yield
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
---@param reagents CraftingReagentInfo[]
---@param orderOrRecraftGUID? CraftingOrderInfo | string
---@param applyConcentration? boolean
function Self:GetOperationInfo(recipe, reagents, orderOrRecraftGUID, applyConcentration)
    if not applyConcentration then applyConcentration = false end

    local res
    if type(orderOrRecraftGUID) == "table" then
        res = C_TradeSkillUI.GetCraftingOperationInfoForOrder(recipe.recipeID, reagents, orderOrRecraftGUID.orderID, applyConcentration)
    else ---@cast orderOrRecraftGUID string?
        res = C_TradeSkillUI.GetCraftingOperationInfo(recipe.recipeID, reagents, orderOrRecraftGUID, applyConcentration)
    end

    Promise:YieldTime("GetOperationInfo")

    return res
end

---@param recipe CraftingRecipeSchematic
function Self:LoadAllocation(recipe)
    local quality = self:GetTrackedQuality(recipe) or 1
    local allocations = Optimization:GetRecipeCostAllocations(Addon:CreateOperation(recipe))
    local allocation = allocations and allocations[max(quality, Util:TblMinKey(allocations))]
    if not allocation then return end

    self:SetTrackedAllocation(recipe, allocation)
end

---@todo Recraft allocations
function Self:LoadAllocations()
    for i=0,0 do
        local isRecraft = i == 1
        local tracked = C_TradeSkillUI.GetRecipesTracked(isRecraft)

        for _,recipeID in pairs(tracked) do
            local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)
            local hasQualityReagents = Util:TblFind(recipe.reagentSlotSchematics, Reagents.IsQualityReagent, false, Reagents)

            if hasQualityReagents then
                Promise:Async(function() self:LoadAllocation(recipe) end)
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