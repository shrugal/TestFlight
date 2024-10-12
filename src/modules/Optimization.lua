---@class Addon
local Addon = select(2, ...)
local Reagents, Prices = Addon.Reagents, Addon.Prices

---@class Optimization
local Self = Addon.Optimization

---------------------------------------
--              Crafts
---------------------------------------

---@param recipe CraftingRecipeSchematic
---@param recipeInfo TradeSkillRecipeInfo
---@param operationInfo CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
---@param recraftItemGUID? string
---@param order CraftingOrderInfo?
function Self:GetRecipeAllocations(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)
    local qualityReagents = Reagents:GetQualityReagents(recipe, order)
    local skillBase, skillBest = Reagents:GetSkillBounds(recipe, optionalReagents, qualityReagents, recraftItemGUID, order)

    if not skillBase then return end

    -- Check allocations cache
    local cache = self.Cache.Allocations
    local key = cache:Key(recipe, skillBase, order, optionalReagents)

    if cache:Has(key) then return cache:Get(key) end

    local weights, prices = self:GetRecipeWeightsAndPrices(recipe, qualityReagents, order)
    local maxWeight = Reagents:GetMaxWeight(qualityReagents)

    local breakpoints = Addon.QUALITY_BREAKPOINTS[recipeInfo.maxQuality]
    local difficulty = operationInfo.baseDifficulty + operationInfo.bonusDifficulty

    ---@type RecipeAllocation[]
    local allocations = {}

    for i=#breakpoints, 1, -1 do
        local breakpointFactor = math.max(0, (breakpoints[i] * difficulty - skillBase) / skillBest)
        local prevPrice = math.huge

        if breakpointFactor <= 1 then
            local w = math.ceil(breakpointFactor * maxWeight)
            local price = prices[w]

            if prevPrice <= price then break end

            local allocation = Reagents:CreateAllocation(order)

            for j=#qualityReagents, 1, -1 do
                local reagent = qualityReagents[j]
                local weight = weights[j][w]

                allocation[reagent.slotIndex] = self:CreateReagentAllocationsForWeight(reagent, weight)

                w = math.max(0, w - weight * Reagents:GetWeight(reagent))
            end

            allocations[i] = allocation
            prevPrice = price
        end

        if breakpointFactor == 0 then break end
    end

    cache:Set(key, allocations)

    return allocations
end

---@param recipe CraftingRecipeSchematic
---@param qualityReagents CraftingReagentSlotSchematic[]
---@param order? CraftingOrderInfo
---@return table<number, table<number, number>>
---@return table<number, number>
function Self:GetRecipeWeightsAndPrices(recipe, qualityReagents, order)
    -- Check weights cache
    local cache = self.Cache.WeightsAndPrices
    local key = cache:Key(recipe, order)

    if cache:Has(key) then return unpack(cache:Get(key)) end

    -- Intialize knapsack matrices
    ---@type table<number, table<number, number>>, table<number, table<number, number>>
    local prices, weights = { [0] = {}, { [0] = 0 } }, {}
    for i=1, #qualityReagents do weights[i] = {} end

    -- Compute lowest prices and corresponding reagent allocations
    for i,reagent in ipairs(qualityReagents) do
        prices[0], prices[1] = prices[1], wipe(prices[0])

        local itemWeight = Reagents:GetWeight(reagent)
        local p1, p2, p3 = Prices:GetReagentPrices(reagent)
        local s = math.min(0, 1 - itemWeight)

        for weight=0, 2 * reagent.quantityRequired do
            local q1, q2, q3 = self:GetReagentQuantitiesForWeight(reagent, weight)
            local weightPrice = p1 * q1 + p2 * q2 + p3 * q3
            local contribution = weight * itemWeight

            for j=s, #prices[0] do
                local w = j + contribution
                local newPrice = prices[0][math.max(0, j)] + weightPrice
                local oldPrice = prices[1][w] or math.huge

                if newPrice < oldPrice then
                    prices[1][w], weights[i][w] = newPrice, weight
                end
            end
        end
    end

    cache:Set(key, { weights, prices[1] })

    return weights, prices[1]
end

---@param recipe CraftingRecipeSchematic
---@param recipeInfo TradeSkillRecipeInfo
---@param operationInfo CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
---@param recraftItemGUID? string
---@param order? CraftingOrderInfo
function Self:CanChangeCraftQuality(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)
    if recipeInfo.maxQuality == 0 then return false, false end

    local breakpoints = Addon.QUALITY_BREAKPOINTS[recipeInfo.maxQuality]
    local difficulty = operationInfo.baseDifficulty + operationInfo.bonusDifficulty
    local quality = math.floor(operationInfo.quality)
    local qualityReagents = Reagents:GetQualityReagents(recipe, order)
    local skillBase, skillBest = Reagents:GetSkillBounds(recipe, optionalReagents, qualityReagents, recraftItemGUID, order)
    local skillCheapest = skillBest * self:GetCheapestReagentWeight(qualityReagents) / Reagents:GetMaxWeight(qualityReagents)

    local canDecrease = (breakpoints[quality] or 0) * difficulty > skillBase + skillCheapest
    local canIncrease = (breakpoints[quality+1] or math.huge) * difficulty <= skillBase + skillBest

    return canDecrease or false, canIncrease or false
end

---------------------------------------
--             Reagents
---------------------------------------

---@param qualityReagents CraftingReagentSlotSchematic[]
---@return number
function Self:GetCheapestReagentWeight(qualityReagents)
    local cheapestWeight = 0
    for _,reagent in pairs(qualityReagents) do
        local _, q2, q3 = self:GetReagentQuantitiesForWeight(reagent, 0)
        cheapestWeight = cheapestWeight + (q2 + 2 * q3) * Reagents:GetWeight(reagent)
    end
    return cheapestWeight
end

---@param reagent CraftingReagentSlotSchematic
---@param weight number
---@param p1? number
---@param p2? number
---@param p3? number
function Self:GetReagentQuantitiesForWeight(reagent, weight, p1, p2, p3)
    if not p1 then p1, p2, p3 = Prices:GetReagentPrices(reagent) end

    local q, q2, q3 = reagent.quantityRequired, 0, 0

    if p3 < p1 and p3 < p2 then return 0, 0, q end

    q3 = math.max(0, weight - q)

    if p2 < p1 and p2 < p3 then return 0, q - q3, q3 end

    local w, r = weight - 2 * q3, weight % 2
    if 2 * p2 <= p1 + p3 then
        q2 = q2 + w
    else
        q2, q3 = r, q3 + (w - r) / 2
    end

    return q - q2 - q3, q2, q3
end

---@param reagent CraftingReagentSlotSchematic
---@param weight number
---@return ProfessionTransationAllocations
function Self:CreateReagentAllocationsForWeight(reagent, weight)
    return Reagents:CreateAllocations(reagent, self:GetReagentQuantitiesForWeight(reagent, weight))
end

---------------------------------------
--               Caches
---------------------------------------

Self.Cache = {
    ---@type Cache<table, fun(self: Cache, recipe: CraftingRecipeSchematic, order?: CraftingOrderInfo): string>
    WeightsAndPrices = Addon:CreateCache(
        ---@param recipe CraftingRecipeSchematic
        ---@param order CraftingOrderInfo
        function (_, recipe, order) return Self:GetRecipeCacheKey(recipe, nil, order) end,
        1
    ),
    ---@type Cache<RecipeAllocation[], fun(self: Cache, recipe: CraftingRecipeSchematic, baseSkill: number, order?: CraftingOrderInfo, optionalReagents?: CraftingReagentInfo[]): string>
    Allocations = Addon:CreateCache(
        ---@param recipe CraftingRecipeSchematic
        ---@param baseSkill? number
        ---@param order CraftingOrderInfo
        ---@param optionalReagents? CraftingReagentInfo[]
        function(_, recipe, baseSkill, order, optionalReagents) return Self:GetRecipeCacheKey(recipe, baseSkill, order, optionalReagents) end,
        10
    )
}

---@param recipe CraftingRecipeSchematic
---@param baseSkill? number
---@param order? CraftingOrderInfo
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetRecipeCacheKey(recipe, baseSkill, order, optionalReagents)
    local key = ("%d|%d|%d|%d"):format(
        recipe.recipeID,
        recipe.isRecraft and 1 or 0,
        baseSkill or 0,
        order and order.orderID or 0
    )

    if optionalReagents then
        for _,reagent in pairs(optionalReagents) do
            key = key .. ("||%d|%d"):format(reagent.itemID, reagent.quantity)
        end
    end

    return key
end
