# AGENTS.md

This repo is a World of Warcraft addon written in Lua with a mix of Lua and XML UI frames. The entrypoint and file load order are controlled by the TOC.

## Project structure

- Root
  - [TestFlight.toc](TestFlight.toc): load order and addon metadata.
  - [README.md](README.md): short project description.
  - [CHANGELOG.md](CHANGELOG.md), [CHANGES.md](CHANGES.md), [TODO.md](TODO.md): notes and history.
- src/
  - Core
    - [src/Init.lua](src/Init.lua): global namespace setup, addon bootstrapping, load Blizzard_Professions if needed.
    - [src/Constants.lua](src/Constants.lua): static data tables, breakpoints, auras, and constants.
    - [src/Util.lua](src/Util.lua): utility helpers for tables, iteration, and WoW helpers.
    - [src/Addon.lua](src/Addon.lua): main addon object, SavedVariables defaults, migrations, events.
    - [src/Options.lua](src/Options.lua): Blizzard Settings UI registration.
  - Core frames
    - XML templates in [src/frames](src/frames) (SettingsEditBox).
  - Mixins
    - [src/mixins](src/mixins): data structures and functional helpers (Promise, Allocations, Cache, Operation).
  - Modules
    - [src/modules](src/modules): feature-specific modules (Recipes, Reagents, Orders, Prices, Optimization, Restock, Buffs, GUI).
  - GUI
    - [src/gui](src/gui): primary UI features and pages.
    - Objective tracker integrations under [src/gui/ObjectiveTracker](src/gui/ObjectiveTracker).
    - Recipe form and container UI under [src/gui/RecipeForm](src/gui/RecipeForm) and [src/gui/RecipeFormContainer](src/gui/RecipeFormContainer), including XML frame definitions and mixins.

## Dependencies and toolkits

- World of Warcraft API
  - Blizzard UI: Settings, CreateFrame, TooltipDataProcessor, C_TradeSkillUI, C_AddOns, and related enums.
  - SavedVariables: `TestFlightDB` (account), `TestFlightCharDB` (per character).
- Optional addon integrations (declared in TOC)
  - Auctionator, TradeSkillMaster, RECrystallize, OribosExchange, Auctioneer, WoWNotes.
- Price sources (required for cost/profit calculations)
  - TradeSkillMaster, Auctionator, RECrystallize, OribosExchange, Auctioneer.
  - Settings allow manual selection or automatic first-available.
- Restock inventory accounting (optional)
  - TradeSkillMaster, Syndicator, Altoholic.
- XML UI templates
  - Uses Blizzard templates like `UIPanelButtonTemplate`, `NumericInputSpinnerTemplate`, `ProfessionsGearSlotTemplate`, and custom XML under src/frames and GUI subfolders.

## Feature overview

- Goal: keep additions lightweight and integrated with the default crafting UI.
- Crafting
  - Experimentation mode unlocks reagent slots and simulates results and skill.
  - Optimize reagents/tools with one-click quality switching and multiple optimization targets.
  - Simulate buffs/consumables and extra skill points; show costs, profits, and stat value.
- Orders
  - Auto-allocate profitable reagents, show profits/rewards, track orders, and complete tracked orders sequentially.
  - Configure max prices for skill/currency rewards and show reagent prices on order creation.
- Tracking and restocking
  - Track multiple crafts, reapply allocations, and surface reagent breakdowns in the objective tracker.
  - One-click AH search and Auctionator shopping list generation for missing reagents.
  - Restock targets with min profit, plus crafting queue and pending restock views.
- Misc
  - Auctionator shopping tab buy automation button.
  - Tooltip reagent skill contribution (toggle in settings).
  - Recraft preview command: `/tf recraft <item-link>`.

## Coding style and conventions

- Lua + EmmyLua annotations
  - Frequent use of `---@class`, `---@type`, `---@param`, `---@return`.
  - Prefer typed locals and self-documenting helpers.
- Namespacing
  - Central Addon table set in [src/Init.lua](src/Init.lua), then modules assign `local Self = Addon.<Module>`.
  - Public namespace exposed as `TestFlight = Addon`.
- Mixins and events
  - Common pattern: `local Self = Mixin(Addon.<Module>, CallbackRegistryMixin)` with `Self.Event` and `Self:TriggerEvent`.
- Functions and data
  - Method style: `function Self:MethodName(...)`.
  - Tables and constants in `Constants.lua` are treated as read-only config.
- Formatting
  - 4-space indentation, no trailing semicolons.
  - Local bindings at top of file: `local Name = ...`, `local Addon = select(2, ...)`.
- UI helpers
  - GUI module provides `InsertElement`, `InsertButton`, `InsertFontString`, etc. Prefer these for UI consistency.

## Practical guidance for agents

- Respect TOC load order when adding files or new modules; update [TestFlight.toc](TestFlight.toc) accordingly.
- When adding Settings UI, use [src/Options.lua](src/Options.lua) helpers to keep consistent callbacks and proxy settings.
- When integrating with optional addons, gate behavior on availability checks and follow existing patterns in `Prices.SOURCES`.
- For new UI frames, prefer XML templates under `src/gui/**/frames` and add a Lua mixin in the matching `mixins` folder.
- Upstream source and release info lives on CurseForge, with source mirror at https://gitlab.com/shrugal/testflight.
- A documentation of the World of Warcraft API can be found at https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
