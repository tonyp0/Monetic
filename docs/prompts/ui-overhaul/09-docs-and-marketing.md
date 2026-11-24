# Step 9: Docs, App Store Previews, Final Sweep

Wrap up: make the docs match the app, refresh the previews, and catch anything inconsistent.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first.

## Do

1. **Consistency sweep**: grep `Monetic/` for leftovers and fix them:
   - hard-coded colours (`Color(hex:`, `.red`, `.blue`, `.gray`, `Color.white` / `.black` outside tokens), fixed font sizes (`.system(size:`), outside `Brand.swift` and `@ScaledMetric` uses
   - any `.uppercased()`, `.textCase(.uppercase)` or `.tracking(` / `.kerning(`
   - any gradient outside the logo mark
   - corner radii that aren't `Radius.small` or `Radius.large`
   - shadows on anything that doesn't float
   - copy in Title Case or label-speak, and anywhere "Expense" is still used as a fallback title

   Fix what you find, keeping each fix minimal.
2. **README**: rewrite the "Design System" section to describe the new direction (pocket notebook, system appearance by default, one accent, the token files, and the rule that the gradient is for the logo only). Remove "Dark is the mode the brand is tuned for and the default for new installs." Link to `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` as the design reference.
3. **App Store previews**: regenerate `Marketing/AppPreviews/01–08` from the screenshot tour, keeping the same filenames and screens. Use the light set by default, and add a dark variant for the dashboard if it looks good (`03-dashboard-dark.png`). Check the README image references still resolve.
4. **Final check**: run `scripts/test.sh all` and `scripts/screenshots.sh final`.

## Done when

- Tests pass, the sweep's grep checks come back clean (or every remaining hit is justified in the summary), the README matches the app, and the previews are updated.
- Summarise the whole overhaul: before and after for each screen, files touched, tests added or changed, and suggested follow-ups (for example per-group budgets, a widget, or localisation).
