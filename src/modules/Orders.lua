---@class Addon
local Addon = select(2, ...)
local Recipes, Util = Addon.Recipes, Addon.Util

---@class Orders: CallbackRegistryMixin
---@field Event Orders.Event
local Self = Mixin(Addon.Orders, CallbackRegistryMixin)

---@type table<boolean, CraftingOrderInfo[]>
Self.tracked = { [false] = {}, [true] = {} }
---@type number[]
Self.creatingProvidedReagents = {}

---------------------------------------
--              Tracking
---------------------------------------

-- Get

---@param order CraftingOrderInfo
function Self:IsTracked(order)
    local trackedOrder = self:GetTracked(order)
    if not trackedOrder or not Recipes:IsTracked(order) then return false end
    return trackedOrder.orderID == order.orderID
end

---@param recipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number
function Self:GetTracked(recipeOrOrder)
    local recipeID, isRecraft = Recipes:GetRecipeInfo(recipeOrOrder)
    return self.tracked[isRecraft][recipeID]
end

function Self:GetTrackedProvidedReagentAmounts()
    ---@type number[]
    local reagents = {}
    for _,orders in pairs(self.tracked) do
        for _,order in pairs(orders) do
            if self:IsCreating(order) then
                local amount = Recipes:GetTrackedAmount(order) or 1
                if amount > 0 then
                    for itemID,quantity in pairs(self.creatingProvidedReagents) do
                        reagents[itemID] = (reagents[itemID] or 0) + quantity * amount
                    end
                end
            else
                for _,reagent in pairs(order.reagents) do
                    local itemID, quantity = reagent.reagent.itemID, reagent.reagent.quantity
                    reagents[itemID] = (reagents[itemID] or 0) + quantity
                end
            end
        end
    end
    return reagents
end

-- Set

---@param order CraftingOrderInfo
---@param value? boolean
function Self:SetTracked(order, value)
    value = value ~= false

    if value and self:IsTracked(order) then return end
    if not value and not self:GetTracked(order) then return end

    local recipeID, isRecraft = Recipes:GetRecipeInfo(order)
    self.tracked[isRecraft][recipeID] = value and order or nil

    if value then Recipes:SetTracked(order, true) end

    self:TriggerEvent(self.Event.TrackedUpdated, order, value)

    self:UpdateCreatingReagents()
end

-- Clear

---@param orderID number
function Self:ClearTrackedByOrderID(orderID)
    for _,orders in pairs(self.tracked) do
        for _,order in pairs(orders) do
            if order.orderID == orderID then self:SetTracked(order, false) end
        end
    end
end

---@param recipeID number
function Self:ClearTrackedByRecipeID(recipeID)
    for _,orders in pairs(self.tracked) do
        if orders[recipeID] then self:SetTracked(orders[recipeID], false) break end
    end
end

---------------------------------------
--             Creating
---------------------------------------

---@param order? CraftingOrderInfo
function Self:IsCreating(order)
    return order and not order.orderID
end

function Self:GetCreating()
    for _,orders in pairs(self.tracked) do
        local order = Util:TblWhere(orders, "orderID", nil)
        if order then return order end
    end
end

---@param slot ReagentSlot
---@param silent? boolean
function Self:UpdateCreatingReagent(slot, silent)
    local reagent = slot:GetReagentSlotSchematic()
    local itemID = reagent.reagents[1].itemID ---@cast itemID -?
    local provided = slot.Checkbox:IsShown() and not slot.Checkbox:GetChecked()
    local required = reagent.required and reagent.quantityRequired

    self.creatingProvidedReagents[itemID] = provided and required or nil

    if silent then return end

    self:TriggerEvent(self.Event.CreatingReagentsUpdated)
end

function Self:UpdateCreatingReagents()
    if not ProfessionsCustomerOrdersFrame then return end

    wipe(self.creatingProvidedReagents)

    local form = ProfessionsCustomerOrdersFrame.Form
    local recipe = form.transaction:GetRecipeSchematic()
    local tracked = recipe and self:GetTracked(form.order) == form.order

    if recipe and tracked then
        for slot in form.reagentSlotPool:EnumerateActive() do
            self:UpdateCreatingReagent(slot, true)
        end
    end

    self:TriggerEvent(self.Event.CreatingReagentsUpdated)
end

---------------------------------------
--              Util
---------------------------------------

---@param order CraftingOrderInfo | number
---@return number, boolean
function Self:GetOrderInfo(order)
    local orderID = type(order) == "number" and order or order.orderID
    local isRecraft = type(order) == "table" and order.isRecraft or false
    return orderID, isRecraft
end

---------------------------------------
--              Events
---------------------------------------

---@class Orders.Event
---@field TrackedUpdated "TrackedUpdated"
---@field CreatingReagentsUpdated "CreatingReagentsUpdated"

Self:GenerateCallbackEvents({ "TrackedUpdated", "CreatingReagentsUpdated" })
Self:OnLoad()

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    if tracked then return end

    self:ClearTrackedByRecipeID(recipeID)
end

---@param result Enum.CraftingOrderResult
---@param orderID number
function Self:OnClaimedFulfilled(result, orderID)
    local R = Enum.CraftingOrderResult
    if not Util:OneOf(result, R.Ok, R.Expired) then return end

    self:ClearTrackedByOrderID(orderID)
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_FULFILL_ORDER_RESPONSE", Self.OnClaimedFulfilled, Self)