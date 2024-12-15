---@class Addon
local Addon = select(2, ...)
local GUI, Optimization, Orders, Recipes, Util = Addon.GUI, Addon.Optimization, Addon.Orders, Addon.Recipes, Addon.Util
local NS = GUI.RecipeForm

local Parent = NS.RecipeForm

---@class GUI.RecipeForm.WithOrder: GUI.RecipeForm.RecipeForm
---@field trackOrderBox CheckButton
---@field GetTrackRecipeCheckbox fun(self: self): CheckButton
local Self = NS.WithOrder

-- Track order checkbox

---@param frame CheckButton
function Self:TrackOrderBoxOnClick(frame)
    local order, value = self:GetOrder(), frame:GetChecked()
    if not order then return end

    Orders:SetTracked(order, value)
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
    if order and Orders:IsClaimable(order) then
        return floor(order.minQuality)
    end

    return Parent.GetQuality(self)
end

-- Tracking service

function Self:GetTracking()
    return Orders, self:GetOrder()
end

function Self:UpdateTracking()
    local order = self:GetOrder()
    if not order or not Orders:IsTracked(order) then return end

    Orders:SetTrackedAllocation(order, self:GetOperation())
end

---------------------------------------
--              Events
---------------------------------------

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdated(recipeID, tracked)
    if not self.form:IsVisible() then return end

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

    if not tracked then return end

    self:UpdateTracking()
end

function Self:OnTrackRecipeCheckboxClicked()
    local recipe, order = self:GetRecipe(), self:GetOrder()
    if not recipe or not order or not self:GetTrackRecipeCheckbox():GetChecked() then return end

    Orders:SetTracked(order)

    Recipes:SetTrackedAmount(recipe, 0)
end

function Self:OnAddonLoaded()
    self:GetTrackRecipeCheckbox():HookScript("OnClick", Util:FnBind(self.OnTrackRecipeCheckboxClicked, self))

    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, self.OnTrackedRecipeUpdated, self)
    Orders:RegisterCallback(Orders.Event.TrackedUpdated, self.OnTrackedOrderUpdated, self)
end