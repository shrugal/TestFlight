---@class Addon
local Addon = select(2, ...)
local GUI, Optimization, Orders, Recipes, Util = Addon.GUI, Addon.Optimization, Addon.Orders, Addon.Recipes, Addon.Util

local NS = GUI.RecipeForm
local Parent = NS.RecipeForm

---@class GUI.RecipeForm.OrderForm: GUI.RecipeForm.RecipeForm
---@field trackOrderBox CheckButton
local Self = NS.OrderForm

-- Track order checkbox

---@param frame CheckButton
function Self:TrackOrderBoxOnClick(frame)
    local order, value = self:GetOrder(), frame:GetChecked()
    if not order then return end

    Orders:SetTracked(order, value)

    if not value then return end

    Recipes:SetTrackedByForm(self)
end

---@return CheckButton
function Self:InsertTrackOrderBox(...)
    local input = GUI:InsertCheckbox(self.form, nil, Util:FnBind(self.TrackOrderBoxOnClick, self), ...)

    input:SetSize(26, 26)
    input.text:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode("Track Order"))
    input:Hide()

    self.trackOrderBox = input

    return input
end

function Self:UpdateTrackOrderBox()
    local order = self:GetOrder()

    self.trackOrderBox:SetShown(order and Recipes:IsTracked(order))
    self.trackOrderBox:SetChecked(order and Orders:IsTracked(order))
end

---------------------------------------
--              Util
---------------------------------------

function Self:GetQuality()
    local order = self:GetOrder()
    if order and self:IsClaimableOrder(order) then
        return floor(order.minQuality)
    end

    return Parent.GetQuality(self)
end

function Self:GetAllocation()
    local form, order = self.form, self:GetOrder()

    if form["GetRecipeOperationInfo"] and order and self:IsClaimableOrder(order) then ---@cast form RecipeCraftingForm
        local tx = form.transaction
        local recipe = tx:GetRecipeSchematic()
        local optionalReagents = tx:CreateOptionalOrFinishingCraftingReagentInfoTbl()
        local allocations = Optimization:GetRecipeAllocations(recipe, optionalReagents, order)
        local quality = tx:IsApplyingConcentration() and order.minQuality - 1 or order.minQuality

        local allocation = allocations and allocations[math.max(quality, Util:TblMinKey(allocations))]
        if allocation then return allocation end
    end

    return Parent.GetAllocation(self)
end

---@param order CraftingOrderInfo
function Self:IsClaimableOrder(order)
    return order.orderID and order.orderState == Enum.CraftingOrderState.Created
end

---------------------------------------
--              Events
---------------------------------------

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdated(recipeID, tracked)
    if not self.form:IsShown() then return end

    local order = self:GetOrder()
    if not order or order.spellID ~= recipeID then return end

    self.trackOrderBox:SetShown(tracked)
end

---@param updatedOrder CraftingOrderInfo
---@param tracked boolean
function Self:OnTrackedOrderUpdated(updatedOrder, tracked)
    local order = self:GetOrder()
    if not order or order.orderID ~= updatedOrder.orderID then return end

    self.trackOrderBox:SetChecked(tracked)
end

function Self:OnAddonLoaded()
    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, self.OnTrackedRecipeUpdated, self)
    Orders:RegisterCallback(Orders.Event.TrackedUpdated, self.OnTrackedOrderUpdated, self)
end