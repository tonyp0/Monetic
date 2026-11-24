# Prompt 3: Savings Plan and Countdown

Paste everything below the line into Claude Code (or hand it to a developer) from the repo root.

---

You are adding the savings side of the Trips feature to **Monetic**, a SwiftUI + SwiftData iOS 17 budgeting app. Prompts 1 and 2 added a `Trip` model with an `estimatedTotal` (manual or from the per diem estimator) and a placeholder "Savings plan" section in `TripDetailView`. This task replaces that placeholder with the part that keeps people coming back every week: **how much to save, whether they're on track, and how long until they leave.**

## Read first

- `Monetic/Models/Trip.swift`, `Monetic/Views/TripDetailView.swift`, `TripsView.swift`.
- `Monetic/Models/Transaction.swift` and `Category.swift` — how spending and monthly totals work today.
- `Monetic/Views/ContentView.swift` — the dashboard hero card and month rollover.
- `Monetic/DesignSystem/BrandComponents.swift` — the budget ring and progress bars. The savings progress should reuse the **ring** so it feels like part of the same app.
- `MoneticTests/TestSupport.swift`.

## Ground rules

1. **Savings are not spending.** Money set aside for a trip must not count toward the monthly budget's "spent" total or change any existing category totals. Store contributions in their own model; do not reuse `Transaction`.
2. **All plan math is a pure, tested function** with an injected `asOf:` date and `Calendar`. No `Date()` in model or plan code.
3. **Be honest about the numbers.** If the trip is too close or the target too high to be realistic, say so plainly rather than showing an impossible monthly figure.
4. Design system only, `project.pbxproj` wiring for every new file, existing behavior and tests unchanged. Re-run the migration test with the new model.

## 1. Models

- `SavingsContribution` (`@Model`): `id`, `amount` (positive = deposit, negative = withdrawal), `date` (start of day), `notes`, `trip: Trip?`, `createdAt`. Cascade-delete from `Trip`.
- On `Trip` add: `savingsGoal: Double` (defaults to `estimatedTotal` per person, editable), `savingsStartDate: Date`, `contributionCadence: String` (`"weekly"` | `"biweekly"` | `"monthly"`).

## 2. The plan

File: `Monetic/Trips/SavingsPlan.swift`

`SavingsPlan.make(goal:, saved:, startDate:, departureDate:, cadence:, asOf:, calendar:) -> SavingsPlan` returning:
- `remaining` (never negative), `periodsLeft` (contribution dates strictly before departure), `perPeriodAmount` (rounded **up** to the cent so the goal is actually reached).
- `expectedSavedByNow` (straight-line from start date to departure) and `status`: `.ahead`, `.onTrack` (within 5% of expected), `.behind`, `.funded`, `.departed`.
- `isUnrealistic` when `periodsLeft == 0` with money remaining, or when the per-period amount is more than the user's whole `monthlyBudget` scaled to that cadence (read `monthlyBudget` as an input parameter; don't read `AppStorage` inside the function).
- A `catchUpAmount` for `.behind`: what the next contribution would have to be to get back on track.

## 3. UI

- Replace the placeholder in `TripDetailView` with a **savings card**: brand ring showing saved / goal, "$X saved of $Y", the per-period amount ("Save $42 a week"), status chip, and the countdown ("38 days to go").
- "Add to savings" button opens a sheet with the existing amount input, date (default today), and notes. Allow withdrawals via a toggle. List contributions newest first; swipe to delete or edit.
- Trip rows in `TripsView` gain a thin progress bar and the status chip.
- On the **Budget** dashboard, if there's an upcoming trip, show one compact card under the hero: trip name, countdown, this period's savings amount, and a button that opens the add-to-savings sheet. Tapping the card switches to the Trips tab and opens that trip. Hide the card when there are no upcoming trips. It must not change the hero card's numbers.
- When `isUnrealistic`, show a short warning with the two honest options: raise the per-period amount, or lower the goal / change dates.

## 4. Reminders (local notifications)

- Optional per trip, off by default: a reminder on each contribution date ("Spring Break: time to put $42 aside"). Request notification permission only when the user turns this on, never at launch.
- Schedule with `UNCalendarNotificationTrigger`; reschedule when the trip, cadence or goal changes; remove when the trip is deleted or fully funded. iOS limits pending local notifications to 64, so schedule only the next few per trip and top up when the app becomes active.
- Put scheduling behind a small protocol so tests can verify what would be scheduled without touching `UNUserNotificationCenter`.

## 5. Tests

- `MoneticTests/SavingsPlanTests.swift`: each cadence; start date in the past and future; departure tomorrow; fully funded; over-funded; withdrawals bringing it below goal; the ±5% on-track band; rounding up; `isUnrealistic`; month-length and DST boundaries.
- `MoneticTests/SavingsContributionTests.swift`: cascade delete with the trip; **contributions never change any `BudgetCategory.monthlySpending` or the dashboard total** (compute the total the way `ContentView` does).
- Reminder scheduling tests through the protocol: correct dates, cap respected, cleared on delete and when funded.
- UI test: create a trip, add a contribution, see the ring and the dashboard card update.

## Done when

- Saving toward a trip never alters monthly budget numbers (covered by a test).
- `scripts/test.sh` and `scripts/test.sh ui` pass.
- Notification permission is never requested unless the user enables reminders.
- Your final message lists: files changed, the status thresholds you used, how the dashboard card behaves with zero, one and several upcoming trips, and anything deferred.
