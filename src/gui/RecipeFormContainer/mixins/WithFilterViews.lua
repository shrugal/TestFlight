---@class Addon
local Addon = select(2, ...)
local Buffs, Cache, GUI, Optimization, Prices, Promise, Reagents, Recipes, Restock, Util = Addon.Buffs, Addon.Cache, Addon.GUI, Addon.Optimization, Addon.Prices, Addon.Promise, Addon.Reagents, Addon.Recipes, Addon.Restock, Addon.Util
local NS = GUI.RecipeFormContainer

---@type GUI.RecipeFormContainer.RecipeFormContainer
local Parent = NS.RecipeFormContainer

---@class GUI.RecipeFormContainer.WithFilterViews: GUI.RecipeFormContainer.RecipeFormContainer, GUI.RecipeFormContainer.WithCrafting
---@field frame RecipeFormContainer
---@field recipeList RecipeList
---@field filterJob? Promise
local Self = GUI.RecipeFormContainer.WithFilterViews

---@enum RecipeFormContainer.Filter
Self.Filter = {
    Scan = "SCAN",
    Queue = "QUEUE",
    Restock = "RESTOCK",
}

---@type table<RecipeFormContainer.Filter, fun(a: RecipeTreeNode, b: RecipeTreeNode): boolean>
Self.SortComparator = {
    [Self.Filter.Scan] = function(a, b)
        if a and b then
            local a, b = a:GetData(), b:GetData()
            -- Sort by name if no value
            if not a.value or not b.value then return a.recipeInfo.name < b.recipeInfo.name end
            -- Low price before high price
            if Self:GetFilterSort(Self.filter) == Optimization.Method.Cost then return a.value < b.value end
            -- High profit before low profit
            return a.value > b.value
        end
        return a ~= b and b == nil
    end,
    [Self.Filter.Restock] = function (a, b)
        if a and b then
            local a, b = a:GetData(), b:GetData()
            -- Non zero amount before zero amount
            if (a.amount ~= 0) ~= (b.amount ~= 0) then return a.amount ~= 0 end
        end
        return Self.SortComparator[Self.Filter.Scan](a, b)
    end,
    [Self.Filter.Queue] = function (a, b)
        if a and b then
            local a, b = a:GetData(), b:GetData()
            local amounts = Self.Cache.CurrentCraftAmount
            local aMaxAmount, bMaxAmount = amounts:Val(a), amounts:Val(b)

            -- Craftable before non craftable
            local aCraftable, bCraftable = aMaxAmount > 0, bMaxAmount > 0
            if aCraftable ~= bCraftable then return aCraftable end

            -- Non missing aura before missing aura
            local auras = Self.Cache.CurrentMissingAura
            local aAura, bAura = auras:Val(a), auras:Val(b)
            if (not aAura ~= not bAura) then return not aAura end

            -- Has tool before not has tool
            local currentTool = Buffs:GetCurrentTool(a.operation:GetProfessionInfo().profession)
            local aHasTool = (a.operation.toolGUID or currentTool) == currentTool
            local bHasTool = (b.operation.toolGUID or currentTool) == currentTool
            if aHasTool ~= bHasTool then return aHasTool end

            -- Full craftable before non full craftable
            local aFullCraftable = aCraftable and a.amount <= aMaxAmount
            local bFullCraftable = bCraftable and b.amount <= bMaxAmount
            if aFullCraftable ~= bFullCraftable then return aFullCraftable end
        end
        return Self.SortComparator[Self.Filter.Restock](a, b)
    end,
}

---@type RecipeFormContainer.Filter?
Self.filter = nil
---@type Optimization.Method?
Self.sort = nil

---@type TreeDataProviderMixin
Self.dataProvider = CreateTreeDataProvider()

---------------------------------------
--            RecipeList
---------------------------------------

---@param frame RecipeList
---@param recipeInfo TradeSkillRecipeInfo | { favoritesInstance?: boolean }
---@param scrollToRecipe? boolean
function Self:RecipeListSelectRecipe(frame, recipeInfo, scrollToRecipe)
    local node = self.recipeList.selectionBehavior:GetFirstSelectedElementData() --[[@as RecipeTreeNode?]]
    local data = node and node:GetData()

    -- Skip if recipe is already selected, to prevent selecting a different quality
    if data and data.recipeInfo and Util:TblMatch(data.recipeInfo, "recipeID", recipeInfo.recipeID, "favoritesInstance", recipeInfo.favoritesInstance) then
        return
    end

    return Util:TblGetHooked(frame, "SelectRecipe")(frame, recipeInfo, scrollToRecipe)
end

---@param frame ProfessionsRecipeListRecipeFrame
---@param node RecipeTreeNode
---@param reuse? boolean
function Self:InitRecipeListRecipe(frame, node, reuse)
    if not frame.GetLabelColor then return end

    local data = node:GetData()

    -- Hook OnClick
    if not reuse then
        frame:HookScript("OnClick", function (_, buttonName)
            if buttonName ~= "LeftButton" or not self.filter then return end

            if not IsModifiedClick("RECIPEWATCHTOGGLE") then
                self.selectedRecipeID = data.recipeInfo.recipeID
                self.selectedQuality = data.quality
            elseif self.filter == self.Filter.Restock then
                local operation, quality, amount = data.operation, data.quality, data.amount
                if not operation or not amount then return end
                local recipe = operation.recipe

                if amount <= 0 or not Recipes:IsTracked(recipe) then return end

                Recipes:SetTrackedPerQuality(recipe, quality ~= nil)
                Recipes:SetTrackedAmount(recipe, amount, quality)
                Recipes:SetTrackedAllocation(recipe, operation, quality)
            end
        end)
    end

    local value, amount, quality = data.value, data.amount, data.quality
    local r, g, b = frame:GetLabelColor():GetRGB()

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
    self.progressBar = CreateFrame("Frame", nil, self.recipeList, "TestFlightRecipeListProgressBarTemplate") --[[@as GUI.RecipeListProgressBar]]

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
    local IsSortSelected = function (sort) return self:IsFilterSelected(self.Filter.Scan, sort) end
    local SetSortSelected = function (sort) self:SetFilterSelected(self.Filter.Scan, sort) return 4 end

    Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", function (_, rootDescription)
        if ProfessionsFrame:GetTab() ~= self.tabID then return end

        rootDescription:CreateSpacer()
        rootDescription:CreateTitle("TestFlight")
        rootDescription:CreateRadio(NONE, IsFilterSelected, SetFilterSelected)

        -- Add sort menu
        if Prices:IsSourceInstalled() then
            local sortSubmenu = rootDescription:CreateRadio("Scan", IsFilterSelected, SetFilterSelected, self.Filter.Scan) --[[@as ElementMenuDescriptionProxy]]

            for name,method in pairs(Optimization.Method) do repeat
                if method == Optimization.Method.CostPerConcentration then
                    break
                elseif method == Optimization.Method.ProfitPerConcentration then
                    name = "Profit per Concentration"
                end

                sortSubmenu:CreateRadio(name, IsSortSelected, SetSortSelected, method)
            until true end
        end

        -- Add tracked and restock options
        rootDescription:CreateRadio("Queue", IsFilterSelected, SetFilterSelected, self.Filter.Queue)
        rootDescription:CreateRadio("Restock", IsFilterSelected, SetFilterSelected, self.Filter.Restock)

        rootDescription:CreateSpacer()
        Buffs:AddAuraFilters(rootDescription)
    end)

    -- Update reset filter button state
    local dropdown = self.recipeList.FilterDropdown
    hooksecurefunc(dropdown, "ValidateResetState", function ()
        if dropdown.ResetButton:IsShown() or not self.filter then return end
        dropdown.ResetButton:SetShown(true)
    end)
end

function Self:IsFilterSelected(filter, sort)
    return filter == self.filter and (not sort or self.sort == sort)
end

---@param filter? RecipeFormContainer.Filter
---@param sort? Optimization.Method
function Self:SetFilterSelected(filter, sort)
    if filter == self.Filter.Scan then
        sort = sort or self.sort or Optimization.Method.Profit
        GUI.RecipeForm.CraftingForm:SetOptimizationMethod(sort)
    else
        sort = filter and self.sort or nil
    end

    if filter == self.filter and sort == self.sort then return end

    self.filter = filter
    self.sort = sort

    if filter then ---@cast sort -?
        self.recipeList:SetPoint("BOTTOMLEFT", 0, 32.5)
        self:UpdateRecipeList(true, true)
    else
        self.recipeList:SetPoint("BOTTOMLEFT", 0, 5)
        self:UpdateFilterButtons()

        self.dataProvider:GetRootNode():Flush()
        self.filterProfessionInfo, self.filterRecipeIDs = nil, nil
        self.selectedRecipeID, self.selectedQuality = nil, nil

        if self.filterJob then self.filterJob:Cancel() end
        self.Cache.Filter:Clear()
    end
end

---@param filter? RecipeFormContainer.Filter
function Self:GetFilterSort(filter)
    return filter == self.Filter.Scan and self.sort or filter and Optimization.Method.Profit or nil
end

---@param refresh? boolean
---@param flush? boolean
---@param updateSelected? boolean
function Self:UpdateRecipeList(refresh, flush, updateSelected)
    if not self.filter then return end
    local filter, sort = self.filter, self:GetFilterSort(self.filter) --[[@cast filter -?]] --[[@cast sort -?]]

    local profInfo = self:GetProfessionInfo()
    local professionChanged = not self.filterProfessionInfo
        or not Util:TblMatch(self.filterProfessionInfo, "professionID", profInfo.professionID, "skillLevel", profInfo.skillLevel, "skillModifier", profInfo.skillModifier)

    local recipeIDs = self:GetFilterRecipeIDs(filter)
    local n = #recipeIDs

    self.filterProfessionInfo = profInfo
    self.filterRecipeIDs = recipeIDs

    local recipeList = self.recipeList
    local scrollBox = recipeList.ScrollBox
    local noResultsText = recipeList.NoResultsText
    local selectionBehavior = recipeList.selectionBehavior
    local provider = self.dataProvider
    local hasCustomProvider = scrollBox:GetDataProvider() == provider

    local refresh = refresh
        or professionChanged
        or not hasCustomProvider
        or not self.filterRecipeIDs or not Util:TblEquals(self.filterRecipeIDs, recipeIDs)
    local flush = flush or professionChanged
    local updateSelected = updateSelected or professionChanged or hasCustomProvider

    -- Update selected
    if updateSelected then
        local node = selectionBehavior:GetFirstSelectedElementData() --[[@as RecipeTreeNode]]
        if node then
            local data = node:GetData()
            self.selectedRecipeID, self.selectedQuality = data.recipeInfo.recipeID, data.quality
        else
            self.selectedRecipeID, self.selectedQuality = recipeList.previousRecipeID, nil
        end
    end

    -- Flush or clear data provider
    if flush then
        provider:GetRootNode():Flush()
    else
        local recipeIDMap = Util:TblFlip(recipeIDs)
        for _,node in provider:EnumerateEntireRange() do repeat ---@cast node RecipeTreeNode
            local data = node:GetData()
            if recipeIDMap[data.recipeInfo.recipeID] then break end
            provider:Remove(node)
        until true end
    end

    -- Set data provider
    if not hasCustomProvider then
        scrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
        selectionBehavior:ClearSelections()
    end

    -- Set sort comparator
    local sortComparator = self.SortComparator[filter]
    if provider.sortComparator ~= sortComparator then
        provider:SetSortComparator(sortComparator, false, true)
    end

    -- Refresh recipes
    if refresh then
        if professionChanged then self.Cache.Filter:Clear() end

        Promise:Async(function ()
            Promise:GetCurrent():SetPriority(5)

            ---@type table<TreeNodeMixin, true>
            local datas = {}

            for i,recipeID in ipairs(recipeIDs) do repeat
                wipe(datas)

                local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
                if not recipeInfo then break end

                local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, recipeInfo.isRecraft)
                local operations = self:GetFilterRecipeOperations(filter, recipe, sort)

                if operations then
                    for _,operation in pairs(operations) do repeat
                        local quality = recipeInfo.supportsQualities and operation:GetResultQuality() or nil

                        local value
                        if Prices:IsSourceInstalled() then
                            value = Optimization:GetOperationValue(operation, sort)
                            if not value or abs(value) == math.huge then break end
                        end

                        local amount, amountShown, amountTotal = self:GetFilterRecipeAmount(filter, recipe, quality, value)

                        local node = provider:FindElementDataByPredicate(function (node) ---@cast node RecipeTreeNode
                            local data = node:GetData()
                            return data.recipeInfo.recipeID == recipeID and data.quality == quality
                        end, false) --[[@as RecipeTreeNode?]]

                        local data = node and node:GetData() or {} --[[@as RecipeTreeNodeData]]
                        local frame = node and scrollBox:FindFrame(node) --[[@as ProfessionsRecipeListRecipeFrame?]]

                        data.recipeInfo = recipeInfo
                        data.operation = operation
                        data.value = value
                        data.method = sort
                        data.quality =  quality
                        data.amount = amount
                        data.amountShown = amountShown
                        data.amountTotal = amountTotal

                        -- Insert node or update visible frame
                        if not node then
                            provider:Insert(data)
                        elseif frame then
                            self:InitRecipeListRecipe(frame, node, true)
                        end

                        datas[data] = true
                    until true end
                end

                -- Remove unused qualities
                for _,node in provider:EnumerateEntireRange() do repeat ---@cast node RecipeTreeNode
                    local data = node:GetData()
                    if data.recipeInfo.recipeID ~= recipeID or datas[data] then break end
                    provider:Remove(node)
                until true end

                -- Update progress and maybe yield
                if not hasCustomProvider and recipeID == self.selectedRecipeID and not selectionBehavior:HasSelection() then
                    Promise:Yield(i, n, recipeID) -- Yield to restore selection
                else
                    Promise:YieldProgress(i, n)
                end
            until true end

            provider:Sort()
            provider:Invalidate()
        end):Singleton(self, "filterJob"):Start(function ()
            noResultsText:SetShown(false)

            self:UpdateFilterButtons()

            self.progressBar:Start(n)

            return function () self.progressBar:Progress(n, n) end
        end):Progress(function (i, n, recipeID)
            if not i or not n then return end

            self.progressBar:Progress(i, n)

            if not recipeID then return end

            self:RestoreSelectedRecipe()
        end):Finally(function ()
            noResultsText:SetShown(provider:IsEmpty())

            self:UpdateFilterButtons()
        end)
    else
        provider:Sort()
        provider:Invalidate()

        self:RestoreSelectedRecipe()
    end
end

function Self:RestoreSelectedRecipe()
    if not self.filter then return end

    local recipeID, quality = self.selectedRecipeID, self.selectedQuality
    if not recipeID then return end

    ---@param node RecipeTreeNode
    local function predicate(node)
        local data = node:GetData()
        return data.recipeInfo.recipeID == recipeID and (not data.quality or not quality or data.quality == quality)
    end

    local node = self.recipeList.selectionBehavior:GetFirstSelectedElementData() --[[@as RecipeTreeNode?]]
    if node and predicate(node) then return end

    self.recipeList.selectionBehavior:SelectFirstElementData(predicate)
end

---@param filter RecipeFormContainer.Filter
function Self:GetFilterRecipeIDs(filter)
    local recipeIDs = C_TradeSkillUI.GetFilteredRecipeIDs() ---@cast recipeIDs -?

    if filter == self.Filter.Scan then
        local professionID = self:GetProfessionInfo().professionID

        return Util:TblFilter(recipeIDs, function (recipeID)
            return C_TradeSkillUI.IsRecipeInSkillLine(recipeID, professionID)
        end)
    elseif filter == self.Filter.Queue then
        return Util:TblFilter(recipeIDs, function (recipeID)
            return (Recipes:GetTrackedAmountTotal(recipeID) or 0) > 0
        end)
    elseif filter == self.Filter.Restock then
        return Util:TblFilter(recipeIDs, Restock.IsTracked, false, Restock)
    end
end

---@param filter RecipeFormContainer.Filter
---@param recipe CraftingRecipeSchematic
---@param method Optimization.Method
---@return Operation[]?
function Self:GetFilterRecipeOperations(filter, recipe, method)
    ---@type table<number, Operation | false>
    local operations
    local Service = Util:Select(filter, self.Filter.Queue, Recipes, self.Filter.Restock, Restock)

    if Service then
        local amounts = Service:GetTrackedAmounts(recipe) ---@cast amounts -?

        operations = Util:TblMap(amounts, Util.FnFalse) --[[@as table<number, Operation | false>]]

        if filter == self.Filter.Queue then
            for quality,amount in pairs(amounts) do repeat
                if amount == 0 then break end
                operations[quality] = Recipes:GetTrackedAllocation(recipe, quality) or false
            until true end
        end

        if not Util:TblIncludes(operations, false) then return operations end
    end

    local cache = self.Cache.Filter
    local key, time = cache:Key(method, recipe), Prices:GetRecipeScanTime(recipe)

    if not cache:Has(key) or cache:Get(key)[1] ~= time then
        local includeNonTradable = filter == self.Filter.Queue
        cache:Set(key, { time, Optimization:GetRecipeAllocations(recipe, method, includeNonTradable) })
    end

    local optimized = cache:Get(key)[2]
    if not operations then return optimized end

    local minQuality = optimized and Util:TblMinKey(optimized)

    for quality,op in pairs(operations) do repeat
        if op then break end
        operations[quality] = optimized and optimized[max(quality, minQuality)]
    until true end

    return operations
end

---@param filter RecipeFormContainer.Filter
---@param recipe CraftingRecipeSchematic
---@param quality? number
---@param value number
---@return number? amount
---@return number? amountShown
---@return number? amountTotal
function Self:GetFilterRecipeAmount(filter, recipe, quality, value)
    if filter == self.Filter.Queue then
        return Recipes:GetTrackedAmount(recipe, quality) --[[@as number]]
    elseif filter == self.Filter.Restock then
        local total = Restock:GetTrackedAmount(recipe, quality)

        if Prices:IsSourceInstalled() and value < Restock:GetTrackedMinProfit(recipe, quality or 1) then
            return 0, total
        end

        return Restock:GetTrackedMissing(recipe, quality), total
    end
end

---------------------------------------
--        Filter buttons
---------------------------------------

-- Craft/Restock

---@return RecipeTreeNode?
function Self:GetNextTrackedCraftable()
    if self.filter ~= self.Filter.Queue then return end
    if self.dataProvider:IsEmpty() then return end

    return select(2, self.dataProvider:FindByPredicate(function (node) ---@cast node RecipeTreeNode
        local data = node:GetData()
        if not data.amount or not data.operation then return false end
        return data.amount > 0 and data.operation:HasAllReagents()
    end, false))
end

function Self:GetNextTrackedRestock()
    if self.filter ~= self.Filter.Restock then return end
    if self.dataProvider:IsEmpty() then return end

    return select(2, self.dataProvider:FindByPredicate(function (node)
        return (node:GetData().amount or 0) > 0
    end, false))
end

---@param frame Frame
function Self:CraftRestockButtonOnEnter(frame)
    if self.filter == self.Filter.Queue then
        local node = self:GetNextTrackedCraftable()
        if not node then return end

        local data = node:GetData()
        local operation, amount = data.operation, data.amount
        if not operation or not amount then return end

        if not operation:IsToolEquipped() then
            GUI:ShowInfoTooltip(frame, "Equip pending crafting tool.")
        elseif operation:GetMissingAura() then
            local action, recipe, item = operation:GetAuraAction() ---@cast action -?
            GUI:ShowInfoTooltip(frame, Buffs:GetAuraActionTooltip(action, recipe, item))
        else
        end
    elseif self.filter == self.Filter.Restock then
    end
end

function Self:CraftRestockButtonOnClick()
    if self.filter == self.Filter.Queue then
        local node = self:GetNextTrackedCraftable()
        if not node then return end

        local data = node:GetData()
        local operation, amount = data.operation, data.amount
        if not operation or not amount then return end

        if not operation:IsToolEquipped() then
            operation:EquipTool()
        elseif operation:GetMissingAura() then
            operation:CastNextAura()
        else
            self:CraftOperation(operation, min(amount, operation:GetMaxCraftAmount()))
        end
    elseif self.filter == self.Filter.Restock then
        for _,node in self.dataProvider:EnumerateEntireRange() do repeat ---@cast node RecipeTreeNode
            local data = node:GetData()
            local operation, quality, amount = data.operation, data.quality, data.amount
            if not operation or not amount then break end

            if amount <= 0 then break end

            Recipes:SetTracked(operation.recipe)
            Recipes:SetTrackedPerQuality(operation.recipe, quality ~= nil)
            Recipes:SetTrackedAmount(operation.recipe, amount, quality)
            Recipes:SetTrackedAllocation(operation.recipe, operation, quality)
        until true end
    end
end

-- Prev/Next filter

function Self:PrevFilterButtonOnClick()
    local curr = Util:TblIndexOf(self.filterList, self.filter) or 0
    self:SetFilterSelected(self.filterList[curr - 1])
end

function Self:NextFilterButtonOnClick()
    local curr = Util:TblIndexOf(self.filterList, self.filter) or 0
    self:SetFilterSelected(self.filterList[curr + 1])
end

-- Insert/Update buttons

function Self:InsertFilterButtons()
    if Prices:IsSourceInstalled() then
        self.filterList = { self.Filter.Scan, self.Filter.Queue, self.Filter.Restock }
    else
        self.filterList = { self.Filter.Queue, self.Filter.Restock }
    end

    self.craftRestockBtn = GUI:InsertButton(
        "", self.frame, Util:FnBind(self.CraftRestockButtonOnEnter, self), Util:FnBind(self.CraftRestockButtonOnClick, self),
        "TOP", self.recipeList, "BOTTOM", 0, -3.5
    )

    self.craftRestockBtn:SetMotionScriptsWhileDisabled(true)

    self.secureCraftRestockBtn = Buffs:CreateAuraSecureButton(self.craftRestockBtn)

    self.prevFilterBtn = GUI:InsertButton(
        "<", self.frame, nil, Util:FnBind(self.PrevFilterButtonOnClick, self),
        "TOPLEFT", self.recipeList, "BOTTOMLEFT", 1, -3.5
    )

    self.nextFilterBtn = GUI:InsertButton(
        ">", self.frame, nil, Util:FnBind(self.NextFilterButtonOnClick, self),
        "TOPRIGHT", self.recipeList, "BOTTOMRIGHT", -1, -3.5
    )

    self.craftRestockBtn:Hide()
    self.prevFilterBtn:Hide()
    self.nextFilterBtn:Hide()
end

function Self:UpdateFilterButtons()
    self.secureCraftRestockBtn:SetShown(false)

    local shown = Util:OneOf(self.filter, self.Filter.Queue, self.Filter.Restock)
    local enabled = shown and not self.filterJob
    local text = ""

    if shown then
        if self.filter == self.Filter.Restock then
            enabled = enabled and self:GetNextTrackedRestock() ~= nil
            text = "Restock"
        elseif self.filter == self.Filter.Queue then
            local empty = self.dataProvider:IsEmpty()
            local next = not empty and self:GetNextTrackedCraftable()
            local op = next and next:GetData().operation

            enabled = enabled and not not next

            if empty then
                text = "Queue"
            elseif not next then
                text = "Buy mats"
            elseif op and not op:IsToolEquipped() then
                text = "Equip tool"
            elseif op and op:GetMissingAura() then
                local action, _, item = op:GetAuraAction() ---@cast action -?
                text = Buffs:GetAuraActionLabel(action)

                if Util:OneOf(action, Buffs.AuraAction.BuyItem, Buffs.AuraAction.BuyMats) then
                    enabled = false
                elseif action == Buffs.AuraAction.UseItem and item then
                    self.secureCraftRestockBtn:SetShown(true)
                    self.secureCraftRestockBtn:SetAttribute("item", (select(2, C_Item.GetItemInfo(item))))
                end
            else
                text = "Create Next"
            end
        end
    end

    self.craftRestockBtn:SetShown(shown)
    self.craftRestockBtn:SetEnabled(enabled)
    self.craftRestockBtn:SetTextToFit(text)

    local shown = self.filter ~= nil
    local curr = Util:TblIndexOf(self.filterList, self.filter) or 0
    local prev, next = self.filterList[curr - 1], self.filterList[curr + 1]

    self.prevFilterBtn:SetShown(shown)
    self.nextFilterBtn:SetShown(shown)
    self.prevFilterBtn:SetText(curr > 1 and "<" or "X")
    self.nextFilterBtn:SetEnabled(curr < #self.filterList)

    self.prevFilterBtn.tooltipText = Util:TblIndexOf(self.Filter, prev) --[[@as string?]] or "Close filter"
    self.nextFilterBtn.tooltipText = Util:TblIndexOf(self.Filter, next) --[[@as string?]]
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnShow()
    if not self.filter then return end
    self:UpdateRecipeList(true)
end

function Self:OnHide()
    if not self.filterJob then return end
    self.filterJob:Cancel()
end

---@param frame ProfessionsRecipeListRecipeFrame
---@param node RecipeTreeNode
function Self:OnRecipeListRecipeInitialized(frame, node)
    self:InitRecipeListRecipe(frame, node)
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

---@param event string
function Self:OnBuffChanged(event)
    local refresh = event ~= Buffs.Event.EquipmentChanged

    if refresh then self.Cache.Filter:Clear() end

    if not self.filter or not self.frame:IsVisible() then return end

    self:UpdateRecipeList(refresh)
end

function Self:OnTrackedRecipeUpdated()
    if self.filter ~= self.Filter.Queue or not self.frame:IsVisible() then return end
    self:UpdateRecipeList(true)
end

function Self:OnTrackedRestockUpdated()
    if self.filter ~= self.Filter.Restock or not self.frame:IsVisible() then return end
    self:UpdateRecipeList(true)
end

function Self:OnOwnedItemsUpdated()
    if not Util:OneOf(self.filter, self.Filter.Restock, self.Filter.Queue) or not self.frame:IsVisible() then return end
    self:UpdateRecipeList(true)
end

function Self:OnAddonLoaded()
    self:CreateRecipeListProgressBar()
    self:InsertFilterButtons()

    self.frame:HookScript("OnShow", Util:FnBind(self.OnShow, self))
    self.frame:HookScript("OnHide", Util:FnBind(self.OnHide, self))

    Util:TblHook(self.recipeList, "SelectRecipe", self.RecipeListSelectRecipe, self)

    self.recipeList.ScrollBox.view:RegisterCallback(ScrollBoxListViewMixin.Event.OnInitializedFrame, self.OnRecipeListRecipeInitialized, self)

    hooksecurefunc(Professions, "SetDefaultFilters", Util:FnBind(self.OnSetDefaultFilters, self))
    hooksecurefunc(Professions, "OnRecipeListSearchTextChanged", Util:FnBind(self.OnRecipeListSearchTextChanged, self))

    EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_LIST_UPDATE", self.OnTradeSkillListUpdate, self)

    Buffs:RegisterCallback(Buffs.Event.BuffChanged, self.OnBuffChanged, self)

    local OnTrackedRecipeUpdated = Util:FnDebounce(self.OnTrackedRecipeUpdated, 0)
    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, OnTrackedRecipeUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedAmountUpdated, OnTrackedRecipeUpdated, self)
    Recipes:RegisterCallback(Recipes.Event.TrackedAllocationUpdated, OnTrackedRecipeUpdated, self)

    local OnTrackedRestockUpdated = Util:FnDebounce(self.OnTrackedRestockUpdated, 0)
    Restock:RegisterCallback(Restock.Event.TrackedUpdated, OnTrackedRestockUpdated, self)
    Restock:RegisterCallback(Restock.Event.TrackedMinProfitUpdated, OnTrackedRestockUpdated, self)

    local OnOwnedItemsUpdated = Util:FnDelayedUpdate(self.OnOwnedItemsUpdated, 1)
    EventRegistry:RegisterFrameEventAndCallback("AUCTION_HOUSE_SHOW_NOTIFICATION", OnOwnedItemsUpdated, self)
    EventRegistry:RegisterFrameEventAndCallback("AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION", OnOwnedItemsUpdated, self)
    EventRegistry:RegisterFrameEventAndCallback("UPDATE_PENDING_MAIL", OnOwnedItemsUpdated, self)
    EventRegistry:RegisterFrameEventAndCallback("UNIT_INVENTORY_CHANGED", OnOwnedItemsUpdated, self)
end

---------------------------------------
--              Caches
---------------------------------------

Self.Cache = {
    ---@type Cache<{ [1]: number, [2]: Operation }, fun(self: self, method: Optimization.Method, recipe: CraftingRecipeSchematic): number>
    Filter = Cache:Create(function (_, method, recipe)
        return ("%s;;%s"):format(method, recipe.recipeID)
    end),
    ---@type Cache<number, (fun(self: self, data: RecipeTreeNodeData): string), (fun(self: self, data: RecipeTreeNodeData): number)>
    CurrentCraftAmount = Cache:PerFrame(
        ---@param data RecipeTreeNodeData
        function (_, data) return ("%d;%d"):format(data.recipeInfo.recipeID, data.quality or 0) end,
        ---@param data RecipeTreeNodeData
        function (_, data) return data.operation:GetMaxCraftAmount() end
    ),
    ---@type Cache<number, (fun(self: self, data: RecipeTreeNodeData): string), (fun(self: self, data: RecipeTreeNodeData): number)>
    CurrentMissingAura = Cache:PerFrame(
        ---@param data RecipeTreeNodeData
        function (_, data) return ("%d;%d"):format(data.recipeInfo.recipeID, data.quality or 0) end,
        ---@param data RecipeTreeNodeData
        function (_, data) return data.operation:GetMissingAura() end
    )
}

---------------------------------------
--              Types
---------------------------------------

---@class RecipeTreeNode: TreeNodeMixin
---@field GetData fun(self: self): RecipeTreeNodeData

---@alias RecipeTreeNodeData { recipeInfo: TradeSkillRecipeInfo, operation?: Operation, value?: number, method?: Optimization.Method, quality?: number, amount?: number, total?: number }