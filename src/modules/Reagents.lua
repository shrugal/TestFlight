---@class Addon
local Addon = select(2, ...)
local Buffs, C, Cache, Orders, Prices, Recipes, Util = Addon.Buffs, Addon.Constants, Addon.Cache, Addon.Orders, Addon.Prices, Addon.Recipes, Addon.Util

---@class Reagents
local Self = Addon.Reagents

---@param reagent CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic | ProfessionTransactionAllocation | number
---@param characterInventoryOnly? boolean
function Self:GetQuantity(reagent, characterInventoryOnly)
    if type(reagent) == "table" then
        if reagent.reagents then reagent = reagent.reagents[1] end ---@cast reagent -CraftingReagentSlotSchematic
        if reagent.reagent then reagent = reagent.reagent end ---@cast reagent -ProfessionTransactionAllocation
        if reagent.itemID then reagent = reagent.itemID end ---@cast reagent number
    end

    return Util:TblGetHooked(ItemUtil, "GetCraftingReagentCount")(reagent, characterInventoryOnly)
end

---@param reagent CraftingReagentSlotSchematic
---@return number, number?, number?
function Self:GetQuantities(reagent)
    if #reagent.reagents == 1 then return self:GetQuantity(reagent) end

    local r1, r2, r3 = unpack(reagent.reagents)
    return self:GetQuantity(r1), self:GetQuantity(r2), self:GetQuantity(r3)
end

---@param recipe CraftingRecipeSchematic
---@param allocation RecipeAllocation
---@param order? CraftingOrderInfo
---@param recraftMods? CraftingItemSlotModification
---@return number
function Self:GetMaxCraftAmount(recipe, allocation, order, recraftMods)
    local count = math.huge

    for slotIndex,slot in pairs(recipe.reagentSlotSchematics) do repeat
        if self:IsProvided(slot, order, recraftMods) then break end

        local slotCount = math.huge
        local missing = slot.required and slot.quantityRequired or 0
        local allocs = allocation[slotIndex]

        if allocs then
            for _,alloc in allocs:Enumerate() do
                slotCount = min(slotCount, floor(self:GetQuantity(alloc.reagent) / alloc.quantity))
                missing = max(0, missing - alloc.quantity)
            end
        end

        if missing > 0 then
            slotCount = min(slotCount, floor(self:GetQuantity(slot) / missing))
        end

        count = min(count, slotCount)
    until true end

    if recipe.recipeType == Enum.TradeskillRecipeType.Enchant then
        local item = self:GetEnchantVellum(recipe)
        if not item then return 0 end

        count = min(count, self:GetQuantity(item:GetItemID()))
    end

    return count
end

---@param reagent number | CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic
---@param weightPerSkill? number
function Self:GetWeight(reagent, weightPerSkill)
    if type(reagent) == "table" then
        if reagent.reagents then reagent = reagent.reagents[1] end ---@cast reagent -CraftingReagentSlotSchematic
        do reagent = reagent.itemID end
    end ---@cast reagent number

    if self:HasStatBonus(reagent, "sk") then
        return floor(self:GetStatBonus(reagent, "sk") * weightPerSkill)
    else
        return C.REAGENTS[reagent] or 0
    end
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

---@param qualityReagents CraftingReagentSlotSchematic[]
function Self:GetCheapestWeight(qualityReagents)
    local cheapestWeight = 0
    for _,reagent in pairs(qualityReagents) do
        local p1, p2, p3 = Prices:GetReagentPrices(reagent)
        local w = p3 <= p1 and p3 <= p2 and 2 or p2 <= p1 and p2 <= p3 and 1 or 0
        cheapestWeight = cheapestWeight + reagent.quantityRequired * w * self:GetWeight(reagent)
    end
    return cheapestWeight
end

---@param recipe CraftingRecipeSchematic
---@param qualitySlots? CraftingReagentSlotSchematic[]
---@param optionalReagents? CraftingReagentInfo[]
---@param orderOrRecraftGUID? CraftingOrderInfo | string
function Self:GetSkillBounds(recipe, qualitySlots, optionalReagents, orderOrRecraftGUID)
    local cache = self.Cache.SkillBounds
    local key = cache:Key(recipe, optionalReagents, orderOrRecraftGUID)

    if cache:Has(key) then return unpack(cache:Get(key)) end

    local order = type(orderOrRecraftGUID) == "table" and orderOrRecraftGUID or nil

    if not qualitySlots then qualitySlots = self:GetQualitySlots(recipe) end

    optionalReagents = optionalReagents and Util:TblFilter(optionalReagents, self.IsUntradableBonusSkill, false, self)

    -- Create crafting infos
    local reagents = self:CreateCraftingInfosFromSchematics(qualitySlots, optionalReagents)

    -- Add order materials
    if order then
        for _,reagent in pairs(order.reagents) do
            local schematic = Util:TblWhere(recipe.reagentSlotSchematics, "slotIndex", reagent.slotIndex)
            if schematic and self:IsModified(schematic) then
                tinsert(reagents, reagent.reagent)
            end
        end
    end

    -- Get required skill with base and best materials
    local opBase = Recipes:GetOperationInfo(recipe, reagents, orderOrRecraftGUID)
    for i=1,#qualitySlots do reagents[i].itemID = qualitySlots[i].reagents[3].itemID end
    local opBest = Recipes:GetOperationInfo(recipe, reagents, orderOrRecraftGUID)

    if not opBase or not opBest then return end

    local skillBase = opBase.baseSkill + opBase.bonusSkill
    local skillRange = opBest.baseSkill + opBest.bonusSkill - skillBase

    cache:Set(key, { skillBase, skillRange })

    return skillBase, skillRange
end

---@param recipe CraftingRecipeSchematic
function Self:GetWeightPerSkill(recipe)
    local cache = self.Cache.WeightPerSkill
    local key = cache:Key(recipe)

    if cache:Has(key) then return cache:Get(key) end

    local qualitySlots = self:GetQualitySlots(recipe)
    local maxWeight = self:GetMaxWeight(qualitySlots)
    local _, skillRange = self:GetSkillBounds(recipe, qualitySlots)
    local weightPerSkill = maxWeight / skillRange

    cache:Set(key, weightPerSkill)

    return weightPerSkill
end

---@return number[] reagents
---@return number[] missing
---@return number[] owned
---@return number[] crafted
---@return number[] provided
function Self:GetTrackedBySource()
    local GetCraftingReagentCount = Util:TblGetHooked(ItemUtil, "GetCraftingReagentCount")

    local recipeReagents = Recipes:GetTrackedReagentAmounts()
    local recipeResults = Recipes:GetTrackedResultAmounts()
    local orderReagents, orderProvided = Orders:GetTrackedReagentAmounts()
    local orderResults = Orders:GetTrackedResultAmounts()

    -- Combine
    local reagents, crafted = recipeReagents, recipeResults

    for itemID,amount in pairs(orderReagents) do reagents[itemID] = (reagents[itemID] or 0) + amount end
    for itemID,amount in pairs(orderResults) do crafted[itemID] = (crafted[itemID] or 0) + amount end

    -- Split reagents in missing, owned and crafting
    local missing, owned, crafting = {}, {}, {}

    for itemID,amount in pairs(reagents) do
        local ownedItems = GetCraftingReagentCount(itemID)
        if ownedItems > 0 then
            owned[itemID], amount = ownedItems, max(0, amount - ownedItems)
        end

        local craftingItems = min(amount, crafted[itemID] or 0)
        if craftingItems > 0 then
            crafting[itemID], amount = craftingItems, amount - craftingItems
        end

        if amount > 0 then
            missing[itemID] = amount
        end
    end

    return reagents, missing, owned, crafting, orderProvided
end

---------------------------------------
--            CraftingInfo
---------------------------------------

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
    for slotIndex,allocs in pairs(allocation) do
        local reagent = Util:TblWhere(recipe.reagentSlotSchematics, "slotIndex", slotIndex)
        if reagent and self:IsModified(reagent) and (not predicate or predicate(reagent)) then
            for _,alloc in pairs(allocs.allocs) do
                tinsert(infos, Professions.CreateCraftingReagentInfo(alloc.reagent.itemID, reagent.dataSlotIndex, alloc.quantity))
            end
        end
    end

    return infos
end

---@param recipe CraftingRecipeSchematic
---@param targetWeight number
---@param isLowerBound? boolean
function Self:GetCraftingInfoForWeight(recipe, targetWeight, isLowerBound)
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

---@param reagents CraftingReagentInfo[]
---@param reagent CraftingReagentSlotSchematic
---@param i? number
---@param q? number
function Self:AddCraftingInfo(reagents, reagent, i, q)
    if q and q > 0 then tinsert(reagents, self:CreateCraftingInfoFromSchematic(reagent, i, q)) end
end

---@param reagents CraftingReagentInfo[]
---@param reagent CraftingReagentSlotSchematic
---@param q1? number
---@param q2? number
---@param q3? number
function Self:AddCraftingInfos(reagents, reagent, q1, q2, q3)
    self:AddCraftingInfo(reagents, reagent, 1, q1)
    self:AddCraftingInfo(reagents, reagent, 2, q2)
    self:AddCraftingInfo(reagents, reagent, 3, q3)
end

---@param recipe CraftingRecipeSchematic
function Self:GetEnchantVellum(recipe)
    for _,itemGUID in pairs(C_TradeSkillUI.GetEnchantItems(recipe.recipeID)) do
        local item = Item:CreateFromItemGUID(itemGUID) --[[@as ItemMixin]]
        if item:IsStackable() then return item end
    end
end

---------------------------------------
--            Allocation
---------------------------------------

---@param allocations ProfessionTransationAllocations
---@param reagent CraftingReagent | CraftingReagentInfo | CraftingItemSlotModification | number
---@param quantity? number
function Self:Allocate(allocations, reagent, quantity)
    if type(reagent) == "number" then
        reagent = Professions.CreateCraftingReagentByItemID(reagent)
    elseif reagent.dataSlotIndex then
        quantity = quantity or reagent.quantity
        reagent = Professions.CreateCraftingReagentByItemID(reagent.itemID)
    end ---@cast reagent CraftingReagent

    local origOnChanged = allocations.OnChanged
    allocations.OnChanged = Util.FnNoop
    allocations:Allocate(reagent, quantity or 0)
    allocations.OnChanged = origOnChanged
end

---@param allocations ProfessionTransationAllocations
function Self:ClearAllocations(allocations)
    local origOnChanged = allocations.OnChanged
    allocations.OnChanged = Util.FnNoop
    allocations:Clear()
    allocations.OnChanged = origOnChanged
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

---------------------------------------
--              Slots
---------------------------------------

---@param reagent CraftingReagentSlotSchematic
---@param recipeInfo TradeSkillRecipeInfo
---@return boolean
---@return string?
function Self:IsLocked(reagent, recipeInfo)
    return Util:TblGetHooked(Professions, "GetReagentSlotStatus")(reagent, recipeInfo)
end

---@param reagent CraftingReagentSlotSchematic
function Self:IsBasic(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Basic and #reagent.reagents == 1
end

---@param reagent CraftingReagentSlotSchematic
function Self:IsQuality(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Basic and #reagent.reagents > 1
end

---@param reagent CraftingReagentSlotSchematic
function Self:IsModifying(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Modifying
end

-- Reagent modifies the result quality
---@param reagent CraftingReagentSlotSchematic
function Self:IsModified(reagent)
    return reagent.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent
end

---@param reagent CraftingReagentSlotSchematic
function Self:IsFinishing(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Finishing
end

-- Reagent modifies the result quality, but is not a quality reagent
---@param reagent CraftingReagentSlotSchematic
function Self:IsOptional(reagent)
    return reagent.reagentType == Enum.CraftingReagentType.Modifying or reagent.reagentType == Enum.CraftingReagentType.Finishing
end

---@param reagent CraftingReagentSlotSchematic
function Self:IsBonusSkill(reagent)
    return self:IsFinishing(reagent) and Util:TblEvery(reagent.reagents, self.HasStatBonus, false, self, "sk")
end

---@param reagent CraftingReagentInfo | CraftingReagent | number
function Self:IsUntradableBonusSkill(reagent)
    return self:HasStatBonus(reagent, "sk") and not Prices:HasReagentPrice(reagent)
end

---@param reagent CraftingReagentSlotSchematic
---@param order? CraftingOrderInfo
---@param recraftMods? CraftingItemSlotModification[]
function Self:IsProvided(reagent, order, recraftMods)
    if not order then return false end
    if reagent.orderSource == Enum.CraftingOrderReagentSource.Customer then return order.orderID ~= nil end
    if reagent.orderSource == Enum.CraftingOrderReagentSource.Crafter then return order.orderID == nil end

    if Orders:IsCreatingProvided(order, reagent.slotIndex) then return true end
    if Util:TblWhere(order.reagents, "slotIndex", reagent.slotIndex) then return true end

    if order.orderID and order.isRecraft and self:IsModified(reagent) then ---@cast recraftMods -?
        local slot = Util:TblWhere(recraftMods, "dataSlotIndex", reagent.dataSlotIndex)
        return slot and slot.itemID ~= 0
    end

    return false
end

---@param reagent CraftingReagentSlotSchematic
---@param order? CraftingOrderInfo
---@param recraftMods? CraftingItemSlotModification[]
---@return CraftingReagentInfo[] | CraftingItemSlotModification[]
function Self:GetProvided(reagent, order, recraftMods)
    if not order or Orders:IsCreating(order) then return {} end ---@todo
    if reagent.orderSource == Enum.CraftingOrderReagentSource.Customer and order.orderID == nil then return {} end
    if reagent.orderSource == Enum.CraftingOrderReagentSource.Crafter and order.orderID ~= nil then return {} end

    local list = Util:TblFilterWhere(order.reagents, "slotIndex", reagent.slotIndex)
    for k,v in pairs(list) do --[=[@cast list CraftingReagentInfo[]]=] list[k] = v.reagent end

    if #list == 0 and order.orderID and order.isRecraft and self:IsModified(reagent) then ---@cast recraftMods -?
        local slot = Util:TblWhere(recraftMods, "dataSlotIndex", reagent.dataSlotIndex)
        if slot and slot.itemID ~= 0 then tinsert(list, slot) end
    end

    return list
end

---@param recipe CraftingRecipeSchematic
---@param order CraftingOrderInfo?
---@param recraftMods? CraftingItemSlotModification[]
---@return CraftingReagentSlotSchematic[]
function Self:GetQualitySlots(recipe, order, recraftMods)
    return Util:TblFilter(recipe.reagentSlotSchematics, function (slot)
        return self:IsQuality(slot) and not self:IsProvided(slot, order, recraftMods)
    end)
end

---@param recipe CraftingRecipeSchematic
---@param recipeInfo? TradeSkillRecipeInfo
function Self:GetBonusSkillSlot(recipe, recipeInfo)
    if not recipeInfo then recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipe.recipeID) end ---@cast recipeInfo -?

    for _,slot in pairs(recipe.reagentSlotSchematics) do
        if self:IsBonusSkill(slot) and not self:IsLocked(slot, recipeInfo) then
            return slot
        end
    end
end

---@param order? CraftingOrderInfo
---@param recraftGUID string?
function Self:GetRecraftMods(order, recraftGUID)
    if recraftGUID then
        return C_TradeSkillUI.GetItemSlotModifications(recraftGUID)
    elseif order and order.orderID and order.isRecraft then
        return C_TradeSkillUI.GetItemSlotModificationsForOrder(order.orderID)
    end
end

---------------------------------------
--              Stats
---------------------------------------

---@param reagent CraftingReagentInfo | CraftingReagent | number
---@param stat BonusStat
function Self:GetStatBonus(reagent, stat)
    if type(reagent) == "table" then reagent = reagent.itemID end

    local stats = C.FINISHING_REAGENTS[reagent]
    local val = stats and stats[stat] or 0

    return stat == "sk" and val or val / 100
end

---@param reagent CraftingReagentInfo | CraftingReagent | number
---@param stat BonusStat
function Self:HasStatBonus(reagent, stat)
    return self:GetStatBonus(reagent, stat) > 0
end

function Self:GetMaxBonusSkill()
    local maxSkill = 0
    for itemID, stats in pairs(C.FINISHING_REAGENTS) do
        if (stats.sk or 0) > maxSkill and Prices:HasReagentPrice(itemID) then
            maxSkill = stats.sk
        end
    end
    return maxSkill
end

---------------------------------------
--              Cache
---------------------------------------

Self.Cache = {
    ---@type Cache<number[], fun(self: Cache, recipe: CraftingRecipeSchematic, optionalReagents?: CraftingReagentInfo[], orderOrRecraftGUID?: CraftingOrderInfo | string): string>
    SkillBounds = Cache:Create(
        ---@param recipe CraftingRecipeSchematic
        ---@param optionalReagents? CraftingReagentInfo[]
        ---@param orderOrRecraftGUID? CraftingOrderInfo | string
        function (_, recipe, optionalReagents, orderOrRecraftGUID)
            local order = type(orderOrRecraftGUID) == "table" and orderOrRecraftGUID or nil
            local recraftGUID = type(orderOrRecraftGUID) == "string" and orderOrRecraftGUID or nil
            local profInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipe.recipeID)
            local reagent = optionalReagents and select(2, Util:TblFind(optionalReagents, Self.IsUntradableBonusSkill, false, Self))

            local key = ("%d;%d;%s;%d;%d"):format(
                recipe.recipeID,
                order and order.orderID or 0,
                recipe.isRecraft and recraftGUID or 0,
                profInfo and profInfo.skillLevel + profInfo.skillModifier or 0,
                reagent and reagent.itemID or 0
            )

            return key
        end,
        nil,
        10,
        true
    ),
    ---@type Cache<number, fun (self: Cache, recipe: CraftingRecipeSchematic): string>
    WeightPerSkill = Cache:Create(
        ---@param recipe CraftingRecipeSchematic
        function (_, recipe)
            return ("%d;%d"):format(recipe.recipeID, recipe.isRecraft and 1 or 0)
        end
    )
}

---------------------------------------
--              Events
---------------------------------------

function Self:OnBuffChanged()
    self.Cache.SkillBounds:Clear()
end

function Self:OnLoaded()
    Buffs:RegisterCallback(Buffs.Event.AuraChanged, self.OnBuffChanged, self)
end

Addon:RegisterCallback(Addon.Event.Loaded, Self.OnLoaded, Self)