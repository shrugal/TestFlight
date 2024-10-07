---@class TestFlight
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

local Parent = GUI.RecipeForm.RecipeCraftingForm

---@class GUI.RecipeForm.OrdersForm: GUI.RecipeForm.RecipeCraftingForm
local Self = Mixin(GUI.RecipeForm.OrdersForm, Parent)

---------------------------------------
--              Util
---------------------------------------

function Self:GetOrder()
    return GUI.OrdersView.frame and GUI.OrdersView.frame.order
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    local ordersView = ProfessionsFrame.OrdersPage.OrderView

    self.form = ordersView.OrderDetails.SchematicForm

    -- Elements

    -- Insert experiment checkbox
    self:InsertExperimentBox(
        self.form,
        "LEFT", self.form.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
    )

    -- Insert skill points spinner
    self:InsertSkillSpinner(
        self.form.Details.StatLines.SkillStatLine,
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