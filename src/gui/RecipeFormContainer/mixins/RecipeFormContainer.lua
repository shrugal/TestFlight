---@class Addon
local Addon = select(2, ...)
local GUI, Reagents = Addon.GUI, Addon.Reagents
local NS = GUI.RecipeFormContainer

---@class GUI.RecipeFormContainer.RecipeFormContainer
---@field frame RecipeFormContainer
---@field form GUI.RecipeForm.RecipeForm
local Self = NS.RecipeFormContainer

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

    form:SetOperation(operation)

    if recipe.recipeType == Enum.TradeskillRecipeType.Enchant then
        local item = Reagents:GetEnchantVellum(recipe)
        if not item then return end

        form.form.transaction:SetEnchantAllocation(item)

        if amount > 1 then self.frame.vellumItemID = item:GetItemID() end
    end

    operation:Craft(amount)
end