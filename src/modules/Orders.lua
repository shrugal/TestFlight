---@type string
local Name = ...
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
    return Self.tracked[recipeOrOrder.isRecraft or false][recipeOrOrder.recipeID or recipeOrOrder.spellID]
end

---@param order CraftingOrderInfo
function Self:SetTracked(order)
    Self.tracked[order.isRecraft or false][order.spellID] = order

    Self:UpdateCreatingReagents()
    GUI:UpdateObjectiveTrackers(true)
end

---@param form OrdersForm | CustomerOrderForm
function Self:SetTrackedByForm(form)
    local recipe = form.transaction:GetRecipeSchematic()
    if not recipe then return end

    if not Recipes:IsTracked(recipe) then
        Self:ClearTracked(recipe)
    elseif form.order then
        Self:SetTracked(form.order)
    end
end

---@param recipeOrOrder CraftingRecipeSchematic | CraftingOrderInfo
function Self:ClearTracked(recipeOrOrder)
    Self.tracked[recipeOrOrder.isRecraft or false][recipeOrOrder.recipeID or recipeOrOrder.spellID] = nil

    Self:UpdateCreatingReagents()
    GUI:UpdateObjectiveTrackers(true)
end

---@param orderID number
function Self:ClearTrackedByOrderID(orderID)
    for _,orders in pairs(Self.tracked) do
        local order = Util:TblWhere(orders, "orderID", orderID)
        if order then Self:ClearTracked(order) break end
    end
end

---@param recipeID number
function Self:ClearTrackedByRecipeID(recipeID)
    for _,orders in pairs(Self.tracked) do
        local order = orders[recipeID]
        if order then Self:ClearTracked(order) end
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
    for _,orders in pairs(Self.tracked) do
        local order = Util:TblWhere(orders, "orderID", nil)
        if order then return order end
    end
end

---@param reagent CraftingReagentSlotSchematic
---@param provided boolean
function Self:UpdateCreatingReagent(reagent, provided)
    local itemID = reagent.reagents[1].itemID ---@cast itemID -?

    Self.creatingProvidedReagents[itemID] = provided and reagent.required and reagent.quantityRequired or nil

    GUI:UpdateObjectiveTrackers(true)
end

---@param hook? boolean
function Self:UpdateCreatingReagents(hook)
    if not ProfessionsCustomerOrdersFrame then return end

    wipe(Self.creatingProvidedReagents)

    local form = ProfessionsCustomerOrdersFrame.Form
    local recipe = form.transaction:GetRecipeSchematic()
    local tracked = recipe and Self:GetTracked(recipe) == form.order

    if recipe and (tracked or hook) then
        for slot in form.reagentSlotPool:EnumerateActive() do
            local reagent = slot:GetReagentSlotSchematic()

            if tracked then
                Self:UpdateCreatingReagent(reagent, not slot.Checkbox:GetChecked())
            end

            if hook then
                local origCb = slot.Checkbox:GetScript("OnClick")
                slot:SetCheckboxCallback(function (checked)
                    origCb(checked)

                    local tracked = Self:GetTracked(recipe) == form.order
                    if tracked then
                        Self:UpdateCreatingReagent(reagent, not slot.Checkbox:GetChecked())
                    end
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
        ordersForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, Self.SetTrackedByForm, Self, ordersForm)
    end

    if Util:IsAddonLoadingOrLoaded("Blizzard_ProfessionsCustomerOrders", addonName) then
        -- ProfessionsCustomerOrdersFrame

        local customerOrderForm = ProfessionsCustomerOrdersFrame.Form

        hooksecurefunc(customerOrderForm, "UpdateListOrderButton", function (self) Self:SetTrackedByForm(self) end)
        hooksecurefunc(customerOrderForm, "UpdateReagentSlots", function () Self:UpdateCreatingReagents(true) end)
    end
end

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    local order = GUI:GetFormOrder()
    if not tracked then
        Self:ClearTrackedByRecipeID(recipeID)
    elseif order and order.spellID == recipeID then
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

    Self:ClearTrackedByOrderID(Self.claimed)
    Self.claimed = nil
end

---@param result Enum.CraftingOrderResult
---@param orderID number
function Self:OnClaimedFulfilled(result, orderID)
    local R = Enum.CraftingOrderResult
    if not Util:OneOf(result, R.Ok, R.Expired) then return end

    Self:ClearTrackedByOrderID(orderID)
    Self.claimed = nil
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_CLAIMED_ORDER_UPDATED", Self.OnClaimedAdded, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_CLAIMED_ORDER_REMOVED", Self.OnClaimedRemoved, Self)
EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_FULFILL_ORDER_RESPONSE", Self.OnClaimedFulfilled, Self)