---@class Addon
local Addon = select(2, ...)
local Prices, Promise, Reagents, Recipes, Util = Addon.Prices, Addon.Promise, Addon.Reagents, Addon.Recipes, Addon.Util

---@class Optimization
local Self = Addon.Optimization

---@enum Optimization.Method
Self.Method = {
    Cost = "COST",
    Profit = "PROFIT",
    ProfitPerConcentration = "PROFIT_PER_CONCENTRATION"
}

---------------------------------------
--              Crafts
---------------------------------------

---@param operation Operation
---@param method Optimization.Method
function Self:GetOperationAllocations(operation, method)
    if Util:OneOf(method, self.Method.Profit, self.Method.ProfitPerConcentration) then
        return self:GetRecipeProfitAllocations(operation:WithFinishingReagents(), method == self.Method.ProfitPerConcentration)
    else
        return self:GetRecipeCostAllocations(operation)
    end
end

---@param operation Operation
---@param method Optimization.Method
function Self:GetOperationValue(operation, method)
    if method == Self.Method.Cost then
        return operation:GetReagentPrice()
    elseif method == Self.Method.Profit then
        return (operation:GetProfit())
    elseif method == Self.Method.ProfitPerConcentration then
        return operation:GetProfitPerConcentration()
    end
end

-- Get best recipe allocation for given optimization method
---@param recipe CraftingRecipeSchematic
---@param method Optimization.Method
function Self:GetRecipeAllocation(recipe, method)
    -- Only items and enchants
    if recipe.isRecraft or not recipe.hasCraftingOperationInfo then return end
    if not Util:OneOf(recipe.recipeType, Enum.TradeskillRecipeType.Item, Enum.TradeskillRecipeType.Enchant) then return end

    local operation = Addon:CreateOperation(recipe, nil, nil, method == Self.Method.ProfitPerConcentration)

    -- Only tradable crafts
    if Util:OneOf(method, Self.Method.Profit, Self.Method.ProfitPerConcentration) and not operation:HasProfit() then return end

    local operations = self:GetOperationAllocations(operation, method)
    if not operations then return end

    local d = method == Self.Method.Cost and -1 or 1
    local bestOperation, bestValue, lastPrice

    for i=5, 1, -1 do repeat
        local operation = operations[i]
        if not operation then break end

        -- Ignore lower qualities with higher prices
        if Util:OneOf(method, Self.Method.Profit, Self.Method.ProfitPerConcentration) then
            local price = operation:GetResultPrice()
            if lastPrice and price >= lastPrice then break end
            lastPrice = price
        end

        local value = self:GetOperationValue(operation, method)

        if not value or abs(value) == math.huge then break end
        if bestValue and value * d <= bestValue * d then break end

        bestOperation, bestValue = operation, value
    until true end

    return bestOperation
end

-- Get optimized allocations for given optimization method
---@param recipe CraftingRecipeSchematic
---@param method Optimization.Method
---@param transaction? ProfessionTransaction
---@param orderOrRecraftGUID? CraftingOrderInfo | string
function Self:GetRecipeAllocations(recipe, method, transaction, orderOrRecraftGUID)
    local applyConcentration = method == self.Method.ProfitPerConcentration
    local allocation

    if transaction then
        applyConcentration = applyConcentration or transaction:IsApplyingConcentration()
        allocation = Util:TblCopy(transaction.allocationTbls, true)
    end

    local operation = Addon:CreateOperation(recipe, allocation, orderOrRecraftGUID, applyConcentration)

    return self:GetOperationAllocations(operation, method)
end

-- Recipe alloctions that maximize profit
---@param operation Operation
---@param optimizeConcentration? boolean
function Self:GetRecipeProfitAllocations(operation, optimizeConcentration)
    -- Check allocations cache
    local cache = self.Cache.ProfitAllocations
    local key = cache:Key(operation, optimizeConcentration)

    if cache:Has(key) then return cache:Get(key) end

    Promise:YieldFirst()

    local skillBase = operation:GetSkillBounds()
    if not skillBase then return end

    Promise:YieldTime("GetRecipeProfitAllocations: Skill")

    ---@type Operation[]
    local operations = Util:TblCopy(self:GetRecipeCostAllocations(operation) --[=[@as Operation[]]=])

    if optimizeConcentration or operation:HasProfit() then
        local prevQuality, prevPrice = math.huge, math.huge

        for qualityID,operation in pairs(operations) do
            local optimizeConcentration = optimizeConcentration and operation:GetConcentrationCost() > 0

            Promise:YieldTime("GetRecipeProfitAllocations: Concentration cost")

            ---@type number
            local profit
            if not optimizeConcentration then
                profit = operation:GetProfit() --[[@as number]]
            else
                local reagents = self:GetReagentsForMethod(operation, self.Method.ProfitPerConcentration)
                operation = operation:WithQualityReagents(reagents)
                profit = operation:GetProfitPerConcentration() --[[@as number]]

                Promise:YieldTime("GetRecipeProfitAllocations: Profit per concentration 1")
            end

            local bonusSkill = operation:GetOperationInfo().bonusSkill
            local maxProfit, maxProfitOperation = profit, operation
            local finishingReagents = {}

            for i,reagent in pairs(operation:GetFinishingReagentSlots()) do
                for j,item in ipairs_reverse(reagent.reagents) do
                    local itemID = item.itemID ---@cast itemID -?
                    local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
                    local price = Prices:GetItemPrice(itemID)

                    if quality and price > 0 and (quality > prevQuality or price < prevPrice) then
                        finishingReagents[1] = Reagents:CreateCraftingInfoFromSchematic(reagent, j)

                        ---@type Operation, number
                        local operation, profit = operation:WithFinishingReagents(finishingReagents), nil

                        ---@todo Nothing that modifies skill requirements, for now
                        if operation:GetOperationInfo().bonusSkill == bonusSkill then
                            if not optimizeConcentration then
                                profit = operation:GetProfit() --[[@as number]]
                            else
                                local reagents = self:GetReagentsForMethod(operation, self.Method.ProfitPerConcentration)
                                operation = operation:WithQualityReagents(reagents)
                                profit = operation:GetProfitPerConcentration() --[[@as number]]

                                Promise:YieldTime("GetRecipeProfitAllocations: Profit per concentration 2")
                            end

                            if profit > maxProfit then
                                maxProfit, maxProfitOperation = profit, operation
                            end

                            prevQuality, prevPrice = quality, price
                        end
                    end
                end
            end

            operations[qualityID] = maxProfitOperation

            Promise:YieldTime("GetRecipeProfitAllocations: End")
        end
    end

    cache:Set(key, operations)

    return operations
end

-- Recipe allocations that minimize cost
---@param operation Operation
function Self:GetRecipeCostAllocations(operation)
    -- Check allocations cache
    local cache = self.Cache.CostAllocations
    local key = cache:Key(operation)

    if cache:Has(key) then return cache:Get(key) end

    Promise:YieldFirst()

    local skillBase, skillBest = operation:GetSkillBounds()
    if not skillBase then return end

    Promise:YieldTime("GetRecipeCostAllocations: Skill")

    local breakpoints = operation:GetQualityBreakpoints()
    local difficulty = operation:GetDifficulty()
    local maxWeight = operation:GetMaxWeight()

    local _, prices = self:GetRecipeWeightsAndPrices(operation)

    ---@type Operation[]
    local operations = {}
    local prevPrice = math.huge

    for i=#breakpoints, 1, -1 do
        local breakpointSkill = max(0, breakpoints[i] * difficulty - skillBase)

        if breakpointSkill <= skillBest then
            local weight = math.ceil(breakpointSkill * maxWeight / skillBest)
            local price = prices[weight]

            if price > prevPrice then break end
            prevPrice = price

            operations[i] = operation:WithQualityReagents(self:GetReagentsForWeight(operation, weight))
        end

        if breakpointSkill == 0 then break end

        Promise:YieldTime("GetRecipeCostAllocations: End")
    end

    cache:Set(key, operations)

    return operations
end

---@param operation Operation
---@return table<number, table<number, number>>
---@return table<number, number>
function Self:GetRecipeWeightsAndPrices(operation)
    -- Check weights cache
    local cache = self.Cache.WeightsAndPrices
    local key = cache:Key(operation)

    if cache:Has(key) then return unpack(cache:Get(key)) end

    Promise:YieldFirst()

    local qualitySlots = operation:GetQualityReagentSlots()

    -- Intialize knapsack matrices
    ---@type table<number, table<number, number>>, table<number, table<number, number>>
    local prices, weights = { [0] = {}, { [0] = 0 } }, {}
    for i=1, #qualitySlots do weights[i] = {} end

    -- Compute lowest prices and corresponding reagent allocations
    for i,reagent in ipairs(qualitySlots) do
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

            Promise:YieldTime("GetRecipeWeightsAndPrices: Inner")
        end

        Promise:YieldTime("GetRecipeWeightsAndPrices: End")
    end

    cache:Set(key, { weights, prices[1] })

    return weights, prices[1]
end

---@param recipe CraftingRecipeSchematic
---@param quality number
---@param optionalReagents? CraftingReagentInfo[]
---@param orderOrRecraftGUID? CraftingOrderInfo | string
function Self:CanChangeCraftQuality(recipe, quality, optionalReagents, orderOrRecraftGUID)
    local order = type(orderOrRecraftGUID) == "table" and orderOrRecraftGUID or nil

    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipe.recipeID) ---@cast recipeInfo -?
    if recipeInfo.maxQuality == 0 then return false, false end

    local qualityReagents = Reagents:GetQualitySlots(recipe, order)
    local reagents = Reagents:CreateCraftingInfosFromSchematics(qualityReagents, optionalReagents)
    local operationInfo = Recipes:GetOperationInfo(recipe, reagents, orderOrRecraftGUID)

    local breakpoints = Addon.QUALITY_BREAKPOINTS[recipeInfo.maxQuality]
    local difficulty = operationInfo.baseDifficulty + operationInfo.bonusDifficulty

    local skillBase, skillBest = Reagents:GetSkillBounds(recipe, qualityReagents, optionalReagents, orderOrRecraftGUID)
    local skillCheapest = skillBest * self:GetCheapestReagentWeight(qualityReagents) / Reagents:GetMaxWeight(qualityReagents)

    local canDecrease = (breakpoints[quality] or 0) * difficulty > skillBase + skillCheapest
    local canIncrease = (breakpoints[quality+1] or math.huge) * difficulty <= skillBase + skillBest

    return canDecrease or false, canIncrease or false
end

---------------------------------------
--             Reagents
---------------------------------------

---@param qualitySlots CraftingReagentSlotSchematic[]
---@return number
function Self:GetCheapestReagentWeight(qualitySlots)
    local cheapestWeight = 0
    for _,reagent in pairs(qualitySlots) do
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

---@param operation Operation
---@param weight number
function Self:GetReagentsForWeight(operation, weight)
    ---@type CraftingReagentInfo[]
    local reagents = {}

    local weights = self:GetRecipeWeightsAndPrices(operation)
    local qualitySlots = operation:GetQualityReagentSlots()

    for j=#qualitySlots, 1, -1 do
        local reagent = qualitySlots[j]
        local w = weights[j][weight]

        Reagents:AddCraftingInfos(reagents, reagent, self:GetReagentQuantitiesForWeight(reagent, w))

        weight = math.max(0, weight - w * Reagents:GetWeight(reagent))
    end

    return reagents
end

---@param operation Operation
---@param method Optimization.Method
function Self:GetReagentsForMethod(operation, method)
    local _, prices = self:GetRecipeWeightsAndPrices(operation)

    local lowerWeight, upperWeight = operation:GetWeightThresholds()

    if Util:OneOf(method, self.Method.Cost, self.Method.Profit) then
        return self:GetReagentsForWeight(operation, lowerWeight)
    end

    local profit = operation:GetProfit()
    local qualityReagentsPrice = Prices:GetReagentsPrice(operation:GetQualityReagents())
    local resFactor = operation:GetResourcefulnessFactor()

    local lowerProfit = profit + (qualityReagentsPrice - prices[lowerWeight]) * (1 - resFactor)
    local lowerCon = operation:GetConcentrationCost(lowerWeight)

    local maxRelProfit, maxProfitWeight = lowerProfit / lowerCon, lowerWeight
    local prevProfit, prevCon = lowerProfit, lowerCon

    for weight = lowerWeight + 1, upperWeight do repeat
        local weightPrice, nextPrice = prices[weight], prices[weight + 1] or math.huge
        if weightPrice >= nextPrice then break end

        local profit = profit + (qualityReagentsPrice - weightPrice) * (1 - resFactor)
        local hasProfit = profit >= 0

        if not hasProfit and maxRelProfit >= 0 then break end

        -- Profit per concentration (profit >= 0) or marginal cost (profit < 0)
        local concentration = operation:GetConcentrationCost(weight)
        local relProfit = hasProfit and profit / concentration or (profit - prevProfit) / (prevCon - concentration)

        if relProfit > maxRelProfit then
            maxProfitWeight = weight
            prevProfit, prevCon = profit, concentration

            if hasProfit then maxRelProfit = relProfit end
        end

        Promise:YieldTime("GetReagentsForMethod: End")
    until true end

    return self:GetReagentsForWeight(operation, maxProfitWeight)
end

---------------------------------------
--               Caches
---------------------------------------

Self.Cache = {
    ---@type Cache<table, fun(self: Cache, operation: Operation): string>
    WeightsAndPrices = Addon.Cache:Create(
        ---@param operation Operation
        function (_, operation)
            return Self:GetRecipeCacheKey(operation)
        end,
        5
    ),
    ---@type Cache<Operation[], fun(self: Cache, operation: Operation): string>
    CostAllocations = Addon.Cache:Create(
        ---@param operation Operation
        function(_, operation)
            return Self:GetRecipeCacheKey(operation, true)
        end,
        10
    ),
    ---@type Cache<Operation[], fun(self: Cache, operation: Operation, optimizeConcentration?: boolean): string>
    ProfitAllocations = Addon.Cache:Create(
        ---@param operation Operation
        ---@param optimizeConcentration? boolean
        function(_, operation, optimizeConcentration)
            return Self:GetRecipeCacheKey(operation, true, optimizeConcentration)
        end,
        10
    )
}

---@param operation Operation
---@param optionalReagents? boolean
---@param optimizeConcentration? boolean
function Self:GetRecipeCacheKey(operation, optionalReagents, optimizeConcentration)
    local order = operation:GetOrder()
    local profInfo = operation:GetProfessionInfo()

    local key = ("%d;%d;%d;%d;%d;%d"):format(
        operation.recipe.recipeID,
        operation.recipe.isRecraft and 1 or 0,
        profInfo and profInfo.skillLevel + profInfo.skillModifier or 0,
        order and order.orderID or 0,
        operation.applyConcentration and 1 or 0,
        optimizeConcentration and 1 or 0
    )

    if optionalReagents then
        for _,reagent in pairs(operation:GetOptionalReagents()) do
            key = key .. (";;%d;%d"):format(reagent.itemID, reagent.quantity)
        end
    end

    return key
end
