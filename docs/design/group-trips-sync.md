# Group trips: should we sync, and how?

Status: proposal. Nothing here is built.
Context: Monetic is iOS-first, built by one developer on a student budget. Today trips are shared with links (`monetic://trip?d=…`, see `Monetic/Trips/TripShare.swift`). A link carries the plan (name, destination, dates, travelers, style, total, each person's share and the estimate breakdown) and never carries money: no contributions, no notes, no budget. Each person who opens the link gets an independent copy. Nothing syncs.

The question is what to build if people want more than that: plan changes that reach everyone, or (opt-in) seeing how the group is doing.

## Ground rules any option must keep

- **Contributions stay private by default.** Nobody sees what anyone else saved unless that person turns it on, per trip, and can turn it off again.
- **Opt-in progress is coarse.** When someone does share, show a percentage or "on track / behind", not amounts or individual deposits.
- **The app keeps working alone.** Budgeting, trips and savings never require an account or a network.
- **Links keep working.** Whatever we add, the link stays the way to invite someone, and old links still import.

## Option 1: CloudKit sharing (`CKShare`)

**How it works.** The organizer's trip lives in a custom zone in their private CloudKit database. Sharing it creates a `CKShare`. Invitees accept through the system sheet and see the zone in their *shared* database.

**SwiftData can't do this today.** SwiftData's CloudKit integration only mirrors the private database, with no shared-database or `CKShare` support. So the shared trips would need either:
- a second store using Core Data with `NSPersistentCloudKitContainer` (which does support shared stores), mirrored into or alongside the SwiftData models; or
- **CloudKit directly through `CKSyncEngine`** (iOS 17+, which matches our deployment target). We would own the record mapping, but there's no second persistence stack.

`CKSyncEngine` is the better of the two. Two persistence frameworks for one model is a lasting source of bugs. With `CKSyncEngine`, SwiftData stays the local source of truth and a small sync layer pushes and pulls the shared records.

**What's shared, with whom.** Only people the organizer invites, each identified by Apple ID.
- `TripPlan` record, in the organizer's zone: name, destination, dates, travelers, style, total, breakdown. Only the organizer edits it; participants can read it.
- `ParticipantProgress` record, one per person who opts in: percent saved and status only. Each person writes only their own.
- Contributions never leave the device's private data. They aren't even in the private CloudKit database unless we add personal iCloud backup separately.

**Conflicts.** Plan edits come only from the organizer, so the only conflict is the organizer editing on two devices. Handle it with CloudKit's server change tag: on `serverRecordChanged`, re-apply our edit to the server's record field by field, last write wins per field. Progress records have a single writer, so they can't conflict. A participant's own goal override stays local (we already let people set their own share), so plan updates never overwrite it.

**Cost.** Effectively free. It needs the Apple Developer Program ($99/yr), which shipping requires anyway. Private and shared data counts against the *organizer's* iCloud storage, and the records are tiny (well under 10 KB per trip). Public-database quotas don't apply.

**Reach and auth.** Apple ID only, so there's no Android and no web. iOS users who aren't signed in to iCloud, or have iCloud off for Monetic, can't accept a share.

**Privacy obligations.** Low. Apple hosts the data in the users' own iCloud accounts, and we never see it. The App Store privacy label and privacy policy still need to say that trip plans sync through iCloud.

**Effort: about 5–7 weeks** solo:
- 1 week: spike on `CKSyncEngine` and the zone and record design.
- 2 weeks: the sync layer, mapping records to and from SwiftData.
- 1 week: the share UI (`UICloudSharingController` or `ShareLink` with a `CKShare`) and accept flow.
- 1 week: opt-in progress.
- 1–2 weeks: testing, which can't be done fully on simulators and needs two real Apple IDs and devices.

**Users who never sign in.** Users with no iCloud fall back to today's link import and get a frozen copy with no updates. Everything else keeps working.

## Option 2: Hosted backend (Supabase or Firebase)

**How it works.** The app gets accounts (Sign in with Apple, plus email or Google for Android/web). Shared trips live in a hosted Postgres (Supabase) or Firestore (Firebase) database with row-level access rules. The app syncs shared trips; everything else stays in SwiftData.

**What's shared, with whom.** Trip members, enforced by row-level security (Supabase) or security rules (Firebase). The same two record types as option 1 (`trip_plans`, `participant_progress`) plus a `trip_members` table. Contributions stay on device.

**Conflicts.** The same model: organizer-only plan edits, an `updated_at` per field (or per record), and last write wins. Each member writes only their own progress row. Offline edits are queued and replayed. That queue is real work: Firestore has it built in, but with Supabase we'd write it ourselves.

**Cost.** Rough figures; check current pricing before deciding.

| Users (MAU) | Supabase | Firebase |
|---|---|---|
| 1k | Free tier ($0), but free projects pause when idle, so plan for Pro at about $25/mo for anything real | Free (Spark) likely enough |
| 10k | Pro, about $25/mo | Probably a few $/mo on Blaze (pay-as-you-go) |
| 100k | Pro, about $25/mo plus usage, so roughly $25–100/mo | Auth beyond the free MAU tier for some providers plus reads and writes: roughly $50–300/mo depending on sync chattiness |

The money is small. The bigger costs are on-call responsibility, a privacy policy that has to be true, and account deletion.

**Reach and auth.** The only option that reaches Android and web, if a non-iOS version is ever on the table. The catch is that it requires accounts:
- The App Store requires in-app account deletion when you offer account creation.
- Sign in with Apple is required if we offer other social logins on iOS.

**Privacy obligations.** The highest of the three. We'd hold personal data (email, Apple or Google IDs, travel dates and destinations) on our servers. That brings:
- a real privacy policy, data-export and deletion handling (GDPR and CCPA style), and breach responsibility;
- an accurate App Store privacy label;
- keys and secrets to manage.

Student users and travel dates together are sensitive.

**Effort: about 7–10 weeks** solo:
- 1 week: auth and account deletion.
- 1 week: schema and access rules, with tests.
- 3 weeks: the sync layer and offline queue.
- 1 week: invite flow, where links become membership tokens.
- 1 week: opt-in progress.
- 1–2 weeks: privacy policy, label and testing.
- Ongoing: ops.

**Users who never sign in.** Links still work as a frozen copy. Group sync needs an account, which some users won't create. Supporting both paths for the same trip (one person synced, another not) is a permanent edge case.

## Option 3: Stay link-based, plus a tiny stateless endpoint

**How it works.** Keep exactly what ships today, and add one serverless function (for example a Cloudflare Worker) on a domain we own:

- `https://<domain>/t?d=…` serves a small HTML page. It decodes the same payload and renders the plan with Open Graph tags, so Messages, WhatsApp and Instagram show a rich preview ("Spring Break · Cancún · Mar 14–21 · about $640 each"). The page has an "Open in Monetic" button and an App Store link.
- An `apple-app-site-association` file on the same domain turns that URL into a **universal link**, so it opens the app directly when installed.
- The app accepts both `monetic://trip?d=` (today) and the https form. The decoder doesn't change; only the scheme check grows.

The endpoint stores nothing. It decodes, validates and renders. It can keep an **anonymous counter** (requests per day, unique hashed share IDs) for the trigger metric below. That needs no accounts and no user data.

**What's shared, with whom.** Anyone the organizer sends the link to, exactly as today. The plan passes through the endpoint when a preview is fetched. It's the plan only (no money), and we don't log it.

**Conflicts.** None, by design. Each person's copy is independent. Re-opening a newer link from the same trip updates the plan in place and never touches savings; this is already built and tested (`TripShareImport.update`). If the organizer changes the plan, they send a new link.

**Cost.** Workers' free tier (about 100k requests/day) covers us far past 100k users. A domain is about $10–15/yr. There's no database.

**Reach.** The web page works on Android and desktop as a read-only plan. Android users can't save toward it in Monetic, but they can see it.

**Privacy obligations.** Minimal: the plan in transit, nothing stored, and a one-line statement in the privacy policy.

**Effort: about 1–1.5 weeks.** That's 2–3 days for the Worker and page, 1 day for the AASA file, Associated Domains and app changes, and 1–2 days for testing on real devices, since universal links don't fully work on simulators.

**Users who never sign in.** Nothing breaks. There's nothing to sign in to.

**Limits.** No live updates. No group progress, even opt-in. The organizer has to re-send after changes.

## Side by side

| | CloudKit | Hosted backend | Links + endpoint |
|---|---|---|---|
| Plan updates reach everyone | Yes | Yes | No, re-send the link |
| Opt-in group progress | Yes | Yes | No |
| Android / web | No | Yes | Read-only web page |
| Accounts | Apple ID (implicit) | Ours, plus deletion flow | None |
| Running cost at 100k users | ~$0 | ~$25–300/mo | ~$0–5/mo plus domain |
| Data we hold | None | Personal data | None |
| Effort (solo) | 5–7 wks | 7–10 wks | 1–1.5 wks |
| Never-signed-in users | Frozen copy via link | Frozen copy via link | Same as everyone |

## Recommendation

**Do option 3 now, and plan option 1 for when the numbers justify it. Skip option 2 unless Android becomes a goal.**

- Option 3 fixes the biggest real weakness of today's links: a bare `monetic://` URL often isn't tappable and has no preview in other apps. It costs about a week and adds no ongoing obligations. It also gives us the anonymous counter, the only way we'll learn whether group trips matter, since **the app has no analytics today.**
- Option 1 is the right sync design for an iOS-only app: no accounts, no servers, no personal data on our side, and private-by-default fits CloudKit's model naturally. Build it with `CKSyncEngine`, not a second Core Data stack.
- Option 2 buys Android and web at the price of accounts, ops and real privacy liability. Not worth it for a solo, iOS-first app unless cross-platform becomes a goal on its own.

## Trigger metric

Build CloudKit sync when, over a rolling 30 days, both of these hold:

1. **Share rate:** at least **20% of trips created** are shared (the trip gets a `sharedAt`), and
2. **Import rate:** at least **30% of shared trips get at least one import within 7 days** (the share ID was opened on another device).

A third signal makes it urgent: people re-share the same trip repeatedly, meaning the same share ID is sent 3 or more times. That's users working around the lack of updates.

How to measure without adding tracking:
- **Import rate, opens:** the Worker's anonymous counter of unique hashed share IDs seen, compared with how many have a preview fetched from a second client, gives a rough number with no app changes.
- **Share rate and imports:** an optional, anonymous, aggregate-only ping from the app ("a trip was shared", "a trip was joined"; no IDs, no amounts), disclosed in the privacy label. Alternatively, ask in a TestFlight survey.

If neither number moves after a semester of real use, links are enough. Stop there.
