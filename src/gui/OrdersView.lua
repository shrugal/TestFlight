---@class TestFlight
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

---@class GUI.OrdersView
---@field frame OrdersView
local Self = GUI.OrdersView

---@param frame OrdersView
function Self:UpdateCreateButton(frame)
    if not Addon.enabled then return end

    self.frame.CreateButton:SetEnabled(false)
    self.frame.CreateButton:SetScript("OnEnter", Util:FnBind(self.CreateButtonOnEnter, self))
end

---@param frame Button
function Self:CreateButtonOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddErrorLine(GameTooltip, "Experimentation mode is enabled.")
    GameTooltip:Show()
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    self.frame = ProfessionsFrame.OrdersPage.OrderView

    hooksecurefunc(self.frame, "UpdateCreateButton", Util:FnBind(self.UpdateCreateButton, self))
end