# UI Overhaul — Step-by-Step Prompts

A sequence of prompts for redesigning Monetic's interface with Claude Code, one reviewable step at a time.

## How to use

1. Start Claude Code from the repo root on a Mac with Xcode (the steps build and run the app in the simulator).
2. Run the prompts **in order**, one per session (or `/clear` between them). Each prompt is everything below the `---` line in its file. You can paste it, or just say:

   > Follow the prompt in `docs/prompts/ui-overhaul/02-design-tokens.md`

3. After each step: look at the screenshots it produces, run the app yourself, and commit before moving on. Every step leaves the app building, with tests passing, so you can stop at any point.

Every prompt tells Claude to read [`DESIGN-BRIEF.md`](DESIGN-BRIEF.md) first. That file is the shared source of truth for the visual direction, so if you want to change a decision (a colour, a radius, a rule), change it there once.

## The steps

| # | Prompt | What changes | Size |
|---|---|---|---|
| 0 | [`00-screenshot-harness.md`](00-screenshot-harness.md) | A UI test that seeds demo data and screenshots every screen in light and dark. It provides the "before" images and is reused after each later step. | S |
| 1 | [`01-system-appearance.md`](01-system-appearance.md) | Appearance follows iOS by default, and the selector lists System first. | XS |
| 2 | [`02-design-tokens.md`](02-design-tokens.md) | New colours, category palette, type scale, radii. Same token names, so every screen changes at once. | M |
| 3 | [`03-components.md`](03-components.md) | Flat background, quieter cards, solid buttons, no all-caps labels, `BudgetBar` replaces the ring. | M |
| 4 | [`04-home-screen.md`](04-home-screen.md) | Home restructured: sentence hero, one split bar, one grouped list, floating Add button. | L |
| 5 | [`05-spending-trend.md`](05-spending-trend.md) | Daily bars become a running-total line with an on-track pace line. | M |
| 6 | [`06-expense-screens.md`](06-expense-screens.md) | Category detail, Add Expense and Edit Expense. | L |
| 7 | [`07-budget-onboarding-settings.md`](07-budget-onboarding-settings.md) | Set Budget, Onboarding, Settings, and Add/Edit Group. | L |
| 8 | [`08-polish-accessibility.md`](08-polish-accessibility.md) | Motion, haptics, Dynamic Type, contrast, VoiceOver, Reduce Motion. | M |
| 9 | [`09-docs-and-marketing.md`](09-docs-and-marketing.md) | README Design System section, App Store previews, and a final consistency sweep. | S |

Steps 2 and 3 do most of the work of removing the "generic AI app" look. Steps 4–7 are where the app starts to feel designed.
