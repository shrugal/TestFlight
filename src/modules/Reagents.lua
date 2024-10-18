---@class Addon
local Addon = select(2, ...)
local Orders, Recipes, Util = Addon.Orders, Addon.Recipes, Addon.Util

---@class Reagents
local Self = Addon.Reagents

---@param reagent number | CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic
function Self:GetWeight(reagent)
    if type(reagent) == "table" then
        if reagent.reagents then reagent = reagent.reagents[1] end ---@cast reagent -CraftingReagentSlotSchematic
        do reagent = reagent.itemID end
    end ---@cast reagent -CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic

    return Addon.REAGENTS[reagent] or 0
end

---@param reagent CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic | ProfessionTransactionAllocation
---@param characterInventoryOnly? boolean
function Self:GetQuantity(reagent, characterInventoryOnly)
    if reagent.reagents then reagent = reagent.reagents[1] end ---@cast reagent -CraftingReagentSlotSchematic
    if reagent.reagent then reagent = reagent.reagent end ---@cast reagent -ProfessionTransactionAllocation
    return ProfessionsUtil.GetReagentQuantityInPossession(reagent, characterInventoryOnly)
end

---@param reagent CraftingReagentSlotSchematic
---@return number, number?, number?
function Self:GetQuantities(reagent)
    if #reagent.reagents == 1 then return self:GetQuantity(reagent) end

    local r1, r2, r3 = unpack(reagent.reagents)
    return self:GetQuantity(r1), self:GetQuantity(r2), self:GetQuantity(r3)
end

---@param reagent CraftingReagentSlotSchematic
---@param itemIndex? number
---@param quantity? number
---@return CraftingReagentInfo
function Self:CreateCraftingInfoFromSchematic(reagent, itemIndex, quantity)
    return Professions.CreateCraftingReagentInfo(
        reagent.reagents[itemIndex or 1].itemID,
        reagent.dataSlotIndex,
        quantity or reagent.quantityRequired
    )
end

---@param reagents CraftingReagentSlotSchematic[]
---@param optionalReagents? CraftingReagentInfo[]
function Self:CreateCraftingInfosFromSchematics(reagents, optionalReagents)
    local infos = Util:TblMap(reagents, self.CreateCraftingInfoFromSchematic, false, self)

    -- Add optional reagents
    if optionalReagents then
        for _,info in pairs(optionalReagents) do tinsert(infos, info) end
    end

    return infos
end

---@param recipe CraftingRecipeSchematic
---@param allocation RecipeAllocation
---@param predicate? fun(reagent: CraftingReagentSlotSchematic): boolean?
function Self:CreateCraftingInfosFromAllocation(recipe, allocation, predicate)
    ---@type CraftingReagentInfo[]
    local infos = {}

    -- Add allocation reagents
    for slotIndex,allocations in pairs(allocation) do
        local reagent = Util:TblWhere(recipe.reagentSlotSchematics, "slotIndex", slotIndex)
        if reagent and reagent.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent and (not predicate or predicate(reagent)) then
            for _,alloc in pairs(allocations.allocs) do
                tinsert(infos, Professions.CreateCraftingReagentInfo(alloc.reagent.itemID, reagent.dataSlotIndex, alloc.quantity))
            end
        end
    end

    return infos
end

---@param reagents CraftingReagentInfo[]
---@param reagent CraftingReagentSlotSchematic
---@param q1? number
---@param q2? number
---@param q3? number
function Self:AddCraftingInfos(reagents, reagent, q1, q2, q3)
    if q1 and q1 > 0 then tinsert(reagents, self:CreateCraftingInfoFromSchematic(reagent, 1, q1)) end
    if q2 and q2 > 0 then tinsert(reagents, self:CreateCraftingInfoFromSchematic(reagent, 2, q2)) end
    if q3 and q3 > 0 then tinsert(reagents, self:CreateCraftingInfoFromSchematic(reagent, 3, q3)) end
end

---@param recipe CraftingRecipeSchematic
---@param targetWeight number
---@param isLowerBound? boolean
function Self:GetForWeight(recipe, targetWeight, isLowerBound)
    ---@type CraftingReagentInfo[]
    local reagents = {}

    local restWeight = targetWeight
    local slots = Util(self:GetQualitySlots(recipe)):SortBy(Util:FnBind(self.GetWeight, self))()

    for i,reagent in ipairs_reverse(slots) do
        local w = self:GetWeight(reagent)
        local q1 = reagent.quantityRequired
        local q3 = min(q1, floor(restWeight / w / 2))
        q1, restWeight = q1 - q3, restWeight - q3 * w * 2
        local q2 = min(q1, floor(restWeight / w))
        q1, restWeight = q1 - q2, restWeight - q2 * w

        if isLowerBound and i == 1 and restWeight > 0 and q1 > 0 then
            q1, q2, restWeight = q1 - 1, q2 + 1, restWeight - w
        end

        self:AddCraftingInfos(reagents, reagent, q1, q2, q3)
    end

    return reagents, targetWeight - restWeight
end

---@param reagent CraftingReagentSlotSchematic
---@param q1 number
---@param q2 number
---@param q3 number
---@return ProfessionTransationAllocations
function Self:CreateAllocations(reagent, q1, q2, q3)
    local reagentAllocations = Addon:CreateAllocations()

    self:Allocate(reagentAllocations, reagent.reagents[1], q1)
    self:Allocate(reagentAllocations, reagent.reagents[2], q2)
    self:Allocate(reagentAllocations, reagent.reagents[3], q3)

    return reagentAllocations
end

---@param allocations ProfessionTransationAllocations
---@param reagent CraftingReagent | CraftingReagentInfo |  number
---@param quantity number
function Self:Allocate(allocations, reagent, quantity)
    if type(reagent) == "number" then
        reagent = Professions.CreateCraftingReagentByItemID(reagent)
    elseif reagent.dataSlotIndex then
        reagent = Professions.CreateCraftingReagentByItemID(reagent.itemID)
    end ---@cast reagent CraftingReagent

    local origOnChanged = allocations.OnChanged
    allocations.OnChanged = Util.FnNoop
    allocations:Allocate(reagent, quantity)
    allocations.OnChanged = origOnChanged
end

---@param reagent CraftingReagentSlotSchematic
function Self:IsBasicReagent(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Basic and #reagent.reagents == 1
end

---@param reagent CraftingReagentSlotSchematic
function Self:IsQualityReagent(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Basic and #reagent.reagents > 1
end

-- Reagent modifies the result quality
---@param reagent CraftingReagentSlotSchematic
function Self:IsModifyingReagent(reagent)
    return reagent.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent
end

---@param reagent CraftingReagentSlotSchematic
function Self:IsFinishingReagent(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Finishing
end

-- Reagent modifies the result quality, but is not a quality reagent
---@param reagent CraftingReagentSlotSchematic
function Self:IsOptionalReagent(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Modifying or reagent.reagentType == Enum.CraftingReagentType.Finishing
end

---@param recipe CraftingRecipeSchematic
---@param order CraftingOrderInfo?
---@return CraftingReagentSlotSchematic[]
function Self:GetQualitySlots(recipe, order)
    return Util:TblFilter(recipe.reagentSlotSchematics, function (reagent, slotIndex)
        return self:IsQualityReagent(reagent) and not (order and Util:TblWhere(order.reagents, "slotIndex", slotIndex))
    end, true)
end

-- Get the non-skill finishing reagent slot
---@param recipe CraftingRecipeSchematic
---@return CraftingReagentSlotSchematic[]
function Self:GetFinishingSlots(recipe)
    return Util:TblFilter(recipe.reagentSlotSchematics, function (reagent)
        return reagent.reagentType == Enum.CraftingReagentType.Finishing
    end)
end

---@param qualityReagents CraftingReagentSlotSchematic[]
---@param allocation RecipeAllocation
function Self:GetAllocationWeight(qualityReagents, allocation)
    local weight = 0
    for _,reagent in pairs(qualityReagents) do
       local allocations = allocation[reagent.slotIndex]
       if allocations then
          for i=2,3 do
             local quantity = allocations:GetQuantityAllocated(reagent.reagents[i])
             if quantity > 0 then
                weight = weight + (i-1) * quantity * self:GetWeight(reagent)
             end
          end
       end
    end
    return weight
end

---@param order CraftingOrderInfo
function Self:GetOrderWeight(order)
    local orderWeight = 0
    for _,reagent in pairs(order.reagents) do
        orderWeight = orderWeight + reagent.reagent.quantity * self:GetWeight(reagent.reagent)
    end
    return orderWeight
end

---@param qualityReagents CraftingReagentSlotSchematic[]
---@return number
function Self:GetMaxWeight(qualityReagents)
    local weight = 0
    for _,reagent in pairs(qualityReagents) do
        weight = weight + 2 * reagent.quantityRequired * self:GetWeight(reagent)
    end
    return weight
end

---@param recipe CraftingRecipeSchematic
---@param qualitySlots? CraftingReagentSlotSchematic[]
---@param optionalReagents? CraftingReagentInfo[]
---@param orderOrRecraftGUID? CraftingOrderInfo | string
function Self:GetSkillBounds(recipe, qualitySlots, optionalReagents, orderOrRecraftGUID)
    local order = type(orderOrRecraftGUID) == "table" and orderOrRecraftGUID or nil

    if not qualitySlots then qualitySlots = self:GetQualitySlots(recipe, order) end

    -- Create crafting infos
    local reagents = self:CreateCraftingInfosFromSchematics(qualitySlots, optionalReagents)

    -- Add order materials
    if order then
        for _,reagent in pairs(order.reagents) do
            local schematic = Util:TblWhere(recipe.reagentSlotSchematics, "slotIndex", reagent.slotIndex)
            if schematic and self:IsModifyingReagent(schematic) then
                tinsert(reagents, reagent.reagent)
            end
        end
    end

    -- Get required skill with base and best materials
    local opBase = Recipes:GetOperationInfo(recipe, reagents, orderOrRecraftGUID)
    for i=1,#qualitySlots do reagents[i].itemID = qualitySlots[i].reagents[3].itemID end
    local opBest = Recipes:GetOperationInfo(recipe, reagents, orderOrRecraftGUID)

    if not opBase or not opBest then return end

    if Addon.enabled then
        opBase.baseSkill = opBase.baseSkill + Addon.extraSkill
        opBest.baseSkill = opBest.baseSkill + Addon.extraSkill
    end

    local skillBase = opBase.baseSkill + opBase.bonusSkill
    local skillBest = opBest.baseSkill + opBest.bonusSkill - skillBase

    return skillBase, skillBest
end

---@return number[] reagents
---@return number[] missing
---@return number[] owned
---@return number[] crafted
---@return number[] provided
function Self:GetTrackedBySource()
    local GetCraftingReagentCount = Util:TblGetHooked(ItemUtil, "GetCraftingReagentCount")

    local reagents = Recipes:GetTrackedReagentAmounts()
    local crafting = Recipes:GetTrackedResultAmounts()
    local provided = Orders:GetTrackedProvidedReagentAmounts()

    local missing, crafted, owned = {}, {}, {}

    for itemID,required in pairs(reagents) do
        -- Account for owned items
        local ownedItems = GetCraftingReagentCount(itemID)
        if ownedItems > 0 then
            owned[itemID], required = ownedItems, max(0, required - ownedItems)
        end

        -- Account for crafting results
        local craftingItems = min(required, crafting[itemID] or 0)
        if craftingItems > 0 then
            crafted[itemID], required = craftingItems, required - craftingItems
        end

        -- Add to missing reagents
        if required > 0 then
            missing[itemID] = required
        end
    end

    return reagents, missing, owned, crafted, provided
end