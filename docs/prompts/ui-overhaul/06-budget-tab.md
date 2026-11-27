# Step 6: Budget Tab

Rebuild the budget screen around one question: how much can I spend this month while still saving for my trip?

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first. This step restructures the Budget tab (`ContentView` and `SpendingChartsView`). **Trip savings are money set aside, never spending**: this step must not change any budget or savings numbers.

## Read first

- `Monetic/Views/ContentView.swift`: the `List`, `BudgetHeroCard`, `GroupCard`, `NoGroupsCard`, the toolbar, the sheets, `checkMonthRollover()`, and the upcoming-trip card added by Trips prompt 3.
- `Monetic/Views/SpendingChartsView.swift`: the donut and the daily bar chart.
- `Monetic/Models/Category.swift` (`monthlySpending(asOf:)`), `SavingsPlan`, and `SavingsContributionTests` (they prove contributions don't change budget totals).

## Context from the step-0 screenshots

- Scrolled content shows through behind the top bar (chart bars and donut run under the toolbar), and the tab bar covers the last group rows and the chart legend. Fix both here.

## Target layout (top to bottom)

1. **Navigation**: large title with the month ("November"; add the year only when it isn't the current year). Toolbar: gear (`settingsButton`) on the left, and plain `Edit` (reorder and delete groups) on the right. Remove the `MONETIC` wordmark. Use standard scroll-edge behaviour (`.toolbarBackground` with `Brand.background` once content scrolls under) so nothing shows through.
2. **Hero** (no card):
   - "You have" (`.title3`, `textSecondary`), the remaining amount in `Brand.hero` with `.contentTransition(.numericText())`, then "left for November" (`.title3`, `textSecondary`), read as one sentence by VoiceOver.
   - One line in `.subheadline`: "About **$X a day** for the next N days." Over budget: "You're **$X over** your budget this month." in `danger`. No budget set: replace the hero with "Set a budget for November" plus a primary button that opens the existing set-budget sheet.
   - `BudgetBar` split by group colour, then "Spent $X · Budget $Y" in `.footnote`. These keep the `spentTotal` and `budgetTotal` identifiers (update the identifier code if the label text changes). Tapping "Budget" opens the set-budget sheet.
3. **Saving for trips** (replaces the Trips-3 dashboard card; only when there's an upcoming trip). A compact `surface` row or small section:
   - Flag, "Cancún · 108 days", and "Put aside **$42 this week**" (the plan's per-period amount), with a small `StatusChip`.
   - A plain **Add** button opening the add-to-savings sheet, and a tap on the row switching to the Trips tab and opening that trip, exactly as the Trips-3 card does today.
   - With several upcoming trips, show the soonest and a "+2 more" link to the Trips tab.
   - Below it, one honest line in `.footnote` when the plan doesn't fit: "Your trip savings are more than what's left this month." Compute this in a pure, tested helper from the remaining budget and the plan's monthly-equivalent amount. Show it only when true, and never change the hero numbers.
4. **Groups**: one grouped `List` section on `surface` with `Radius.large` corners and `hairline` dividers, replacing the separate cards. Header "Groups" with a plain **Add group** (`addGroupButton`). Rows: `CategoryTile` (36pt), name, "3 expenses", trailing amount `.monospacedDigit()` ($0 in `textTertiary`), native chevron → category detail. Swipe-to-delete and Edit-mode reorder keep working, in the user's order.
5. **How you're pacing**: replaces the donut (removed entirely, since the split bar replaces it) and the daily bars:
   - A Swift Charts `LineMark` of **cumulative** spending from day 1 to today in `accent` (`.monotone`, light `AreaMark` under it at about 12%), a dashed "on-track" line from $0 to the budget at month end in `textTertiary` (hidden with no budget), and a `RuleMark` at the budget labelled "Budget". Axes: days 1, 8, 15, 22 and the last day; currency with no cents; 3–4 `hairline` gridlines. A `PointMark` with today's total at the end of the line.
   - One sentence under it from a tested pure function: ahead of pace "You're spending a little faster than planned." (`warning`); within ±5% "Right on track." (`positive`); behind "Nice, you're under your plan so far." (`positive`); over "You've gone over your budget this month." (`danger`).
   - Show only with expenses on at least 2 distinct days; otherwise "Your spending trend shows up here after a few days."
   - Chart accessibility: a summary label plus `.accessibilityChartDescriptor`.
6. **Add expense**: a floating **Add expense** button (`PrimaryButtonStyle`, capsule, soft neutral shadow) positioned **above the tab bar**, replacing the toolbar `+` and carrying its `addTransactionButton` identifier. Add bottom content inset so everything scrolls clear of it and the tab bar.
7. **Empty state** (no groups): a centred line plus **Add your first group**, with no card.

## Notes

- Put days-left and per-day amount, the cumulative series builder, and the pace verdict in pure helpers with unit tests: mid-month, last day, over budget, zero budget, December, recurring expenses on their day, days with no spending carrying forward.
- Keep `checkMonthRollover()` and all sheet logic unchanged. Delete dead code (`BudgetRing` budget use, donut, `DailySpend` if unused) rather than commenting it out. `ProgressRing` stays for trips.

## Done when

- Budget and savings numbers are unchanged (existing tests pass, including `SavingsContributionTests`); new helper tests pass; UI tests pass, with any selector changes listed.
- `scripts/screenshots.sh step6`: Budget tab with zero, partial and over-budget spending (tweak the seed temporarily, then revert), with and without an upcoming trip, in both modes and at an AX size, with nothing hidden under the toolbar, floating button or tab bar.
