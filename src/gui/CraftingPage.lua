---@class Addon
local Addon = select(2, ...)
local Cache, GUI, Optimization, Prices, Promise, Util = Addon.Cache, Addon.GUI, Addon.Optimization, Addon.Prices, Addon.Promise, Addon.Util

---@class GUI.CraftingPage
---@field frame CraftingPage
local Self = GUI.CraftingPage

---@type Optimization.Method?
Self.sortMethod = nil
---@type table<Optimization.Method, Cache<{ [1]: number, [2]: Operation }, fun(self: self, recipe: CraftingRecipeSchematic): number>>
Self.sortCaches = {}
---@type TreeDataProviderMixin
Self.dataProvider = CreateTreeDataProvider()

Self.dataProvider:SetSortComparator(function(a, b)
    if not a or not b then return a ~= b and b == nil end
    a, b = a:GetData().value, b:GetData().value
    if Self.sortMethod == Optimization.Method.Cost then return a < b end
    return a > b
end, false, true)

---------------------------------------
--            Hooks
---------------------------------------

function Self:Init()
    if not self.sortMethod then return end

    self:UpdateSort()
end

function Self:ValidateControls()
    if not Addon.enabled then return end

    self.frame.CreateButton:SetEnabled(false)
    self.frame.CreateAllButton:SetEnabled(false)
    self.frame.CreateMultipleInputBox:SetEnabled(false)
    self.frame:SetCreateButtonTooltipText("Experimentation mode is enabled.")
end

---------------------------------------
--            RecipeList
---------------------------------------

function Self:CreateRecipeListProgressBar()
    self.progressBar = CreateFrame("Frame", nil, self.frame.RecipeList, "TestFlightProfessionsRecipeListProgressBarTemplate") --[[@as GUI.ProfessionsRecipeListProgressBar]]

    self.progressBar:SetPoint("BOTTOM", 0, 3)
    self.progressBar:SetPoint("LEFT", 4, 0)
    self.progressBar:SetPoint("RIGHT", -35, 0)
    self.progressBar:Hide()

    self.progressBar.CancelButton:SetScript("OnClick", function()
        if not self.sortJob then return end
        self.sortJob:Cancel()
    end)
end

function Self:CreateRecipeListFilter()
    local dropdown = self.frame.RecipeList.FilterDropdown

    -- Set menu generator without skillLine options
    Professions.InitFilterMenu(dropdown, nil, nil, true)

	dropdown:SetDefaultCallback(function()
		Professions.SetDefaultFilters(false)
	end)

    hooksecurefunc(
        dropdown,
        "menuGenerator",
        ---@param rootDescription RootMenuDescriptionMixin
        function (_, rootDescription)
            local isNPCCrafting = C_TradeSkillUI.IsNPCCrafting()

            -- Add sort option
            local IsSortSelected = Util:FnBind(self.IsSortSelected, self)
            local SetSortSelected = Util:FnBind(self.SetSortSelected, self)

            local sortSubmenu = rootDescription:CreateButton("Sort")
            sortSubmenu:CreateRadio(NONE, IsSortSelected, SetSortSelected)

            for name,method in pairs(Optimization.Method) do repeat
                if method == Optimization.Method.CostPerConcentration then
                    break
                elseif method == Optimization.Method.ProfitPerConcentration then
                    name = "Profit per Concentration"
                end

                sortSubmenu:CreateRadio(name, IsSortSelected, SetSortSelected, method)
            until true end

            -- Add skillLine options
            if isNPCCrafting then return end

            local childProfessionInfos = C_TradeSkillUI.GetChildProfessionInfos()
            if #childProfessionInfos <= 0 then return end

            local function IsExpansionChecked(professionInfo)
                return C_TradeSkillUI.GetChildProfessionInfo().professionID == professionInfo.professionID
            end

            local function SetExpansionChecked(professionInfo)
                EventRegistry:TriggerEvent("Professions.SelectSkillLine", professionInfo)
            end

            rootDescription:CreateSpacer()

            for _,professionInfo in ipairs(childProfessionInfos) do
                rootDescription:CreateRadio(professionInfo.expansionName, IsExpansionChecked, SetExpansionChecked, professionInfo)
            end
        end
    )
end

function Self:IsSortSelected(method)
    return method == Self.sortMethod
end

function Self:SetSortSelected(method)
    self.sortMethod = method

    if method then
        GUI.RecipeForm.CraftingForm:SetOptimizationMethod(method)

        self:UpdateSort(true)
    else
        if self.sortJob then self.sortJob:Cancel() end
        for _,cache in pairs(self.sortCaches) do cache:Clear() end

         self.frame:Init(self.frame.professionInfo)
    end
end

---@param refresh? boolean
function Self:UpdateSort(refresh)
    local method = self.sortMethod ---@cast method -?
    local info = self.frame.professionInfo
    local recipeIDs = C_TradeSkillUI.GetFilteredRecipeIDs() ---@cast recipeIDs -?

    local professionChanged = not self.professionInfo or not Util:TblMatch(self.professionInfo, "professionID", info.professionID, "skillLevel", info.skillLevel, "skillModifier", info.skillModifier)
    local filterChanged = not self.recipeIDs or not Util:TblEquals(self.recipeIDs, recipeIDs)

    self.professionInfo = info
    self.recipeIDs = recipeIDs

    if refresh or professionChanged or filterChanged then
        if self.sortJob then self.sortJob:Cancel() end

        self.dataProvider:GetRootNode():Flush()

        if professionChanged then
            for _,cache in pairs(self.sortCaches) do cache:Clear() end
        end

        if not self.sortCaches[method] then
            self.sortCaches[method] = Cache:Create(function (_, recipe) return recipe.recipeID end)
        end

        local cache = self.sortCaches[method]

        recipeIDs = Util:TblFilter(recipeIDs, function (recipeID)
            return C_TradeSkillUI.IsRecipeInSkillLine(recipeID, info.professionID)
        end)
        local n = #recipeIDs

        self.frame.RecipeList.NoResultsText:SetShown(false)

        self.sortJob = Promise:Async(function ()
            -- Util:DebugProfileStart("Job > Start")

            Promise:GetCurrent():SetPriority(5)

            for i,recipeID in ipairs(recipeIDs) do
                Util:DebugProfileSegment("Recipe > GetRecipeSchematic")

                local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)

                Util:DebugProfileSegment("Recipe > Cache")

                local key, time = cache:Key(recipe), Prices:GetRecipeScanTime(recipe)
                if not cache:Has(key) or cache:Get(key)[1] ~= time then
                    cache:Set(key, { time, Optimization:GetRecipeAllocation(recipe, method) })
                end

                local operation = cache:Get(key)[2]
                if operation then
                    local value = Optimization:GetOperationValue(operation, method)

                    Util:DebugProfileSegment("Recipe > Data Provider Insert")

                    if value and abs(value) ~= math.huge then
                        self.dataProvider:Insert({
                            recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID),
                            allocation = operation.allocation,
                            value = value,
                            method = method,
                            quality = operation:GetQuality()
                        })
                    end
                end

                Promise:YieldProgress(i, n)
            end

            Util:DebugProfileSegment("Job > NoResultsText")

            self.frame.RecipeList.NoResultsText:SetShown(self.dataProvider:IsEmpty())

            Util:DebugProfileSegment("Job > Data Provider Invalidate")

            -- Fix last recipe not getting sorted correctly
            self.dataProvider:Invalidate()

            -- Util:DebugProfileStop()
        end):Start(function ()
            self.progressBar:Start(n)
            return function () self.progressBar:Progress(n, n) end
        end):Progress(function (i, n)
            if not i or not n then return end
            self.progressBar:Progress(i, n)
        end):Finally(function ()
            self.sortJob = nil
        end)
    end

    self.frame.RecipeList.ScrollBox:SetDataProvider(self.dataProvider, ScrollBoxConstants.RetainScrollPosition)
end

function Self:HookElementFactory()
    local view = self.frame.RecipeList.ScrollBox.view

    -- Override recipe list item template
    Util:TblHook(view, "elementFactory", function (factory, node)
        Util:TblGetHooked(view, "elementFactory")(
            function (template, initializer)
                if template == "ProfessionsRecipeListRecipeTemplate" then
                    template = "TestFlightProfessionsRecipeListRecipeTemplate"
                end

                factory(template, initializer)
            end,
            node
        )
    end)
end

---@param ignoreSkillLine? boolean
function Self:ProfessionsIsUsingDefaultFilters(ignoreSkillLine)
    local res = Util:TblGetHooked(Professions, "IsUsingDefaultFilters")(ignoreSkillLine)
    if not res or not self.frame:IsVisible() then return res end

    return not self.sortMethod
end

---------------------------------------
--              Events
---------------------------------------

---@param node TreeNodeMixin
---@param selected boolean
function Self:OnSelectionChanged(node, selected)
    if not selected then return end

    local form, data = GUI.RecipeForm.CraftingForm, node:GetData()

    if data.allocation then
        form:AllocateReagents(data.allocation)
    elseif data.method and data.quality then
        form:SetOptimizationMethod(data.method)
        form:SetQuality(data.quality)
    end
end

-- Search text changed
function Self:OnRecipeListSearchTextChanged()
    if not self.sortMethod or not self.frame:IsVisible() then return end
    self:UpdateSort()
end

-- Filter reset
function Self:OnSetDefaultFilters()
    if not self.sortMethod or not self.frame:IsVisible() then return end
    self:SetSortSelected()
end

-- Filter changed
function Self:OnTradeSkillListUpdate()
    if not self.sortMethod or not self.frame:IsVisible() then return end
    self:UpdateSort()
end

-- Page shown
function Self:OnRegisterUnitEvent(_, event)
    if event ~= "UNIT_AURA" or not self.sortMethod then return end
    self:UpdateSort(true)
end

-- Page hidden
function Self:OnUnregisterEvent(_, event)
    if event ~= "UNIT_AURA" or not self.sortJob then return end
    self.sortJob:Cancel()
end

function Self:OnRefresh()
    if self.frame:IsVisible() then self:ValidateControls() end
end

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    self.frame = ProfessionsFrame.CraftingPage

    hooksecurefunc(self.frame, "Init", Util:FnBind(self.Init, self))
    hooksecurefunc(self.frame, "ValidateControls", Util:FnBind(self.ValidateControls, self))

    self.frame.RecipeList.selectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, self.OnSelectionChanged, self)

    GUI:RegisterCallback(GUI.Event.Refresh, self.OnRefresh, self)

    if not Prices:IsSourceInstalled() then return end

    self:CreateRecipeListProgressBar()
    self:CreateRecipeListFilter()
    self:HookElementFactory()

    hooksecurefunc(self.frame, "RegisterUnitEvent", Util:FnBind(self.OnRegisterUnitEvent, self))
    hooksecurefunc(self.frame, "UnregisterEvent", Util:FnBind(self.OnUnregisterEvent, self))

    Util:TblHook(Professions, "IsUsingDefaultFilters", Util:FnBind(self.ProfessionsIsUsingDefaultFilters, self))
    hooksecurefunc(Professions, "SetDefaultFilters", Util:FnBind(self.OnSetDefaultFilters, self))
    hooksecurefunc(Professions, "OnRecipeListSearchTextChanged", Util:FnBind(self.OnRecipeListSearchTextChanged, self))

    EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_LIST_UPDATE", self.OnTradeSkillListUpdate, self)

end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)