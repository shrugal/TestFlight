---@diagnostic disable: missing-fields

---@class Addon
local Addon = select(2, ...)

---@type Util
Addon.Util = {}
---@type Promise.Static
Addon.Promise = {}

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
        ---@type GUI.RecipeForm.AmountForm
        AmountForm = {},
        ---@type GUI.RecipeForm.OrderForm
        OrderForm = {},
        ---@type GUI.RecipeForm.RecipeForm
        RecipeForm = {},
        ---@type GUI.RecipeForm.RecipeCraftingForm
        RecipeCraftingForm = {},
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
    ---@type GUI.OrdersView
    OrdersView = {},
    ---@type GUI.ItemFlyout
    ItemFlyout = {}
}

TestFlight = Addon