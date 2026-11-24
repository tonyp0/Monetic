# Step 0: Screenshot Harness

Run this before any visual change. It gives you "before" images and a repeatable way to check every later step in light and dark mode.

---

You're preparing **Monetic** (SwiftUI + SwiftData, iOS 17, `Monetic.xcodeproj`, scheme `Monetic`) for a UI overhaul. Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first, especially "Engineering ground rules". **This step changes no visuals.** It only adds tooling to capture every screen.

## Read first

- `Monetic/MoneticApp.swift`: `loadStore()` and `resetSettingsForTesting()`, behind the DEBUG `-UITesting` launch argument.
- `MoneticUITests/AddExpenseUITests.swift` and `MoneticDemoUITests.swift`: how existing UI tests launch and get past onboarding and the new-month budget sheet (there's a race between the two).
- `scripts/test.sh`: how tests are run and how a simulator is picked.
- `Monetic/Views/OnboardingView.swift`: the starter groups.

## Do

1. **Seed demo data behind a DEBUG flag.** Add a `-SeedDemoData` launch argument (only in `#if DEBUG`, only together with `-UITesting`). It marks onboarding complete, sets a $500 budget for the current month, inserts 7 starter groups with their default emoji and colours, and adds about 12 realistic expenses spread over the past 10–14 days of the current month (with notes, one recurring monthly, a few groups at $0). Pick amounts so one group is near or over its share and the overall budget is around 55–65% used. Put the seeding in its own small file (for example `Monetic/Utilities/DemoData.swift`) and add it to the app target in `project.pbxproj`.
2. **Add `MoneticUITests/ScreenTourUITests.swift`**, added to the `MoneticUITests` target. It's not a correctness test, so no `sleep()`; use `waitForExistence`. Run it twice, once with `-appAppearance light` and once with `-appAppearance dark` (launch-argument UserDefaults override `@AppStorage`). Capture a screenshot of each of these as a kept `XCTAttachment` named `NN-screen-mode` (for example `03-home-top-dark`):
   - onboarding (fresh launch without seed data) and the set-budget sheet
   - home (top), home (scrolled to the chart), home (scrolled to the groups list)
   - category detail for a group with expenses, and one with none
   - Add Expense (empty, then with amount and group filled in), Edit Expense
   - Add Group, Edit Group, Settings
3. **Add `scripts/screenshots.sh`**, using the same simulator selection as `test.sh` (reuse it, don't copy-paste it if you can source or share it). It runs only `ScreenTourUITests` with `-resultBundlePath`, then exports the attachments to `screenshots/<label>/` with `xcrun xcresulttool` (handle the Xcode 16+ `export attachments` syntax and fall back to the older one). Takes an optional label argument (default: current short git SHA). Add `screenshots/` to `.gitignore`.
4. Run it now with label `before`, and confirm `screenshots/before/` contains both modes of every screen.

## Don't

- Change any view, colour or copy.
- Let the seed or tour code compile into Release builds.

## Done when

- `scripts/test.sh` and `scripts/test.sh ui` still pass.
- `scripts/screenshots.sh before` produces the full light and dark set. List the files in your summary and point out anything that already looks broken (clipped text, overlap) as a baseline note.
