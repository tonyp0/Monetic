# Prompt 2: Trip Cost Estimator

Paste everything below the line into Claude Code (or hand it to a developer) from the repo root.

---

You are adding a cost estimator to the Trips feature of **Monetic**, a SwiftUI + SwiftData iOS 17 budgeting app. Prompt 1 already added a `Trip` model (`Monetic/Models/Trip.swift`) with a user-typed `estimatedTotal` and an `estimateSource` of `"manual"`. Now a user should be able to pick a destination, dates, number of travelers and a travel style, and get a **breakdown** (lodging, food and incidentals, local transport, activities, flights) built from real public data. The whole estimator runs **offline** from data bundled in the app.

## Read first

- `Monetic/Models/Trip.swift`, `Monetic/Views/AddTripView.swift`, `EditTripView.swift`, `TripDetailView.swift` (from prompt 1).
- `Monetic/Utilities/Formatting.swift` — `Currency`.
- `Monetic/DesignSystem/BrandComponents.swift` — reuse the progress bars/cards for the breakdown.
- `MoneticTests/TestSupport.swift`.

## Data source (read carefully)

Use the **U.S. Department of State foreign per diem rates** for international destinations and **GSA per diem rates** for U.S. destinations. Both are public, government-published, and give a per-location **maximum lodging rate** and **M&IE** (meals and incidental expenses) per day.

- **Never invent or "estimate from memory" any number.** If you cannot download the datasets from this environment, stop and tell me exactly which files to download and where to put them; build and test everything against a small fixture instead.
- Add `scripts/build-cost-data.swift` (or `.py`, run with system Python and no third-party packages) that reads the raw downloaded files from `data/raw/` (gitignored) and writes `Monetic/Resources/cost-data.json`. The script must be deterministic and record the dataset names, effective dates and source URLs in the JSON's `meta` block.
- JSON shape (adjust if the source requires it, and explain why):
  ```json
  {
    "meta": { "sources": [...], "generatedAt": "...", "currency": "USD" },
    "locations": [
      { "id": "MX-CUN", "name": "Cancún", "country": "Mexico", "aliases": ["Cancun"],
        "lodgingPerNight": 0, "mealsPerDay": 0, "seasonal": [] }
    ]
  }
  ```
- Add the JSON to the app target as a bundle resource. Keep it under ~2 MB; strip fields the app doesn't use.
- Show the data source and its effective date on the estimate screen ("Based on U.S. government per diem rates, effective …").

## Ground rules

1. **Estimator is a pure function.** `TripEstimator.estimate(location:, nights:, travelers:, style:, flightTotal:, startDate:) -> TripEstimate` with no SwiftUI, no SwiftData and no `Date()` inside. All math is unit-tested.
2. **Per diem rates are ceilings for government travelers, not what students pay.** Model that explicitly with travel style multipliers, kept in one clearly named, documented table:
   - `budget` (hostels, shared rooms, groceries), `standard`, `comfort`.
   - Lodging is per **room**, not per person: assume `ceil(travelers / 2)` rooms for budget and standard, one room per traveler for comfort. Expose the sharing assumption in the UI so the user can change it.
   - Put each multiplier's justification in a comment. These are product assumptions, so label them as such in the UI ("Budget style assumes about X% of the government rate").
3. **Flights are user-entered.** Don't call any flight API. Provide a single "Flights (total for group)" field, defaulting to empty, with helper text telling the user to paste a fare they found. The estimate shows a clear "+ flights" gap if it's left empty.
4. **Seasonal rates:** if the source gives seasonal lodging rates for a location, use the rate for each night of the trip, not a single average.
5. **Currency:** source data is in USD. If the user's `Currency.code` isn't USD, show amounts in USD with a note. Do **not** ship hard-coded exchange rates.
6. Design system only, `project.pbxproj` wiring for every new file, existing behavior and tests unchanged.

## 1. Code

- `Monetic/Estimating/CostDataStore.swift`: loads and decodes the bundled JSON once; `search(_ query: String) -> [Location]` with diacritic- and case-insensitive matching on name, country and aliases ("cancun" finds "Cancún").
- `Monetic/Estimating/TripEstimator.swift`: `TravelStyle`, `TripEstimate` (line items + total + per-person), the estimator.
- Add `locationID: String?` and `travelStyle: String` to `Trip` (string-backed enum like `recurringFrequency`). Keep `estimatedTotal` as the stored number the rest of the app reads; set `estimateSource = "perDiem"` when it came from the estimator. Re-run the migration test from prompt 1 with these new properties.

## 2. UI

- In `AddTripView`/`EditTripView`, the destination field becomes a search field over `CostDataStore`. Picking a result sets `locationID`. Free text with no match still works and falls back to a manual total.
- Add a travel style segmented control (use the brand segmented control) and the flights field.
- Show a live **breakdown card**: one row per line item with amount and share of total, then total and per-person. Let the user override the final total; an override switches `estimateSource` back to `"manual"` and shows "Edited by you".
- `TripDetailView` shows the saved breakdown and the data source line.

## 3. Tests

- `MoneticTests/TripEstimatorTests.swift` against a **fixture JSON** in the test bundle (not the real dataset), so tests don't change when the data is regenerated: per-style math; room-sharing for 1, 2, 3 and 5 travelers; seasonal rates across a season boundary; zero/empty flights; per-person rounding (totals must add up to the cent).
- `MoneticTests/CostDataStoreTests.swift`: decoding, diacritic-insensitive search, aliases, no match.
- One test that loads the **real** bundled JSON and checks it decodes, has a non-empty `meta.sources`, and has no location with a zero or negative rate.

## Done when

- A trip to a city in the dataset gets a breakdown in under a second, offline (airplane mode on the simulator).
- `scripts/test.sh` passes; regenerating the data with the script produces a byte-identical JSON.
- The estimate screen names its data source and effective date, and every multiplier is labeled as an assumption.
- Your final message lists: the exact datasets and URLs used (or what I need to download), the multiplier table with your reasoning, files changed, and anything deferred.
