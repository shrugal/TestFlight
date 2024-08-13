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
function Self:GetRecipeBasePrice(recipe)
    local price = 0
    for _,reagent in pairs(recipe.reagentSlotSchematics) do
        if reagent.reagentType == Enum.CraftingReagentType.Basic and not self:IsQualityReagent(reagent) then
            price = price + reagent.quantityRequired * self:GetReagentPrice(reagent)
        end
    end

    return price
end

---@param recipe CraftingRecipeSchematic
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetRecipeAllocations(recipe, optionalReagents)
    local qualityReagents = self:GetQualityReagents(recipe)
    local form = self:GetCraftingForm()
    local recipeInfo = form.currentRecipeInfo
    local operationInfo = form:GetRecipeOperationInfo()
    local skillBase, skillBest = self:GetReagentSkillBounds(recipe, qualityReagents, optionalReagents)

    -- Check allocations cache
    local key = Self.Cache.Allocations:Key(recipe, skillBase, optionalReagents)
    if Self.Cache.Allocations:Has(key) then
        return Self.Cache.Allocations:Get(key)
    end

    local weights, prices = self:GetRecipeWeightsAndPrices(recipe, qualityReagents)
    local maxWeight = self:GetMaxReagentWeight(recipe, qualityReagents)
    local breakpoints = Addon.QUALITY_BREAKPOINTS[recipeInfo.maxQuality]
    local difficulty = operationInfo.baseDifficulty + operationInfo.bonusDifficulty

    local allocations = {}

    for i=#breakpoints, 1, -1 do
        local breakpointFactor = math.max(0, (breakpoints[i] * difficulty - skillBase) / skillBest)
        local prevPrice = math.huge

        if breakpointFactor <= 1 then
            local w = math.ceil(breakpointFactor * maxWeight)
            local price = prices[w]

            if prevPrice <= price then break end

            ---@type RecipeAllocation
            local allocation = {}

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

    Self.Cache.Allocations:Set(key, allocations)

    return allocations
end

---@param recipe CraftingRecipeSchematic
---@param qualityReagents? CraftingReagentSlotSchematic[]
---@return table<number, table<number, number>>
---@return table<number, number>
function Self:GetRecipeWeightsAndPrices(recipe, qualityReagents)
    -- Check weights cache
    local key = Self.Cache.WeightsAndPrices:Key(recipe)
    if Self.Cache.WeightsAndPrices:Has(key) then
        return unpack(Self.Cache.WeightsAndPrices:Get(key))
    end

    if not qualityReagents then qualityReagents = self:GetQualityReagents(recipe) end

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

    Self.Cache.WeightsAndPrices:Set(key, { weights, prices[1] })

    return weights, prices[1]
end

---@param recipe CraftingRecipeSchematic
---@param allocation RecipeAllocation
---@param addMissingRequired? boolean
---@param addBase? boolean
---@param addOptional? RecipeAllocation
function Self:GetRecipeAllocationPrice(recipe, allocation, addMissingRequired, addBase, addOptional)
    local price = 0

    for _,reagent in pairs(allocation) do
        for _,item in reagent:Enumerate() do
            price = price + item.quantity * self:GetReagentPrice(item)
        end
    end

    if addMissingRequired then
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
    end

    if addBase then price = price + self:GetRecipeBasePrice(recipe) end

    if addOptional then
        for _,reagent in pairs(recipe.reagentSlotSchematics) do
            if not reagent.required and not allocation[reagent.slotIndex] then
                local optionalAllocation = addOptional[reagent.slotIndex]

                if optionalAllocation then
                    local first = optionalAllocation:SelectFirst()

                    if first then
                        price = price + first.quantity * self:GetReagentPrice(first)
                    end
                end
            end
        end
    end

    return price
end

---@param recipe CraftingRecipeSchematic
---@param optionalReagents? CraftingReagentInfo[]
function Self:CanChangeCraftQuality(recipe, optionalReagents)
    local form = self:GetCraftingForm()
    local recipeInfo = form.currentRecipeInfo
    local operationInfo = form:GetRecipeOperationInfo()

    if recipeInfo.maxQuality == 0 then return false, false end

    local breakpoints = Addon.QUALITY_BREAKPOINTS[recipeInfo.maxQuality]
    local difficulty = operationInfo.baseDifficulty + operationInfo.bonusDifficulty
    local quality = math.floor(operationInfo.quality)
    local skillBase, skillBest, skillCheapest = self:GetReagentSkillBounds(recipe, nil, optionalReagents)

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
function Self:IsQualityReagent(reagent)
    return Professions.GetReagentInputMode(reagent) == Professions.ReagentInputMode.Quality
end

---@param recipe CraftingRecipeSchematic
---@return CraftingReagentSlotSchematic[]
function Self:GetQualityReagents(recipe)
    return Util:TblFilter(recipe.reagentSlotSchematics, Self.IsQualityReagent, false, self)
end

---@param recipe CraftingRecipeSchematic
---@param reagents? CraftingReagentSlotSchematic[]
---@return number
function Self:GetMaxReagentWeight(recipe, reagents)
    if not reagents then reagents = self:GetQualityReagents(recipe) end

    local maxWeight = 0
    for _,reagent in pairs(reagents) do
        maxWeight = maxWeight + 2 * reagent.quantityRequired * self:GetReagentWeight(reagent)
    end

    return maxWeight
end

---@param recipe CraftingRecipeSchematic
---@param reagents? CraftingReagentSlotSchematic[]
---@return number
function Self:GetCheapestReagentWeight(recipe, reagents)
    if not reagents then reagents = self:GetQualityReagents(recipe) end

    local cheapestWeight = 0
    for _,reagent in pairs(reagents) do
        local _, q2, q3 = self:GetReagentQuantitiesForWeight(reagent, 0)
        cheapestWeight = cheapestWeight + (q2 + 2 * q3) * self:GetReagentWeight(reagent)
    end

    return cheapestWeight
end

---@param recipe CraftingRecipeSchematic
---@param qualityReagents? CraftingReagentSlotSchematic[]
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetReagentSkillBounds(recipe, qualityReagents, optionalReagents)
    if not qualityReagents then qualityReagents = self:GetQualityReagents(recipe) end

    local itemGUID = self:GetCraftingFormItemGUID()

    -- Create allocation
    local allocation = Util:TblMap(qualityReagents, Self.CreateReagentInfo, false, self)
    if optionalReagents then
        for _,reagent in pairs(optionalReagents) do tinsert(allocation, reagent) end
    end

    -- Get required skill with base materials
    local opBase = C_TradeSkillUI.GetCraftingOperationInfo(recipe.recipeID, allocation, itemGUID, false)
    if not opBase then return 0 end

    -- Get required skill with best materials
    for i=1,#qualityReagents do allocation[i].itemID = qualityReagents[i].reagents[3].itemID end
    local opBest = C_TradeSkillUI.GetCraftingOperationInfo(recipe.recipeID, allocation, itemGUID, false)
    if not opBest then return 0 end

    if Addon.enabled then
        opBase.baseSkill = opBase.baseSkill + Addon.extraSkill
        opBest.baseSkill = opBest.baseSkill + Addon.extraSkill
    end

    local skillBase = opBase.baseSkill + opBase.bonusSkill
    local skillBest = opBest.baseSkill + opBest.bonusSkill - skillBase
    local skillCheapest = skillBest * self:GetCheapestReagentWeight(recipe, qualityReagents) / self:GetMaxReagentWeight(recipe, qualityReagents)

    return skillBase, skillBest, skillCheapest
end

---------------------------------------
--               Caches
---------------------------------------

Self.Cache = {
    ---@type Cache<table, fun(self: Cache, recipe: CraftingRecipeSchematic): string>
    WeightsAndPrices = Addon:CreateCache(
        ---@param recipe CraftingRecipeSchematic
        function (_, recipe) return Self:GetRecipeCacheKey(recipe) end,
        1
    ),
    ---@type Cache<RecipeAllocation[], fun(self: Cache, recipe: CraftingRecipeSchematic, baseSkill: number, optionalReagents?: CraftingReagentInfo[]): string>
    Allocations = Addon:CreateCache(
        ---@param recipe CraftingRecipeSchematic
        ---@param baseSkill? number
        ---@param optionalReagents? CraftingReagentInfo[]
        function(_, recipe, baseSkill, optionalReagents) return Self:GetRecipeCacheKey(recipe, baseSkill, optionalReagents) end,
        10
    )
}

---@param recipe CraftingRecipeSchematic
---@param baseSkill? number
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetRecipeCacheKey(recipe, baseSkill, optionalReagents)
    local key = ("%d|%d|%d"):format(
        recipe.recipeID,
        recipe.isRecraft and 1 or 0,
        baseSkill or 0
    )

    for _,reagent in pairs(recipe.reagentSlotSchematics) do
        if self:IsQualityReagent(reagent) then
            key = key .. ("||%d|%d|%d"):format(self:GetReagentPrices(reagent))
        end
    end

    if optionalReagents then
        for _,reagent in pairs(optionalReagents) do
            key = key .. ("||%d|%d"):format(reagent.itemID, reagent.quantity)
        end
    end

    return key
end

-- Util

function Self:GetCraftingForm()
    return ProfessionsFrame.CraftingPage.SchematicForm
end

---@return string
function Self:GetCraftingFormItemGUID()
    return self:GetCraftingForm():GetTransaction():GetRecraftAllocation()
end