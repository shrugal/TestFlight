---@class Addon
local Addon = select(2, ...)
local C, Operation, Optimization, Promise, Reagents, Util = Addon.Constants, Addon.Operation, Addon.Optimization, Addon.Promise, Addon.Reagents, Addon.Util

---@class Recipes: CallbackRegistryMixin
---@field Event Recipes.Event
local Self = Mixin(Addon.Recipes, CallbackRegistryMixin)

---@type table<boolean, table<number, Operation | Operation[]>>
Self.trackedAllocations = { [false] = {}, [true] = {} }

---------------------------------------
--              Tracking
---------------------------------------

-- Get

---@param recipeOrOrder RecipeOrOrder
---@param isRecraftOrQuality? boolean|number
function Self:IsTracked(recipeOrOrder, isRecraftOrQuality)
    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraftOrQuality)

    return C_TradeSkillUI.IsRecipeTracked(recipeID, isRecraft)
end

---@param isRecraft boolean
function Self:GetTrackedIDs(isRecraft)
    return C_TradeSkillUI.GetRecipesTracked(isRecraft)
end

---@param recipeOrOrder RecipeOrOrder
---@param isRecraftOrQuality? boolean|number
function Self:GetTrackedAmount(recipeOrOrder, isRecraftOrQuality)
    if not self:IsTracked(recipeOrOrder, isRecraftOrQuality) then return end
    local recipeID, isRecraft, quality = self:GetRecipeInfo(recipeOrOrder, isRecraftOrQuality)

    local amounts = Addon.DB.Char.tracked[isRecraft][recipeID]
    if type(amounts) ~= "table" then return amounts or 1 end

    return quality and amounts[quality] or 0
end

---@param recipeOrOrder RecipeOrOrder
---@param isRecraft? boolean
---@return number[]?
function Self:GetTrackedAmounts(recipeOrOrder, isRecraft)
    if not self:IsTracked(recipeOrOrder, isRecraft) then return end
    local recipeID, isRecraft, quality = self:GetRecipeInfo(recipeOrOrder, isRecraft)

    local amounts = Addon.DB.Char.tracked[isRecraft][recipeID]
    if type(amounts) == "table" then return amounts end

    return { [quality or 0] = amounts or 1 }
end

---@param recipeOrOrder RecipeOrOrder
---@param isRecraftOrQuality? boolean|number
---@return Operation?
function Self:GetTrackedAllocation(recipeOrOrder, isRecraftOrQuality)
    if not self:IsTracked(recipeOrOrder, isRecraftOrQuality) then return end
    local recipeID, isRecraft, quality, trackedPerQuality = self:GetRecipeInfo(recipeOrOrder, isRecraftOrQuality)

    local allocations = self.trackedAllocations[isRecraft][recipeID]
    if not allocations or not trackedPerQuality then return allocations end

    return allocations[quality or 0]
end

---@param recipeID number
---@param isRecraft? boolean
function Self:GetTrackedQuality(recipeID, isRecraft)
    return Addon.DB.Char.qualities[isRecraft][recipeID]
end

---@param recipeOrOrder RecipeOrOrder
---@param isRecraft? boolean
---@return number[]?
function Self:GetTrackedQualities(recipeOrOrder, isRecraft)
    if not self:IsTracked(recipeOrOrder, isRecraft) then return end
    local recipeID, isRecraft, quality = self:GetRecipeInfo(recipeOrOrder, isRecraft)

    local amounts = Addon.DB.Char.tracked[isRecraft][recipeID]
    if type(amounts) == "table" then return Util(amounts):Keys():Sort()() end

    return quality and { quality }
end

---@param recipeID number
---@param isRecraft? boolean
function Self:IsTrackedPerQuality(recipeID, isRecraft)
    return type(Addon.DB.Char.tracked[isRecraft or false][recipeID]) == "table"
end

function Self:GetTrackedReagentAmounts()
    ---@type number[]
    local reagents = {}

    for recipe in self:Enumerate() do
        local qualities = self:GetTrackedAmounts(recipe) ---@cast qualities -?

        for quality,amount in pairs(qualities) do repeat
            if amount <= 0 then break end

            local operation = self:GetTrackedAllocation(recipe, quality)

            for slotIndex,reagent in pairs(recipe.reagentSlotSchematics) do
                local required = reagent.required and reagent.quantityRequired or 0
                local missing = amount * required

                if operation and operation.allocation[slotIndex] then
                    for _, alloc in operation.allocation[slotIndex]:Enumerate() do repeat
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
    end

    return reagents
end

function Self:GetTrackedResultAmounts()
    ---@type number[]
    local items = {}

    for recipe in self:Enumerate(false) do
        local qualities = self:GetTrackedAmounts(recipe) ---@cast qualities -?

        for quality,amount in pairs(qualities) do repeat
            if amount <= 0 then break end

            local output = C_TradeSkillUI.GetRecipeOutputItemData(recipe.recipeID, nil, nil, quality ~= 0 and quality or nil)
            if not output or not output.itemID then break end

            ---@todo Quality
            items[output.itemID] = (items[output.itemID] or 0) + amount * recipe.quantityMin
        until true end
    end

    return items
end

-- Set

---@param recipeOrOrder RecipeOrOrder
---@param value? boolean
---@param isRecraftOrQuality? boolean|number
function Self:SetTracked(recipeOrOrder, value, isRecraftOrQuality)
    value = value ~= false

    if self:IsTracked(recipeOrOrder, isRecraftOrQuality) == value then return end

    local recipeID, isRecraft = self:GetRecipeInfo(recipeOrOrder, isRecraftOrQuality)

    C_TradeSkillUI.SetRecipeTracked(recipeID, value, isRecraft)
end

---@param recipeOrOrder RecipeOrOrder
---@param amount? number
---@param isRecraftOrQuality? boolean|number
function Self:SetTrackedAmount(recipeOrOrder, amount, isRecraftOrQuality)
    if not self:IsTracked(recipeOrOrder, isRecraftOrQuality) then return end
    local recipeID, isRecraft, quality, trackedPerQuality = self:GetRecipeInfo(recipeOrOrder, isRecraftOrQuality)

    if amount and amount < 0 then amount = 0 end
    if amount == (trackedPerQuality and 0 or 1) then amount = nil end

    local amounts = Addon.DB.Char.tracked[isRecraft]

    if trackedPerQuality then
        if not quality or amounts[recipeID][quality] == amount then return end
        amounts[recipeID][quality] = amount
    else
        if amounts[recipeID] == amount then return end
        amounts[recipeID] = amount
    end

    self:TriggerEvent(Self.Event.TrackedAmountUpdated, recipeID, isRecraftOrQuality or false, amount)
end

---@param recipeOrOrder RecipeOrOrder
---@param operation? Operation
---@param isRecraftOrQuality? boolean|number
function Self:SetTrackedAllocation(recipeOrOrder, operation, isRecraftOrQuality)
    local recipeID, isRecraft, quality, trackedPerQuality = self:GetRecipeInfo(recipeOrOrder, isRecraftOrQuality)

    local allocations = self.trackedAllocations[isRecraft]

    if trackedPerQuality then
        if not allocations[recipeID] then allocations[recipeID] = {} end
        if not quality or allocations[recipeID][quality] == operation then return end
        allocations[recipeID][quality] = operation
    else
        if allocations[recipeID] == operation then return end
        allocations[recipeID] = operation
    end

    self:TriggerEvent(Self.Event.TrackedAllocationUpdated, recipeID, isRecraftOrQuality or false, operation)
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
---@param value? boolean
---@param isRecraft? boolean
function Self:SetTrackedPerQuality(recipeOrOrder, value, isRecraft)
    value = value ~= false

    if not self:IsTracked(recipeOrOrder, isRecraft) then return end

    local recipeID, isRecraft, quality, trackedPerQuality = self:GetRecipeInfo(recipeOrOrder, isRecraft)
    if trackedPerQuality == value then return end

    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if not recipeInfo or not recipeInfo.supportsQualities then return end

    local amounts = Addon.DB.Char.tracked[isRecraft]
    local allocations = self.trackedAllocations[isRecraft]

    ---@type number?, Operation?
    local amount, allocation

    if value then
        amount = amounts[recipeID] or 1 --[[@as number?]]
        allocation = allocations[recipeID] or 1 --[[@as Operation?]]

        amounts[recipeID], allocations[recipeID] = {}, {}
    else
        amount = amounts[recipeID] and amounts[recipeID][quality or 0] or 0
        allocation = allocations[recipeID] and allocations[recipeID][quality or 0] or 0

        amounts[recipeID], allocation[recipeID] = nil, nil
    end

    if quality or not value then
        self:SetTrackedAmount(recipeOrOrder, amount, quality)
        self:SetTrackedAllocation(recipeOrOrder, allocation, quality)
    end

    self:TriggerEvent(Self.Event.TrackedPerQualityChanged, recipeID, isRecraft, value)
end

-- Clear

---@param recipeID number
function Self:ClearTrackedByRecipeID(recipeID)
    for i=0,1 do
        local isRecraft = i == 1
        if not self:IsTracked(recipeID, isRecraft) then
            Addon.DB.Char.tracked[isRecraft][recipeID] = nil
            Addon.DB.Char.qualities[isRecraft][recipeID] = nil
            self.trackedAllocations[isRecraft][recipeID] = nil
        end
    end
end

---------------------------------------
--              Stats
---------------------------------------

---@param recipe CraftingRecipeSchematic
---@param stat BonusStat
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetStatBonus(recipe, stat, optionalReagents)
    local val = 0

    local perks = C.PERKS.recipes[recipe.recipeID]
    if perks then
        local professionInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipe.recipeID)
        local configID = C_ProfSpecs.GetConfigIDForSkillLine(professionInfo.professionID)

        for _,perkID in pairs(perks) do
            local perk = C.PERKS.nodes[perkID]
            if perk[stat] and C_ProfSpecs.GetStateForPerk(perkID, configID) == Enum.ProfessionsSpecPerkState.Earned then
                val = val + perk[stat] / 100
            end
        end
    end

    if optionalReagents then
        for _,reagent in pairs(optionalReagents) do
            val = val + Reagents:GetStatBonus(reagent, stat)
        end
    end

    return val
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetResourcefulnessFactor(recipe, operationInfo, optionalReagents)
    local stat = Util:TblWhere(operationInfo.bonusStats, "bonusStatName", C.STATS.RC.NAME)
    if not stat then return 0 end

    local chance = stat.ratingPct / 100
    local yield = C.STATS.RC.YIELD * (1 + self:GetStatBonus(recipe, "rf", optionalReagents))

    return chance * yield
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetMulticraftFactor(recipe, operationInfo, optionalReagents)
    local stat = Util:TblWhere(operationInfo.bonusStats, "bonusStatName", C.STATS.MC.NAME)
    if not stat then return 0 end

    local chance = stat.ratingPct / 100
    local baseYield = C.STATS.MC.YIELD[recipe.quantityMax] or C.STATS.MC.YIELD[0]
    local yield = (1 + baseYield * recipe.quantityMax * (1 + self:GetStatBonus(recipe, "mc", optionalReagents))) / 2

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
                if i ~= nil then return C_TradeSkillUI.GetRecipeSchematic(recipeID, recraft) end
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
---@param isRecraftOrQuality? boolean|number
---@return number recipeID
---@return boolean isRecraft
---@return number? quality
---@return boolean trackedPerQuality
function Self:GetRecipeInfo(recipeOrOrder, isRecraftOrQuality)
    local recipeID = type(recipeOrOrder) == "number" and recipeOrOrder or recipeOrOrder.recipeID or recipeOrOrder.spellID
    local isRecraft = type(recipeOrOrder) == "table" and recipeOrOrder.isRecraft or isRecraftOrQuality == true
    local quality = type(isRecraftOrQuality) == "number" and isRecraftOrQuality or self:GetTrackedQuality(recipeID, isRecraft) or nil
    local trackedPerQuality = self:IsTrackedPerQuality(recipeID, isRecraft)

    return recipeID, isRecraft, quality, trackedPerQuality
end

---@param recipe CraftingRecipeSchematic
---@param reagents CraftingReagentInfo[]
---@param orderOrRecraftGUID? CraftingOrderInfo | string
---@param applyConcentration? boolean
function Self:GetOperationInfo(recipe, reagents, orderOrRecraftGUID, applyConcentration)
    if not applyConcentration then applyConcentration = false end

    -- Create operation info for recipe's that don't have any
    if not recipe.hasCraftingOperationInfo then
        local profInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipe.recipeID)
        return  { recipeID = recipe.recipeID, baseSkill = profInfo.skillLevel, bonusSkill = profInfo.skillModifier, baseDifficulty = 0, bonusDifficulty = 1, isQualityCraft = false, quality = 1, craftingQuality = 1, craftingQualityID = 0, craftingDataID = 0, lowerSkillThreshold = 0, upperSkillTreshold = 0, guaranteedCraftingQualityID = 0, bonusStats = {}, concentrationCurrencyID = 0, concentrationCost = 0, ingenuityRefund = 0 }
    end

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
---@param operationInfo? CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
---@param qualityID? number
function Self:GetResult(recipe, operationInfo, optionalReagents, qualityID)
    if not qualityID then qualityID = operationInfo and operationInfo.craftingQualityID or 1 end
    if recipe.isRecraft then return end

    if C.ENCHANTS[recipe.recipeID] then
        return C.ENCHANTS[recipe.recipeID][qualityID]
    end

    if operationInfo then
        local data = C_TradeSkillUI.GetRecipeOutputItemData(recipe.recipeID, optionalReagents, nil, qualityID)
        return data.hyperlink or data.itemID
    else
        if recipe.outputItemID then return recipe.outputItemID end
        local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipe.recipeID)
        if not recipeInfo or not recipeInfo.qualityItemIDs then return end
        return recipeInfo.qualityItemIDs[qualityID]
    end
end

---@todo Recraft allocations
function Self:LoadAllocations()
    return Promise:Async(function ()
        for recipe in self:Enumerate() do repeat
            local hasQualityReagents = Util:TblFind(recipe.reagentSlotSchematics, Reagents.IsQuality, false, Reagents)
            if not hasQualityReagents then break end

            local allocations = Optimization:GetTransactionAllocations(recipe, Optimization.Method.Cost)
            if not allocations then break end

            local minQuality = Util:TblMinKey(allocations)
            local qualities = self:GetTrackedAmounts(recipe) ---@cast qualities -?

            for quality,_ in pairs(qualities) do repeat
                local operation = allocations[max(quality, minQuality)]
                if not operation then break end

                self:SetTrackedAllocation(recipe, operation, quality)
            until true end
        until true end
    end)
end

---------------------------------------
--              Events
---------------------------------------

---@class Recipes.Event
---@field TrackedUpdated "TrackedUpdated"
---@field TrackedAmountUpdated "TrackedAmountUpdated"
---@field TrackedQualityUpdated "TrackedQualityUpdated"
---@field TrackedAllocationUpdated "TrackedAllocationUpdated"
---@field TrackedPerQualityChanged "TrackedPerQualityChanged"

Self:GenerateCallbackEvents({ "TrackedUpdated", "TrackedAmountUpdated", "TrackedQualityUpdated", "TrackedAllocationUpdated", "TrackedPerQualityChanged" })
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