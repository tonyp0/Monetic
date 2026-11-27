# Step 9: Polish and Accessibility

Make it feel finished, and make sure every student can use it.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first, especially **Motion and feel**. This is a sweep across the whole app, Trips and Budget alike. Don't restructure layouts.

## Motion and feedback

- `.contentTransition(.numericText())` on every amount or count that can change while visible: budget hero, spent and budget totals, group totals, category header, trip saved amount, countdown and estimate total.
- `ProgressRing` and `BudgetBar` animate their fill with `.smooth`.
- Insert and delete animations on list rows (`.snappy`). Sheets use default system presentation.
- `.sensoryFeedback`: `.success` on saving an expense, group, budget, trip or contribution; `.impact(weight: .light)` on chip, swatch and travel-style selection; `.warning` the moment a save pushes the month over budget; a distinct success when a trip becomes fully funded.
- Under `@Environment(\.accessibilityReduceMotion)`, replace movement with fades or nothing.

## Accessibility audit

Check and fix each item:

1. **Dynamic Type**: run the screenshot tour at `UICTContentSizeCategoryAccessibilityXXXL`. Fix clipping, truncation and overlap. Rows may switch to vertical with `ViewThatFits` or a `dynamicTypeSize` check. Hero numbers (countdown, remaining, saved) may scale down with `.minimumScaleFactor(0.6)` but never truncate.
2. **VoiceOver**:
   - Every control is meaningfully labelled (gear → "Settings", `…` → "More options", `+` on Trips → "Plan a trip").
   - The next-trip hero reads as one sentence: "Cancún, spring break, 108 days to go. $412 saved of $640. Behind plan. Save $102 this week to catch up."
   - Group rows read "Food and Dining, $24.50 this month, 3 expenses". The ring and bar read their percentage and status.
   - The estimate breakdown reads each line and the source footnote. Flag emoji are hidden when the country is read anyway; decorative tiles are hidden when the name is read.
3. **Contrast**: re-run the step-2 contrast check against the final tokens, including `StatusChip` text on its tint in both modes.
4. **Tap targets**: everything tappable is at least 44×44pt (swatches, chips, toolbar icons, stepper).
5. **Colour isn't the only signal**: status is always a word too (chips, over-budget, behind plan).
6. **Bold Text and Increase Contrast**: check both. With Increase Contrast, raise `hairline` and `textSecondary` contrast (consider `@Environment(\.colorSchemeContrast)` in the adaptive colour helper).
7. **Localised formatting**: dates and currency use the user's locale everywhere, including the countdown and date ranges ("Mar 14–21" via `Date.FormatStyle` / `formatted(.interval)`, not string concatenation).
8. Add launch arguments to the screenshot tour for an AX size and for Increase Contrast, so these checks are repeatable.

## Done when

- All tests pass.
- `scripts/screenshots.sh step9` (normal, AX size, increased contrast) shows no clipping or overlap. List every issue you found and how you fixed it.
