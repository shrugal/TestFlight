---@class Addon
local Addon = select(2, ...)
local GUI, Optimization, Util = Addon.GUI, Addon.Optimization, Addon.Util
local NS = GUI.RecipeForm

---@type GUI.RecipeForm.RecipeForm | GUI.RecipeForm.WithCrafting | GUI.RecipeForm.WithOrder
local Parent = Util:TblCombineMixins(NS.RecipeForm, NS.WithCrafting, NS.WithOrder)

---@class GUI.RecipeForm.OrdersForm: GUI.RecipeForm.RecipeForm, GUI.RecipeForm.WithCrafting, GUI.RecipeForm.WithOrder
local Self = Mixin(NS.OrdersForm, Parent)

function Self:UpdateAuraSlots()
    Parent.UpdateAuraSlots(self)

    if not self.form.OptionalReagents:IsShown() then return end

    self.auraSlotContainer:SetPoint("TOPLEFT", self.form.Reagents, "BOTTOMLEFT", 215, -20)
end

---------------------------------------
--              Hooks
---------------------------------------

---@param _ RecipeCraftingForm
---@param recipeInfo TradeSkillRecipeInfo
function Self:Init(_, recipeInfo)
    Parent.Init(self, _, recipeInfo)

    self:UpdateTrackOrderBox()
end

---------------------------------------
--              Util
---------------------------------------

function Self:GetOrder()
    local order = self.container.frame and self.container.frame.order

    -- Fulfillable state is sometimes not updated correctly
    if order and order.orderState == Enum.CraftingOrderState.Claimed and not order.isFulfillable then
        local claimed = C_CraftingOrders.GetClaimedOrder()
        if claimed and claimed.isFulfillable then order = claimed end
    end

    return order
end

function Self:GetQuality()
    local quality = NS.WithCrafting.GetQuality(self)
    if not quality then return end

    return Parent.GetQuality(self) or quality
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    local ordersView = ProfessionsFrame.OrdersPage.OrderView

    self.container = GUI.RecipeFormContainer.OrdersView
    self.form = ordersView.OrderDetails.SchematicForm

    Parent.OnAddonLoaded(self)

    -- Elements

    -- Insert track order spinner
    self:InsertTrackOrderBox(
        "TOPLEFT", self.form.TrackRecipeCheckbox, "BOTTOMLEFT", 0, 0
    )

    -- Insert optimization buttons
    self:InsertOptimizationButtons(
        ordersView,
        "TOPLEFT", ordersView.OrderDetails, "BOTTOMLEFT", 0, -4
    )
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)