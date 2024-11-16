---@class Addon
local Addon = select(2, ...)
local Operation, Optimization, Promise, Reagents, Util = Addon.Operation, Addon.Optimization, Addon.Promise, Addon.Reagents, Addon.Util

---@class Recipes: CallbackRegistryMixin
---@field Event Recipes.Event
local Self = Mixin(Addon.Recipes, CallbackRegistryMixin)

---@type table<boolean, RecipeAllocation[]>
Self.trackedAllocations = { [false] = {}, [true] = {} }

---------------------------------------
--              Tracking
---------------------------------------

-- Get

---@param recipeOrOrder RecipeOrOrder
---@param isRecraft? boolean
function Self:IsTracked(recipeOrOrder, isRecraft)
    return C_TradeSkillUI.IsRecipeTracked(self:GetRecipeInfo(recipeOrOrder, isRecraft))
end

---@param isRecraft boolean
function Self:GetTrackedIDs(isRecraft)
    return C_TradeSkillUI.GetRecipesTracked(isRecraft)
end

---@param recipeOrOrder RecipeOrOrder
---@param isRecraft? boolean
function Self:GetTrackedAmount(recipeOrOrder, isRecraft)
    if not self:IsTracked(recipeOrOrder) then return end
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    return Addon.DB.Char.amounts[isRecraft][recipeID] or 1
end

---@param recipeOrOrder RecipeOrOrder
---@param isRecraft? boolean
function Self:GetTrackedQuality(recipeOrOrder, isRecraft)
    if not self:IsTracked(recipeOrOrder) then return end
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    return Addon.DB.Char.qualities[isRecraft][recipeID]
end

---@param recipeOrOrder RecipeOrOrder
---@param isRecraft? boolean
function Self:GetTrackedAllocation(recipeOrOrder, isRecraft)
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    return self.trackedAllocations[isRecraft][recipeID]
end

function Self:GetTrackedReagentAmounts()
    ---@type number[]
    local reagents = {}

    for recipe in self:Enumerate() do repeat
        local amount = self:GetTrackedAmount(recipe)
        if amount <= 0 then break end

        local allocation = self:GetTrackedAllocation(recipe)

        for slotIndex,reagent in pairs(recipe.reagentSlotSchematics) do
            local required = reagent.required and reagent.quantityRequired or 0
            local missing = amount * required

            if allocation and allocation[slotIndex] then
                for _, alloc in allocation[slotIndex]:Enumerate() do repeat
                    missing = missing - amount * alloc.quantity

                    local itemID = alloc.reagent.itemID ---@cast itemID -?
                    reagents[itemID] = (reagents[itemID] or 0) + amount * alloc.quantity
                until true end
            end

            if missing > 0 then
                local itemID = reagent.reagents[1].itemID ---@cast itemID -?
                reagents[itemID] = (reagents[itemID] or 0) + missing
            end
        end
    until true end

    return reagents
end

function Self:GetTrackedResultAmounts()
    ---@type number[]
    local items = {}

    for recipe in self:Enumerate(false) do repeat
        local amount = self:GetTrackedAmount(recipe)
        if amount <= 0 then break end

        local output = C_TradeSkillUI.GetRecipeOutputItemData(recipe.recipeID, nil, nil, self:GetTrackedQuality(recipe))
        if not output or not output.itemID then break end

        items[output.itemID] = (items[output.itemID] or 0) + amount * recipe.quantityMin
    until true end
    
    return items
end

-- Set

---@param recipeOrOrder RecipeOrOrder
---@param value? boolean
---@param isRecraft? boolean
function Self:SetTracked(recipeOrOrder, value, isRecraft)
    value = value ~= false
    if self:IsTracked(recipeOrOrder, isRecraft) == value then return end

    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    C_TradeSkillUI.SetRecipeTracked(recipeID, value, isRecraft)
end

---@param recipeOrOrder RecipeOrOrder
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

---@param recipeOrOrder RecipeOrOrder
---@param quality? number
---@param isRecraft? boolean
function Self:SetTrackedQuality(recipeOrOrder, quality, isRecraft)
    if quality then quality = floor(quality) end

    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    if Addon.DB.Char.qualities[isRecraft][recipeID] == quality then return end

    Addon.DB.Char.qualities[isRecraft][recipeID] = quality

    self:TriggerEvent(Self.Event.TrackedQualityUpdated, recipeID, isRecraft, quality)
end

---@param recipeOrOrder RecipeOrOrder
---@param allocation? RecipeAllocation
---@param isRecraft? boolean
function Self:SetTrackedAllocation(recipeOrOrder, allocation, isRecraft)
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    self.trackedAllocations[isRecraft][recipeID] = allocation

    self:TriggerEvent(Self.Event.TrackedAllocationUpdated, recipeID, isRecraft, allocation)
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
---@param stat "mc" | "rf" | "cc" | "ig"
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetStatValue(recipe, stat, optionalReagents)
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

    local reagents = Addon.FINISHING_REAGENTS
    if optionalReagents then
        for _,reagent in pairs(optionalReagents) do
            local data = reagents[reagent.itemID]
            if data and data[stat] then
                val = val + data[stat] / 100
            end
        end
    end

    return val
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetResourcefulnessFactor(recipe, operationInfo, optionalReagents)
    local stat = Util:TblWhere(operationInfo.bonusStats, "bonusStatName", ITEM_MOD_RESOURCEFULNESS_SHORT)
    if not stat then return 0 end

    local chance = stat.ratingPct / 100
    local yield = Addon.RESOURCEFULNESS_YIELD + self:GetStatValue(recipe, "rf", optionalReagents)

    return chance * yield
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetMulticraftFactor(recipe, operationInfo, optionalReagents)
    local stat = Util:TblWhere(operationInfo.bonusStats, "bonusStatName", ITEM_MOD_MULTICRAFT_SHORT)
    if not stat then return 0 end

    local chance = stat.ratingPct / 100
    local baseYield = Addon.MULTICRAFT_YIELD[recipe.quantityMax] or Addon.MULTICRAFT_YIELD[0]
    local yield = (1 + baseYield * recipe.quantityMax * (1 + self:GetStatValue(recipe, "mc", optionalReagents))) / 2

    return chance * yield
end

---------------------------------------
--              Util
---------------------------------------

---@param isRecraft? boolean
---@return fun(): CraftingRecipeSchematic?
function Self:Enumerate(isRecraft)
    local recraft, recipeIDs, i, recipeID
    return function ()
        while true do
            if recraft ~= nil then
                i, recipeID = next(recipeIDs, i)
                if i ~= nil then return C_TradeSkillUI.GetRecipeSchematic(recipeID, recraft, self:GetTrackedQuality(recipeID, recraft)) end
            end
            if isRecraft == nil then
                if recraft == false then return else recraft = not recraft end
            else
                if recraft == isRecraft then return else recraft = isRecraft end
            end
            recipeIDs = self:GetTrackedIDs(recraft)
        end
    end
end

---@param recipeOrOrder RecipeOrOrder
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

    Promise:YieldTime()

    return res
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
---@param qualityID? number
function Self:GetResult(recipe, operationInfo, optionalReagents, qualityID)
    if not qualityID then qualityID = operationInfo.craftingQualityID end
    if recipe.isRecraft then return end

    if Addon.ENCHANTS[operationInfo.craftingDataID] then
        return Addon.ENCHANTS[operationInfo.craftingDataID][qualityID]
    end

    local data = C_TradeSkillUI.GetRecipeOutputItemData(recipe.recipeID, optionalReagents, nil, qualityID)
    local id, link = data.itemID, data.hyperlink

    if link and select(14, C_Item.GetItemInfo(link)) == Enum.ItemBind.OnAcquire then return 0 end

    return link or id
end

---@param recipe CraftingRecipeSchematic
function Self:LoadAllocation(recipe)
    local quality = self:GetTrackedQuality(recipe) or 1
    local allocations = Optimization:GetMinCostAllocations(Operation:Create(recipe))
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