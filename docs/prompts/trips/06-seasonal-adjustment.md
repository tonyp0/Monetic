# Prompt 6: Seasonal Price Adjustment and More Currencies

Paste everything below the line into Claude Code (or hand it to a developer) from the repo root.

---

This task has two independent parts for **Monetic**, a SwiftUI + SwiftData iOS 17 budgeting app:

- **(A) Seasonal price adjustment:** trip estimates reflect the time of year, using an index that AI researches offline and a person approves.
- **(B) More currencies:** the app can be set to any common world currency, not just the four in Settings today.

They touch different files. Do A first, then B, and keep them in separate commits.

# Part A: Seasonal price adjustment

You are making trip estimates reflect the time of year. After prompts 1–5, `TripEstimator` prices each night at the per diem season it falls in. The problem is the data: of 1,325 bundled locations, only 198 have more than one season. **980 of the 1,029 foreign locations have a single year-round rate**, so spring break in Cancún costs the same as September. Meals rates never vary by season.

This task adds a **seasonal lodging index**: for a reviewed list of popular destinations, 12 monthly percentages (Cancún in March might be 135%, in September 80%). AI does the research **offline, at data-build time**, a person reviews it, and only reviewed values ship in the app.

## The core rule: AI researches, people approve, the app does plain math

- The app never calls a language model for this. No API keys in the app, no network, no new dependency.
- A developer-run script asks Claude (with web search) for a draft index **with a cited source for every month**. Drafts are never bundled.
- A person approves entries into a committed file. Only approved entries reach `cost-data.json`.
- The estimate stays deterministic: the same inputs and bundled data always give the same cents.

This keeps the shared rule "never invent cost data": every shipped number has a source and a named reviewer.

## Read first

- `Monetic/Estimating/TripEstimator.swift`, `Monetic/Estimating/CostDataStore.swift`.
- `scripts/build-cost-data.py`, `scripts/fetch-cost-data.sh` (the build is offline and byte-for-byte deterministic; keep it that way).
- `Monetic/Views/TripForm.swift`, `Monetic/Views/TripBreakdownCard.swift`, `Monetic/Views/TripDetailView.swift`.
- `MoneticTests/` estimator, data store, and store migration tests.

## Ground rules

1. iOS 17.0+, SwiftUI + SwiftData, design system only, no third-party dependencies. Every new `.swift` file wired into `project.pbxproj`.
2. **When a location has no approved index, the estimate is exactly what it is today, to the cent.** All existing tests pass unchanged.
3. **Apply the index only to locations with a single season.** Locations that already have seasonal per diem rates (most of them GSA) must not be adjusted twice.
4. **Lodging only.** Meals, transport, and activities are unchanged in this task.
5. Previously saved `TripEstimate`s (stored as Codable on `Trip`) must still decode. New fields use `decodeIfPresent` with defaults. Re-run the store migration test.
6. The research script is the only code that touches the network or an API key. It reads `ANTHROPIC_API_KEY` from the environment, never writes it anywhere, and is not part of `scripts/test.sh` or CI.

## 1. Research tooling: `scripts/research-seasonality/`

- `destinations.txt`: one `cost-data.json` location ID per line. Start with about 40 single-season foreign destinations popular with U.S. students and families (beach, ski, and city: e.g. Cancún, Cabo San Lucas, Puerto Vallarta, Punta Cana, Nassau, Montego Bay, Paris, London, Rome, Barcelona, Tokyo, Reykjavik). Verify every ID exists and is single-season; the script must fail on a bad ID. Show me the list in your summary.
- `research.py` (Python 3, standard library plus the `anthropic` SDK, installed only for this script and documented in a `README.md` next to it):
  - Calls the Claude API (`claude-opus-5-5`) with the web search tool, once per destination.
  - Asks for the typical hotel price **by month relative to that destination's annual average**, as 12 whole-number percentages, each with a one-line reason and at least one source URL. Use structured output; reject responses that don't match the schema.
  - **Normalizes** the 12 values so their mean is 100, rounding to whole numbers, adjusting the largest month to fix rounding. The index then moves cost between months without raising or lowering the annual level.
  - Clamps each month to 60–200% and flags any destination where clamping happened.
  - Writes `data/seasonality/drafts/<location-id>.json` (gitignored), including the model ID, the date run, and the raw sources.
- `review.py`: prints a draft as a readable table (month, percent, reason, sources), then on `--approve <id> --reviewer "<name>"` copies it into `data/seasonality/approved.json` with `reviewedBy` and `reviewedAt`. **You (the agent) never run `--approve`.** Approving is mine.
- If `ANTHROPIC_API_KEY` is set when you work on this, run `research.py` on 3 destinations so I can see real drafts. Otherwise don't; describe the command instead. Do not invent draft data.

`approved.json` is committed and starts as an empty list unless I approve entries during review.

## 2. Build: `scripts/build-cost-data.py`

- Read `data/seasonality/approved.json` if present. For each entry, attach to its location:
  `"seasonalIndex": {"lodgingPercentByMonth": [12 ints], "reviewedAt": "yyyy-MM-dd", "sources": ["url", ...]}`.
- Fail the build if an entry names an unknown or multi-season location, has anything other than 12 values, has a value outside 60–200, or doesn't average 100 (±1).
- Add a `meta.sources` entry `{"id": "seasonality", ...}` describing the index. The build must stay offline and byte-for-byte deterministic. With an empty `approved.json`, `cost-data.json` must not change.

## 3. Code

- `CostLocation` gains `seasonalIndex: SeasonalIndex?` (decodeIfPresent).
- In `TripEstimator.estimate`, each night's lodging becomes `rate × stylePercent × rooms × monthPercent`, where `monthPercent` is the index for the month that night falls in (100 when there's no index). Keep the money math in integers: accumulate in hundredths of a cent, then **round half up once per line item** to whole cents. Comment the rounding rule.
- `TripEstimate` gains `seasonalLodgingDeltaCents: Int` (the lodging total minus what it would be with no index; 0 when no index) so the UI can say how much the season added or saved. `decodeIfPresent`, default 0.
- A small pure helper for the form hint: the cheapest and priciest months for a location with an index.

## 4. UI

- **TripBreakdownCard**, under the lodging line, only when the delta isn't 0: "Includes +$312 for peak season (March)" or "−$140 for low season". A secondary line: "Seasonal adjustment researched with AI and reviewed by Monetic", plus the sources (tappable links).
- **TripForm**, when the chosen destination has an index: one quiet line under the dates, e.g. "Hotels here run about 35% above average in March. Cheapest month: September." Hide it otherwise.
- Update `TripEstimator.sourceLine` to mention the seasonal index when it was applied.
- Design system only; VoiceOver labels say the delta in words.

## 5. Tests

Use a fixture dataset with a hand-written index. It's test data only and is labeled as such.

- No index → identical cents to today, for every style (pin a few existing cases).
- Multi-season location with an index in the fixture → the estimator ignores the index (also covered by the build's validation).
- A trip spanning two months uses each night's own month; a trip spanning Dec 31 → Jan 1 wraps correctly; Feb 29 uses February.
- Rounding: a case where the per-night math produces fractional cents rounds once per line item, half up; the per-person split still adds back to the total.
- `seasonalLodgingDeltaCents` is positive in peak, negative in low season, 0 at 100%.
- Old saved estimates without the new field decode with delta 0; the migration test passes.
- Build-script validation: add a small Python test (`scripts/research-seasonality/test_validation.py`, standard library `unittest`) for each failure case in section 2, plus the normalize-to-100 helper.
- `CostDataStore` decodes a location with and without `seasonalIndex`.

# Part B: More currencies

## How it works today

- `Currency.code` (`Monetic/Utilities/Formatting.swift`) reads the `selectedCurrencyCode` user default, or falls back to the device region's currency, or USD.
- `SettingsView.currencyCard` offers only Device Default, USD, EUR, GBP, and JPY.
- Changing the currency **only changes the label**: stored amounts are plain numbers, and Monetic doesn't convert. Per diem trip estimates always stay in USD (`Trip.totalCurrencyCode`, and the note in `TripBreakdownCard`).
- Amount entry assumes two decimal places: `AmountInput.sanitize` allows 2 decimals, `AmountInput.text(cents:)` always writes `"1500.00"`, and amounts are handled internally as hundredths (`* 100` in `TripDraft`, `SavingsPlan`, `SavingsDrafts`, `TripShare`).

## Read first

- `Monetic/Utilities/Formatting.swift` (`Currency`, `AmountInput`), `Monetic/Views/SettingsView.swift`.
- The amount field in `Monetic/DesignSystem/BrandComponents.swift` and every caller of `AmountInput` (grep for it).
- `Monetic/MoneticApp.swift`, which resets `selectedCurrencyCode` for UI tests.

## Ground rules

1. **No conversion and no exchange rates.** Switching currency relabels amounts, exactly as today. Don't change any stored value when the currency changes.
2. Keep storing amounts as they are now. Hundredths stay the internal unit, so no SwiftData migration is needed. Only entry and display learn about decimal places.
3. Per diem estimates stay in USD with the existing note. Don't touch Part A's math.
4. Existing behavior for USD, EUR, GBP and the device default is unchanged, and all existing tests pass.
5. Use Foundation for the currency list and names (`Locale.commonISOCurrencyCodes`, `Locale.current.localizedString(forCurrencyCode:)`). No hard-coded list of names, no dependency.

## 1. Code

- `Currency.options`: the selectable codes. Start from `Locale.commonISOCurrencyCodes` and **leave out currencies with three decimal places** (e.g. KWD, BHD, OMR, JOD, TND), since hundredths can't hold their amounts. Derive that from the currency's fraction digits, not a hand-written list, and comment why. If the device default is one of these, fall back to USD and say so in Settings.
- `Currency.fractionDigits(for:)`: 0 for currencies like JPY and KRW, 2 for most. Read it from a currency `NumberFormatter`.
- `AmountInput.sanitize`, `text(cents:)` and the amount field use the current currency's decimal places. With JPY you can't type a decimal separator, and a prefilled field shows `"1500"`, not `"1500.00"`. Check that re-sanitizing prefilled text never multiplies the value (`"1500.00"` must not become `"150000"`).
- If `selectedCurrencyCode` holds a code that is no longer in `options`, treat it as Device Default instead of crashing or showing a blank picker.

## 2. UI (Settings)

- Replace the five-option menu with a row that opens a searchable list, using design system components:
  - Device Default first, then a short "Common" group (USD, EUR, GBP, CAD, AUD, MXN, JPY, INR, plus the device's own currency), then all the others sorted by localized name.
  - Each row shows the localized name, code and symbol: "Mexican Peso · MXN · $". Search matches name or code.
  - A checkmark marks the selection, and VoiceOver reads the full currency name.
- Below the row, keep the existing caption and add: "Changing currency doesn't convert amounts you've already entered."
- When the chosen currency isn't USD, the trip breakdown's "Shown in US dollars" note keeps appearing, as it does today.

## 3. Tests

Use a fixed `en_US_POSIX` or explicit locale. Never depend on the device region.

- `options` includes USD, EUR, MXN and JPY, has no three-decimal currencies and no duplicates, and is sorted as described.
- `fractionDigits` returns 0 for JPY and KRW and 2 for USD and EUR.
- `AmountInput` with JPY: `sanitize("1500.5")` → `"1500"`, `text(cents: 150000)` → `"1500"`, and `cents("1500")` → `150000`. The existing USD cases still pass.
- A stored code that isn't in `options` falls back to Device Default.
- A UI test: pick MXN in Settings, then see an expense amount shown with MXN formatting. Reset afterwards using the existing UI-test reset.

# Done when

- **A:** With an empty `approved.json`, `cost-data.json` is byte-identical to before and every estimate is unchanged.
- **A:** With a fixture index, a Cancún-style location costs more in March than in September for the same trip, and the breakdown shows the delta and its sources.
- **A:** No code path in the app calls a model or the network; state in your summary how that's enforced.
- **B:** Settings lets me search for and pick any supported currency. JPY entry has no decimals, and USD/EUR/GBP behave exactly as before.
- **B:** No stored amount changes when the currency changes.
- `scripts/test.sh` passes without an API key.
- Your final message lists: files changed, the destination list, exactly how I run research and approve an entry, any drafts you generated (or that you didn't), the currencies you excluded and why, and anything deferred (e.g. seasonal meals or activities, flights by month, currency conversion).
