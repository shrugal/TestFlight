---@class Addon
local Addon = select(2, ...)
local Buffs, C, Cache, Operation, Prices, Promise, Reagents, Util = Addon.Buffs, Addon.Constants, Addon.Cache, Addon.Operation, Addon.Prices, Addon.Promise, Addon.Reagents, Addon.Util

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
        return (operation:GetProfitPerConcentration())
    end
end

-- Get best recipe allocation for given optimization method
---@param recipe CraftingRecipeSchematic
---@param method Optimization.Method
---@param includeNonTradable? boolean
function Self:GetRecipeAllocation(recipe, method, includeNonTradable)
    local operations = self:GetRecipeAllocations(recipe, method, includeNonTradable)
    if not operations then return end

    local d = method == Self.Method.Cost and -1 or 1
    local bestOperation, bestValue, lastQuality, lastPrice

    for i=5, 1, -1 do repeat
        local operation = operations[i]
        if not operation then break end

        local value = self:GetOperationValue(operation, method)

        if not value or abs(value) == math.huge then break end
        if bestValue and value * d <= bestValue * d then break end

        bestOperation, bestValue = operation, value
    until true end

    return bestOperation
end

-- Get best recipe allocations for given optimization method
---@param recipe CraftingRecipeSchematic
---@param method Optimization.Method
---@param includeNonTradable? boolean
function Self:GetRecipeAllocations(recipe, method, includeNonTradable)
    local applyConcentration = Util:OneOf(method, self.Method.CostPerConcentration, self.Method.ProfitPerConcentration)

    -- Only items and enchants
    if recipe.isRecraft or applyConcentration and not recipe.hasCraftingOperationInfo then return end
    if not Util:OneOf(recipe.recipeType, Enum.TradeskillRecipeType.Item, Enum.TradeskillRecipeType.Enchant) then return end

    local operation = Operation:Create(recipe, nil, nil, applyConcentration)

    -- Only tradable crafts
    if not includeNonTradable and Util:OneOf(method, Self.Method.Profit, Self.Method.ProfitPerConcentration) and not operation:HasProfit() then return end

    local operations = self:GetAllocationsForMethod(operation, method)
    if not operations then return end

    -- Ignore lower qualities with higher or equal prices
    if Util:OneOf(method, Self.Method.Profit, Self.Method.ProfitPerConcentration) then
        operations = Util:TblCopy(operations)

        local lastQuality, lastPrice

        for i=5, 1, -1 do repeat
            local operation = operations[i]
            if not operation then break end

            local quality, price = operation:GetResultQuality(), operation:GetResultPrice()
            if lastQuality and lastPrice and quality < lastQuality and price >= lastPrice then break end
            lastQuality, lastPrice = quality,  price
        until true end
    end

    return operations
end

---@param order CraftingOrderInfo
---@param tx? ProfessionTransaction
---@param extraSkill? boolean | number
function Self:GetOrderAllocation(order, tx, extraSkill)
    local recipe = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft)
    local applyConcentration = tx and tx:IsApplyingConcentration()
    local quality = order.minQuality

    -- Try without concentration
    if not applyConcentration then
        local operations = self:GetTransactionAllocations(recipe, self.Method.Profit, tx, order, extraSkill)
        if not operations then return end

        local operation = operations[math.max(quality, Util:TblMinKey(operations))]
        do return operation end ---@todo
        if operation or not operations[quality - 1] then return operation end
    end

    -- Try with concentration
    local operations = self:GetTransactionAllocations(recipe, self.Method.ProfitPerConcentration, tx, order, extraSkill)
    if not operations then return end

    return operations[math.max(quality - 1, Util:TblMinKey(operations))]
end

-- Get optimized allocations for given optimization method
---@param recipe CraftingRecipeSchematic
---@param method Optimization.Method
---@param tx? ProfessionTransaction
---@param orderOrRecraftGUID? CraftingOrderInfo | string
---@param extraSkill? boolean | number
function Self:GetTransactionAllocations(recipe, method, tx, orderOrRecraftGUID, extraSkill)
    local applyConcentration = Util:OneOf(method, self.Method.CostPerConcentration, self.Method.ProfitPerConcentration)
    local allocation

    if tx then
        applyConcentration = applyConcentration or tx:IsApplyingConcentration()
        allocation = Util:TblCopy(tx.allocationTbls, true)

        -- Clear tradable finishing reagents
        for slotIndex,alloc in pairs(allocation) do
            local slot = recipe.reagentSlotSchematics[slotIndex]
            if Reagents:IsFinishing(slot) and alloc:HasAnyAllocations() and Prices:HasReagentPrice(alloc.allocs[1]) then
                Reagents:ClearAllocations(alloc)
            end
        end
    end

    local operation = Operation:Create(recipe, allocation, orderOrRecraftGUID, applyConcentration, extraSkill)

    return self:GetAllocationsForMethod(operation, method)
end

---------------------------------------
--            Optimization
---------------------------------------

-- Recipe alloctions for given optimization method
---@param operation Operation
---@param method Optimization.Method
function Self:GetAllocationsForMethod(operation, method)
    if method == self.Method.Cost then return self:GetMinCostAllocations(operation) end

    local cache = self.Cache.ProfitAllocations
    local key = cache:Key(operation, method)

    if cache:Has(key) then return cache:Get(key) end

    Promise:YieldFirst()

    local isQualityCraft = operation:GetOperationInfo().isQualityCraft
    local optimizeTools = true
    local optimizeFinishingReagents = isQualityCraft and Util:OneOf(method, Self.Method.Profit, Self.Method.CostPerConcentration, Self.Method.ProfitPerConcentration)
    local optimizeConcentration = isQualityCraft and Util:OneOf(method, Self.Method.CostPerConcentration, Self.Method.ProfitPerConcentration)

    local operations = self:GetMinCostAllocations(operation)

    if operations then
        operations = Util:TblCopy(operations) --[=[@as Operation[]]=]

        local finishingReagents = optimizeFinishingReagents and {} or nil

        for quality,operation in pairs(operations) do
            -- Auras
            operation = operation:WithAuras(Buffs:GetCurrentAndEnabledAuras(operation.recipe))

            -- Concentration
            local optimizeConcentration = optimizeConcentration and operation:GetConcentrationCost() > 0
            operation = operation:WithConcentration(optimizeConcentration)

            Promise:YieldTime()

            local lowerWeight, upperWeight = operation:GetWeightThresholds()

            -- Optimize tool
            if optimizeTools then
                operation = self:GetBestToolAllocation(operation)
            end

            -- Optimize concentration
            if optimizeConcentration then
                operation, lowerWeight, upperWeight = self:GetBestConcentrationAllocation(operation, method, lowerWeight, upperWeight)
            end

            -- Optimize finishing reagents
            if optimizeFinishingReagents then ---@cast finishingReagents -?
                local bonusSkill = operation:GetOperationInfo().bonusSkill

                local prevQuality, prevPrice, prevName = math.huge, math.huge, nil
                local maxProfitOperation, maxProfit = operation, optimizeConcentration and operation:GetProfitPerConcentration() or operation:GetProfit()

                for slotIndex,slot in pairs(operation.recipe.reagentSlotSchematics) do repeat
                    if not Reagents:IsFinishing(slot) or Reagents:IsLocked(slot, operation:GetRecipeInfo()) then break end
                    if operation:HasAllocation(slotIndex) then break end

                    for i,item in ipairs_reverse(slot.reagents) do repeat
                        if Reagents:GetStatBonus(item, "SK") > 0 then break end

                        local itemID = item.itemID ---@cast itemID -?
                        local name, quality = C_Item.GetItemInfo(itemID), C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
                        local price = Prices:GetItemPrice(itemID)

                        -- Check quality and price
                        if not quality or price == 0 or quality < prevQuality and price >= prevPrice then break end

                        finishingReagents[1] = Reagents:CreateCraftingInfoFromSchematic(slot, i)

                        ---@type Operation, number
                        local operation = operation:WithFinishingReagents(finishingReagents, slotIndex)
                        local baseWeight = operation:GetWeight(true)

                        if operation:GetOperationInfo().bonusSkill ~= bonusSkill then break end

                        -- Optimize tool
                        if optimizeTools then
                            operation = self:GetBestToolAllocation(operation)
                        end

                        -- Optimize concentration
                        if optimizeConcentration and (not name or name ~= prevName) then
                            operation, lowerWeight, upperWeight = self:GetBestConcentrationAllocation(operation, method, lowerWeight, upperWeight)

                            -- If weight didn't change then it won't for lesser quality variants
                            if operation:GetWeight(true) == baseWeight then
                                prevName = name
                            end
                        end

                        local profit = optimizeConcentration and operation:GetProfitPerConcentration() or operation:GetProfit()

                        if profit > maxProfit then
                            maxProfit, maxProfitOperation = profit, operation
                        end

                        prevQuality, prevPrice = quality, price
                    until true end
                until true end

                operation = maxProfitOperation
            end

            operations[quality] = operation

            Promise:YieldTime()
        end
    end

    cache:Set(key, operations)

    return operations
end

-- Recipe allocations that minimize cost
---@param operation Operation
function Self:GetMinCostAllocations(operation)
    local cache = self.Cache.CostAllocations
    local key = cache:Key(operation)

    if cache:Has(key) then return cache:Get(key) end

    Promise:YieldFirst()

    operation = operation:WithConcentration(false)

    local skillBase, skillRange = operation:GetSkillBounds(true)
    if not skillBase then return end

    Promise:YieldTime()

    local breakpoints = operation:GetQualityBreakpoints()
    local difficulty = operation:GetDifficulty()
    local weightPerSkill = operation:GetWeightPerSkill()

    ---@type Operation[]
    local operations = {}
    local prevPrice, upperWeight = math.huge, operation:GetMaxWeight(true)

    for quality=#breakpoints, 1, -1 do
        local breakpointSkill = max(0, breakpoints[quality] * difficulty - skillBase)

        if breakpointSkill <= skillRange then
            local lowerWeight = ceil(breakpointSkill * weightPerSkill)

            local operation, lowerWeight = self:GetAllocationForQuality(operation, quality, Self.Method.Cost, lowerWeight, upperWeight)

            if operation then
                local price = operation:GetReagentPrice()
                if price > prevPrice then break end

                operations[quality] = operation

                prevPrice, upperWeight = price, lowerWeight - 1
            end
        end

        if breakpointSkill == 0 then break end

        Promise:YieldTime()
    end

    cache:Set(key, operations)

    return operations
end

---@param operation Operation
---@return number[][]
---@return number[]
function Self:GetWeightsAndPrices(operation)
    local cache = self.Cache.WeightsAndPrices
    local key = cache:Key(operation)

    if cache:Has(key) then return unpack(cache:Get(key)) end

    Promise:YieldFirst()

    local weightSlots = operation:GetWeightReagentSlots()

    -- Intialize knapsack matrices
    ---@type number[][], number[][], number?
    local prices, weights, weightPerSkill = { [0] = {}, { [0] = 0 } }, {}, nil
    for i=1, #weightSlots do weights[i] = {} end

    -- Compute lowest prices and corresponding reagent allocations
    for i,slot in ipairs(weightSlots) do repeat
        prices[0], prices[1] = prices[1], wipe(prices[0])

        if Reagents:IsBonusSkill(slot) then
            for w,v in pairs(prices[0]) do prices[1][w] = v; weights[i][w] = 0 end

            if operation:HasAllocation(slot.slotIndex) then break end

            if not weightPerSkill then weightPerSkill = operation:GetWeightPerSkill() end
            if weightPerSkill == 0 or weightPerSkill == math.huge then break end

            for j,reagent in pairs(slot.reagents) do repeat
                local price = Prices:GetReagentPrice(reagent)
                if price == 0 then break end

                local c = Reagents:GetWeight(reagent, weightPerSkill)

                for w=0, #prices[0] + c do
                    local newPrice = prices[0][max(0, w - c)] + price
                    local oldPrice = prices[1][w] or prices[0][w] or math.huge

                    if newPrice < oldPrice then
                        prices[1][w], weights[i][w] = newPrice, j
                    end
                end
            until true end
        else
            local p1, p2, p3 = Prices:GetReagentPrices(slot)
            local itemWeight = Reagents:GetWeight(slot)

            for j=0, 2*slot.quantityRequired do
                local q1, q2, q3 = self:GetReagentQuantitiesForWeight(slot, j)
                local price = p1 * q1 + p2 * q2 + p3 * q3
                local c = j * itemWeight

                for w=0, #prices[0] + c do
                    local newPrice = prices[0][max(0, w - c)] + price
                    local oldPrice = prices[1][w] or math.huge

                    if newPrice < oldPrice then
                        prices[1][w], weights[i][w] = newPrice, j
                    end
                end

                Promise:YieldTime()
            end
        end

        Promise:YieldTime()
    until true end

    cache:Set(key, { weights, prices[1] })

    return weights, prices[1]
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

    local weights = self:GetWeightsAndPrices(operation)
    local weightSlots = operation:GetWeightReagentSlots()
    local weightPerSkill = operation:GetWeightPerSkill()

    for i=#weightSlots, 1, -1 do
        local slot, j = weightSlots[i], weights[i][weight]

        if not Reagents:IsBonusSkill(slot) then
            Reagents:AddCraftingInfos(reagents, slot, self:GetReagentQuantitiesForWeight(slot, j))
            weight = math.max(0, weight - j * Reagents:GetWeight(slot))
        elseif j > 0 then
            Reagents:AddCraftingInfo(reagents, slot, j, 1)
            weight = math.max(0, weight - Reagents:GetWeight(slot.reagents[j], weightPerSkill))
        elseif operation:HasAllocation(slot.slotIndex) then
            local itemID = operation.allocation[slot.slotIndex].allocs[1].reagent.itemID
            Reagents:AddCraftingInfo(reagents, slot, Util:TblFindWhere(slot.reagents, "itemID", itemID), 1)
        end
    end

    return reagents
end

---@param operation Operation
---@param weight number 
---@param weights? number[][]
---@param prices? number[]
function Self:GetReagentPriceForWeight(operation, weight, weights, prices)
    if not weights or not prices then weights, prices = self:GetWeightsAndPrices(operation) end

    local resFactor = 1 - operation:GetResourcefulnessFactor()
    local price = (prices[weight] or math.huge) * resFactor

    local bonusSkillSlot = operation:GetBonusSkillReagentSlot()
    local bonusSkillReagent = bonusSkillSlot and bonusSkillSlot.reagents[weights[#weights]]

    if bonusSkillReagent then
        price = price + Prices:GetReagentPrice(bonusSkillReagent) * (1 - resFactor)
    end

    return price
end

---@param operation Operation
---@param method Optimization.Method
---@param lowerWeight number
---@param upperWeight number
function Self:GetWeightForMethod(operation, method, lowerWeight, upperWeight)
    if Util:OneOf(method, self.Method.Cost, self.Method.Profit) then
        return lowerWeight
    end

    local weights, prices = self:GetWeightsAndPrices(operation)

    local optimizeProfit = method == Self.Method.ProfitPerConcentration

    local profit = operation:GetProfit()
    local resFactor = 1 - operation:GetResourcefulnessFactor()
    local qualityReagentsPrice = Prices:GetReagentsPrice(operation:GetQualityReagents()) * resFactor
    local bonusSkillReagentPrice = Prices:GetReagentPrice(operation:GetBonusSkillReagent())
    local weightReagentsPrice = qualityReagentsPrice + bonusSkillReagentPrice

    local lowerProfit = profit + weightReagentsPrice - self:GetReagentPriceForWeight(operation, lowerWeight, weights, prices)
    local lowerCon = operation:GetConcentrationCost(lowerWeight)

    local maxValue, maxValueWeight = optimizeProfit and lowerProfit / lowerCon or -Addon.DB.Account.concentrationCost, lowerWeight

    for weight = lowerWeight + 1, upperWeight do repeat
        local weightPrice = self:GetReagentPriceForWeight(operation, weight, weights, prices)
        local nextWeightPrice = self:GetReagentPriceForWeight(operation, weight + 1, weights, prices)

        if weight < upperWeight and weightPrice >= nextWeightPrice then break end

        local profit = profit + weightReagentsPrice - weightPrice
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

    return maxValueWeight
end

local getReagents = Util:FnBind(Self.GetReagentsForWeight, Self)
local getWeight = Util(Self.Method):Flip():Map(function (_, method)
    return function (operation, lowerWeight, upperWeight)
        return Self:GetWeightForMethod(operation, method, lowerWeight, upperWeight)
    end
end, true)()

---@param operation Operation
---@param quality? number
---@param method Optimization.Method
---@param lowerWeight number
---@param upperWeight number
function Self:GetAllocationForQuality(operation, quality, method, lowerWeight, upperWeight)
    return operation:WithQuality(
        quality or operation:GetQuality(),
        lowerWeight,
        upperWeight,
        getWeight[method],
        getReagents
    )
end

---@param operation Operation
---@param method Optimization.Method
---@param lowerWeight number
---@param upperWeight number
---@return Operation
---@return number lowerWeight
---@return number upperWeight
function Self:GetBestConcentrationAllocation(operation, method, lowerWeight, upperWeight)
    ---@diagnostic disable-next-line: cast-local-type
    operation, lowerWeight, upperWeight = self:GetAllocationForQuality(operation, nil, method, lowerWeight, upperWeight) ---@cast operation -?
    return operation, lowerWeight, upperWeight
end

---------------------------------------
--               Buffs
---------------------------------------

---@param operation Operation
function Self:GetBestToolAllocation(operation)
    local toolBonusSkill = operation.toolGUID and Buffs:GetToolBonus(operation.toolGUID)

    local maxProfitOperation, maxProfit = operation, operation:GetProfit()

    for _,toolGUID in pairs(operation:GetAvailableTools()) do repeat
        if toolGUID == operation.toolGUID then break end
        if Buffs:GetToolBonus(toolGUID) ~= toolBonusSkill then break end

        local operation = operation:WithTool(toolGUID)
        local profit = operation:GetProfit()

        if profit > maxProfit then
            maxProfit, maxProfitOperation = profit, operation
        end
    until true end

    return maxProfitOperation
end

---------------------------------------
--               Caches
---------------------------------------

Self.Cache = {
    ---@type Cache<table, fun(self: Cache, operation: Operation): string>
    WeightsAndPrices = Cache:Create(
        ---@param operation Operation
        function (_, operation)
            return Self:GetOperationCacheKey(operation, false)
        end,
        nil,
        5,
        true
    ),
    ---@type Cache<Operation[], fun(self: Cache, operation: Operation): string>
    CostAllocations = Cache:Create(
        ---@param operation Operation
        function(_, operation) return Self:GetOperationCacheKey(operation) end,
        nil,
        10,
        true
    ),
    ---@type Cache<Operation[], fun(self: Cache, operation: Operation, method: Optimization.Method): string>
    ProfitAllocations = Cache:Create(
        ---@param operation Operation
        ---@param method Optimization.Method
        function(_, operation, method)
            local applyConcentration = Util:OneOf(method, Self.Method.CostPerConcentration, Self.Method.ProfitPerConcentration)
            return ("%s;;%d;%s"):format(
                method,
                method == Self.Method.CostPerConcentration and Addon.DB.Account.concentrationCost or 0,
                Self:GetOperationCacheKey(operation, applyConcentration, true)
            )
        end,
        nil,
        10,
        true
    ),
}

---@type fun(slot: CraftingReagentSlotSchematic, allocs?: ProfessionTransationAllocations): boolean?
local cacheKeyReagentsFilter = function (slot, allocs)
    return Reagents:IsModifying(slot)
        or allocs and allocs:HasAnyAllocations() and Reagents:IsUntradableBonusSkill(allocs.allocs[1].reagent)
end

---@param operation Operation
---@param applyConcentration? boolean
---@param applyAuras? boolean
function Self:GetOperationCacheKey(operation, applyConcentration, applyAuras)
    if applyConcentration == nil then applyConcentration = operation.applyConcentration end

    return Operation:GetKey(
        operation.recipe,
        operation.allocation,
        operation.orderOrRecraftGUID,
        applyConcentration,
        operation.extraSkill,
        "",
        applyAuras and Buffs:GetCurrentAndEnabledAuras(operation.recipe) or nil,
        cacheKeyReagentsFilter
    )
end

---------------------------------------
--               Events
---------------------------------------

function Self:OnTraitChanged()
    for _,cache in pairs(self.Cache) do cache:Clear() end
end

function Self:OnLoaded()
    Buffs:RegisterCallback(Buffs.Event.TraitChanged, self.OnTraitChanged, self)
end

Addon:RegisterCallback(Addon.Event.Loaded, Self.OnLoaded, Self)