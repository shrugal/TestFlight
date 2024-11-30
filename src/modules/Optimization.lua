---@class Addon
local Addon = select(2, ...)
local Cache, Operation, Prices, Promise, Reagents, Recipes, Util = Addon.Cache, Addon.Operation, Addon.Prices, Addon.Promise, Addon.Reagents, Addon.Recipes, Addon.Util

---@class Optimization
local Self = Addon.Optimization

---@enum Optimization.Method
Self.Method = {
    Cost = "COST",
    CostPerConcentration = "COST_PER_CONCENTRATION",
    Profit = "PROFIT",
    ProfitPerConcentration = "PROFIT_PER_CONCENTRATION"
}

---------------------------------------
--              Crafts
---------------------------------------

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

    local operation = Operation:Create(recipe, nil, nil, method == Self.Method.ProfitPerConcentration)

    -- Only tradable crafts
    if Util:OneOf(method, Self.Method.Profit, Self.Method.ProfitPerConcentration) and not operation:HasProfit() then return end

    local operations = self:GetAllocationsForMethod(operation, method)

    if not operations then return end

    local d = method == Self.Method.Cost and -1 or 1
    local bestOperation, bestValue, lastQuality, lastPrice

    for i=5, 1, -1 do repeat
        local operation = operations[i]
        if not operation then break end

        -- Ignore lower qualities with higher or equal prices
        if Util:OneOf(method, Self.Method.Profit, Self.Method.ProfitPerConcentration) then
            local quality, price = operation:GetResultQuality(), operation:GetResultPrice()
            if lastQuality and lastPrice and quality < lastQuality and price >= lastPrice then break end
            lastQuality, lastPrice = quality,  price
        end

        local value = self:GetOperationValue(operation, method)

        if not value or abs(value) == math.huge then break end
        if bestValue and value * d <= bestValue * d then break end

        bestOperation, bestValue = operation, value
    until true end

    return bestOperation
end

---@param order CraftingOrderInfo
---@param tx? ProfessionTransaction
function Self:GetOrderAllocation(order, tx)
    local quality = tx and tx:IsApplyingConcentration() and order.minQuality - 1 or order.minQuality
    local recipe = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft)
    local operations = self:GetRecipeAllocations(recipe, self.Method.Profit, tx, order)
    return operations and operations[math.max(quality, Util:TblMinKey(operations))]
end

-- Get optimized allocations for given optimization method
---@param recipe CraftingRecipeSchematic
---@param method Optimization.Method
---@param tx? ProfessionTransaction
---@param orderOrRecraftGUID? CraftingOrderInfo | string
function Self:GetRecipeAllocations(recipe, method, tx, orderOrRecraftGUID)
    local applyConcentration = method == self.Method.ProfitPerConcentration
    local operation

    if tx then
        local allocation = Util:TblCopy(tx.allocationTbls, true)
        operation = Operation:Create(recipe, allocation, orderOrRecraftGUID, applyConcentration or tx:IsApplyingConcentration())

        -- Remove finishing reagents for profit optimizations
        ---@todo Skill modifiying finishing slots should stay untouched
        if Util:OneOf(method, Self.Method.Profit, Self.Method.ProfitPerConcentration) then
            operation = operation:WithFinishingReagents()
        end
    else
        operation = Operation:Create(recipe, nil, orderOrRecraftGUID, applyConcentration)
    end

    return self:GetAllocationsForMethod(operation, method)
end

-- Recipe alloctions for given optimization method
---@param operation Operation
---@param method Optimization.Method
function Self:GetAllocationsForMethod(operation, method)
    local optimizeProfit = Util:OneOf(method, Self.Method.Profit, Self.Method.CostPerConcentration, Self.Method.ProfitPerConcentration)
    local optimizeConcentration = Util:OneOf(method, Self.Method.CostPerConcentration, Self.Method.ProfitPerConcentration)

    local cache = self.Cache.Allocations
    local key = cache:Key(operation, method)

    if cache:Has(key) then return cache:Get(key) end

    Promise:YieldFirst()

    Util:DebugProfileLevel("GetAllocationsForMethod")

    Util:DebugProfileSegment("GetMinCostAllocations")

    local operations = self:GetMinCostAllocations(operation)

    Util:DebugProfileSegment()

    if operations and (optimizeConcentration or optimizeProfit) then
        operations = Util:TblCopy(operations) --[=[@as Operation[]]=]

        local prevQuality, prevPrice, prevName = math.huge, math.huge, nil

        for qualityID,operation in pairs(operations) do
            local optimizeConcentration = optimizeConcentration and operation:GetConcentrationCost() > 0
            Promise:YieldTime()

            local baseWeight = operation:GetWeight()

            if optimizeConcentration then
                Util:DebugProfileSegment("Concentration")

                local weight = self:GetWeightForMethod(operation, method)
                Promise:YieldTime()

                if weight ~= baseWeight then
                    operation = operation:WithWeightReagents(self:GetReagentsForWeight(operation, weight))
                end
            end

            if optimizeProfit then
                Util:DebugProfileLevel("Profit")

                local profit = optimizeConcentration and operation:GetProfitPerConcentration() or operation:GetProfit()
                local bonusSkill = operation:GetOperationInfo().bonusSkill
                local maxProfit, maxProfitOperation = profit, operation
                local finishingReagents = {}

                for i,reagent in pairs(operation.recipe.reagentSlotSchematics) do repeat
                    if not Reagents:IsFinishing(reagent) or Reagents:IsLocked(reagent, operation:GetRecipeInfo()) then break end

                    for j,item in ipairs_reverse(reagent.reagents) do repeat
                        Util:DebugProfileSegment()

                        ---@todo Nothing that modifies skill requirements, for now
                        if Reagents:GetStatBonus(item, "sk") > 0 then break end

                        local itemID = item.itemID ---@cast itemID -?
                        local name, quality = C_Item.GetItemInfo(itemID), C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
                        local price = Prices:GetItemPrice(itemID)

                        -- Check quality and price
                        if not quality or price == 0 or quality < prevQuality and price >= prevPrice then break end

                        finishingReagents[1] = Reagents:CreateCraftingInfoFromSchematic(reagent, j)

                        Util:DebugProfileSegment("WithFinishingReagents")

                        ---@type Operation, number
                        local operation, profit = operation:WithFinishingReagents(finishingReagents), nil
                        local baseWeight = operation:GetWeight()

                        Util:DebugProfileSegment("bonusSkill")

                        ---@todo Nothing that modifies skill requirements, for now
                        if operation:GetOperationInfo().bonusSkill ~= bonusSkill then break end

                        if optimizeConcentration and (not name or name ~= prevName) then
                            Util:DebugProfileSegment("Concentration")

                            local weight = self:GetWeightForMethod(operation, method)
                            Promise:YieldTime()

                            if weight ~= baseWeight then
                                operation = operation:WithWeightReagents(self:GetReagentsForWeight(operation, weight))
                            else
                                prevName = name
                            end
                        end

                        Util:DebugProfileSegment("GetProfit")

                        profit = optimizeConcentration and operation:GetProfitPerConcentration() or operation:GetProfit()

                        Util:DebugProfileSegment()

                        if profit > maxProfit then
                            maxProfit, maxProfitOperation = profit, operation
                        end

                        prevQuality, prevPrice = quality, price
                    until true end
                until true end

                Util:DebugProfileLevelStop()

                operation = maxProfitOperation
            end

            operations[qualityID] = operation

            Promise:YieldTime()
        end
    end

    Util:DebugProfileSegment()

    cache:Set(key, operations)

    Util:DebugProfileLevelStop()

    return operations
end

-- Recipe allocations that minimize cost
---@param operation Operation
function Self:GetMinCostAllocations(operation)
    local cache = self.Cache.Allocations
    local key = cache:Key(operation, Self.Method.Cost)

    if cache:Has(key) then return cache:Get(key) end

    Promise:YieldFirst()

    local skillBase, skillBest = operation:GetSkillBounds(true)
    if not skillBase then return end

    Promise:YieldTime()

    local breakpoints = operation:GetQualityBreakpoints()
    local difficulty = operation:GetDifficulty()
    local weightPerSkill = operation:GetWeightPerSkill()

    local _, prices = self:GetWeightsAndPrices(operation)

    ---@type Operation[]
    local operations = {}
    local prevPrice = math.huge

    for i=#breakpoints, 1, -1 do
        local breakpointSkill = max(0, breakpoints[i] * difficulty - skillBase)

        if breakpointSkill <= skillBest then
            local weight = ceil(breakpointSkill * weightPerSkill)
            local price = prices[weight]

            if price > prevPrice then break end
            prevPrice = price

            operations[i] = operation:WithWeightReagents(self:GetReagentsForWeight(operation, weight))
        end

        if breakpointSkill == 0 then break end

        Promise:YieldTime()
    end

    cache:Set(key, operations)

    return operations
end

---@param operation Operation
---@return table<number, table<number, number>>
---@return table<number, number>
---@return number?
function Self:GetWeightsAndPrices(operation)
    local cache = self.Cache.WeightsAndPrices
    local key = cache:Key(operation)

    if cache:Has(key) then return unpack(cache:Get(key)) end

    Promise:YieldFirst()

    local weightSlots = operation:GetWeightReagentSlots()

    -- Intialize knapsack matrices
    ---@type table<number, table<number, number>>, table<number, table<number, number>>, number?
    local prices, weights, weightPerSkill = { [0] = {}, { [0] = 0 } }, {}, nil
    for i=1, #weightSlots do weights[i] = {} end

    -- Compute lowest prices and corresponding reagent allocations
    for i,slot in ipairs(weightSlots) do
        prices[0], prices[1] = prices[1], wipe(prices[0])

        if Reagents:IsBonusSkill(slot) then
            if not weightPerSkill then weightPerSkill = operation:GetWeightPerSkill() end

            for w,v in pairs(prices[0]) do prices[1][w] = v; weights[i][w] = 0 end

            for j,reagent in pairs(slot.reagents) do repeat
                local price = Prices:GetReagentPrice(reagent)
                if price == 0 then break end

                local itemWeight = Reagents:GetWeight(reagent, weightPerSkill)
                local s = math.min(0, 1 - itemWeight)

                for k=s, #prices[0] do
                    local w = k + itemWeight
                    local newPrice = prices[0][math.max(0, k)] + price
                    local oldPrice = prices[1][w] or prices[0][w] or math.huge

                    if newPrice < oldPrice then
                        prices[1][w], weights[i][w] = newPrice, j
                    end
                end
            until true end
        else
            local p1, p2, p3 = Prices:GetReagentPrices(slot)
            local itemWeight = Reagents:GetWeight(slot)
            local s = math.min(0, 1 - itemWeight)

            for j=0, 2*slot.quantityRequired do
                local q1, q2, q3 = self:GetReagentQuantitiesForWeight(slot, j)
                local price = p1 * q1 + p2 * q2 + p3 * q3
                local contribution = j * itemWeight

                for k=s, #prices[0] do
                    local w = k + contribution
                    local newPrice = prices[0][math.max(0, k)] + price
                    local oldPrice = prices[1][w] or math.huge

                    if newPrice < oldPrice then
                        prices[1][w], weights[i][w] = newPrice, j
                    end
                end

                Promise:YieldTime()
            end
        end

        Promise:YieldTime()
    end

    cache:Set(key, { weights, prices[1], weightPerSkill })

    return weights, prices[1]
end

---@todo Migrate to Operations
---@param recipe CraftingRecipeSchematic
---@param quality number
---@param optionalReagents? CraftingReagentInfo[]
---@param order? CraftingOrderInfo
---@param recraftGUID? string
function Self:CanChangeCraftQuality(recipe, quality, optionalReagents, order, recraftGUID)
    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipe.recipeID) ---@cast recipeInfo -?
    if recipeInfo.maxQuality == 0 then return false, false end

    local qualityReagents = Reagents:GetQualitySlots(recipe, order, Reagents:GetRecraftMods(order, recraftGUID))
    local reagents = Reagents:CreateCraftingInfosFromSchematics(qualityReagents, optionalReagents)
    local operationInfo = Recipes:GetOperationInfo(recipe, reagents, order or recraftGUID)

    local breakpoints = Addon.QUALITY_BREAKPOINTS[recipeInfo.maxQuality]
    local difficulty = operationInfo.baseDifficulty + operationInfo.bonusDifficulty

    local skillBase, skillBest = Reagents:GetSkillBounds(recipe, qualityReagents, optionalReagents, order or recraftGUID)
    local skillCheapest = self:GetCheapestReagentWeight(qualityReagents) * skillBest / Reagents:GetMaxWeight(qualityReagents)

    if Reagents:GetBonusSkillSlot(recipe) then skillBest = skillBest + Reagents:GetMaxBonusSkill() end

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

    local weights, _, weightPerSkill = self:GetWeightsAndPrices(operation)
    local weightSlots = operation:GetWeightReagentSlots()

    for j=#weightSlots, 1, -1 do
        local reagent = weightSlots[j]
        local w = weights[j][weight]

        if not Reagents:IsBonusSkill(reagent) then
            Reagents:AddCraftingInfos(reagents, reagent, self:GetReagentQuantitiesForWeight(reagent, w))
        elseif w > 0 then
            Reagents:AddCraftingInfo(reagents, reagent, w, 1)
        end

        weight = math.max(0, weight - w * Reagents:GetWeight(reagent, weightPerSkill))
    end

    return reagents
end

---@param operation Operation
---@param method Optimization.Method
function Self:GetWeightForMethod(operation, method)
    Util:DebugProfileLevel("GetWeightForMethod")

    local _, prices = self:GetWeightsAndPrices(operation)

    Util:DebugProfileSegment("GetWeightThresholds")
    local lowerWeight, upperWeight = operation:GetWeightThresholds()
    Util:DebugProfileSegment()

    if Util:OneOf(method, self.Method.Cost, self.Method.Profit) then
        return lowerWeight
    end

    local optimizeProfit = method == Self.Method.ProfitPerConcentration

    local profit = operation:GetProfit()
    local qualityReagentsPrice = Prices:GetReagentsPrice(operation:GetQualityReagents())
    local resFactor = operation:GetResourcefulnessFactor()
    local lowerProfit = profit + (qualityReagentsPrice - prices[lowerWeight]) * (1 - resFactor)

    local lowerCon = operation:GetConcentrationCost(lowerWeight)

    local maxValue, maxValueWeight = optimizeProfit and lowerProfit / lowerCon or -Addon.DB.Account.concentrationCost, lowerWeight

    for weight = lowerWeight + 1, upperWeight do repeat
        local weightPrice, nextPrice = prices[weight], prices[weight + 1] or math.huge
        if weightPrice >= nextPrice then break end

        local profit = profit + (qualityReagentsPrice - weightPrice) * (1 - resFactor)
        if profit < 0 and maxValue >= 0 then break end

        local concentration = operation:GetConcentrationCost(weight)

        local value = optimizeProfit and profit / concentration or (profit - lowerProfit) / (lowerCon - concentration)

        if value > maxValue then
            maxValueWeight = weight
            lowerProfit, lowerCon = profit, concentration

            if optimizeProfit then maxValue = value end
        end

        Promise:YieldTime()
    until true end

    Util:DebugProfileLevelStop()

    return maxValueWeight
end

---------------------------------------
--               Caches
---------------------------------------

Self.Cache = {
    ---@type Cache<table, fun(self: Cache, operation: Operation): string>
    WeightsAndPrices = Cache:Create(
        ---@param operation Operation
        function (_, operation)
            return Self:GetRecipeCacheKey(operation)
        end,
        5
    ),
    ---@type Cache<Operation[], fun(self: Cache, operation: Operation, method: Optimization.Method): string>
    Allocations = Cache:Create(
        ---@param operation Operation
        ---@param method Optimization.Method
        function(_, operation, method)
            return Self:GetRecipeCacheKey(operation, method)
        end,
        20
    )
}

---@param operation Operation
---@param method? Optimization.Method
function Self:GetRecipeCacheKey(operation, method)
    local order = operation:GetOrder()
    local profInfo = operation:GetProfessionInfo()

    local key = ("%d;%d;%d;%d;%d;%d;%d;%d"):format(
        operation.recipe.recipeID,
        operation.recipe.isRecraft and 1 or 0,
        profInfo and profInfo.skillLevel + profInfo.skillModifier or 0 + Addon.extraSkill,
        order and order.orderID or 0,
        operation.applyConcentration and 1 or 0,
        method == Self.Method.CostPerConcentration and Addon.DB.Account.concentrationCost or 0,
        Prices:GetRecipeScanTime(operation.recipe, nil, order, operation:GetRecraftMods())
    )

    if method then
        key = method .. ";;" .. key

        for _,reagent in pairs(operation:GetOptionalReagents()) do
            key = key .. (";;%d;%d"):format(reagent.itemID, reagent.quantity)
        end
    end

    return key
end
