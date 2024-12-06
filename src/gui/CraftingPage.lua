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
        ---@diagnostic disable-next-line: inject-field
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
        if not self.sortJob then return end
        self.sortJob:Cancel()
    end)
end

function Self:ModifyRecipeListFilter()
    -- Add sort menu
    local IsSortSelected = Util:FnBind(self.IsSortSelected, self)
    local SetSortSelected = Util:FnBind(self.SetSortSelected, self)

    Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", function (_, rootDescription)
        if ProfessionsFrame:GetTab() ~= ProfessionsFrame.recipesTabID then return end

        local sortSubmenu = rootDescription:Insert(MenuUtil.CreateButton("Sort"), 8) --[[@as ElementMenuDescriptionProxy]]
        sortSubmenu:CreateRadio(NONE, IsSortSelected, SetSortSelected)

        for name,method in pairs(Optimization.Method) do repeat
            if method == Optimization.Method.CostPerConcentration then
                break
            elseif method == Optimization.Method.ProfitPerConcentration then
                name = "Profit per Concentration"
            end

            sortSubmenu:CreateRadio(name, IsSortSelected, SetSortSelected, method)
        until true end
    end)

    -- Update reset filter button state
    local dropdown = self.frame.RecipeList.FilterDropdown
    hooksecurefunc(dropdown, "ValidateResetState", function ()
        if dropdown.ResetButton:IsShown() or not self.sortMethod then return end
        dropdown.ResetButton:SetShown(true)
    end)
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
            Promise:GetCurrent():SetPriority(5)

            for i,recipeID in ipairs(recipeIDs) do
                local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)

                local key, time = cache:Key(recipe), Prices:GetRecipeScanTime(recipe)
                if not cache:Has(key) or cache:Get(key)[1] ~= time then
                    cache:Set(key, { time, Optimization:GetRecipeAllocation(recipe, method) })
                end

                local operation = cache:Get(key)[2]
                if operation then
                    local value = Optimization:GetOperationValue(operation, method)

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

            self.frame.RecipeList.NoResultsText:SetShown(self.dataProvider:IsEmpty())

            -- Fix last recipe not getting sorted correctly
            self.dataProvider:Invalidate()
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

---@param frame ProfessionsRecipeListRecipeFrame
---@param node TreeNodeMixin
function Self:OnRecipeListRecipeInitialized(frame, node)
    self:InitRecipeListRecipe(frame, node)
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
    self:ModifyRecipeListFilter()

    hooksecurefunc(self.frame, "RegisterUnitEvent", Util:FnBind(self.OnRegisterUnitEvent, self))
    hooksecurefunc(self.frame, "UnregisterEvent", Util:FnBind(self.OnUnregisterEvent, self))

    self.frame.RecipeList.ScrollBox.view:RegisterCallback(ScrollBoxListViewMixin.Event.OnInitializedFrame, self.OnRecipeListRecipeInitialized, self)

    hooksecurefunc(Professions, "SetDefaultFilters", Util:FnBind(self.OnSetDefaultFilters, self))
    hooksecurefunc(Professions, "OnRecipeListSearchTextChanged", Util:FnBind(self.OnRecipeListSearchTextChanged, self))

    EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_LIST_UPDATE", self.OnTradeSkillListUpdate, self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)