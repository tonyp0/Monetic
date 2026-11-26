# Estimate calibration: learning from everyone's trips

Status: proposal. Nothing here is built, and nothing is collected today.

**Today.** Each user can log what a past trip really cost (`TripActuals`). `EstimateAccuracy` compares that with the estimate on their own phone. When their recent trips in one travel style keep running over or under, Monetic shows them a one-line hint and never changes the estimate.

**The idea.** With explicit opt-in, send anonymized estimate-vs-actual pairs to a small backend. Enough of them could correct the travel-style multipliers in `StyleAssumptions` for everyone. Those multipliers are currently Monetic's judgment, labeled as assumptions in the app.

## What would be collected

A pair is sent only once per trip, after the user logs actuals and has opted in. It contains only:

| Field | Example | Why |
|---|---|---|
| `locationID` | `DOS-MEXICO-CANCUN` | Group by place; it's a public per diem area, not an address |
| `style` | `budget` | The multiplier being calibrated |
| `travelers`, `rooms`, `nights` | `5`, `3`, `7` | The estimator's inputs |
| Season | `2027-Q1` | Rates are seasonal. Only the quarter, never dates |
| `dataEffective` | `2024-08-01` | Which rate table produced the estimate |
| Estimated cents per line | lodging, food, transport, activities | The estimator's output |
| Actual cents per line | same lines, or "not tracked" | The ground truth |

Never collected:
- trip name, notes, destination text, exact dates;
- flights (user-typed, not estimated);
- savings, contributions or the budget;
- device ID or account;
- the share ID, or anything from a joined trip's organizer.

There's no user identifier, so pairs can't be linked to each other or to a person. The cost is that we can't de-duplicate a user who submits the same trip twice; the app enforces one submission per trip locally.

For rare places, five travelers in one small town in one quarter could still identify a group. So places with fewer than about 20 contributing trips are reported as their **country** (for State Dept rates) or **state** (for GSA rates), never as the locality.

## Consent UX

- **Off by default.** Never asked during onboarding.
- **Asked at the moment it's meaningful:** once, right after someone saves their first actuals, as a dismissible card under the comparison. "Help make Monetic's estimates better? Share this comparison anonymously: the place, travel style, season and amounts, never your name, notes, dates or savings." Buttons: **Share anonymously** / **Not now**. "Not now" doesn't ask again for 90 days.
- **Preview before sending.** "See exactly what's sent" shows the payload above as a readable table.
- **A setting** under Settings → Privacy, "Share trip comparisons anonymously", to turn it off at any time. Turning it off stops future sends.
- **Per-trip control:** each comparison card shows "Shared anonymously" with an option to not share this one, if it hasn't been sent yet. Sends are queued for 24 hours so a mistake can be undone.
- **No dark patterns:** equal-weight buttons, no nagging, the feature works identically either way.

## Minimum backend

- **One endpoint:** `POST /v1/pairs`. A serverless function (for example a Cloudflare Worker, the same one proposed in `group-trips-sync.md`) validates the payload with the same rules the app uses for share links: known location IDs, sane ranges, rounded season.
- **Storage:** one append-only table in a managed database (for example D1/SQLite or Postgres). There are no user tables.
- **Abuse:** per-IP rate limit at the edge, IPs never stored, payload size cap, and outlier trimming at analysis time (drop pairs where actual/estimate is under 0.2 or over 5).
- **Analysis:** offline, in a notebook or script, quarterly. It produces a proposed new `StyleAssumptions` table and a report. **Multipliers change only in an app release**, reviewed by a person, never pushed live from the server.
- **Cost:** within free tiers until well past 10k users.

## How many trips before changing a multiplier

The quantity being estimated is the median ratio `actual / estimate` per line item (lodging, food, transport, activities), per style.

- **Global per style first.** Change a style's multiplier only with **at least 100 pairs** for that style, from **at least 15 distinct locations** across at least two seasons, so one popular spring-break town can't dominate. Use the median ratio with a bootstrap 90% interval. Ship a change only if the interval excludes 1.0 *and* the shift is at least 5 points (for example lodging 45% → 50%). Cap any single release's change at ±15 points.
- **Per place or region later.** A location- or region-specific adjustment needs **at least 30 pairs for that place and style**. Until then the place uses the global style multiplier. Coarse regions (country or state) come before cities.
- **Re-check after each change:** the next quarter's pairs should show the median ratio moving toward 1.0. If not, revert.

These thresholds are a starting point. With ratios that typically vary ±30–40%, 100 pairs gives a median accurate to roughly ±5 points, which is the smallest change worth shipping.

## Privacy policy changes required before collecting anything

1. **Privacy policy:** a new section describing the collection: what's collected (the table above), that it's optional and off by default, that it isn't linked to identity, why (improving estimates), where it's stored and for how long (proposal: 3 years, then deleted), and how to turn it off. Note that already-sent pairs can't be deleted on request because they can't be tied to the person. That limitation must be stated plainly.
2. **App Store privacy label:** add "Other Usage Data" (or "Product Interaction"), *not linked to the user*, *not used for tracking*, purpose *Analytics / Product personalization*. Today's label is "Data Not Collected", so this is a visible change and should be a deliberate decision.
3. **Legal basis (GDPR/UK GDPR):** consent, given via the opt-in above. Even without identifiers, location plus season plus party size could be personal data in rare cases. The coarsening rule above exists to keep it anonymous; document it in a short data-protection assessment.
4. **Children:** if the App Store age rating admits under-13s (COPPA) or under-16s (GDPR-K), disable the opt-in for those users or require age confirmation.
5. **Vendor terms:** the edge and database providers become processors and need a DPA.
6. **Release note and in-app "What's new"** announcing the feature, linking the policy.

Until all six are done, the app collects nothing, and the local hint is the only calibration.
