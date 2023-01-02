local Name = ...

local enabled = false
---@type table<string, function>
local hooks = {}
---@type CheckButton[]
local checkboxes = {}
---@type NumericInputSpinner, number
local skillBox, extraSkill = nil, 0

local QUALITY_BREAKPOINTS = {
    [3] = { 0, 0.5, 1 },
    [5] = { 0, 0.2, 0.5, 0.8, 1 }
}

---------------------------------------
--              Hook
---------------------------------------

local function hook(obj, name, fn)
    if not obj or hooks[name] ~= nil then return end
    hooks[name] = obj[name]
    obj[name] = fn
end

local function unhook(obj, name)
    if not obj or hooks[name] == nil then return end
    obj[name] = hooks[name]
    hooks[name] = nil
end

local function refresh()
    for _, checkbox in pairs(checkboxes) do
        checkbox:SetChecked(enabled)
    end

    -- ProfessionsFrame
    ProfessionsFrame.CraftingPage.SchematicForm:Refresh()
    ProfessionsFrame.CraftingPage:ValidateControls()

    -- ProfessionsCustomerOrdersFrame
    if ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form:IsVisible() then
        ProfessionsCustomerOrdersFrame.Form:InitSchematic()
        if enabled then
            ProfessionsCustomerOrdersFrame.Form.PaymentContainer.ListOrderButton:SetEnabled(false)
        end
    end
end

local function enable()
    if enabled then return end
    enabled = true

    hook(ItemUtil, "GetCraftingReagentCount", function() return math.huge end)
    hook(Professions, "GetReagentSlotStatus", function() return false end)

    -- ProfessionsFrame
    local form = ProfessionsFrame.CraftingPage.SchematicForm

    hook(form, "GetRecipeOperationInfo", function(self)
        ---@type CraftingOperationInfo
        local op = hooks.GetRecipeOperationInfo(self)
        if not op then return end

        op.baseSkill, op.bonusSkill = op.baseSkill + op.bonusSkill, extraSkill

        if op.isQualityCraft then
            local skill, difficulty = op.baseSkill + op.bonusSkill, op.baseDifficulty + op.bonusDifficulty
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
    end)

    form.Details.StatLines.SkillStatLine.RightLabel:Hide()
    skillBox:Show()

    refresh()
end

local function disable()
    if not enabled then return end
    enabled = false

    unhook(ItemUtil, "GetCraftingReagentCount")
    unhook(Professions, "GetReagentSlotStatus")

    -- ProfessionsFrame
    local form = ProfessionsFrame.CraftingPage.SchematicForm

    unhook(form, "GetRecipeOperationInfo")
    extraSkill = 0

    form.Details.StatLines.SkillStatLine.RightLabel:Show()
    skillBox:Hide()

    -- Clear reagents in locked slots
    for reagentType, slots in pairs(form.reagentSlots) do
        if reagentType ~= Enum.CraftingReagentType.Basic then
            for _, slot in pairs(slots) do
                local schematic = slot:GetReagentSlotSchematic()
                local locked = Professions.GetReagentSlotStatus(schematic, form.currentRecipeInfo)
                if locked and form.transaction:HasAllocations(schematic.slotIndex) then
                    form.transaction:ClearAllocations(schematic.slotIndex)
                    slot:ClearItem()
                    form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
                end
            end
        end
    end

    refresh()
end

local function toggle()
    if enabled then disable() else enable() end
end

---------------------------------------
--               GUI
---------------------------------------

---@param self CheckButton
local function CheckboxOnClick(self)
    if self:GetChecked() ~= enabled then toggle() end
end

---@param self CheckButton
local function CheckboxOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip_AddNormalLine(GameTooltip, "Experiment with crafting recipes without reagent and spec limits.");
    GameTooltip:Show();
end

---@param form Frame
---@param sibling? Frame
local function InsertCheckbox(form, sibling)
    local checkbox = CreateFrame("CheckButton", nil, form, "UICheckButtonTemplate")

    checkbox.text:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode("Experiment"))
    checkbox:SetChecked(enabled)
    checkbox:SetScript("OnClick", CheckboxOnClick)
    checkbox:SetScript("OnEnter", CheckboxOnEnter);
    checkbox:SetScript("OnLeave", GameTooltip_Hide);

    if sibling then
        checkbox:SetPoint("LEFT", sibling, "RIGHT", 20, 0)
    else
        checkbox:SetPoint("BOTTOMLEFT")
    end

    tinsert(checkboxes, checkbox)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == Name then
            -- ProfessionsFrame
            local parent = ProfessionsFrame.CraftingPage
            local form = parent.SchematicForm

            InsertCheckbox(form, form.AllocateBestQualityCheckBox.text)

            hooksecurefunc(parent, "ValidateControls", function(self)
                if not enabled then return end
                self.CreateButton:SetEnabled(false)
                self.CreateAllButton:SetEnabled(false)
                self.CreateMultipleInputBox:SetEnabled(false)
                self:SetCreateButtonTooltipText("Experimentation mode is enabled.")
            end)

            skillBox = CreateFrame("EditBox", nil, form.Details.StatLines.SkillStatLine, "NumericInputSpinnerTemplate") --[[@as NumericInputSpinner]]
            skillBox:Hide()
            skillBox:SetPoint("RIGHT")
            skillBox:SetOnValueChangedCallback(function(self, value)
                extraSkill = max(0, value - (self.min or 0))
                ProfessionsFrame.CraftingPage.SchematicForm:UpdateDetailsStats()
            end)

            hooksecurefunc(form, "UpdateDetailsStats", function(self)
                ---@type CraftingOperationInfo
                local op = (enabled and hooks or self).GetRecipeOperationInfo(form)
                if not op then return end

                local skill, difficulty = op.baseSkill + op.bonusSkill, op.baseDifficulty + op.bonusDifficulty
                skillBox:SetMinMaxValues(skill, max(skill, difficulty))
                skillBox:SetValue(skill + extraSkill)
            end)
        elseif ... == "Blizzard_ProfessionsCustomerOrders" then
            -- ProfessionsCustomerOrdersFrame
            local parent = ProfessionsCustomerOrdersFrame.Form
            local form = parent.ReagentContainer

            InsertCheckbox(form)

            hooksecurefunc(parent, "UpdateListOrderButton", function(self)
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
---@field SetMinMaxValues fun(self: self, min: number, max: number)
---@field SetValue fun(self: self, value: number)
---@field SetOnValueChangedCallback fun(self: self, callback: fun(self: self, value: number))
