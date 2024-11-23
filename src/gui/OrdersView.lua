---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

---@class GUI.OrdersView
---@field frame OrdersView
local Self = GUI.OrdersView

function Self:InitCreateUpdate()
    local orig = self.frame.CreateButton:GetScript("OnClick")
    self.frame.CreateButton:SetScript("OnClick", function(...)
        local dialog = self:GetConfirmationDialog()
        if dialog then
            StaticPopup_OnClick(dialog, 1)
            self.frame:UpdateCreateButton()
        else
            orig(...)

            dialog = self:GetConfirmationDialog()
            if not dialog then return end

            self.frame.CreateButton:SetText(RPE_CONFIRM)
            dialog.data.cancelCallback = Util:FnBind(self.frame.UpdateCreateButton, self.frame)
        end
    end)
end

---@param frame OrdersView
function Self:UpdateCreateButton(frame)
    if not Addon.enabled then return end

    self.frame.CreateButton:SetEnabled(false)
    self.frame.CreateButton:SetScript("OnEnter", Util:FnBind(self.CreateButtonOnEnter, self))
    self.frame.CreateButton:SetScript("OnLeave", GameTooltip_Hide)
end

---@param frame Button
function Self:CreateButtonOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddErrorLine(GameTooltip, "Experimentation mode is enabled.")
    GameTooltip:Show()
end

---------------------------------------
--               Util
---------------------------------------

function Self:GetConfirmationDialog()
    local _, dialog = StaticPopup_Visible("GENERIC_CONFIRMATION")
    if dialog and dialog.data.text == CRAFTING_ORDERS_OWN_REAGENTS_CONFIRMATION then
        return dialog
    end
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    self.frame = ProfessionsFrame.OrdersPage.OrderView

    self:InitCreateUpdate()

    -- This is just a visual fix
    self.frame.CompleteOrderButton:SetPoint("BOTTOMRIGHT", -20, 7)

    hooksecurefunc(self.frame, "UpdateCreateButton", Util:FnBind(self.UpdateCreateButton, self))
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)