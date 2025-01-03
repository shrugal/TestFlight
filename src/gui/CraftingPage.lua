---@class Addon
local Addon = select(2, ...)
local Cache, GUI, Optimization, Prices, Promise, Reagents, Recipes, Restock, Util = Addon.Cache, Addon.GUI, Addon.Optimization, Addon.Prices, Addon.Promise, Addon.Reagents, Addon.Recipes, Addon.Restock, Addon.Util

---@class GUI.CraftingPage
---@field frame CraftingPage
---@field filterJob? Promise
local Self = GUI.CraftingPage

---@enum CraftingPage.Filter
Self.Filter = {
    Sorted = "SORTED",
    Restock = "RESTOCK",
    Tracked = "TRACKED",
}

---@type CraftingPage.Filter?
Self.filter = nil
---@type Optimization.Method?
Self.sort = nil

---@type Cache<{ [1]: number, [2]: Operation }, fun(self: self, method: Optimization.Method, recipe: CraftingRecipeSchematic): number>
Self.filterCache = Cache:Create(function (_, method, recipe)
    return ("%s;;%s"):format(method, recipe.recipeID)
end)

---@type TreeDataProviderMixin
Self.dataProvider = CreateTreeDataProvider()

Self.dataProvider:SetSortComparator(function(a, b)
    if not a or not b then return a ~= b and b == nil end
    a, b = a:GetData(), b:GetData()
    if (a.amount == 0) ~= (b.amount == 0) then return a.amount ~= 0 end
    if Self:GetFilterSort(Self.filter) == Optimization.Method.Cost then return a.value < b.value end
    return a.value > b.value
end, false, true)

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
    if not frame.GetLabelColor then return end

    local data = node:GetData() --[[@as RecipeTreeNodeData]]
    local value, amount, quality = data.value, data.amount, data.quality
    local r, g, b = frame:GetLabelColor():GetRGB()

    frame:HookScript("OnClick", function (_, buttonName)
        if buttonName ~= "LeftButton" or not IsModifiedClick("RECIPEWATCHTOGGLE") then return end

        if self.filter == self.Filter.Restock then
            local operation, quality, amount = data.operation, data.quality, data.amount
            local recipe = operation.recipe

            if amount <= 0 or not Recipes:IsTracked(recipe) then return end

            Recipes:SetTrackedPerQuality(recipe, quality ~= nil)
            Recipes:SetTrackedAmount(recipe, amount, quality)
            Recipes:SetTrackedAllocation(recipe, operation, quality)
        end
    end)

    -- Set amount
    if amount then
        if not frame.Amount then
            frame.Amount = GUI:InsertFontString(frame, "OVERLAY", "GameFontHighlight_NoShadow")
            frame.Amount:SetPoint("LEFT")
            frame.Amount:SetWidth(26)
            frame.Amount:SetJustifyH("RIGHT")
            frame.Amount:SetHeight(12)
        end

        frame.Amount:Show()
        frame.Amount:SetText(tostring(amount))
        frame.Amount:SetVertexColor(r, g, b)

        -- Adjust other elements
        frame.SkillUps:Hide()
        frame.Label:SetPoint("LEFT", frame.Amount, "RIGHT", 6, 0)
    elseif frame.Amount then
        frame.Amount:Hide()

        -- Adjust other elements
        frame.Label:SetPoint("LEFT", frame.SkillUps, "RIGHT", 4, 0)
    end

    -- Set value
    if value then
        if not frame.Value then
            frame.Value = GUI:InsertFontString(frame, "OVERLAY", "GameFontHighlight_NoShadow")
            frame.Value:SetPoint("RIGHT")
            frame.Value:SetJustifyH("RIGHT")
            frame.Value:SetHeight(12)
        end

        frame.Value:Show()
        frame.Value:SetText(Util(value):RoundCurrency():CurrencyString(false)())
        frame.Value:SetVertexColor(r, value < 0 and 0 or g, value < 0 and 0 or b)

        -- Adjust other elements
        if frame.LockedIcon:IsShown() then
            frame.LockedIcon:ClearAllPoints()
            frame.LockedIcon:SetPoint("RIGHT", frame.Value, "LEFT")
        end
    elseif frame.Value then
        frame.Value:Hide()
    end

    -- Set quality
    if quality then
        frame.Count:Show()
        frame.Count:SetText(" " .. C_Texture.GetCraftingReagentQualityChatIcon(quality))
    elseif value or amount then
        frame.Count:Hide()
    end

    if not (amount or value or quality) then return end

    -- Adjust label
    local padding = 10
    local leftWidth = amount and frame.Amount:GetWidth() + select(4, frame.Label:GetPoint(1)) or frame.SkillUps:GetWidth()
    local countWidth = frame.Count:IsShown() and frame.Count:GetStringWidth() or 0
    local valueWidth = frame.Value and frame.Value:IsShown() and frame.Value:GetWidth() or 0
    local lockedWith = frame.LockedIcon:IsShown() and frame.LockedIcon:GetWidth() or 0
    local width = frame:GetWidth() - (lockedWith + countWidth + padding + leftWidth + valueWidth)

    frame.Label:SetWidth(frame:GetWidth())
    frame.Label:SetWidth(min(width, frame.Label:GetStringWidth()))
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
        local sortSubmenu = rootDescription:Insert(MenuUtil.CreateRadio("Scan", IsFilterSelected, SetFilterSelected, self.Filter.Sorted)) --[[@as ElementMenuDescriptionProxy]]

        for name,method in pairs(Optimization.Method) do repeat
            if method == Optimization.Method.CostPerConcentration then
                break
            elseif method == Optimization.Method.ProfitPerConcentration then
                name = "Profit per Concentration"
            end

            sortSubmenu:CreateRadio(name, IsSortSelected, SetSortSelected, method)
        until true end

        -- Add tracked and restock options
        rootDescription:Insert(MenuUtil.CreateRadio("Queue", IsFilterSelected, SetFilterSelected, self.Filter.Tracked))
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

---@param filter? CraftingPage.Filter
---@param sort? Optimization.Method
function Self:SetFilterSelected(filter, sort)
    if filter == self.Filter.Sorted then
        sort = sort or self.sort or Optimization.Method.Profit
        GUI.RecipeForm.CraftingForm:SetOptimizationMethod(sort)
    else
        sort = filter and self.sort or nil
    end

    self.filter = filter
    self.sort = sort

    if filter then ---@cast sort -?
        self.frame.RecipeList:SetPoint("BOTTOMLEFT", 0, 32.5)
        self:UpdateRecipeList(true)
    else
        self.frame.RecipeList:SetPoint("BOTTOMLEFT", 0, 5)
        self:UpdateFilterButtons()

        if self.filterJob then self.filterJob:Cancel() end
        self.filterCache:Clear()

        self.frame:Init(self.frame.professionInfo)
    end
end

---@param filter? CraftingPage.Filter
function Self:GetFilterSort(filter)
    return filter == self.Filter.Sorted and self.sort or filter and Optimization.Method.Profit or nil
end

---@param refresh? boolean
function Self:UpdateRecipeList(refresh)
    if not self.filter then return end
    local filter, sort = self.filter, self:GetFilterSort(self.filter) --[[@cast filter -?]] --[[@cast sort -?]]

    local profInfo = self.frame.professionInfo
    local professionChanged = not self.professionInfo or not Util:TblMatch(self.professionInfo, "professionID", profInfo.professionID, "skillLevel", profInfo.skillLevel, "skillModifier", profInfo.skillModifier)

    local recipeIDs = self:GetFilterRecipeIDs(filter)
    local n = #recipeIDs
    local filterChanged = not self.recipeIDs or not Util:TblEquals(self.recipeIDs, recipeIDs)

    self.professionInfo = profInfo
    self.recipeIDs = recipeIDs

    local recipeList = self.frame.RecipeList
    local noResultsText = recipeList.NoResultsText
    local selectionBehavior = recipeList.selectionBehavior
    local provider = self.dataProvider

    if professionChanged or recipeList.ScrollBox:GetDataProvider() == provider then
        local selected = selectionBehavior:GetFirstSelectedElementData() --[[@as TreeNodeMixin]]
        if selected then
            local data = selected:GetData() --[[@as RecipeTreeNodeData]]
            self.selectedRecipeID, self.selectedQuality = data.recipeInfo.recipeID, data.quality
        else
            self.selectedRecipeID, self.selectedQuality = recipeList.previousRecipeID, nil
        end
    end

    if refresh or professionChanged or filterChanged then
        provider:GetRootNode():Flush()
        recipeList.ScrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
        selectionBehavior:ClearSelections()

        if professionChanged then self.filterCache:Clear() end

        Promise:Async(function ()
            Promise:GetCurrent():SetPriority(5)

            for i,recipeID in ipairs(recipeIDs) do
                local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
                local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
                local operations = self:GetFilterRecipeOperations(filter, recipe, sort)

                if operations then
                    for _,operation in pairs(operations) do repeat
                        local quality = recipeInfo and recipeInfo.supportsQualities and operation:GetResultQuality() or nil
                        local value = Optimization:GetOperationValue(operation, sort)

                        if not value or abs(value) == math.huge then break end

                        local amount, amountShown, amountTotal = self:GetFilterRecipeAmount(filter, recipe, quality, value)

                        provider:Insert({
                            recipeInfo = recipeInfo,
                            operation = operation,
                            value = value,
                            method = sort,
                            quality =  quality,
                            amount = amount,
                            amountShown = amountShown,
                            amountTotal = amountTotal
                        })
                    until true end
                end

                if recipeID == self.selectedRecipeID and not selectionBehavior:HasSelection() then
                    Promise:Yield(i, n, recipeID) -- Yield so UI can be updated
                else
                    Promise:YieldProgress(i, n, recipeID)
                end
            end

            -- Fix last recipe not getting sorted correctly
            provider:Invalidate()
        end):Singleton(self, "filterJob"):Start(function ()
            noResultsText:SetShown(false)

            self:UpdateFilterButtons()

            self.progressBar:Start(n)

            return function () self.progressBar:Progress(n, n) end
        end):Progress(function (i, n, recipeID)
            if not i or not n then return end

            self.progressBar:Progress(i, n)

            if recipeID == self.selectedRecipeID and not selectionBehavior:HasSelection() then
                self:RestoreSelectedRecipe()
            end
        end):Finally(function ()
            noResultsText:SetShown(provider:IsEmpty())

            self:UpdateFilterButtons()
        end)
    else
        recipeList.ScrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
        self:RestoreSelectedRecipe()
    end
end

function Self:RestoreSelectedRecipe()
    if not self.filter then return end

    local recipeID, quality = self.selectedRecipeID, self.selectedQuality
    if not recipeID then return end

    self.frame.RecipeList.selectionBehavior:SelectFirstElementData(function (node) ---@cast node TreeNodeMixin
        local data = node:GetData() --[[@as RecipeTreeNodeData]]
        return data.recipeInfo.recipeID == recipeID and (not data.quality or not quality or data.quality == quality)
    end)
end

---@param filter CraftingPage.Filter
function Self:GetFilterRecipeIDs(filter)
    local recipeIDs = C_TradeSkillUI.GetFilteredRecipeIDs() ---@cast recipeIDs -?

    if filter == self.Filter.Sorted then
        local professionID = self.frame.professionInfo.professionID

        return Util:TblFilter(recipeIDs, function (recipeID)
            return C_TradeSkillUI.IsRecipeInSkillLine(recipeID, professionID)
        end)
    elseif filter == self.Filter.Tracked then
        return Util:TblFilter(recipeIDs, Recipes.IsTracked, false, Recipes)
    elseif filter == self.Filter.Restock then
        return Util:TblFilter(recipeIDs, Restock.IsTracked, false, Restock)
    end
end

---@param filter CraftingPage.Filter
---@param recipe CraftingRecipeSchematic
---@param method Optimization.Method
---@return Operation[]?
function Self:GetFilterRecipeOperations(filter, recipe, method)
    ---@type table<number, Operation | false>
    local operations
    local Service = Util:Select(filter, self.Filter.Tracked, Recipes, self.Filter.Restock, Restock)

    if Service then
        local amounts = Service:GetTrackedAmounts(recipe) ---@cast amounts -?

        operations = Util:TblMap(amounts, Util.FnFalse) --[[@as table<number, Operation | false>]]

        if filter == self.Filter.Tracked then
            for quality,amount in pairs(amounts) do repeat
                if amount == 0 then break end
                operations[quality] = Recipes:GetTrackedAllocation(recipe, quality) or false
            until true end
        end

        if not Util:TblIncludes(operations, false) then return operations end
    end

    local cache = self.filterCache
    local key, time = cache:Key(method, recipe), Prices:GetRecipeScanTime(recipe)

    if not cache:Has(key) or cache:Get(key)[1] ~= time then
        local includeNonTradable = filter == self.Filter.Tracked
        cache:Set(key, { time, Optimization:GetRecipeAllocations(recipe, method, includeNonTradable) })
    end

    local optimized = cache:Get(key)[2]
    if not operations then return optimized end

    for quality,op in pairs(operations) do repeat
        if op then break end
        operations[quality] = optimized and optimized[quality]
    until true end

    return operations
end

---@param filter CraftingPage.Filter
---@param recipe CraftingRecipeSchematic
---@param quality? number
---@param value number
---@return number? amount
---@return number? amountShown
---@return number? amountTotal
function Self:GetFilterRecipeAmount(filter, recipe, quality, value)
    if filter == self.Filter.Tracked then
        return Recipes:GetTrackedAmount(recipe, quality) --[[@as number]]
    elseif filter == self.Filter.Restock then
        local total = Restock:GetTrackedAmount(recipe, quality)

        if value < Restock:GetTrackedMinProfit(recipe, quality or 1) then return 0, total end

        return Restock:GetTrackedMissing(recipe), total
    end
end

---------------------------------------
--        Filter buttons
---------------------------------------

-- Craft/Restock

function Self:GetNextTrackedCraftable()
    if self.filter ~= self.Filter.Tracked then return end
    if self.dataProvider:IsEmpty() then return end

    return select(2, self.dataProvider:FindByPredicate(function (node)
        local data = node:GetData() --[[@as RecipeTreeNodeData]]
        if not data.amount or not data.operation then return false end
        return data.amount > 0 and data.operation:HasAllReagents()
    end, false))
end

function Self:GetNextTrackedCRestock()
    if self.filter ~= self.Filter.Restock then return end
    if self.dataProvider:IsEmpty() then return end

    return select(2, self.dataProvider:FindByPredicate(function (node)
        return (node:GetData().amount or 0) > 0
    end, false))
end

function Self:CraftRestockButtonOnClick()
    if self.filter == self.Filter.Tracked then
        local node = self:GetNextTrackedCraftable()
        if not node then return end

        local data = node:GetData() --[[@as RecipeTreeNodeData]]
        local operation = data.operation
        local amount = min(data.amount, operation:GetMaxCraftAmount())

        self:CraftOperation(operation, amount)
    elseif self.filter == self.Filter.Restock then
        for _,node in self.dataProvider:EnumerateEntireRange() do repeat
            local data = node:GetData() --[[@as RecipeTreeNodeData]]
            local operation, quality, amount = data.operation, data.quality, data.amount
            local recipe = operation.recipe

            if amount <= 0 then break end

            Recipes:SetTracked(recipe)
            Recipes:SetTrackedPerQuality(recipe, quality ~= nil)
            Recipes:SetTrackedAmount(recipe, amount, quality)
            Recipes:SetTrackedAllocation(recipe, operation, quality)
        until true end
    end
end

-- Prev/Next filter

local filterList = { Self.Filter.Sorted, Self.Filter.Tracked, Self.Filter.Restock }

function Self:PrevFilterButtonOnClick()
    local curr = Util:TblIndexOf(filterList, self.filter) or 0
    self:SetFilterSelected(filterList[curr - 1])
end

function Self:NextFilterButtonOnClick()
    local curr = Util:TblIndexOf(filterList, self.filter) or 0
    self:SetFilterSelected(filterList[curr + 1])
end

-- Insert/Update buttons

function Self:InsertFilterButtons()
    self.craftRestockBtn = GUI:InsertButton(
        "", self.frame, nil, Util:FnBind(self.CraftRestockButtonOnClick, self),
        "TOP", self.frame.RecipeList, "BOTTOM", 0, -3.5
    )

    self.prevFilterBtn = GUI:InsertButton(
        "<", self.frame, nil, Util:FnBind(self.PrevFilterButtonOnClick, self),
        "TOPLEFT", self.frame.RecipeList, "BOTTOMLEFT", 1, -3.5
    )


    self.nextFilterBtn = GUI:InsertButton(
        ">", self.frame, nil, Util:FnBind(self.NextFilterButtonOnClick, self),
        "TOPRIGHT", self.frame.RecipeList, "BOTTOMRIGHT", -1, -3.5
    )

    self.prevFilterBtn.tooltipText = "Previous filter page"
    self.nextFilterBtn.tooltipText = "Next filter page"

    self.craftRestockBtn:Hide()
    self.prevFilterBtn:Hide()
    self.nextFilterBtn:Hide()
end

function Self:UpdateFilterButtons()
    local shown = Util:OneOf(self.filter, self.Filter.Tracked, self.Filter.Restock)
    local enabled = shown and not self.filterJob
    local text = ""

    if self.filter == self.Filter.Restock then
        enabled = enabled and self:GetNextTrackedCRestock() ~= nil
        text = "Restock"
    elseif self.filter == self.Filter.Tracked then
        enabled = enabled and self:GetNextTrackedCraftable() ~= nil
        text = "Create Next"
    end

    self.craftRestockBtn:SetShown(shown)
    self.craftRestockBtn:SetEnabled(enabled)
    self.craftRestockBtn:SetTextToFit(text)

    local shown = self.filter ~= nil
    local curr = Util:TblIndexOf(filterList, self.filter) or 0

    self.prevFilterBtn:SetShown(shown)
    self.nextFilterBtn:SetShown(shown)
    self.prevFilterBtn:SetText(curr > 1 and "<" or "X")
    self.nextFilterBtn:SetEnabled(curr < #filterList)
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
    local recipeList = self.frame.RecipeList

    if recipeList.previousRecipeID ~= recipe.recipeID then
        EventRegistry:TriggerEvent("ProfessionsRecipeListMixin.Event.OnRecipeSelected", operation:GetRecipeInfo(), recipeList)
        recipeList.previousRecipeID = recipe.recipeID
    end

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
    if not selected or not self.frame:IsVisible() then return end

    local form, data = GUI.RecipeForm.CraftingForm, node:GetData() --[[@as RecipeTreeNodeData]]

    if data.operation then
        form:SetOperation(data.operation)

        local amount = min(data.amount or 1, data.operation:GetMaxCraftAmount())
        if amount <= 1 then return end

        self.frame.CreateMultipleInputBox:SetValue(amount)
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

function Self:OnProfessionStatsChanged()
    self.filterCache:Clear()
end

function Self:OnTrackedRecipeUpdated()
    if self.filter ~= self.Filter.Tracked or not self.frame:IsVisible() then return end
    self:UpdateRecipeList(true)
end

function Self:OnTrackedRestockUpdated()
    if self.filter ~= self.Filter.Restock or not self.frame:IsVisible() then return end
    self:UpdateRecipeList(true)
end

function Self:OnOwnedItemsUpdated()
    if not Util:OneOf(self.filter, self.Filter.Restock, self.Filter.Tracked) or not self.frame:IsVisible() then return end
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
    self:InsertFilterButtons()

    hooksecurefunc(self.frame, "RegisterUnitEvent", Util:FnBind(self.OnRegisterUnitEvent, self))
    hooksecurefunc(self.frame, "UnregisterEvent", Util:FnBind(self.OnUnregisterEvent, self))

    self.frame.RecipeList.selectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, self.OnSelectionChanged, self)
    self.frame.RecipeList.ScrollBox.view:RegisterCallback(ScrollBoxListViewMixin.Event.OnInitializedFrame, self.OnRecipeListRecipeInitialized, self)

    hooksecurefunc(Professions, "SetDefaultFilters", Util:FnBind(self.OnSetDefaultFilters, self))
    hooksecurefunc(Professions, "OnRecipeListSearchTextChanged", Util:FnBind(self.OnRecipeListSearchTextChanged, self))

    EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_LIST_UPDATE", self.OnTradeSkillListUpdate, self)

    Addon:RegisterCallback(Addon.Event.ProfessionBuffChanged, self.OnProfessionStatsChanged, self)
    Addon:RegisterCallback(Addon.Event.ProfessionTraitChanged, self.OnProfessionStatsChanged, self)

    local OnTrackedRecipeUpdated = Util:FnDebounce(self.OnTrackedRecipeUpdated, 0)
    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, OnTrackedRecipeUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedAmountUpdated, OnTrackedRecipeUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedAllocationUpdated, OnTrackedRecipeUpdated, self)

    local OnTrackedRestockUpdated = Util:FnDebounce(self.OnTrackedRestockUpdated, 0)
    Restock:RegisterCallback(Restock.Event.TrackedUpdated, OnTrackedRestockUpdated, self)
    Restock:RegisterCallback(Restock.Event.TrackedMinProfitUpdated, OnTrackedRestockUpdated, self)

    local OnOwnedItemsUpdated = Util:FnDebounce(self.OnOwnedItemsUpdated, 1)
    EventRegistry:RegisterFrameEventAndCallback("AUCTION_HOUSE_SHOW_NOTIFICATION", OnOwnedItemsUpdated, self)
    EventRegistry:RegisterFrameEventAndCallback("AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION", OnOwnedItemsUpdated, self)
    EventRegistry:RegisterFrameEventAndCallback("UPDATE_PENDING_MAIL", OnOwnedItemsUpdated, self)
    EventRegistry:RegisterFrameEventAndCallback("UNIT_INVENTORY_CHANGED", OnOwnedItemsUpdated, self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)

---------------------------------------
--              Types
---------------------------------------

---@alias RecipeTreeNodeData { recipeInfo: TradeSkillRecipeInfo, operation: Operation, value: number, method: Optimization.Method, quality: number, amount?: number, total?: number }