---@class Addon
local Addon = select(2, ...)
local Cache, GUI, Optimization, Prices, Promise, Reagents, Recipes, Util = Addon.Cache, Addon.GUI, Addon.Optimization, Addon.Prices, Addon.Promise, Addon.Reagents, Addon.Recipes, Addon.Util

---@class GUI.CraftingPage
---@field frame CraftingPage
---@field filterJob? Promise
local Self = GUI.CraftingPage

---@enum CraftingPage.Filter
Self.Filter = {
    Sorted = "SORTED",
    Tracked = "TRACKED",
    Restock = "RESTOCK",
}

Self.FilterSortComparators = {
    [Self.Filter.Sorted] = function(a, b)
        if not a or not b then return a ~= b and b == nil end
        a, b = a:GetData().value, b:GetData().value
        if Self.sort == Optimization.Method.Cost then return a < b end
        return a > b
    end,
}

---@type CraftingPage.Filter?
Self.filter = nil
---@type Optimization.Method?
Self.sort = nil

---@type Cache<{ [1]: number, [2]: Operation }, fun(self: self, recipe: CraftingRecipeSchematic): number>
Self.filterCache = Cache:Create(function (_, recipe) return recipe.recipeID end)
---@type TreeDataProviderMixin
Self.dataProvider = CreateTreeDataProvider()

---------------------------------------
--            Hooks
---------------------------------------

function Self:Init()
    if not self.filter then return end

    self:UpdateRecipeList()
end

function Self:ValidateControls()
    if not Addon.enabled then return end

    self.frame.CreateButton:SetEnabled(false)
    self.frame.CreateAllButton:SetEnabled(false)
    self.frame.CreateMultipleInputBox:SetEnabled(false)

    self.frame:SetCreateButtonTooltipText("Experimentation mode is enabled.")
    self.frame.CreateButton:SetScript("OnLeave", GameTooltip_Hide)
    self.frame.CreateAllButton:SetScript("OnLeave", GameTooltip_Hide)
end

---------------------------------------
--            RecipeList
---------------------------------------

---@param frame ProfessionsRecipeListRecipeFrame
---@param node TreeNodeMixin
function Self:InitRecipeListRecipe(frame, node)
    local value = node:GetData().value

    if not value then
        if frame.Value then frame.Value:Hide() end
        return
    end

    -- Set value
    if not frame.Value then
        frame.Value = GUI:InsertFontString(frame, "OVERLAY", "GameFontHighlight_NoShadow")
        frame.Value:SetPoint("RIGHT")
        frame.Value:SetJustifyH("RIGHT")
        frame.Value:SetHeight(12)
    end

    frame.Value:Show()
    frame.Value:SetText(Util(value):RoundCurrency():CurrencyString(false)())

    local r, g, b = frame:GetLabelColor():GetRGB()
    if value < 0 then g, b = 0, 0 end
    frame.Value:SetVertexColor(r, g, b)

    -- Adjust label
    local padding = 10
    local lockedWith = frame.LockedIcon:IsShown() and frame.LockedIcon:GetWidth() or 0
    local countWidth = frame.Count:IsShown() and frame.Count:GetStringWidth() or 0
    local width = frame:GetWidth() - (lockedWith + countWidth + padding + frame.SkillUps:GetWidth() + frame.Value:GetWidth())

    frame.Label:SetWidth(frame:GetWidth())
    frame.Label:SetWidth(min(width, frame.Label:GetStringWidth()))

    -- Adjust locked icon
    if frame.LockedIcon:IsShown() then
        frame.LockedIcon:ClearAllPoints()
        frame.LockedIcon:SetPoint("RIGHT", frame.Value, "LEFT")
    end
end

function Self:CreateRecipeListProgressBar()
    self.progressBar = CreateFrame("Frame", nil, self.frame.RecipeList, "TestFlightProfessionsRecipeListProgressBarTemplate") --[[@as GUI.ProfessionsRecipeListProgressBar]]

    self.progressBar:SetPoint("BOTTOM", 0, 3)
    self.progressBar:SetPoint("LEFT", 4, 0)
    self.progressBar:SetPoint("RIGHT", -35, 0)
    self.progressBar:Hide()

    self.progressBar.CancelButton:SetScript("OnClick", function()
        if not self.filterJob then return end
        self.filterJob:Cancel()
    end)
end

function Self:ModifyRecipeListFilter()
    local IsFilterSelected = function (filter) return self:IsFilterSelected(filter) end
    local SetFilterSelected = function (filter) self:SetFilterSelected(filter) return 4 end
    local IsSortSelected = function (sort) return self:IsFilterSelected(self.Filter.Sorted, sort) end
    local SetSortSelected = function (sort) self:SetFilterSelected(self.Filter.Sorted, sort) return 4 end

    Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", function (_, rootDescription)
        if ProfessionsFrame:GetTab() ~= ProfessionsFrame.recipesTabID then return end

        rootDescription:Insert(MenuUtil.CreateSpacer())
        rootDescription:Insert(MenuUtil.CreateTitle("TestFlight"))
        rootDescription:Insert(MenuUtil.CreateRadio(NONE, IsFilterSelected, SetFilterSelected))

        -- Add sort menu
        local sortSubmenu = rootDescription:Insert(MenuUtil.CreateRadio("Sorted", IsFilterSelected, SetFilterSelected, self.Filter.Sorted)) --[[@as ElementMenuDescriptionProxy]]

        for name,method in pairs(Optimization.Method) do repeat
            if method == Optimization.Method.CostPerConcentration then
                break
            elseif method == Optimization.Method.ProfitPerConcentration then
                name = "Profit per Concentration"
            end

            sortSubmenu:CreateRadio(name, IsSortSelected, SetSortSelected, method)
        until true end

        -- Add tracked and restock options
        rootDescription:Insert(MenuUtil.CreateRadio("Tracked", IsFilterSelected, SetFilterSelected, self.Filter.Tracked))
        rootDescription:Insert(MenuUtil.CreateRadio("Restock", IsFilterSelected, SetFilterSelected, self.Filter.Restock))
    end)

    -- Update reset filter button state
    local dropdown = self.frame.RecipeList.FilterDropdown
    hooksecurefunc(dropdown, "ValidateResetState", function ()
        if dropdown.ResetButton:IsShown() or not self.filter then return end
        dropdown.ResetButton:SetShown(true)
    end)
end

function Self:IsFilterSelected(filter, sort)
    return filter == self.filter and (not sort or self.sort == sort)
end

function Self:SetFilterSelected(filter, sort)
    if filter ~= self.Filter.Sorted then
        sort = nil
    elseif not sort then
        sort = self.sort or Optimization.Method.Profit
    end

    self.filter = filter
    self.sort = sort

    -- Adjust recipe list
    if Util:OneOf(filter, self.Filter.Tracked, self.Filter.Restock) then
        self.frame.RecipeList:SetPoint("BOTTOMLEFT", 0, 32.5)
    else
        self.frame.RecipeList:SetPoint("BOTTOMLEFT", 0, 5)
    end

    self:UpdateCraftRestockButton()

    -- Update
    if filter then
        if sort then
            GUI.RecipeForm.CraftingForm:SetOptimizationMethod(sort)
        end

        self:UpdateRecipeList(true)
    else
        if self.filterJob then self.filterJob:Cancel() end
        self.filterCache:Clear()

        self.frame:Init(self.frame.professionInfo)
    end
end

---@param refresh? boolean
function Self:UpdateRecipeList(refresh)
    local method = self.sort or Optimization.Method.Profit ---@cast method -?

    local info = self.frame.professionInfo
    local professionChanged = not self.professionInfo or not Util:TblMatch(self.professionInfo, "professionID", info.professionID, "skillLevel", info.skillLevel, "skillModifier", info.skillModifier)

    refresh = refresh or professionChanged

    local recipeIDs = self:GetFilterRecipeIDs()
    local n = #recipeIDs
    local filterChanged = not self.recipeIDs or not Util:TblEquals(self.recipeIDs, recipeIDs)

    self.professionInfo = info
    self.recipeIDs = recipeIDs

    if refresh or filterChanged then
        self.dataProvider:GetRootNode():Flush()
        self.dataProvider:SetSortComparator(self:GetFilterSortComparator(), false, true)

        self:UpdateCraftRestockButton()

        if refresh then self.filterCache:Clear() end

        self.frame.RecipeList.NoResultsText:SetShown(false)

        Promise:Async(function ()
            Promise:GetCurrent():SetPriority(5)

            for i,recipeID in ipairs(recipeIDs) do
                local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
                local operation = self:GetFilterRecipeOperation(recipe, method)

                if operation then
                    local value = Optimization:GetOperationValue(operation, method)

                    if value and abs(value) ~= math.huge then
                        self.dataProvider:Insert({
                            recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID),
                            operation = operation,
                            value = value,
                            method = method,
                            quality = operation:GetQuality(),
                            amount = self:GetFilterRecipeAmount(recipe)
                        })
                    end
                end

                Promise:YieldProgress(i, n)
            end

            self.frame.RecipeList.NoResultsText:SetShown(self.dataProvider:IsEmpty())

            -- Fix last recipe not getting sorted correctly
            self.dataProvider:Invalidate()
        end):Singleton(self, "filterJob"):Start(function ()
            self.progressBar:Start(n)
            return function () self.progressBar:Progress(n, n) end
        end):Progress(function (i, n)
            if not i or not n then return end
            self.progressBar:Progress(i, n)
        end):Finally(function ()
            self:UpdateCraftRestockButton()
        end)
    end

    self.frame.RecipeList.ScrollBox:SetDataProvider(self.dataProvider, ScrollBoxConstants.RetainScrollPosition)
end

function Self:GetFilterRecipeIDs()
    local recipeIDs = C_TradeSkillUI.GetFilteredRecipeIDs() ---@cast recipeIDs -?

    if self.filter == self.Filter.Sorted then
        local professionID = self.frame.professionInfo.professionID

        return Util:TblFilter(recipeIDs, function (recipeID)
            return C_TradeSkillUI.IsRecipeInSkillLine(recipeID, professionID)
        end)
    elseif self.filter == self.Filter.Tracked then
        return Util:TblFilter(recipeIDs, function (recipeID)
            return (Recipes:GetTrackedAmount(recipeID, false) or 0) > 0
        end)
    else
        return {} ---@todo
    end
end

function Self:GetFilterSortComparator()
    if self.filter == self.Filter.Sorted then
        return function(a, b)
            if not a or not b then return a ~= b and b == nil end
            a, b = a:GetData().value, b:GetData().value
            if Self.sort == Optimization.Method.Cost then return a < b end
            return a > b
        end
    end
end

---@param recipe CraftingRecipeSchematic
---@param method Optimization.Method
function Self:GetFilterRecipeOperation(recipe, method)
    if self.filter == self.Filter.Tracked then
        local op = Recipes:GetTrackedAllocation(recipe)
        if op then return op end
    end

    local cache = self.filterCache
    local key, time = cache:Key(recipe), Prices:GetRecipeScanTime(recipe)

    if not cache:Has(key) or cache:Get(key)[1] ~= time then
        local includeNonTradable = Util:OneOf(self.filter, self.Filter.Tracked, self.Filter.Restock)
        cache:Set(key, { time, Optimization:GetRecipeAllocation(recipe, method, includeNonTradable) })
    end

    return cache:Get(key)[2]
end

---@param recipe CraftingRecipeSchematic
function Self:GetFilterRecipeAmount(recipe)
    if self.filter == self.Filter.Tracked then
        return Recipes:GetTrackedAmount(recipe) --[[@as number]]
    elseif self.filter == self.Filter.Restock then
        return 1 ---@todo
    end
end

---------------------------------------
--        Craft/Restock button
---------------------------------------

function Self:CraftRestockButtonOnClick()
    if self.filter == self.Filter.Tracked then
        local node = select(2, self.dataProvider:FindByPredicate(function (node)
            local data = node:GetData() --[[@as RecipeTreeNodeData]]
            return data.operation:HasAllReagents()
        end, false))

        if not node then return end

        local data = node:GetData() --[[@as RecipeTreeNodeData]]
        local operation = data.operation
        local amount = min(data.amount, operation:GetMaxCraftAmount())

        self:CraftOperation(operation, amount)
    elseif self.filter == self.Filter.Restock then
        for _,node in self.dataProvider:EnumerateEntireRange() do
            local data = node:GetData() --[[@as RecipeTreeNodeData]]
            local operation, amount = data.operation, data.amount
            local recipe = operation.recipe

            Recipes:SetTracked(recipe)
            Recipes:SetTrackedAmount(recipe, amount)
            Recipes:SetTrackedQuality(recipe, operation:GetResultQuality())
            Recipes:SetTrackedAllocation(recipe, operation)
        end
    end
end

function Self:InsertCraftRestockButton()
    self.craftRestockBtn = GUI:InsertButton(
        "", self.frame, nil, Util:FnBind(self.CraftRestockButtonOnClick, self),
        "TOP", self.frame.RecipeList, "BOTTOM", 0, -5
    )

    self.craftRestockBtn:Hide()
end

function Self:UpdateCraftRestockButton()
    self.craftRestockBtn:SetShown(Util:OneOf(self.filter, self.Filter.Tracked, self.Filter.Restock))
    self.craftRestockBtn:SetEnabled(not self.filterJob and not self.dataProvider:IsEmpty())

    if self.filter == self.Filter.Tracked then
        self.craftRestockBtn:SetTextToFit("Create Next")
    elseif self.filter == self.Filter.Restock then
        self.craftRestockBtn:SetTextToFit("Restock")
    end
end

---------------------------------------
--              Util
---------------------------------------

---@param operation Operation
---@param amount? number
function Self:CraftOperation(operation, amount)
    local recipe = operation.recipe
    local reagents = operation:GetReagents()
    local applyConcentration = operation.applyConcentration

    local form = GUI.RecipeForm.CraftingForm

    ProfessionsUtil.OpenProfessionFrameToRecipe(recipe.recipeID)

    form:SetOperation(operation)

    if recipe.recipeType == Enum.TradeskillRecipeType.Enchant then
        local item = Reagents:GetEnchantVellum(recipe)
        if not item then return end

        form.form.transaction:SetEnchantAllocation(item)

        if amount > 1 then self.frame.vellumItemID = item:GetItemID() end

        C_TradeSkillUI.CraftEnchant(recipe.recipeID, amount, reagents, item:GetItemLocation(), applyConcentration)
    elseif recipe.recipeType == Enum.TradeskillRecipeType.Item then
        C_TradeSkillUI.CraftRecipe(recipe.recipeID, amount, reagents, nil, nil, applyConcentration)
    end
end

---------------------------------------
--              Events
---------------------------------------

---@param node TreeNodeMixin
---@param selected boolean
function Self:OnSelectionChanged(node, selected)
    if not selected then return end

    local form, data = GUI.RecipeForm.CraftingForm, node:GetData()

    if data.operation then
        form:SetOperation(data.operation)
    elseif data.method and data.quality then
        form:SetOptimizationMethod(data.method)
        form:SetQuality(data.quality)
    end
end

-- Search text changed
function Self:OnRecipeListSearchTextChanged()
    if not self.filter or not self.frame:IsVisible() then return end
    self:UpdateRecipeList()
end

-- Filter reset
function Self:OnSetDefaultFilters()
    if not self.filter or not self.frame:IsVisible() then return end
    self:SetFilterSelected()
end

-- Filter changed
function Self:OnTradeSkillListUpdate()
    if not self.filter or not self.frame:IsVisible() then return end
    self:UpdateRecipeList()
end

-- Page shown
function Self:OnRegisterUnitEvent(_, event)
    if event ~= "UNIT_AURA" or not self.filter then return end
    self:UpdateRecipeList(true)
end

-- Page hidden
function Self:OnUnregisterEvent(_, event)
    if event ~= "UNIT_AURA" or not self.filterJob then return end
    self.filterJob:Cancel()
end

function Self:OnRefresh()
    if self.frame:IsVisible() then self:ValidateControls() end
end

---@param frame ProfessionsRecipeListRecipeFrame
---@param node TreeNodeMixin
function Self:OnRecipeListRecipeInitialized(frame, node)
    self:InitRecipeListRecipe(frame, node)
end

function Self:OnProfessionChanged()
    self.filterCache:Clear()
end

function Self:OnTrackedRecipeUpdated()
    if self.filter ~= self.Filter.Tracked or not self.frame:IsVisible() then return end
    self:UpdateRecipeList(true)
end

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    self.frame = ProfessionsFrame.CraftingPage

    hooksecurefunc(self.frame, "Init", Util:FnBind(self.Init, self))
    hooksecurefunc(self.frame, "ValidateControls", Util:FnBind(self.ValidateControls, self))

    GUI:RegisterCallback(GUI.Event.Refresh, self.OnRefresh, self)

    if not Prices:IsSourceInstalled() then return end

    self:CreateRecipeListProgressBar()
    self:ModifyRecipeListFilter()
    self:InsertCraftRestockButton()

    hooksecurefunc(self.frame, "RegisterUnitEvent", Util:FnBind(self.OnRegisterUnitEvent, self))
    hooksecurefunc(self.frame, "UnregisterEvent", Util:FnBind(self.OnUnregisterEvent, self))

    self.frame.RecipeList.selectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, self.OnSelectionChanged, self)
    self.frame.RecipeList.ScrollBox.view:RegisterCallback(ScrollBoxListViewMixin.Event.OnInitializedFrame, self.OnRecipeListRecipeInitialized, self)

    hooksecurefunc(Professions, "SetDefaultFilters", Util:FnBind(self.OnSetDefaultFilters, self))
    hooksecurefunc(Professions, "OnRecipeListSearchTextChanged", Util:FnBind(self.OnRecipeListSearchTextChanged, self))

    EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_LIST_UPDATE", self.OnTradeSkillListUpdate, self)

    Addon:RegisterCallback(Addon.Event.ProfessionBuffChanged, self.OnProfessionChanged, self)
    Addon:RegisterCallback(Addon.Event.ProfessionTraitChanged, self.OnProfessionChanged, self)

    local OnTrackedRecipeUpdated = Util:FnDebounce(self.OnTrackedRecipeUpdated, 0)
    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, OnTrackedRecipeUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedAmountUpdated, OnTrackedRecipeUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedAllocationUpdated, OnTrackedRecipeUpdated, self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)

---------------------------------------
--              Types
---------------------------------------

---@alias RecipeTreeNodeData { recipeInfo: TradeSkillRecipeInfo, operation: Operation, value: number, method: Optimization.Method, quality: number, amount?: number }