---@class TestFlight
local Addon = select(2, ...)
local GUI, Recipes, Util = Addon.GUI, Addon.Recipes, Addon.Util

---@class Orders
local Self = Addon.Orders

---@type table<boolean, CraftingOrderInfo[]>
Self.tracked = { [false] = {}, [true] = {} }
---@type number?
Self.claimed = nil
---@type number[]
Self.creatingProvidedReagents = {}

---------------------------------------
--              Tracking
---------------------------------------

---@param recipeOrOrder CraftingRecipeSchematic | CraftingOrderInfo
function Self:GetTracked(recipeOrOrder)
    return self.tracked[recipeOrOrder.isRecraft or false][recipeOrOrder.recipeID or recipeOrOrder.spellID]
end

---@param order CraftingOrderInfo
function Self:SetTracked(order)
    self.tracked[order.isRecraft or false][order.spellID] = order

    self:UpdateCreatingReagents()
    GUI:UpdateObjectiveTrackers(true)
end

---@param form OrdersForm | CustomerOrderForm
function Self:SetTrackedByForm(form)
    local recipe = form.transaction:GetRecipeSchematic()
    if not recipe then return end

    if not Recipes:IsTracked(recipe) then
        self:ClearTracked(recipe)
    elseif form.order then
        self:SetTracked(form.order)
    end
end

---@param recipeOrOrder CraftingRecipeSchematic | CraftingOrderInfo
function Self:ClearTracked(recipeOrOrder)
    self.tracked[recipeOrOrder.isRecraft or false][recipeOrOrder.recipeID or recipeOrOrder.spellID] = nil

    self:UpdateCreatingReagents()
    GUI:UpdateObjectiveTrackers(true)
end

---@param orderID number
function Self:ClearTrackedByOrderID(orderID)
    for _,orders in pairs(self.tracked) do
        local order = Util:TblWhere(orders, "orderID", orderID)
        if order then self:ClearTracked(order) break end
    end
end

---@param recipeID number
function Self:ClearTrackedByRecipeID(recipeID)
    for _,orders in pairs(self.tracked) do
        local order = orders[recipeID]
        if order then self:ClearTracked(order) end
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
function Self:UpdateCreatingReagent(slot)
    local reagent = slot:GetReagentSlotSchematic()
    local itemID = reagent.reagents[1].itemID ---@cast itemID -?
    local provided = slot.Checkbox:IsShown() and not slot.Checkbox:GetChecked()
    local required = reagent.required and reagent.quantityRequired

    self.creatingProvidedReagents[itemID] = provided and required or nil

    GUI:UpdateObjectiveTrackers(true)
end

---@param hook? boolean
function Self:UpdateCreatingReagents(hook)
    if not ProfessionsCustomerOrdersFrame then return end

    wipe(self.creatingProvidedReagents)

    local form = ProfessionsCustomerOrdersFrame.Form
    local recipe = form.transaction:GetRecipeSchematic()
    local tracked = recipe and self:GetTracked(recipe) == form.order

    if recipe and (tracked or hook) then
        for slot in form.reagentSlotPool:EnumerateActive() do
            if tracked then self:UpdateCreatingReagent(slot) end

            if hook then
                local origCb = slot.Checkbox:GetScript("OnClick")
                slot:SetCheckboxCallback(function (checked)
                    origCb(checked)

                    local tracked = self:GetTracked(recipe) == form.order
                    if tracked then self:UpdateCreatingReagent(slot) end
                end)
            end
        end
    end

    GUI:UpdateObjectiveTrackers(true)
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then
        -- ProfessionsFrame.OrdersPage

        local ordersForm = ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm
        ordersForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, self.SetTrackedByForm, self, ordersForm)
    end

    if Util:IsAddonLoadingOrLoaded("Blizzard_ProfessionsCustomerOrders", addonName) then
        -- ProfessionsCustomerOrdersFrame

        local customerOrderForm = ProfessionsCustomerOrdersFrame.Form

        hooksecurefunc(customerOrderForm, "UpdateListOrderButton", Util:FnBind(self.SetTrackedByForm, self))
        hooksecurefunc(customerOrderForm, "UpdateReagentSlots", function () self:UpdateCreatingReagents(true) end)
    end
end

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    local order = GUI:GetFormOrder()
    if not tracked then
        self:ClearTrackedByRecipeID(recipeID)
    elseif order and order.spellID == recipeID then
        self:SetTracked(order)
    end
end

---@param orderID number
function Self:OnClaimedAdded(orderID)
    self.claimed = orderID

    local order = C_CraftingOrders.GetClaimedOrder()
    if not order or not C_TradeSkillUI.IsRecipeTracked(order.spellID, order.isRecraft) then return end

    self:SetTracked(order)
end

function Self:OnClaimedRemoved()
    if not self.claimed then return end

    self:ClearTrackedByOrderID(self.claimed)
    self.claimed = nil
end

---@param result Enum.CraftingOrderResult
---@param orderID number
function Self:OnClaimedFulfilled(result, orderID)
    local R = Enum.CraftingOrderResult
    if not Util:OneOf(result, R.Ok, R.Expired) then return end

    self:ClearTrackedByOrderID(orderID)
    self.claimed = nil
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_CLAIMED_ORDER_UPDATED", Self.OnClaimedAdded, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_CLAIMED_ORDER_REMOVED", Self.OnClaimedRemoved, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_FULFILL_ORDER_RESPONSE", Self.OnClaimedFulfilled, Self)