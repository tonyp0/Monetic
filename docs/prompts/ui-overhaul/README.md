# UI Overhaul — Step-by-Step Prompts

A sequence of prompts for redesigning Monetic's interface with Claude Code, one reviewable step at a time.

## How to use

1. Start Claude Code from the repo root on a Mac with Xcode (the steps build and run the app in the simulator).
2. Run the prompts **in order**, one per session (or `/clear` between them). Each prompt is everything below the `---` line in its file. You can paste it, or just say:

   > Follow the prompt in `docs/prompts/ui-overhaul/02-design-tokens.md`

3. After each step: look at the screenshots it produces, run the app yourself, and commit before moving on. Every step leaves the app building, with tests passing, so you can stop at any point.

Every prompt tells Claude to read [`DESIGN-BRIEF.md`](DESIGN-BRIEF.md) first. That file is the shared source of truth for the visual direction, so if you want to change a decision (a colour, a radius, a rule), change it there once.

## Running order with the Trips prompts

Monetic is now trips-first (see "What Monetic is" in the brief), so the later overhaul steps redesign Trips screens and must run after those screens exist:

1. Overhaul **0–3** (screenshot tool, system appearance, tokens, shared components). Trips screens built after this pick up the new look automatically.
2. Trips prompts **1–3** (`docs/prompts/trips/`: trip model and tab, cost estimator, savings plan).
3. Overhaul **4–6** (Trips home, trip detail and planning, Budget tab).
4. Trips prompts **4–5** whenever they're ready (sharing, AI trip entry). If they land after step 5, re-run step 5's sections for them.
5. Overhaul **7–10**.

## The steps

| # | Prompt | What changes | Size |
|---|---|---|---|
| 0 | [`00-screenshot-harness.md`](00-screenshot-harness.md) | A UI test that seeds demo data and screenshots every screen in light and dark. | S |
| 1 | [`01-system-appearance.md`](01-system-appearance.md) | Appearance follows iOS by default, and the selector lists System first. | XS |
| 2 | [`02-design-tokens.md`](02-design-tokens.md) | New colours, category palette, type scale and radii, keeping the same token names. | M |
| 3 | [`03-components.md`](03-components.md) | Flat background, quieter cards, solid buttons, no all-caps labels, `BudgetBar`, `ProgressRing` (trip savings only) and `StatusChip`. | M |
| 4 | [`04-trips-home.md`](04-trips-home.md) | Trips becomes the first tab: next-trip hero with countdown and savings ring, trip list, empty-state pitch. Adds trips to the demo data and tour. | L |
| 5 | [`05-trip-detail-and-planning.md`](05-trip-detail-and-planning.md) | Trip detail, cost estimate with its source, Add/Edit Trip, Add to Savings, Join preview. | L |
| 6 | [`06-budget-tab.md`](06-budget-tab.md) | Budget tab: sentence hero, split bar, "Saving for trips", one group list, pacing chart. | L |
| 7 | [`07-expense-screens.md`](07-expense-screens.md) | Category detail, Add Expense and Edit Expense. | M |
| 8 | [`08-onboarding-settings.md`](08-onboarding-settings.md) | Trip-led onboarding, college starter groups, Set Budget, Settings, Add/Edit Group, dead-code cleanup. | L |
| 9 | [`09-polish-accessibility.md`](09-polish-accessibility.md) | Motion, haptics, Dynamic Type, contrast, VoiceOver, Reduce Motion. | M |
| 10 | [`10-docs-and-marketing.md`](10-docs-and-marketing.md) | README rewritten around trips, App Store previews led by trips, final sweep. | S |
