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
    local shoppingFrame = AuctionatorShoppingFrame
    local commodityFrame = AuctionatorBuyCommodityFrame
    local itemFrame = AuctionatorBuyItemFrame

    local confirmDialog = commodityFrame.FinalConfirmationDialog
    local priceDialog = commodityFrame.WidePriceRangeWarningDialog
    local quantityDialog = commodityFrame.QuantityCheckConfirmationDialog
    local buyDialog = itemFrame.BuyDialog

    if confirmDialog:IsShown() or priceDialog:IsShown() or quantityDialog:IsShown() then
        self.buyingItemKey = commodityFrame.itemKey

        if confirmDialog:IsShown() then
            confirmDialog.AcceptButton:Click()
        elseif priceDialog:IsShown() then
            priceDialog.ContinueButton:Click()
        elseif quantityDialog:IsShown() then
            quantityDialog.AcceptButton:Click()
        end
    elseif buyDialog:IsShown() then
        self.buyingItemKey = itemFrame.expectedItemKey

        buyDialog.Buy:Click()
    elseif commodityFrame:IsShown() then
        commodityFrame:BuyClicked()
    else
        local resultsListing = (itemFrame:IsShown() and itemFrame or shoppingFrame).ResultsListing
        local row = resultsListing.tableBuilder.rows[1]
        if row then row:OnClick() end
    end
end

function Self:InsertBuyButton()
    self.buyButton = GUI:InsertButton("Buy Next", AuctionatorShoppingFrame.SearchOptions, nil, Util:FnBind(self.BuyButtonOnClick, self))
    self.buyButton:SetPoint("LEFT", AuctionatorShoppingFrame.SearchOptions.AddToListButton, "RIGHT", 5, 0)
    self.buyButton:SetPoint("RIGHT", -5, 0)
end

function Self:UpdateBuyButton()
    local shoppingFrame = AuctionatorShoppingFrame
    local commodityFrame = AuctionatorBuyCommodityFrame
    local itemFrame = AuctionatorBuyItemFrame

    local confirmDialog = commodityFrame.FinalConfirmationDialog
    local priceDialog = commodityFrame.WidePriceRangeWarningDialog
    local quantityDialog = commodityFrame.QuantityCheckConfirmationDialog
    local buyDialog = itemFrame.BuyDialog

    local enabled, text = true, nil

    if confirmDialog:IsShown() or priceDialog:IsShown() or quantityDialog:IsShown() or buyDialog:IsShown() then
        text = "Confirm"
    elseif commodityFrame:IsShown() then
        text = "Buy"
    else
        text = "Buy Next"

        if itemFrame:IsShown() then
            enabled = itemFrame.DataProvider:GetCount() > 0
        else
            enabled = shoppingFrame.DataProvider:GetCount() > 0
        end
    end

    self.buyButton:SetEnabled(enabled)
    self.buyButton:SetText(text)
end

---------------------------------------
--              Util
---------------------------------------

function Self:ForgetItemKey()
    local itemKey = self.buyingItemKey
    self.buyingItemKey = nil
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
    local itemKey = self:ForgetItemKey()
    if not itemKey then return end

    local commodityFrame = AuctionatorBuyCommodityFrame
    local itemFrame = AuctionatorBuyItemFrame

    if commodityFrame:IsShown() then
        if not Util:TblEquals(commodityFrame.itemKey, itemKey) then return end
        commodityFrame:Hide()
    elseif itemFrame:IsShown() then
        if not Util:TblEquals(itemFrame.expectedItemKey, itemKey) then return end
        itemFrame:Hide()
    end

    self:RemoveBuyEntryByItemKey(itemKey)
end

function Self:OnAuctionHousePurchaseFailed()
    self:ForgetItemKey()
end

function Self:OnShoppingStateChanged()
    self:UpdateBuyButton()
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

function Self:OnAuctionHouseShown()
    if self.buyButton then return end

    self:InsertBuyButton()

    local OnShoppingStateChanged = Util:FnBind(self.OnShoppingStateChanged, self)

    hooksecurefunc(AuctionatorShoppingFrame.DataProvider, "onUpdate", OnShoppingStateChanged)
    hooksecurefunc(AuctionatorBuyCommodityFrame.DataProvider, "onUpdate", OnShoppingStateChanged)
    hooksecurefunc(AuctionatorBuyItemFrame.DataProvider, "onUpdate", OnShoppingStateChanged)

    AuctionatorBuyCommodityFrame:HookScript("OnHide", OnShoppingStateChanged)
    AuctionatorBuyCommodityFrame.FinalConfirmationDialog:HookScript("OnShow", OnShoppingStateChanged)
    AuctionatorBuyCommodityFrame.FinalConfirmationDialog:HookScript("OnHide", OnShoppingStateChanged)
    AuctionatorBuyCommodityFrame.WidePriceRangeWarningDialog:HookScript("OnShow", OnShoppingStateChanged)
    AuctionatorBuyCommodityFrame.WidePriceRangeWarningDialog:HookScript("OnHide", OnShoppingStateChanged)
    AuctionatorBuyCommodityFrame.QuantityCheckConfirmationDialog:HookScript("OnShow", OnShoppingStateChanged)
    AuctionatorBuyCommodityFrame.QuantityCheckConfirmationDialog:HookScript("OnHide", OnShoppingStateChanged)

    AuctionatorBuyItemFrame:HookScript("OnHide", OnShoppingStateChanged)
    AuctionatorBuyItemFrame.BuyDialog:HookScript("OnShow", OnShoppingStateChanged)
    AuctionatorBuyItemFrame.BuyDialog:HookScript("OnHide", OnShoppingStateChanged)

    hooksecurefunc(AuctionatorShoppingFrame.ListsContainer, "onListExpanded", Util:FnBind(self.OnShoppingListExpand, self))
    hooksecurefunc(AuctionatorShoppingFrame.ListsContainer, "onListSearch", Util:FnBind(self.OnShoppingListSearch, self))
    hooksecurefunc(AuctionatorShoppingFrame, "DoSearch", Util:FnBind(self.OnShoppingSearch, self))
end

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Auctionator", addonName) then return end

    hooksecurefunc(AuctionatorInitalizeMainlineFrame, "AuctionHouseShown", Util:FnBind(self.OnAuctionHouseShown, self))

    local OnAuctionHousePurchaseFailed = Util:FnBind(self.OnAuctionHousePurchaseFailed, self)
    EventRegistry:RegisterFrameEventAndCallback("COMMODITY_PRICE_UPDATED", OnAuctionHousePurchaseFailed)
    EventRegistry:RegisterFrameEventAndCallback("COMMODITY_PRICE_UNAVAILABLE", OnAuctionHousePurchaseFailed)
    EventRegistry:RegisterFrameEventAndCallback("COMMODITY_PURCHASE_FAILED", OnAuctionHousePurchaseFailed)
    EventRegistry:RegisterFrameEventAndCallback("AUCTION_HOUSE_SHOW_ERROR", OnAuctionHousePurchaseFailed)

    EventRegistry:RegisterFrameEventAndCallback("AUCTION_HOUSE_PURCHASE_COMPLETED", self.OnAuctionHousePurchaseCompleted, self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)
