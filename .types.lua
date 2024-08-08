---@diagnostic disable: duplicate-set-field
---@meta

---
-- This class contains EmmyLua annotations to help
-- IDEs work with some external classes and types
---

-- WoW methods

---@class C_TradeSkillUI
---@field GetRecipeItemLink fun(recipeID: number): string
C_TradeSkillUI = {}

---@class GameTooltip
---@field SetRecipeResultItem fun(recipeSpellID: number, reagents?: CraftingReagentInfo[], allocationItemGUID?: string, overrideLevel?: number, overrideQualityID?: number)

---@class CheckButton
---@field text FontString

---@class NumericInputSpinner: EditBox
---@field min number
---@field max number
---@field IncrementButton Button
---@field DecrementButton Button
---@field SetMinMaxValues fun(self: self, min: number, max: number)
---@field SetValue fun(self: self, value: number)
---@field SetOnValueChangedCallback fun(self: self, callback: fun(self: self, value: number))

---@class QuestObjectiveAnimLine: Frame
---@field itemName string
---@field Button Button
---@field Text FontString
---@field Check Texture
