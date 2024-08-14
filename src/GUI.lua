---@type string
local Name = ...
---@class TestFlight
local Addon = select(2, ...)
local Optimization, Util = Addon.Optimization, Addon.Util

---@class GUI
local Self = {}
Addon.GUI = Self

Self.Hooks = {}

---@type CheckButton[]
Self.experimentBoxes = {}
---@type NumericInputSpinner
Self.skillSpinner = nil
---@type table<table, NumericInputSpinner>, table<integer, integer>
Self.amountSpinners, Self.amounts = {}, nil
---@type integer?
Self.craftingRecipeID = nil
---@type string?, string?
Self.recraftRecipeID, Self.recraftItemLink = nil, nil
---@type OptimizationFormButton, OptimizationFormButton, OptimizationFormButton
Self.btnDecrease, Self.btnOptimize, Self.btnIncrease = nil, nil, nil

-- Blizzard frames

---@type CraftingFrame, CraftingForm, Flyout
local craftingFrame, craftingForm, flyout
---@type OrderForm, OrdersFormReagents
local orderForm, orderReagents
local recipeTracker = ProfessionsRecipeTracker

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

---------------------------------------
--             Lifecycle
---------------------------------------

function Self:OnEnable()
    Util:TblHook(ItemUtil, "GetCraftingReagentCount", Util.FnInfinite)
    Util:TblHook(Professions, "GetReagentSlotStatus", Util.FnFalse)
    Util:TblHook(ProfessionsUtil, "GetReagentQuantityInPossession", Util.FnInfinite)
    Util:TblHook(flyout, "InitializeContents", Self.Hooks.Flyout.InitializeContents)

    -- ProfessionsFrame
    Util:TblHook(craftingForm, "GetRecipeOperationInfo", Self.Hooks.CraftingForm.GetRecipeOperationInfo)

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

    -- Clear reagents in locked slots
    self:ClearExperimentalReagentSlots(craftingForm)
    self:ClearExperimentalReagentSlots(orderForm)

    -- ObjectiveTrackerFrame
    Util:TblUnhook(recipeTracker, "Update")

    Self:Refresh()
end

function Self:Refresh()
    for _, checkbox in pairs(Self.experimentBoxes) do
        checkbox:SetChecked(Addon.enabled)
    end

    -- ProfessionsFrame
    craftingForm:Refresh()
    craftingFrame:ValidateControls()

    -- ProfessionsCustomerOrdersFrame
    if orderForm and orderForm:IsVisible() then
        orderForm:InitSchematic()
        if Addon.enabled then
            orderForm.PaymentContainer.ListOrderButton:SetEnabled(false)
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

---@param form ProfessionForm
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

    craftingForm:UpdateDetailsStats()
    craftingForm:UpdateRecraftSlot()
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
        Self.amounts[recipeID] = value > 1 and value or nil
        ObjectiveTrackerFrame:Update()
    end
end

---@param form ProfessionForm
---@param GetRecipeID fun(): number?
---@return NumericInputSpinner
local function InsertAmountSpinner(form, GetRecipeID, ...)
    local input = InsertNumericSpinner(form, AmountSpinnerOnEnter, AmountSpinnerOnChange(GetRecipeID), ...)

    input:SetMinMaxValues(1, math.huge)

    Self.amountSpinners[form] = input

    return input
end

-- Optimization buttons

---@param self OptimizationFormButton
local function DecreaseQualityButtonOnClick(self)
    Self:ChangeCraftingFormQualityBy(craftingForm, -1)
end

---@param self OptimizationFormButton
local function OptimizeQualityButtonOnClick(self)
    Self:SetCraftingFormQuality(craftingForm)
end

---@param self OptimizationFormButton
local function IncreaseQualityButtonOnClick(self)
    Self:ChangeCraftingFormQualityBy(craftingForm, 1)

end

---@param parent Frame
---@param form CraftingForm
local function InsertOptimizationButtons(parent, form, ...)
    if not Optimization:IsItemPriceSourceInstalled() then return end

    local btnDecrease = InsertButton("<",   	 parent, nil, DecreaseQualityButtonOnClick, ...) --[[@as OptimizationFormButton]]
    local btnOptimize = InsertButton("Optimize", parent, nil, OptimizeQualityButtonOnClick, "LEFT", btnDecrease, "RIGHT", 30) --[[@as OptimizationFormButton]]
    local btnIncrease = InsertButton(">",        parent, nil, IncreaseQualityButtonOnClick, "LEFT", btnOptimize, "RIGHT", 30) --[[@as OptimizationFormButton]]

    btnDecrease.form = form
    btnOptimize.form = form
    btnIncrease.form = form

    btnDecrease.tooltipText = "Decrease quality"
    btnOptimize.tooltipText = "Optimize for current quality"
    btnIncrease.tooltipText = "Increase quality"

    Self.btnDecrease = btnDecrease
    Self.btnOptimize = btnOptimize
    Self.btnIncrease = btnIncrease
end

---@param form CraftingForm
local function UpdateOptimizationButtons(form)
    if not Optimization:IsItemPriceSourceInstalled() then return end

    local btnDecrease, btnOptimize, btnIncrease = Self.btnDecrease, Self.btnOptimize, Self.btnIncrease
    local canDecrease, canIncrease = Optimization:CanChangeCraftQuality(form.recipeSchematic, form.transaction:CreateOptionalOrFinishingCraftingReagentInfoTbl())

    btnDecrease:SetEnabled(canDecrease)
    btnIncrease:SetEnabled(canIncrease)
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

-- CraftingFrame

Self.Hooks.CraftingFrame = {}

function Self.Hooks.CraftingFrame.ValidateControls(self)
    if not Addon.enabled then return end
    self.CreateButton:SetEnabled(false)
    self.CreateAllButton:SetEnabled(false)
    self.CreateMultipleInputBox:SetEnabled(false)
    self:SetCreateButtonTooltipText("Experimentation mode is enabled.")
end

-- CraftingForm

Self.Hooks.CraftingForm = {}

Self.Hooks.CraftingForm.GetRecipeOperationInfo = function(self)
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

function Self.Hooks.CraftingForm.Init(self, recipe)
    if not Addon.CreateAllocations then
        local AllocationsMixin = Util:TblCreateMixin(craftingForm.transaction:GetAllocations(1))
        function Addon:CreateAllocations() return CreateAndInitFromMixin(AllocationsMixin) end
    end

    local trackBox, amountSpinner = self.TrackRecipeCheckbox, Self.amountSpinners[self]
    amountSpinner:SetShown(trackBox:IsShown() and trackBox:GetChecked())
    amountSpinner:SetValue(recipe and Self.amounts[recipe.recipeID] or 1)

    self.OutputIcon:SetScript("OnEnter", Self.Hooks.CraftingForm.CraftOutputSlotOnEnter)
    self.recraftSlot.InputSlot:SetScript("OnEnter", Self.Hooks.CraftingForm.RecraftInputSlotOnEnter)
    self.recraftSlot.OutputSlot:SetScript("OnEnter", Self.Hooks.CraftingForm.RecraftOutputSlotOnEnter)
    self.recraftSlot.OutputSlot:SetScript("OnClick", Self.Hooks.CraftingForm.RecraftOutputSlotOnClick)

    if Self.recraftRecipeID then
        local same = Self.recraftRecipeID == recipe.recipeID
        Self:SetRecraftRecipe(same and Self.recraftRecipeID or nil, same and Self.recraftItemLink or nil)
    end
end

function Self.Hooks.CraftingForm.Refresh(self)
    local minimized = ProfessionsUtil.IsCraftingMinimized()

    Self.skillSpinner:SetShown(Addon.enabled and not minimized)

    Self.experimentBoxes[self]:SetShown(not minimized)

    local trackBox, amountSpinner = self.TrackRecipeCheckbox, Self.amountSpinners[self]
    amountSpinner:SetShown(trackBox:IsShown() and trackBox:GetChecked())

    if Self.btnDecrease then
        Self.btnDecrease:SetShown(not minimized)
        Self.btnOptimize:SetShown(not minimized)
        Self.btnIncrease:SetShown(not minimized)
    end
end

function Self.Hooks.CraftingForm.UpdateDetailsStats(self)
    local op = self:GetRecipeOperationInfo()
    if not op or not op.isQualityCraft then return end

    local skillNoExtra = op.baseSkill + op.bonusSkill - Addon.extraSkill
    local difficulty = op.baseDifficulty + op.bonusDifficulty

    Self.skillSpinner:SetMinMaxValues(0, difficulty - skillNoExtra)
    Self.skillSpinner:SetValue(Addon.extraSkill)

    UpdateOptimizationButtons(craftingForm)
end

function Self.Hooks.CraftingForm.DetailsSetStats(self, operationInfo, supportsQualities, isGatheringRecipe)
    if not Optimization:IsItemPriceSourceInstalled() then return end

    local label = COSTS_LABEL:gsub(":", "")

    local recipe = craftingForm.recipeSchematic
    local allocation = craftingForm.transaction.allocationTbls
    local optionalReagents = craftingForm.transaction:CreateOptionalOrFinishingCraftingReagentInfoTbl()
    local allocationPrice = Optimization:GetRecipeAllocationPrice(recipe, allocation, true)
    local allocationPriceStr = C_CurrencyInfo.GetCoinTextureString(allocationPrice)

    local function applyExtra()
        if self.recipeInfo == nil or ProfessionsUtil.IsCraftingMinimized() then return end

        local statLine = self.statLinePool:Acquire()
        statLine.layoutIndex = math.huge
        statLine:SetLabel(label)
        statLine.RightLabel:SetText(allocationPriceStr)

        statLine:SetScript("OnEnter", function(line)
            GameTooltip:SetOwner(line, "ANCHOR_RIGHT")

            GameTooltip_AddColoredDoubleLine(GameTooltip, label, allocationPriceStr, HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)

            if supportsQualities then
                GameTooltip_AddNormalLine(GameTooltip, "Based on reagent market prices, and without taking resourcefulness into account.")

                local allocations = Optimization:GetRecipeAllocations(recipe, optionalReagents)

                GameTooltip_AddBlankLineToTooltip(GameTooltip)
                GameTooltip_AddNormalLine(GameTooltip, "Optimal costs:")

                for i=1,5 do
                    local qualityAllocation = allocations[i]
                    if qualityAllocation then
                        local qualityLabel = CreateAtlasMarkup(Professions.GetIconForQuality(i), 20, 20)
                        local qualityPrice = Optimization:GetRecipeAllocationPrice(recipe, qualityAllocation, false, true, allocation)
                        local qualityPriceStr = C_CurrencyInfo.GetCoinTextureString(qualityPrice)
                        GameTooltip_AddHighlightLine(GameTooltip, qualityLabel .. " " .. qualityPriceStr)
                    end
                end
            else
                GameTooltip_AddNormalLine(GameTooltip, "Click to optimize cost.")
            end

            GameTooltip:Show()
        end)

        statLine:Show()

        self.StatLines:Layout()
        self:Layout()
    end

    local origApplyLayout = self.ApplyLayout
    self.ApplyLayout = function() origApplyLayout() applyExtra() end

    applyExtra()
end

function Self.Hooks.CraftingForm.CraftOutputSlotOnEnter(self)
    local form = craftingForm

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local reagents = form.transaction:CreateCraftingReagentInfoTbl()

    self:SetScript("OnUpdate", function()
        GameTooltip:SetRecipeResultItem(
            form.recipeSchematic.recipeID,
            reagents,
            form.transaction:GetAllocationItemGUID(),
            form:GetCurrentRecipeLevel(),
            form:GetRecipeOperationInfo().craftingQualityID
        )
    end)
end

function Self.Hooks.CraftingForm.RecraftInputSlotOnEnter(self)
    local form = craftingForm

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

function Self.Hooks.CraftingForm.RecraftOutputSlotOnEnter(self)
    local form = craftingForm

    local itemGUID = form.transaction:GetRecraftAllocation()
    local reagents = form.transaction:CreateCraftingReagentInfoTbl()

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    GameTooltip:SetRecipeResultItem(
        form.recipeSchematic.recipeID,
        reagents,
        itemGUID,
        form:GetCurrentRecipeLevel(),
        form:GetRecipeOperationInfo().craftingQualityID
    )
end

function Self.Hooks.CraftingForm.RecraftOutputSlotOnClick(self)
    local form = craftingForm

    local itemGUID = form.transaction:GetRecraftAllocation()
    local reagents = form.transaction:CreateCraftingReagentInfoTbl()

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    local outputItemInfo = C_TradeSkillUI.GetRecipeOutputItemData(
        form.recipeSchematic.recipeID,
        reagents,
        itemGUID,
        form:GetRecipeOperationInfo().craftingQualityID
    )

    if outputItemInfo and outputItemInfo.hyperlink then
        HandleModifiedItemClick(outputItemInfo.hyperlink)
    end
end

-- OrderForm

Self.Hooks.OrderForm = {}

function Self.Hooks.OrderForm.InitSchematic(self)
    local recipeID = self.order.spellID
    local trackBox = self.TrackRecipeCheckbox.Checkbox
    local amountSpinner = Self.amountSpinners[orderForm]

    amountSpinner:SetShown(trackBox:IsShown() and trackBox:GetChecked())
    amountSpinner:SetValue(recipeID and Self.amounts[recipeID] or 1)
end

function Self.Hooks.OrderForm.UpdateListOrderButton(self)
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
    local amount = Self.amounts[recipe.recipeID]

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
        local quantityRequired = schematic.quantityRequired * (Self.amounts[recipe.recipeID] or 1)
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

---@param form CraftingForm
---@param quality? number
---@param exact? boolean
function Self:SetCraftingFormQuality(form, quality, exact)
    if not quality then quality = math.floor(craftingForm:GetRecipeOperationInfo().quality) end

    local recipe = form.recipeSchematic
    local allocations = Optimization:GetRecipeAllocations(recipe, craftingForm.transaction:CreateOptionalOrFinishingCraftingReagentInfoTbl())
    local qualityAllocation = allocations[quality] or not exact and allocations[quality + 1]

    if not qualityAllocation then return end

    Self:SetReagentAllocation(craftingForm, qualityAllocation)
end


---@param form CraftingForm
---@param by number
function Self:ChangeCraftingFormQualityBy(form, by)
    local quality = math.floor(craftingForm:GetRecipeOperationInfo().quality)
    Self:SetCraftingFormQuality(form, quality + by, true)
end

---@param form ProfessionForm
---@param allocation RecipeAllocation
function Self:SetReagentAllocation(form, allocation)

    for slotIndex,allocations in pairs(allocation) do
        self:SetReagentSlotAllocation(form, slotIndex, allocations, true)
    end

    for slot in form.reagentSlotPool:EnumerateActive() do slot:Update() end

    form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

---@param form ProfessionForm
---@param slotIndex number
---@param allocations ProfessionTransationAllocations
function Self:SetReagentSlotAllocation(form, slotIndex, allocations, silent)
    if not Addon.enabled then
        for _,reagent in allocations:Enumerate() do
            if reagent.quantity > Optimization:GetReagentQuantity(reagent) then Addon:Enable() break end
        end
    end

    form.transaction:OverwriteAllocations(slotIndex, allocations)
    form.transaction:SetManuallyAllocated(true)

    if silent then return end

    for slot in form.reagentSlotPool:EnumerateActive() do
        if slot:GetSlotIndex() == slotIndex then slot:Update() break end
    end

    form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

---@param form ProfessionForm
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

---@param form ProfessionForm
---@param slot ReagentSlot
function Self:ResetReagentSlot(form, slot)
    if slot:GetOriginalItem() then
        self:RestoreOriginalSlotItem(form, slot)
    elseif form.transaction:HasAnyAllocations(slot:GetReagentSlotSchematic().slotIndex) then
        self:ClearReagentSlot(form, slot)
    end
end

---@param form ProfessionForm
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

---@param form ProfessionForm
---@param slot ReagentSlot
function Self:ClearReagentSlot(form, slot)
    form.transaction:ClearAllocations(slot:GetReagentSlotSchematic().slotIndex)
    slot:ClearItem()
    form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnAddonLoaded(addonName)
    local isSelf = addonName == Name

    if isSelf then
        -- TestFlight

        TestFlightDB = TestFlightDB or { amounts = {} }
        Self.amounts = TestFlightDB.amounts

        -- RecipeObjectiveTracker

        -- Hook update
        hooksecurefunc(recipeTracker, "AddRecipe", Self.Hooks.RecipeTracker.AddRecipe)
    end

    if addonName == "Blizzard_Professions" or isSelf and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
        -- ProfessionsFrame

        craftingFrame = ProfessionsFrame.CraftingPage
        craftingForm = craftingFrame.SchematicForm

        flyout = OpenProfessionsItemFlyout()
        CloseProfessionsItemFlyout()

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
        Self.skillSpinner = InsertNumericSpinner(
            craftingForm.Details.StatLines.SkillStatLine,
            SkillSpinnerOnEnter,
            SkillSpinnerOnChange,
            "RIGHT", -50, 1
        )

        -- Insert optimization buttons
        InsertOptimizationButtons(craftingFrame, craftingForm, "BOTTOMLEFT", craftingFrame.RecipeList, "BOTTOMRIGHT", 2, 2)

        -- Hooks

        hooksecurefunc(craftingFrame, "ValidateControls", Self.Hooks.CraftingFrame.ValidateControls)

        hooksecurefunc(craftingForm, "Init", Self.Hooks.CraftingForm.Init)
        hooksecurefunc(craftingForm, "Refresh", Self.Hooks.CraftingForm.Refresh)
        hooksecurefunc(craftingForm, "UpdateDetailsStats", Self.Hooks.CraftingForm.UpdateDetailsStats)

        hooksecurefunc(craftingForm.Details, "SetStats", Self.Hooks.CraftingForm.DetailsSetStats)
    end

    if addonName == "Blizzard_ProfessionsCustomerOrders" or isSelf and C_AddOns.IsAddOnLoaded("Blizzard_ProfessionsCustomerOrders") then
        -- ProfessionsCustomerOrdersFrame

        orderForm = ProfessionsCustomerOrdersFrame.Form
        orderReagents = orderForm.ReagentContainer

        -- Elements

        -- Insert experiment checkbox
        InsertExperimentBox(
            orderForm,
            orderReagents,
            "LEFT", orderForm.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
        )

        -- Insert tracked amount spinner
        InsertAmountSpinner(
            orderForm,
            function () return orderForm.order and orderForm.order.spellID end,
            "LEFT", orderForm.TrackRecipeCheckbox, "RIGHT", 30, 1
        )

        -- Hooks

        hooksecurefunc(orderForm, "InitSchematic", Self.Hooks.OrderForm.InitSchematic)
        hooksecurefunc(orderForm, "UpdateListOrderButton", Self.Hooks.OrderForm.UpdateListOrderButton)
    end
end

function Self:OnTrackedRecipeUpdate(recipeID, tracked)
    local recipe = craftingForm and craftingForm:GetRecipeInfo()
    if recipe and recipe.recipeID == recipeID then
        local amountSpinner = Self.amountSpinners[craftingForm]
        amountSpinner:SetShown(tracked and not ProfessionsUtil.IsCraftingMinimized())
        if not tracked then amountSpinner:SetValue(1) end
    end

    if orderForm and orderForm.order and orderForm.order.spellID == recipeID then
        local amountSpinner = Self.amountSpinners[orderForm]
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

    if not recipeID or not Self.amounts[recipeID] then return end

    local amount = max(1, Self.amounts[recipeID] - 1)
    Self.amounts[recipeID] = amount > 1 and amount or nil

    local recipe = craftingForm:GetRecipeInfo()
    if recipe and recipe.recipeID == recipeID then
        Self.amountSpinners[craftingForm]:SetValue(amount)
    end

    if orderForm and orderForm.order and orderForm.order.spellID == recipeID then
        Self.amountSpinners[orderForm]:SetValue(amount)
    end
end

EventRegistry:RegisterFrameEventAndCallback("ADDON_LOADED", Self.OnAddonLoaded, Self)
EventRegistry:RegisterFrameEventAndCallback("TRACKED_RECIPE_UPDATE", Self.OnTrackedRecipeUpdate, Self)
EventRegistry:RegisterFrameEventAndCallback("TRADE_SKILL_CRAFT_BEGIN", Self.OnTradeSkillCraftBegin, Self)
EventRegistry:RegisterFrameEventAndCallback("UPDATE_TRADESKILL_CAST_STOPPED", Self.OnUpdateTradeskillCastStopped, Self)
EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_INTERRUPTED", Self.OnSpellcastStoppedOrSucceeded, Self)
EventRegistry:RegisterFrameEventAndCallback("UNIT_SPELLCAST_SUCCEEDED", Self.OnSpellcastStoppedOrSucceeded, Self)
