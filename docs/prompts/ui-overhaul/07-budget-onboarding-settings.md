# Step 7: Set Budget, Onboarding, Settings, Groups

The remaining screens, so the whole app speaks one visual language.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first. This step covers `SetBudgetView`, `OnboardingView`, `SettingsView`, `AddCategoryView` and `EditCategoryView`.

## Read first

- Those five files in `Monetic/Views/`
- `MoneticApp.swift` (`StoreUnavailableView` also needs restyling)
- UI tests that drive onboarding and the budget sheet (they match "Get Started", "Save Budget", `staticTexts["0"]`, `budgetAmountField`, `getStartedButton`, `saveBudgetButton`)

## Set budget

- Flat background. A plain `Cancel` in the toolbar (when dismissible). Title in `.title2`: "How much can you spend in November?" Then a hint in `.subheadline` / `textSecondary`: "Include everything: snacks, games, gifts, bus fare."
- The big amount in `Brand.hero`, centred. Keep the tap-to-focus behaviour and the visible `"0"` placeholder text the UI test taps.
- When `lastMonthlyBudget > 0`, show a quiet suggestion chip: "Use last month's $450".
- A `PrimaryButtonStyle` "Save Budget" pinned above the keyboard (same text and identifier), disabled until valid.

## Onboarding

- Screen 1: the logo mark (the one place the gradient appears), then "Monetic" in `.largeTitle`, and one line: "See where your money goes, and make it last all month." Then the "Get Started" primary button (same text and identifier).
- Screen 2 (choose starter groups): a two-column grid of selectable tiles (`CategoryTile` plus name) with checkmarks, showing "You can change these any time." Every starter group must be reachable: in the step-0 shots the button area overlapped the 7th row and Travel and Work were hidden with no sign the list scrolls. Keep the button in a bottom `safeAreaInset` so the grid scrolls clear of it, and make sure the last row is visibly cut off at the fold or otherwise clearly scrollable. Restyle within the existing flow; don't add or remove steps unless the current flow already has them.
- Add a simple page indicator if there's more than one screen.

## Settings

- Native-feeling grouped sections on `surface`: **Appearance** (the restyled segmented selector from steps 1 and 3), **Currency**, **Budget** (repeat monthly toggle, this month's budget), and **About** (logo mark, version, one-line description).
- Section headers in sentence case `.subheadline` / `textSecondary` (no all-caps), and footers for explanations.
- Plain `Done` in the toolbar.

## Add group / Edit group

- A live preview at the top: `CategoryTile` (56pt) plus the name as typed.
- Name field, then an emoji picker grid, then a colour row of 9 swatch circles (28pt, the selected one with a 2pt ring in `textPrimary` and a checkmark). Use the step-2 palette and keep the stored keys.
- Plain `Cancel` and `.semibold` `Save` (`saveGroupButton`). Delete group (Edit only) at the bottom as a `danger` text button with a confirmation that says how many expenses will be deleted with it.

## Also

- Restyle any **Trips** screens that exist so far (tab bar included) with the same tokens and components. Don't change their behaviour or layout structure, and leave Trips features that aren't built yet alone. Add them to the screenshot tour if they aren't in it.

- Restyle `StoreUnavailableView` in `MoneticApp.swift` to match.
- By the end of this step, nothing in `Monetic/Views` should use a deprecated `Brand` API. Remove the deprecated aliases, `brandEyebrow`, `BudgetRing`, the `GradientButtonStyle` typealias and any other dead component code, and confirm the build has **zero** deprecation warnings from our own code.

## Done when

- All tests pass.
- `scripts/screenshots.sh step7`: every screen in both modes. Put `before` and `step7` side by side and write a short screen-by-screen before/after note in your summary.
