---@class Addon
local Addon = select(2, ...)
local Util = Addon.Util

local Parent = ProfessionsRecipeListRecipeMixin

---@class GUI.ProfessionsRecipeListRecipeMixin: ProfessionsRecipeListRecipeMixin
---@field Value FontString
local Self = CreateFromMixins(Parent)

---@class GUI.ProfessionsRecipeListRecipeButton: Button, GUI.ProfessionsRecipeListRecipeMixin

---@param self GUI.ProfessionsRecipeListRecipeButton
---@param node TreeNodeMixin
---@param hideCraftableCount boolean
function Self:Init(node, hideCraftableCount)
    self.node = node

    Parent.Init(self, node, hideCraftableCount)

    local value = node:GetData().value
    if not value then self.Value:Hide() return end

    if abs(value) > 10000 then
        value = Util:NumRound(value, -4)
    elseif abs(value) > 100 then
        value = Util:NumRound(value, -2)
    end

    self.Value:Show()
    self.Value:SetText(Util:NumCurrencyString(value, false))

    -- Adjust label
	local padding = 10
    local lockedWith = self.LockedIcon:IsShown() and self.LockedIcon:GetWidth() or 0
	local countWidth = self.Count:IsShown() and self.Count:GetStringWidth() or 0
	local width = self:GetWidth() - (lockedWith + countWidth + padding + self.SkillUps:GetWidth() + self.Value:GetWidth())

	self.Label:SetWidth(self:GetWidth())
	self.Label:SetWidth(min(width, self.Label:GetStringWidth()))

    -- Adjust locked icon
    if self.LockedIcon:IsShown() then
        self.LockedIcon:ClearAllPoints()
        self.LockedIcon:SetPoint("RIGHT", self.Value, "LEFT")
    end
end

---@param color ColorMixin
function Self:SetLabelFontColors(color)
    Parent.SetLabelFontColors(self, color)

    local value = self.node:GetData().value
    if not value then return end

    local r, g, b = color:GetRGB()
    if value < 0 then g, b = 0, 0 end

    self.Value:SetVertexColor(r, g, b)
end

TestFlightProfessionsRecipeListRecipeMixin = Self