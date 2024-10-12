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
function Self:GetQuantity(reagent)
    if reagent.reagents then reagent = reagent.reagents[1] end ---@cast reagent -CraftingReagentSlotSchematic
    if reagent.reagent then reagent = reagent.reagent end ---@cast reagent -ProfessionTransactionAllocation
    return ProfessionsUtil.GetReagentQuantityInPossession(reagent)
end

---@param reagent CraftingReagentSlotSchematic
---@return number, number?, number?
function Self:GetQuantities(reagent)
    if #reagent.reagents == 1 then return self:GetQuantity(reagent) end

    local r1, r2, r3 = unpack(reagent.reagents)
    return self:GetQuantity(r1), self:GetQuantity(r2), self:GetQuantity(r3)
end

---@param reagent CraftingReagentSlotSchematic
---@param quality? 1|2|3
---@param quantity? number
---@return CraftingReagentInfo
function Self:CreateCraftingInfoFromSchematic(reagent, quality, quantity)
    return Professions.CreateCraftingReagentInfo(
        reagent.reagents[quality or 1].itemID,
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
---@param optionalReagents? CraftingReagentInfo[]
function Self:CreateCraftingInfosFromAllocation(recipe, allocation, optionalReagents)
    ---@type CraftingReagentInfo[]
    local infos = {}

    -- Add allocation reagents
    for slotIndex,allocs in pairs(allocation) do
        local reagent = Util:TblWhere(recipe.reagentSlotSchematics, "slotIndex", slotIndex)
        if reagent and self:IsQualityReagent(reagent) then
            for _,alloc in pairs(allocs.allocs) do
                tinsert(infos, Professions.CreateCraftingReagentInfo(alloc.reagent.itemID, reagent.dataSlotIndex, alloc.quantity))
            end
        end
    end

    -- Add optional reagents
    if optionalReagents then
        for _,info in pairs(optionalReagents) do tinsert(infos, info) end
    end

    return infos
end

---@param order? CraftingOrderInfo
---@return RecipeAllocation
function Self:CreateAllocation(order)
    ---@type ProfessionTransationAllocations[]
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
---@param q1 number
---@param q2 number
---@param q3 number
---@return ProfessionTransationAllocations
function Self:CreateAllocations(reagent, q1, q2, q3)
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
    return reagent.reagentType == Enum.CraftingReagentType.Basic and #reagent.reagents > 1
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
    local maxWeight = 0
    for _,reagent in pairs(qualityReagents) do
        maxWeight = maxWeight + 2 * reagent.quantityRequired * self:GetWeight(reagent)
    end
    return maxWeight
end

---@param recipe CraftingRecipeSchematic
---@param optionalReagents? CraftingReagentInfo[]
---@param qualityReagents? CraftingReagentSlotSchematic[]
---@param recraftItemGUID? string
---@param order? CraftingOrderInfo
function Self:GetSkillBounds(recipe, optionalReagents, qualityReagents, recraftItemGUID, order)
    if not qualityReagents then qualityReagents = self:GetQualityReagents(recipe, order) end

    -- Create crafting infos
    local infos = self:CreateCraftingInfosFromSchematics(qualityReagents, optionalReagents)

    -- Get required skill with base and best materials
    ---@type CraftingOperationInfo?, CraftingOperationInfo?
    local opBase, opBest
    if not order then
        opBase = C_TradeSkillUI.GetCraftingOperationInfo(recipe.recipeID, infos, recraftItemGUID, false)
        for i=1,#qualityReagents do infos[i].itemID = qualityReagents[i].reagents[3].itemID end
        opBest = C_TradeSkillUI.GetCraftingOperationInfo(recipe.recipeID, infos, recraftItemGUID, false)
    else
        -- Add order materials
        for _,reagent in pairs(order.reagents) do
            local schematic = Util:TblWhere(recipe.reagentSlotSchematics, "slotIndex", reagent.slotIndex)
            if schematic and (self:IsQualityReagent(schematic) or self:IsModifyingReagent(schematic)) then
                tinsert(infos, reagent.reagent)
            end
        end

        opBase = C_TradeSkillUI.GetCraftingOperationInfoForOrder(recipe.recipeID, infos, order.orderID, false)
        for i=1,#qualityReagents do infos[i].itemID = qualityReagents[i].reagents[3].itemID end
        opBest = C_TradeSkillUI.GetCraftingOperationInfoForOrder(recipe.recipeID, infos, order.orderID, false)
    end

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