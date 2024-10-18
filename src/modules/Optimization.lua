---@class Addon
local Addon = select(2, ...)
local Async, Reagents, Recipes, Prices, Util = Addon.Async, Addon.Reagents, Addon.Recipes, Addon.Prices, Addon.Util

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

-- Get optimized allocations for given optimization method
---@param recipe CraftingRecipeSchematic
---@param method Optimization.Method
---@param transaction ProfessionTransaction
---@param orderOrRecraftGUID? CraftingOrderInfo | string
function Self:GetRecipeAllocations(recipe, method, transaction, orderOrRecraftGUID)
    local optimizeConcentration = method == self.Method.ProfitPerConcentration
    local applyConcentration = optimizeConcentration or transaction:IsApplyingConcentration()
    local allocation = Util:TblCopy(transaction.allocationTbls, true)

    -- Make sure all reagents provided by orders are allocated
    local order = type(orderOrRecraftGUID) == "table" and orderOrRecraftGUID
    if order and order.reagents then
        for _,reagent in pairs(order.reagents) do
            Reagents:Allocate(allocation[reagent.slotIndex], reagent.reagent)
        end
    end

    local operation = Addon:CreateOperation(recipe, allocation, orderOrRecraftGUID, applyConcentration)

    if Util:OneOf(method, self.Method.Profit, self.Method.ProfitPerConcentration) then
        return self:GetRecipeProfitAllocations(operation:WithFinishingReagents(), optimizeConcentration)
    else
        return self:GetRecipeCostAllocations(operation)
    end
end

-- Recipe alloctions that maximize profit
---@param operation Operation
---@param optimizeConcentration? boolean
function Self:GetRecipeProfitAllocations(operation, optimizeConcentration)
    local skillBase = operation:GetSkillBounds()
    if not skillBase then return end

    -- Check allocations cache
    local cache = self.Cache.ProfitAllocations
    local key = cache:Key(operation, optimizeConcentration)

    if cache:Has(key) then return cache:Get(key) end

    ---@type Operation[]
    local operations = Util:TblCopy(self:GetRecipeCostAllocations(operation) --[=[@as Operation[]]=])

    if operation:HasProfit() then
        local prevQuality, prevPrice = math.huge, math.huge

        for qualityID,operation in pairs(operations) do
            ---@type number
            local profit
            if not optimizeConcentration then
                profit = operation:GetProfit() --[[@as number]]
            else
                local reagents = self:GetReagentsForMethod(operation, self.Method.ProfitPerConcentration)
                operation = operation:WithQualityReagents(reagents)
                profit = operation:GetProfitPerConcentration() --[[@as number]]
            end

            local bonusSkill = operation:GetOperationInfo().bonusSkill
            local maxProfit, maxProfitOperation = profit, operation

            for i,reagent in pairs(operation:GetFinishingReagentSlots()) do
                for j,item in ipairs_reverse(reagent.reagents) do
                    local itemID = item.itemID ---@cast itemID -?
                    local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
                    local price = Prices:GetItemPrice(itemID)

                    if quality and price > 0 and (quality > prevQuality or price < prevPrice) then
                        local finishingReagents = { Reagents:CreateCraftingInfoFromSchematic(reagent, j) }

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
        end
    end

    cache:Set(key, operations)

    return operations
end

-- Recipe allocations that minimize cost
---@param operation Operation
function Self:GetRecipeCostAllocations(operation)
    local skillBase, skillBest = operation:GetSkillBounds()
    if not skillBase then return end

    -- Check allocations cache
    local cache = self.Cache.CostAllocations
    local key = cache:Key(operation)

    if cache:Has(key) then return cache:Get(key) end

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

        Async:Yield()
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
        end
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

    ---@type number, number
    local maxProfit, maxProfitWeight = -math.huge, nil
    local prevPrice = math.huge

    for weight=upperWeight, lowerWeight, -1 do
        local weightPrice = prices[weight]

        if weightPrice < prevPrice then
            local profit = profit + (qualityReagentsPrice - weightPrice) * (1 - resFactor)

            if method == self.Method.ProfitPerConcentration then
                profit = profit / operation:GetConcentrationCost(weight)
            end


            if profit > maxProfit then
                maxProfit, maxProfitWeight = profit, weight
            end
        end

        prevPrice = weightPrice
    end

    Async:Yield()

    return self:GetReagentsForWeight(operation, maxProfitWeight)
end

---------------------------------------
--               Caches
---------------------------------------

Self.Cache = {
    ---@type Cache<table, fun(self: Cache, operation: Operation): string>
    WeightsAndPrices = Addon:CreateCache(
        ---@param operation Operation
        function (_, operation) 
            return Self:GetRecipeCacheKey(operation)
        end,
        5
    ),
    ---@type Cache<Operation[], fun(self: Cache, operation: Operation): string>
    CostAllocations = Addon:CreateCache(
        ---@param operation Operation
        function(_, operation)
            return Self:GetRecipeCacheKey(operation, true)
        end,
        10
    ),
    ---@type Cache<Operation[], fun(self: Cache, operation: Operation, optimizeConcentration?: boolean): string>
    ProfitAllocations = Addon:CreateCache(
        ---@param operation Operation
        ---@param optimizeConcentration? boolean
        function(_, operation, optimizeConcentration)
            return Self:GetRecipeCacheKey(operation, true, optimizeConcentration)
        end,
        10
    ),
}

---@param operation Operation
---@param optionalReagents? boolean
---@param optimizeConcentration? boolean
function Self:GetRecipeCacheKey(operation, optionalReagents, optimizeConcentration)
    local order = operation:GetOrder()

    local key = ("%d|%d|%d|%d|%d|%d"):format(
        operation.recipe.recipeID,
        operation.recipe.isRecraft and 1 or 0,
        operation:GetOperationInfo().baseSkill or 0,
        order and order.orderID or 0,
        operation.applyConcentration and 1 or 0,
        optimizeConcentration and 1 or 0
    )

    if optionalReagents then
        for _,reagent in pairs(operation:GetOptionalReagents()) do
            key = key .. ("||%d|%d"):format(reagent.itemID, reagent.quantity)
        end
    end

    return key
end
