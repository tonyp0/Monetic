# Step 10: Docs, App Store Previews, Final Sweep

Make the docs and store previews tell the new story (trips first), and catch anything inconsistent.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first, especially **What Monetic is** and **What it's not**.

## Do

1. **Consistency sweep**: grep `Monetic/` for leftovers and fix them, keeping each fix minimal:
   - hard-coded colours (`Color(hex:`, `.red`, `.blue`, `.gray`, `Color.white` / `.black` outside tokens) and fixed font sizes (`.system(size:`) outside `Brand.swift` and `@ScaledMetric` uses
   - any `.uppercased()`, `.textCase(.uppercase)`, `.tracking(` or `.kerning(`
   - any gradient outside the logo mark
   - corner radii that aren't `Radius.small` or `Radius.large`
   - shadows on anything that doesn't float
   - any ring used for something other than trip savings
   - copy in Title Case or label-speak, leftover K–12 or kid-oriented wording, "Expense" as a fallback title, and any estimate shown without its source line
   - anything that drifts into the brief's "What it's not" list (in-trip spending, bill splitting, itineraries)
2. **README**: rewrite the intro and "What The App Does" / "Why It Was Made" around the new positioning: who it's for, the problem, what it does (estimate from cited data, savings plan inside the budget, countdown, plan with friends), what makes it different, and what it's not. Remove the K–12 framing. Rewrite the "Design System" section for the new direction (travel notebook, system appearance by default, one accent, ring for trip savings only, gradient for the logo only) and link to `docs/prompts/ui-overhaul/DESIGN-BRIEF.md`. Keep the tech-stack and testing sections accurate, and mention the cost-data source and where it's documented.
3. **App Store previews**: regenerate `Marketing/AppPreviews/` from the screenshot tour, leading with trips. Suggested order: 01 Trips home (next trip hero), 02 Trip cost estimate with source, 03 Savings plan, 04 Join a friend's trip (if sharing exists), 05 Budget tab with "Saving for trips", 06 Pacing chart, 07 Add expense, 08 Onboarding. Use the light set by default and add dark variants of 01 and 05 if they look good. Delete previews that no longer exist, and update every README image reference.
4. **Final check**: run `scripts/test.sh all` and `scripts/screenshots.sh final`.

## Done when

- Tests pass, the sweep's grep checks come back clean (or every remaining hit is justified in the summary), the README tells the trips-first story, and the previews are updated.
- Summarise the whole overhaul: before and after for each screen, files touched, tests added or changed, and suggested follow-ups (for example a home-screen widget showing the trip countdown, or Live Activities near departure).
