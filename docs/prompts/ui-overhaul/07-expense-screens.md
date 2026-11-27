# Step 7: Category Detail, Add Expense, Edit Expense

Rework the screens where everyday spending is viewed and entered, so logging an expense takes seconds.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first. This step covers `CategoryDetailView`, `AddTransactionView` and `EditTransactionView`.

## Read first

- `Monetic/Views/CategoryDetailView.swift`, `AddTransactionView.swift`, `EditTransactionView.swift`
- `AmountEntryCard` and `BrandField` in `Monetic/DesignSystem/BrandComponents.swift`
- `AmountInput` in `Monetic/Utilities/Formatting.swift`
- The add-to-savings sheet from step 5: Add Expense should share its amount-entry pattern.
- `MoneticUITests/AddExpenseUITests.swift` (it drives these screens)

## Category detail

- A standard inline nav title is enough; drop the duplicate header card. At the top, on the background: `CategoryTile` (56pt), the group name in `.title2`, and "**$24.50** this month · 3 expenses" in `.subheadline` (`groupMonthlySpent` on the amount). Toolbar: plain `Done` and the existing `…` menu as a plain SF Symbol.
- Expenses in one list, **sectioned by date** ("Today", "Yesterday", then "Mon 16 Nov"). Row title is the note, falling back to the group name (**never "Expense"**). The secondary line says "Repeats monthly" or "Repeats yearly" when recurring, with a small `arrow.triangle.2.circlepath` symbol. Amount trailing, `.monospacedDigit()`. Keep swipe-to-delete and tap-to-edit.
- Empty state: "Nothing here yet this month." plus a button.
- The bottom **Add expense** button becomes `PrimaryButtonStyle` with no gradient or glow, keeping `addExpenseButton`.

## Add expense / Edit expense

One calm page instead of three stacked cards:

1. **Amount** at the top on the background, centred: currency symbol in `textSecondary`, number in `Brand.hero`, auto-focused on appear (Add only). Keep the existing hidden-field focus mechanics and the `amountField` identifier, which the UI tests depend on. Placeholder `0` in `textTertiary`.
2. **Group**: a horizontally scrolling row of chips (`CategoryTile` at 28pt plus the name, `Radius.small`). The selected chip gets the group's tint and a 1.5pt border in the group colour; unselected chips sit on `surfaceSunken`. Show full names, never truncated ("Entertain…" isn't acceptable): chips size to their content and the row scrolls. Scroll the preselected or newly selected chip **fully** into view with some leading margin (`ScrollViewReader` / `.scrollPosition`); in the step-0 shots a selected chip ended up half off the left edge.
3. **Details**: one grouped `surface` block with plain rows: Date (compact `DatePicker`), Note ("What was it for?"), Repeats (Never / Monthly / Yearly as a menu picker).
4. Toolbar: plain `Cancel`, and plain `.semibold` `Save` (`saveExpenseButton`, visible text still "Save"), disabled until the amount is valid and a group is chosen.
5. Edit expense shares the layout. Factor out a shared `ExpenseForm` if it removes real duplication (add it to the app target). Delete sits at the bottom of Edit as a `danger` text button with a confirmation dialog.
6. `.sensoryFeedback(.success, …)` on save.

## Don't

- Add anything trip-related to these screens (no "is this for a trip?" toggle). Per the brief, Monetic doesn't track in-trip spending.

## Done when

- `scripts/test.sh` and `scripts/test.sh ui` pass. Update UI-test selectors only where the structure changed, and list each change.
- `scripts/screenshots.sh step7`: these screens in both modes and at an AX Dynamic Type size, with the keyboard up and down. Long group names and long notes wrap or scroll, never clip.
