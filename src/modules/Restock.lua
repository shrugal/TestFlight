---@class Addon
local Addon = select(2, ...)
local Recipes, Util = Addon.Recipes, Addon.Util

---@class Restock: CallbackRegistryMixin
---@field Event Restock.Event
local Self = Mixin(Addon.Restock, CallbackRegistryMixin)

Self.MAX_PROFIT = 9999 * 10000 -- 9999g

---------------------------------------
--              Tracking
---------------------------------------

-- Get

---@param recipeOrOrder RecipeOrOrder
---@param quality? number
function Self:IsTracked(recipeOrOrder, quality)
    local amounts = self:GetTrackedAmounts(recipeOrOrder)
    return amounts and (not quality or amounts[quality] ~= nil) or false
end

function Self:GetTrackedIDs()
    return Util:TblKeys(Addon.DB.Char.restock)
end

---@param recipeOrOrder RecipeOrOrder
---@param quality? number
function Self:GetTrackedAmount(recipeOrOrder, quality)
    if not self:IsTracked(recipeOrOrder, quality) then return end
    local amounts = self:GetTrackedAmounts(recipeOrOrder)
    return quality and amounts[quality] or Util:TblReduce(amounts, Util.FnAdd, 0)
end

---@param recipe CraftingRecipeSchematic
---@param quality? number
function Self:GetTrackedOwned(recipe, quality)
    if not self:IsTracked(recipe, quality) then return end

    if quality then
        local item = Recipes:GetResult(recipe, nil, nil, quality)
        if not item then return end
        return self:GetItemCount(item, true)
    end

    local owned = 0
    for quality in pairs(self:GetTrackedAmounts(recipe)) do
        owned = owned + (self:GetTrackedOwned(recipe, quality) or 0)
    end

    return owned
end

---@param recipe CraftingRecipeSchematic
---@param quality? number
function Self:GetTrackedMissing(recipe, quality)
    if not self:IsTracked(recipe, quality) then return end

    local total = self:GetTrackedAmount(recipe, quality)
    local owned = self:GetTrackedOwned(recipe, quality)

    return max(0, total - owned)
end

---@param recipeOrOrder RecipeOrOrder
function Self:GetTrackedAmounts(recipeOrOrder)
    local recipeID = Recipes:GetRecipeInfo(recipeOrOrder)
    return Addon.DB.Char.restock[recipeID]
end

---@param recipeOrOrder RecipeOrOrder
---@param quality? number
function Self:GetTrackedMinProfit(recipeOrOrder, quality)
    if not self:IsTracked(recipeOrOrder, quality) then return end
    local recipeID = Recipes:GetRecipeInfo(recipeOrOrder)
    local profits = Addon.DB.Char.restockMinProfits[recipeID]
    return profits and profits[quality or 1] or 0
end

-- Set

---@param recipeOrOrder RecipeOrOrder
---@param quality number
---@param amount? number
function Self:SetTracked(recipeOrOrder, quality, amount)
    if amount and amount <= 0 then amount = nil end

    local recipeID = Recipes:GetRecipeInfo(recipeOrOrder)
    local amounts = self:GetTrackedAmounts(recipeOrOrder)

    if (amounts and amounts[quality]) == amount then return end

    if not amounts then
        amounts = {}
        Addon.DB.Char.restock[recipeID] = amounts
    end

    amounts[quality] = amount

    if not amount and Util:TblIsEmpty(amounts) then
        Addon.DB.Char.restock[recipeID] = nil
    end

    self:TriggerEvent(Self.Event.TrackedUpdated, recipeID, quality, amount or 0)
end

---@param recipeOrOrder RecipeOrOrder
---@param quality number
---@param profit? number
function Self:SetTrackedMinProfit(recipeOrOrder, quality, profit)
    if not self:IsTracked(recipeOrOrder, quality) then return end

    if profit then profit = max(-Self.MAX_PROFIT, min(profit, Self.MAX_PROFIT)) end
    if profit == 0 then profit = nil end

    local recipeID = Recipes:GetRecipeInfo(recipeOrOrder)
    local profits = Addon.DB.Char.restockMinProfits[recipeID]

    if (profits and profits[quality]) == profit then return end

    if not profits then
        profits = {}
        Addon.DB.Char.restockMinProfits[recipeID] = profits
    end

    profits[quality] = profit

    if not profit and Util:TblIsEmpty(profits) then
        Addon.DB.Char.restockMinProfits[recipeID] = nil
    end

    self:TriggerEvent(Self.Event.TrackedMinProfitUpdated, recipeID, quality, profit or 0)
end

---------------------------------------
--              Util
---------------------------------------

---@param key? boolean
function Self:Enumerate(key)
    return Util:TblEnum(Addon.DB.Char.restock, 1, key)
end

---@param item string | number
---@param allChars? boolean
function Self:GetItemCount(item, allChars)
    if type(item) == "string" then item = C_Item.GetItemInfoInstant(item) end

    local count = C_Item.GetItemCount(item, true, false, true, true)

    if C_AddOns.IsAddOnLoaded("TradeSkillMaster") then
        local itemStr = "i:" .. item
        count = count + TSM_API.GetAuctionQuantity(itemStr) + TSM_API.GetMailQuantity(itemStr)

        if allChars then
            local _, accountOwned, _, accountAuctions = TSM_API.GetPlayerTotals(itemStr)
            count = count + accountOwned + accountAuctions
        end
    elseif C_AddOns.IsAddOnLoaded("Syndicator") and Syndicator.API.IsReady() then
        local player, realm = UnitName("player"), GetNormalizedRealmName()
        local info = Syndicator.API.GetInventoryInfoByItemID(item, true, true)

        for _,char in pairs(info.characters) do
            if char.character == player and char.realmNormalized == realm then
                count = count + char.auctions + char.mail
                if not allChars then break end
            elseif allChars then
                count = count + char.auctions + char.mail + char.bags + char.bank
            end
        end
    elseif C_AddOns.IsAddOnLoaded("DataStore_Auctions") and C_AddOns.IsAddOnLoaded("DataStore_Mails") then
        local charKey = DataStore.ThisCharKey
        count = count + DataStore:GetAuctionHouseItemCount(charKey, item) + DataStore:GetMailItemCount(charKey, item)

        if allChars then
            for _,charKey in pairs(DataStore.GetCharacters()) do
                if charKey ~= DataStore.ThisCharKey then
                    count = count + DataStore:GetAuctionHouseItemCount(charKey, item) + DataStore:GetMailItemCount(charKey, item)
                    count = count + DataStore:GetInventoryItemCount(charKey, item) + DataStore:GetPlayerBankItemCount(charKey, item)
                end
            end
        end
    end

    return count
end

---------------------------------------
--              Events
---------------------------------------

---@class Restock.Event
---@field TrackedUpdated "TrackedUpdated"
---@field TrackedMinProfitUpdated "TrackedMinProfitUpdated"

Self:GenerateCallbackEvents({ "TrackedUpdated", "TrackedMinProfitUpdated" })
Self:OnLoad()