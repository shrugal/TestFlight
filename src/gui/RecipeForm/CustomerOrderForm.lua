---@class Addon
local Addon = select(2, ...)
local GUI, Orders, Prices, Reagents, Util = Addon.GUI, Addon.Orders, Addon.Prices, Addon.Reagents, Addon.Util
local NS = GUI.RecipeForm

---@type GUI.RecipeForm.RecipeForm | GUI.RecipeForm.WithExperimentation | GUI.RecipeForm.WithAmount | GUI.RecipeForm.WithOrder
local Parent = Util:TblCombineMixins(NS.RecipeForm, NS.WithExperimentation, NS.WithAmount, NS.WithOrder)

---@class GUI.RecipeForm.CustomerOrderForm: GUI.RecipeForm.RecipeForm, GUI.RecipeForm.WithExperimentation, GUI.RecipeForm.WithAmount, GUI.RecipeForm.WithOrder
---@field form CustomerOrderForm
local Self = Mixin(NS.CustomerOrderForm, Parent)

---@param btn Button
function Self:ListOrderButtonOnEnter(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT");
    GameTooltip_AddErrorLine(GameTooltip, "Experimentation mode is enabled.");
    GameTooltip:Show();
end

function Self:InsertReagentPrice()
    local parent = self.form.PaymentContainer
    ---@type Region, Region
    local prev, curr

    -- TimeRemaining
    prev, curr = parent.Tip, parent.TimeRemaining
    curr:ClearAllPoints()
    curr:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 6)

    -- Duration
    prev, curr = parent.Tip, parent.Duration
    curr:ClearAllPoints()
    curr:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 6)

    -- PostingFee
    prev, curr = curr, parent.PostingFee
    curr:ClearAllPoints()
    curr:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 6)

    -- TotalPrice
    prev, curr = curr, parent.TotalPrice
    curr:ClearAllPoints()
    curr:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 6)

    -- Cost label
    prev, curr = curr, parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    curr:SetSize(110, 40)
    curr:SetJustifyH("RIGHT")
    curr:SetText("Reagents")
    curr:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 6)
    self.costLabel = curr

    -- Cost value
    curr = GUI:InsertElement("Frame", parent, "MoneyDisplayFrameTemplate") --[[@as MoneyDisplayFrame]]
    curr:SetPoint("LEFT", self.costLabel, "RIGHT", 10, 0)
    curr:SetPoint("RIGHT")
    curr:SetAmount(0)
    curr.hideCopper = true
    curr.leftAlign = true
    curr.useAuctionHouseIcons = true
    curr:OnLoad()
    self.costValue = curr
end

function Self:UpdateReagentPrice()
    local recipe = self:GetRecipe()
    if not recipe then return end

    local order = self:GetOrder()
    local recraftMods = Reagents:GetRecraftMods(order, self.form.transaction:GetRecraftAllocation())

    local price = Prices:GetRecipeAllocationPrice(recipe, self:GetAllocation(), order, recraftMods)

    self.costValue:SetAmount(price)
end

---------------------------------------
--               Util
---------------------------------------

function Self:GetTrackRecipeCheckbox()
    return self.form.TrackRecipeCheckbox.Checkbox
end

---------------------------------------
--               Hooks
---------------------------------------

function Self:Init()
    local s = Enum.CraftingOrderState
	local completed = Util:OneOf(self.form.order.orderState, s.Expired, s.Rejected, s.Canceled, s.Fulfilled)
    self.form.PaymentContainer.PostingFee:ClearAllPoints()
    self.form.PaymentContainer.PostingFee:SetPoint("TOPLEFT", self.form.PaymentContainer.Duration, "BOTTOMLEFT", 0, completed and 46 or 6)
end

function Self:InitSchematic()
    self:UpdateExperimentBox()
    self:UpdateAmountSpinner()
    self:UpdateTrackOrderBox()
    self:UpdateReagentPrice()
end

function Self:UpdateListOrderButton()
    self:UpdateTracking()

    if not Addon.enabled or self.form.committed then return end

    local listOrderButton = self.form.PaymentContainer.ListOrderButton
    listOrderButton:SetEnabled(false)
    listOrderButton:SetScript("OnEnter", Util:FnBind(self.ListOrderButtonOnEnter, self))
    listOrderButton:SetScript("OnLeave", GameTooltip_Hide)
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

function Self:OnAllocationUpdated()
    if not self.form:IsVisible() then return end
    Orders:UpdateCreatingReagents()
end

function Self:OnCreatingReagentsUpdated()
    if not self.form:IsVisible() then return end
    self:UpdateReagentPrice()
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

    -- Insert cost frame

    self:InsertReagentPrice()

    -- Hooks

    hooksecurefunc(self.form, "Init", Util:FnBind(self.Init, self))
    hooksecurefunc(self.form, "InitSchematic", Util:FnBind(self.InitSchematic, self))
    hooksecurefunc(self.form, "UpdateListOrderButton", Util:FnBind(self.UpdateListOrderButton, self))

    EventRegistry:RegisterCallback("Professions.AllocationUpdated", Util:FnDebounce(self.OnAllocationUpdated), self)

    Orders:RegisterCallback(Orders.Event.CreatingReagentsUpdated, self.OnCreatingReagentsUpdated, self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)