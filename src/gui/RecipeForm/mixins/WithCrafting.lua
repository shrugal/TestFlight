---@class Addon
local Addon = select(2, ...)
local GUI, Operation, Optimization, Orders, Prices, Recipes, Util = Addon.GUI, Addon.Operation, Addon.Optimization, Addon.Orders, Addon.Prices, Addon.Recipes, Addon.Util
local NS = GUI.RecipeForm

---@type GUI.RecipeForm.WithExperimentation | GUI.RecipeForm.WithSkill | GUI.RecipeForm.WithOptimization
local Parent = Util:TblCombineMixins(NS.WithExperimentation, NS.WithSkill, NS.WithOptimization)

---@class GUI.RecipeForm.WithCrafting: GUI.RecipeForm.WithExperimentation, GUI.RecipeForm.WithSkill, GUI.RecipeForm.WithOptimization
---@field form RecipeCraftingForm
local Self = Mixin(NS.WithCrafting, Parent)

Self.optimizationMethod = Optimization.Method.Cost

---------------------------------------
--               Hooks
---------------------------------------

function Self:GetRecipeOperationInfo()
    ---@type CraftingOperationInfo
    local op = Util:TblGetHooks(self.form).GetRecipeOperationInfo(self.form)
    if not op then return end

    op.baseSkill = op.baseSkill + Addon.extraSkill

    if op.isQualityCraft then
        local skill, difficulty = op.baseSkill + op.bonusSkill, op.baseDifficulty + op.bonusDifficulty

        local p = skill / difficulty
        local rank = self.form.currentRecipeInfo.maxQuality
        local breakpoints = Addon.QUALITY_BREAKPOINTS[rank]

        for i, v in ipairs(breakpoints) do
            if v > p then rank = i - 1 break end
        end

        local lower, upper = breakpoints[rank], breakpoints[rank + 1] or 1
        local quality = rank + (upper == lower and 0 or (p - lower) / (upper - lower))
        local qualityID = self.form.currentRecipeInfo.qualityIDs[rank]

        op.quality = quality
        ---@diagnostic disable-next-line: assign-type-mismatch
        op.craftingQuality = rank
        op.craftingQualityID = qualityID
        op.lowerSkillThreshold = difficulty * lower
        op.upperSkillTreshold = difficulty * upper
    end

    return op
end

---@param recipe CraftingRecipeSchematic
function Self:Init(_, recipe)
    if not recipe then return end

    self:Refresh()

    if not self:CanAllocateReagents() then return end

    -- Set or update tracked allocation
    local Service, model = self:GetTracking()
    local allocation = model and Service:GetTrackedAllocation(model)
    if allocation then
        self:AllocateReagents(allocation)
    else
        self:UpdateTracking()
    end
end

function Self:Refresh()
    self:UpdateExperimentBox()
    self:UpdateSkillSpinner()
    self:UpdateConcentrationCostSpinner()
    self:UpdateOptimizationButtons()
end

-- Stats

function Self:UpdateDetailsStats()
    self:UpdateSkillSpinner()
    self:UpdateConcentrationCostSpinner()
    self:UpdateOptimizationButtons()
end

---@param line RecipeStatLine
function Self:CostStatLineOnEnter(line)
    local op = self.operation

    local label = COSTS_LABEL:gsub(":", "")
    local reagentPrice = op and Util:NumCurrencyString(op:GetReagentPrice())

    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")

    GameTooltip_AddColoredDoubleLine(GameTooltip, label, reagentPrice or "Not craftable", HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, "Based on reagent market prices, not taking resourcefulness or multicraft into account.")

    if op then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddNormalLine(GameTooltip, "Breakdown:")

        for slotIndex,slot in pairs(op.recipe.reagentSlotSchematics) do
            local missing = slot.required and slot.quantityRequired or 0
            local price, itemID = 0, nil

            if op.allocation[slotIndex] then
                for _, alloc in op.allocation[slotIndex]:Enumerate() do
                    missing = missing - alloc.quantity
                    price = price + alloc.quantity * Prices:GetReagentPrice(alloc.reagent)
                    if not itemID then itemID = alloc.reagent.itemID end
                end
            end

            if missing > 0 then
                price = price + missing * Prices:GetReagentPrice(slot)
            end

            if price > 0 then
                if not itemID then itemID = slot.reagents[1].itemID --[[@as number]] end

                local label, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
                if icon then label = ("|T%d:0|t %s"):format(icon, label) end

                GameTooltip_AddColoredDoubleLine(GameTooltip, label, Util:NumCurrencyString(price), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
            end
        end

        if op:GetRecipeInfo().supportsQualities then
            local operations = Optimization:GetAllocationsForMethod(op, Optimization.Method.Cost)

            if operations then
                GameTooltip_AddBlankLineToTooltip(GameTooltip)
                GameTooltip_AddNormalLine(GameTooltip, "Optimal costs:")

                for i=1,5 do
                    local op = operations[i]
                    if op then
                        local label = CreateAtlasMarkup(Professions.GetIconForQuality(i), 20, 20)
                        local priceStr = Util:NumCurrencyString(op:GetReagentPrice())

                        GameTooltip_AddHighlightLine(GameTooltip, label .. " " .. priceStr)
                    end
                end
            end
        end
    end

    GameTooltip:Show()
end

---@param line RecipeStatLine
function Self:ProfitStatLineOnEnter(line)
    local op = self.operation
    if not op then return end

    local recipeInfo = op:GetRecipeInfo()
    local order = op:GetOrder()
    local reagentPrice = op:GetReagentPrice()
    local profit, revenue, resourcefulness, multicraft, rewards, traderCut = op:GetProfit()

    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")

    GameTooltip_AddColoredDoubleLine(GameTooltip, "Profit", Util:NumCurrencyString(profit), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, "Based on reagent and result market prices, taking resourcefulness and multicraft into account.")

    GameTooltip_AddBlankLineToTooltip(GameTooltip)
    GameTooltip_AddNormalLine(GameTooltip, "Breakdown:")

    -- Revenue
    GameTooltip_AddColoredDoubleLine(GameTooltip, order and "Commission" or "Sell price", Util:NumCurrencyString(revenue), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    if order and order.npcOrderRewards then
        GameTooltip_AddColoredDoubleLine(GameTooltip, "Rewards", Util:NumCurrencyString(rewards), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    end
    if recipeInfo.supportsCraftingStats then
        GameTooltip_AddColoredDoubleLine(GameTooltip, "Resourcefulness", Util:NumCurrencyString(resourcefulness), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
        if not order then
            GameTooltip_AddColoredDoubleLine(GameTooltip, "Multicraft", Util:NumCurrencyString(multicraft), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
        end
    end

    -- Costs
    GameTooltip_AddColoredDoubleLine(GameTooltip, "Reagents", Util:NumCurrencyString(-reagentPrice), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddColoredDoubleLine(GameTooltip, order and "Consortium cut" or "Auction fee", Util:NumCurrencyString(-traderCut), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)

    if recipeInfo.supportsQualities then
        local operations = Optimization:GetAllocationsForMethod(op, Optimization.Method.Profit)

        if operations then
            GameTooltip_AddBlankLineToTooltip(GameTooltip)
            GameTooltip_AddNormalLine(GameTooltip, "Optimal profits:")

            for i=1,5 do
                local op = operations[i]
                if op then
                    local label = CreateAtlasMarkup(Professions.GetIconForQuality(i), 20, 20)
                    local profitStr = Util:NumCurrencyString((op:GetProfit()))

                    GameTooltip_AddHighlightLine(GameTooltip, label .. " " .. profitStr)
                end
            end
        end
    end

    GameTooltip:Show()
end

---@param line RecipeStatLine
function Self:ConcentrationStatLineOnEnter(line)
    if not line.statLineType or not line.professionType or not line.baseValue then return end

    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    local statString
    if line.bonusValue then
        statString = PROFESSIONS_CRAFTING_STAT_QUANTITY_TT_FMT:format(line.baseValue + line.bonusValue, line.baseValue, line.bonusValue)
    else
        statString = PROFESSIONS_CRAFTING_STAT_NO_BONUS_TT_FMT:format(line.baseValue)
    end

    GameTooltip_AddColoredDoubleLine(GameTooltip, PROFESSIONS_CRAFTING_STAT_CONCENTRATION, statString, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, PROFESSIONS_CRAFTING_STAT_CONCENTRATION_DESCRIPTION)

    if self.operation then
        local profitCon = self.operation:WithConcentration(true):GetProfitPerConcentration()
        local profitNoCon = self.operation:WithConcentration(false):GetProfitPerConcentration()

        if profitCon and abs(profitCon) ~= math.huge then
            GameTooltip_AddBlankLineToTooltip(GameTooltip)
            GameTooltip_AddColoredDoubleLine(GameTooltip, "Final profit per point", Util:NumCurrencyString(profitCon), NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
            GameTooltip_AddColoredDoubleLine(GameTooltip, "Profit change per point", Util:NumCurrencyString(profitCon - profitNoCon), NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
        end
    end

    GameTooltip:Show()
end

---@param stat string
---@param line RecipeStatLine
function Self:BonusStatLineOnEnter(stat, line)
    local op = self.operation
    if not op then return end

    local bonusStat = Util:TblWhere(op:GetOperationInfo().bonusStats, "bonusStatName", stat)
    if not bonusStat then return end

    local points = bonusStat.bonusStatValue

    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")

    local statStr = line:GetStatFormat():format(math.ceil(line.baseValue))
    GameTooltip_AddColoredDoubleLine(GameTooltip, stat, statStr, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, bonusStat.ratingDescription)

    if points > 0 then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddNormalLine(GameTooltip, PROFESSIONS_CRAFTING_STAT_TT_FMT:format(stat, points, bonusStat.bonusRatingPct))

        ---@type number?
        local statProfit
        if ITEM_MOD_RESOURCEFULNESS_SHORT then
            statProfit = select(3, op:GetProfit()) --[[@as number?]]
        elseif ITEM_MOD_MULTICRAFT_SHORT then
            statProfit = select(4, op:GetProfit()) --[[@as number?]]
        elseif stat == ITEM_MOD_INGENUITY_SHORT then
            statProfit = select(2, op:WithConcentration(true):GetProfitPerConcentration()) --[[@as number]]
        end

        if statProfit and statProfit > 0 then
            local profitStr = Util:NumCurrencyString(statProfit / points)

            GameTooltip_AddBlankLineToTooltip(GameTooltip)
            GameTooltip_AddColoredDoubleLine(GameTooltip, "Profit change per point", profitStr, NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
        end
    end

    GameTooltip:Show()
end

---@param frame RecipeFormDetails
---@param operationInfo CraftingOperationInfo
---@param supportsQualities boolean
---@param isGatheringRecipe boolean
function Self:DetailsSetStats(frame, operationInfo, supportsQualities, isGatheringRecipe)
    self.operation = nil

    if isGatheringRecipe then return end
    if not Prices:IsSourceInstalled() then return end

    local order = self:GetOrder()
    local tx = self.form.transaction
    local recipe = tx:GetRecipeSchematic()

    local isUnclaimedOrder = order and order.orderState ~= Enum.CraftingOrderState.Claimed
    local isSalvage = recipe.recipeType == Enum.TradeskillRecipeType.Salvage

    ---@type number?, number?, number?
    local reagentPrice, profit

    if isSalvage then
        local allocation = tx:GetSalvageAllocation()

        if allocation then
            reagentPrice, _, profit = Prices:GetRecipePrices(recipe, operationInfo, allocation)
        end
    else
        if isUnclaimedOrder then ---@cast order -?
            self.operation = Optimization:GetOrderAllocation(order, self.form.transaction)
        else
            self.operation = Operation:FromCraftingForm(self.form, order)
        end

        if self.operation then
            reagentPrice, profit = self.operation:GetReagentPrice(), self.operation:GetProfit()
        end
    end

    local function applyExtra()
        if frame.recipeInfo == nil or ProfessionsUtil.IsCraftingMinimized() then return end

        -- Cost
        local statLine = frame.statLinePool:Acquire() --[[@as RecipeStatLine]]
        statLine.layoutIndex = 1000
        statLine:SetLabel(COSTS_LABEL:gsub(":", ""))
        statLine.RightLabel:SetText(reagentPrice and Util:NumCurrencyString(reagentPrice) or "-")
        statLine:SetScript("OnEnter", Util:FnBind(self.CostStatLineOnEnter, self))
        statLine:Show()

        -- Profit
        local statLine = frame.statLinePool:Acquire() --[[@as RecipeStatLine]]
        statLine.layoutIndex = 1001
        statLine:SetLabel("Profit") -- TODO
        statLine.RightLabel:SetText(profit and Util:NumCurrencyString(profit) or "-")
        statLine:SetScript("OnEnter", Util:FnBind(self.ProfitStatLineOnEnter, self))
        statLine:Show()

        -- Stats tooltips
        if self.operation then
            if frame.StatLines.ConcentrationStatLine:IsShown() then
                frame.StatLines.ConcentrationStatLine:SetScript("OnEnter", Util:FnBind(self.ConcentrationStatLineOnEnter, self))
            end

            for line in frame.statLinePool:EnumerateActive() do
                local stat = line.LeftLabel:GetText()
                if Util:OneOf(stat,  ITEM_MOD_RESOURCEFULNESS_SHORT, ITEM_MOD_MULTICRAFT_SHORT, ITEM_MOD_INGENUITY_SHORT) then
                    line:SetScript("OnEnter", Util:FnBind(self.BonusStatLineOnEnter, self, stat))
                end
            end
        end

        frame.StatLines:Layout()
        frame:Layout()
    end

    local origApplyLayout = frame.ApplyLayout
    frame.ApplyLayout = function() origApplyLayout() applyExtra() end

    applyExtra()
end

---------------------------------------
--               Util
---------------------------------------

function Self:GetTrackRecipeCheckbox()
    return self.form.TrackRecipeCheckbox
end

function Self:GetQuality()
    local op = self.form:GetRecipeOperationInfo()
    if op and op.isQualityCraft then return floor(op.quality) end
end

function Self:CanAllocateReagents()
    local recipe = self:GetRecipe()
    if not recipe or not Recipes:IsTracked(recipe) then return false end

    local order = self:GetOrder()
    if order then
        -- The order is not claimed
        if order.orderState ~= Enum.CraftingOrderState.Claimed then return false end
        -- Order is already crafted
        if order.isFulfillable then return false end
        -- The order is not tracked
        if not Orders:IsTracked(order) then return false end
    else
        -- The recipe has a tracked order
        if Orders:GetTracked(recipe) then return false end
    end

    return true
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnEnabled()
    if not self.form then return end

    Util:TblHook(self.form, "GetRecipeOperationInfo", self.GetRecipeOperationInfo, self)
end

function Self:OnDisabled()
    if not self.form then return end

    Util:TblUnhook(self.form, "GetRecipeOperationInfo")
end

function Self:OnRefresh()
    Parent.OnRefresh(self)

    if not self.form or not self.form:IsVisible() then return end

    self.form:Refresh()
end

function Self:OnExtraSkillUpdated()
    if not self.form or not self.form:IsVisible() then return end

    self.form:UpdateDetailsStats()
    self.form:UpdateRecraftSlot()
end

function Self:OnAllocationModified()
    self:UpdateTracking()
end

function Self:OnAddonLoaded()
    Parent.OnAddonLoaded(self)

    -- Elements

    -- Insert experiment checkbox
    self:InsertExperimentBox(
        self.form,
        "LEFT", self.form.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
    )

    -- Insert skill points spinner
    self:InsertSkillSpinner(
        self.form.Details.StatLines.SkillStatLine,
        "RIGHT", -50, 1
    )

    -- Insert concentration cost spinner
    self:InsertConcentrationCostSpinner(
        self.form.Details.StatLines.ConcentrationStatLine,
        "RIGHT", -50, 1
    )

    -- Hooks

    hooksecurefunc(self.form, "Init", Util:FnBind(self.Init, self))
    hooksecurefunc(self.form, "Refresh", Util:FnBind(self.Refresh, self))
    hooksecurefunc(self.form, "UpdateDetailsStats", Util:FnBind(self.UpdateDetailsStats, self))

    hooksecurefunc(self.form.Details, "SetStats", Util:FnBind(self.DetailsSetStats, self))

    -- Events

    self.form:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, self.OnAllocationModified, self)

    Addon:RegisterCallback(Addon.Event.Enabled, self.OnEnabled, self)
    Addon:RegisterCallback(Addon.Event.Disabled, self.OnDisabled, self)
    Addon:RegisterCallback(Addon.Event.ExtraSkillUpdated, self.OnExtraSkillUpdated, self)
end