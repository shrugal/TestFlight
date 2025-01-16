---@class Addon
local Addon = select(2, ...)

---@class GUI.RecipeListProgressBarMixin
---@field ProgressBar StatusBar
---@field CancelButton Button
local Self = {}

---@class GUI.RecipeListProgressBar: Frame, GUI.RecipeListProgressBarMixin

---@param self GUI.RecipeListProgressBar
---@param total number
function Self:Start(total)
    self:Show()
    self.ProgressBar:SetMinMaxValues(0, total)
    self.ProgressBar:SetValue(0.01)
    self.ProgressBar.Text:SetFormattedText("Scanning %d/%d", 0, total)
end

---@param self GUI.RecipeListProgressBar
---@param currentCount number
---@param totalCount number
function Self:Progress(currentCount, totalCount)
    if currentCount == totalCount then self:Hide() return end

    self.ProgressBar:SetValue(currentCount)
    self.ProgressBar.Text:SetFormattedText("Scanning %d/%d", currentCount, totalCount)
end

TestFlightRecipeListProgressBarMixin = Self
