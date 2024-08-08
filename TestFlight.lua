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
---@type integer?
local craftingRecipeID

-- Blizzard frames
local craftingFrame, craftingForm, flyout
local orderForm, orderReagents
local recipeTracker = ProfessionsRecipeTracker

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
    return hooks[obj][name]
end

local function unhook(obj, name)
    if not obj or not hooks[obj] or not hooks[obj][name] then return end
    local fn = obj[name]
    obj[name] = hooks[obj][name]
    hooks[obj][name] = nil
    return fn
end

---@param op CraftingOperationInfo
local function hasInspiration(op)
    return op and op.bonusStats and op.bonusStats[1] and
        op.bonusStats[1].bonusStatName == PROFESSIONS_OUTPUT_INSPIRATION_TITLE
end

local function ClearOptionalSlots(form)
    if not form or not form.reagentSlots then return end

    for reagentType, slots in pairs(form.reagentSlots) do
        if reagentType ~= Enum.CraftingReagentType.Basic then
            for _, slot in pairs(slots) do
                local schematic = slot:GetReagentSlotSchematic()
                if form.transaction:HasAnyAllocations(schematic.slotIndex) then
                    form.transaction:ClearAllocations(schematic.slotIndex)
                    slot:ClearItem()
                    form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
                end
            end
        end
    end
end

---------------------------------------
--             Overrides
---------------------------------------

local function FnInfinite() return math.huge end

local function FnFalse() return false end

local function FnTrue() return true end

local function FnNoop() end

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
            if v > p then
                rank = i - 1
                break
            end
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
    local fn1 = unhook(Professions, "GetReagentQuantityInPossession")
    local fn2 = unhook(ItemUtil, "GetCraftingReagentCount")

    hooks[recipeTracker].Update(...)

    hook(Professions, "GetReagentQuantityInPossession", fn1)
    hook(ItemUtil, "GetCraftingReagentCount", fn2)
end

local function FlyoutInitializeContents(...)
    flyout.OnElementEnabledImplementation = flyout.GetElementValidImplementation or FnTrue
    hooks[flyout].InitializeContents(...)
end

---------------------------------------
--             Recraft
---------------------------------------

local function SetRecraftSlotLink(link)
    local recraftSlot = craftingForm.recraftSlot

    recraftSlot.InputSlot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(recraftSlot.InputSlot, "ANCHOR_RIGHT")

        GameTooltip:SetHyperlink(link)
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddInstructionLine(GameTooltip, RECRAFT_REAGENT_TOOLTIP_CLICK_TO_REPLACE)
        GameTooltip:Show()
    end);

    recraftSlot.OutputSlot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(recraftSlot.OutputSlot, "ANCHOR_RIGHT")

        GameTooltip:SetRecipeResultItem(
            craftingForm.recipeSchematic.recipeID,
            craftingForm.transaction:CreateCraftingReagentInfoTbl(),
            craftingForm.transaction:GetRecraftAllocation(),
            craftingForm:GetCurrentRecipeLevel(),
            craftingForm:GetOutputOverrideQuality()
        )
    end);

    recraftSlot.OutputSlot:SetScript("OnClick", function()
        GameTooltip:SetOwner(recraftSlot.OutputSlot, "ANCHOR_RIGHT")

        local outputItemInfo = C_TradeSkillUI.GetRecipeOutputItemData(
            craftingForm.recipeSchematic.recipeID,
            craftingForm.transaction:CreateCraftingReagentInfoTbl(),
            craftingForm.transaction:GetRecraftAllocation()
        )

        if outputItemInfo and outputItemInfo.hyperlink then
            HandleModifiedItemClick(outputItemInfo.hyperlink)
        end
    end);

    recraftSlot:Init(nil, FnTrue, FnNoop, link)
end

local function SetRecraftRecipe(recipeId)
    local link = C_TradeSkillUI.GetRecipeItemLink(recipeId) --[[@as string]]
    if not link then return end

    Professions.SetRecraftingTransitionData({ isRecraft = true, itemLink = link })
    C_TradeSkillUI.OpenRecipe(recipeId)

    SetRecraftSlotLink(link)
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

    -- Set recraft slot again
    local data = Professions.GetRecraftingTransitionData()
    if data and data.isRecraft and not data.itemGUID and data.itemLink then
        SetRecraftSlotLink(data.itemLink)
    end

    -- ProfessionsCustomerOrdersFrame
    if orderForm and orderForm:IsVisible() then
        orderForm:InitSchematic()
        if enabled then
            orderForm.PaymentContainer.ListOrderButton:SetEnabled(false)
        end
    end

    -- ObjectiveTrackerFrame
    ObjectiveTrackerFrame:Update()
end

local function enable()
    if enabled then return end
    enabled = true

    hook(ItemUtil, "GetCraftingReagentCount", FnInfinite)
    hook(Professions, "GetReagentSlotStatus", FnFalse)
    hook(Professions, "GetReagentQuantityInPossession", FnInfinite)
    hook(flyout, "InitializeContents", FlyoutInitializeContents)

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
    unhook(Professions, "GetReagentQuantityInPossession")
    unhook(flyout, "InitializeContents")

    -- ProfessionsFrame
    unhook(craftingForm, "GetRecipeOperationInfo")

    -- Clear reagents in locked slots
    ClearOptionalSlots(craftingForm)
    ClearOptionalSlots(orderForm)

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
frame:RegisterEvent("UPDATE_TRADESKILL_CAST_STOPPED")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local isSelf = ... == Name

        if isSelf then
            -- TestFlight

            TestFlightDB = TestFlightDB or { amounts = {} }
            amounts = TestFlightDB.amounts

            -- RecipeObjectiveTracker

            -- Hook update
            hooksecurefunc(recipeTracker, "AddRecipe", function(self, recipeID, isRecraft)
                local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)
                local amount = amounts[recipe.recipeID]

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
                    local quantityRequired = schematic.quantityRequired * (amounts[recipe.recipeID] or 1)
                    local quantity = ProfessionsUtil.AccumulateReagentsInPossession(schematic.reagents)
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

                        ---@type QuestObjectiveAnimLine
                        local line = block:GetExistingLine(j)
                        local oldHeight = line:GetHeight()
                        line.Text:SetHeight(0)
                        line.Text:SetText(text)
                        local newHeight = line.Text:GetHeight()
                        line:SetHeight(newHeight)
                        block.height = block.height - oldHeight + newHeight

                        line.itemName = name

                        if not line.Button then
                            line.Button = CreateFrame("Button", nil, line)
                            line.Button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                            line.Button:SetAllPoints(line)
                            line.Button:SetScript("OnClick", TrackerLineOnClick)
                        end
                    end
                end
            end)
        end

        if ... == "Blizzard_Professions" or isSelf and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
            -- ProfessionsFrame

            craftingFrame = ProfessionsFrame.CraftingPage
            craftingForm = craftingFrame.SchematicForm

            flyout = OpenProfessionsItemFlyout()
            CloseProfessionsItemFlyout()

            -- Insert experiment checkbox
            InsertExperimentBox(
                craftingForm,
                "LEFT", craftingForm.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
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
                    ObjectiveTrackerFrame:Update()
                end,
                "RIGHT",
                craftingForm.TrackRecipeCheckbox,
                "LEFT",
                -30,
                1
            )
            amountBox:SetMinMaxValues(1, math.huge)
            amountBoxes[craftingForm] = amountBox

            -- Hook update stats
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
                local trackBox = self.TrackRecipeCheckbox
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
        end

        if ... == "Blizzard_ProfessionsCustomerOrders" or isSelf and C_AddOns.IsAddOnLoaded("Blizzard_ProfessionsCustomerOrders") then
            -- ProfessionsCustomerOrdersFrame

            orderForm = ProfessionsCustomerOrdersFrame.Form
            orderReagents = orderForm.ReagentContainer

            -- Insert experiment checkbox
            InsertExperimentBox(
                orderReagents,
                "LEFT", orderForm.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
            )

            -- Insert tracked amount spinner
            local amountBox = InsertNumericSpinner(
                orderForm,
                AmountBoxOnEnter,
                function(self, value)
                    if not orderForm.order then return end
                    local recipeID = orderForm.order.spellID
                    amounts[recipeID] = value > 1 and value or nil
                    ObjectiveTrackerFrame:Update()
                end,
                "LEFT", orderForm.TrackRecipeCheckbox, "RIGHT", 30, 1
            )
            amountBox:SetMinMaxValues(1, math.huge)
            amountBoxes[orderForm] = amountBox

            -- Hook init schematic
            hooksecurefunc(orderForm, "InitSchematic", function(self)
                local recipeID = self.order.spellID
                local trackBox = self.TrackRecipeCheckbox.Checkbox
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

        local recipe = craftingForm and craftingForm:GetRecipeInfo()
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
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        craftingRecipeID = nil
    elseif event == "UPDATE_TRADESKILL_CAST_STOPPED" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        local recipeID = craftingRecipeID
        craftingRecipeID = nil

        if not recipeID or not amounts[recipeID] then return end

        local amount = max(1, amounts[recipeID] - 1)
        amounts[recipeID] = amount > 1 and amount or nil

        local recipe = craftingForm:GetRecipeInfo()
        if recipe and recipe.recipeID == recipeID then
            amountBoxes[craftingForm]:SetValue(amount)
        end

        if orderForm and orderForm.order and orderForm.order.spellID == recipeID then
            amountBoxes[orderForm]:SetValue(amount)
        end
    end
end)

---------------------------------------
--              Commands
---------------------------------------

SLASH_TESTFLIGHT1 = "/testflight"
SLASH_TESTFLIGHT2 = "/tf"

local function ParseArgs(input)
    input = " " .. input

    local args = {}
    local link = 0

    for s in input:gmatch("[| ]+[^| ]+") do
        if link == 0 and s:sub(1, 1) == " " then
            s = s:gsub("^ +", "")
            tinsert(args, s)
        else
            args[#args] = args[#args] .. s
        end

        if s:sub(1, 2) == "|H" then link = 1 end
        if s:sub(1, 2) == "|h" then link = (link + 1) % 3 end
    end

    return args
end

---@param link string
local function GetItemId(link) return link and tonumber(link:match("|Hitem:(%d+)")) end

local function Print(msg) print("|cff00bbbb[TestFlight]|r " .. msg) end

---@param input string
function SlashCmdList.TESTFLIGHT(input)
    local args = ParseArgs(input)
    local cmd = args[1]

    if cmd == "recraft" or cmd == "rc" then
        -- Get item ID
        local id = GetItemId(args[2])
        if not id then
            Print("Recraft: First parameter must be an item link.")
            return
        end

        -- Make sure the crafting frame is open
        local frameOpen = ProfessionsFrame and ProfessionsFrame:IsShown()
        if not frameOpen then
            Print("Recraft: Please open the crafting window first.")
            return
        end

        for _, recipeId in pairs(C_TradeSkillUI.GetAllRecipeIDs()) do
            local link = C_TradeSkillUI.GetRecipeItemLink(recipeId) --[[@as string ]]
            if id == GetItemId(link) then
                SetRecraftRecipe(recipeId)
                return
            end
        end

        Print("Recraft: No recipe for link found.")
    else
        Print("Help")
        Print("|cffcccccc/testflight recraft [link]|r: Set recraft UI to an item given by link")
    end
end
