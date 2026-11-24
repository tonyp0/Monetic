# Prompt 1: Trip Model and Trips Tab

Paste everything below the line into Claude Code (or hand it to a developer) from the repo root.

---

You are adding the first piece of a trip-planning feature to **Monetic**, a SwiftUI + SwiftData iOS 17 budgeting app (`Monetic.xcodeproj`, scheme `Monetic`). Today the app is a single monthly-budget dashboard. This task adds a **Trips** area where someone can create a trip (destination, dates, an estimated total cost they type in) and see it in a list. Cost estimates and savings come in later prompts; build the foundation they will sit on, and nothing more.

## Read first

- `Monetic/MoneticApp.swift` — how the `Schema` and `ModelContainer` are built, the `-UITesting` in-memory path, and `resetSettingsForTesting()`.
- `Monetic/Models/Category.swift`, `Monetic/Models/Transaction.swift` — model conventions (`@Attribute(.unique) var id: UUID`, `createdAt`, string-backed enums like `recurringFrequency`).
- `Monetic/Views/ContentView.swift` — the root view: `NavigationStack`, sheets, and the onboarding `fullScreenCover` driven by `hasCompletedOnboarding`.
- `Monetic/DesignSystem/Brand.swift`, `BrandComponents.swift` — tokens, `BrandBackground`, `brandCard`, buttons, `BrandSectionHeader`, `BrandAmountField`-style inputs. Use these for every screen.
- `Monetic/Views/AddCategoryView.swift`, `EditTransactionView.swift` — the existing add/edit sheet patterns to copy.
- `Monetic/Utilities/Formatting.swift` — `Currency`, `AmountInput.sanitize/parse`.
- `MoneticTests/TestSupport.swift` — shared fixtures and the in-memory container helper.

## Ground rules

1. **Don't change existing behavior.** The monthly budget dashboard, onboarding, settings and all existing tests must behave exactly as before.
2. **Design system only.** Every new screen uses `Brand` tokens and `BrandComponents`. If a component you need doesn't exist, add it to `BrandComponents.swift` in the same style rather than styling inline.
3. **Schema change must be safe for existing users.** Adding a new `@Model` to the schema is a lightweight migration, but prove it: write a test that creates an on-disk store with only the old schema (`BudgetCategory`, `Transaction`) in a temp directory, inserts data, then reopens it with the new schema and confirms the old data is intact. Do not add a `VersionedSchema`/migration plan unless that test shows you need one.
4. **Project wiring:** this `.xcodeproj` does not use synchronized folders. Add every new `.swift` file to the `Monetic` (or test) target in `project.pbxproj`, then build to confirm.
5. **Testability:** keep logic out of views. Put validation and derived values (duration, days until departure) on the model or in a small pure helper that tests can call with fixed dates.

## 1. The `Trip` model

File: `Monetic/Models/Trip.swift`

```swift
@Model final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String            // "Spring Break 2027"
    var destination: String     // free text for now: "Cancún, Mexico"
    var startDate: Date         // normalized to start of day
    var endDate: Date           // normalized to start of day, >= startDate
    var travelers: Int          // >= 1, default 1
    var estimatedTotal: Double  // user-entered for now; prompt 2 fills it from data
    var estimateSource: String  // "manual" now; prompt 2 adds "perDiem"
    var notes: String
    var createdAt: Date
}
```

Add helpers, all taking an `asOf:`/`calendar:` parameter so tests are deterministic:
- `nights` and `days` (a trip from Mar 14 to Mar 21 is 7 nights, 8 days).
- `daysUntilDeparture(asOf:)`, clamped at 0.
- `status(asOf:)` → `.upcoming`, `.inProgress`, `.past`.
- `perPersonTotal` (`estimatedTotal / travelers`).

Register `Trip.self` in the schema in `MoneticApp.loadStore()`, including the `-UITesting` in-memory path.

## 2. Navigation: add a Trips tab

- Add a small `RootView` with a `TabView` of two tabs: **Budget** (the existing `ContentView`, unchanged) and **Trips** (new `TripsView`). Point `MoneticApp` at `RootView`.
- The onboarding `fullScreenCover` currently lives in `ContentView`. Make sure it still appears on first launch and still covers the tab bar. If it has to move up to `RootView`, move it as-is.
- Style the tab bar with `Brand` colors; tint with `Brand.accent`. Check both dark (default) and light mode.

## 3. Trips screens

- **`TripsView`:** list of trips, upcoming first (soonest departure at the top), then a collapsed "Past trips" section. Each row shows name, destination, date range, a countdown ("in 42 days"), and the estimated total in `Currency`. Empty state explains the feature in one line with a "Plan a trip" button.
- **`AddTripView` / `EditTripView`:** name, destination, start and end dates, travelers (stepper, 1–20), estimated total (use the same amount input as `AddTransactionView`), notes. Save is disabled until: name and destination are non-empty after trimming, end ≥ start, total > 0. Copy the save/cancel/dismiss patterns of the existing add/edit sheets.
- **`TripDetailView`:** header card with destination, dates, nights, countdown, total and per-person total. Leave a clearly marked placeholder section titled "Savings plan" that says it's coming soon; prompt 3 replaces it.
- Delete from the list (swipe) and from the detail view, with a confirmation.
- Add accessibility identifiers: `tripsTab`, `addTripButton`, `saveTripButton`, `tripRow_<name>`.

## 4. Tests

- `MoneticTests/TripTests.swift`: date normalization; nights/days across a month boundary and a DST change; `daysUntilDeparture` and `status` on fixed dates (before, on start day, during, on end day, after); `perPersonTotal`; validation rules for the add form (extract a pure `TripDraft.isValid` or similar).
- `MoneticTests/TripPersistenceTests.swift`: insert, fetch in a fresh context, edit, delete. Trips and budget categories don't affect each other's queries or totals.
- The migration test from ground rule 3.
- `MoneticUITests/TripsUITests.swift`: launch with `-UITesting`, finish onboarding, switch to Trips, add a trip, assert the row appears with the right countdown text. Use `waitForExistence`, no `sleep()`. Make the countdown testable by having the UI test pick dates relative to the test's own "now", not hard-coded ones.

## Done when

- `scripts/test.sh` (unit) and `scripts/test.sh ui` pass on an iOS 17+ simulator.
- The Budget tab looks and behaves exactly as before; onboarding still shows on first launch.
- An existing store from before this change opens with its data intact (migration test).
- Your final message lists: files added/changed, where the onboarding cover ended up and why, screenshots described for both color modes, and anything you deferred.
