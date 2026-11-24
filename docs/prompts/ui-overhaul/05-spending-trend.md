# Step 5: Spending Trend Chart

Replace the mostly-empty daily bar chart with a chart that teaches pacing.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first. This step only touches the trend chart in `Monetic/Views/SpendingChartsView.swift` (and its placement in `ContentView.swift`).

## Read first

- `Monetic/Views/SpendingChartsView.swift`: `DailySpend` and the daily `Chart`.
- How `ContentView` passes data in.

## Do

1. A titled section, "How you're pacing", in the same list style as Groups (one `surface` block, no extra card inside).
2. A Swift Charts `Chart` with:
   - A `LineMark` (with a subtle `AreaMark` under it at about 12% opacity) of **cumulative** spending per day from day 1 to today, in `accent`. Use `.interpolationMethod(.monotone)`. Don't extend the line past today.
   - A dashed `RuleMark` or `LineMark` "on-track" line from $0 on day 1 to the full budget on the last day of the month, in `textTertiary`. Hide it when no budget is set.
   - A horizontal `RuleMark` at the budget amount, labelled "Budget", in `textSecondary`.
   - X axis: day of month at 1, 8, 15, 22 and the last day. Y axis: currency with no cents, 3–4 gridlines in `hairline`, trailing.
   - Point the line's end at today's total with a small `PointMark` and annotation ("$312").
3. Under the chart, one plain sentence in `.subheadline`, computed by a small tested pure function:
   - ahead of pace: "You're spending a little faster than planned." (`warning`)
   - on pace (within ±5% of the on-track value for today): "Right on track." (`positive`)
   - behind pace: "Nice, you're under your plan so far." (`positive`)
   - over budget: "You've gone over your budget this month." (`danger`)
4. Show the section only once there are expenses on at least 2 distinct days this month. Otherwise show a single line: "Your spending trend will show up here after a few days."
5. Accessibility: give the chart an `accessibilityLabel` summary and use `.accessibilityChartDescriptor` (or per-mark labels) so VoiceOver users get the same information.
6. Remove `DailySpend` and the bar chart code if they're no longer used, and unit-test the cumulative series builder (recurring expenses count on their day; days with no spending carry the previous total forward).

## Done when

- Tests pass, including the new pace and cumulative tests.
- `scripts/screenshots.sh step5`: the chart reads well in both modes with the seed data, and the empty-state line shows on a fresh install.
