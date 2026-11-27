# Monetic Design Brief

The shared reference for every UI-overhaul step. Prompts in this folder tell Claude to read it before changing anything. Edit this file, not the prompts, to change a decision.

## What Monetic is

Monetic helps **college students afford the trips they want**: know what a trip will really cost, save for it inside their real monthly budget, and plan it with friends. It's still a budgeting app, but **trips are the reason students download it and keep opening it**.

- **Who it's for:** college students, especially groups planning spring break or study abroad.
- **The problem:** students pick trips without knowing the real cost, don't save in time, and end up short, in debt, or covering for friends.
- **What it does:** estimates the trip cost from real, cited data; turns it into a savings plan that fits their monthly budget; counts down to departure; brings their friends into the plan.
- **What makes it different:** it's the only app that connects a trip goal to everyday budgeting, it uses cited cost data instead of guesses, and it spreads from one organizer through a friend group.

### What it's not (keep these out of the UI)

- **Not an in-trip spending tracker** (that's TravelSpend, Trail Wallet). No "log spending while abroad" flows, currency converters or daily travel budgets.
- **Not a bill-splitter** (that's Splitwise). No "who owes whom", no settle-up, no shared expenses. Students can keep using Splitwise once the trip starts.
- **Not a trip planner** (that's Wanderlog). No itineraries, bookings, maps or activity lists.

If a design idea drifts into one of these, drop it.

## Who we're designing for

Students aged roughly 18–23, on a phone, often between classes, usually with less money than they'd like and a group chat full of trip plans. The app should feel **confident, optimistic and honest about money**, like a sharp friend who's good with money: not a bank, not a kids' app, not a hype-y fintech. Every screen should answer one question quickly, usually "Can I afford this?" or "Am I on track?"

## What we're moving away from

The current UI looks generic and machine-generated because of these patterns. None of them should survive the overhaul:

- A navy-to-purple gradient wash behind every screen.
- The cyan-blue-violet-magenta gradient on buttons, the wordmark, the progress ring and selection states.
- Every element in its own bordered, glowing, 22pt-radius card, including cards inside cards.
- Small ALL-CAPS letter-spaced labels everywhere (`REMAINING`, `SPENT`, `BY GROUP`, `AMOUNT`, `DATE`…).
- Two large circles stacked on the home screen (budget ring plus donut) that show the same total.
- Capsule outlines behind every toolbar button (Cancel, Save, Edit, Done, gear).
- Nine neon, high-chroma category colours.
- Rounded SF used for every number and heading.

## Direction: "travel notebook"

Warm paper, dark ink, **one** confident accent colour, and plain sentences instead of labels. Depth comes from background colour steps, not borders and glows. The excitement comes from **the trip itself**, meaning the destination name, the countdown and the progress toward it, never from decoration.

### App structure

- **Trips is the first tab and where the app opens.** Budget is the second tab. Settings is reached from a toolbar button, not a tab.
- The **next upcoming trip** is the hero of the app: destination, countdown, saved vs goal, and what to save next.
- The **Budget tab** answers "how much can I spend this month while still saving for my trip?" It shows trip savings as money set aside, never as spending.

### Appearance

- The app follows the **iOS system appearance** by default. Users can still force Light or Dark in Settings.
- Both modes are first-class, so check every change in both.

### Colour tokens (`Monetic/DesignSystem/Brand.swift`)

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#F7F5F0` | `#141312` | Screen background (flat, no gradient) |
| `surface` | `#FFFFFF` | `#1E1D1B` | List groups, the one card a screen may have |
| `surfaceRaised` | `#FFFFFF` | `#272523` | Floating elements (FAB, menus) |
| `surfaceSunken` | `#EFECE5` | `#0F0E0D` | Input wells, segmented control track |
| `hairline` | black 8% | white 8% | Row dividers only, not card borders |
| `track` | black 7% | white 10% | Empty part of progress bars |
| `textPrimary` | `#1C1B18` | `#F3F1EC` | |
| `textSecondary` | `#6B675F` | `#A9A49A` | Supporting text (meets 4.5:1) |
| `textTertiary` | `#9C978D` | `#6E6A63` | Placeholders and decoration only, never essential text |
| `accent` | `#2B59E0` | `#7FA2FF` | The one brand colour: primary button, links, selection |
| `onAccent` | `#FFFFFF` | `#0E1A3D` | Text and icons on an accent fill |
| `positive` | `#1F8A5B` | `#4CC38A` | Under budget / on track |
| `warning` | `#B26B00` | `#F0B44C` | Close to budget (≥ 80%) |
| `danger` | `#C8372D` | `#FF7A6B` | Over budget, destructive actions |

The logo gradient (`cyan`, `blue`, `violet`, `magenta`) stays defined but is used **only** for the logo mark and app icon.

### Category palette (`Monetic/DesignSystem/CategoryPalette.swift`)

Keep the **stored keys unchanged** (they're saved in user data) and keep the legacy-name mapping. Only the colours change: softer, mid-chroma and earthy, so they sit together without fighting.

| Key | Light | Dark | Reads as |
|---|---|---|---|
| `azure` | `#2F7FD1` | `#6AAAF0` | sky |
| `indigo` | `#5B5BD6` | `#8E8CF0` | iris |
| `violet` | `#7D5BBE` | `#AB8FE6` | lavender |
| `magenta` | `#9A4A9E` | `#C77FCB` | plum |
| `rose` | `#C2477A` | `#E68AAE` | berry |
| `coral` | `#D9534A` | `#F07A6E` | tomato |
| `amber` | `#C7880B` | `#E8B04A` | saffron |
| `mint` | `#4F8A4A` | `#8DBA7A` | sage |
| `cyan` | `#1F8A88` | `#4DBDB8` | teal |

Light `amber` was darkened slightly from `#C98A0B` to `#C7880B` so it reaches 3:1 on white (`BrandContrastTests` checks every pair).

Each hue also gets a **tint** (the hue at about 14% opacity over `surface`) for icon tile backgrounds.

### Type

- Use **SF Pro text styles** (`.largeTitle`, `.title2`, `.headline`, `.body`, `.subheadline`, `.footnote`) so Dynamic Type works. No fixed point sizes for text, except through `@ScaledMetric`.
- **Money amounts** use `.monospacedDigit()` so columns line up.
- The **rounded design** is reserved for the single hero amount on a screen (the home screen's remaining amount, the big amount on entry screens).
- **Sentence case everywhere.** No all-caps, no letter-spacing. Most labels can go entirely; where one is needed, use `.subheadline` in `textSecondary`.

### Shape and space

- Two radii only: `Radius.small = 12` (tiles, controls, chips) and `Radius.large = 20` (list groups, sheets, the one card).
- Spacing scale: 4, 8, 12, 16, 24, 32. Screen gutter: 16.
- No borders on surfaces in light mode. A `hairline` border on `surface` is allowed in dark mode only.
- Shadows only on things that float above content (the floating Add button, popovers): soft, neutral, never coloured.

### Components and patterns

- **Lists over cards.** Related rows live in one grouped list section with dividers, not in separate floating cards.
- **One card per screen at most**, and never a card inside a card.
- **One filled button per screen** (the primary action) in solid `accent`. Everything else is plain text-style or `.bordered` tinted.
- **Toolbar buttons are plain** text or SF Symbols with no capsule background, as in native iOS.
- **Emoji stay** as spending-group icons: they're quick to scan and students like them. Show them on the category `tint` in a 12pt-radius tile, with no border and no glow. Trips use the destination country's **flag emoji** when the country is known, and an SF Symbol (`airplane`) otherwise.
- **Two kinds of progress, two shapes.** Saving toward a **trip goal** uses a ring (`ProgressRing`, solid `accent`, no gradient): it's the app's signature, and only trip savings get it. **Monthly budgets** use a horizontal bar (`BudgetBar`), split by group colour where useful. Never show both for the same number.
- **The countdown is a number, not a widget.** "108 days" in `Brand.hero`, with the destination name above it. No flip-clocks, boarding-pass mockups, stamps, maps or stock travel photos.
- **Status chips** ("On track", "Behind", "Funded") are small sentence-case capsules: tint background at about 14%, text in the status colour. Always pair the colour with the word.
- **Cited numbers show their source.** Any estimate built from data has a one-line footnote naming the source and its effective date. Numbers the user typed are marked as theirs ("You entered").

### Voice

- Talk like a friend who's good with money: direct, short, second person, a little warm, never preachy, never cutesy. No exclamation marks except for real wins ("Fully funded!").
- Lead with the answer: "Cancún in 108 days", "Save $42 a week to make it", "You're $60 behind. Put in $102 this week to catch up."
- **Be honest.** If a plan isn't realistic, say so plainly and give the two real options (save more, or change the goal or dates). Never guilt or shame.
- Prefer a sentence to a label-plus-value pair. Say "You have $240 left for November", not "Remaining balance".
- Empty states sell the next step in one line and one button: "Where do you want to go? Find out what it'll cost." → **Plan a trip**.
- Never say "Expense" as a title. Fall back to the note, then the group name.
- Group copy is about planning together, never about who owes what.

### Motion and feel

- Numbers change with `.contentTransition(.numericText())`.
- Springs are short and gentle (`.snappy` or `.smooth`), nothing bouncy.
- Light haptic (`.sensoryFeedback`) on save and delete.
- Respect Reduce Motion everywhere.

## Engineering ground rules (every step)

1. **iOS 17.0+, SwiftUI, no new dependencies.** Don't change SwiftData models (`Monetic/Models/`, `Trip`, `SavingsContribution`) or the trip estimator and savings-plan maths. This overhaul changes how things look and read, not what they calculate.
2. **Keep every accessibility identifier**: `tripsTab`, `addTripButton`, `saveTripButton`, `tripRow_<name>` (and any others the Trips prompts added; check `grep -rn accessibilityIdentifier Monetic/`), `addExpenseButton`, `addTransactionButton`, `addGroupButton`, `amountField`, `budgetAmountField`, `getStartedButton`, `groupMonthlySpent`, `saveBudgetButton`, `saveExpenseButton`, `saveGroupButton`, `settingsButton`, `spentTotal`, `budgetTotal` (the last two are built from a label in `ContentView.swift`, so keep that working if the label changes). If an element moves, its identifier moves with it.
3. **UI tests also match visible text**: "Save Budget", "Get Started", "Done", "Save", "Food & Dining", and amounts like "$6.25". If copy changes, update `MoneticUITests/` in the same step.
4. **The Xcode project doesn't use synchronized folders.** Any new `.swift` file must be added to the right target in `Monetic.xcodeproj/project.pbxproj`. Prove it by building.
5. **Lists that support swipe-to-delete or reorder stay `List`s** (budget groups, trips, contributions, expenses).
6. **Stay in scope.** Only change what the current step asks for. Note anything else you spot in the final summary instead of fixing it.
7. **Verify before finishing**: build, run `scripts/test.sh` (unit tests) and `scripts/test.sh ui`, run `scripts/screenshots.sh <step label>` (the tour from step 0; if automatic simulator selection fails, pass `DESTINATION='id=<simulator UDID>'`; if a launch fails with a "preflight checks (Busy)" error, shut down and reboot the simulator cleanly and rerun), and look at the light and dark screenshots yourself. Report anything that looks off.
8. Finish with a short summary: what changed, which screenshots to look at, any test changes, and anything deferred.
