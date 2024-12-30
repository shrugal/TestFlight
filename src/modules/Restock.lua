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
    local qualities = self:GetRecipeQualities(recipeOrOrder)
    return qualities and (not quality or qualities[quality] ~= nil) or false
end

function Self:GetTrackedIDs()
    return Util:TblKeys(Addon.DB.Char.restock)
end

---@param recipeOrOrder RecipeOrOrder
---@param quality? number
function Self:GetTrackedAmount(recipeOrOrder, quality)
    if not self:IsTracked(recipeOrOrder, quality) then return end
    local qualities = self:GetRecipeQualities(recipeOrOrder)
    return quality and qualities[quality] or Util:TblReduce(qualities, Util.FnAdd, 0)
end

---@param recipe CraftingRecipeSchematic
---@param quality? number
function Self:GetTrackedOwned(recipe, quality)
    if not self:IsTracked(recipe, quality) then return end

    if quality then
        local itemID = Recipes:GetResult(recipe, nil, nil, quality)
        if not itemID then return end
        return C_Item.GetItemCount(itemID, true, false, true, true)
    end

    local owned = 0
    for quality in pairs(self:GetRecipeQualities(recipe)) do
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
function Self:GetTrackedQualities(recipeOrOrder)
    if not self:IsTracked(recipeOrOrder) then return end
    return self:GetRecipeQualities(recipeOrOrder)
end

-- Set

---@param recipeOrOrder RecipeOrOrder
---@param quality number
---@param amount? number
function Self:SetTracked(recipeOrOrder, quality, amount)
    if amount and amount < 0 then amount = 0 end
    if amount == 0 then amount = nil end

    local recipeID = Recipes:GetRecipeInfo(recipeOrOrder)
    local qualities = self:GetRecipeQualities(recipeOrOrder, amount ~= nil)

    if not qualities or qualities[quality] == amount then return end

    qualities[quality] = amount

    if not amount and Util:TblCount(qualities) == 0 then
        Addon.DB.Char.restock[recipeID] = nil
    end

    self:TriggerEvent(Self.Event.TrackedUpdated, recipeID, quality, amount or 0)
end

---------------------------------------
--              Util
---------------------------------------

---@param key? boolean
function Self:Enumerate(key)
    return Util:TblEnum(Addon.DB.Char.restock, 1, key)
end

---@param recipeOrOrder RecipeOrOrder
function Self:GetRecipeQualities(recipeOrOrder, create)
    local recipeID = Recipes:GetRecipeInfo(recipeOrOrder)
    local qualities = Addon.DB.Char.restock[recipeID]

    if not qualities and create then
        qualities = {}
        Addon.DB.Char.restock[recipeID] = qualities
    end

    return qualities
end

---------------------------------------
--              Events
---------------------------------------

---@class Restock.Event
---@field TrackedUpdated "TrackedUpdated"

Self:GenerateCallbackEvents({ "TrackedUpdated" })
Self:OnLoad()