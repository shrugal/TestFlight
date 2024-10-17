---@class Addon
local Addon = select(2, ...)
local Prices, Reagents, Recipes, Util = Addon.Prices, Addon.Reagents, Addon.Recipes, Addon.Util

-- A crafting operation
---@class Operation
---@field recipe CraftingRecipeSchematic
---@field allocation RecipeAllocation
---@field orderOrRecraftGUID? CraftingOrderInfo | string
---@field applyConcentration? boolean
local Self = {}

-- CREATE

---@param recipe CraftingRecipeSchematic
---@param allocation? RecipeAllocation
---@param orderOrRecraftGUID? CraftingOrderInfo | string
---@param applyConcentration? boolean
function Addon:CreateOperation(recipe, allocation, orderOrRecraftGUID, applyConcentration)
    return CreateAndInitFromMixin(Self, recipe, allocation, orderOrRecraftGUID, applyConcentration) --[[@as Operation]]
end

---@param allocation? RecipeAllocation
function Self:WithAllocation(allocation)
    return Addon:CreateOperation(self.recipe, allocation, self.orderOrRecraftGUID, self.applyConcentration)
end

---@param reagentType Enum.CraftingReagentType
---@param reagents? CraftingReagentInfo[]
function Self:WithReagents(reagentType, reagents)
    local allocation = Util:TblCopy(self.allocation, true)

    for _,slot in ipairs(self.recipe.reagentSlotSchematics) do
        if Reagents:IsModifyingReagent(slot) and slot.reagentType == reagentType then
            allocation[slot.slotIndex] = Addon:CreateAllocations()

            if reagents then
                for _,reagent in pairs(reagents) do
                    if reagent.dataSlotIndex == slot.dataSlotIndex then
                        Reagents:Allocate(allocation[slot.slotIndex], reagent, reagent.quantity)
                    end
                end
            end
        end
    end

    return self:WithAllocation(allocation)
end

---@param reagents? CraftingReagentInfo[]
function Self:WithQualityReagents(reagents)
    return self:WithReagents(Enum.CraftingReagentType.Basic, reagents)
end

---@param reagents? CraftingReagentInfo[]
function Self:WithModifyingReagents(reagents)
    return self:WithReagents(Enum.CraftingReagentType.Modifying, reagents)
end

---@param reagents? CraftingReagentInfo[]
function Self:WithFinishingReagents(reagents)
    return self:WithReagents(Enum.CraftingReagentType.Finishing, reagents)
end

-- CLASS

---@param recipe CraftingRecipeSchematic
---@param allocation? RecipeAllocation
---@param orderOrRecraftGUID? CraftingOrderInfo | string
---@param applyConcentration? boolean
function Self:Init(recipe, allocation, orderOrRecraftGUID, applyConcentration)
    self.recipe = recipe
    self.allocation = allocation or {}
    self.orderOrRecraftGUID = orderOrRecraftGUID
    self.applyConcentration = applyConcentration
end

function Self:GetRecipeInfo()
    if not self.recipeInfo then
        self.recipeInfo = C_TradeSkillUI.GetRecipeInfo(self.recipe.recipeID)
    end
    return self.recipeInfo
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

-- Reagents

function Self:GetQualityReagentSlots()
    if not self.qualityReagentSlots then
        self.qualityReagentSlots = Reagents:GetQualitySlots(self.recipe)
    end
    return self.qualityReagentSlots
end

function Self:GetFinishingReagentSlots()
    if not self.finishingReagentSlots then
        self.finishingReagentSlots = Reagents:GetFinishingSlots(self.recipe)
    end
    return self.finishingReagentSlots
end

function Self:GetQualityReagents()
    if not self.qualityReagents then
        local predicate = Util:FnBind(Reagents.IsQualityReagent, Reagents)
        self.qualityReagents = Reagents:CreateCraftingInfosFromAllocation(self.recipe, self.allocation, predicate)
    end
    return self.qualityReagents
end

function Self:GetOptionalReagents()
    if not self.optionalReagents then
        local predicate = function (reagent) return not reagent.required end
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

---@return number skillBase
---@return number skillBest
function Self:GetSkillBounds()
    if not self.skillBase or not self.skillBest then
        self.skillBase, self.skillBest = Reagents:GetSkillBounds(self.recipe, self:GetQualityReagentSlots(), self:GetOptionalReagents(), self.orderOrRecraftGUID)
    end
    return self.skillBase, self.skillBest
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
    return ceil(lower / bestSkill), min(self:GetMaxWeight(), floor(upper / bestSkill))
end

function Self:GetConcentrationFactors()
    if not self.concentrationFactors then
        self.concentrationFactors = {}

        local maxWeight = self:GetMaxWeight()
        local baseSkill, bestSkill = self:GetSkillBounds()
        local lowerSkill, upperSkill = self:GetSkillThresholds(true)
        local prevWeight, prevCon

        for i,v in ipairs(Addon.CONCENTRATION_BREAKPOINTS) do
            local skill = lowerSkill + v * (upperSkill - lowerSkill)
            local weight = max(0, maxWeight * (skill - baseSkill) / bestSkill)

            local reagents = Reagents:GetForWeight(self.recipe, weight, i == 1)
            local op = self:WithQualityReagents(reagents)
            local info = op:GetOperationInfo()
            local opWeight = op:GetWeight()
            local opCon = info.concentrationCost

            if i > 1 and opWeight <= weight then
                self.concentrationFactors[i-1] = (prevCon - opCon) / (prevWeight - opWeight)
            end

            prevWeight, prevCon = opWeight, opCon
        end
    end
    return self.concentrationFactors
end

function Self:GetConcentrationCost(weight)
    local concentration = self:GetOperationInfo().concentrationCost

    if not weight or weight == self:GetWeight() then
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

    return currCon
end

-- Stats

function Self:GetResourcefulnessFactor()
    if not self.resourcefulnessFactor then
        self.resourcefulnessFactor = Recipes:GetResourcefulnessFactor(self.recipe, self:GetOperationInfo())
    end
    return self.resourcefulnessFactor
end

function Self:GetMulticraftFactor()
    if not self.multicraftFactor then
        self.multicraftFactor = Recipes:GetMulticraftFactor(self.recipe, self:GetOperationInfo())
    end
    return self.multicraftFactor
end

-- Prices

function Self:GetReagentPrice()
    if not self.reagentPrice then
        self.reagentPrice = Prices:GetRecipeAllocationPrice(self.recipe, self.allocation, self:GetOrder())
    end
    return self.reagentPrice
end

function Self:GetResultPrice()
    if not self.resultPrice then
        self.resultPrice = Prices:GetRecipeResultPrice(self.recipe, self:GetOperationInfo(), self:GetOptionalReagents(), self:GetResultQuality())
    end
    return self.resultPrice
end

---@return number? profit
---@return number? revenue
---@return number? resourcefulness
---@return number? multicraft
---@return number? rewards
---@return number? traderCut
function Self:GetProfit()
    if not self.profit then
        local reagentPrice = self:GetReagentPrice() ---@cast reagentPrice -?
        local resultPrice = self:GetResultPrice()
        local profit, revenue, resourcefulness, multicraft, rewards, traderCut = Prices:GetRecipeProfit(self.recipe, self:GetOperationInfo(), self.allocation, reagentPrice, resultPrice, self:GetOrder())
        self.profit, self.revenue, self.resourcefulness, self.multicraft, self.rewards, self.traderCut = profit, revenue, resourcefulness, multicraft, rewards, traderCut
    end
    return self.profit, self.revenue, self.resourcefulness, self.multicraft, self.rewards, self.traderCut
end

function Self:GetProfitPerConcentration()
    return self:GetProfit() / self:GetOperationInfo().concentrationCost
end

function Self:HasProfit()
    return self:GetOrder() ~= nil or not self.orderOrRecraftGUID and self:GetResultPrice() > 0
end

