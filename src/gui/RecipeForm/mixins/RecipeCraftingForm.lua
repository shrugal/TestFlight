---@class Addon
local Addon = select(2, ...)
local GUI, Optimization, Orders, Prices, Recipes, Util = Addon.GUI, Addon.Optimization, Addon.Orders, Addon.Prices, Addon.Recipes, Addon.Util
local NS = GUI.RecipeForm

local Parent = NS.RecipeForm

---@class GUI.RecipeForm.RecipeCraftingForm: GUI.RecipeForm.RecipeForm
---@field form RecipeCraftingForm
---@field skillSpinner NumericInputSpinner
---@field decreaseBtn ButtonFitToText
---@field optimizeBtn ButtonFitToText
---@field increaseBtn ButtonFitToText
local Self = Mixin(NS.RecipeCraftingForm, Parent)

function Self:GetTrackCheckbox()
    return self.form.TrackRecipeCheckbox
end

-- Experiment box

function Self:UpdateExperimentBox()
    Parent.UpdateExperimentBox(self)

    if self:IsCraftingRecipe() then return end

    self.experimentBox:SetShown(false)
end

-- Skill spinner

---@param frame NumericInputSpinner
function Self:SkillSpinnerOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Show result with extra crafting skill.")
    GameTooltip:Show()
end

---@param frame NumericInputSpinner
---@param value number
function Self:SkillSpinnerOnChange(frame, value)
    Addon:SetExtraSkill(value)
end

---@param parent Frame
function Self:InsertSkillSpinner(parent, ...)
    self.skillSpinner = GUI:InsertNumericSpinner(
        parent,
        Util:FnBind(self.SkillSpinnerOnEnter, self),
        Util:FnBind(self.SkillSpinnerOnChange, self),
        ...
    )
end

function Self:UpdateSkillSpinner()
    self.skillSpinner:SetShown(Addon.enabled and not ProfessionsUtil.IsCraftingMinimized() and self:IsCraftingRecipe())
    self.skillSpinner:SetValue(Addon.extraSkill)
end

-- Optimization buttons

function Self:DecreaseQualityButtonOnClick()
    self:ChangeCraftingFormQualityBy(-1)
end

function Self:OptimizeQualityButtonOnClick()
    self:SetCraftingFormQuality()
end

function Self:IncreaseQualityButtonOnClick()
    self:ChangeCraftingFormQualityBy(1)

end

---@param parent Frame
function Self:InsertOptimizationButtons(parent, ...)
    if not Prices:IsSourceInstalled() then return end

    self.decreaseBtn = GUI:InsertButton("<",   	 parent, nil, Util:FnBind(self.DecreaseQualityButtonOnClick, self), ...)
    self.optimizeBtn = GUI:InsertButton("Optimize", parent, nil, Util:FnBind(self.OptimizeQualityButtonOnClick, self), "LEFT", self.decreaseBtn, "RIGHT", 30)
    self.increaseBtn = GUI:InsertButton(">",        parent, nil, Util:FnBind(self.IncreaseQualityButtonOnClick, self), "LEFT", self.optimizeBtn, "RIGHT", 30)

    self.decreaseBtn.tooltipText = "Decrease quality"
    self.optimizeBtn.tooltipText = "Optimize for current quality"
    self.increaseBtn.tooltipText = "Increase quality"
end

function Self:UpdateOptimizationButtons()
    if not Prices:IsSourceInstalled() then return end

    local recipe, recipeInfo, op, tx = self.form.recipeSchematic, self.form.currentRecipeInfo, self.form:GetRecipeOperationInfo(), self.form.transaction
    local isSalvage, isMinimized = recipe.recipeType == Enum.TradeskillRecipeType.Salvage, ProfessionsUtil.IsCraftingMinimized()
    local order = self:GetOrder()

    local show = op and not isSalvage and not isMinimized
        and not (order and order.orderState ~= Enum.CraftingOrderState.Claimed)

    self.decreaseBtn:SetShown(show)
    self.optimizeBtn:SetShown(show)
    self.increaseBtn:SetShown(show)

    if not show then return end

    local canDecrease, canIncrease = Optimization:CanChangeCraftQuality(
        recipe,
        recipeInfo,
        op,
        tx:CreateOptionalOrFinishingCraftingReagentInfoTbl(),
        tx:GetRecraftAllocation(),
        order
    )

    self.decreaseBtn:SetEnabled(canDecrease)
    self.increaseBtn:SetEnabled(canIncrease)
end

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

    if not Recipes:IsTracked(recipe) then return end

    local order = self:GetOrder()
    if order and not Orders:IsTracked(order) then return end
    if not order and Orders:GetTracked(recipe) then return end

    -- Set or update tracked allocation
    local allocation = Recipes:GetTrackedAllocation(recipe)
    if allocation then
        self:AllocateReagents(allocation)
    else
        Recipes:SetTrackedByForm(self)
    end
end

function Self:Refresh()
    self:UpdateExperimentBox()
    self:UpdateSkillSpinner()
    self:UpdateOptimizationButtons()
end

function Self:UpdateDetailsStats()
    local op = self.form:GetRecipeOperationInfo()
    if not op or not op.baseDifficulty then return end

    local skillNoExtra = op.baseSkill + op.bonusSkill - Addon.extraSkill
    local difficulty = op.baseDifficulty + op.bonusDifficulty

    self.skillSpinner:SetMinMaxValues(0, math.max(0, difficulty - skillNoExtra))
    self.skillSpinner:SetValue(Addon.extraSkill)

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

    ---@type ProfessionAllocations | ItemMixin?, CraftingReagentInfo[], string?
    local allocation, optionalReagents, recraftItemGUID
    if isSalvage then
        allocation = tx:GetSalvageAllocation()
    else
        allocation = tx.allocationTbls
        optionalReagents, recraftItemGUID = tx:CreateOptionalOrFinishingCraftingReagentInfoTbl(), tx:GetRecraftAllocation()
    end

    if isUnclaimedOrder then ---@cast order -?
        local quality = tx:IsApplyingConcentration() and order.minQuality - 1 or order.minQuality
        local allocations = Optimization:GetRecipeAllocations(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)
        allocation = allocations and allocations[math.max(quality, Util:TblMinKey(allocations))]
    end

    ---@type string?, number?, number?, number?, number?, number?, number?, number?
    local reagentPriceStr, reagentPrice, profit, revenue, traderCut, resourcefulness, rewards, multicraft
    if allocation then
        reagentPrice, _, profit, revenue, resourcefulness, multicraft, rewards, traderCut = Prices:GetRecipePrices(recipe, operationInfo, allocation, order, optionalReagents)
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
                    local allocations = Optimization:GetRecipeAllocations(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)

                    if allocations then
                        GameTooltip_AddBlankLineToTooltip(GameTooltip)
                        GameTooltip_AddNormalLine(GameTooltip, "Optimal costs:")

                        for i=1,5 do
                            local qualityAllocation = allocations[i]
                            if qualityAllocation then
                                local qualityLabel = CreateAtlasMarkup(Professions.GetIconForQuality(i), 20, 20)
                                local qualityPrice = Prices:GetRecipeAllocationPrice(recipe, qualityAllocation, order, optionalReagents)
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
        if profit then
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
                GameTooltip_AddColoredDoubleLine(GameTooltip, "Reagent costs", Util:NumCurrencyString(-reagentPrice), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
                GameTooltip_AddColoredDoubleLine(GameTooltip, order and "Consortium cut" or "Auction fee", Util:NumCurrencyString(-traderCut), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)

                if supportsQualities and not isSalvage then
                    local allocations = Optimization:GetRecipeAllocations(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)

                    if allocations then
                        GameTooltip_AddBlankLineToTooltip(GameTooltip)
                        GameTooltip_AddNormalLine(GameTooltip, "Optimal profits:")

                        for i=1,5 do
                            local qualityAllocation = allocations[i]
                            if qualityAllocation then
                                local qualityLabel = CreateAtlasMarkup(Professions.GetIconForQuality(i), 20, 20)
                                local _, _, qualityProfit = Prices:GetRecipePrices(recipe, operationInfo, qualityAllocation, order, optionalReagents, i)
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
                        local allocations = Optimization:GetRecipeAllocations(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)
                        if allocations then
                            noConProfit, conProfit, concentration = Prices:GetConcentrationValueForOrder(recipe, operationInfo, allocations, optionalReagents, order)
                        end
                    elseif allocation then
                        noConProfit, conProfit, concentration = Prices:GetConcentrationValue(recipe, operationInfo, allocation, optionalReagents, tx:IsApplyingConcentration())
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

function Self:GetQuality()
    local op = self.form:GetRecipeOperationInfo()
    if op.isQualityCraft then return floor(op.quality) end
end

---@param quality? number
---@param exact? boolean
function Self:SetCraftingFormQuality(quality, exact)
    if not quality then quality = math.floor(self.form:GetRecipeOperationInfo().quality) end

    local recipe, recipeInfo, op, tx = self.form.recipeSchematic, self.form.currentRecipeInfo, self.form:GetRecipeOperationInfo(), self.form.transaction
    local order = self:GetOrder()
    local optionalReagents, recraftItemGUID = tx:CreateOptionalOrFinishingCraftingReagentInfoTbl(), tx:GetRecraftAllocation()
    local allocations = Optimization:GetRecipeAllocations(recipe, recipeInfo, op, optionalReagents, recraftItemGUID, order)
    local qualityAllocation = allocations and (allocations[quality] or not exact and allocations[quality + 1])

    if not qualityAllocation then return end

    self:AllocateReagents(qualityAllocation)
end

---@param by number
function Self:ChangeCraftingFormQualityBy(by)
    local quality = math.floor(self.form:GetRecipeOperationInfo().quality)
    self:SetCraftingFormQuality(quality + by, true)
end

function Self:IsCraftingRecipe()
    local recipeInfo = self.form:GetRecipeInfo()
    if not recipeInfo then return end

    return not recipeInfo.isGatheringRecipe and not recipeInfo.isDummyRecipe
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

function Self:OnAddonLoaded()
    Parent.OnAddonLoaded(self)

    self.form:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, self.OnAllocationModified, self)

    Addon:RegisterCallback(Addon.Event.Enabled, self.OnEnabled, self)
    Addon:RegisterCallback(Addon.Event.Disabled, self.OnDisabled, self)
    Addon:RegisterCallback(Addon.Event.ExtraSkillUpdated, self.OnExtraSkillUpdated, self)
end