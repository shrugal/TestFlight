---@class TestFlight
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
--             Lifecycle
---------------------------------------

function Self:OnEnable()
    Util:TblHook(itemFlyout, "InitializeContents", self.InitializeContents, self)
end

function Self:OnDisable()
    Util:TblUnhook(itemFlyout, "InitializeContents")
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    itemFlyout = OpenProfessionsItemFlyout()
    CloseProfessionsItemFlyout()
end