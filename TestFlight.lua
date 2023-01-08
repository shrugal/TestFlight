local Name = ...

local enabled = false
---@type table<table, table<string, function>>
local hooks = {}
---@type CheckButton[]
local experimentBoxes = {}
---@type NumericInputSpinner, number
local skillBox, extraSkill = nil, 0
---@type CheckButton
local inspirationBox, withInspiration = nil, false
---@type table<table, NumericInputSpinner>, table<integer, integer>
local amountBoxes, amounts = {}, nil
---@type integer
local craftingRecipeID

-- Blizzard frames
local craftingFrame = ProfessionsFrame.CraftingPage
local craftingForm = craftingFrame.SchematicForm
local orderForm, orderReagents
local recipeTracker = PROFESSION_RECIPE_TRACKER_MODULE

local QUALITY_BREAKPOINTS = {
    [3] = { 0, 0.5, 1 },
    [5] = { 0, 0.2, 0.5, 0.8, 1 }
}

local LINE_TYPE_ANIM = { template = "QuestObjectiveAnimLineTemplate", freeLines = {} };

---------------------------------------
--              Util
---------------------------------------

local function hook(obj, name, fn)
    if not obj or hooks[obj] and hooks[obj][name] then return end
    hooks[obj] = hooks[obj] or {}
    hooks[obj][name] = obj[name]
    obj[name] = fn
end

local function unhook(obj, name)
    if not obj or not hooks[obj] or not hooks[obj][name] then return end
    obj[name] = hooks[obj][name]
    hooks[obj][name] = nil
end

---@param op CraftingOperationInfo
local function hasInspiration(op)
    return op and op.bonusStats and op.bonusStats[1] and
        op.bonusStats[1].bonusStatName == PROFESSIONS_OUTPUT_INSPIRATION_TITLE
end

---------------------------------------
--             Overrides
---------------------------------------

local function FnInfinite() return math.huge end

local function FnFalse() return false end

local function SchematicFormGetRecipeOperationInfo(self)
    ---@type CraftingOperationInfo
    local op = hooks[craftingForm].GetRecipeOperationInfo(self)
    if not op then return end

    op.baseSkill, op.bonusSkill = op.baseSkill + op.bonusSkill, extraSkill

    if op.isQualityCraft then
        local skill, difficulty = op.baseSkill + op.bonusSkill, op.baseDifficulty + op.bonusDifficulty

        if withInspiration and hasInspiration(op) then
            local desc = op.bonusStats[1].ratingDescription
            local inspirationSkill = tonumber(desc:match("(%d+)[^.%d%%]") or desc:match("(%d+)%.?$")) or 0
            skill = skill + inspirationSkill
        end

        local p = skill / difficulty
        local rank = self.currentRecipeInfo.maxQuality
        local breakpoints = QUALITY_BREAKPOINTS[rank]

        for i, v in ipairs(breakpoints) do
            if v > p then rank = i - 1 break end
        end

        local lower, upper = breakpoints[rank], breakpoints[rank + 1] or 1
        local quality = rank + (upper == lower and 0 or (p - lower) / (upper - lower))

        op.quality = quality
        op.craftingQuality = rank
        op.lowerSkillThreshold = difficulty * lower
        op.upperSkillTreshold = difficulty * upper
    end

    return op
end

local function RecipeTrackerModuleUpdate(...)
    unhook(ItemUtil, "GetCraftingReagentCount")
    hooks[recipeTracker].Update(...)
    hook(ItemUtil, "GetCraftingReagentCount", FnInfinite)
end

---------------------------------------
--             Hooking
---------------------------------------

local function refresh()
    for _, checkbox in pairs(experimentBoxes) do
        checkbox:SetChecked(enabled)
    end

    -- ProfessionsFrame
    craftingForm:Refresh()
    craftingFrame:ValidateControls()

    -- ProfessionsCustomerOrdersFrame
    if orderForm and orderForm:IsVisible() then
        orderForm:InitSchematic()
        if enabled then
            orderForm.PaymentContainer.ListOrderButton:SetEnabled(false)
        end
    end

    -- ObjectiveTrackerFrame
    ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION_RECIPE)
end

local function enable()
    if enabled then return end
    enabled = true

    hook(ItemUtil, "GetCraftingReagentCount", FnInfinite)
    hook(Professions, "GetReagentSlotStatus", FnFalse)

    -- ProfessionsFrame
    hook(craftingForm, "GetRecipeOperationInfo", SchematicFormGetRecipeOperationInfo)

    -- ObjectiveTrackerFrame
    hook(recipeTracker, "Update", RecipeTrackerModuleUpdate)

    refresh()
end

local function disable()
    if not enabled then return end
    enabled = false

    extraSkill = 0
    withInspiration = false

    unhook(ItemUtil, "GetCraftingReagentCount")
    unhook(Professions, "GetReagentSlotStatus")

    -- ProfessionsFrame
    unhook(craftingForm, "GetRecipeOperationInfo")

    -- Clear reagents in locked slots
    for reagentType, slots in pairs(craftingForm.reagentSlots) do
        if reagentType ~= Enum.CraftingReagentType.Basic then
            for _, slot in pairs(slots) do
                local schematic = slot:GetReagentSlotSchematic()
                local locked = Professions.GetReagentSlotStatus(schematic, craftingForm.currentRecipeInfo)
                if locked and craftingForm.transaction:HasAllocations(schematic.slotIndex) then
                    craftingForm.transaction:ClearAllocations(schematic.slotIndex)
                    slot:ClearItem()
                    craftingForm:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
                end
            end
        end
    end

    -- ObjectiveTrackerFrame
    unhook(recipeTracker, "Update")

    refresh()
end

local function toggle()
    if enabled then disable() else enable() end
end

---------------------------------------
--               GUI
---------------------------------------

-- Spinner

---@param parent Frame
---@param onEnter? function
---@param onValueChanged? function
local function InsertNumericSpinner(parent, onEnter, onValueChanged, ...)
    local input = CreateFrame("EditBox", nil, parent, "NumericInputSpinnerTemplate") --[[@as NumericInputSpinner]]

    input:Hide()
    input:SetScript("OnEnter", onEnter)
    input:SetScript("OnLeave", GameTooltip_Hide)
    if onValueChanged then input:SetOnValueChangedCallback(onValueChanged) end

    if ... then input:SetPoint(...) end

    return input
end

-- Checkbox

---@param parent? Frame
---@param onEnter? function
---@param onClick? function
local function InsertCheckbox(parent, onEnter, onClick, ...)
    local input = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate") --[[@as CheckButton]]

    input:SetScript("OnEnter", onEnter);
    input:SetScript("OnLeave", GameTooltip_Hide);
    input:SetScript("OnClick", onClick)

    if ... then input:SetPoint(...) end

    return input
end

-- Experiment checkbox

---@param self CheckButton
local function ExperimentBoxOnClick(self)
    if self:GetChecked() ~= enabled then toggle() end
end

---@param self CheckButton
local function ExperimentBoxOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Experiment with crafting recipes without reagent and spec limits.")
    GameTooltip:Show()
end

---@param parent Frame
local function InsertExperimentBox(parent, ...)
    local input = InsertCheckbox(parent, ExperimentBoxOnEnter, ExperimentBoxOnClick, ...)

    input.text:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode("Experiment"))
    input:SetChecked(enabled)

    tinsert(experimentBoxes, input)
    return input
end

-- Amount spinner

local function AmountBoxOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Show result with extra crafting skill.")
    GameTooltip:Show()
end

-- ObjectiveTracker line

---@param self Button
local function TrackerLineOnClick(self, mouseButton)
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

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("TRACKED_RECIPE_UPDATE")
frame:RegisterEvent("TRADE_SKILL_CRAFT_BEGIN")
frame:RegisterEvent("UPDATE_TRADESKILL_CAST_COMPLETE")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == Name then
            TestFlightDB = TestFlightDB or { amounts = {} }
            amounts = TestFlightDB.amounts

            -- ProfessionsFrame

            -- Insert experiment checkbox
            InsertExperimentBox(
                craftingForm,
                "LEFT", craftingForm.AllocateBestQualityCheckBox.text, "RIGHT", 20, 0
            )

            -- Insert skill points spinner
            skillBox = InsertNumericSpinner(
                craftingForm.Details.StatLines.SkillStatLine,
                function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip_AddNormalLine(GameTooltip, "Show result with extra crafting skill.")
                    GameTooltip:Show()
                end,
                function(self, value)
                    extraSkill = max(0, value - (self.min or 0))
                    craftingFrame.SchematicForm:UpdateDetailsStats()
                end,
                "RIGHT"
            )

            -- Insert inspiration checkbox
            inspirationBox = InsertCheckbox(
                craftingForm.Details.StatLines.SkillStatLine,
                function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip_AddNormalLine(GameTooltip, "Show result with inspiration bonus.")
                    GameTooltip:Show()
                end,
                function(self)
                    if withInspiration == self:GetChecked() then return end
                    withInspiration = self:GetChecked()
                    refresh()
                end,
                "TOPLEFT", skillBox.DecrementButton, "BOTTOMLEFT", -3, 3
            )
            inspirationBox:SetScale(0.9)
            inspirationBox:Hide()

            -- Insert tracked amount spinner
            local amountBox = InsertNumericSpinner(
                craftingForm,
                AmountBoxOnEnter,
                function(self, value)
                    local recipe = craftingForm:GetRecipeInfo()
                    if not recipe then return end
                    amounts[recipe.recipeID] = value > 1 and value or nil
                    ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION_RECIPE)
                end,
                "RIGHT",
                craftingForm.TrackRecipeCheckBox,
                "LEFT",
                -30,
                1
            )
            amountBox:SetMinMaxValues(1, math.huge)
            amountBoxes[craftingForm] = amountBox

            -- Hook upddate stats
            hooksecurefunc(craftingForm, "UpdateDetailsStats", function(self)
                ---@type CraftingOperationInfo
                local op = (enabled and hooks[craftingForm] or self).GetRecipeOperationInfo(craftingForm)
                if not op or not op.isQualityCraft then return end

                local skill, difficulty = op.baseSkill + op.bonusSkill, op.baseDifficulty + op.bonusDifficulty
                skillBox:SetMinMaxValues(skill, max(skill, difficulty))
                skillBox:SetValue(skill + extraSkill)
            end)

            -- Hook form init
            hooksecurefunc(craftingForm, "Init", function(self, recipe)
                local trackBox = self.TrackRecipeCheckBox
                amountBox:SetShown(trackBox:IsShown() and trackBox:GetChecked())
                amountBox:SetValue(recipe and amounts[recipe.recipeID] or 1)
            end)

            -- Hook form refresh
            hooksecurefunc(craftingForm, "Refresh", function(self)
                craftingForm.Details.StatLines.SkillStatLine.RightLabel:SetShown(not enabled)
                skillBox:SetShown(enabled)
                inspirationBox:SetShown(enabled and hasInspiration(craftingForm.Details.operationInfo))
                inspirationBox:SetChecked(withInspiration)
            end)

            -- Hook validate controls
            hooksecurefunc(craftingFrame, "ValidateControls", function(self)
                if not enabled then return end
                self.CreateButton:SetEnabled(false)
                self.CreateAllButton:SetEnabled(false)
                self.CreateMultipleInputBox:SetEnabled(false)
                self:SetCreateButtonTooltipText("Experimentation mode is enabled.")
            end)

            -- RecipeObjectiveTracker

            -- Hook update
            hooksecurefunc(recipeTracker, "Update", function(self)
                for i = 0, 1 do
                    local isRecraft = i ~= 0
                    for _, recipeID in ipairs(C_TradeSkillUI.GetRecipesTracked(isRecraft)) do
                        local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)
                        local amount = amounts[recipe.recipeID]
                        local block = self:GetBlock(NegateIf(recipeID, isRecraft))

                        local blockName = recipe.name
                        if isRecraft then blockName = PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER:format(blockName) end
                        if (amount or 1) > 1 then blockName = ("%s (%d)"):format(blockName, amount) end
                        self:SetBlockHeader(block, blockName);

                        for j, schematic in ipairs(recipe.reagentSlotSchematics) do
                            if schematic.reagentType == Enum.CraftingReagentType.Basic then
                                local reagent = schematic.reagents[1]
                                local quantityRequired = schematic.quantityRequired * (amounts[recipe.recipeID] or 1)
                                local quantity = Professions.AccumulateReagentsInPossession(schematic.reagents)
                                local name = nil

                                if reagent.itemID then
                                    name = Item:CreateFromItemID(reagent.itemID):GetItemName();
                                elseif reagent.currencyID then
                                    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
                                    if currencyInfo then name = currencyInfo.name end
                                end

                                if name then
                                    local text = PROFESSIONS_TRACKER_REAGENT_FORMAT:format(
                                        PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT:format(quantity, quantityRequired),
                                        name
                                    )
                                    local metQuantity = quantity >= quantityRequired
                                    local dash = metQuantity and OBJECTIVE_DASH_STYLE_HIDE or OBJECTIVE_DASH_STYLE_SHOW
                                    local color = OBJECTIVE_TRACKER_COLOR[metQuantity and "Complete" or "Normal"]

                                    ---@type QuestObjectiveAnimLine
                                    local line = self:AddObjective(block, j, text, LINE_TYPE_ANIM, nil, dash, color)
                                    line.Check:SetShown(metQuantity)

                                    line.itemName = name

                                    if not line.Button then
                                        line.Button = CreateFrame("Button", nil, line)
                                        line.Button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                                        line.Button:SetAllPoints(line)
                                        line.Button:SetScript("OnClick", TrackerLineOnClick)
                                    end
                                end
                            end
                        end
                    end
                end
            end)

        elseif ... == "Blizzard_ProfessionsCustomerOrders" then
            -- ProfessionsCustomerOrdersFrame

            orderForm = ProfessionsCustomerOrdersFrame.Form
            orderReagents = orderForm.ReagentContainer

            -- Insert experiment checkbox
            InsertExperimentBox(orderReagents, "BOTTOMLEFT")

            -- Insert tracked amount spinner
            local amountBox = InsertNumericSpinner(
                orderForm,
                AmountBoxOnEnter,
                function(self, value)
                    if not orderForm.order then return end
                    local recipeID = orderForm.order.spellID
                    amounts[recipeID] = value > 1 and value or nil
                    ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION_RECIPE)
                end,
                "LEFT", orderForm.TrackRecipeCheckBox, "RIGHT", 30, 1
            )
            amountBox:SetMinMaxValues(1, math.huge)
            amountBoxes[orderForm] = amountBox

            -- Hook init schematic
            hooksecurefunc(orderForm, "InitSchematic", function(self)
                local recipeID = self.order.spellID
                local trackBox = self.TrackRecipeCheckBox.Checkbox
                amountBox:SetShown(trackBox:IsShown() and trackBox:GetChecked())
                amountBox:SetValue(recipeID and amounts[recipeID] or 1)
            end)

            -- Hook update list button
            hooksecurefunc(orderForm, "UpdateListOrderButton", function(self)
                if not enabled then return end
                if self.committed then return end

                local listOrderButton = self.PaymentContainer.ListOrderButton;

                listOrderButton:SetEnabled(false);
                listOrderButton:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(listOrderButton, "ANCHOR_RIGHT");
                    GameTooltip_AddErrorLine(GameTooltip, "Experimentation mode is enabled.");
                    GameTooltip:Show();
                end)
            end)
        end
    elseif event == "TRACKED_RECIPE_UPDATE" then
        local recipeID, tracked = ...;

        local recipe = craftingForm:GetRecipeInfo()
        if recipe and recipe.recipeID == recipeID then
            local amountBox = amountBoxes[craftingForm]
            amountBox:SetShown(tracked)
            if not tracked then amountBox:SetValue(1) end
        end

        if orderForm and orderForm.order and orderForm.order.spellID == recipeID then
            local amountBox = amountBoxes[orderForm]
            amountBox:SetShown(tracked)
            if not tracked then amountBox:SetValue(1) end
        end
    elseif event == "TRADE_SKILL_CRAFT_BEGIN" then
        craftingRecipeID = ...
    elseif event == "UPDATE_TRADESKILL_CAST_COMPLETE" then
        if not craftingRecipeID or not amounts[craftingRecipeID] then return end

        local amount = max(1, amounts[craftingRecipeID] - 1)
        amounts[craftingRecipeID] = amount > 1 and amount or nil

        local recipe = craftingForm:GetRecipeInfo()
        if recipe and recipe.recipeID == craftingRecipeID then
            amountBoxes[craftingForm]:SetValue(amount)
        end

        if orderForm and orderForm.order and orderForm.order.spellID == craftingRecipeID then
            amountBoxes[orderForm]:SetValue(amount)
        end
    end
end)

---------------------------------------
--               Types
---------------------------------------

---@class CheckButton
---@field text FontString

---@class NumericInputSpinner: EditBox
---@field min number
---@field max number
---@field IncrementButton Button
---@field DecrementButton Button
---@field SetMinMaxValues fun(self: self, min: number, max: number)
---@field SetValue fun(self: self, value: number)
---@field SetOnValueChangedCallback fun(self: self, callback: fun(self: self, value: number))

---@class QuestObjectiveAnimLine: Frame
---@field itemName string
---@field Button Button
---@field Text FontString
---@field Check Texture
