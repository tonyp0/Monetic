# Step 3: Shared Components

Rework the shared building blocks so the generic look disappears app-wide before any per-screen redesign.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first, especially **What we're moving away from** and **Components and patterns**. This step changes `Monetic/DesignSystem/BrandComponents.swift`, plus the call-site edits needed to keep things compiling and coherent.

## Read first

- `Monetic/DesignSystem/BrandComponents.swift` (all of it)
- `Monetic/DesignSystem/Brand.swift` (as updated in step 2)
- Call sites: `grep -rn "BrandBackground\|brandCard\|brandEyebrow\|GradientButtonStyle\|SoftButtonStyle\|BudgetRing\|BrandProgressBar\|MoneticWordmark\|CategoryTile\|BrandSectionHeader\|BrandField\|BrandSegmented\|AmountEntryCard" Monetic/`

## Do

1. **`BrandBackground`**: a flat `Brand.background`. No gradient, no glow.
2. **`brandCard()`**: `surface` fill, `Radius.large`, no shadow, a `hairline` border **in dark mode only**.
3. **Buttons**
   - Replace `GradientButtonStyle` with `PrimaryButtonStyle`: solid `accent` fill, `onAccent` label, `.headline`, full width, `Radius.small`, pressed state dims slightly, disabled state uses `track` fill and `textTertiary` label. Keep a `typealias GradientButtonStyle = PrimaryButtonStyle` (deprecated) so nothing breaks before the screens are reworked.
   - Make `SoftButtonStyle` a quiet secondary: `accent` label on `accent` at about 10% opacity, no border.
4. **Labels**: change `brandEyebrow()` to render sentence case in `.subheadline` / `textSecondary` with no tracking, and deprecate it. Then go through every call site. Where the label repeats what's obvious from context (`REMAINING`, `TOTAL`, `BY GROUP`, `AMOUNT`…), delete it. Where it's needed, write it in sentence case. List what you removed in your summary.
5. **Progress**
   - Add `BudgetBar`: a horizontal capsule bar 10–12pt tall on `track`. It takes either a single fraction (coloured `positive`, `warning` at ≥ 80% or `danger` when over) or an array of `(colour, amount)` segments for a split-by-group view, with 2pt gaps between segments. When spending is over budget, the bar is full in `danger` and an overflow label is shown by the caller. Animate width changes with `.smooth` (none under Reduce Motion). Add an accessibility label and value ("62% of budget used").
   - Keep `BudgetRing` compiling, but mark it deprecated; step 4 removes its last use.
   - Bring `BrandProgressBar` in line with `BudgetBar` (or have it wrap it).
6. **`MoneticWordmark`**: if it still has a use, render it as plain `textPrimary` in `.headline` with normal tracking. The gradient belongs to the logo mark only.
7. **`CategoryTile`**: the emoji on `CategoryPalette.tint(for:)`, `Radius.small`, no border, no shadow. Size driven by a parameter with sensible defaults (36pt in rows, 56pt in headers).
8. **`BrandSegmented`** and the appearance selector: the selected segment is a `surface` (light) or `surfaceRaised` (dark) pill on a `surfaceSunken` track with `textPrimary` text, like the native segmented control. No gradient.
9. **`BrandField` / `AmountEntryCard`**: remove the card-in-card look. Fields sit on `surfaceSunken` with `Radius.small`. The amount uses `Brand.hero`.
10. **Toolbar buttons**: wherever the app wraps toolbar buttons in capsule or glass backgrounds, remove that so they render as plain native toolbar items (text in `accent`, the confirm action in `.semibold`).
11. Remove any coloured (`violet`, `accent`) shadows anywhere in the app.

## Don't

- Restructure screen layouts (steps 4–7). Swapping component calls is fine; moving sections around isn't.
- Delete deprecated APIs that are still in use.

## Done when

- The app builds, unit and UI tests pass, and no gradient is visible anywhere except the logo mark: `grep -rn "gradient" Monetic/Views` shows only logo uses or nothing.
- `scripts/screenshots.sh step3`: compare against `step2` and describe the difference screen by screen in both modes.
