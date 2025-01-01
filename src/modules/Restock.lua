---@class Addon
local Addon = select(2, ...)
local Recipes, Util = Addon.Recipes, Addon.Util

---@class Restock: CallbackRegistryMixin
---@field Event Restock.Event
local Self = Mixin(Addon.Restock, CallbackRegistryMixin)

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
        local itemID = Recipes:GetResult(recipe, nil, nil, quality)
        if not itemID then return end
        return self:GetItemCount(itemID)
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

    return total - owned
end

---@param recipeOrOrder RecipeOrOrder
---@param create? boolean
function Self:GetTrackedAmounts(recipeOrOrder, create)
    local recipeID = Recipes:GetRecipeInfo(recipeOrOrder)
    local amounts = Addon.DB.Char.restock[recipeID]

    if not amounts and create then
        amounts = {}
        Addon.DB.Char.restock[recipeID] = amounts
    end

    return amounts
end

-- Set

---@param recipeOrOrder RecipeOrOrder
---@param quality number
---@param amount? number
function Self:SetTracked(recipeOrOrder, quality, amount)
    if amount and amount < 0 then amount = 0 end
    if amount == 0 then amount = nil end

    local recipeID = Recipes:GetRecipeInfo(recipeOrOrder)
    local amounts = self:GetTrackedAmounts(recipeOrOrder, amount ~= nil)

    if not amounts or amounts[quality] == amount then return end

    amounts[quality] = amount

    if not amount and Util:TblCount(amounts) == 0 then
        Addon.DB.Char.restock[recipeID] = nil
    end

    self:TriggerEvent(Self.Event.TrackedUpdated, recipeID, quality, amount or 0)
end

---------------------------------------
--              Stock
---------------------------------------

function Self:GetItemCount(itemID)
    local count = C_Item.GetItemCount(itemID, true, false, true, true)

    if C_AddOns.IsAddOnLoaded("TradeSkillMaster") then
        local itemStr = "i:" .. itemID
        count = count + TSM_API.GetAuctionQuantity(itemStr)
        count = count + TSM_API.GetMailQuantity(itemStr)
    elseif C_AddOns.IsAddOnLoaded("Syndicator") and Syndicator.API.IsReady() then
        local info = Syndicator.API.GetInventoryInfoByItemID(itemID, true, true)
        local char = Util:TblWhere(info.characters, "character", UnitName("player"), "realmNormalized", GetNormalizedRealmName())
        if char then count = count + char.auctions + char.mail end
    elseif C_AddOns.IsAddOnLoaded("DataStore_Auctions") and C_AddOns.IsAddOnLoaded("DataStore_Mails") then
        local charID = DataStore.ThisCharID
        count = count + DataStore.GetAuctionHouseItemCount(charID, itemID)
        count = count + DataStore.GetMailItemCount(charID, itemID)
    end

    return count
end

---------------------------------------
--              Util
---------------------------------------

---@param key? boolean
function Self:Enumerate(key)
    return Util:TblEnum(Addon.DB.Char.restock, 1, key)
end

---------------------------------------
--              Events
---------------------------------------

---@class Restock.Event
---@field TrackedUpdated "TrackedUpdated"

Self:GenerateCallbackEvents({ "TrackedUpdated" })
Self:OnLoad()