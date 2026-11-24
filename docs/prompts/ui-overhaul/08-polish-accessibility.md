# Step 8: Polish and Accessibility

Make it feel finished, and make sure every student can use it.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first, especially **Motion and feel**. This is a sweep across the whole app. Don't restructure layouts.

## Motion and feedback

- `.contentTransition(.numericText())` on every money amount that can change while visible (hero, spent, budget, group totals, category header).
- Insert and delete animations on list rows (`.snappy`). Sheets use default system presentation, with no custom bouncy transitions.
- `.sensoryFeedback`: `.success` on saving an expense, group or budget; `.impact(weight: .light)` on selecting a group chip or colour swatch; `.warning` the moment a save pushes the month over budget.
- Under `@Environment(\.accessibilityReduceMotion)`, replace movement with fades or no animation.

## Accessibility audit

Check and fix each item:

1. **Dynamic Type**: run the screenshot tour at `UICTContentSizeCategoryAccessibilityXXXL`. Fix clipping, truncation and overlap. Rows may switch to a vertical layout with `ViewThatFits` or a `dynamicTypeSize` check. The hero amount may scale down with `.minimumScaleFactor(0.6)`, but never truncate.
2. **VoiceOver**: every control has a meaningful label (gear → "Settings", `…` → "More options"). Group rows read as "Food and Dining, $24.50 this month, 3 expenses". The budget bar reads its percentage and state. Decorative emoji tiles are hidden from VoiceOver when the name is already read.
3. **Contrast**: re-run the step-2 contrast check against the final tokens, and verify `danger`, `warning` and `positive` text meets 4.5:1 on its actual background.
4. **Tap targets**: everything tappable is at least 44×44pt (swatches, chips, toolbar icons).
5. **Colour isn't the only signal**: over-budget states also use words or an icon, not just red.
6. **Bold Text and Increase Contrast**: check both settings. With Increase Contrast, raise `hairline` and `textSecondary` contrast (consider `@Environment(\.colorSchemeContrast)` in the adaptive colour helper).
7. Add UI-test launch arguments to the screenshot tour for an AX size and for Increase Contrast, so these checks are repeatable.

## Done when

- All tests pass.
- `scripts/screenshots.sh step8` (normal, AX size, increased contrast) shows no clipping or overlap. List every issue you found and how you fixed it.
