---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util
local NS = GUI.RecipeForm

---@type GUI.RecipeForm.RecipeForm | GUI.RecipeForm.WithCrafting | GUI.RecipeForm.WithAmount
local Parent = Util:TblCombineMixins(NS.RecipeForm, NS.WithCrafting, NS.WithOrder)

---@class GUI.RecipeForm.OrdersForm: GUI.RecipeForm.RecipeForm, GUI.RecipeForm.WithCrafting, GUI.RecipeForm.WithOrder
local Self = Mixin(NS.OrdersForm, Parent)

---------------------------------------
--              Hooks
---------------------------------------

---@param _ RecipeCraftingForm
---@param recipe CraftingRecipeSchematic
function Self:Init(_, recipe)
    Parent.Init(self, _, recipe)

    self:UpdateTrackOrderBox()
end

---------------------------------------
--              Util
---------------------------------------

function Self:GetOrder()
    return GUI.OrdersView.frame and GUI.OrdersView.frame.order
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