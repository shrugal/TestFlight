---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

---@class GUI.CraftingPage
---@field frame CraftingPage
local Self = GUI.CraftingPage

function Self:ValidateControls()
    if not Addon.enabled then return end

    self.frame.CreateButton:SetEnabled(false)
    self.frame.CreateAllButton:SetEnabled(false)
    self.frame.CreateMultipleInputBox:SetEnabled(false)
    self.frame:SetCreateButtonTooltipText("Experimentation mode is enabled.")
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnRefresh()
    if not self.frame or not self.frame:IsVisible() then return end

    self:ValidateControls()
end

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    self.frame = ProfessionsFrame.CraftingPage

    hooksecurefunc(self.frame, "ValidateControls", Util:FnBind(self.ValidateControls, self))

    GUI:RegisterCallback(GUI.Event.Refresh, self.OnRefresh, self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)