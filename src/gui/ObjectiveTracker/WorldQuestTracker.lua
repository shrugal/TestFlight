---@class TestFlight
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util

---@class GUI.ObjectiveTracker.WorldQuestTracker
local Self = GUI.ObjectiveTracker.WorldQuestTracker

function Self:RefreshTrackerAnchor()
    if not WorldQuestTrackerScreenPanel or not WorldQuestTrackerScreenPanel:IsShown() then return end
    if not WorldQuestTrackerAddon.db.profile.tracker_attach_to_questlog then return end

    local reagentsTracker = GUI.ObjectiveTracker.ReagentsTracker.module
    if not reagentsTracker then return end

    local point, relativeTo, relativePoint, x, y = ObjectiveTrackerFrame:GetPoint(1)
    if not point then return end

    local height = reagentsTracker:IsShown() and reagentsTracker:GetHeight() or 0

    WorldQuestTrackerScreenPanel:SetPoint(point, relativeTo, relativePoint, x - 10, y - 20 - WorldQuestTrackerAddon.TrackerHeight - height)
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("WorldQuestTracker", addonName) then return end

    hooksecurefunc(WorldQuestTrackerAddon, "RefreshTrackerAnchor", Util:FnBind(self.RefreshTrackerAnchor, self))
end