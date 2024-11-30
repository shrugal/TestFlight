---@class Addon
local Addon = select(2, ...)
local Cache, Prices, Reagents, Recipes, Util = Addon.Cache, Addon.Prices, Addon.Reagents, Addon.Recipes, Addon.Util

---@class Operation.Static
local Static = Addon.Operation

---@type Operation
---@diagnostic disable-next-line: missing-fields
Static.Mixin = {}

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
function Static:Create(recipe, allocation, orderOrRecraftGUID, applyConcentration)
    return CreateAndInitFromMixin(Static.Mixin, recipe, allocation, orderOrRecraftGUID, applyConcentration) --[[@as Operation]]
end

---@param tx ProfessionTransaction
---@param order? CraftingOrderInfo
function Static:FromTransaction(tx, order)
    return self:Create(tx:GetRecipeSchematic(), Util:TblCopy(tx.allocationTbls, true), order or tx:GetRecraftAllocation(), tx:IsApplyingConcentration())
end

---@param form RecipeCraftingForm
---@param order? CraftingOrderInfo
function Static:FromCraftingForm(form, order)
    local op = self:FromTransaction(form.transaction, order)

    if not form.transaction:IsApplyingConcentration() then
        op.operationInfo = form:GetRecipeOperationInfo()
    end

    return op
end

---@param allocation? RecipeAllocation
function Self:WithAllocation(allocation)
    return Static:Create(self.recipe, allocation, self.orderOrRecraftGUID, self.applyConcentration)
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
    return self:WithReagents(reagentTypes, reagents, slot and slot.slotIndex)
end

---@param applyConcentration? boolean
function Self:WithConcentration(applyConcentration)
    if applyConcentration == nil then applyConcentration = false end
    if self.applyConcentration == applyConcentration then return self end

    local op = Util:TblCopy(self)

    op.applyConcentration = applyConcentration
    op.resultPrice, op.profit = nil, nil

    return op
end

-- CLASS

---@param recipe CraftingRecipeSchematic
---@param allocation? RecipeAllocation
---@param orderOrRecraftGUID? CraftingOrderInfo | string
---@param applyConcentration? boolean
function Self:Init(recipe, allocation, orderOrRecraftGUID, applyConcentration)
    self.recipe = recipe
    self.allocation = allocation or Reagents:CreateAllocationFromSchematics(recipe.reagentSlotSchematics)
    self.orderOrRecraftGUID = orderOrRecraftGUID
    self.applyConcentration = applyConcentration

    -- Remove non-modifying and allocate provided order reagents
    local order = self:GetOrder()
    for slotIndex,allocations in pairs(self.allocation) do
        local slot = self.recipe.reagentSlotSchematics[slotIndex]

        if not Reagents:IsModified(slot) then
            self.allocation[slotIndex] = nil
        elseif Reagents:IsProvided(slot, order, self:GetRecraftMods()) then
            Reagents:ClearAllocations(allocations)

            for _,reagent in pairs(Reagents:GetProvided(slot, order, self:GetRecraftMods())) do
                local quantity = reagent.quantity or 1
                if allocations:GetQuantityAllocated(reagent) < quantity then
                    Reagents:Allocate(allocations, reagent, quantity)
                end
            end
        end
    end
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

-- Quality

function Self:GetQuality()
    return floor(self:GetOperationInfo().quality)
end

function Self:GetResultQuality()
    local quality = self:GetQuality()
    if not self.applyConcentration then return quality end
    return min(quality + 1, self:GetRecipeInfo().maxQuality)
end

function Self:GetQualityBreakpoints()
    return Addon.QUALITY_BREAKPOINTS[self:GetRecipeInfo().maxQuality]
end

-- Difficulty, Skill, Weight, Concentration

function Self:GetDifficulty()
    local operationInfo = self:GetOperationInfo()
    return operationInfo.baseDifficulty + operationInfo.bonusDifficulty
end

---@param includeBonusSkillReagents? boolean
---@return number skillBase
---@return number skillBest
function Self:GetSkillBounds(includeBonusSkillReagents)
    if not self.skillBase or not self.skillBest then
        local cache = Static.Cache.SkillBounds
        local key = cache:Key(self)

        if not cache:Has(key) then
            cache:Set(key, { Reagents:GetSkillBounds(self.recipe, self:GetQualityReagentSlots(), self:GetOptionalReagents(), self.orderOrRecraftGUID) })
        end

        self.skillBase, self.skillBest = unpack(cache:Get(key))
    end

    if includeBonusSkillReagents and self:GetBonusSkillReagentSlot() then
        return self.skillBase, self.skillBest + Reagents:GetMaxBonusSkill()
    else
        return self.skillBase, self.skillBest
    end
end

function Self:GetWeight()
    if not self.weight then
        self.weight = Reagents:GetAllocationWeight(self:GetQualityReagentSlots(), self.allocation)
    end
    return self.weight
end

function Self:GetMaxWeight()
    if not self.maxWeight then
        self.maxWeight = Reagents:GetMaxWeight(self:GetQualityReagentSlots())
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

---@param absolute? boolean
function Self:GetWeightThresholds(absolute)
    local lowerSkill, upperSkill = self:GetSkillThresholds(absolute)
    local maxWeight, difficulty = self:GetMaxWeight(), self:GetDifficulty()
    local lower, upper = maxWeight * lowerSkill, maxWeight * upperSkill

    if absolute then return lower / difficulty, upper / difficulty end

    local _, bestSkill = self:GetSkillBounds()
    return ceil(lower / bestSkill), min(maxWeight, floor(upper / bestSkill))
end

function Self:GetConcentrationFactors()
    if not self.concentrationFactors then
        local cache = Static.Cache.ConcentrationFactors
        local key = cache:Key(self)

        if not cache:Has(key) then
            ---@type number[]
            local concentrationFactors = {}

            local maxWeight = self:GetMaxWeight()
            local baseSkill, bestSkill = self:GetSkillBounds()
            local lowerSkill, upperSkill = self:GetSkillThresholds(true)
            local prevWeight, prevCon

            for i,v in ipairs(Addon.CONCENTRATION_BREAKPOINTS) do
                local skill = lowerSkill + v * (upperSkill - lowerSkill)
                local weight = max(0, maxWeight * (skill - baseSkill) / bestSkill)

                local reagents = Reagents:GetCraftingInfoForWeight(self.recipe, weight, i == 1)
                local op = self:WithQualityReagents(reagents)
                local info = op:GetOperationInfo()
                local opWeight = op:GetWeight()
                local opCon = info.concentrationCost

                if i > 1 and opWeight <= weight then
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
    Util:DebugProfileLevel("GetConcentrationCost")

    local concentration = self:GetOperationInfo().concentrationCost

    if not weight or weight == self:GetWeight() then
        Util:DebugProfileLevelStop()

        return concentration
    end

    local conFactors = self:GetConcentrationFactors()
    local baseSkill, bestSkill = self:GetSkillBounds()
    local lowerSkill, upperSkill = self:GetSkillThresholds(true)
    local maxWeight = self:GetMaxWeight()
    local currCon = concentration
    local currWeight = self:GetWeight()

    local n = #Addon.CONCENTRATION_BREAKPOINTS
    local d = currWeight <= weight and 1 or -1
    local bound = d == 1 and min or max

    for i=1,n-1 do
       local v = Addon.CONCENTRATION_BREAKPOINTS[d == 1 and i+1 or n-i]
       local f = conFactors[d == 1 and i or n-i]
       local targetSkill = lowerSkill + v * (upperSkill - lowerSkill)
       local targetWeight = bound(weight, maxWeight * (targetSkill - baseSkill) / bestSkill)

       if targetWeight * d > currWeight * d and targetWeight * d <= weight * d then
          currCon = currCon + (targetWeight - currWeight) * f
          currWeight = targetWeight
       end
    end

    Util:DebugProfileLevelStop()

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

            return ("%d;%d;%d;%d"):format(
                operation.recipe.recipeID,
                operation:GetQuality(),
                order and order.orderID or 0,
                operationInfo.baseSkill + operationInfo.bonusSkill + Addon.extraSkill
            )
        end,
        10
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
                profInfo and profInfo.skillLevel + profInfo.skillModifier or 0 + Addon.extraSkill
            )
        end,
        10
    )
}