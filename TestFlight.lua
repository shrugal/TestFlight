local Name = ...

local enabled = false
local hooks = {}
local checkboxes = {}

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
    do
        local parent = ProfessionsFrame.CraftingPage
        local form = parent.SchematicForm

        if not enabled then
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
        end

        form:Refresh()
        parent:ValidateControls()
    end

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

    refresh()
end

local function disable()
    if not enabled then return end
    enabled = false

    unhook(ItemUtil, "GetCraftingReagentCount")
    unhook(Professions, "GetReagentSlotStatus")

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
