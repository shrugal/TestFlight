---@type Addon
local Addon = select(2, ...)

---@class SettingsEditBox: CallbackRegistryMixin, DefaultTooltip, EditBox
---@field Event { OnValueChanged: "OnValueChanged" }
local Self = CreateFromMixins(CallbackRegistryMixin, DefaultTooltipMixin)
TestFlightSettingsEditBoxMixin = Self

Self:GenerateCallbackEvents({ "OnValueChanged" })

function Self:OnLoad()
	CallbackRegistryMixin.OnLoad(self)
	DefaultTooltipMixin.OnLoad(self)
end

function Self:Init(value, initTooltip)
	self:SetValue(value)
	self:SetTooltipFunc(initTooltip)

	self:SetScript("OnEditFocusLost", function(editBox)
		self:TriggerEvent(self.Event.OnValueChanged, editBox:GetText())
	end)
end

function Self:Release()
	self:SetScript("OnEditFocusLost", nil)
end

function Self:SetValue(value)
	self:SetText(value)
end

---@class SettingsEditBoxControl: SettingsControl
local Self = CreateFromMixins(SettingsControlMixin)
TestFlightSettingsEditBoxControlMixin = Self

function Self:OnLoad()
	SettingsControlMixin.OnLoad(self)

    ---@type SettingsEditBox
    self.EditBox = CreateFrame("EditBox", nil, self, "TestFlightSettingsEditBoxTemplate")
	-- self.EditBox:SetPoint("LEFT", self, "CENTER", -80, -3)
end

---@param initializer SettingsListElementInitializer
function Self:Init(initializer)
    SettingsControlMixin.Init(self, initializer)

	local setting = self:GetSetting()
    local initTooltip = Settings.CreateOptionsInitTooltip(setting, initializer:GetName(), initializer:GetTooltip(), initializer:GetOptions())

	self.EditBox:Init(setting:GetValue(), initTooltip)

	self.cbrHandles:RegisterCallback(self.EditBox, TestFlightSettingsEditBoxMixin.Event.OnValueChanged, self.OnEditBoxValueChanged, self)

	self:EvaluateState()
end

function Self:OnSettingValueChanged(setting, value)
	SettingsControlMixin.OnSettingValueChanged(self, setting, value)

	self:SetValue(value)
end

function Self:OnEditBoxValueChanged(value)
	if self:ShouldInterceptSetting(value) then
		self:SetValue(value)
	else
		self:GetSetting():SetValue(value)
	end
end

function Self:SetValue(value)
	self.EditBox:SetValue(value)
end

function Self:EvaluateState()
	SettingsListElementMixin.EvaluateState(self)

	local enabled = SettingsControlMixin.IsEnabled(self)

	self.EditBox:SetEnabled(enabled)
	self:DisplayEnabled(enabled)
end

function Self:Release()
	self.EditBox:Release()
	SettingsControlMixin.Release(self)
end