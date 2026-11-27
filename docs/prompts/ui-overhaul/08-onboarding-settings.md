# Step 8: Onboarding, Set Budget, Settings, Groups

The first five minutes and the remaining screens. Onboarding should sell the trip idea and get a student to their first plan.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first, especially **What Monetic is** and **Voice**. This step covers `OnboardingView`, `SetBudgetView`, `SettingsView`, `AddCategoryView`, `EditCategoryView` and `StoreUnavailableView`.

## Read first

- Those files in `Monetic/Views/` and `MoneticApp.swift`.
- How onboarding finishes (`hasCompletedOnboarding`, `saveAndContinue()`), and how the app lands on the Trips tab afterwards (step 4).
- The starter groups (`defaultCategories`) and every test that depends on them (unit tests iterate over the starter list; UI tests use "Food & Dining").
- UI tests that drive onboarding and the budget sheet: "Get Started", "Save Budget", `staticTexts["0"]`, `budgetAmountField`, `getStartedButton`, `saveBudgetButton`.

## Onboarding

Keep it to a few short screens with a page indicator:

1. **Welcome**: the logo mark (the one place the gradient appears), "Monetic" in `.largeTitle`, then one line: "Know what your next trip costs, save for it, and bring your friends." **Get Started** (same text and identifier).
2. **Starter groups**: "What do you usually spend on?" with a two-column grid of selectable tiles (`CategoryTile` plus name, checkmarks) and "You can change these any time." Revise the starter list for college students, for example Rent & Bills, Groceries, Food & Dining, Going Out, Transport, School & Books, Subscriptions, Shopping, Travel. **Keep "Food & Dining" and "Travel"** (tests use the first; the Trips estimate-vs-actual feature reads the second). Update the unit tests that iterate the starter list in this same step. Every tile must be reachable: in the step-0 shots, the button overlapped the 7th row and the last groups were hidden. Put the button in a bottom `safeAreaInset` so the grid scrolls clear of it, and let the last row visibly cut off at the fold so it's clear the list scrolls.
3. **Monthly budget**: the set-budget screen below, as an onboarding page.
4. **First trip** (new, last): "Got a trip in mind?" with "Spring break, study abroad, a weekend away. See what it'll cost." Then **Plan a trip** (primary; finishes onboarding and opens Add Trip on the Trips tab) and **Maybe later** (plain; finishes onboarding on the Trips empty state). Give both identifiers (`onboardingPlanTripButton`, `onboardingSkipTripButton`) and update the UI tests that complete onboarding.

Keep the existing data-saving behaviour (`saveAndContinue()` and the onboarding flag); only the screens and the final routing change.

## Set budget

- Flat background, plain `Cancel` when dismissible. Title in `.title2`: "How much can you spend in November?" and a hint in `.subheadline` / `textSecondary`: "Count everything: rent, food, going out. Trip savings come out of this too."
- The big amount in `Brand.hero`, centred. Keep the tap-to-focus behaviour and the visible `"0"` the UI test taps.
- When `lastMonthlyBudget > 0`, a quiet suggestion chip: "Use last month's $450".
- **Save Budget** (`PrimaryButtonStyle`, same text and identifier) pinned above the keyboard, disabled until valid.

## Settings

- Grouped sections on `surface`: **Appearance** (the segmented selector from steps 1 and 3), **Currency**, **Budget** (repeat-monthly toggle, this month's budget), **Trip reminders** (if Trips 3 added a global setting; otherwise skip), and **About** (logo mark, version, one line: "Monetic helps you afford the trips you want.", plus the cost-data source and its effective date from the bundled data, if present).
- Sentence-case section headers in `.subheadline` / `textSecondary`, footers for explanations. Plain `Done`.

## Add group / Edit group

- A live preview at the top: `CategoryTile` (56pt) and the name as typed.
- Name field, then an emoji picker grid, then a row of 9 colour swatches (28pt circles; the selected one gets a 2pt `textPrimary` ring and a checkmark), using the step-2 palette and keeping the stored keys.
- Plain `Cancel`, `.semibold` `Save` (`saveGroupButton`). Delete group (Edit only) at the bottom as a `danger` text button, with a confirmation that says how many expenses will be deleted with it.

## Also

- Restyle `StoreUnavailableView` in `MoneticApp.swift` to match.
- By the end of this step, nothing in `Monetic/` uses a deprecated `Brand` API. Remove the deprecated aliases, `brandEyebrow`, the `BudgetRing` typealias, `GradientButtonStyle` and other dead component code, and confirm the build has **zero** deprecation warnings from our own code.

## Done when

- All tests pass, with starter-list and onboarding test changes listed.
- `scripts/screenshots.sh step8`: every onboarding page, set budget, settings and the group screens in both modes. Put `before` and `step8` side by side and write a short screen-by-screen before/after note.
