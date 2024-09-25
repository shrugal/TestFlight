---@type string
local Name = ...
---@class TestFlight
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

---@class Orders
local Self = Addon.Orders

---@type number?
Self.claimed = nil
---@type CraftingOrderInfo[]
Self.tracked = {}

---@param recipe CraftingRecipeSchematic
function Self:GetTracked(recipe)
    return Util:TblWhere(Self.tracked, "spellID", recipe.recipeID, "isRecraft", recipe.isRecraft)
end

---@param order CraftingOrderInfo
function Self:SetTracked(order)
    Self.tracked[order.orderID] = order

    GUI:UpdateObjectiveTrackers(true)
end

---@param order CraftingOrderInfo | number
function Self:ClearTracked(order)
    Self.tracked[type(order) == "number" and order or order.orderID] = nil

    GUI:UpdateObjectiveTrackers(true)
end

---@param recipeID number
function Self:CheckUnsetTracked(recipeID)
    for _,order in pairs(Self.tracked) do
        if order.spellID == recipeID and not C_TradeSkillUI.IsRecipeTracked(recipeID, order.isRecraft) then
            Self:ClearTracked(order)
        end
    end
end

---------------------------------------
--              Events
---------------------------------------

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    local order = GUI:GetFormOrder()
    if not tracked then
        Self:CheckUnsetTracked(recipeID)
    elseif order then
        Self:SetTracked(order)
    end
end

---@param orderID number
function Self:OnClaimedAdded(orderID)
    Self.claimed = orderID

    local order = C_CraftingOrders.GetClaimedOrder()
    if not order or not C_TradeSkillUI.IsRecipeTracked(order.spellID, order.isRecraft) then return end

    Self:SetTracked(order)
end

function Self:OnClaimedRemoved()
    if not Self.claimed then return end

    Self:ClearTracked(Self.claimed)
    Self.claimed = nil
end

---@param result Enum.CraftingOrderResult
---@param orderID number
function Self:OnClaimedFulfilled(result, orderID)
    local R = Enum.CraftingOrderResult
    if not Util:OneOf(result, R.Ok, R.Expired) then return end

    Self:ClearTracked(orderID)
    Self.claimed = nil
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_CLAIMED_ORDER_UPDATED", Self.OnClaimedAdded, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_CLAIMED_ORDER_REMOVED", Self.OnClaimedRemoved, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_FULFILL_ORDER_RESPONSE", Self.OnClaimedFulfilled, Self)