---@class Addon
local Addon = select(2, ...)
local GUI, Optimization, Orders, Prices, Reagents, Recipes, Util = Addon.GUI, Addon.Optimization, Addon.Orders, Addon.Prices, Addon.Reagents, Addon.Recipes, Addon.Util
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

function Self:UpdateDetailsStats()
    local op = self.form:GetRecipeOperationInfo()
    if not op or not op.baseDifficulty then return end

    local skillNoExtra = op.baseSkill + op.bonusSkill - Addon.extraSkill
    local difficulty = op.baseDifficulty + op.bonusDifficulty

    self.skillSpinner:SetMinMaxValues(0, math.max(0, difficulty - skillNoExtra))

    self:UpdateSkillSpinner()
    self:UpdateConcentrationCostSpinner()
    self:UpdateOptimizationButtons()
end

---@param frame RecipeFormDetails
---@param operationInfo CraftingOperationInfo
---@param supportsQualities boolean
---@param isGatheringRecipe boolean
function Self:DetailsSetStats(frame, operationInfo, supportsQualities, isGatheringRecipe)
    if isGatheringRecipe then return end
    if not Prices:IsSourceInstalled() then return end

    local recipeInfo, tx, order = frame.recipeInfo, frame.transaction, self:GetOrder()
    local recipe = tx:GetRecipeSchematic()
    local isSalvage = recipe.recipeType == Enum.TradeskillRecipeType.Salvage
    local isUnclaimedOrder = order and order.orderState ~= Enum.CraftingOrderState.Claimed

    ---@type (ProfessionAllocations | ItemMixin)?, CraftingReagentInfo[]?, string?, CraftingItemSlotModification[]?
    local allocation, optionalReagents, recraftGUID, recraftMods
    if isSalvage then
        allocation = tx:GetSalvageAllocation()
    else
        allocation = tx.allocationTbls
        optionalReagents, recraftGUID = tx:CreateOptionalOrFinishingCraftingReagentInfoTbl(), tx:GetRecraftAllocation()
        recraftMods = Reagents:GetRecraftMods(order, recraftGUID)
    end

    local orderOrRecraftGUID = order or recraftGUID

    if isUnclaimedOrder then ---@cast order -?
        local operation = Optimization:GetOrderAllocation(order, tx)
        allocation = operation and operation.allocation
        optionalReagents = operation and operation:GetOptionalReagents()
    end

    ---@type string?, number?, number?, number?, number?, number?, number?, number?
    local reagentPriceStr, reagentPrice, profit, revenue, traderCut, resourcefulness, rewards, multicraft
    if allocation then
        reagentPrice, _, profit, revenue, resourcefulness, multicraft, rewards, traderCut = Prices:GetRecipePrices(recipe, operationInfo, allocation, order, recraftMods, optionalReagents)
        reagentPriceStr = Util:NumCurrencyString(reagentPrice)
    end

    local function applyExtra()
        if frame.recipeInfo == nil or ProfessionsUtil.IsCraftingMinimized() then return end

        -- Cost
        do
            local label = COSTS_LABEL:gsub(":", "")

            local statLine = frame.statLinePool:Acquire() --[[@as RecipeStatLine]]
            statLine.layoutIndex = 1000
            statLine:SetLabel(label)
            statLine.RightLabel:SetText(reagentPriceStr or "-")

            statLine:SetScript("OnEnter", function(line)
                GameTooltip:SetOwner(line, "ANCHOR_RIGHT")

                GameTooltip_AddColoredDoubleLine(GameTooltip, label, reagentPriceStr or "Not craftable", HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
                GameTooltip_AddNormalLine(GameTooltip, "Based on reagent market prices, not taking resourcefulness or multicraft into account.")

                if supportsQualities and not isSalvage then
                    local operations = Optimization:GetRecipeAllocations(recipe, Optimization.Method.Cost, tx, orderOrRecraftGUID)

                    if operations then
                        GameTooltip_AddBlankLineToTooltip(GameTooltip)
                        GameTooltip_AddNormalLine(GameTooltip, "Optimal costs:")

                        for i=1,5 do
                            local qualityOperation = operations[i]
                            if qualityOperation then
                                local qualityLabel = CreateAtlasMarkup(Professions.GetIconForQuality(i), 20, 20)
                                local qualityPrice = qualityOperation:GetReagentPrice()
                                local qualityPriceStr = Util:NumCurrencyString(qualityPrice)

                                GameTooltip_AddHighlightLine(GameTooltip, qualityLabel .. " " .. qualityPriceStr)
                            end
                        end
                    end
                end

                GameTooltip:Show()
            end)

            statLine:Show()
        end

        -- Profit
        if profit then --[[@cast revenue -?]] --[[@cast rewards -?]] --[[@cast resourcefulness -?]] --[[@cast multicraft -?]]
            local label = "Profit" -- TODO
            local profitStr = Util:NumCurrencyString(profit)

            local statLine = frame.statLinePool:Acquire() --[[@as RecipeStatLine]]
            statLine.layoutIndex = 1001
            statLine:SetLabel(label) -- TODO
            statLine.RightLabel:SetText(profitStr or "-")

            statLine:SetScript("OnEnter", function(line)
                GameTooltip:SetOwner(line, "ANCHOR_RIGHT")

                GameTooltip_AddColoredDoubleLine(GameTooltip, label, profitStr, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
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

                if supportsQualities and not isSalvage then
                    local operations = Optimization:GetRecipeAllocations(recipe, Optimization.Method.Cost, tx, orderOrRecraftGUID)

                    if operations then
                        GameTooltip_AddBlankLineToTooltip(GameTooltip)
                        GameTooltip_AddNormalLine(GameTooltip, "Optimal profits:")

                        for i=1,5 do
                            local qualityOperation = operations[i]
                            if qualityOperation then
                                local qualityLabel = CreateAtlasMarkup(Professions.GetIconForQuality(i), 20, 20)
                                local qualityProfit = qualityOperation:GetProfit() ---@cast qualityProfit -?
                                local qualityProfitStr = Util:NumCurrencyString(qualityProfit)

                                GameTooltip_AddHighlightLine(GameTooltip, qualityLabel .. " " .. qualityProfitStr)
                            end
                        end
                    end
                end

                GameTooltip:Show()
            end)

            statLine:Show()
        end

        -- Concentration tooltip
        if allocation or order then
            frame.StatLines.ConcentrationStatLine:SetScript(
                "OnEnter",
                ---@param self RecipeStatLine
                ---@diagnostic disable-next-line: redefined-local
                function (self)
                    if not self.statLineType or not self.professionType or not self.baseValue then return end

                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:ClearLines()

                    local statString
                    if self.bonusValue then
                        statString = PROFESSIONS_CRAFTING_STAT_QUANTITY_TT_FMT:format(self.baseValue + self.bonusValue, self.baseValue, self.bonusValue)
                    else
                        statString = PROFESSIONS_CRAFTING_STAT_NO_BONUS_TT_FMT:format(self.baseValue)
                    end

                    GameTooltip_AddColoredDoubleLine(GameTooltip, PROFESSIONS_CRAFTING_STAT_CONCENTRATION, statString, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
                    GameTooltip_AddNormalLine(GameTooltip, PROFESSIONS_CRAFTING_STAT_CONCENTRATION_DESCRIPTION)

                    local noConProfit, conProfit, concentration
                    if order then
                        local operations = Optimization:GetRecipeAllocations(recipe, Optimization.Method.Cost, tx, orderOrRecraftGUID)
                        if operations then
                            noConProfit, conProfit, concentration = Prices:GetConcentrationValueForOrder(operations, order)
                        end
                    elseif allocation then
                        noConProfit, conProfit, concentration = Prices:GetConcentrationValue(recipe, operationInfo, allocation, recraftMods, optionalReagents, tx:IsApplyingConcentration())
                    end

                    if conProfit and concentration and concentration > 0 then
                        local conProfitStr = Util:NumCurrencyString(conProfit / concentration)
                        GameTooltip_AddBlankLineToTooltip(GameTooltip)
                        GameTooltip_AddColoredDoubleLine(GameTooltip, "Final profit per point", conProfitStr, NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR)

                        if noConProfit then
                            local conProfitIncStr = Util:NumCurrencyString((conProfit - noConProfit) / concentration)
                            GameTooltip_AddColoredDoubleLine(GameTooltip, "Profit change per point", conProfitIncStr, NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
                        end
                    end

                    GameTooltip:Show()
                end
            )
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