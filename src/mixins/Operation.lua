---@class Addon
local Addon = select(2, ...)
local Cache, Prices, Reagents, Recipes, Util = Addon.Cache, Addon.Prices, Addon.Reagents, Addon.Recipes, Addon.Util

---@class Operation.Static
local Static = Addon.Operation

---@type Operation
---@diagnostic disable-next-line: missing-fields
Static.Mixin = {}

---@param recipe CraftingRecipeSchematic
---@param allocation? RecipeAllocation
---@param orderOrRecraftGUID? CraftingOrderInfo | string
---@param applyConcentration? boolean
---@param extraSkill? boolean | number
---@param reagentsFilter? fun(slot: CraftingReagentSlotSchematic, allocs?: ProfessionTransationAllocations): boolean?
function Static:GetKey(recipe, allocation, orderOrRecraftGUID, applyConcentration, extraSkill, reagentsFilter)
    local order = type(orderOrRecraftGUID) == "table" and orderOrRecraftGUID or nil
    local recraftGUID = type(orderOrRecraftGUID) == "string" and orderOrRecraftGUID or nil
    local profInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipe.recipeID)
    local recraftMods = Reagents:GetRecraftMods(order, recraftGUID)

    local key = ("%d;%s;%d;%d;%d;%d;%d"):format(
        recipe.recipeID,
        recipe.isRecraft and recraftGUID or 0,
        applyConcentration and 1 or 0,
        order and order.orderID or 0,
        profInfo and profInfo.skillLevel + profInfo.skillModifier or 0,
        tonumber(extraSkill) or extraSkill and Addon.extraSkill or 0,
        Prices:GetRecipeScanTime(recipe, nil, order, recraftMods) or 0
    )

    for slotIndex,slot in pairs(recipe.reagentSlotSchematics) do repeat
        key = key .. ";"

        local missing = slot.required and slot.quantityRequired or 0
        local allocs = allocation and allocation[slotIndex]

        if reagentsFilter and not reagentsFilter(slot, allocs) then break end

        if allocs then
            for _,alloc in allocs:Enumerate() do
                missing = missing - alloc.quantity
                key = key .. (";%d;%d"):format(alloc.reagent.itemID, alloc.quantity)
            end
        end

        if missing > 0 then
            key = key .. (";%d;%d"):format(slot.reagents[1].itemID, missing)
        end
    until true end

    return key
end

-- A crafting operation
---@class Operation
---@field recipe CraftingRecipeSchematic
---@field allocation RecipeAllocation
---@field orderOrRecraftGUID? CraftingOrderInfo | string
---@field applyConcentration? boolean
local Self = Static.Mixin

-- CREATE

---@param recipe CraftingRecipeSchematic
---@param allocation? RecipeAllocation
---@param orderOrRecraftGUID? CraftingOrderInfo | string
---@param applyConcentration? boolean
---@param extraSkill? boolean | number
function Static:Create(recipe, allocation, orderOrRecraftGUID, applyConcentration, extraSkill)
    return CreateAndInitFromMixin(Static.Mixin, recipe, allocation, orderOrRecraftGUID, applyConcentration, extraSkill) --[[@as Operation]]
end

---@param tx ProfessionTransaction
---@param order? CraftingOrderInfo
---@param extraSkill? boolean | number
function Static:FromTransaction(tx, order, extraSkill)
    local recipe = tx:GetRecipeSchematic()
    local allocation = Util:TblCopy(tx.allocationTbls, true)
    local orderOrRecraftGUID = order or tx:GetRecraftAllocation()
    local applyConcentration = tx:IsApplyingConcentration()

    return self:Create(recipe, allocation, orderOrRecraftGUID, applyConcentration, extraSkill)
end

---@param allocation? RecipeAllocation
function Self:WithAllocation(allocation)
    return Static:Create(self.recipe, allocation, self.orderOrRecraftGUID, self.applyConcentration, self.extraSkill)
end

---@param reagentTypes number
---@param reagents? CraftingReagentInfo[]
---@param finishingSlotIndex? number
function Self:WithReagents(reagentTypes, reagents, finishingSlotIndex)
    local order = self:GetOrder()
    local allocation = {}

    for slotIndex,slot in ipairs(self.recipe.reagentSlotSchematics) do
        local allocate = Util:NumMaskSome(reagentTypes, slot.reagentType)
            and (not finishingSlotIndex or not Reagents:IsFinishing(slot) or slotIndex == finishingSlotIndex)
            and (not Reagents:IsProvided(slot, order, self:GetRecraftMods()))

        if allocate then
            allocation[slotIndex] = Addon:CreateAllocations()

            if reagents then
                for _,reagent in pairs(reagents) do
                    if reagent.dataSlotIndex == slot.dataSlotIndex then
                        Reagents:Allocate(allocation[slotIndex], reagent, reagent.quantity)
                    end
                end
            end
        elseif self.allocation[slot.slotIndex] then
            allocation[slotIndex] = Util:TblCopy(self.allocation[slot.slotIndex], true)
        end
    end

    return self:WithAllocation(allocation)
end

---@param reagents? CraftingReagentInfo[]
function Self:WithQualityReagents(reagents)
    return self:WithReagents(Util:NumMask(Enum.CraftingReagentType.Basic), reagents)
end

---@param reagents? CraftingReagentInfo[]
---@param slotIndex? number
function Self:WithFinishingReagents(reagents, slotIndex)
    return self:WithReagents(Util:NumMask(Enum.CraftingReagentType.Finishing), reagents, slotIndex)
end

---@param reagents? CraftingReagentInfo[]
function Self:WithWeightReagents(reagents)
    local reagentTypes = Util:NumMask(Enum.CraftingReagentType.Basic, Enum.CraftingReagentType.Finishing)
    local slot = self:GetBonusSkillReagentSlot()
    return self:WithReagents(reagentTypes, reagents, slot and slot.slotIndex or 0)
end

---@param applyConcentration? boolean
function Self:WithConcentration(applyConcentration)
    if applyConcentration == nil then applyConcentration = false end
    if applyConcentration == self.applyConcentration then return self end

    local op = Util:TblCopy(self)

    op.applyConcentration = applyConcentration
    op.resultPrice, op.profit = nil, nil

    return op
end

---@param extraSkill? boolean | number
function Self:WithExtraSkill(extraSkill)
    extraSkill = tonumber(extraSkill) or extraSkill and Addon.extraSkill or 0
    if extraSkill == self.extraSkill then return self end

    return Static:Create(self.recipe, Util:TblCopy(self.allocation, true), self.orderOrRecraftGUID, self.applyConcentration, extraSkill)
end

-- CLASS

---@param recipe CraftingRecipeSchematic
---@param allocation? RecipeAllocation
---@param orderOrRecraftGUID? CraftingOrderInfo | string
---@param applyConcentration? boolean
---@param extraSkill? boolean | number
function Self:Init(recipe, allocation, orderOrRecraftGUID, applyConcentration, extraSkill)
    self.recipe = recipe
    self.allocation = allocation or {}
    self.orderOrRecraftGUID = orderOrRecraftGUID
    self.applyConcentration = applyConcentration
    self.extraSkill = tonumber(extraSkill) or extraSkill and Addon.extraSkill or 0

    local order = self:GetOrder()

    for slotIndex,slot in pairs(recipe.reagentSlotSchematics) do repeat        
        -- Remove non-modifying reagents
        if not Reagents:IsModified(slot) then self.allocation[slotIndex] = nil break end

        -- Allocate provided or min. required reagents
        local provided = Reagents:IsProvided(slot, order, self:GetRecraftMods())
        local alloc = self.allocation[slotIndex]

        if not alloc and (provided or slot.required) then
            alloc = Addon:CreateAllocations()
            self.allocation[slotIndex] = alloc
        end

        if provided then
            Reagents:ClearAllocations(alloc)

            for _,reagent in pairs(Reagents:GetProvided(slot, order, self:GetRecraftMods())) do
                local quantity = reagent.quantity or 1
                if alloc:GetQuantityAllocated(reagent) < quantity then
                    Reagents:Allocate(alloc, reagent, quantity)
                end
            end
        elseif slot.required and not alloc:HasAllAllocations(slot.quantityRequired) then
            Reagents:Allocate(alloc, slot.reagents[1], slot.quantityRequired - alloc:Accumulate())
        end
    until true end
end

---@param reagentsFilter? fun(slot: CraftingReagentSlotSchematic, allocs?: ProfessionTransationAllocations): boolean?
function Self:GetKey(applyConcentration, reagentsFilter)
    if applyConcentration == nil then applyConcentration = self.applyConcentration end
    return Static:GetKey(self.recipe, self.allocation, self.orderOrRecraftGUID, applyConcentration, self.extraSkill, reagentsFilter)
end

function Self:GetRecipeInfo()
    if not self.recipeInfo then
        self.recipeInfo = C_TradeSkillUI.GetRecipeInfo(self.recipe.recipeID)
    end
    return self.recipeInfo
end

function Self:GetProfessionInfo()
    if not self.professionInfo then
        self.professionInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(self.recipe.recipeID)
    end
    return self.professionInfo
end

function Self:GetOrder()
    if type(self.orderOrRecraftGUID) == "table" then return self.orderOrRecraftGUID --[[@as CraftingOrderInfo]] end
end

function Self:GetRecraftGUID()
    if type(self.orderOrRecraftGUID) == "string" then return self.orderOrRecraftGUID --[[@as string]] end
end

function Self:GetOperationInfo()
    if not self.operationInfo then
        self.operationInfo = Recipes:GetOperationInfo(self.recipe, self:GetReagents(), self.orderOrRecraftGUID)

        -- Extra skill
        if self.extraSkill > 0 then
            local op = self.operationInfo

            op.baseSkill = op.baseSkill + self.extraSkill

            if op.isQualityCraft then
                local recipeInfo = self:GetRecipeInfo()
                local maxQuality = recipeInfo.maxQuality ---@cast maxQuality -?

                local skill = op.baseSkill + op.bonusSkill
                local difficulty = op.baseDifficulty + op.bonusDifficulty
                local p = skill / difficulty

                local quality = maxQuality
                local breakpoints = Addon.QUALITY_BREAKPOINTS[maxQuality]

                for i, v in ipairs(breakpoints) do
                    if v > p then quality = i - 1 break end
                end

                -- Skill, quality
                local lower, upper = breakpoints[quality], breakpoints[quality + 1] or 1
                local qualityProgress = upper == lower and 0 or (p - lower) / (upper - lower)
                local qualityID = recipeInfo.qualityIDs[quality]
                local qualityChanged = op.craftingQuality ~= quality

                op.quality = quality + qualityProgress
                op.craftingQuality = quality
                op.craftingQualityID = qualityID
                op.lowerSkillThreshold = difficulty * lower
                op.upperSkillTreshold = difficulty * upper

                -- Concentration cost
                if (op.concentrationCost or 0) > 0 then
                    if quality == #breakpoints then
                        op.concentrationCost = 0
                    else
                        local weight = self:GetWeight() + self.extraSkill * self:GetWeightPerSkill()
                        local base = self:WithExtraSkill()

                        if qualityChanged then
                            local isLowerBound = qualityProgress < 0.5
                            local weightReagents = Reagents:GetCraftingInfoForWeight(self.recipe, weight, isLowerBound)
                            base = base:WithWeightReagents(weightReagents)
                        end
                        
                        if base:GetQuality() ~= op.craftingQuality then
                            op.concentrationCost = 0/0
                        else
                            op.concentrationCost = base:GetConcentrationCost(weight)
                        end

                        if Util:NumIsNaN(op.concentrationCost) then
                            op.concentrationCost = -1
                        end
                    end
                end
            end
        end
    end
    return self.operationInfo
end

function Self:GetResult()
    if not self.result then
        self.result = Recipes:GetResult(self.recipe, self:GetOperationInfo(), self:GetOptionalReagents(), self:GetResultQuality()) --[[@as string | number]]
    end
    return self.result
end

-- Reagents

function Self:GetQualityReagentSlots()
    if not self.qualityReagentSlots then
        self.qualityReagentSlots = Reagents:GetQualitySlots(self.recipe, self:GetOrder(), self:GetRecraftMods())
    end
    return self.qualityReagentSlots
end

function Self:GetBonusSkillReagentSlot()
    return Reagents:GetBonusSkillSlot(self.recipe, self:GetRecipeInfo())
end

function Self:GetWeightReagentSlots()
    if not self.weightSlots then
        self.weightSlots = Util:TblCopy(self:GetQualityReagentSlots())

        local bonusSkillSlot = self:GetBonusSkillReagentSlot()
        if bonusSkillSlot then tinsert(self.weightSlots, bonusSkillSlot) end
    end
    return self.weightSlots
end

function Self:GetQualityReagents()
    if not self.qualityReagents then
        local predicate = Util:FnBind(Reagents.IsQuality, Reagents)
        self.qualityReagents = Reagents:CreateCraftingInfosFromAllocation(self.recipe, self.allocation, predicate)
    end
    return self.qualityReagents
end

function Self:GetOptionalReagents()
    if not self.optionalReagents then
        local predicate = Util:FnBind(Reagents.IsOptional, Reagents)
        self.optionalReagents = Reagents:CreateCraftingInfosFromAllocation(self.recipe, self.allocation, predicate)
    end
    return self.optionalReagents
end

function Self:GetReagents()
    if not self.reagents then
        self.reagents = Reagents:CreateCraftingInfosFromAllocation(self.recipe, self.allocation)
    end
    return self.reagents
end

function Self:GetRecraftMods()
    if self.recipe.isRecraft and not self.recraftMods then
        self.recraftMods = Reagents:GetRecraftMods(self:GetOrder(), self:GetRecraftGUID())
    end
    return self.recraftMods
end

function Self:HasAllocation(slotIndex)
    return self.allocation[slotIndex] and self.allocation[slotIndex]:HasAnyAllocations()
end

-- Quality

function Self:GetQuality()
    return self:GetOperationInfo().craftingQuality
end

function Self:GetResultQuality()
    local quality = self:GetQuality()
    if not self.applyConcentration then return quality end
    return min(quality + 1, self:GetRecipeInfo().maxQuality)
end

function Self:GetQualityBreakpoints()
    return Addon.QUALITY_BREAKPOINTS[self:GetRecipeInfo().maxQuality]
end

---@return boolean canIncrease
---@return boolean canDecrease
function Self:CanChangeQuality()
    local recipeInfo = self:GetRecipeInfo()
    if not recipeInfo.supportsQualities or recipeInfo.maxQuality == 0 then return false, false end

    local breakpoints = self:GetQualityBreakpoints()
    local quality = self:GetQuality()
    local qualityReagents = self:GetQualityReagentSlots()
    local difficulty = self:GetDifficulty()
    local skillBase, skillRange = self:GetSkillBounds(true)
    local skillCheapest = Reagents:GetCheapestWeight(qualityReagents) / self:GetWeightPerSkill()

    local canDecrease = (breakpoints[quality] or 0) * difficulty > skillBase + skillCheapest
    local canIncrease = (breakpoints[quality+1] or math.huge) * difficulty <= skillBase + skillRange

    return canDecrease or false, canIncrease or false
end

-- Difficulty, Skill, Weight, Concentration

function Self:GetDifficulty()
    local operationInfo = self:GetOperationInfo()
    return operationInfo.baseDifficulty + operationInfo.bonusDifficulty
end

---@param includeBonusSkillReagents? boolean
---@return number skillBase
---@return number skillRange
function Self:GetSkillBounds(includeBonusSkillReagents)
    if not self.skillBase or not self.skillRange then
        local cache = Static.Cache.SkillBounds
        local key = cache:Key(self)

        if not cache:Has(key) then
            local skillBase, skillRange = Reagents:GetSkillBounds(self.recipe, self:GetQualityReagentSlots(), self:GetOptionalReagents(), self.orderOrRecraftGUID)
            cache:Set(key, { skillBase, skillRange })
        end

        self.skillBase, self.skillRange = unpack(cache:Get(key))

        self.skillBase = self.skillBase + self.extraSkill
    end

    if includeBonusSkillReagents and self:GetBonusSkillReagentSlot() then
        return self.skillBase, self.skillRange + Reagents:GetMaxBonusSkill()
    else
        return self.skillBase, self.skillRange
    end
end

---@param includeBonusSkillReagents? boolean
function Self:GetWeight(includeBonusSkillReagents)
    if not self.weight then
        self.weight = Reagents:GetAllocationWeight(self:GetQualityReagentSlots(), self.allocation)
    end

    if includeBonusSkillReagents then
        local slot = self:GetBonusSkillReagentSlot()
        local alloc = slot and self.allocation[slot.slotIndex]
        if alloc and alloc:HasAnyAllocations() then
            return self.weight + Reagents:GetWeight(alloc.allocs[1].reagent, self:GetWeightPerSkill())
        end
    end

    return self.weight
end

---@param includeBonusSkillReagents? boolean
function Self:GetMaxWeight(includeBonusSkillReagents)
    if not self.maxWeight then
        self.maxWeight = Reagents:GetMaxWeight(self:GetQualityReagentSlots())
    end

    if includeBonusSkillReagents then
        local slot = self:GetBonusSkillReagentSlot()
        local alloc = slot and self.allocation[slot.slotIndex]
        if slot and not (alloc and alloc:HasAnyAllocations() and Reagents:IsUntradableBonusSkill(alloc.allocs[1].reagent)) then
            return self.maxWeight + Reagents:GetMaxBonusSkill() * self:GetWeightPerSkill()
        end
    end

    return self.maxWeight
end

function Self:GetWeightPerSkill()
    return self:GetMaxWeight() / select(2, self:GetSkillBounds()) --[[@as number]]
end

---@param absolute? boolean
function Self:GetSkillThresholds(absolute)
    local operationInfo = self:GetOperationInfo()
    local lower, upper = operationInfo.lowerSkillThreshold, operationInfo.upperSkillTreshold

    if absolute then return lower, upper end

    local baseSkill = self:GetSkillBounds()
    return max(0, lower - baseSkill), max(0, upper - baseSkill)
end

function Self:GetWeightThresholds()
    local lowerSkill, upperSkill = self:GetSkillThresholds()
    local weightPerSkill = self:GetWeightPerSkill()
    local maxWeight = self:GetMaxWeight(true)

    local lower = min(maxWeight, ceil(lowerSkill * weightPerSkill))
    local upper = min(maxWeight, floor(upperSkill * weightPerSkill))

    return lower, upper
end

function Self:GetConcentrationFactors()
    if not self.concentrationFactors then
        local cache = Static.Cache.ConcentrationFactors
        local key = cache:Key(self)

        if not cache:Has(key) then
            ---@type number[]
            local concentrationFactors = {}

            local n = #Addon.CONCENTRATION_BREAKPOINTS
            local baseSkill = self:GetSkillBounds()
            local lowerSkill, upperSkill = self:GetSkillThresholds(true)
            local weightPerSkill = self:GetWeightPerSkill()
            local prevWeight, prevCon

            for i,v in ipairs(Addon.CONCENTRATION_BREAKPOINTS) do
                local skill = lowerSkill + v * (upperSkill - lowerSkill) - baseSkill
                local weight = max(0, skill * weightPerSkill)

                local opWeight, opCon = prevWeight, prevCon

                if weight ~= prevWeight then
                    local reagents = Reagents:GetCraftingInfoForWeight(self.recipe, weight, i < n)
                    local op = self:WithQualityReagents(reagents)
                    local info = op:GetOperationInfo()

                    opWeight, opCon = op:GetWeight(), info.concentrationCost
                end

                if i > 1 and opWeight >= prevWeight then
                    concentrationFactors[i-1] = (prevCon - opCon) / (prevWeight - opWeight)
                end

                prevWeight, prevCon = opWeight, opCon
            end

            cache:Set(key, concentrationFactors)
        end

        self.concentrationFactors = cache:Get(key)
    end

    return self.concentrationFactors
end

function Self:GetConcentrationCost(weight)
    if self:GetQuality() == self:GetRecipeInfo().maxQuality then return 0 end

    local concentration = self:GetOperationInfo().concentrationCost

    if not weight or weight == self:GetWeight(true) then
        return concentration
    end

    local conFactors = self:GetConcentrationFactors()
    local baseSkill = self:GetSkillBounds()
    local lowerSkill, upperSkill = self:GetSkillThresholds(true)
    local weightPerSkill = self:GetWeightPerSkill()
    local currCon = concentration
    local currWeight = self:GetWeight(true)

    local n = #Addon.CONCENTRATION_BREAKPOINTS
    local d = currWeight <= weight and 1 or -1
    local bound = d == 1 and min or max

    for i=1,n-1 do
       local v = Addon.CONCENTRATION_BREAKPOINTS[d == 1 and i+1 or n-i]
       local f = conFactors[d == 1 and i or n-i]
       local targetSkill = lowerSkill + v * (upperSkill - lowerSkill) - baseSkill
       local targetWeight = max(0, bound(weight, targetSkill * weightPerSkill))

       if targetWeight * d > currWeight * d and targetWeight * d <= weight * d then
          currCon = currCon + (targetWeight - currWeight) * f
          currWeight = targetWeight
       end
    end

    return currCon
end

-- Stats

---@param stat BonusStat
---@return number
function Self:GetStatBonus(stat)
    if not self[stat] then
        self[stat] = Recipes:GetStatBonus(self.recipe, stat, self:GetOptionalReagents())
    end
    return self[stat]
end

function Self:GetResourcefulnessFactor()
    if not self.resourcefulnessFactor then
        self.resourcefulnessFactor = Recipes:GetResourcefulnessFactor(self.recipe, self:GetOperationInfo(), self:GetOptionalReagents())
    end
    return self.resourcefulnessFactor
end

function Self:GetMulticraftFactor()
    if not self.multicraftFactor then
        self.multicraftFactor = Recipes:GetMulticraftFactor(self.recipe, self:GetOperationInfo(), self:GetOptionalReagents())
    end
    return self.multicraftFactor
end

-- Prices

function Self:GetReagentPrice()
    if not self.reagentPrice then
        self.reagentPrice = Prices:GetRecipeAllocationPrice(self.recipe, self.allocation, self:GetOrder(), self:GetRecraftMods())
    end
    return self.reagentPrice
end

function Self:GetResultPrice()
    if not self.resultPrice then
        self.resultPrice = Prices:GetRecipeResultPrice(self.recipe, self:GetOperationInfo(), self:GetOptionalReagents(), self:GetResultQuality())
    end
    return self.resultPrice
end

---@return number profit
---@return number revenue
---@return number resourcefulness
---@return number multicraft
---@return number rewards
---@return number traderCut
function Self:GetProfit()
    if not self.profit then
        local reagentPrice = self:GetReagentPrice() ---@cast reagentPrice -?
        local resultPrice = self:GetResultPrice()
        local operationInfo = self:GetOperationInfo()
        local order = self:GetOrder()
        local optionalReagents = self:GetOptionalReagents()

        self.profit, self.revenue, self.resourcefulness, self.multicraft, self.rewards, self.traderCut = Prices:GetRecipeProfit(self.recipe, operationInfo, self.allocation, reagentPrice, resultPrice, order, optionalReagents)
    end
    return self.profit, self.revenue, self.resourcefulness, self.multicraft, self.rewards, self.traderCut
end

function Self:GetProfitPerConcentration()
    local op = self:GetOperationInfo()

    if (op.concentrationCost or 0) == 0 then return math.huge, 0 end

    local bonusStat = Util:TblWhere(op.bonusStats, "bonusStatName", ITEM_MOD_INGENUITY_SHORT)
    local p = bonusStat and bonusStat.ratingPct / 100 or 0
    local concentration = op.concentrationCost - p * op.ingenuityRefund

    local profit = self:GetProfit()
    local profitPerConcentration = profit / concentration
    local ingenuityValue = profitPerConcentration - profit / op.concentrationCost

    return profitPerConcentration, ingenuityValue
end

function Self:HasProfit()
    return self:GetOrder() ~= nil or not self.orderOrRecraftGUID and self:GetResultPrice() > 0
end

-- CACHE

Static.Cache = {
    ---@type Cache<number[], fun(self: Cache, operation: Operation): string>
    SkillBounds = Cache:Create(
        ---@param operation Operation
        function (_, operation)
            local order = operation:GetOrder()
            local operationInfo = operation:GetOperationInfo()
            local _, reagent = Util:TblFind(operation:GetOptionalReagents(), Reagents.IsUntradableBonusSkill, false, Reagents)

            return ("%d;%d;%d;%d;%d"):format(
                operation.recipe.recipeID,
                operation:GetQuality(),
                order and order.orderID or 0,
                operationInfo.baseSkill,
                reagent and reagent.itemID or 0
            )
        end,
        10,
        true
    ),
    ---@type Cache<number[], fun(self: Cache, operation: Operation): string>
    ConcentrationFactors = Cache:Create(
        ---@param operation Operation
        function (_, operation)
            local profInfo = operation:GetProfessionInfo()

            return ("%d;%d;%d;%d"):format(
                operation.recipe.recipeID,
                operation:GetQuality(),
                operation:GetStatBonus("cc") * 100,
                profInfo and profInfo.skillLevel + profInfo.skillModifier or 0
            )
        end,
        10,
        true
    )
}