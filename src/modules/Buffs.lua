---@class Addon
local Addon = select(2, ...)
local C, Util = Addon.Constants, Addon.Util

---@class Buffs: CallbackRegistryMixin
---@field Event Buffs.Event
local Self = Mixin(Addon.Buffs, CallbackRegistryMixin)

---@type number[]
Self.buffCharges = {}

---------------------------------------
--              Events
---------------------------------------

---@class Buffs.Event
---@field AuraChanged "AuraChanged"
---@field TraitChanged "TraitChanged"
---@field EquipmentChanged "EquipmentChanged"
---@field BuffChanged "BuffChanged"

Self:GenerateCallbackEvents({ "AuraChanged", "TraitChanged", "EquipmentChanged", "BuffChanged" })
Self:OnLoad()

---@param unit string
---@param info UnitAuraUpdateInfo
function Self:OnUnitAura(unit, info)
    if unit ~= "player" then return end

    local auraCharges

    if info.addedAuras then
        for _,data in pairs(info.addedAuras) do
            if C.BUFFS[data.spellId] then self.buffCharges[data.auraInstanceID], auraCharges = data.charges, true end
        end
    end

    if info.removedAuraInstanceIDs then
        for _,instanceID in pairs(info.removedAuraInstanceIDs) do
            if self.buffCharges[instanceID] then self.buffCharges[instanceID], auraCharges = nil, true end
        end
    end

    if info.updatedAuraInstanceIDs then
        for _,instanceID in pairs(info.updatedAuraInstanceIDs) do repeat
            if not self.buffCharges[instanceID] then break end
            local data = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceID) ---@cast data -?
            if self.buffCharges[instanceID] == data.charges then break end
            self.buffCharges[instanceID], auraCharges = data.charges, true
        until true end
    end

    if not auraCharges then return end

    self:TriggerEvent(self.Event.AuraChanged)
    self:TriggerEvent(self.Event.BuffChanged)
end

---@param configID number
function Self:OnTradeConfigUpdated(configID)
    local config = C_Traits.GetConfigInfo(configID)
    if not config or config.type ~= Enum.TraitConfigType.Profession then return end

    self:TriggerEvent(self.Event.TraitChanged, configID)
    self:TriggerEvent(self.Event.BuffChanged)
end

---@param skillLineID number
---@param isTool boolean
function Self:OnProfessionEquipmentChanged(skillLineID, isTool)
    self:TriggerEvent(self.Event.EquipmentChanged, skillLineID, isTool)
    self:TriggerEvent(self.Event.BuffChanged)
end

function Self:OnLoaded()
    AuraUtil.ForEachAura("player", "HELPFUL", nil, function (data) ---@cast data AuraData
        if C.BUFFS[data.spellId] then self.buffCharges[data.auraInstanceID] = data.charges end
    end, true)

    EventRegistry:RegisterFrameEventAndCallback("UNIT_AURA", self.OnUnitAura, self)
    EventRegistry:RegisterCallback("TRAIT_CONFIG_UPDATED", self.OnTradeConfigUpdated, self)
    EventRegistry:RegisterFrameEventAndCallback("PROFESSION_EQUIPMENT_CHANGED", self.OnProfessionEquipmentChanged, self)
end

Addon:RegisterCallback(Addon.Event.Loaded, Self.OnLoaded, Self)