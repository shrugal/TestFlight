---@type string
local Name = ...
---@class Addon
local Addon = select(2, ...)
local GUI, Reagents, Util = Addon.GUI, Addon.Reagents, Addon.Util

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
        self:SetBuyInfo(commodityFrame.itemKey, commodityFrame.DetailsContainer.Quantity:GetNumber())

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
        self:SetBuyInfo(itemFrame.expectedItemKey, 1)

        buyDialog.Buy:Click()
    else
        local resultsListing = (itemFrame:IsShown() and itemFrame or shoppingFrame).ResultsListing
        local row = resultsListing.tableBuilder.rows[1]

        if row then
            row:OnClick()
        elseif shoppingFrame:IsShown() then
            self:StartSearch()
        end
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

    local enabled, text = true, "Buy Next"

    if Util:TblSome(self.buyDialogs, IsShown) then
        text = "Confirm"
    elseif commodityFrame:IsShown() then
        text = "Buy"
    else
        local empty = (itemFrame:IsShown() and itemFrame or shoppingFrame).DataProvider:GetCount() == 0

        if empty and shoppingFrame:IsShown() and not Util:TblIsEmpty(self:GetMissingReagents()) then
            text = Name
        else
            enabled = not empty
        end
    end

    self.buyButton:SetEnabled(enabled)
    self.buyButton:SetText(text)
end

---------------------------------------
--              Util
---------------------------------------

---@param itemKey? ItemKey
---@param quantity? number
function Self:SetBuyInfo(itemKey, quantity)
    self.buyItemKey, self.buyQuantity = itemKey, quantity
end

function Self:GetUnsetBuyInfo()
    local itemKey, quantity = self.buyItemKey, self.buyQuantity
    self:SetBuyInfo()
    return itemKey, quantity
end

function Self:GetShoppingListName()
    return ("%s (%s)"):format(Name, AUCTIONATOR_L_TEMPORARY_LOWER_CASE)
end

function Self:IsShoppingListSearch()
    return self.buyList == self:GetShoppingListName()
end

function Self:GetMissingReagents()
    return select(2, Reagents:GetTrackedBySource())
end

function Self:StartSearch(searchTerms)
    if not searchTerms then
        local missing = self:GetMissingReagents()
        if Util:TblIsEmpty(missing) then return end

        searchTerms = {}

        for itemID,amount in pairs(missing) do
            local name = C_Item.GetItemInfo(itemID)
            local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
            tinsert(searchTerms, { searchString = name, tier = quality, isExact = true, quantity = amount })
        end
    end

    Auctionator.API.v1.MultiSearchAdvanced(Name, searchTerms)
end

---@param itemKey ItemKey
---@param amount number
function Self:SubBuyAmountByItemKey(itemKey, amount)
    if self:IsShoppingListSearch() then
        self:SubBuyAmountFromShoppingList(itemKey, amount)
    end

    return self:SubBuyAmountFromSearch(itemKey, amount)
end

---@param itemKey ItemKey
---@param amount number
function Self:SubBuyAmountFromShoppingList(itemKey, amount)
    local terms = Auctionator.API.v1.GetShoppingListItems(Name, self.buyList)
    local termPattern = Auctionator.API.v1.ConvertToSearchString(Name, {
        searchString = C_Item.GetItemInfo(itemKey.itemID),
        tier = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemKey.itemID),
        isExact = true,
        quantity = "(%d*)"
    })

    ---@type _, string?
    local _, term = Util:TblFind(terms, function (term) return term:match(termPattern) end)
    if not term then return end

    local quantity = (tonumber(term:match(termPattern)) or 0) - amount
    if quantity <= 0 then
        Auctionator.API.v1.DeleteShoppingListItem(Name, self.buyList, term)
    else
        Auctionator.API.v1.AlterShoppingListItem(Name, self.buyList, term, termPattern:gsub("%(%%d%*%)", quantity))
    end

    return quantity <= 0
end

---@param itemKey ItemKey
---@param amount number
function Self:SubBuyAmountFromSearch(itemKey, amount)
    local dataProvider = AuctionatorShoppingFrame.DataProvider

    ---@type number?, AuctionatorShoppingEntry
    local index, entry = Util:TblFind(dataProvider.results, function (entry) return Util:TblEquals(entry.itemKey, itemKey) end)
    if not index then return end

    local quantity = (entry.purchaseQuantity or 0) - amount
    if quantity <= 0 then
        tremove(dataProvider.results, index)
    else
        entry.purchaseQuantity = quantity
    end

    dataProvider:SetDirty()

    if #dataProvider.entriesToProcess == 0 then
        dataProvider:CheckForEntriesToProcess()
    end

    return quantity <= 0
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnAuctionHousePurchaseCompleted()
    local itemKey, quantity = self:GetUnsetBuyInfo()
    if not itemKey then return end

    ---@type _, AuctionatorBuyCommodityFrame, AuctionatorBuyItemFrame
    local _, commodityFrame, itemFrame = unpack(self.buyFrames)
    local frame

    if commodityFrame:IsShown() then
        if not Util:TblEquals(commodityFrame.itemKey, itemKey) then return end
        frame = commodityFrame
    elseif itemFrame:IsShown() then
        if not Util:TblEquals(itemFrame.expectedItemKey, itemKey) then return end
        frame = itemFrame
    end

    local done = self:SubBuyAmountByItemKey(itemKey, quantity or 1)

    if done and frame then frame:Hide() end
end

function Self:OnAuctionHousePurchaseFailed()
    self:SetBuyInfo()
end

function Self:OnShoppingListExpand()
    if not Auctionator.Config.Get(Auctionator.Config.Options.AUTO_LIST_SEARCH) then return end
    self.buyList = AuctionatorShoppingFrame.ListsContainer:GetExpandedList():GetName()
end

---@param list AuctionatorShoppingList
function Self:OnShoppingListSearch(list)
    self.buyList = list:GetName()
end

function Self:OnShoppingSearch()
    self.buyList = nil
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

    local UpdateBuyButton = Util(self.UpdateBuyButton):Bind(self):Debounce(0)()
    for i,frame in pairs(self.buyFrames) do
        hooksecurefunc(frame.DataProvider, "onUpdate", UpdateBuyButton)
        frame:HookScript(i == 1 and "OnShow" or "OnHide", UpdateBuyButton)
    end
    for _,frame in pairs(self.buyDialogs) do
        frame:HookScript("OnShow", UpdateBuyButton)
        frame:HookScript("OnHide", UpdateBuyButton)
    end

    Reagents:RegisterCallback(Reagents.Event.TrackedUpdated, UpdateBuyButton)

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
