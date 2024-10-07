---@class TestFlight
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

local Parent = GUI.RecipeForm.RecipeForm

---@class GUI.RecipeForm.CustomerOrderForm: GUI.RecipeForm.RecipeForm, GUI.RecipeForm.AmountForm
---@field form CustomerOrderForm
local Self = Mixin(GUI.RecipeForm.CustomerOrderForm, Parent, GUI.RecipeForm.AmountForm)

---@param btn Button
function Self:ListOrderButtonOnEnter(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT");
    GameTooltip_AddErrorLine(GameTooltip, "Experimentation mode is enabled.");
    GameTooltip:Show();
end

function Self:GetTrackCheckbox()
    return self.form.TrackRecipeCheckbox.Checkbox
end

---------------------------------------
--               Hooks
---------------------------------------

function Self:InitSchematic(self)
    self:UpdateAmountSpinner()
end

function Self:UpdateListOrderButton()
    if not Addon.enabled then return end
    if self.form.committed then return end

    local listOrderButton = self.form.PaymentContainer.ListOrderButton;

    listOrderButton:SetEnabled(false);
    listOrderButton:SetScript("OnEnter", Util:FnBind(self.ListOrderButtonOnEnter, self))
end

---------------------------------------
--               Util
---------------------------------------

function Self:GetOrder()
    return self.form and self.form.order
end

---------------------------------------
--             Lifecycle
---------------------------------------

function Self:OnRefresh()
    Parent.OnRefresh(self)

    if not self.form or not self.form:IsVisible() then return end

    self.form:InitSchematic()

    if not Addon.enabled then return end

    self.form.PaymentContainer.ListOrderButton:SetEnabled(false)
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_ProfessionsCustomerOrders", addonName) then return end

    self.form = ProfessionsCustomerOrdersFrame.Form

    local reagents = self.form.ReagentContainer

    -- Elements

    -- Insert experiment checkbox
    self:InsertExperimentBox(
        reagents,
        "LEFT", self.form.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
    )

    -- Insert tracked amount spinner
    self:InsertAmountSpinner(
        "LEFT", self.form.TrackRecipeCheckbox, "RIGHT", 30, 1
    )

    -- Hooks

    hooksecurefunc(self.form, "InitSchematic", Util:FnBind(self.InitSchematic, self))
    hooksecurefunc(self.form, "UpdateListOrderButton", Util:FnBind(self.UpdateListOrderButton, self))
end