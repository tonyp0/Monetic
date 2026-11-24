# Step 4: Home Screen

Rebuild the main screen around one clear sentence, one bar and one list.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first. This step restructures the home screen. The trend chart is step 5; leave it in place, just restyled to fit.

## Read first

- `Monetic/Views/ContentView.swift`: `ContentView` (a `List` with `.brandListRow()`), `BudgetHeroCard`, `GroupCard`, `NoGroupsCard`, the toolbar, the sheets and `checkMonthRollover()`.
- `Monetic/Views/SpendingChartsView.swift`: the donut ("By group") and the daily bar chart.
- `Monetic/Models/Category.swift`: `monthlySpending(asOf:)`.

## Target layout (top to bottom)

1. **Navigation**: a large native title with the current month name ("November"; add the year only when it isn't the current year). Toolbar: gear (`settingsButton`) on the left, and `Edit` (plain text, for reorder and delete) on the right. Remove the gradient `MONETIC` wordmark from the toolbar.
2. **Hero** (no card, sitting on the background):
   - "You have" in `.title3` / `textSecondary`, then the remaining amount in `Brand.hero` (`.contentTransition(.numericText())`), then "left for November" in `.title3` / `textSecondary`. Keep it one readable sentence for VoiceOver (`.accessibilityElement(children: .combine)`).
   - Under it, one line in `.subheadline`: "About **$X a day** for the next N days." When over budget, show "You're **$X over** your budget this month." in `danger`. With no budget set, replace the hero with "Set a budget for November" and a `PrimaryButtonStyle` button that opens the existing set-budget sheet.
   - `BudgetBar` split by group colour (from step 3), showing spending per group against the whole budget.
   - A compact legend row: "Spent $X" · "Budget $Y" in `.footnote`. Tapping "Budget" opens the set-budget sheet (it replaces the old sliders button). These texts must keep the `spentTotal` and `budgetTotal` identifiers; update the identifier code if the label text changes.
3. **Groups**: one `Section` in an `.insetGrouped`-style list on `surface`, with `Radius.large` corners and `hairline` dividers, replacing seven separate cards. Header: "Groups" in `.headline`, with a plain "Add group" button (`addGroupButton`) at the trailing edge. Each row:
   - `CategoryTile` (36pt), the name in `.body`, and a secondary line: "3 expenses" or, when the group has spending, a thin per-group progress hint only if that's meaningful (no per-group budgets exist today, so don't invent one).
   - Amount trailing in `.body` `.monospacedDigit()`. $0 groups show the amount in `textTertiary`.
   - Keep the native chevron and the tap → category detail sheet. Keep swipe-to-delete and Edit-mode reorder working.
   - Order rows as the user arranged them (don't sort by amount).
4. **Spending trend**: leave `SpendingChartsView` below the groups for now, but **remove the donut entirely** (the split bar replaces it) and remove the collapsible "Spending Overview" header. Step 5 rebuilds the remaining chart.
5. **Add expense**: a floating **"Add expense"** button pinned bottom-centre over the list (`PrimaryButtonStyle`, capsule, soft neutral shadow). It replaces the toolbar `+`, so it carries that button's `addTransactionButton` identifier. Add bottom content inset so the last row isn't hidden behind it.
6. **Empty state** (no groups): restyle `NoGroupsCard` as a centred message plus one button ("Add your first group"), with no card.

## Notes

- Compute days remaining and the per-day amount in a small pure helper (for example in `Formatting.swift` or a new `BudgetMath.swift`) and **unit-test it**: mid-month, last day of month, over budget, zero budget, and December.
- Keep `checkMonthRollover()` and all sheet presentation logic unchanged.
- Remove `BudgetRing` and the donut code once unused. Delete dead code rather than leaving it commented out.

## Done when

- Unit tests (including the new helper tests) and UI tests pass. Update UI tests only where the structure genuinely changed (for example the add button moved), and list those changes.
- `scripts/screenshots.sh step4`: home looks right in both modes, with zero, partial and over-budget spending. Temporarily tweak the seed to check over-budget, then revert the tweak. Also check at the largest Dynamic Type size (`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL`) that nothing clips or overlaps.
