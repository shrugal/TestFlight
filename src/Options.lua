---@type string
local Name = ...
---@class Addon
local Addon = select(2, ...)
local C, GUI, Prices, Util = Addon.Constants, Addon.GUI, Addon.Prices, Addon.Util

---@class Options
local Self = Addon.Options

function Self:RegisterCategories()
    self.category, self.layout = Settings.RegisterVerticalLayoutCategory(Name)
    Settings.RegisterAddOnCategory(self.category)
end

function Self:RegisterGeneralSettings()
    -- Auto enable experimentation mode
    self:CreateCheckbox(
        "autoEnable",
        true,
        "Auto-Enable Experimentation",
        "Enable experimentation mode if needed when opening tracked recipes."
    )

    -- Reagents tooltip
    self:CreateCheckbox(
        "tooltip",
        false,
        "Reagent Tooltip",
        "Toggle reagent tooltip info."
    )

    -- Reagents tracker
    self:CreateCheckbox(
        "reagents",
        true,
        "Reagents Tracker",
        "Toggle reagents tracker.",
        function (setting, value)
            local tracker = GUI.ObjectiveTracker.ReagentsTracker.module
            if not tracker then return end

            if value then tracker:UpdatePosition() else tracker:RemoveFromParent() end
        end
    )

    --- Price source
    Settings.CreateDropdown(
        self.category,
        Settings.RegisterProxySetting(
            self.category,
            "priceSource",
            Settings.VarType.String,
            "Price Source",
            "auto",
            function () return Addon.DB.Account.priceSource or "auto" end,
            function (value) Addon.DB.Account.priceSource = value ~= "auto" and value or nil end
        ),
        function ()
            local container = Settings.CreateControlTextContainer()

            container:Add("auto", "Automatic", "Automatically select the first available price source.")

            for name,source in pairs(Prices.SOURCES) do
                container:Add(name, name .. (source:IsAvailable() and "" or " (unavailable)"))
            end

            return container:GetData()
        end,
        "Select the price source for reagents and items."
    )

    -- TSM price string
    if Prices.SOURCES.TradeSkillMaster:IsAvailable() then
        self:CreateEditBox(
            self.category,
            Settings.RegisterProxySetting(
                self.category,
                "tsmPriceString",
                Settings.VarType.String,
                "TSM Price String",
                nil,
                function () return Addon.DB.Account.tsmPriceString or C.TSM_PRICE_STRING end,
                ---@param value? string
                function (value)
                    value = (value or ""):trim()

                    if value == "" or value == C.TSM_PRICE_STRING then
                        value = nil
                    else
                        local _, err = TSM_API.GetCustomPriceValue(value, "i:2589")
                        if err then return Addon:Error("TSM price: %s", err or "Invalid string") end
                    end

                    Addon.DB.Account.tsmPriceString = value
                end
            ),
            "Enter a custom TSM price string to use for reagents and items."
        )
    end
end

---------------------------------------
--               Util
---------------------------------------

---@param name string
---@param defaultValue boolean
---@param label? string
---@param tooltip? string
---@param callback? fun(setting: Setting, value: boolean)
---@param category? SettingsCategory
---@param variableTbl? table
function Self:CreateCheckbox(name, defaultValue, label, tooltip, callback, category, variableTbl)
    if not label then label = Util(name):StartCase():Lower():UcFirst()() end
    if not category then category = self.category end
    if not variableTbl then variableTbl = Addon.DB.Account end

    local setting = Settings.RegisterAddOnSetting(category, name, name, variableTbl, Settings.VarType.Boolean, label, defaultValue)
    if callback then setting:SetValueChangedCallback(callback) end

    return Settings.CreateCheckbox(category, setting, tooltip)
end

---@param category SettingsCategory
---@param setting Setting
---@param tooltip? string
function Self:CreateEditBox(category, setting, tooltip)
    assert(setting:GetVariableType() == Settings.VarType.String)

    local initializer = Settings.CreateControlInitializer("TestFlightSettingsEditBoxControlTemplate", setting, nil, tooltip)
	SettingsPanel:GetLayout(category):AddInitializer(initializer)
    return initializer
end

---------------------------------------
--               Events
---------------------------------------

function Self:OnLoaded()
    self:RegisterCategories()
    self:RegisterGeneralSettings()
end

Addon:RegisterCallback(Addon.Event.Loaded, Self.OnLoaded, Self)