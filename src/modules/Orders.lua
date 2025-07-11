---@class Addon
local Addon = select(2, ...)
local C, Recipes, Reagents, Util = Addon.Constants, Addon.Recipes, Addon.Reagents, Addon.Util

---@class Orders: CallbackRegistryMixin
---@field Event Orders.Event
local Self = Mixin(Addon.Orders, CallbackRegistryMixin)

---@type table<boolean, CraftingOrderInfo[][]>
Self.tracked = { [false] = {}, [true] = {} }
---@type number[]
Self.trackedAmounts = {}
---@type table<boolean, Operation[][]>
Self.trackedAllocations = { [false] = {}, [true] = {} }
---@type table<boolean, (true | number)[][]>
Self.creatingProvided = { [false] = {}, [true] = {} }

---------------------------------------
--              Tracking
---------------------------------------

function Self:HasTracked()
    return next(self.tracked[true]) ~= nil or next(self.tracked[false]) ~= nil
end

-- Get

---@param recipeOrOrder RecipeOrOrder
---@param isRecraft? boolean
function Self:IsTracked(recipeOrOrder, isRecraft)
    local orderID = type(recipeOrOrder) == "table" and recipeOrOrder.orderID or 0
    local trackedOrders = self:GetTracked(recipeOrOrder, isRecraft)

    return trackedOrders and trackedOrders[orderID] ~= nil or false
end

---@param recipeOrOrder RecipeOrOrder
---@param isRecraft? boolean
function Self:GetTracked(recipeOrOrder, isRecraft)
    local recipeID, isRecraft = Recipes:GetRecipeInfo(recipeOrOrder, isRecraft)

    return self.tracked[isRecraft][recipeID]
end

function Self:GetTrackedByOrderID(orderID)
    for order in self:Enumerate() do
        if order.orderID == orderID then return order end
    end
end

---@param recipeOrOrder RecipeOrOrder
---@param isRecraft? boolean
function Self:GetTrackedAmount(recipeOrOrder, isRecraft)
    local recipeID, isRecraft = Recipes:GetRecipeInfo(recipeOrOrder, isRecraft)

    local trackedOrders = self:GetTracked(recipeOrOrder, isRecraft)
    if not trackedOrders then return end

    local amount = Util:TblCount(trackedOrders)

    if isRecraft then return amount end

    return amount - 1 + (Self.trackedAmounts[recipeID] or 1)
end

---@param recipeOrOrder RecipeOrOrder
---@param isRecraft? boolean
---@return Operation?
function Self:GetTrackedAllocation(recipeOrOrder, isRecraft)
    local recipeID, isRecraft = Recipes:GetRecipeInfo(recipeOrOrder, isRecraft)

    if not self.trackedAllocations[isRecraft][recipeID] then return end

    return self.trackedAllocations[isRecraft][recipeID][recipeOrOrder.orderID or 0]
end

function Self:GetTrackedReagentAmounts()
    ---@type number[]
    local reagents, provided = {}, {}

    for order in self:Enumerate() do repeat
        local amount = self:IsCreating(order) and self:GetTrackedAmount(order) or 1
        if amount <= 0 then break end

        local recipe = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft)
        local operation = self:GetTrackedAllocation(order)
        local recraftMods = Reagents:GetRecraftMods(order)

        -- Provided by customer
        if not self:IsCreating(order) then
            for _,reagent in pairs(order.reagents) do
                local itemID, quantity = reagent.reagent.itemID, reagent.reagent.quantity
                provided[itemID] = (provided[itemID] or 0) + quantity
            end
        end

        for slotIndex,reagent in pairs(recipe.reagentSlotSchematics) do repeat
            if reagent.reagentType == Enum.CraftingReagentType.Automatic then break end

            local required = reagent.required and reagent.quantityRequired or 0
            local missing = amount * required

            if self:IsCreatingProvided(order, slotIndex) then
                -- Provided by crafter
                local itemID = self.creatingProvided[order.isRecraft][order.spellID][slotIndex]
                if type(itemID) ~= "number" then itemID = reagent.reagents[1].itemID --[[@cast itemID -?]] end
                provided[itemID] = (provided[itemID] or 0) + missing
            elseif Reagents:IsProvided(reagent, order, recraftMods) then
                -- Provided by customer: Already accounted for
            else
                -- Allocated
                if operation and operation.allocation[slotIndex] then
                    for _, alloc in operation.allocation[slotIndex]:Enumerate() do
                        missing = max(0, missing - amount * alloc.quantity)

                        local itemID = alloc.reagent.itemID ---@cast itemID -?
                        reagents[itemID] = (reagents[itemID] or 0) + amount * alloc.quantity
                    end
                end

                if missing > 0 then
                    local itemID = reagent.reagents[1].itemID ---@cast itemID -?
                    reagents[itemID] = (reagents[itemID] or 0) + missing
                end
            end
        until true end
    until true end

    return reagents, provided
end

function Self:GetTrackedResultAmounts()
    ---@type number[]
    local items = {}

    for order in self:Enumerate() do repeat
        if not self:IsCreating(order) then break end

        local amount = self:GetTrackedAmount(order)
        if amount <= 0 then break end

        local output = C_TradeSkillUI.GetRecipeOutputItemData(order.spellID, nil, nil, order.minQuality)
        if not output or not output.itemID then break end

        items[output.itemID] = (items[output.itemID] or 0) + amount
    until true end

    return items
end

---@param professionInfo? ProfessionInfo
---@return number
function Self:GetTrackedConcentrationCost(professionInfo)
    local cost = 0

    for order in self:Enumerate() do repeat
        if self:IsCreating(order) then break end

        local amount = self:GetTrackedAmount(order)
        if amount <= 0 then break end

        local op = self:GetTrackedAllocation(order)
        if not op or not op.applyConcentration then break end

        if professionInfo and professionInfo.professionID ~= op.professionInfo.professionID then break end

        cost = cost + amount * op:GetConcentrationCost()
    until true end

    return cost
end

-- Set

---@param order CraftingOrderInfo
---@param value? boolean
function Self:SetTracked(order, value)
    value = value ~= false

    if value == self:IsTracked(order) then return end

    local recipeID, isRecraft = Recipes:GetRecipeInfo(order)
    local orderID = order.orderID or 0
    local recipes = self.tracked[isRecraft]

    if value and not recipes[recipeID] then recipes[recipeID] = {} end

    recipes[recipeID][orderID] = value and order or nil

    if not value then
        if not next(recipes[recipeID]) then
            recipes[recipeID] = nil
            if Recipes:GetTrackedAmount(order) == 0 then
                Recipes:SetTracked(order, false)
            end
        end

        self:SetTrackedAllocation(order, nil)
        if self:IsCreating(order) then self:SetTrackedAmount(order, nil) end
    elseif not Recipes:IsTracked(order) then
        Recipes:SetTracked(order, true)
        Recipes:SetTrackedAmount(order, 0)
    end

    self:TriggerEvent(self.Event.TrackedUpdated, order, value)

    self:UpdateCreatingReagents()
end

---@param recipeOrOrder RecipeOrOrder
---@param amount? number
function Self:SetTrackedAmount(recipeOrOrder, amount)
    if amount and amount < 0 then amount = 0 end
    if amount == 1 then amount = nil end

    local recipeID = Recipes:GetRecipeInfo(recipeOrOrder)
    if self.trackedAmounts[recipeID] == amount then return end

    self.trackedAmounts[recipeID] = amount

    self:TriggerEvent(Self.Event.TrackedAmountUpdated, recipeID, amount)
end

---@param recipeOrOrder RecipeOrOrder
---@param operation? Operation
---@param isRecraft? boolean
function Self:SetTrackedAllocation(recipeOrOrder, operation, isRecraft)
    local recipeID, isRecraft = Recipes:GetRecipeInfo(recipeOrOrder, isRecraft)
    local orderID = type(recipeOrOrder) == "table" and recipeOrOrder.orderID or 0

    if not self.trackedAllocations[isRecraft][recipeID] then
        if not operation then return end
        self.trackedAllocations[isRecraft][recipeID] = {}
    end

    self.trackedAllocations[isRecraft][recipeID][orderID] = operation

    if not operation and not next(self.trackedAllocations[isRecraft][recipeID]) then
        self.trackedAllocations[isRecraft][recipeID] = nil
    end

    self:TriggerEvent(Self.Event.TrackedAllocationUpdated, recipeID, isRecraft, orderID, operation)
end

---------------------------------------
--             Creating
---------------------------------------

---@param order? CraftingOrderInfo
function Self:IsCreating(order)
    return order and not order.orderID
end

---@param slot ReagentSlot
function Self:IsCreatingSlotProvided(slot)
    if slot:GetReagentType() == Enum.CraftingReagentType.Modifying then
        return slot:GetTransaction():GetRecipeSchematic().isRecraft and slot:IsOriginalItemSet()
    else
        return slot.Checkbox:IsShown() and not slot.Checkbox:GetChecked()
    end
end

---@param order? CraftingOrderInfo
---@param slotIndex number
function Self:IsCreatingProvided(order, slotIndex)
    if not self:IsCreating(order) then return false end ---@cast order -?

    local slots = Self.creatingProvided[order.isRecraft][order.spellID]
    if slots then return slots[slotIndex] and true or false end

    local frame = ProfessionsCustomerOrdersFrame
    if not frame or frame.Form.order ~= order then return false end

    local recipe = frame.Form.transaction:GetRecipeSchematic()
    if not recipe or recipe.recipeID ~= order.spellID or recipe.isRecraft ~= order.isRecraft then return false end

    for slot in frame.Form.reagentSlotPool:EnumerateActive() do
        if slot:GetSlotIndex() == slotIndex then
            return self:IsCreatingSlotProvided(slot)
        end
    end

    return false
end

---@param slot ReagentSlot
---@param silent? boolean
function Self:UpdateCreatingReagent(slot, silent)
    local tx, reagent = slot:GetTransaction(), slot:GetReagentSlotSchematic()
    local recipe = tx:GetRecipeSchematic()
    local provided = self:IsCreatingSlotProvided(slot)
    local itemID = provided and slot.item and slot.item:GetItemID()
    local recipes = Self.creatingProvided[recipe.isRecraft]

    if not recipes[recipe.recipeID] then
        if not provided then return end
        recipes[recipe.recipeID] = {}
    end

    recipes[recipe.recipeID][reagent.slotIndex] = itemID or provided or nil

    if not next(recipes[recipe.recipeID]) then recipes[recipe.recipeID] = nil end

    if silent then return end

    self:TriggerEvent(self.Event.CreatingReagentsUpdated, reagent.slotIndex)
end

function Self:UpdateCreatingReagents()
    if not ProfessionsCustomerOrdersFrame then return end

    local form = ProfessionsCustomerOrdersFrame.Form
    local order = form.order
    local tracked = order and self:IsTracked(order)

    if tracked then
        for slot in form.reagentSlotPool:EnumerateActive() do
            self:UpdateCreatingReagent(slot, true)
        end
    elseif order and Self.creatingProvided[order.isRecraft][order.spellID] then
        Self.creatingProvided[order.isRecraft][order.spellID] = nil
    end

    self:TriggerEvent(self.Event.CreatingReagentsUpdated)
end

---------------------------------------
--               Util
---------------------------------------

---@return fun(): CraftingOrderInfo?
function Self:Enumerate()
    return Util:TblEnum(self.tracked, 3)
end

---@param order CraftingOrderInfo
function Self:IsClaimable(order)
    return order.orderID and order.orderState == Enum.CraftingOrderState.Created and order.customerGuid ~= UnitGUID("player")
end

---@param order CraftingOrderInfo
function Self:GetNumNpcRewards(order)
    if order.orderType ~= Enum.CraftingOrderType.Npc then return 0, 0, 0 end

    local knowledge, currency, payout = 0, 0, 0
    for _,reward in pairs(order.npcOrderRewards) do
        local itemID = C_Item.GetItemInfoInstant(reward.itemLink)
        knowledge = knowledge + (C.KNOWLEDGE_POINTS[itemID] or 0) * reward.count
        currency = currency + (C.ARTISAN_CURRENCY[itemID] and 1 or 0) * reward.count
        payout = payout + (C.ARTISAN_PAYOUT[itemID] and 1 or 0) * reward.count
    end
    return knowledge, currency, payout
end

---@param a? CraftingOrderInfo
---@param b? CraftingOrderInfo
function Self:IsEqual(a, b)
    if a == b then return true end
    if (a == nil) ~= (b == nil) then return false end --[[@cast a -?]] --[[@cast b - ?]]
    return a.orderID == b.orderID and a.orderState == b.orderState and a.isFulfillable == b.isFulfillable
end

---------------------------------------
--              Events
---------------------------------------

---@class Orders.Event
---@field TrackedUpdated "TrackedUpdated"
---@field TrackedAmountUpdated "TrackedAmountUpdated"
---@field TrackedAllocationUpdated "TrackedAllocationUpdated"
---@field CreatingReagentsUpdated "CreatingReagentsUpdated"

Self:GenerateCallbackEvents({ "TrackedUpdated", "TrackedAmountUpdated", "TrackedAllocationUpdated", "CreatingReagentsUpdated" })
Self:OnLoad()

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    if tracked then return end

    for order in self:Enumerate() do
        if order.spellID == recipeID and not Recipes:IsTracked(order) then
            self:SetTracked(order, false)
        end
    end
end

---@param result Enum.CraftingOrderResult
---@param orderID number
function Self:OnClaimedFulfilled(result, orderID)
    local R = Enum.CraftingOrderResult
    if not Util:OneOf(result, R.Ok, R.Expired) then return end

    local order = self:GetTrackedByOrderID(orderID)
    if not order then return end

    self:SetTracked(order, false)
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_FULFILL_ORDER_RESPONSE", Self.OnClaimedFulfilled, Self)