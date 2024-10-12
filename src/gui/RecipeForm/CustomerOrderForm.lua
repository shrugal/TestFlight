---@class Addon
local Addon = select(2, ...)
local GUI, Orders, Recipes, Util = Addon.GUI, Addon.Orders, Addon.Recipes, Addon.Util
local NS = GUI.RecipeForm

local Parent = Util:TblCombineMixins(NS.RecipeForm, NS.AmountForm, NS.OrderForm)

---@class GUI.RecipeForm.CustomerOrderForm: GUI.RecipeForm.RecipeForm, GUI.RecipeForm.AmountForm, GUI.RecipeForm.OrderForm
---@field form CustomerOrderForm
local Self = Mixin(NS.CustomerOrderForm, Parent)

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

function Self:InitSchematic()
    self:UpdateAmountSpinner()
    self:UpdateTrackOrderBox()
end

function Self:UpdateListOrderButton()
    Recipes:SetTrackedByForm(self)

    if not Addon.enabled or self.form.committed then return end

    local listOrderButton = self.form.PaymentContainer.ListOrderButton
    listOrderButton:SetEnabled(false);
    listOrderButton:SetScript("OnEnter", Util:FnBind(self.ListOrderButtonOnEnter, self))
end

function Self:UpdateReagentSlots()
    Orders:UpdateCreatingReagents()

    for slot in self.form.reagentSlotPool:EnumerateActive() do
        local origCb = slot.Checkbox:GetScript("OnClick")
        slot:SetCheckboxCallback(function (checked)
            origCb(checked)

            if not Orders:IsTracked(self:GetOrder()) then return end

            Orders:UpdateCreatingReagent(slot)
        end)
    end
end

---------------------------------------
--               Util
---------------------------------------

function Self:GetOrder()
    return self.form and self.form.order
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnRefresh()
    Parent.OnRefresh(self)

    if not self.form or not self.form:IsVisible() then return end

    self.form:InitSchematic()

    if not Addon.enabled then return end

    self.form.PaymentContainer.ListOrderButton:SetEnabled(false)
end

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_ProfessionsCustomerOrders", addonName) then return end

    self.form = ProfessionsCustomerOrdersFrame.Form

    Parent.OnAddonLoaded(self)

    -- Elements

    -- Insert experiment checkbox
    self:InsertExperimentBox(
        self.form.ReagentContainer,
        "LEFT", self.form.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
    )

    -- Insert track order spinner
    self:InsertTrackOrderBox(
        "LEFT", self.form.TrackRecipeCheckbox, "RIGHT", 10, 0
    )
    self.trackOrderBox:SetScale(0.9)

    -- Insert tracked amount spinner
    self:InsertAmountSpinner(
        "LEFT", self.trackOrderBox, "RIGHT", 98, 1
    )
    self.amountSpinner:SetScale(0.9)

    -- Hooks

    hooksecurefunc(self.form, "InitSchematic", Util:FnBind(self.InitSchematic, self))
    hooksecurefunc(self.form, "UpdateListOrderButton", Util:FnBind(self.UpdateListOrderButton, self))
    hooksecurefunc(self.form, "UpdateReagentSlots", Util:FnBind(self.UpdateReagentSlots, self))

end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)