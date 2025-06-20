---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util
local NS = GUI.RecipeFormContainer

---@type GUI.RecipeFormContainer.RecipeFormContainer | GUI.RecipeFormContainer.WithCrafting | GUI.RecipeFormContainer.WithFilterViews
local Parent = Util:TblCombineMixins(NS.RecipeFormContainer, NS.WithCrafting, NS.WithFilterViews)

---@class GUI.RecipeFormContainer.CraftingPage: GUI.RecipeFormContainer.RecipeFormContainer, GUI.RecipeFormContainer.WithCrafting, GUI.RecipeFormContainer.WithFilterViews
---@field frame CraftingPage
---@field filterJob? Promise
local Self = Mixin(GUI.RecipeFormContainer.CraftingPage, Parent)

---------------------------------------
--            Hooks
---------------------------------------

function Self:Init(_, profInfo)
    if not self.filter then return end

    local updateSelected = profInfo ~= self.filterProfessionInfo and profInfo.openRecipeID ~= nil

    self:UpdateRecipeList(false, false, updateSelected)
end

---@param frame CraftingPage
function Self:ValidateControls(frame)
    self:UpdateCreateButton(frame)
end

---------------------------------------
--            CreateButton
---------------------------------------

function Self:InitCreateButton()
    Parent.InitCreateButton(self)

    Util:TblHookScript(self.frame.CreateButton, "OnEnter", self.CreateButtonOnEnter, self)
end

---@param frame? CraftingPage
function Self:UpdateCreateButton(frame)
    if not frame then
        self.frame.ValidateControls(self.frame)
    end

    local craft = Parent.UpdateCreateButton(self)
    if craft then return end

    self.frame.CreateAllButton:SetEnabled(false)
    self.frame.CreateMultipleInputBox:SetEnabled(false)
end

---------------------------------------
--           FilterViews
---------------------------------------

---@param filter? RecipeFormContainer.Filter
---@param sort? Optimization.Method
function Self:SetFilterSelected(filter, sort)
    Parent.SetFilterSelected(self, filter, sort)

    if self.filter then return end

    self.frame:Init(self.frame.professionInfo)
end

---------------------------------------
--              Util
---------------------------------------

function Self:GetProfessionInfo()
    return self.frame.professionInfo
end

---@param operation Operation
---@param amount? number
function Self:CraftOperation(operation, amount)
    local recipe = operation.recipe
    local recipeList = self.frame.RecipeList

    if recipeList.previousRecipeID ~= recipe.recipeID then
        EventRegistry:TriggerEvent("ProfessionsRecipeListMixin.Event.OnRecipeSelected", operation:GetRecipeInfo(), recipeList)
        recipeList.previousRecipeID = recipe.recipeID
    end

    Parent.CraftOperation(self, operation, amount)
end

---------------------------------------
--              Events
---------------------------------------

---@param node RecipeTreeNode
---@param selected boolean
function Self:OnSelectionChanged(node, selected)
    if not selected or self.selectedRestoring or not self.frame:IsVisible() then return end

    local form, data = GUI.RecipeForm.CraftingForm, node:GetData()

    if data.operation then
        form:SetOperation(data.operation, false)

        local amount = min(data.amount or 1, data.operation:GetMaxCraftAmount())
        if amount <= 1 then return end

        self.frame.CreateMultipleInputBox:SetValue(amount)
    elseif data.method and data.quality then
        form:SetOptimizationMethod(data.method)
        form:SetQuality(data.quality)
    end
end

function Self:OnRefresh()
    if self.frame:IsVisible() then self.frame:ValidateControls() end
end

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    self.frame = ProfessionsFrame.CraftingPage
    self.tabID = ProfessionsFrame.recipesTabID
    self.form = GUI.RecipeForm.CraftingForm

    self.recipeList = self.frame.RecipeList

    Parent.OnAddonLoaded(self)

    hooksecurefunc(self.frame, "Init", Util:FnBind(self.Init, self))
    hooksecurefunc(self.frame, "ValidateControls", Util:FnBind(self.ValidateControls, self))

    GUI:RegisterCallback(GUI.Event.Refresh, self.OnRefresh, self)

    self.frame.RecipeList.selectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, self.OnSelectionChanged, self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)