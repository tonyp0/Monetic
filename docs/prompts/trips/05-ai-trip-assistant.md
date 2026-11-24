# Prompt 5: AI Trip Assistant and Estimate Accuracy

Paste everything below the line into Claude Code (or hand it to a developer) from the repo root.

---

You are adding AI to the Trips feature of **Monetic**, a SwiftUI + SwiftData iOS 17 budgeting app. After prompts 1–4, trips are estimated from bundled government per diem data (`Monetic/Estimating/TripEstimator.swift`) with documented travel-style multipliers. This task adds two things:

- **(A) A natural-language trip entry:** "spring break in Cancún with 4 friends, cheap, March 14–21" fills in the trip form.
- **(B) Estimate-vs-actual tracking:** after a trip, compare what the app predicted with what was really spent, so the estimates can be measured and improved.

## The core rule: AI understands words, data supplies numbers

The language model **only extracts structured inputs** (destination, dates, travelers, style, flight price if the user said one). It **never produces a cost**. Every amount the user sees still comes from `TripEstimator` and the bundled dataset, or from the user. Enforce this in code: the model's output type has no money fields other than a user-quoted flight price, and the UI shows that number as "you said".

## Read first

- `Monetic/Estimating/TripEstimator.swift`, `CostDataStore.swift`.
- `Monetic/Views/AddTripView.swift`.
- `Monetic/Models/Trip.swift`, `Monetic/Models/Transaction.swift`, `Category.swift`.

## Ground rules

1. **On-device first, no API keys in the app.** Use Apple's Foundation Models framework (`import FoundationModels`, guided generation with `@Generable`) for part A. It requires iOS 26 and an Apple Intelligence device, so:
   - Keep the deployment target at iOS 17. Wrap all of it in `if #available(iOS 26, *)` and check `SystemLanguageModel.default.availability`.
   - When it's unavailable (older OS, unsupported device, Apple Intelligence off, model still downloading), hide the text box and show the normal form. No error screens.
   - If the framework's API differs from what you expect, read the SDK headers in the installed Xcode rather than guessing, and tell me what you found.
2. **Never send user data off the device** in this task.
3. **The extractor is behind a protocol** (`TripIntentExtracting`) with a deterministic fake for tests, so no test depends on the model's output.
4. Design system only, `project.pbxproj` wiring, existing behavior and tests unchanged. Re-run the migration test for any new model properties.

## Part A: Natural-language trip entry

- `Monetic/Trips/TripIntent.swift`: `@Generable struct TripIntent` with optional `destinationQuery`, `startDate`, `endDate`, `travelers`, `style` (enum constrained to the app's `TravelStyle` cases), `quotedFlightTotal`. Dates are resolved relative to an injected "today" and the user's calendar; a bare "March" in November means next March.
- Resolve `destinationQuery` through `CostDataStore.search`. If there are several matches, show them; if none, keep the text as a manual destination.
- At the top of `AddTripView`: a single text field "Describe your trip", then the form below fills in with each AI-filled field visibly marked until the user touches it. The user must always be able to review and edit before saving. Nothing saves automatically.
- Run extraction off the main thread with a short timeout; on any failure, leave the form as it was and show "Couldn't read that, fill it in below".
- Tests (with the fake extractor): field mapping, ambiguous destinations, missing fields, date resolution across the year boundary, rejection of out-of-range travelers, and timeout handling. Add a small, non-CI evaluation script (`scripts/eval-trip-intent/`) with ~30 example sentences and expected fields that I can run on a real device to measure extraction accuracy; report the score format, not invented results.

## Part B: Estimate vs actual

- Let a past trip link to actual spending. Simplest version: on a trip in `.past` status, "Log what you spent" with the same line items as the estimate (lodging, food, transport, activities, flights). Optionally prefill from `Transaction`s in the Travel group dated within the trip, which the user confirms.
- Store actuals on the trip; show a **comparison card**: estimate vs actual per line item and overall, as amounts and percentages.
- Add `Monetic/Estimating/EstimateAccuracy.swift`: pure functions for per-line and overall error (signed percentage and absolute), and aggregate stats across a user's past trips grouped by travel style. If a user's trips consistently run over or under for a style, show a one-line, dismissible hint on their next estimate ("Your last 3 budget-style trips ran 18% over the estimate"). Never change the estimate silently.
- Tests: error math including zero estimates and missing actuals; aggregation; the hint appears only with at least 3 comparable trips.

## Part C: Write the next step (don't build it)

File: `docs/design/estimate-calibration.md`, one page. With users' explicit opt-in, anonymized estimate-vs-actual pairs could improve the multipliers for everyone. Cover: what exactly would be collected (no names, no notes, coarse dates), consent UX, the minimum backend needed, how many trips per destination/style you'd need before changing a multiplier, and the privacy policy changes required before collecting anything.

## Done when

- On an Apple Intelligence simulator or device, typing a trip sentence fills the form; on any other setup the form works exactly as before.
- No cost figure anywhere comes from the language model (state in your summary how the code enforces this).
- `scripts/test.sh` passes without needing the model.
- Your final message lists: the availability states you handled, files changed, how to run the eval script, the calibration doc, and anything deferred.
