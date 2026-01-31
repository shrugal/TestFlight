---@class Addon
local Addon = select(2, ...)
local Allocations, Buffs, C, Cache, Orders, Prices, Recipes, Util = Addon.Allocations, Addon.Buffs, Addon.Constants, Addon.Cache, Addon.Orders, Addon.Prices, Addon.Recipes, Addon.Util

---@class Reagents: CallbackRegistryMixin
---@field Event Reagents.Event
local Self = Mixin(Addon.Reagents, CallbackRegistryMixin)

---@param item number | string
function Self:GetName(item)
    local name = C_Item.GetItemInfo(item)

    local icon = self:GetQualityIcon(item)
    if icon then name = ("%s %s"):format(name, icon) end

    return name
end

---@param reagent Reagent
function Self:GetItemID(reagent)
    if type(reagent) == "number" then return reagent end
    if reagent.reagents then reagent = reagent.reagents[1] end ---@cast reagent -CraftingReagentSlotSchematic
    if reagent.reagent then reagent = reagent.reagent end ---@cast reagent -CraftingReagentInfo | ProfessionTransactionAllocation
    return reagent.itemID
end

---@param item number | string
function Self:GetQualityIcon(item)
    local qualityInfo = C_TradeSkillUI.GetItemReagentQualityInfo(item)
    if qualityInfo then return CreateAtlasMarkup(qualityInfo.iconChat, 17, 15, 1, 0) end
end

---@param reagent Reagent
---@param characterInventoryOnly? boolean
function Self:GetQuantity(reagent, characterInventoryOnly)
    local itemID = self:GetItemID(reagent)
    return Util:TblGetHooked(ItemUtil, "GetCraftingReagentCount")(itemID, characterInventoryOnly)
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
    local itemID = self:GetItemID(reagent)

    if self:HasStatBonus(itemID, "SK") then
        return floor(self:GetStatBonus(itemID, "SK") * weightPerSkill)
    else
        return C.REAGENTS[itemID] or 0
    end
end

---@param order CraftingOrderInfo
function Self:GetOrderWeight(order)
    local orderWeight = 0
    for _,reagent in pairs(order.reagents) do
        orderWeight = orderWeight + reagent.reagentInfo.quantity * self:GetWeight(reagent.reagentInfo)
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
                tinsert(reagents, reagent.reagentInfo)
            end
        end
    end

    -- Get required skill with base and best materials
    local opBase = Recipes:GetOperationInfo(recipe, reagents, orderOrRecraftGUID)
    for i=1,#qualitySlots do reagents[i].reagent = qualitySlots[i].reagents[3] end
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
        reagent.reagents[itemIndex or 1],
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
                tinsert(infos, Professions.CreateCraftingReagentInfo(alloc.reagent, reagent.dataSlotIndex, alloc.quantity))
            end
        end
    end

    return infos
end

---@param recipe CraftingRecipeSchematic
---@param weight number
---@param isLowerBound? boolean
function Self:GetCraftingInfoForWeight(recipe, weight, isLowerBound)
    ---@type CraftingReagentInfo[]
    local reagents = {}

    local rest = weight
    local slots = Util(self:GetQualitySlots(recipe)):SortBy(Util:FnBind(self.GetWeight, self))()

    for i,reagent in ipairs_reverse(slots) do
        local w = self:GetWeight(reagent)
        local q1 = reagent.quantityRequired
        local q3 = min(q1, floor(rest / w / 2))
        q1, rest = q1 - q3, rest - q3 * w * 2
        local q2 = min(q1, floor(rest / w))
        q1, rest = q1 - q2, rest - q2 * w

        if isLowerBound and i == 1 and rest > 0 and q1 > 0 then
            q1, q2, rest = q1 - 1, q2 + 1, rest - w
        end

        self:AddCraftingInfos(reagents, reagent, q1, q2, q3)
    end

    return reagents, weight - rest
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
        reagent = Professions.CreateItemReagent(reagent)
    elseif reagent.dataSlotIndex then
        quantity = quantity or reagent.quantity
        reagent = reagent.reagent
    end ---@cast reagent CraftingReagent

    Allocations:WithoutOnChanged(allocations, "Allocate", reagent, quantity or 0)
end

---@param allocations ProfessionTransationAllocations
function Self:ClearAllocations(allocations)
    Allocations:WithoutOnChanged(allocations, "Clear")
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
    return self:IsFinishing(reagent) and Util:TblEvery(reagent.reagents, self.HasStatBonus, false, self, "SK")
end

---@param reagent CraftingReagentInfo | CraftingReagent | number
function Self:IsUntradableBonusSkill(reagent)
    return self:HasStatBonus(reagent, "SK") and not Prices:HasReagentPrice(reagent)
end

---@param reagent CraftingReagentSlotSchematic
---@param order? CraftingOrderInfo
---@param recraftMods? CraftingItemSlotModification[]
function Self:IsProvided(reagent, order, recraftMods)
    if not order then return false end
    if reagent.orderSource == Enum.CraftingOrderReagentSource.Customer then return order.orderID ~= nil end
    if reagent.orderSource == Enum.CraftingOrderReagentSource.Crafter then return order.orderID == nil end

    if Orders:IsCreatingProvided(order, reagent.slotIndex) then return true end
    if Util:TblSomeWhere(order.reagents, "slotIndex", reagent.slotIndex) then return true end

    if order.orderID and order.isRecraft and self:IsModified(reagent) then ---@cast recraftMods -?
        local slot = Util:TblWhere(recraftMods, "dataSlotIndex", reagent.dataSlotIndex)
        return slot and slot.reagent.itemID ~= 0
    end

    return false
end

---@param reagent CraftingReagentSlotSchematic
---@param order? CraftingOrderInfo
---@param recraftMods? CraftingItemSlotModification[]
---@return CraftingReagentInfo[] | CraftingItemSlotModification[]
function Self:GetProvided(reagent, order, recraftMods)
    if not order or Orders:IsCreating(order) then return Util.EMPTY end ---@todo
    if reagent.orderSource == Enum.CraftingOrderReagentSource.Customer and order.orderID == nil then return Util.EMPTY end
    if reagent.orderSource == Enum.CraftingOrderReagentSource.Crafter and order.orderID ~= nil then return Util.EMPTY end

    ---@type CraftingReagentInfo[] | CraftingItemSlotModification[]
    local list = Util(order.reagents):FilterWhere("slotIndex", reagent.slotIndex):Pick("reagentInfo")()

    if #list == 0 and order.orderID and order.isRecraft and self:IsModified(reagent) then ---@cast recraftMods -?
        local slot = Util:TblWhere(recraftMods, "dataSlotIndex", reagent.dataSlotIndex)
        if slot and slot.reagent.itemID ~= 0 then tinsert(list, slot) end
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
    local itemID = self:GetItemID(reagent)
    local stats = C.FINISHING_REAGENTS[itemID]
    local val = stats and stats[stat] or 0

    return stat == "SK" and val or val / 100
end

---@param reagent CraftingReagentInfo | CraftingReagent | number
---@param stat BonusStat
function Self:HasStatBonus(reagent, stat)
    return self:GetStatBonus(reagent, stat) > 0
end

function Self:GetMaxBonusSkill()
    local maxSkill = 0
    for itemID, stats in pairs(C.FINISHING_REAGENTS) do
        if (stats.SK or 0) > maxSkill and Prices:HasReagentPrice(itemID) then
            maxSkill = stats.SK
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

---@class Reagents.Event
---@field TrackedUpdated "TrackedUpdated"

Self:GenerateCallbackEvents({ "TrackedUpdated"  })
Self:OnLoad()

function Self:OnTrackedUpdated(...)
    self:TriggerEvent(self.Event.TrackedUpdated, ...)
end

function Self:OnTraitChanged()
    self.Cache.SkillBounds:Clear()
end

function Self:OnLoaded()
    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, self.OnTrackedUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedAmountUpdated, self.OnTrackedUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedAllocationUpdated, self.OnTrackedUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedQualityUpdated, self.OnTrackedUpdated, self)

    Orders:RegisterCallback(Orders.Event.TrackedUpdated, self.OnTrackedUpdated, self)
    Orders:RegisterCallback(Orders.Event.TrackedAmountUpdated, self.OnTrackedUpdated, self)
    Orders:RegisterCallback(Orders.Event.TrackedAllocationUpdated, self.OnTrackedUpdated, self)
    Orders:RegisterCallback(Orders.Event.CreatingReagentsUpdated, self.OnTrackedUpdated, self)

    Buffs:RegisterCallback(Buffs.Event.TraitChanged, self.OnTraitChanged, self)
end

Addon:RegisterCallback(Addon.Event.Loaded, Self.OnLoaded, Self)