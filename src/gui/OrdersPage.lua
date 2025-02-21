---@class Addon
local Addon = select(2, ...)
local Buffs, Cache, GUI, Optimization, Orders, Promise, Util = Addon.Buffs, Addon.Cache, Addon.GUI, Addon.Optimization, Addon.Orders, Addon.Promise, Addon.Util

---@class GUI.OrdersPage
---@field frame OrdersPage
local Self = GUI.OrdersPage

---@type Cache<Promise, fun(self: Cache, order: CraftingOrderInfo): number>
Self.profitCache = Cache:Create(function (_, order) return order.orderID end, nil, 50, true)

-- Orders list

function Self:AdjustOrdersList()
    local browseFrame = self.frame.BrowseFrame
    local orderList = browseFrame.OrderList

    orderList:ClearAllPoints()
    orderList:SetPoint("TOPLEFT", browseFrame.RecipeList, "TOPRIGHT")
    orderList:SetPoint("TOPRIGHT", -2, 0)
    orderList:SetHeight(531)
    orderList.NineSlice:SetPoint("BOTTOMRIGHT", -3, -2)
end

-- Claim order button

function Self:ClaimOrderButtonOnClick()
    local orders = C_CraftingOrders.GetCrafterOrders()

    if #orders == 0 then
        self.frame:StartDefaultSearch()
    else
        local order = self:GetNextOrder()
        if order then self:ClaimOrder(order) end
    end
end

function Self:InsertClaimOrderButton()
    self.claimOrderBtn = GUI:InsertButton("Start Next", self.frame.BrowseFrame, nil, Util:FnBind(self.ClaimOrderButtonOnClick, self), "BOTTOMRIGHT", -20, 7)
    self:UpdateClaimOrderButton()
end

function Self:UpdateClaimOrderButton()
    local orders = C_CraftingOrders.GetCrafterOrders()

    if #orders == 0 then
        self.claimOrderBtn:SetEnabled(true)
        self.claimOrderBtn:SetTextToFit("Search")
    else
        self.claimOrderBtn:SetEnabled(self:HasNextOrder())
        self.claimOrderBtn:SetTextToFit("Start Next")
    end
end

-- Track all orders checkbox

function Self:TrackAllOrdersBoxOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip_AddColoredLine(GameTooltip, "Track all matching orders", HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, "Track all craftable orders with learned recipes, and that are profitable or give enough knowledge or artisan currency.")
    GameTooltip:Show()
end

function Self:TrackAllOrdersBoxOnClick(frame)
    self:SetAllOrdersTracked(frame:GetChecked())
end

function Self:InsertTrackAllOrdersBox()
    local input = GUI:InsertCheckbox(
        self.frame.BrowseFrame,
        Util:FnBind(self.TrackAllOrdersBoxOnEnter, self),
        Util:FnBind(self.TrackAllOrdersBoxOnClick, self),
        "BOTTOMLEFT", self.frame.BrowseFrame.RecipeList, "BOTTOMRIGHT", 3, 0
    )

    input:SetSize(26, 26)
    input.text:SetPoint("LEFT", input, "RIGHT", 0, 1)

    self.trackAllOrdersBox = input

    if not self.frame:IsVisible() then return end

    self:UpdateTrackAllOrdersBox()
end

function Self:UpdateTrackAllOrdersBox()
    local profits = Util:TblMap(C_CraftingOrders.GetCrafterOrders(), self.GetOrderProfit, false, self)

    Promise:All(profits)
        :Singleton(self, "trackAllOrdersJob")
        :Start(function ()
            self.trackAllOrdersBox:Disable()
            self.trackAllOrdersBox.text:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode("Loading ..."))
        end)
        :Finally(function ()
            local enabled = self:HasNextOrder() or self:HasTrackableOrders()
            local color = enabled and WHITE_FONT_COLOR or LIGHTGRAY_FONT_COLOR

            self.trackAllOrdersBox:SetEnabled(enabled)
            self.trackAllOrdersBox:SetChecked(enabled and self:IsAllOrdersTracked())
            self.trackAllOrdersBox.text:SetText(color:WrapTextInColorCode("Track All"))
        end)
end

-- Track all filters

---@param frame NumericInputSpinner
function Self:TrackAllKnowledgeFiltersOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip_AddColoredLine(GameTooltip, "Cost per Knowledge Point", HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, "Amount of gold you are willing to spend per profession knowledge point.")
    GameTooltip:Show()
end

---@param frame NumericInputSpinner
function Self:TrackAllCurrencyFiltersOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip_AddColoredLine(GameTooltip, "Cost per Artisan Currency", HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, "Amount of gold you are willing to spend per artisan currency item.")
    GameTooltip:Show()
end

---@param frame NumericInputSpinner
function Self:TrackAllPayoutFiltersOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip_AddColoredLine(GameTooltip, "Cost per Artisan Bag", HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, "Amount of gold you are willing to spend per artisan material bag.")
    GameTooltip:Show()
end

---@param frame NumericInputSpinner
---@param value number
function Self:TrackAllKnowledgeFiltersOnChange(frame, value)
    Addon:SetKnowledgeCost(value * 10000)
end

---@param frame NumericInputSpinner
---@param value number
function Self:TrackAllCurrencyFiltersOnChange(frame, value)
    Addon:SetCurrencyCost(value * 10000)
end

---@param frame NumericInputSpinner
---@param value number
function Self:TrackAllPayoutFiltersOnChange(frame, value)
    Addon:SetPayoutCost(value * 10000)
end

function Self:InsertTrackAllFilters()
    -- Knowledge

    self.trackAllKnowledgeFilter, self.trackAllKnowledgeFilterText = self:InsertTrackAllFilter(
        "Inv_cosmicvoid_orb",
        self.TrackAllKnowledgeFiltersOnEnter,
        self.TrackAllKnowledgeFiltersOnChange,
        "BOTTOMLEFT", self.frame.BrowseFrame.RecipeList, "BOTTOMRIGHT", 125, 3
    )

    -- Artisan currency

    self.trackAllCurrencyFilter, self.trackAllCurrencyFilterText = self:InsertTrackAllFilter(
        "Inv_10_gearcraft_artisansmettle_color3",
        self.TrackAllCurrencyFiltersOnEnter,
        self.TrackAllCurrencyFiltersOnChange,
        "LEFT", self.trackAllKnowledgeFilterText, "RIGHT", 45, 0
    )

    -- Artisan payout

    self.trackAllPayoutFilter, self.trackAllPayoutFilterText = self:InsertTrackAllFilter(
        "Inv_misc_bag_14",
        self.TrackAllPayoutFiltersOnEnter,
        self.TrackAllPayoutFiltersOnChange,
        "LEFT", self.trackAllCurrencyFilterText, "RIGHT", 45, 0
    )

    self:UpdateTrackAllFilters()

    self.trackAllKnowledgeFilter:SetMinMaxValues(0, 9999)
    self.trackAllCurrencyFilter:SetMinMaxValues(0, 9999)
    self.trackAllPayoutFilter:SetMinMaxValues(0, 9999)
end

---@param icon string
---@param onEnter fun(frame: NumericInputSpinner)
---@param onValueChanged fun(frame: NumericInputSpinner, value: number)
---@param ... any
function Self:InsertTrackAllFilter(icon, onEnter, onValueChanged, ...)
    local icon = ("|TInterface\\MoneyFrame\\UI-GoldIcon:15|t / |TInterface\\Icons\\%s:15:15:0:0:64:64:4:60:4:60|t"):format(icon)
    local onEnter = Util:FnBind(onEnter, self)
    local onValueChanged = Util:FnBind(onValueChanged, self)

    local input = GUI:InsertNumericSpinner(self.frame.BrowseFrame, onEnter, onValueChanged, ...)

    input:SetShown(true)
    input:SetWidth(32)
    input:SetMaxLetters(4)
    input.DecrementButton:SetAlpha(0.8)
    input.IncrementButton:SetAlpha(0.8)

    local text = GUI:InsertFontString(
        self.frame.BrowseFrame, nil, "GameFontHighlight", icon, onEnter,
        "LEFT", input.IncrementButton, "RIGHT", 0, 0
    )

    return input, text
end

function Self:UpdateTrackAllFilters()
    local shown = self.frame.orderType == Enum.CraftingOrderType.Npc

    self.trackAllKnowledgeFilter:SetShown(shown)
    self.trackAllKnowledgeFilterText:SetShown(shown)
    self.trackAllCurrencyFilter:SetShown(shown)
    self.trackAllCurrencyFilterText:SetShown(shown)
    self.trackAllPayoutFilter:SetShown(shown)
    self.trackAllPayoutFilterText:SetShown(shown)

    self.trackAllKnowledgeFilter:SetValue(floor(Addon.DB.Account.knowledgeCost / 10000))
    self.trackAllCurrencyFilter:SetValue(floor(Addon.DB.Account.currencyCost / 10000))
    self.trackAllPayoutFilter:SetValue(floor(Addon.DB.Account.payoutCost / 10000))
end

---------------------------------------
--            Hooks
---------------------------------------

---@param cell ProfessionsCrafterTableCellItemNameFrame
---@param rowData ProfessionsCrafterOrderListRowData
function Self:ItemNameCellPopulate(cell, rowData)
    local order = rowData.option

    if order.customerGuid == UnitGUID("player") then return end

    if not cell.TrackBox then
        cell.TrackBox = CreateFrame("CheckButton", nil, cell, "UICheckButtonTemplate")
        cell.TrackBox:SetSize(20, 20)
        cell.TrackBox:SetPoint("LEFT", -8, 0)
        cell.Icon:ClearAllPoints()
        cell.Icon:SetPoint("LEFT", cell.TrackBox, "RIGHT", 2, 0)

        cell.TrackBox:SetScript("OnEnter", function () cell:GetParent():OnLineEnter() end)
        cell.TrackBox:SetScript("OnLeave", function () cell:GetParent():OnLineLeave() end)

        cell.TrackBox:SetScript("OnClick", function (self)
            Self:SetOrderTracked(self.order, self:GetChecked())
        end)

        Orders:RegisterCallback(Orders.Event.TrackedUpdated, function (self, order, value)
            if order.orderID == self.order.orderID then self:SetChecked(value) end
        end, cell.TrackBox)
    end

    cell.TrackBox.order = order
    cell.TrackBox:SetChecked(Orders:IsTracked(order))

    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(order.spellID)
    if recipeInfo and not recipeInfo.learned then
        cell.Icon:SetAtlas("Professions_Icon_Warning")

        local text = cell.Text:GetText()
        if text then
            text = text:gsub("|c" .. ("%w"):rep(8), YELLOW_FONT_COLOR:GenerateHexColorMarkup(), 1)
            cell.Text:SetText(text)
        end
    end
end

---@param cell ProfessionsCrafterTableCellCommissionFrame
---@param rowData ProfessionsCrafterOrderListRowData
function Self:CommissionCellPopulate(cell, rowData)
    local moneyFrame = cell.TipMoneyDisplayFrame
    local order = rowData.option

    if order.customerGuid == UnitGUID("player") then return end

    -- Profit

    moneyFrame.SilverDisplay:SetShowsZeroAmount(false)
    moneyFrame.CopperDisplay:SetForcedHidden(false)

    moneyFrame:SetAmount(10000)
    moneyFrame.GoldDisplay.Text:SetText("?")

    self:GetOrderProfit(order):Done(function (profit)
        moneyFrame.CopperDisplay:SetShowsZeroAmount(not profit or abs(profit) < 100)

        if not profit then
            moneyFrame:SetAmount(0)
            moneyFrame.CopperDisplay.Text:SetText("-")
        else
            moneyFrame:SetAmount(abs(Util:NumRoundCurrency(profit)))

            if profit < 0 then
                local frame = moneyFrame.GoldDisplay:IsShown() and moneyFrame.GoldDisplay or moneyFrame.SilverDisplay
                frame.Text:SetText(RED_FONT_COLOR:WrapTextInColorCode("-" .. frame.Text:GetText()))
            end
        end

        moneyFrame:UpdateWidth()
        moneyFrame:UpdateAnchoring()
    end):Singleton(cell, "profitJob"):Start()

    -- Rewards

    -- "No Mats; No Make" does the same thing
    if C_AddOns.IsAddOnLoaded("PublicOrdersReagentsColumn") then return end

    local rewards = ""
    if order.npcOrderRewards then
        for _,r in pairs(order.npcOrderRewards) do repeat
            if not r.itemLink then break end
            rewards = rewards .. ("|T%d:0|t%s "):format(
                C_Item.GetItemIconByID(r.itemLink),
                r.count > 1 and "x" .. r.count or ""
            )
        until true end
    end

    if not cell.RewardText then
        cell.RewardIcon:ClearAllPoints()
        cell.RewardIcon:SetPoint("LEFT")

        cell.RewardText = GUI:InsertFontString(
            cell,
            "ARTWORK", "Number14FontWhite",
            nil,
            function (...) cell.RewardIcon:GetScript("OnEnter")(...) end,
            "LEFT"
        )
        cell.RewardText:SetScript("OnLeave", function (...) cell.RewardIcon:GetScript("OnLeave")(...) end)
    end

    cell.RewardText:SetText(rewards)
    cell.RewardIcon:Hide()
end

---------------------------------------
--              Util
---------------------------------------

---@param order CraftingOrderInfo
function Self:GetOrderProfit(order)
    local cache = self.profitCache
    local key = cache:Key(order)

    if not cache:Has(key) then
        cache:Set(key, Promise:Create(function ()
            local operation = Optimization:GetOrderAllocation(order)
            return operation and operation:GetProfit()
        end))
    end

    return cache:Get(key)
end

---@param order CraftingOrderInfo
function Self:ClaimOrder(order)
    C_CraftingOrders.ClaimOrder(order.orderID, C_TradeSkillUI.GetChildProfessionInfo().profession)
    self.frame:ViewOrder(order)
end

---@param isTracked? boolean
---@param shouldTrack? boolean
function Self:EnumerateOrders(isTracked, shouldTrack)
    local orders, i, order = C_CraftingOrders.GetCrafterOrders(), nil, nil
    return function ()
        while true do repeat
            i, order = next(orders, i)
            if not order then return end
            if isTracked ~= nil and isTracked ~= Orders:IsTracked(order) then break end
            if shouldTrack ~= nil and shouldTrack ~= self:ShouldTrackOrder(order) then break end
            return order
        until true end
    end
end

-- Tracking

---@param order CraftingOrderInfo
---@param value? boolean
function Self:SetOrderTracked(order, value)
    Orders:SetTracked(order, value)

    if not value then return end

    local operation = Optimization:GetOrderAllocation(order)

    Orders:SetTrackedAllocation(order, operation)
end

---@param order CraftingOrderInfo
function Self:ShouldTrackOrder(order)
    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(order.spellID)
    if recipeInfo and not recipeInfo.learned then return false end

    local profit = self:GetOrderProfit(order):Result() --[[@as number?]]
    if not profit then return false end

    local knowledge, currency, payout = Orders:GetNumNpcRewards(order)

    knowledge = Addon.DB.Account.knowledgeCost * knowledge
    currency = Addon.DB.Account.currencyCost * currency
    payout = Addon.DB.Account.payoutCost * payout

    local maxCost = knowledge + currency + payout

    if profit < -maxCost then return false end

    return true
end

function Self:HasNextOrder()
    return Util:TblSome(self:EnumerateOrders(true), Util.FnId2, true)
end

function Self:GetNextOrder()
    ---@type CraftingOrderInfo?
    local next
    for order in self:EnumerateOrders(true) do
        if not next or order.expirationTime < next.expirationTime then
            next = order
        end
    end
    return next
end

function Self:HasTrackableOrders()
    return Util:TblSome(self:EnumerateOrders(nil, true), Util.FnId2, true)
end

function Self:IsAllOrdersTracked()
    return not Util:TblSome(self:EnumerateOrders(false, true), Util.FnId2, true)
end

---@param value? boolean
function Self:SetAllOrdersTracked(value)
    for order in self:EnumerateOrders(not value, value or nil) do
        self:SetOrderTracked(order, value)
    end
end

---------------------------------------
--              Events
---------------------------------------

---@param rowData ProfessionsCrafterOrderListElementMixin
---@param button "LeftButton" | "RightButton"
function Self:OnOrderListElementClick(rowData, button)
    if button == "LeftButton" and IsModifiedClick("QUESTWATCHTOGGLE") then
        local order = rowData.option
        self:SetOrderTracked(order, not Orders:IsTracked(order))
    else
        Util:TblGetHooked(ProfessionsCrafterOrderListElementMixin, "OnClick")(rowData, button)
    end
end

function Self:OnTrackedOrderUpdated()
    self:UpdateTrackAllOrdersBox()
    self:UpdateClaimOrderButton()
end

function Self:OnOrderListUpdated()
    self:UpdateTrackAllOrdersBox()
    self:UpdateClaimOrderButton()
end

function Self:OnTrackAllFilterCostUpdated()
    self:UpdateTrackAllOrdersBox()
    self:UpdateTrackAllFilters()
end

function Self:OnOrderTypeChanged()
    self:UpdateTrackAllFilters()
end

function Self:OnBuffChanged()
    self.profitCache:Clear()
end

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    self.frame = ProfessionsFrame.OrdersPage

    self:AdjustOrdersList()
    self:InsertClaimOrderButton()
    self:InsertTrackAllOrdersBox()
    self:InsertTrackAllFilters()

    ProfessionsTableConstants.Name.Width = ProfessionsTableConstants.Name.Width + 20
    ProfessionsTableConstants.Tip.Width = ProfessionsTableConstants.Tip.Width - 20
    ProfessionsTableConstants.Tip.LeftCellPadding = ProfessionsTableConstants.NoPadding
    ProfessionsTableConstants.Tip.RightCellPadding = ProfessionsTableConstants.StandardPadding

    Util:TblHook(ProfessionsCrafterOrderListElementMixin, "OnClick", self.OnOrderListElementClick, self)

    hooksecurefunc(ProfessionsCrafterTableCellItemNameMixin, "Populate", Util:FnBind(self.ItemNameCellPopulate, self))
    hooksecurefunc(ProfessionsCrafterTableCellCommissionMixin, "Populate", Util:FnBind(self.CommissionCellPopulate, self))
    hooksecurefunc(self.frame, "OrderRequestCallback", Util:FnBind(self.OnOrderListUpdated, self))
    hooksecurefunc(self.frame, "SetCraftingOrderType", Util:FnBind(self.OnOrderTypeChanged, self))

    Orders:RegisterCallback(Orders.Event.TrackedUpdated, self.OnTrackedOrderUpdated, self)

    Addon:RegisterCallback(Addon.Event.KnowledgeCostUpdated, self.OnTrackAllFilterCostUpdated, self)
    Addon:RegisterCallback(Addon.Event.CurrencyCostUpdated, self.OnTrackAllFilterCostUpdated, self)
    Addon:RegisterCallback(Addon.Event.PayoutCostUpdated, self.OnTrackAllFilterCostUpdated, self)

    Buffs:RegisterCallback(Buffs.Event.BuffChanged, self.OnBuffChanged, self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)