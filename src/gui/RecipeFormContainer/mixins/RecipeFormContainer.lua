---@class Addon
local Addon = select(2, ...)
local Buffs, GUI, Reagents = Addon.Buffs, Addon.GUI, Addon.Reagents
local NS = GUI.RecipeFormContainer

---@class GUI.RecipeFormContainer.RecipeFormContainer
---@field frame RecipeFormContainer
---@field tabID number
---@field form GUI.RecipeForm.RecipeForm
local Self = NS.RecipeFormContainer

function Self:ModifyRecipeListFilter()
    Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", function (_, rootDescription)
        if ProfessionsFrame:GetTab() ~= self.tabID then return end

        Buffs:AddAuraFilters(rootDescription, true)
    end)
end

---------------------------------------
--              Util
---------------------------------------

function Self:GetProfessionInfo()
    return Professions.GetProfessionInfo()
end

---@param operation Operation
---@param amount? number
function Self:CraftOperation(operation, amount)
    local recipe = operation.recipe
    local form = GUI.RecipeForm.CraftingForm

    if not form:SetOperation(operation, true) then return end

    if recipe.recipeType == Enum.TradeskillRecipeType.Enchant then
        local item = Reagents:GetEnchantVellum(recipe)
        if not item then return end

        form.form.transaction:SetEnchantAllocation(item)

        if amount > 1 then self.frame.vellumItemID = item:GetItemID() end
    end

    operation:Craft(amount)
end

function Self:OnAddonLoaded()
    self:ModifyRecipeListFilter()
end