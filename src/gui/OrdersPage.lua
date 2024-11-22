---@class Addon
local Addon = select(2, ...)
local Cache, GUI, Optimization, Orders, Util = Addon.Cache, Addon.GUI, Addon.Optimization, Addon.Orders, Addon.Util

---@class GUI.OrdersPage
---@field frame OrdersPage
local Self = GUI.OrdersPage

---@type Cache<number, fun(self: Cache, order: CraftingOrderInfo): number>
Self.profitCache = Cache:Create(function (_, order) return order.orderID end, 50)


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
    ---@type CraftingOrderInfo?
    local next

    for order in self:EnumerateOrders() do
        if Orders:IsTracked(order) and (not next or order.expirationTime < next.expirationTime) then
            next = order
        end
    end

    if not next then return end

    self:ClaimOrder(next)
end

function Self:InsertClaimOrderButton()
    self.claimOrderBtn = GUI:InsertButton("Start Next", self.frame.BrowseFrame, nil, Util:FnBind(self.ClaimOrderButtonOnClick, self), "BOTTOMRIGHT", -10, 7)
    self:UpdateClaimOrderButton()
end

function Self:UpdateClaimOrderButton()
    self.claimOrderBtn:SetEnabled(Orders:HasTracked())
end

-- Track all orders checkbox

function Self:TrackAllOrdersBoxOnClick(frame)
    self:SetAllOrdersTracked(frame:GetChecked())
end

function Self:InsertTrackAllOrdersBox()
    local input = GUI:InsertCheckbox(self.frame.BrowseFrame, nil, Util:FnBind(self.TrackAllOrdersBoxOnClick, self), "BOTTOMLEFT", self.frame.BrowseFrame.RecipeList, "BOTTOMRIGHT", 3, 0)

    input:SetSize(26, 26)
    input.text:SetPoint("LEFT", input, "RIGHT", 0, 1)

    self.trackAllOrdersBox = input
    self:UpdateTrackAllOrdersBox()
end

function Self:UpdateTrackAllOrdersBox()
    local enabled = self:HasOrders()
    local color = enabled and WHITE_FONT_COLOR or LIGHTGRAY_FONT_COLOR

    self.trackAllOrdersBox:SetEnabled(enabled)
    self.trackAllOrdersBox:SetChecked(enabled and self:IsAllOrdersTracked())
    self.trackAllOrdersBox.text:SetText(color:WrapTextInColorCode("Track All"))
end

---------------------------------------
--            Hooks
---------------------------------------

---@param cell ProfessionsCrafterTableCellItemNameFrame
---@param rowData ProfessionsCrafterOrderListRowData
function Self:ItemNameCellPopulate(cell, rowData)
    local order = rowData.option

    if not cell.TrackBox then
        ---@diagnostic disable-next-line: inject-field
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
        cell.Text:SetText(cell.Text:GetText():gsub("|c" .. ("%w"):rep(8), "|cffff0000", 1))
    end
end

---@param cell ProfessionsCrafterTableCellCommissionFrame
---@param rowData ProfessionsCrafterOrderListRowData
function Self:CommissionCellPopulate(cell, rowData)
    local moneyFrame = cell.TipMoneyDisplayFrame
    local order = rowData.option

    -- Rewards

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

        ---@diagnostic disable-next-line: inject-field
        cell.RewardText = cell:CreateFontString(nil, "ARTWORK", "Number14FontWhite")
        cell.RewardText:SetPoint("LEFT")
        cell.RewardText:SetMouseMotionEnabled(true)
        cell.RewardText:SetScript("OnEnter", function (...) cell.RewardIcon:GetScript("OnEnter")(...) end)
        cell.RewardText:SetScript("OnLeave", function (...) cell.RewardIcon:GetScript("OnLeave")(...) end)
    end

    cell.RewardText:SetText(rewards)
    cell.RewardIcon:Hide()

    -- Profit

    local cache = self.profitCache
    local key = cache:Key(order)

    if not cache:Has(key) then
        local operation = Optimization:GetOrderAllocation(order)
        cache:Set(key, operation and operation:GetProfit())
    end

    local profit = cache:Get(key)

    moneyFrame.SilverDisplay:SetShowsZeroAmount(false)
    moneyFrame.CopperDisplay:SetForcedHidden(false)
    moneyFrame.CopperDisplay:SetShowsZeroAmount(not profit or abs(profit) < 100)

    if not profit then
        moneyFrame:SetAmount(0)
        moneyFrame.CopperDisplay.Text:SetText("-")
    else
        if abs(profit) > 10000 then
            profit = Util:NumRound(profit, -4)
        elseif abs(profit) > 100 then
            profit = Util:NumRound(profit, -2)
        end

        moneyFrame:SetAmount(abs(profit))

        if profit < 0 then
            local frame = moneyFrame.GoldDisplay:IsShown() and moneyFrame.GoldDisplay or moneyFrame.SilverDisplay
            frame.Text:SetText(("|cffff0000-%s|r"):format(frame.Text:GetText()))
        end
    end

    moneyFrame:UpdateWidth()
    moneyFrame:UpdateAnchoring()
end

---------------------------------------
--              Util
---------------------------------------

---@param order CraftingOrderInfo
---@param value? boolean
function Self:SetOrderTracked(order, value)
    Orders:SetTracked(order, value)

    if not value then return end

    local operation = Optimization:GetOrderAllocation(order)

    Orders:SetTrackedAllocation(order, operation and operation.allocation)
end

function Self:HasOrders()
    return next(C_CraftingOrders.GetCrafterOrders()) ~= nil
end

function Self:EnumerateOrders()
    local orders, i, order = C_CraftingOrders.GetCrafterOrders(), nil, nil
    return function ()
        while true do
            i, order = next(orders, i)
            if not order then return end
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(order.spellID)
            if recipeInfo and recipeInfo.learned then return order end
        end
    end
end

function Self:IsAllOrdersTracked()
    for order in self:EnumerateOrders() do
        if not Orders:IsTracked(order) then return false end
    end
    return true
end

---@param value? boolean
function Self:SetAllOrdersTracked(value)
    for order in self:EnumerateOrders() do
        self:SetOrderTracked(order, value)
    end
end

---@param order CraftingOrderInfo
function Self:ClaimOrder(order)
    C_CraftingOrders.ClaimOrder(order.orderID, C_TradeSkillUI.GetChildProfessionInfo().profession)
    self.frame:ViewOrder(order)
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
    self:UpdateClaimOrderButton()
    self:UpdateTrackAllOrdersBox()
end

function Self:OnOrderListUpdated()
    self:UpdateTrackAllOrdersBox()
end

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    self.frame = ProfessionsFrame.OrdersPage

    self:AdjustOrdersList()
    self:InsertClaimOrderButton()
    self:InsertTrackAllOrdersBox()

    ProfessionsTableConstants.Name.Width = ProfessionsTableConstants.Name.Width + 20
    ProfessionsTableConstants.Tip.Width = ProfessionsTableConstants.Tip.Width - 20
    ProfessionsTableConstants.Tip.LeftCellPadding = ProfessionsTableConstants.NoPadding
    ProfessionsTableConstants.Tip.RightCellPadding = ProfessionsTableConstants.StandardPadding

    Util:TblHook(ProfessionsCrafterOrderListElementMixin, "OnClick", self.OnOrderListElementClick, self)

    hooksecurefunc(ProfessionsCrafterTableCellItemNameMixin, "Populate", Util:FnBind(self.ItemNameCellPopulate, self))
    hooksecurefunc(ProfessionsCrafterTableCellCommissionMixin, "Populate", Util:FnBind(self.CommissionCellPopulate, self))
    hooksecurefunc(self.frame, "OrderRequestCallback", Util:FnBind(self.OnOrderListUpdated, self))

    Orders:RegisterCallback(Orders.Event.TrackedUpdated, self.OnTrackedOrderUpdated, self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)