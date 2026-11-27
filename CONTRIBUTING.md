# Contributing to Monetic

Thanks for helping. This guide covers how to build, test and change Monetic.

## Ground rules

- **Run the unit suite before opening a PR, and add a test with every bug fix.**
- Pull requests into `main` run the unit suite automatically on GitHub Actions (`.github/workflows/tests.yml`).
- UI changes follow the design brief: warm paper, dark ink, one amber accent, no gradients. Check every change in both Light and Dark mode.

## Build

1. Open `Monetic.xcodeproj` in Xcode.
2. Choose an iPhone simulator or a connected device.
3. Build and run (⌘R).

The app targets iOS 17.0+. The "Describe your trip" assistant needs iOS 26+ on an Apple Intelligence device; everything else works without it.

## Test

- **Xcode:** Product → Test (⌘U) runs everything.
- **Command line:** `scripts/test.sh` picks an available iPhone simulator for you:

  ```sh
  scripts/test.sh        # unit tests only, the fast pre-PR check
  scripts/test.sh ui     # UI tests only
  scripts/test.sh all    # everything, including the demo tour
  ```

  To choose the simulator yourself, set `DESTINATION`, or call xcodebuild directly:

  ```sh
  xcodebuild test -project Monetic.xcodeproj -scheme Monetic \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
    -only-testing:MoneticTests
  ```

  `name=` only matches a simulator on the newest iOS you have installed unless you also give `OS=`. `xcrun simctl list devices available` shows what you have.

- **After updating Xcode**, simulators stay disabled ("CoreSimulator is out of date") until first-launch setup runs. Open Xcode once, or run `sudo xcodebuild -runFirstLaunch`. `scripts/test.sh` checks for this.

### What's covered

| Suite | What it checks |
| --- | --- |
| `MoneticTests/CategoryTransactionTests` | Adding expenses works for all 9 starter groups plus a custom one: saving, reloading, totals, recurring, validation, creating groups |
| `MoneticTests/BudgetCategoryTests` | Which expenses count toward a month (one-time, monthly, yearly, month and year boundaries), budget % and over-budget |
| `MoneticTests/PersistenceTests` | Deleting groups and expenses, editing amounts and dates, reordering |
| `MoneticTests/TransactionTests`, `FormattingTests`, `MonthRolloverTests` | Date normalization, amount entry, month keys, currency, icons, the new-month budget prompt |
| `MoneticTests/TripTests`, `TripPersistenceTests`, `StoreMigrationTests` | Trip dates, nights, countdown, list order, saving and reloading, migrating older stores |
| `MoneticTests/TripEstimatorTests`, `CostDataStoreTests`, `SeasonalIndexTests` | Estimate math and rounding, travel styles, seasons, location search, the bundled data |
| `MoneticTests/SavingsPlanTests`, `SavingsContributionTests`, `SavingsReminderTests` | Savings targets and on-track status, the budget check, deposits and withdrawals, reminders |
| `MoneticTests/TripShareTests` | Trip links: what's encoded, that no money goes in, joining, rejecting broken links |
| `MoneticTests/TripAssistantTests`, `EstimateAccuracyTests` | Turning a trip description into form values, estimate vs. actual |
| `MoneticTests/AppAppearanceTests`, `BrandContrastTests` | The appearance setting, and color contrast in both modes |
| `MoneticUITests/AddExpenseUITests` | End to end: onboarding → set budget → add expense → group and home totals update |
| `MoneticUITests/TripsUITests` | End to end: adding, estimating and saving for a trip, joining from a link, a broken link, the trip assistant (with a canned model) |

`MoneticUITests/MoneticDemoUITests` is a screen-recording tour and `ScreenTourUITests` captures screenshots (`scripts/screenshots.sh`). Neither is a correctness test. `TripIntentEvalTests` scores the assistant against the on-device model and only runs through `scripts/eval-trip-intent/run.sh`.

### Writing a test

- Use Swift Testing (`@Test`, `#expect`) for unit tests and put shared helpers in `MoneticTests/TestSupport.swift`. Use XCTest only for UI tests.
- Use a fresh in-memory store (`TestSupport.makeContainer()`) and fixed dates (`TestSupport.date(2026, 3, 14)`). Never depend on today's date or the device locale.
- Add every new test file to its target in Xcode. The project doesn't use synchronized folders.
- If a test finds a bug you aren't fixing yet, wrap the expectation in `withKnownIssue("…")` so the suite stays green and the bug stays visible.
- UI tests launch the app with `-UITesting YES` (Debug builds only). The app then starts with an empty in-memory store and first-launch settings. Add `-SeedDemoData YES` for a month of sample expenses.

## Refreshing the cost data

Trip estimates come from per diem tables bundled in `Monetic/Resources/cost-data.json`. To refresh them, update the pinned URLs and dates in `scripts/fetch-cost-data.sh` and the constants at the top of `scripts/build-cost-data.py`, then run:

```sh
scripts/fetch-cost-data.sh && python3 scripts/build-cost-data.py
```

The raw downloads go to `data/raw/`, which is gitignored. Only the generated JSON is committed, and the build is deterministic: the same inputs give a byte-identical file.

## Brand assets

Every logo file (`Marketing/Brand/`, the `BrandLogo` image set and `Monetic/AppIcon.icon`) is generated from one set of shapes. To change the logo, edit `scripts/make-brand.swift` and run:

```sh
swift scripts/make-brand.swift
```

Don't edit the generated SVGs or PNGs by hand.

## Screenshots

`scripts/screenshots.sh <label>` captures every main screen in Light and Dark mode into `screenshots/<label>/` (gitignored). The images in `Marketing/AppPreviews/` are the ones the README uses.
