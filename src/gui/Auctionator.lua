---@type string
local Name = ...
---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

---@class GUI.Auctionator
local Self = GUI.Auctionator

---------------------------------------
--             Buy button
---------------------------------------

function Self:BuyButtonOnClick()
    ---@type AuctionatorShoppingFrame, AuctionatorBuyCommodityFrame, AuctionatorBuyItemFrame
    local shoppingFrame, commodityFrame, itemFrame = unpack(self.buyFrames)

    ---@type AuctionatorBuyCommodityFinalConfirmationDialog, AuctionatorBuyCommodityWidePriceRangeWarningDialog, AuctionatorBuyCommodityQuantityCheckConfirmationDialog, AuctionatorBuyItemDialog
    local confirmDialog, priceDialog, quantityDialog, buyDialog = unpack(self.buyDialogs)

    if confirmDialog:IsShown() or priceDialog:IsShown() or quantityDialog:IsShown() then
        self.buyItemKey = commodityFrame.itemKey

        if confirmDialog:IsShown() then
            confirmDialog.AcceptButton:Click()
        elseif priceDialog:IsShown() then
            priceDialog.ContinueButton:Click()
        elseif quantityDialog:IsShown() then
            quantityDialog.AcceptButton:Click()
        end
    elseif commodityFrame:IsShown() then
        commodityFrame:BuyClicked()
    elseif buyDialog:IsShown() then
        self.buyItemKey = itemFrame.expectedItemKey

        buyDialog.Buy:Click()
    else
        local resultsListing = (itemFrame:IsShown() and itemFrame or shoppingFrame).ResultsListing
        local row = resultsListing.tableBuilder.rows[1]
        if row then row:OnClick() end
    end
end

function Self:InsertBuyButton()
    local parent = AuctionatorShoppingFrame.SearchOptions

    self.buyButton = GUI:InsertButton("", parent, nil, Util:FnBind(self.BuyButtonOnClick, self))
    self.buyButton:SetPoint("LEFT", parent.AddToListButton, "RIGHT", 5, 0)
    self.buyButton:SetPoint("RIGHT", -5, 0)

    self:UpdateBuyButton()
end

---@param frame Frame
local function IsShown (frame) return frame:IsShown() end

function Self:UpdateBuyButton()
    ---@type AuctionatorShoppingFrame, AuctionatorBuyCommodityFrame, AuctionatorBuyItemFrame
    local shoppingFrame, commodityFrame, itemFrame = unpack(self.buyFrames)

    local enabled, text = true, nil

    if Util:TblSome(self.buyDialogs, IsShown) then
        text = "Confirm"
    elseif commodityFrame:IsShown() then
        text = "Buy"
    else
        enabled = (itemFrame:IsShown() and itemFrame or shoppingFrame).DataProvider:GetCount() > 0
        text = "Buy Next"
    end

    self.buyButton:SetEnabled(enabled)
    self.buyButton:SetText(text)
end

---------------------------------------
--              Util
---------------------------------------

function Self:ForgetBuyItemKey()
    local itemKey = self.buyItemKey
    self.buyItemKey = nil
    return itemKey
end

---@param itemKey ItemKey
function Self:RemoveBuyEntryByItemKey(itemKey)
    -- Remove from current search
    local dataProvider = AuctionatorShoppingFrame.DataProvider
    local index = Util:TblFind(dataProvider.results, function (entry) return Util:TblEquals(entry.itemKey, itemKey) end)
    if index then
        tremove(dataProvider.results, index)
        dataProvider:SetDirty()

        if #dataProvider.entriesToProcess == 0 then
            dataProvider:CheckForEntriesToProcess()
        end
    end

    -- Remove from TF shopping list
    if self.buyingList == ("%s (%s)"):format(Name, AUCTIONATOR_L_TEMPORARY_LOWER_CASE) then
        local termPrefix = Auctionator.API.v1.ConvertToSearchString(Name, {
            searchString = C_Item.GetItemInfo(itemKey.itemID),
            tier = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemKey.itemID),
            isExact = true
        })

        local terms = Auctionator.API.v1.GetShoppingListItems(Name, self.buyingList)
        local _, term = Util:TblFind(terms, function (term) return Util:StrStartsWith(term, termPrefix) end)

        if term then
            Auctionator.API.v1.DeleteShoppingListItem(Name, self.buyingList, term)
        end
    end
end

---------------------------------------
--              Events
---------------------------------------

---@param auctionID? number
function Self:OnAuctionHousePurchaseCompleted(auctionID)
    local itemKey = self:ForgetBuyItemKey()
    if not itemKey then return end

    ---@type _, AuctionatorBuyCommodityFrame, AuctionatorBuyItemFrame
    local _, commodityFrame, itemFrame = unpack(self.buyFrames)

    if commodityFrame:IsShown() then
        if not Util:TblEquals(commodityFrame.itemKey, itemKey) then return end
        commodityFrame:Hide()
    elseif itemFrame:IsShown() then
        do return end ---@todo
        if not Util:TblEquals(itemFrame.expectedItemKey, itemKey) then return end
        itemFrame:Hide()
    end

    self:RemoveBuyEntryByItemKey(itemKey)
end

function Self:OnAuctionHousePurchaseFailed()
    self:ForgetBuyItemKey()
end

function Self:OnShoppingListExpand()
    if not Auctionator.Config.Get(Auctionator.Config.Options.AUTO_LIST_SEARCH) then return end
    self.buyingList = AuctionatorShoppingFrame.ListsContainer:GetExpandedList():GetName()
end

---@param list AuctionatorShoppingList
function Self:OnShoppingListSearch(list)
    self.buyingList = list:GetName()
end

function Self:OnShoppingSearch()
    self.buyingList = nil
end

function Self:OnShow()
    if not AuctionatorBuyCommodityFrame then return end
    if self.buyFrames then return end

    self.buyFrames = {
        AuctionatorShoppingFrame,
        AuctionatorBuyCommodityFrame,
        AuctionatorBuyItemFrame
    }

    self.buyDialogs = {
        AuctionatorBuyCommodityFrame.FinalConfirmationDialog,
        AuctionatorBuyCommodityFrame.WidePriceRangeWarningDialog,
        AuctionatorBuyCommodityFrame.QuantityCheckConfirmationDialog,
        AuctionatorBuyItemFrame.BuyDialog
    }

    self:InsertBuyButton()

    local UpdateBuyButton = Util:FnBind(self.UpdateBuyButton, self)
    for i,frame in pairs(self.buyFrames) do
        hooksecurefunc(frame.DataProvider, "onUpdate", UpdateBuyButton)
        if i > 1 then frame:HookScript("OnHide", UpdateBuyButton) end
    end
    for _,frame in pairs(self.buyDialogs) do
        frame:HookScript("OnShow", UpdateBuyButton)
        frame:HookScript("OnHide", UpdateBuyButton)
    end

    hooksecurefunc(AuctionatorShoppingFrame.ListsContainer, "onListExpanded", Util:FnBind(self.OnShoppingListExpand, self))
    hooksecurefunc(AuctionatorShoppingFrame.ListsContainer, "onListSearch", Util:FnBind(self.OnShoppingListSearch, self))
    hooksecurefunc(AuctionatorShoppingFrame, "DoSearch", Util:FnBind(self.OnShoppingSearch, self))
end

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Auctionator", addonName) then return end

    hooksecurefunc(AuctionatorAHFrameMixin, "OnShow", Util:FnBind(self.OnShow, self))

    EventRegistry:RegisterFrameEventAndCallback("COMMODITY_PRICE_UPDATED", self.OnAuctionHousePurchaseFailed, self)
    EventRegistry:RegisterFrameEventAndCallback("COMMODITY_PRICE_UNAVAILABLE", self.OnAuctionHousePurchaseFailed, self)
    EventRegistry:RegisterFrameEventAndCallback("COMMODITY_PURCHASE_FAILED", self.OnAuctionHousePurchaseFailed, self)
    EventRegistry:RegisterFrameEventAndCallback("AUCTION_HOUSE_SHOW_ERROR", self.OnAuctionHousePurchaseFailed, self)

    EventRegistry:RegisterFrameEventAndCallback("AUCTION_HOUSE_PURCHASE_COMPLETED", self.OnAuctionHousePurchaseCompleted, self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)
