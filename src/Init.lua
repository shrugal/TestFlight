---@diagnostic disable: missing-fields

---@class Addon
local Addon = select(2, ...)

---@type Constants
Addon.Constants = {}
---@type Util
Addon.Util = {}
---@type Promise.Static
Addon.Promise = {}
---@type Cache.Static
Addon.Cache = {}
---@type Operation.Static
Addon.Operation = {}

---@type Prices
Addon.Prices = {}
---@type Recipes
Addon.Recipes = {}
---@type Reagents
Addon.Reagents = {}
---@type Orders
Addon.Orders = {}
---@type Optimization
Addon.Optimization = {}
---@type Restock
Addon.Restock = {}

---@class GUI
Addon.GUI = {
    ObjectiveTracker = {
        ---@type GUI.ObjectiveTracker.ProfessionsTrackerModule
        ProfessionsTrackerModule = {},
        ---@type GUI.ObjectiveTracker.RecipeTracker
        RecipeTracker = {},
        ---@type GUI.ObjectiveTracker.ReagentsTracker
        ReagentsTracker = {},
        ---@type GUI.ObjectiveTracker.WorldQuestTracker
        WorldQuestTracker = {},
    },

    ---@class GUI.RecipeForm
    RecipeForm = {
        ---@type GUI.RecipeForm.RecipeForm
        RecipeForm = {},
        ---@type GUI.RecipeForm.WithExperimentation
        WithExperimentation = {},
        ---@type GUI.RecipeForm.WithSkill
        WithSkill = {},
        ---@type GUI.RecipeForm.WithAmount
        WithAmount = {},
        ---@type GUI.RecipeForm.WithRestock
        WithRestock = {},
        ---@type GUI.RecipeForm.WithOptimization
        WithOptimization = {},
        ---@type GUI.RecipeForm.WithOrder
        WithOrder = {},
        ---@type GUI.RecipeForm.WithCrafting
        WithCrafting = {},
        ---@type GUI.RecipeForm.CraftingForm
        CraftingForm = {},
        ---@type GUI.RecipeForm.OrdersForm
        OrdersForm = {},
        ---@type GUI.RecipeForm.CustomerOrderForm
        CustomerOrderForm = {},
        ---@type GUI.RecipeForm.OptimizationMethodDropdownMixin
        OptimizationMethodDropdown = {},
    },

    ---@type GUI.CraftingPage
    CraftingPage = {},
    ---@type GUI.OrdersPage
    OrdersPage = {},
    ---@type GUI.OrdersView
    OrdersView = {},
    ---@type GUI.ItemFlyout
    ItemFlyout = {}
}

TestFlight = Addon