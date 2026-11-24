# Monetic Design Brief

The shared reference for every UI-overhaul step. Prompts in this folder tell Claude to read it before changing anything. Edit this file, not the prompts, to change a decision.

## Who it's for

Students in grades K–12 learning their first money habits, and the parents or teachers next to them. The app should feel **calm, friendly and trustworthy**, like a well-made school notebook rather than a crypto dashboard. A 10-year-old should understand every screen without help.

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

## Direction: "pocket notebook"

Warm paper, dark ink, **one** confident accent colour, and plain sentences instead of labels. Depth comes from background colour steps, not borders and glows.

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
| `amber` | `#C98A0B` | `#E8B04A` | saffron |
| `mint` | `#4F8A4A` | `#8DBA7A` | sage |
| `cyan` | `#1F8A88` | `#4DBDB8` | teal |

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
- **Emoji stay** as group icons: kids like them and they're instantly recognisable. Show them on the category `tint` in a 12pt-radius tile, with no border and no glow.
- **Progress is a bar, not a ring.** One horizontal bar, split by group colour where useful.

### Voice

- Plain, warm, second person, around a grade-4 reading level. Say "You have $240 left for November", not "Remaining balance".
- Prefer a sentence to a label-plus-value pair.
- Empty states say what to do next, in one short line and one button.
- Never say "Expense" as a title. Fall back to the note, then the group name.

### Motion and feel

- Numbers change with `.contentTransition(.numericText())`.
- Springs are short and gentle (`.snappy` or `.smooth`), nothing bouncy.
- Light haptic (`.sensoryFeedback`) on save and delete.
- Respect Reduce Motion everywhere.

## Engineering ground rules (every step)

1. **iOS 17.0+, SwiftUI, no new dependencies.** Don't change the SwiftData models (`Monetic/Models/`).
2. **Keep every accessibility identifier**: `addExpenseButton`, `addTransactionButton`, `addGroupButton`, `amountField`, `budgetAmountField`, `getStartedButton`, `groupMonthlySpent`, `saveBudgetButton`, `saveExpenseButton`, `saveGroupButton`, `settingsButton`, `spentTotal`, `budgetTotal` (the last two are built from a label in `ContentView.swift`, so keep that working if the label changes). If an element moves, its identifier moves with it.
3. **UI tests also match visible text**: "Save Budget", "Get Started", "Done", "Save", "Food & Dining", and amounts like "$6.25". If copy changes, update `MoneticUITests/` in the same step.
4. **The Xcode project doesn't use synchronized folders.** Any new `.swift` file must be added to the right target in `Monetic.xcodeproj/project.pbxproj`. Prove it by building.
5. **Home stays a `List`** so swipe-to-delete and drag-to-reorder keep working.
6. **Stay in scope.** Only change what the current step asks for. Note anything else you spot in the final summary instead of fixing it.
7. **Verify before finishing**: build, run `scripts/test.sh` (unit tests) and `scripts/test.sh ui`, run the screenshot tour from step 0, and look at the light and dark screenshots yourself. Report anything that looks off.
8. Finish with a short summary: what changed, which screenshots to look at, any test changes, and anything deferred.
