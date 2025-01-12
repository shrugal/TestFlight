---@class Addon
local Addon = select(2, ...)
local C, GUI, Optimization, Prices, Util = Addon.Constants, Addon.GUI, Addon.Optimization, Addon.Prices, Addon.Util

---@class GUI.RecipeForm.WithDetails: GUI.RecipeForm.RecipeForm
---@field form RecipeCraftingForm
local Self = GUI.RecipeForm.WithDetails

---@param recipeInfo TradeSkillRecipeInfo
function Self:InitDetails(recipeInfo)
    if not Prices:IsSourceInstalled() then return end
    if not self.form.Details:IsVisible() then return end
    if ProfessionsUtil.IsCraftingMinimized() or recipeInfo.isGatheringRecipe then return end

    local anchor, _, _, x, y = self.form.Details:GetPoint()
    if anchor ~= "TOPRIGHT" then return end

    self.form.Details:SetPoint(anchor, x, y + 25)
end

---@param line RecipeStatLine
function Self:CostStatLineOnEnter(line)
    local op = self.operation
    if not op then return end

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
            local operations = Optimization:GetTransactionAllocations(op.recipe, Optimization.Method.Cost, self.form.transaction)

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
        local operations = Optimization:GetTransactionAllocations(op.recipe, Optimization.Method.Profit, self.form.transaction)

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
    if line.baseValue == -1 then
        statString = "?"
    elseif line.bonusValue then
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

    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")

    local statStr = line:GetStatFormat():format(math.ceil(line.baseValue))
    GameTooltip_AddColoredDoubleLine(GameTooltip, stat, statStr, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, bonusStat.ratingDescription)

    local points = bonusStat.bonusStatValue
    if points > 0 then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddNormalLine(GameTooltip, PROFESSIONS_CRAFTING_STAT_TT_FMT:format(stat, points, bonusStat.bonusRatingPct))

        ---@type number?
        local statProfit
        if stat == C.STATS.RC.NAME then
            statProfit = select(3, op:GetProfit()) --[[@as number?]]
        elseif stat == C.STATS.MC.NAME then
            statProfit = select(4, op:GetProfit()) --[[@as number?]]
        elseif stat == C.STATS.IG.NAME then
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
    if not Prices:IsSourceInstalled() then return end
    if isGatheringRecipe then self.operation = nil return end

    self.operation = self:GetOperation()

    ---@type number?, number?, number?
    local reagentPrice, profit

    if self.operation then
         reagentPrice, profit = self.operation:GetReagentPrice(), self.operation:GetProfit()
    else
        local tx = self.form.transaction
        local recipe = tx:GetRecipeSchematic()

        if recipe.recipeType == Enum.TradeskillRecipeType.Salvage then
            local allocation = tx:GetSalvageAllocation()

            if allocation then
                reagentPrice, _, profit = Prices:GetRecipePrices(recipe, operationInfo, allocation)
            end
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

        local op = self.operation
        if op then
            -- Concentration cost and tooltip
            if frame.StatLines.ConcentrationStatLine:IsShown() then
                if op:GetOperationInfo().concentrationCost == -1 then
                    frame.StatLines.ConcentrationStatLine.RightLabel:SetText("?")
                end

                frame.StatLines.ConcentrationStatLine:SetScript("OnEnter", Util:FnBind(self.ConcentrationStatLineOnEnter, self))
            end

            -- Stats tooltips
            for line in frame.statLinePool:EnumerateActive() do
                local stat = line.LeftLabel:GetText()
                if Util:OneOf(stat,  C.STATS.RC.NAME, C.STATS.MC.NAME, C.STATS.IG.NAME) then
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

function Self:OnAddonLoaded()
    hooksecurefunc(self.form, "InitDetails", Util:FnBind(self.InitDetails, self))
    hooksecurefunc(self.form.Details, "SetStats", Util:FnBind(self.DetailsSetStats, self))
end