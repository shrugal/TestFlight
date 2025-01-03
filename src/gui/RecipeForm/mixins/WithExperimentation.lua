---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

---@class GUI.RecipeForm.WithExperimentation: GUI.RecipeForm.RecipeForm
local Self = GUI.RecipeForm.WithExperimentation

---@param frame CheckButton
function Self:ExperimentBoxOnClick(frame)
    if frame:GetChecked() ~= Addon.enabled then Addon:Toggle() end
end

---@param frame CheckButton
function Self:ExperimentBoxOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Experiment with crafting recipes without reagent and spec limits.")
    GameTooltip:Show()
end

---@param parent Frame
function Self:InsertExperimentBox(parent, ...)
    local input = GUI:InsertCheckbox(parent, Util:FnBind(self.ExperimentBoxOnEnter, self), Util:FnBind(self.ExperimentBoxOnClick, self), ...)

    input.text:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode("Experiment"))
    input:SetChecked(Addon.enabled)

    self.experimentBox = input

    return input
end

function Self:UpdateExperimentBox()
    self.experimentBox:SetShown(self:ShouldShowElement(false, true))
    self.experimentBox:SetChecked(Addon.enabled)
end

---------------------------------------
--             Events
---------------------------------------

function Self:OnRefresh()
    if self.form:IsVisible() then return end
    self:UpdateExperimentBox()
end

function Self:OnAddonLoaded()
    GUI:RegisterCallback(GUI.Event.Refresh, self.OnRefresh, self)
end