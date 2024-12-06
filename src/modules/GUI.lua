---@class Addon
local Addon = select(2, ...)
local Reagents, Util = Addon.Reagents, Addon.Util

---@class GUI: CallbackRegistryMixin
---@field Event GUI.Event
local Self = Mixin(Addon.GUI, CallbackRegistryMixin)

---@type GUI.ObjectiveTracker.ProfessionsTrackerModule[]
Self.objectiveTrackers = {
    Self.ObjectiveTracker.RecipeTracker,
    Self.ObjectiveTracker.ReagentsTracker
}

---@type GUI.RecipeForm.RecipeForm[]
Self.forms = {
    Self.RecipeForm.CraftingForm,
    Self.RecipeForm.OrdersForm,
    Self.RecipeForm.CustomerOrderForm
}

---------------------------------------
--             Elements
---------------------------------------

---@generic T
---@param frameType `T`
---@param parent? Frame
---@param template? string
---@param onEnter? function
---@return T
function Self:InsertElement(frameType, parent, template, onEnter, ...)
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
function Self:InsertButton(text, parent, onEnter, onClick, ...)
    local input = self:InsertElement("CheckButton", parent, "UIPanelButtonTemplate", onEnter, ...) --[[@as ButtonFitToText]]

    input:SetScript("OnClick", onClick)
    input:SetTextToFit(text)

    return input
end

---@param parent Frame
---@param onEnter? function
---@param onValueChanged? function
function Self:InsertNumericSpinner(parent, onEnter, onValueChanged, ...)
    local input = self:InsertElement("EditBox", parent, "NumericInputSpinnerTemplate", onEnter, ...) --[[@as NumericInputSpinner]]

    input:Hide()
    if onValueChanged then input:SetOnValueChangedCallback(onValueChanged) end

    return input
end

---@param parent? Frame
---@param onEnter? function
---@param onClick? function
function Self:InsertCheckbox(parent, onEnter, onClick, ...)
    local input = self:InsertElement("CheckButton", parent, "UICheckButtonTemplate", onEnter, ...) --[[@as CheckButton]]

    input:SetScript("OnClick", onClick)

    return input
end

---@param parent Frame
---@param drawLayer? DrawLayer
---@param templateName? string
---@param text? string
---@param onEnter? function
function Self:InsertFontString(parent, drawLayer, templateName, text, onEnter, ...)
    local font = parent:CreateFontString(nil, drawLayer or "ARTWORK", templateName or "GameFontNormal")

    if onEnter then
        font:SetMouseMotionEnabled(true)
        font:SetScript("OnEnter", onEnter)
        font:SetScript("OnLeave", GameTooltip_Hide)
    end

    if text then font:SetText(text) end
    if ... then font:SetPoint(...) end

    return font
end

---------------------------------------
--              Tooltip
---------------------------------------

-- Reagent tooltip

---@param tooltip? GameTooltip
function Self:TooltipPostCall(tooltip)
    if not Addon.DB.Account.tooltip then return end
    if not tooltip or not tooltip.GetItem then return end

    local _, link = tooltip:GetItem()
    if not link then return end

    local id = C_Item.GetItemIDForItemInfo(link)
    if not id then return end

    local reagentWeight = Addon.REAGENTS[id]
    local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(link)
    if not reagentWeight or not quality then return end

    local itemWeight = reagentWeight * (quality - 1)

    tooltip:AddDoubleLine("Craft weight", ("%d (%d)"):format(itemWeight, reagentWeight), nil, nil, nil, WHITE_FONT_COLOR.r, WHITE_FONT_COLOR.g, WHITE_FONT_COLOR.b)

    local form = self:GetVisibleForm()
    if not form or not form.form.transaction then return end
    local recipe = form:GetRecipe()
    if not recipe then return end

    local totalWeight = Reagents:GetMaxWeight(recipe.reagentSlotSchematics)
    local _, maxSkill = Reagents:GetSkillBounds(recipe)
    if not maxSkill or maxSkill == 0 then return end

    local skill = Util:NumRound(maxSkill * itemWeight / totalWeight, 1)

    tooltip:AddDoubleLine("Craft skill", skill, nil, nil, nil, WHITE_FONT_COLOR.r, WHITE_FONT_COLOR.g, WHITE_FONT_COLOR.b)
end

TooltipDataProcessor.AddTooltipPostCall(
    Enum.TooltipDataType.Item,
    Util:FnBind(Self.TooltipPostCall, Self)
)

---------------------------------------
--              Util
---------------------------------------

---@return GUI.RecipeForm.RecipeForm?
function Self:GetVisibleForm()
    for _,f in ipairs(self.forms) do
        if f.form and f.form:IsVisible() then return f end
    end
end

---------------------------------------
--              Events
---------------------------------------

---@class GUI.Event
---@field Refresh "Refresh"

Self:GenerateCallbackEvents({ "Refresh" })
Self:OnLoad()

function Self:OnEnabled()
    Util:TblHook(ItemUtil, "GetCraftingReagentCount", Util.FnInfinite)
    Util:TblHook(Professions, "GetReagentSlotStatus", Util.FnFalse)
    Util:TblHook(ProfessionsUtil, "GetReagentQuantityInPossession", Util.FnInfinite)

    C_Timer.After(0, Util:FnBind(self.Refresh, self))
end

function Self:OnDisabled()
    Util:TblUnhook(ItemUtil, "GetCraftingReagentCount")
    Util:TblUnhook(Professions, "GetReagentSlotStatus")
    Util:TblUnhook(ProfessionsUtil, "GetReagentQuantityInPossession")

    C_Timer.After(0, Util:FnBind(self.Refresh, self))
end

function Self:Refresh()
    ObjectiveTrackerFrame:Update()

    self:TriggerEvent(self.Event.Refresh)
end

Addon:RegisterCallback(Addon.Event.Enabled, Self.OnEnabled, Self)
Addon:RegisterCallback(Addon.Event.Disabled, Self.OnDisabled, Self)
