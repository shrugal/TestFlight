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

## Releases

- Changelog files
  - [CHANGES.md](CHANGES.md) holds the notes for the *next* release only. The packager ships it verbatim as the release description on every site (`manual-changelog` in [.pkgmeta](.pkgmeta)), so write it for players, not for developers.
  - [CHANGELOG.md](CHANGELOG.md) is the full history and always lags one release behind.
  - Append a bullet to the bottom of CHANGES.md in the same commit as the change itself.
  - In the first commit after a tag, move the CHANGES.md content into CHANGELOG.md as a new `Version <tag>` section at the top, then replace CHANGES.md with the entries for the next release. The tagged commit itself does not touch either file.
- Changelog writing style
  - See "Writing texts for humans" below, it applies here
  - Section format: `Version 5.13`, blank line, `- ` bullets, blank line before the next section. No markdown headings, no trailing periods.
  - Minor versions are zero-padded to two digits (`5.09`, `5.10`), major bumps use `.00` (`5.00`).
  - Imperative mood, capitalized: `Add ...`, `Fix ...`, `Improve ...`, `Update ...`, `Show ...`, `Make ...`, `Allow ...`, `Don't ...`. Older entries use past tense; don't copy that.
  - Order within a section: additions, then changes and improvements, then fixes, then `Internal: ...` bullets for refactors with no visible effect.
  - Describe the visible behavior, not the implementation: "Fix error on orders with invalid reagents", not "Add nil check in Orders:Validate".
  - Game patch compatibility bumps get their own bullet instead of being folded into another one, even when the release also contains other changes: `Update ToC version for patch 12.0.5`.
- Triggering a release
  - Releases are driven entirely by git tags pushed to `origin`, there is no manual upload step.
  - Tag names must match `^\d[\d\.]*(-(debug|alpha|beta)\d+)?$` (`5.13`, `5.14-beta1`, `5.00-alpha1`), otherwise the deploy jobs don't run.
  - The tag becomes the addon version: [TestFlight.toc](TestFlight.toc) carries `## Version: @project-version@`, which the packager substitutes. The `#@do-not-package@` block at the end of the TOC keeps local checkouts on `0-dev0`.
  - Release type follows the tag name: `alpha`/`debug` -> alpha, `beta`/`next`/`ptr` -> beta, anything else -> full release. An untagged build is always alpha.
- Cutting a release
  - ALWAYS ask before the final step (push) of a release, even when asked to create a release
  - Check that CHANGES.md covers every user-visible change since the last tag, in the style above.
  - Bump `## Interface:` in [TestFlight.toc](TestFlight.toc) if the release targets a new game patch.
  - Commit, tag that commit with the bare version number, and push both: `git push origin master --tags`.
  - Only increate the major version when specifically asked to, usually increase the minor version.
  - Watch the GitLab pipeline; the five deploy jobs publish to CurseForge, WoWInterface, Wago, GitHub and GitLab.
  - In the next commit, roll CHANGES.md into CHANGELOG.md under the tag just pushed.

## Practical guidance for agents

- Respect TOC load order when adding files or new modules; update [TestFlight.toc](TestFlight.toc) accordingly.
- When adding Settings UI, use [src/Options.lua](src/Options.lua) helpers to keep consistent callbacks and proxy settings.
- When integrating with optional addons, gate behavior on availability checks and follow existing patterns in `Prices.SOURCES`.
- For new UI frames, prefer XML templates under `src/gui/**/frames` and add a Lua mixin in the matching `mixins` folder.
- Upstream source and release info lives on CurseForge, with source mirror at https://gitlab.com/shrugal/testflight.
- A documentation of the World of Warcraft API can be found at https://warcraft.wiki.gg/wiki/World_of_Warcraft_API

## Writing texts for humans (comments, docs, changelogs)

- **Write complete sentences**, not parts stitched together with "-" or ";". No em dashes and no
  semicolons: a clause worth setting apart is worth its own sentence, and where the aside is a list,
  a colon does the job. En dashes stay in ranges (`4–20 minutes`, `Name A–Z`) — a dash is never a
  stand-in for a missing value ("Not known" says that instead).
- **Focus on what is or what should be done**. Don't explain the reason unless it's relevant for decisions
  the user has to make. Don't mention what potential alternatives have not been realized.
- **Don't list every option**, just the most relevant/common/likely ones.
- **Banned outright**, because they read as filler or as jargon a reader cannot act on: honest(ly),
  genuine(ly), load-bearing, footgun, blast radius, circuit breaker, gate(d), critical(ly), clean(ly),
  precise(ly), robust, seamless(ly), comprehensive(ly), bespoke, delve, nuanced, multifaceted, pivotal,
  leverage. Also banned as sentence frames: "measured rather than assumed", "shown rather than hidden",
  "worth noting", "important to remember", "exactly as designed".
