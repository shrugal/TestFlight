---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

---@class GUI.RecipeForm.WithSkill: GUI.RecipeForm.RecipeForm
---@field form RecipeCraftingForm
local Self = GUI.RecipeForm.WithSkill

---@param frame NumericInputSpinner
function Self:SkillSpinnerOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddColoredLine(GameTooltip, "Extra skill", HIGHLIGHT_FONT_COLOR)
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
    self.skillSpinner:SetWidth(26)
    self.skillSpinner.DecrementButton:SetAlpha(0.7)
    self.skillSpinner.IncrementButton:SetAlpha(0.7)
end

function Self:UpdateSkillSpinner()
    local op = self.form:GetRecipeOperationInfo()
    if not op or not op.baseDifficulty then return end

    local skillNoExtra = op.baseSkill + op.bonusSkill - Addon.extraSkill
    local difficulty = op.baseDifficulty + op.bonusDifficulty

    self.skillSpinner:SetMinMaxValues(0, math.max(0, difficulty - skillNoExtra))
    self.skillSpinner:SetShown(Addon.enabled and not ProfessionsUtil.IsCraftingMinimized() and self:IsCraftingRecipe())
    self.skillSpinner:SetValue(Addon.extraSkill)
end