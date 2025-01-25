---@class Addon
local Addon = select(2, ...)
local GUI, Buffs, Util = Addon.GUI, Addon.Buffs, Addon.Util
local NS = GUI.RecipeForm

local Parent = NS.RecipeForm

---@class GUI.RecipeForm.WithAuras: GUI.RecipeForm.RecipeForm
---@field form RecipeCraftingForm
local Self = NS.WithAuras

---@type Buffs.AuraSlot[]
Self.AURA_SLOTS = {
    Buffs.AuraSlot.Profession,
    Buffs.AuraSlot.Phial
}

---@type string?
Self.auras = nil

---@param auras? string
---@param silent? boolean
function Self:SetAuras(auras, silent)
    if auras == "" then auras = nil end
    if auras == self.auras then return end

    self.auras = auras

    self:UpdateAuraSlots()

    if silent then return end

    self.form:UpdateDetailsStats()
end

function Self:GetAuras()
    return self.auras and Buffs:MergeAuras(Buffs:GetCurrentAuras(self:GetRecipe()), self.auras)
end

---@param auraID number
---@param level? number
function Self:SetAura(auraID, level)
    self:SetAuras(Buffs:SetAura(self.auras or "", auraID, level))
end

---@param slotType Buffs.AuraSlot
---@return number? auraID
---@return number? level
function Self:GetAura(slotType)
    return Util:TblFind(Buffs:EnumerateAuras(self.auras or "", slotType))
end

function Self:GetMissingAura()
    local op = self:GetOperation()
    if not op then return end

    return op:GetMissingAura()
end

function Self:GetAuraAction()
    local op = self:GetOperation()
    if not op then return end

    return op:GetAuraAction()
end

function Self:CastNextAura()
    local op = self:GetOperation()
    if not op then return end

    return op:CastNextAura()
end

function Self:UpdateAuraSlots()
    local recipe = self:GetRecipe()

    local shownSlots = {}
    for _,slotType in ipairs(self.AURA_SLOTS) do
        local slot = self.auraSlots[slotType]
        local show = recipe and Util:TblSome(Buffs:EnumerateAuras(recipe, slotType))

        slot:Init(self, slotType)
        slot:SetShown(show)

        if show then tinsert(shownSlots, slot) end
     end

    Professions.LayoutAndShowReagentSlotContainer(shownSlots, self.auraSlotContainer)

    if not self.auraSlotContainer:IsShown() then return end

    if self.form.RecraftingDescription:IsShown() then
        self.auraSlotContainer:SetPoint("TOPLEFT", self.form.RecraftingDescription, "BOTTOMLEFT", 0, -20)
    else
        local xOffset = self.form.OptionalReagents:IsShown() and 185 or 0
        self.auraSlotContainer:SetPoint("TOPLEFT", self.form.Reagents, "BOTTOMLEFT", xOffset, -20)
    end
end

function Self:InsertAuraSlotContainer()
    self.auraSlotContainer = GUI:InsertElement(
        "Frame", self.form, "ProfessionsReagentContainerTemplate", nil,
        "LEFT", self.form.OptionalReagents, "RIGHT"
    ) --[[@as ProfessionsReagentContainer]]

    self.auraSlotContainer:SetText("Buffs:")
    self.auraSlotContainer:Hide()

    ---@type table<Buffs.AuraSlot, GUI.RecipeForm.AuraReagentSlot>
    self.auraSlots = {}

    for _,slotType in ipairs(self.AURA_SLOTS) do
        self.auraSlots[slotType] = GUI:InsertElement("Frame", self.auraSlotContainer, "TestFlightAuraSlotTemplate") --[[@as GUI.RecipeForm.AuraReagentSlot]]
    end
end

---------------------------------------
--               Util
---------------------------------------

function Self:SetOperation(operation)
    self:SetAuras(operation.auras, true)

    Parent.SetOperation(self, operation)
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnAuraChanged()
    if not self.form:IsVisible() then return end
    self:UpdateAuraSlots()
end

function Self:OnAddonLoaded()
    self:InsertAuraSlotContainer()

    Buffs:RegisterCallback(Buffs.Event.AuraChanged, self.OnAuraChanged, self)
end
