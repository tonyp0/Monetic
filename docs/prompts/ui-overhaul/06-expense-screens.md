# Step 6: Category Detail, Add Expense, Edit Expense

Rework the screens where expenses are viewed and entered.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first. This step covers `CategoryDetailView`, `AddTransactionView` and `EditTransactionView`.

## Read first

- `Monetic/Views/CategoryDetailView.swift`, `AddTransactionView.swift`, `EditTransactionView.swift`
- `AmountEntryCard` and `BrandField` in `Monetic/DesignSystem/BrandComponents.swift`
- `AmountInput` in `Monetic/Utilities/Formatting.swift`
- `MoneticUITests/AddExpenseUITests.swift` (it drives these screens)

## Category detail

- A standard inline nav title is enough; drop the duplicate header card. At the top, on the background: `CategoryTile` (56pt), the group name in `.title2`, and "**$24.50** this month · 3 expenses" in `.subheadline` (`groupMonthlySpent` on the amount). Toolbar: `Done` (plain) and the existing `…` menu as a plain SF Symbol.
- Expenses in one list, **sectioned by date** ("Today", "Yesterday", then "Mon 16 Nov"). Each row: title = the note, falling back to the group name (**never "Expense"**); a secondary line with "Repeats monthly" or "Repeats yearly" when recurring (with a small `arrow.triangle.2.circlepath` symbol); the amount trailing and `.monospacedDigit()`. Keep swipe-to-delete and tap-to-edit.
- Empty state: "No expenses in this group yet." plus a button.
- The bottom "Add expense" button becomes `PrimaryButtonStyle` with no gradient or glow, and keeps its `addExpenseButton` identifier.

## Add expense / Edit expense

Make these one calm page instead of three stacked cards:

1. **Amount** at the top on the background, centred: currency symbol in `textSecondary` and the number in `Brand.hero`, auto-focused on appear (Add only). Keep the existing hidden-field focus mechanics and the `amountField` identifier, since the UI tests depend on them. Placeholder `0` in `textTertiary`.
2. **Group**: a horizontally scrolling row of chips (`CategoryTile` at 28pt plus the name, `Radius.small`). The selected chip gets the group's colour tint and a 1.5pt border in the group colour; unselected chips sit on `surfaceSunken`. Show full names, no truncation ("Entertain…" is not acceptable): chips size to their content and the row scrolls. Scroll the preselected or newly selected group **fully** into view with some leading margin (`ScrollViewReader` / `.scrollPosition`). In the step-0 shots a selected chip ended up half off the left edge.
3. **Details**: one grouped `surface` block with plain rows — Date (compact `DatePicker`), Note ("What was it for?"), and Repeats (Never / Monthly / Yearly as a menu picker).
4. Toolbar: plain `Cancel`, and plain `.semibold` `Save` (`saveExpenseButton`, still visible text "Save"), disabled until the amount is valid and a group is chosen.
5. Edit expense shares the same layout. Factor out a shared `ExpenseForm` view used by both if that removes real duplication, and add it to the app target. Delete lives at the bottom of Edit as a `danger` text button with a confirmation dialog.
6. Haptic (`.sensoryFeedback(.success, …)`) on save.

## Done when

- `scripts/test.sh` and `scripts/test.sh ui` pass. Update UI-test selectors only where the structure changed, and list each change.
- `scripts/screenshots.sh step6`: check these screens in both modes and at an AX Dynamic Type size, with the keyboard up and down. Long group names and long notes must wrap or scroll, never clip.
