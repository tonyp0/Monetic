# Step 5: Trip Detail, Cost Estimate and Savings

The screens that answer "What will it cost?", "Can I afford it?" and "Who's coming?"

**Run after step 4.** It restyles whatever Trips prompts 1–5 have built so far. If sharing (Trips 4) or the AI trip entry (Trips 5) isn't merged yet, skip those sections and note it in your summary.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first, especially **Components and patterns** ("Cited numbers show their source", the ring, status chips), **What it's not** and **Voice**. This step restyles and reorganises the trip screens. **It must not change any estimate, savings-plan or sharing logic, or what gets saved.**

## Read first

- `TripDetailView`, `AddTripView`, `EditTripView`, the add-to-savings sheet, and the join-trip preview sheet if it exists.
- `TripEstimator`, `TripEstimate` and `CostDataStore` (to know what each number means and where the source and effective date come from).
- `SavingsPlan` (status, per-period amount, catch-up, `isUnrealistic`).
- `TripShare` and the "Invite friends" `ShareLink` if they exist.
- Trips unit and UI tests, and the identifiers they use.

## Trip detail

One scrolling page in this order. Use plain sections on the background, with at most one `surface` card on the screen:

1. **Header**: flag and destination in `.largeTitle` (inline nav title when scrolled), then "Mar 14–21 · 7 nights · 4 people" in `.subheadline`. Then the countdown sentence from step 4 ("108 days to go").
2. **Savings** (the one card):
   - A large `ProgressRing` (about 180pt) with "**$412** saved" in the centre and "of $640" under it. When the goal is per person, say so: "your share: $640".
   - A `StatusChip` and the next-action sentence: "Save **$42 a week** until Mar 14", or the catch-up sentence when behind.
   - **Add to savings** (`PrimaryButtonStyle`).
   - If `isUnrealistic`: a short `warning` note in plain words with the two honest options as plain buttons, **Save more each week** and **Change goal or dates**, wired to whatever the current code already offers. Don't invent new behaviour.
3. **What it'll cost**: the estimate breakdown as a plain list. Each line item (Lodging, Food, Getting around, Activities, Flights) has its amount `.monospacedDigit()` and a thin share-of-total bar, then **Total** and **Per person** in `.headline`.
   - Flights not entered: show "+ flights" in `textSecondary` with a small **Add flight price** button, matching the estimator's existing behaviour.
   - Under the list, the **source footnote** in `.footnote` / `textSecondary`: "Based on U.S. government per diem rates, effective Oct 1, 2026. Budget style assumes about 45% of those rates." Use the real values from the data and estimator; never hard-code them. If the total was edited by the user, show "You entered this total" instead.
   - If the estimate-vs-actual comparison (Trips 5) exists on past trips, show it here in the same list style: estimate, actual, difference per line.
4. **Planned with friends** (Trips 4, if present): "Planned with friends · 4 people" and the **Invite friends** button (plain tinted, not filled, since there's only one filled button per screen). The copy must not imply you can see friends' progress. Keep the `ShareLink` message wording, but make it read in the brief's voice.
5. **Savings history**: contributions grouped by month, newest first. Each row has the date, note (or "Added to savings" / "Took out"), and the amount (withdrawals in `textSecondary` with a minus sign, never red). Swipe to edit and delete stay as they are.
6. Toolbar: plain **Edit**, and a `…` menu with Delete (in `danger`, with the existing confirmation).

## Add / Edit trip

Make it feel like answering three quick questions, not filling in a form. Keep the same fields, validation and save behaviour.

1. If the natural-language entry (Trips 5) is available: a single "Describe your trip" field at the top ("spring break in Cancún with 4 friends, cheap, Mar 14–21"). AI-filled fields get a small `accent` dot until the user edits them. When unavailable, the field doesn't appear at all.
2. **Where?** The destination search, with results showing flag, city and country. A free-text destination that doesn't match still works and says "We don't have cost data for this place yet. Enter your own total."
3. **When and who?** Dates (compact pickers), then travellers as a stepper reading "4 people".
4. **How do you travel?** The travel-style control (Budget / Standard / Comfort) with one line under it explaining the selected style in plain words.
5. **Flights**: optional amount with the hint "Paste a fare you found. We don't look up flights."
6. **Live estimate** at the bottom, matching the detail breakdown (same component, and extract it once if that removes duplication), with the source footnote. Overriding the total switches to "You entered this total", as today.
7. Toolbar: plain `Cancel`, `.semibold` `Save` (`saveTripButton`, visible text unchanged).

## Add to savings

- Big amount at the top in `Brand.hero` (same pattern as Add Expense in step 7), then Date and Note as plain rows, then the deposit/withdraw choice as a two-option segmented control ("Add" / "Take out").
- After saving a deposit, show a brief confirmation on the trip detail ("$40 added. 4 more weeks like this and you're there."), computed from the existing plan values. Use `.sensoryFeedback(.success, …)`, plus a short celebratory state when the trip becomes fully funded ("Fully funded!"). Under Reduce Motion, no confetti-style animation; a text change is enough.

## Join trip preview (Trips 4, if present)

- "Join this trip?" with the destination header (as above), dates, travellers, and the estimate breakdown with its source. Then "Your share" as an editable amount, and **Join trip** as the primary button.
- Error states for bad links stay friendly and short, in the brief's voice ("This link doesn't work. Ask your friend to send it again.").

## Done when

- No estimate, plan or share numbers change (existing unit tests pass unchanged; if any test asserts visible text you reworded, update only that assertion and list it).
- UI tests pass.
- `scripts/screenshots.sh step5`: trip detail (behind, on track, funded, unrealistic, manual-total and no-flights variants: tweak the seed temporarily if needed, then revert), Add Trip (empty and filled), Add to Savings, and Join preview, in both modes and at an AX size. Confirm every estimate on screen shows its source footnote.
