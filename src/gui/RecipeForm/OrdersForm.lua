---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util
local NS = GUI.RecipeForm

local Parent = Util:TblCombineMixins(NS.RecipeCraftingForm, NS.OrderForm)

---@class GUI.RecipeForm.OrdersForm: GUI.RecipeForm.RecipeCraftingForm, GUI.RecipeForm.OrderForm
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
    local quality = NS.RecipeCraftingForm.GetQuality(self)
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

    -- Insert experiment checkbox
    self:InsertExperimentBox(
        self.form,
        "LEFT", self.form.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
    )

    -- Insert track order spinner
    self:InsertTrackOrderBox(
        "TOPLEFT", self.form.TrackRecipeCheckbox, "BOTTOMLEFT", 0, 0
    )

    -- Insert skill points spinner
    self:InsertSkillSpinner(
        self.form.Details.StatLines.SkillStatLine,
        "RIGHT", -50, 1
    )

    -- Insert concentration cost spinner
    self:InsertConcentrationCostSpinner(
        self.form.Details.StatLines.ConcentrationStatLine,
        "RIGHT", -50, 1
    )

    -- Insert optimization buttons
    self:InsertOptimizationButtons(
        ordersView,
        "TOPLEFT", ordersView.OrderDetails, "BOTTOMLEFT", 0, -4
    )

    -- Hooks

    hooksecurefunc(self.form, "Init", Util:FnBind(self.Init, self))
    hooksecurefunc(self.form, "Refresh", Util:FnBind(self.Refresh, self))
    hooksecurefunc(self.form, "UpdateDetailsStats", Util:FnBind(self.UpdateDetailsStats, self))

    hooksecurefunc(self.form.Details, "SetStats", Util:FnBind(self.DetailsSetStats, self))
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)