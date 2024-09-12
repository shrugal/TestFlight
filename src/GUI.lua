---@type string
local Name = ...
---@class TestFlight
local Addon = select(2, ...)
local Optimization, Prices, Util = Addon.Optimization, Addon.Prices, Addon.Util

---@class GUI
local Self = {}
Addon.GUI = Self

Self.Hooks = {}

---@type CheckButton[]
Self.experimentBoxes = {}
---@type NumericInputSpinner[]
Self.skillSpinners = {}
---@type table<table, NumericInputSpinner>, table<integer, integer>
Self.amountSpinners = {}
---@type integer?
Self.craftingRecipeID = nil
---@type number?, string?
Self.recraftRecipeID, Self.recraftItemLink = nil, nil
---@type OptimizationFormButton[], OptimizationFormButton[], OptimizationFormButton[]
Self.decreaseBtns, Self.optimizeBtns, Self.increaseBtns = {}, {}, {}

-- Blizzard frames

---@type CraftingPage, CraftingForm, Flyout
local craftingPage, craftingForm, flyout
---@type OrdersView, OrdersForm
local ordersView, ordersForm
---@type CustomerOrderForm, OrdersFormReagents
local customerOrderForm, customerOrderReagents
local recipeTracker = ProfessionsRecipeTracker

---------------------------------------
--             Lifecycle
---------------------------------------

function Self:OnEnable()
    Util:TblHook(ItemUtil, "GetCraftingReagentCount", Util.FnInfinite)
    Util:TblHook(Professions, "GetReagentSlotStatus", Util.FnFalse)
    Util:TblHook(ProfessionsUtil, "GetReagentQuantityInPossession", Util.FnInfinite)
    Util:TblHook(flyout, "InitializeContents", Self.Hooks.Flyout.InitializeContents)

    -- ProfessionsFrame
    Util:TblHook(craftingForm, "GetRecipeOperationInfo", Self.Hooks.RecipeCraftingForm.GetRecipeOperationInfo)
    Util:TblHook(ordersForm, "GetRecipeOperationInfo", Self.Hooks.RecipeCraftingForm.GetRecipeOperationInfo)

    -- ObjectiveTrackerFrame
    Util:TblHook(recipeTracker, "Update", Self.Hooks.RecipeTracker.Update)

    Self:Refresh()
end

function Self:OnDisable()
    Util:TblUnhook(ItemUtil, "GetCraftingReagentCount")
    Util:TblUnhook(Professions, "GetReagentSlotStatus")
    Util:TblUnhook(ProfessionsUtil, "GetReagentQuantityInPossession")
    Util:TblUnhook(flyout, "InitializeContents")

    -- ProfessionsFrame
    Util:TblUnhook(craftingForm, "GetRecipeOperationInfo")
    Util:TblUnhook(ordersForm, "GetRecipeOperationInfo")

    -- Clear reagents in locked slots
    self:ClearExperimentalReagentSlots(craftingForm)
    self:ClearExperimentalReagentSlots(ordersForm)
    self:ClearExperimentalReagentSlots(customerOrderForm)

    -- ObjectiveTrackerFrame
    Util:TblUnhook(recipeTracker, "Update")

    Self:Refresh()
end

function Self:Refresh()
    for _, checkbox in pairs(Self.experimentBoxes) do
        checkbox:SetChecked(Addon.enabled)
    end

    -- ProfessionsFrame.CraftingPage
    if craftingPage and craftingPage:IsVisible() then
        craftingForm:Refresh()
        craftingPage:ValidateControls()
    end

    -- ProfessionsFrame.OrdersPage
    if ordersView and ordersView:IsVisible() then
        ordersForm:Refresh()
    end

    -- ProfessionsCustomerOrdersFrame
    if customerOrderForm and customerOrderForm:IsVisible() then
        customerOrderForm:InitSchematic()
        if Addon.enabled then
            customerOrderForm.PaymentContainer.ListOrderButton:SetEnabled(false)
        end
    end

    -- ObjectiveTrackerFrame
    ObjectiveTrackerFrame:Update()
end

---------------------------------------
--             Elements
---------------------------------------

---@param frameType FrameType
---@param parent? Frame
---@param template? string
---@param onEnter? function
local function InsertElement(frameType, parent, template, onEnter, ...)
    local input = CreateFrame(frameType, nil, parent, template)

    if onEnter then
        input:SetScript("OnEnter", onEnter)
        input:SetScript("OnLeave", GameTooltip_Hide)
    end

    if ... then input:SetPoint(...) end

    return input
end

---@param text string
---@param parent? Frame
---@param onEnter? function
---@param onClick? function
local function InsertButton(text, parent, onEnter, onClick, ...)
    local input = InsertElement("CheckButton", parent, "UIPanelButtonTemplate", onEnter, ...) --[[@as ButtonFitToText]]

    input:SetScript("OnClick", onClick)
    input:SetTextToFit(text)

    return input
end

---@param parent Frame
---@param onEnter? function
---@param onValueChanged? function
local function InsertNumericSpinner(parent, onEnter, onValueChanged, ...)
    local input = InsertElement("EditBox", parent, "NumericInputSpinnerTemplate", onEnter, ...) --[[@as NumericInputSpinner]]

    input:Hide()
    if onValueChanged then input:SetOnValueChangedCallback(onValueChanged) end

    return input
end

---@param parent? Frame
---@param onEnter? function
---@param onClick? function
local function InsertCheckbox(parent, onEnter, onClick, ...)
    local input = InsertElement("CheckButton", parent, "UICheckButtonTemplate", onEnter, ...) --[[@as CheckButton]]

    input:SetScript("OnClick", onClick)

    return input
end

-- Experiment checkbox

---@param self CheckButton
local function ExperimentBoxOnClick(self)
    if self:GetChecked() ~= Addon.enabled then Addon:Toggle() end
end

---@param self CheckButton
local function ExperimentBoxOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Experiment with crafting recipes without reagent and spec limits.")
    GameTooltip:Show()
end

---@param form RecipeForm
---@param parent Frame
local function InsertExperimentBox(form, parent, ...)
    local input = InsertCheckbox(parent, ExperimentBoxOnEnter, ExperimentBoxOnClick, ...)

    input.text:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode("Experiment"))
    input:SetChecked(Addon.enabled)

    Self.experimentBoxes[form] = input

    return input
end

-- Skill spinner

---@param self NumericInputSpinner
local function SkillSpinnerOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Show result with extra crafting skill.")
    GameTooltip:Show()
end

---@param self NumericInputSpinner
local function SkillSpinnerOnChange(self, value)
    Addon.extraSkill = max(0, value)

    if craftingForm:IsVisible() then
        craftingForm:UpdateDetailsStats()
        craftingForm:UpdateRecraftSlot()
    elseif ordersForm:IsVisible() then
        ordersForm:UpdateDetailsStats()
        ordersForm:UpdateRecraftSlot()
    end
end

---@param form RecipeCraftingForm
local function UpdateExperimentationElements(form)
    local info = form:GetRecipeInfo()
    local show = not ProfessionsUtil.IsCraftingMinimized() and not (info and (info.isGatheringRecipe or info.isDummyRecipe))

    Self.skillSpinners[form]:SetShown(show and Addon.enabled)
    Self.experimentBoxes[form]:SetShown(show)
end

-- Amount spinner

---@param self NumericInputSpinner
local function AmountSpinnerOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Set number of tracked recipe crafts.")
    GameTooltip:Show()
end

---@param GetRecipeID fun(): number?
local function AmountSpinnerOnChange(GetRecipeID)
    ---@param self NumericInputSpinner
    return function (self, value)
        local recipeID = GetRecipeID()
        if not recipeID then return end
        Addon.DB.amounts[recipeID] = value > 1 and value or nil
        ObjectiveTrackerFrame:Update()
    end
end

---@param form RecipeForm
---@param GetRecipeID fun(): number?
---@return NumericInputSpinner
local function InsertAmountSpinner(form, GetRecipeID, ...)
    local input = InsertNumericSpinner(form, AmountSpinnerOnEnter, AmountSpinnerOnChange(GetRecipeID), ...)

    input:SetMinMaxValues(1, math.huge)

    Self.amountSpinners[form] = input

    return input
end

---@param form RecipeCraftingForm
local function UpdateAmountSpinner(form)
    local amountSpinner, trackBox = Self.amountSpinners[form], form.TrackRecipeCheckbox
    amountSpinner:SetShown(trackBox:IsShown() and trackBox:GetChecked())
end

-- Optimization buttons

---@param self OptimizationFormButton
local function DecreaseQualityButtonOnClick(self)
    Self:ChangeCraftingFormQualityBy(self.form, -1)
end

---@param self OptimizationFormButton
local function OptimizeQualityButtonOnClick(self)
    Self:SetCraftingFormQuality(self.form)
end

---@param self OptimizationFormButton
local function IncreaseQualityButtonOnClick(self)
    Self:ChangeCraftingFormQualityBy(self.form, 1)

end

---@param parent Frame
---@param form RecipeCraftingForm
local function InsertOptimizationButtons(parent, form, ...)
    if not Prices:IsSourceInstalled() then return end

    local decreaseBtn = InsertButton("<",   	 parent, nil, DecreaseQualityButtonOnClick, ...) --[[@as OptimizationFormButton]]
    local optimizeBtn = InsertButton("Optimize", parent, nil, OptimizeQualityButtonOnClick, "LEFT", decreaseBtn, "RIGHT", 30) --[[@as OptimizationFormButton]]
    local increaseBtn = InsertButton(">",        parent, nil, IncreaseQualityButtonOnClick, "LEFT", optimizeBtn, "RIGHT", 30) --[[@as OptimizationFormButton]]

    decreaseBtn.form = form
    optimizeBtn.form = form
    increaseBtn.form = form

    decreaseBtn.tooltipText = "Decrease quality"
    optimizeBtn.tooltipText = "Optimize for current quality"
    increaseBtn.tooltipText = "Increase quality"

    Self.decreaseBtns[form] = decreaseBtn
    Self.optimizeBtns[form] = optimizeBtn
    Self.increaseBtns[form] = increaseBtn
end

---@param form RecipeCraftingForm
local function UpdateOptimizationButtons(form)
    if not Prices:IsSourceInstalled() then return end

    local recipe, op = form.recipeSchematic, form:GetRecipeOperationInfo()
    local decreaseBtn, optimizeBtn, increaseBtn = Self.decreaseBtns[form], Self.optimizeBtns[form], Self.increaseBtns[form]
    local isSalvage, isMinimized = recipe.recipeType == Enum.TradeskillRecipeType.Salvage, ProfessionsUtil.IsCraftingMinimized()
    local order = Self:GetFormOrder(form)

    local show = op and op.isQualityCraft
        and not isSalvage and not isMinimized
        and not (order and order.orderState ~= Enum.CraftingOrderState.Claimed)

    decreaseBtn:SetShown(show)
    optimizeBtn:SetShown(show)
    increaseBtn:SetShown(show)

    if not show then return end

    local canDecrease, canIncrease = Optimization:CanChangeCraftQuality(
        recipe,
        form.currentRecipeInfo,
        op,
        form.transaction:CreateOptionalOrFinishingCraftingReagentInfoTbl(),
        form.transaction:GetRecraftAllocation(),
        order
    )

    decreaseBtn:SetEnabled(canDecrease)
    increaseBtn:SetEnabled(canIncrease)
end

-- List order button

---@param self Button
local function ListOrderButtonOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip_AddErrorLine(GameTooltip, "Experimentation mode is enabled.");
    GameTooltip:Show();
end

---------------------------------------
--               Hooks
---------------------------------------

-- CraftingPage

Self.Hooks.CraftingPage = {}

---@param self CraftingPage
function Self.Hooks.CraftingPage.ValidateControls(self)
    if not Addon.enabled then return end
    self.CreateButton:SetEnabled(false)
    self.CreateAllButton:SetEnabled(false)
    self.CreateMultipleInputBox:SetEnabled(false)
    self:SetCreateButtonTooltipText("Experimentation mode is enabled.")
end

-- RecipeCraftingForm

Self.Hooks.RecipeCraftingForm = {}

---@param self RecipeCraftingForm
Self.Hooks.RecipeCraftingForm.GetRecipeOperationInfo = function(self)
    ---@type CraftingOperationInfo
    local op = Util:TblGetHooks(self).GetRecipeOperationInfo(self)
    if not op then return end

    op.baseSkill = op.baseSkill + Addon.extraSkill

    if op.isQualityCraft then
        local skill, difficulty = op.baseSkill + op.bonusSkill, op.baseDifficulty + op.bonusDifficulty

        local p = skill / difficulty
        local rank = self.currentRecipeInfo.maxQuality
        local breakpoints = Addon.QUALITY_BREAKPOINTS[rank]

        for i, v in ipairs(breakpoints) do
            if v > p then rank = i - 1 break
            end
        end

        local lower, upper = breakpoints[rank], breakpoints[rank + 1] or 1
        local quality = rank + (upper == lower and 0 or (p - lower) / (upper - lower))
        local qualityID = self.currentRecipeInfo.qualityIDs[rank]

        op.quality = quality
        op.craftingQuality = rank
        op.craftingQualityID = qualityID
        op.lowerSkillThreshold = difficulty * lower
        op.upperSkillTreshold = difficulty * upper
    end

    return op
end

---@param self RecipeCraftingForm
---@param recipe CraftingRecipeSchematic
function Self.Hooks.RecipeCraftingForm:Init(recipe)
    UpdateExperimentationElements(self)
    UpdateOptimizationButtons(self)

    if self ~= craftingForm then return end

    UpdateAmountSpinner(self)

    local amountSpinner = Self.amountSpinners[self]
    amountSpinner:SetValue(recipe and Addon.DB.amounts[recipe.recipeID] or 1)

    self.recraftSlot.InputSlot:SetScript("OnEnter", Self.Hooks.RecipeCraftingForm.RecraftInputSlotOnEnter)
    self.recraftSlot.OutputSlot:SetScript("OnClick", Self.Hooks.RecipeCraftingForm.RecraftOutputSlotOnClick)

    if Self.recraftRecipeID then
        local same = Self.recraftRecipeID == recipe.recipeID
        Self:SetRecraftRecipe(same and Self.recraftRecipeID or nil, same and Self.recraftItemLink or nil)
    end
end

---@param self RecipeCraftingForm
function Self.Hooks.RecipeCraftingForm:Refresh()
    UpdateExperimentationElements(self)
    UpdateOptimizationButtons(self)

    if self ~= craftingForm then return end

    UpdateAmountSpinner(self)
end

---@param self RecipeCraftingForm
function Self.Hooks.RecipeCraftingForm:UpdateDetailsStats()
    local op = self:GetRecipeOperationInfo()
    if not op or not op.baseDifficulty then return end

    local skillNoExtra = op.baseSkill + op.bonusSkill - Addon.extraSkill
    local difficulty = op.baseDifficulty + op.bonusDifficulty

    Self.skillSpinners[self]:SetMinMaxValues(0, math.max(0, difficulty - skillNoExtra))
    Self.skillSpinners[self]:SetValue(Addon.extraSkill)

    UpdateOptimizationButtons(self)
end

---@param self RecipeFormDetails
---@param operationInfo CraftingOperationInfo
---@param supportsQualities boolean
---@param isGatheringRecipe boolean
function Self.Hooks.RecipeCraftingForm:DetailsSetStats(operationInfo, supportsQualities, isGatheringRecipe)
    if isGatheringRecipe then return end
    if not Prices:IsSourceInstalled() then return end

    local form = self:GetParent() --[[@as RecipeCraftingForm]]
    local recipeInfo, tx, order = self.recipeInfo, self.transaction, Self:GetFormOrder(form)
    local recipe = tx:GetRecipeSchematic()
    local isSalvage = recipe.recipeType == Enum.TradeskillRecipeType.Salvage

    ---@type ProfessionAllocations | ItemMixin?, CraftingReagentInfo[], string?
    local allocation, optionalReagents, recraftItemGUID
    if isSalvage then
        allocation = tx:GetSalvageAllocation()
    else
        allocation = tx.allocationTbls
        optionalReagents, recraftItemGUID = tx:CreateOptionalOrFinishingCraftingReagentInfoTbl(), tx:GetRecraftAllocation()
    end

    if order and order.orderState ~= Enum.CraftingOrderState.Claimed then
        local quality = tx:IsApplyingConcentration() and order.minQuality - 1 or order.minQuality
        local allocations = Optimization:GetRecipeAllocations(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)
        allocation = allocations and allocations[math.max(quality, Util:TblMinKey(allocations))]
    end

    ---@type string?, number?, number?, number?, number?, number?, number?
    local reagentPriceStr, reagentPrice, profit, revenue, traderCut, resourcefulness, multicraft
    if allocation then
        reagentPrice, _, profit, revenue, traderCut, resourcefulness, multicraft = Prices:GetRecipePrices(recipe, operationInfo, allocation, order, optionalReagents)
        reagentPriceStr = Util:NumCurrencyString(reagentPrice)
    end

    local function applyExtra()
        if self.recipeInfo == nil or ProfessionsUtil.IsCraftingMinimized() then return end

        -- Cost
        do
            local label = COSTS_LABEL:gsub(":", "")

            local statLine = self.statLinePool:Acquire() --[[@as RecipeStatLine]]
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

            local statLine = self.statLinePool:Acquire() --[[@as RecipeStatLine]]
            statLine.layoutIndex = 1001
            statLine:SetLabel(label) -- TODO
            statLine.RightLabel:SetText(profitStr or "-")

            statLine:SetScript("OnEnter", function(line)
                GameTooltip:SetOwner(line, "ANCHOR_RIGHT")

                GameTooltip_AddColoredDoubleLine(GameTooltip, label, profitStr, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
                GameTooltip_AddNormalLine(GameTooltip, "Based on reagent and result market prices, taking resourcefulness and multicraft into account.")

                if recipeInfo.supportsCraftingStats then
                    GameTooltip_AddBlankLineToTooltip(GameTooltip)
                    GameTooltip_AddNormalLine(GameTooltip, "Breakdown:")

                    GameTooltip_AddColoredDoubleLine(GameTooltip, order and "Commission" or "Sell price", Util:NumCurrencyString(revenue), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
                    GameTooltip_AddColoredDoubleLine(GameTooltip, "Resourcefulness", Util:NumCurrencyString(resourcefulness), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
                    GameTooltip_AddColoredDoubleLine(GameTooltip, "Multicraft", Util:NumCurrencyString(multicraft), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
                    GameTooltip_AddColoredDoubleLine(GameTooltip, "Reagent costs", Util:NumCurrencyString(-reagentPrice), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
                    GameTooltip_AddColoredDoubleLine(GameTooltip, order and "Consortium cut" or "Auction fee", Util:NumCurrencyString(-traderCut), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
                end

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

            -- Concentration tooltip
            if allocation and (operationInfo.concentrationCost or 0) > 0 then --[[@cast reagentPrice -?]]
                self.StatLines.ConcentrationStatLine:SetScript(
                    "OnEnter",
                    ---@param self RecipeStatLine
                    ---@diagnostic disable-next-line: redefined-local
                    function (self)
                        if not self.statLineType or not self.professionType or not self.baseValue then return end

                        local concentrationProfit = profit
                        if not order and not tx:IsApplyingConcentration() then
                            local resultPrice = Prices:GetRecipeResultPrice(recipe, operationInfo, optionalReagents, operationInfo.craftingQualityID + 1)
                            concentrationProfit = Prices:GetRecipeProfit(recipe, operationInfo, allocation, reagentPrice, resultPrice, nil, optionalReagents)
                        end
                        
                        local profitPerPointStr = Util:NumCurrencyString(concentrationProfit / operationInfo.concentrationCost)

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

                        GameTooltip_AddBlankLineToTooltip(GameTooltip)
                        GameTooltip_AddColoredDoubleLine(GameTooltip, "Profit per point", profitPerPointStr, NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR)

                        GameTooltip:Show()
                    end
                )
            end
        end

        self.StatLines:Layout()
        self:Layout()
    end

    local origApplyLayout = self.ApplyLayout
    self.ApplyLayout = function() origApplyLayout() applyExtra() end

    applyExtra()
end

---@param self ReagentSlot
function Self.Hooks.RecipeCraftingForm:RecraftInputSlotOnEnter()
    local form = self:GetParent():GetParent() --[[@as RecipeCraftingForm]]

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    local itemGUID = form.transaction:GetRecraftAllocation()
    if itemGUID then
        GameTooltip:SetItemByGUID(itemGUID)
    elseif Self.recraftRecipeID then
        local link = Self.recraftItemLink or C_TradeSkillUI.GetRecipeItemLink(Self.recraftRecipeID)
        GameTooltip:SetHyperlink(link)
    end

    if itemGUID or Self.recraftRecipeID then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddInstructionLine(GameTooltip, RECRAFT_REAGENT_TOOLTIP_CLICK_TO_REPLACE)
    else
        GameTooltip_AddInstructionLine(GameTooltip, RECRAFT_REAGENT_TOOLTIP_CLICK_TO_ADD)
    end

    GameTooltip:Show()
end

---@param self OutputSlot
function Self.Hooks.RecipeCraftingForm:RecraftOutputSlotOnClick()
    local form = self:GetParent():GetParent() --[[@as RecipeCraftingForm]]

    local itemGUID = form.transaction:GetRecraftAllocation()
    local reagents = form.transaction:CreateCraftingReagentInfoTbl()
    local op = form:GetRecipeOperationInfo()

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    local outputItemInfo = C_TradeSkillUI.GetRecipeOutputItemData(
        form.recipeSchematic.recipeID,
        reagents,
        itemGUID,
        op and op.craftingQualityID
    )

    if outputItemInfo and outputItemInfo.hyperlink then
        HandleModifiedItemClick(outputItemInfo.hyperlink)
    end
end

-- OrdersView

Self.Hooks.OrdersView = {}

---@param self OrdersView
function Self.Hooks.OrdersView:UpdateCreateButton()
    if not Addon.enabled then return end
    self.CreateButton:SetEnabled(false)
    self.CreateButton:SetScript("OnEnter", Self.Hooks.OrdersView.CreateButtonOnEnter)
end

---@param self Button
function Self.Hooks.OrdersView:CreateButtonOnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_AddErrorLine(GameTooltip, "Experimentation mode is enabled.")
    GameTooltip:Show()
end

-- CustomerOrderForm

Self.Hooks.CustomerOrderForm = {}

---@param self CustomerOrderForm
function Self.Hooks.CustomerOrderForm.InitSchematic(self)
    local recipeID = self.order.spellID
    local trackBox = self.TrackRecipeCheckbox.Checkbox
    local amountSpinner = Self.amountSpinners[customerOrderForm]

    amountSpinner:SetShown(trackBox:IsShown() and trackBox:GetChecked())
    amountSpinner:SetValue(recipeID and Addon.DB.amounts[recipeID] or 1)
end

---@param self CustomerOrderForm
function Self.Hooks.CustomerOrderForm.UpdateListOrderButton(self)
    if not Addon.enabled then return end
    if self.committed then return end

    local listOrderButton = self.PaymentContainer.ListOrderButton;

    listOrderButton:SetEnabled(false);
    listOrderButton:SetScript("OnEnter", ListOrderButtonOnEnter)
end

-- RecipeTracker

Self.Hooks.RecipeTracker = {}

function Self.Hooks.RecipeTracker.Update(...)
    local fn1 = Util:TblUnhook(ProfessionsUtil, "GetReagentQuantityInPossession")
    local fn2 = Util:TblUnhook(ItemUtil, "GetCraftingReagentCount")

    Util:TblGetHooks(recipeTracker).Update(...)

    Util:TblHook(ProfessionsUtil, "GetReagentQuantityInPossession", fn1)
    Util:TblHook(ItemUtil, "GetCraftingReagentCount", fn2)
end

---@param self Button
---@param mouseButton string
function Self.Hooks.RecipeTracker.LineOnClick(self, mouseButton)
    local line = self:GetParent() --[[@as QuestObjectiveAnimLine]]
    local block = line:GetParent()

    if mouseButton == "RightButton"
        or IsModifiedClick("RECIPEWATCHTOGGLE")
        or IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow()
    then
        return recipeTracker:OnBlockHeaderClick(block, mouseButton)
    end

    CloseDropDownMenus()

    if AuctionHouseFrame and AuctionHouseFrame:IsVisible() then
        if AuctionHouseFrame:SetSearchText(line.itemName) then AuctionHouseFrame.SearchBar:StartSearch() end
    else
        EventRegistry:TriggerEvent("Professions.ReagentClicked", line.itemName)
    end
end

function Self.Hooks.RecipeTracker.AddRecipe(self, recipeID, isRecraft)
    local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)
    local amount = Addon.DB.amounts[recipe.recipeID]

    -- Set header
    local block = self:GetExistingBlock(NegateIf(recipeID, isRecraft))

    local blockName = recipe.name
    if isRecraft then blockName = PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER:format(blockName) end
    if (amount or 1) > 1 then blockName = ("%s (%d)"):format(blockName, amount) end

    block:SetHeader(blockName);

    -- Set reagents
    local slots = {};
    for j, schematic in ipairs(recipe.reagentSlotSchematics) do
        if ProfessionsUtil.IsReagentSlotRequired(schematic) then
            if ProfessionsUtil.IsReagentSlotModifyingRequired(schematic) then
                table.insert(slots, 1, j);
            else
                table.insert(slots, j);
            end
        end
    end

    for _, j in ipairs(slots) do
        local schematic = recipe.reagentSlotSchematics[j]

        local reagent = schematic.reagents[1]
        local quantity = ProfessionsUtil.AccumulateReagentsInPossession(schematic.reagents)
        local quantityRequired = schematic.quantityRequired * (Addon.DB.amounts[recipe.recipeID] or 1)
        local metQuantity = quantity >= quantityRequired
        local name = nil

        if ProfessionsUtil.IsReagentSlotBasicRequired(schematic) then
            if reagent.itemID then
                name = Item:CreateFromItemID(reagent.itemID):GetItemName();
            elseif reagent.currencyID then
                local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
                if currencyInfo then name = currencyInfo.name end
            end
        elseif ProfessionsUtil.IsReagentSlotModifyingRequired(schematic) and schematic.slotInfo then
            name = schematic.slotInfo.slotText
        end

        if name then
            local count = PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT:format(quantity, quantityRequired)
            local text = PROFESSIONS_TRACKER_REAGENT_FORMAT:format(count, name)
            local dashStyle = metQuantity and OBJECTIVE_DASH_STYLE_HIDE or OBJECTIVE_DASH_STYLE_SHOW
            local colorStyle = OBJECTIVE_TRACKER_COLOR[metQuantity and "Complete" or "Normal"]

            ---@type QuestObjectiveAnimLine
            local line = block:GetExistingLine(j)

            -- Dash style
            if line.dashStyle ~= dashStyle then
                line.Dash[metQuantity and "Hide" or "Show"](line.Dash)
                line.Dash:SetText(QUEST_DASH);
                line.dashStyle = dashStyle
            end

            -- Text
            local oldHeight = line:GetHeight()
            local newHeight = block:SetStringText(line.Text, text, false, colorStyle, block.isHighlighted)
            line:SetHeight(newHeight)
            block.height = block.height - oldHeight + newHeight

            -- Icon
            line.Icon:SetShown(metQuantity)

            -- OnClick
            line.itemName = name
            if not line.Button then
                line.Button = CreateFrame("Button", nil, line)
                line.Button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                line.Button:SetAllPoints(line)
                line.Button:SetScript("OnClick", Self.Hooks.RecipeTracker.LineOnClick)
            end
        end
    end
end

-- Flyout

Self.Hooks.Flyout = {}

function Self.Hooks.Flyout.InitializeContents(...)
    flyout.OnElementEnabledImplementation = flyout.GetElementValidImplementation or Util.FnTrue
    Util:TblGetHooks(flyout).InitializeContents(...)
end

---------------------------------------
--              Util
---------------------------------------

---@return RecipeForm?
function Self:GetVisibleForm()
    if craftingForm and craftingForm:IsVisible() then return craftingForm end
    if ordersForm and ordersForm:IsVisible() then return ordersForm end
    if customerOrderForm and customerOrderForm:IsVisible() then return customerOrderForm end
end

---@param form RecipeForm?
function Self:GetFormOrder(form)
    if not form then form = self:GetVisibleForm() end
    if form == ordersForm then return ordersView.order end
    if form == customerOrderForm then return customerOrderForm.order end
end

function Self:SetRecraftRecipe(recipeId, link, transition)
    if recipeId and not link then
        link = C_TradeSkillUI.GetRecipeItemLink(recipeId)
        if not link then recipeId = nil end
    end

    Self.recraftRecipeID = recipeId
    Self.recraftItemLink = link

    if not recipeId then return end

    if transition then
        Professions.SetRecraftingTransitionData({ isRecraft = true, itemLink = link })
        C_TradeSkillUI.OpenRecipe(recipeId)
    end

    craftingForm.recraftSlot:Init(nil, Util.FnTrue, Util.FnNoop, link)
end

---@param form RecipeCraftingForm
---@param quality? number
---@param exact? boolean
function Self:SetCraftingFormQuality(form, quality, exact)
    if not quality then quality = math.floor(form:GetRecipeOperationInfo().quality) end

    local recipe, recipeInfo, operationInfo, tx = form.recipeSchematic, form.currentRecipeInfo, form:GetRecipeOperationInfo(), form.transaction
    local order = self:GetFormOrder(form)
    local optionalReagents, recraftItemGUID = tx:CreateOptionalOrFinishingCraftingReagentInfoTbl(), tx:GetRecraftAllocation()
    local allocations = Optimization:GetRecipeAllocations(recipe, recipeInfo, operationInfo, optionalReagents, recraftItemGUID, order)
    local qualityAllocation = allocations and (allocations[quality] or not exact and allocations[quality + 1])

    if not qualityAllocation then return end

    Self:SetReagentAllocation(form, qualityAllocation)
end


---@param form RecipeCraftingForm
---@param by number
function Self:ChangeCraftingFormQualityBy(form, by)
    local quality = math.floor(form:GetRecipeOperationInfo().quality)
    Self:SetCraftingFormQuality(form, quality + by, true)
end

---@param form RecipeForm
---@param allocation RecipeAllocation
function Self:SetReagentAllocation(form, allocation)
    for slotIndex,allocations in pairs(allocation) do
        self:SetReagentSlotAllocation(form, slotIndex, allocations, true)
    end

    for slot in form.reagentSlotPool:EnumerateActive() do slot:Update() end

    form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

---@param form RecipeForm
---@param slotIndex number
---@param allocations ProfessionTransationAllocations
function Self:SetReagentSlotAllocation(form, slotIndex, allocations, silent)
    ---@type ReagentSlot
    local slot
    for s in form.reagentSlotPool:EnumerateActive() do if s:GetSlotIndex() == slotIndex then slot = s break end end

    if not slot or slot:IsUnallocatable() then return end

    if not Addon.enabled then
        for _,reagent in allocations:Enumerate() do
            if reagent.quantity > Optimization:GetReagentQuantity(reagent) then Addon:Enable() break end
        end
    end

    form.transaction:OverwriteAllocations(slotIndex, allocations)
    form.transaction:SetManuallyAllocated(true)

    if silent then return end

    slot:Update()

    form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

---@param form RecipeForm
function Self:ClearExperimentalReagentSlots(form)
    if not form or not form.reagentSlots then return end

    for _,slots in pairs(form.reagentSlots) do
        for _, slot in pairs(slots) do
            local slotIndex = slot:GetReagentSlotSchematic().slotIndex

            for _,allocation in form.transaction:EnumerateAllocations(slotIndex) do
                local q = Optimization:GetReagentQuantity(allocation.reagent)
                if allocation.quantity > q then
                    self:ResetReagentSlot(form, slot)
                    break
                end
            end
        end
    end
end

---@param form RecipeForm
---@param slot ReagentSlot
function Self:ResetReagentSlot(form, slot)
    if slot:GetOriginalItem() then
        self:RestoreOriginalSlotItem(form, slot)
    elseif form.transaction:HasAnyAllocations(slot:GetReagentSlotSchematic().slotIndex) then
        self:ClearReagentSlot(form, slot)
    end
end

---@param form RecipeForm
---@param slot ReagentSlot
function Self:RestoreOriginalSlotItem(form, slot)
    if slot:IsOriginalItemSet() then return end

    local schematic = slot:GetReagentSlotSchematic()
    local modification = form.transaction:GetModification(schematic.dataSlotIndex)

    if modification and modification.itemID > 0 then
        local reagent = Professions.CreateCraftingReagentByItemID(modification.itemID)
        form.transaction:OverwriteAllocation(schematic.slotIndex, reagent, schematic.quantityRequired)
    end

    slot:RestoreOriginalItem()

    form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

---@param form RecipeForm
---@param slot ReagentSlot
function Self:ClearReagentSlot(form, slot)
    form.transaction:ClearAllocations(slot:GetReagentSlotSchematic().slotIndex)
    slot:ClearItem()
    form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

---------------------------------------
--              Tooltip
---------------------------------------

-- Reagent tooltip

TooltipDataProcessor.AddTooltipPostCall(
    Enum.TooltipDataType.Item,
    ---@param tooltip? GameTooltip
    function(tooltip)
        if not Addon.DB.tooltip or not tooltip then return end

        local _, link = tooltip:GetItem()
        if not link then return end

        local id = C_Item.GetItemIDForItemInfo(link)
        if not id then return end

        local reagentWeight = Addon.REAGENTS[id]
        local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(link)
        if not reagentWeight or not quality then return end

        local itemWeight = reagentWeight * (quality - 1)

        tooltip:AddDoubleLine("Craft weight", ("%d (%d)"):format(itemWeight, reagentWeight), nil, nil, nil, WHITE_FONT_COLOR.r, WHITE_FONT_COLOR.g, WHITE_FONT_COLOR.b)

        local form = Self:GetVisibleForm()
        if not form then return end

        local recipe = form.transaction:GetRecipeSchematic()
        local totalWeight = Optimization:GetMaxReagentWeight(recipe.reagentSlotSchematics)
        local _, maxSkill = Optimization:GetReagentSkillBounds(recipe)
        if not maxSkill or maxSkill == 0 then return end

        local skill = Util:NumRound(maxSkill * itemWeight / totalWeight, 1)

        tooltip:AddDoubleLine("Craft skill", skill, nil, nil, nil, WHITE_FONT_COLOR.r, WHITE_FONT_COLOR.g, WHITE_FONT_COLOR.b)
    end
)

---------------------------------------
--              Events
---------------------------------------

function Self:OnAddonLoaded(addonName)
    local isSelf = addonName == Name

    if isSelf then
        -- RecipeObjectiveTracker

        -- Hook update
        hooksecurefunc(recipeTracker, "AddRecipe", Self.Hooks.RecipeTracker.AddRecipe)
    end

    if addonName == "Blizzard_Professions" or isSelf and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
        -- Flyout

        flyout = OpenProfessionsItemFlyout()
        CloseProfessionsItemFlyout()

        -- ProfessionsFrame.CraftingPage

        craftingPage = ProfessionsFrame.CraftingPage
        craftingForm = craftingPage.SchematicForm

        -- Elements

        -- Insert experiment checkbox
        InsertExperimentBox(
            craftingForm,
            craftingForm,
            "LEFT", craftingForm.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
        )

        -- Insert tracked amount spinner
        InsertAmountSpinner(
            craftingForm,
            function ()
                local recipe = craftingForm:GetRecipeInfo()
                return recipe and recipe.recipeID
            end,
            "RIGHT", craftingForm.TrackRecipeCheckbox, "LEFT", -30, 1
        )

        -- Insert skill points spinner
        Self.skillSpinners[craftingForm] = InsertNumericSpinner(
            craftingForm.Details.StatLines.SkillStatLine,
            SkillSpinnerOnEnter,
            SkillSpinnerOnChange,
            "RIGHT", -50, 1
        )

        -- Insert optimization buttons
        InsertOptimizationButtons(craftingPage, craftingForm, "BOTTOMLEFT", craftingPage.RecipeList, "BOTTOMRIGHT", 2, 2)

        -- Hooks

        hooksecurefunc(craftingPage, "ValidateControls", Self.Hooks.CraftingPage.ValidateControls)

        hooksecurefunc(craftingForm, "Init", Self.Hooks.RecipeCraftingForm.Init)
        hooksecurefunc(craftingForm, "Refresh", Self.Hooks.RecipeCraftingForm.Refresh)
        hooksecurefunc(craftingForm, "UpdateDetailsStats", Self.Hooks.RecipeCraftingForm.UpdateDetailsStats)

        hooksecurefunc(craftingForm.Details, "SetStats", Self.Hooks.RecipeCraftingForm.DetailsSetStats)


        -- ProfessionsFrame.OrdersPage

        ordersView = ProfessionsFrame.OrdersPage.OrderView
        ordersForm = ordersView.OrderDetails.SchematicForm

        -- Elements

        -- Insert experiment checkbox
        InsertExperimentBox(
            ordersForm,
            ordersForm,
            "LEFT", ordersForm.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
        )

        -- Insert skill points spinner
        Self.skillSpinners[ordersForm] = InsertNumericSpinner(
            ordersForm.Details.StatLines.SkillStatLine,
            SkillSpinnerOnEnter,
            SkillSpinnerOnChange,
            "RIGHT", -50, 1
        )

        -- Insert optimization buttons
        InsertOptimizationButtons(
            ordersView,
            ordersForm,
            "TOPLEFT", ordersView.OrderDetails, "BOTTOMLEFT", 0, -4
        )

        -- Hooks

        hooksecurefunc(ordersView, "UpdateCreateButton", Self.Hooks.OrdersView.UpdateCreateButton)

        hooksecurefunc(ordersForm, "Init", Self.Hooks.RecipeCraftingForm.Init)
        hooksecurefunc(ordersForm, "Refresh", Self.Hooks.RecipeCraftingForm.Refresh)
        hooksecurefunc(ordersForm, "UpdateDetailsStats", Self.Hooks.RecipeCraftingForm.UpdateDetailsStats)

        hooksecurefunc(ordersForm.Details, "SetStats", Self.Hooks.RecipeCraftingForm.DetailsSetStats)
    end

    if addonName == "Blizzard_ProfessionsCustomerOrders" or isSelf and C_AddOns.IsAddOnLoaded("Blizzard_ProfessionsCustomerOrders") then
        -- ProfessionsCustomerOrdersFrame

        customerOrderForm = ProfessionsCustomerOrdersFrame.Form
        customerOrderReagents = customerOrderForm.ReagentContainer

        -- Elements

        -- Insert experiment checkbox
        InsertExperimentBox(
            customerOrderForm,
            customerOrderReagents,
            "LEFT", customerOrderForm.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
        )

        -- Insert tracked amount spinner
        InsertAmountSpinner(
            customerOrderForm,
            function () return customerOrderForm.order and customerOrderForm.order.spellID end,
            "LEFT", customerOrderForm.TrackRecipeCheckbox, "RIGHT", 30, 1
        )

        -- Hooks

        hooksecurefunc(customerOrderForm, "InitSchematic", Self.Hooks.CustomerOrderForm.InitSchematic)
        hooksecurefunc(customerOrderForm, "UpdateListOrderButton", Self.Hooks.CustomerOrderForm.UpdateListOrderButton)
    end
end

function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    local recipe = craftingForm and craftingForm:GetRecipeInfo()
    if recipe and recipe.recipeID == recipeID then
        local amountSpinner = Self.amountSpinners[craftingForm]
        amountSpinner:SetShown(tracked and not ProfessionsUtil.IsCraftingMinimized())
        if not tracked then amountSpinner:SetValue(1) end
    end

    if customerOrderForm and customerOrderForm.order and customerOrderForm.order.spellID == recipeID then
        local amountSpinner = Self.amountSpinners[customerOrderForm]
        amountSpinner:SetShown(tracked)
        if not tracked then amountSpinner:SetValue(1) end
    end
end

function Self:OnTradeSkillCraftBegin(recipeID)
    Self.craftingRecipeID = recipeID
end

function Self:OnUpdateTradeskillCastStopped()
    Self.craftingRecipeID = nil
end

function Self:OnSpellcastStoppedOrSucceeded()
    local recipeID = Self.craftingRecipeID
    Self.craftingRecipeID = nil

    if not recipeID or not Addon.DB.amounts[recipeID] then return end

    local amount = max(1, Addon.DB.amounts[recipeID] - 1)
    Addon.DB.amounts[recipeID] = amount > 1 and amount or nil

    local recipe = craftingForm:GetRecipeInfo()
    if recipe and recipe.recipeID == recipeID then
        Self.amountSpinners[craftingForm]:SetValue(amount)
    end

    if customerOrderForm and customerOrderForm.order and customerOrderForm.order.spellID == recipeID then
        Self.amountSpinners[customerOrderForm]:SetValue(amount)
    end
end

EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)
EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_CRAFT_BEGIN", Self.OnTradeSkillCraftBegin, Self)
EventRegistry:RegisterFrameEventAndCallback("UPDATE_TRADESKILL_CAST_STOPPED", Self.OnUpdateTradeskillCastStopped, Self)
EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_INTERRUPTED", Self.OnSpellcastStoppedOrSucceeded, Self)
EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_SUCCEEDED", Self.OnSpellcastStoppedOrSucceeded, Self)
