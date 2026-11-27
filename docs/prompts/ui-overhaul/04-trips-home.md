# Step 4: Trips Home and App Structure

Make Trips the front door of the app: the first tab, opening on your next trip.

**Run this after Trips prompts 1–3** (trip model and tab, cost estimator, savings plan and countdown) are merged into this branch.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first, especially **What Monetic is**, **App structure**, **Components and patterns** and **Voice**. This step changes the tab structure and the Trips list. Trip detail and the trip forms are step 5, and the Budget tab is step 6.

## Read first

- The root view with the `TabView` (likely `RootView`), `MoneticApp.swift`, and where the onboarding cover lives now.
- `TripsView` and its row view, `Trip.swift`, the savings plan (`SavingsPlan`) and `SavingsContribution`.
- `Monetic/Utilities/DemoData.swift` and `MoneticUITests/ScreenTourUITests.swift` (from step 0).
- `Monetic/DesignSystem/BrandComponents.swift`: `ProgressRing`, `StatusChip`, `PrimaryButtonStyle` (from step 3).
- `MoneticUITests/TripsUITests.swift` and any other tests that switch tabs.

## 1. Extend the demo data and the tour first

- In `DemoData.swift`, seed **three trips** alongside the existing budget data, using the app's own models and plan code (no hand-computed totals):
  1. **Spring break in Cancún**, about 100 days out, 4 travelers, budget style, estimate from the bundled cost data if the location exists (otherwise a manual estimate marked as such), with weekly contributions making it slightly **behind** plan.
  2. **Summer study abroad in Lisbon**, about 7 months out, 1 traveler, standard style, **on track**.
  3. One **past** trip (a weekend road trip), fully funded.
- Add the Trips screens to `ScreenTourUITests` (light and dark): Trips list, Trips empty state (fresh install, after onboarding), and placeholders for trip detail, Add Trip and Add to Savings, which step 5 will style. Number them so the Trips shots sort first.
- Run `scripts/screenshots.sh step4-before` **before** changing any views, so this step has its own "before" set.

## 2. App structure

- **Tab order: Trips first, Budget second.** The app opens on Trips (including after onboarding). Use `Label("Trips", systemImage: "airplane")` and `Label("Budget", systemImage: "chart.bar")` or close equivalents. Keep the `tripsTab` identifier.
- Use the system tab bar styled with tokens: `background` behind it, selected item in `accent`, unselected in `textSecondary`. No custom floating tab bar, no blur gradient.
- Settings stays reachable from a plain gear toolbar button (`settingsButton`) on both tabs.
- Keep the onboarding cover over the tab bar exactly as it works now; step 8 restyles onboarding.
- If something on the Budget tab assumed it was the only screen (for example the month-rollover budget sheet appearing on launch), make sure it still triggers correctly when the app opens on Trips. Don't change its logic; just confirm and test it.

## 3. Trips list (`TripsView`)

Top to bottom:

1. **Large title "Trips"**. Toolbar: gear on the left, plain `+` (`addTripButton`) on the right.
2. **Next trip hero**, for the soonest upcoming trip, sitting on the background with no card:
   - The flag emoji (or `airplane` symbol) and the destination in `.title2`, then the trip name and dates in `.subheadline` / `textSecondary` ("Spring break · Mar 14–21").
   - The **countdown** as the hero: "**108** days to go", with the number in `Brand.hero`. Use "Tomorrow" for 1 and "Today" for 0. While the trip is in progress, show "Happening now" instead; never count negative days.
   - A `ProgressRing` (about 120pt) beside or below it, with "$X saved of $Y" in the centre or underneath, and a `StatusChip` (On track / Behind / Ahead / Funded).
   - One sentence with the next action, using the savings-plan numbers: "Save **$42 this week** to stay on track", or the catch-up amount when behind, or "Fully funded!" when done. If the plan is unrealistic, use the plan's honest wording and `warning` colour.
   - One `PrimaryButtonStyle` button: **Add to savings** (opens the existing add-to-savings sheet for that trip). Tapping anywhere else on the hero opens trip detail.
3. **Other upcoming trips**: one grouped `List` section on `surface`. Each row (`tripRow_<name>`): flag tile, destination and dates, then trailing "in 214 days" and a thin `BudgetBar`-style progress line for savings under the text. No ring in rows. Swipe to delete keeps its confirmation.
4. **Past trips**: a collapsed section ("Past trips · 3"), rows in `textSecondary`.
5. **Empty state** (no trips): no hero, no list. A short pitch centred on the screen:
   - "Where do you want to go?" in `.title2`
   - "Find out what it'll really cost, then save for it inside your budget." in `.body` / `textSecondary`
   - **Plan a trip** (`PrimaryButtonStyle`, same action as `addTripButton`; give it a different identifier, for example `emptyPlanTripButton`, if both are visible).

## Notes

- Countdown wording ("Today", "Tomorrow", "N days to go", "Happening now", past) goes in one small pure function with unit tests at the boundaries (departure day, day before, during, end day, after). Reuse `daysUntilDeparture(asOf:)` and `status(asOf:)` from `Trip`; don't duplicate the date maths.
- Reuse the savings plan's status and amounts. Don't recompute them in the view.
- Respect the brief's "What it's not": no itinerary, packing or in-trip spending hints anywhere on this screen.

## Done when

- The app opens on Trips, the Budget tab still works, and onboarding still covers everything on first launch.
- Unit and UI tests pass. Update tab-switching UI tests where needed, and list each change.
- `scripts/screenshots.sh step4` next to `step4-before`: the Trips list with three trips and the empty state look right in both modes, and at an AX Dynamic Type size the countdown and ring stack vertically instead of clipping.
