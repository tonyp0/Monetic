# Prompt 4: Shared Trip Goal

Paste everything below the line into Claude Code (or hand it to a developer) from the repo root.

---

You are adding the first group feature to the Trips area of **Monetic**, a SwiftUI + SwiftData iOS 17 budgeting app. After prompts 1–3, one person can plan a trip, get an estimate and save toward it. College trips are planned in groups, and the goal of this task is to **test whether trips spread from one organizer to their friends** without building a backend yet.

This task has two parts: **(A) build** link-based trip sharing that needs no server, and **(B) write** a design doc for real-time group sync. Do not build part B.

## Read first

- `Monetic/Models/Trip.swift`, `SavingsContribution` and `Monetic/Trips/SavingsPlan.swift`.
- `Monetic/Views/TripDetailView.swift`, `AddTripView.swift`.
- `Monetic/Estimating/TripEstimator.swift`.
- `Monetic/MoneticApp.swift`.

## Ground rules

1. **No server, no accounts, no third-party SDKs** in part A.
2. **Share the plan, never the money.** A shared trip contains the plan (name, destination, location ID, dates, travelers, style, estimate breakdown, per-person goal). It never contains anyone's contributions, notes or budget.
3. **Treat incoming links as untrusted input.** Validate every field on import (lengths, date order, travelers 1–20, finite non-negative amounts, known style and location IDs). Reject anything invalid with a friendly message and never crash.
4. Design system only, `project.pbxproj` wiring, existing behavior and tests unchanged.

## Part A: Build link-based sharing

### 1. Encoding
- `Monetic/Trips/TripShare.swift`: a `Codable` `TripSharePayload` with a `version: Int` field, encoded as compact JSON → base64url, carried in a URL.
- Pick one URL form and explain the trade-off in your summary: a custom scheme (`monetic://trip?d=…`, works today, no domain needed) or a universal link (needs a domain and an `apple-app-site-association` file, which I'll have to set up; if you choose this, list the exact steps for me and keep the custom scheme as a fallback). Default to the custom scheme.
- Keep the URL short enough for iMessage (target under 1,000 characters for a typical trip); add a test that asserts this for a realistic trip.

### 2. Sharing out
- In `TripDetailView`, an "Invite friends" button using `ShareLink` with a message like "I'm planning Spring Break in Cancún, Mar 14–21. About $640 each. Join the plan in Monetic: <link>".
- Record `sharedAt` and a stable `shareID: UUID` on the trip, so friends importing the same link end up with the same `shareID`.

### 3. Importing
- Handle the URL with `.onOpenURL` on the root view. Show a preview sheet ("Join this trip?") with the plan and the per-person goal, and let the user edit their own share of the goal before saving.
- Importing a link for a `shareID` the user already has offers "Update plan" instead of creating a duplicate, and never touches their contributions.
- The imported trip starts with zero savings and the user's own cadence.

### 4. Lightweight group view
- On a shared trip, show "Planned with friends" and the traveler count from the plan. Don't show other people's progress: there's no sync yet, and the UI must not imply there is.

### 5. Tests
- Round-trip encode/decode; version handling (a `version: 2` payload is rejected with an "update the app" message); every validation rule; malformed base64 and JSON; oversized fields; duplicate import updates in place; contributions are untouched by an update; URL length budget.
- UI test: launch with a share URL (pass it via a `-UITestingOpenURL` DEBUG launch argument that the app handles like `.onOpenURL`), confirm the preview, join, and see the trip in the list.

## Part B: Write (don't build) the sync design

File: `docs/design/group-trips-sync.md`

Compare, for an iOS-first app with a solo developer and a student budget:
1. **CloudKit sharing** (`CKShare`). Note that SwiftData doesn't support CloudKit shared databases today, so cover what that means: a separate Core Data / `NSPersistentCloudKitContainer` store for shared trips, or CloudKit directly. Cost, Android story (none), auth (Apple ID only).
2. **A hosted backend** such as Supabase or Firebase. Accounts, cost at 1k / 10k / 100k users, Android/web reach, data privacy obligations.
3. **Staying link-based** plus a tiny stateless endpoint for richer previews.

For each: what data is shared and with whom, conflict handling when two people edit a plan, privacy (contributions stay private by default; showing progress is opt-in), effort in weeks, and what breaks for users who never sign in. End with a recommendation and the metric that should trigger building it (for example: share of trips with at least one import).

## Done when

- A trip shared from one simulator imports correctly on another (describe how you verified, e.g. `xcrun simctl openurl`).
- Bad links never crash the app; every validation path is covered by a test.
- `scripts/test.sh` and `scripts/test.sh ui` pass.
- The design doc exists, makes a recommendation, and names the trigger metric.
- Your final message lists: the URL scheme chosen and why, files changed, any setup steps I need to do, and anything deferred.
