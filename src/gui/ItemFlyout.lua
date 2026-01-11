---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

---@class GUI.ItemFlyout
local Self = GUI.ItemFlyout

---@type Flyout?
local itemFlyout

---@param frame Flyout
function Self:InitializeContents(frame, ...)
    frame.OnElementEnabledImplementation = frame.GetElementValidImplementation or Util.FnTrue
    Util:TblGetHooks(frame).InitializeContents(frame, ...)
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnEnabled()
    Util:TblHook(itemFlyout, "InitializeContents", self.InitializeContents, self)
end

function Self:OnDisabled()
    Util:TblUnhook(itemFlyout, "InitializeContents")
end

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    itemFlyout = OpenProfessionsItemFlyout(UIParent)
    CloseProfessionsItemFlyout()

    Addon:RegisterCallback(Addon.Event.Enabled, Self.OnEnabled, Self)
    Addon:RegisterCallback(Addon.Event.Disabled, Self.OnDisabled, Self)
end

-- TODO: Figure out how to do this now
-- Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)