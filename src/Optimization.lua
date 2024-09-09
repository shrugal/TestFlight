---@class TestFlight
local Addon = select(2, ...)
local Util = Addon.Util

---@class Optimization
local Self = Addon.Optimization or {}
Addon.Optimization = Self

function Self:IsItemPriceSourceInstalled()
    return C_AddOns.IsAddOnLoaded("TradeSkillMaster")
end

function Self:IsItemPriceSourceAvailable()
    return TSM_API ~= nil
end

---@param itemID number
function Self:GetItemPrice(itemID)
    if not Self:IsItemPriceSourceAvailable() then return 0 end

    return TSM_API.GetCustomPriceValue("first(VendorBuy, DBRecent, DBMinbuyout)", "i:" .. itemID) or 0
end

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
    local qualityReagents = self:GetQualityReagents(recipe, order)
    local skillBase, skillBest = self:GetReagentSkillBounds(recipe, optionalReagents, qualityReagents, recraftItemGUID, order)

    if not skillBase then return end

    -- Check allocations cache
    local cache = Self.Cache.Allocations
    local key = cache:Key(recipe, skillBase, qualityReagents, optionalReagents)

    if cache:Has(key) then return cache:Get(key) end

    local weights, prices = self:GetRecipeWeightsAndPrices(recipe, qualityReagents)
    local maxWeight = self:GetMaxReagentWeight(qualityReagents)

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

            local allocation = self:CreateReagentAllocation(order)

            for j=#qualityReagents, 1, -1 do
                local reagent = qualityReagents[j]
                local weight = weights[j][w]

                allocation[reagent.slotIndex] = self:CreateReagentAllocationsForWeight(reagent, weight)

                w = math.max(0, w - weight * self:GetReagentWeight(reagent))
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
---@return table<number, table<number, number>>
---@return table<number, number>
function Self:GetRecipeWeightsAndPrices(recipe, qualityReagents)
    -- Check weights cache
    local cache = Self.Cache.WeightsAndPrices
    local key = cache:Key(recipe, qualityReagents)

    if cache:Has(key) then return unpack(cache:Get(key)) end

    -- Intialize knapsack matrices
    ---@type table<number, table<number, number>>, table<number, table<number, number>>
    local prices, weights = { [0] = {}, { [0] = 0 } }, {}
    for i=1, #qualityReagents do weights[i] = {} end

    -- Compute lowest prices and corresponding reagent allocations
    for i,reagent in ipairs(qualityReagents) do
        prices[0], prices[1] = prices[1], wipe(prices[0])

        local itemWeight = self:GetReagentWeight(reagent)
        local p1, p2, p3 = self:GetReagentPrices(reagent)
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
---@param allocation RecipeAllocation | ItemMixin
---@param order? CraftingOrderInfo
---@param addOptional? RecipeAllocation
---@return number
function Self:GetRecipeAllocationPrice(recipe, allocation, order, addOptional)
    if recipe.recipeType == Enum.TradeskillRecipeType.Salvage then ---@cast allocation ItemMixin
        return recipe.quantityMin * self:GetReagentPrice(allocation:GetItemID())
    end  ---@cast allocation RecipeAllocation

    local price = 0

    if not order or order.reagentState ~= Enum.CraftingOrderReagentsType.All then
        for slotIndex,reagent in pairs(allocation) do
            for _,item in reagent:Enumerate() do
                local quantity = item.quantity

                local orderReagent = order and Util:TblWhere(order.reagents, "slotIndex", slotIndex, "reagent.itemID", item.reagent.itemID)
                if orderReagent then
                    quantity = quantity - orderReagent.reagent.quantity
                end

                price = price + quantity * self:GetReagentPrice(item)
            end
        end
    end

    for _,reagent in pairs(recipe.reagentSlotSchematics) do
        if reagent.required then
            local missing = reagent.quantityRequired
            local reagentAllocation = allocation[reagent.slotIndex]
            if reagentAllocation then missing = missing - reagentAllocation:Accumulate() end

            if missing > 0 then
                price = price + missing * math.min(self:GetReagentPrices(reagent))
            end
        end
    end

    if addOptional then
        for slotIndex,reagent in pairs(recipe.reagentSlotSchematics) do
            if not reagent.required and not allocation[reagent.slotIndex] then
                local optionalAllocation = addOptional[reagent.slotIndex]

                if optionalAllocation then
                    local item = optionalAllocation:SelectFirst()

                    if item then
                        local quantity = item.quantity

                        local orderReagent = order and Util:TblWhere(order.reagents, "slotIndex", slotIndex, "reagent.itemID", item.reagent.itemID)
                        if orderReagent then
                            quantity = quantity - orderReagent.reagent.quantity
                        end

                        price = price + quantity * self:GetReagentPrice(item)
                    end
                end
            end
        end
    end

    return price
end

---@param recipe CraftingRecipeSchematic
---@param recipeInfo TradeSkillRecipeInfo
---@param operationInfo CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
---@param order? CraftingOrderInfo
function Self:CanChangeCraftQuality(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)
    if recipeInfo.maxQuality == 0 then return false, false end

    local breakpoints = Addon.QUALITY_BREAKPOINTS[recipeInfo.maxQuality]
    local difficulty = operationInfo.baseDifficulty + operationInfo.bonusDifficulty
    local quality = math.floor(operationInfo.quality)
    local skillBase, skillBest, skillCheapest = self:GetReagentSkillBounds(recipe, optionalReagents, nil, recraftItemGUID, order)

    local canDecrease = (breakpoints[quality] or 0) * difficulty > skillBase + skillCheapest
    local canIncrease = (breakpoints[quality+1] or math.huge) * difficulty <= skillBase + skillBest

    return canDecrease or false, canIncrease or false
end

---------------------------------------
--             Reagents
---------------------------------------

---@param reagent number | CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic
function Self:GetReagentWeight(reagent)
    if type(reagent) == "table" then
        if reagent.reagents then reagent = reagent.reagents[1] end ---@cast reagent -CraftingReagentSlotSchematic
        do reagent = reagent.itemID end
    end ---@cast reagent -CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic

    return Addon.REAGENTS[reagent] or 0
end

---@param reagent number | CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic | ProfessionTransactionAllocation
function Self:GetReagentPrice(reagent)
    if not self:IsItemPriceSourceAvailable() then return 0 end

    if type(reagent) == "table" then
        if reagent.reagents then reagent = reagent.reagents[1] end ---@cast reagent -CraftingReagentSlotSchematic
        if reagent.reagent then reagent = reagent.reagent end ---@cast reagent -ProfessionTransactionAllocation
        do reagent = reagent.itemID end
    end ---@cast reagent -CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic | ProfessionTransactionAllocation

    if not reagent then return 0 end

    return self:GetItemPrice(reagent)
end

---@param reagent CraftingReagentSlotSchematic
---@return number, number?, number?
function Self:GetReagentPrices(reagent)
    if #reagent.reagents == 1 then return self:GetReagentPrice(reagent) end

    local r1, r2, r3 = unpack(reagent.reagents)
    return self:GetReagentPrice(r1), self:GetReagentPrice(r2), self:GetReagentPrice(r3)
end

---@param reagent CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic | ProfessionTransactionAllocation
function Self:GetReagentQuantity(reagent)
    if reagent.reagents then reagent = reagent.reagents[1] end ---@cast reagent -CraftingReagentSlotSchematic
    if reagent.reagent then reagent = reagent.reagent end ---@cast reagent -ProfessionTransactionAllocation
    return ProfessionsUtil.GetReagentQuantityInPossession(reagent)
end

---@param reagent CraftingReagentSlotSchematic
---@return number, number?, number?
function Self:GetReagentQuantities(reagent)
    if #reagent.reagents == 1 then return self:GetReagentQuantity(reagent) end

    local r1, r2, r3 = unpack(reagent.reagents)
    return self:GetReagentQuantity(r1), self:GetReagentQuantity(r2), self:GetReagentQuantity(r3)
end

---@param reagent CraftingReagentSlotSchematic
---@param quality? 1|2|3
---@param quantity? number
---@return CraftingReagentInfo
function Self:CreateReagentInfo(reagent, quality, quantity)
    return Professions.CreateCraftingReagentInfo(
        reagent.reagents[quality or 1].itemID,
        reagent.dataSlotIndex,
        quantity or reagent.quantityRequired
    )
end

---@param reagent CraftingReagentSlotSchematic
---@param weight number
---@param p1? number
---@param p2? number
---@param p3? number
function Self:GetReagentQuantitiesForWeight(reagent, weight, p1, p2, p3)
    if not p1 then p1, p2, p3 = self:GetReagentPrices(reagent) end

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

---@param order? CraftingOrderInfo
---@return RecipeAllocation
function Self:CreateReagentAllocation(order)
    local allocation = {}

    if order then
        for _,reagent in pairs(order.reagents) do
            if not allocation[reagent.slotIndex] then allocation[reagent.slotIndex] = Addon:CreateAllocations() end
            allocation[reagent.slotIndex]:Allocate(Professions.CreateCraftingReagentByItemID(reagent.reagent.itemID), reagent.reagent.quantity)
        end
    end

    return allocation
end

---@param reagent CraftingReagentSlotSchematic
---@param weight number
---@return ProfessionTransationAllocations
function Self:CreateReagentAllocationsForWeight(reagent, weight)
    local q1, q2, q3 = self:GetReagentQuantitiesForWeight(reagent, weight)
    local reagentAllocations = Addon:CreateAllocations()

    reagentAllocations:Allocate(Professions.CreateCraftingReagentByItemID(reagent.reagents[1].itemID), q1)
    reagentAllocations:Allocate(Professions.CreateCraftingReagentByItemID(reagent.reagents[2].itemID), q2)
    reagentAllocations:Allocate(Professions.CreateCraftingReagentByItemID(reagent.reagents[3].itemID), q3)

    return reagentAllocations
end

---@param reagent CraftingReagentSlotSchematic
function Self:IsModifyingReagent(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Modifying
end

---@param reagent CraftingReagentSlotSchematic
function Self:IsQualityReagent(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Basic and #reagent.reagents == 3
end

---@param recipe CraftingRecipeSchematic
---@param order CraftingOrderInfo?
---@return CraftingReagentSlotSchematic[]
function Self:GetQualityReagents(recipe, order)
    return Util:TblFilter(recipe.reagentSlotSchematics, function (reagent, slotIndex)
        return self:IsQualityReagent(reagent) and not (order and Util:TblWhere(order.reagents, "slotIndex", slotIndex))
    end, true)
end

---@param order CraftingOrderInfo
function Self:GetOrderReagentWeight(order)
    local orderWeight = 0
    for _,reagent in pairs(order.reagents) do
        orderWeight = orderWeight + reagent.reagent.quantity * self:GetReagentWeight(reagent.reagent)
    end
    return orderWeight
end

---@param qualityReagents CraftingReagentSlotSchematic[]
---@return number
function Self:GetMaxReagentWeight(qualityReagents)
    local maxWeight = 0
    for _,reagent in pairs(qualityReagents) do
        maxWeight = maxWeight + 2 * reagent.quantityRequired * self:GetReagentWeight(reagent)
    end
    return maxWeight
end

---@param qualityReagents CraftingReagentSlotSchematic[]
---@return number
function Self:GetCheapestReagentWeight(qualityReagents)
    local cheapestWeight = 0
    for _,reagent in pairs(qualityReagents) do
        local _, q2, q3 = self:GetReagentQuantitiesForWeight(reagent, 0)
        cheapestWeight = cheapestWeight + (q2 + 2 * q3) * self:GetReagentWeight(reagent)
    end
    return cheapestWeight
end

---@param recipe CraftingRecipeSchematic
---@param optionalReagents? CraftingReagentInfo[]
---@param qualityReagents? CraftingReagentSlotSchematic[]
---@param recraftItemGUID? string
---@param order? CraftingOrderInfo
function Self:GetReagentSkillBounds(recipe, optionalReagents, qualityReagents, recraftItemGUID, order)
    if not qualityReagents then qualityReagents = self:GetQualityReagents(recipe, order) end

    -- Create allocation
    local allocation = Util:TblMap(qualityReagents, Self.CreateReagentInfo, false, self)

    if optionalReagents then
        for _,reagent in pairs(optionalReagents) do tinsert(allocation, reagent) end
    end

    -- Get required skill with base and best materials
    ---@type CraftingOperationInfo?, CraftingOperationInfo?
    local opBase, opBest
    if not order then
        opBase = C_TradeSkillUI.GetCraftingOperationInfo(recipe.recipeID, allocation, recraftItemGUID, false)
        for i=1,#qualityReagents do allocation[i].itemID = qualityReagents[i].reagents[3].itemID end
        opBest = C_TradeSkillUI.GetCraftingOperationInfo(recipe.recipeID, allocation, recraftItemGUID, false)
    else
        -- Add order materials
        for _,reagent in pairs(order.reagents) do
            local schematic = Util:TblWhere(recipe.reagentSlotSchematics, "slotIndex", reagent.slotIndex)
            if schematic and (Self:IsQualityReagent(schematic) or Self:IsModifyingReagent(schematic)) then
                tinsert(allocation, reagent.reagent)
            end
        end

        opBase = C_TradeSkillUI.GetCraftingOperationInfoForOrder(recipe.recipeID, allocation, order.orderID, false)
        for i=1,#qualityReagents do allocation[i].itemID = qualityReagents[i].reagents[3].itemID end
        opBest = C_TradeSkillUI.GetCraftingOperationInfoForOrder(recipe.recipeID, allocation, order.orderID, false)
    end

    if not opBase or not opBest then return end

    if Addon.enabled then
        opBase.baseSkill = opBase.baseSkill + Addon.extraSkill
        opBest.baseSkill = opBest.baseSkill + Addon.extraSkill
    end

    local skillBase = opBase.baseSkill + opBase.bonusSkill
    local skillBest = opBest.baseSkill + opBest.bonusSkill - skillBase
    local skillCheapest = skillBest * self:GetCheapestReagentWeight(qualityReagents) / self:GetMaxReagentWeight(qualityReagents)

    return skillBase, skillBest, skillCheapest
end

---------------------------------------
--               Caches
---------------------------------------

Self.Cache = {
    ---@type Cache<table, fun(self: Cache, recipe: CraftingRecipeSchematic, qualityReagents: CraftingReagentSlotSchematic[]): string>
    WeightsAndPrices = Addon:CreateCache(
        ---@param recipe CraftingRecipeSchematic
        ---@param qualityReagents CraftingReagentSlotSchematic[]
        function (_, recipe, qualityReagents) return Self:GetRecipeCacheKey(recipe, nil, qualityReagents) end,
        1
    ),
    ---@type Cache<RecipeAllocation[], fun(self: Cache, recipe: CraftingRecipeSchematic, baseSkill: number, qualityReagents: CraftingReagentSlotSchematic[], optionalReagents?: CraftingReagentInfo[]): string>
    Allocations = Addon:CreateCache(
        ---@param recipe CraftingRecipeSchematic
        ---@param baseSkill? number
        ---@param qualityReagents CraftingReagentSlotSchematic[]
        ---@param optionalReagents? CraftingReagentInfo[]
        function(_, recipe, baseSkill, qualityReagents, optionalReagents) return Self:GetRecipeCacheKey(recipe, baseSkill, qualityReagents, optionalReagents) end,
        10
    )
}

---@param recipe CraftingRecipeSchematic
---@param baseSkill? number
---@param qualityReagents CraftingReagentSlotSchematic[]
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetRecipeCacheKey(recipe, baseSkill, qualityReagents, optionalReagents)
    local key = ("%d|%d|%d"):format(
        recipe.recipeID,
        recipe.isRecraft and 1 or 0,
        baseSkill or 0
    )

    for _,reagent in ipairs(qualityReagents) do
        key = key .. ("||%d|%d|%d"):format(self:GetReagentPrices(reagent))
    end

    if optionalReagents then
        for _,reagent in pairs(optionalReagents) do
            key = key .. ("||%d|%d"):format(reagent.itemID, reagent.quantity)
        end
    end

    return key
end
