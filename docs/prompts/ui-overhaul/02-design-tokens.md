# Step 2: Design Tokens

Swap the colour, type and shape tokens while keeping their names, so every screen picks up the new look before any layout work.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first. This step implements its **Colour tokens**, **Category palette**, **Type** and **Shape and space** sections in the token files. Layout and components come later.

## Read first

- `Monetic/DesignSystem/Brand.swift`
- `Monetic/DesignSystem/CategoryPalette.swift`
- `grep -rn "Brand\.\|CategoryPalette" Monetic/` to see how each token is used.

## Do

1. **`Brand.swift`**
   - Set every surface, text, accent and status colour to the brief's light and dark values via the existing `adaptive(light:dark:)` helper. Add `onAccent`.
   - Keep `cyan`, `blue`, `violet`, `magenta` and the gradients, but mark them with a doc comment as **logo and app icon only**. Don't delete them yet; components still use them until step 3.
   - Replace `Radius` with `small = 12` and `large = 20`. To avoid touching every view now, keep `card`, `row`, `control` and `chip` as deprecated aliases (`@available(*, deprecated, message: "Use Radius.small/large")`) pointing to the nearest new value: card and row → large, control and chip → small.
   - Replace `Space` with the 4/8/12/16/24/32 scale (`xs`, `s`, `m`, `l`, `xl`, `xxl`) and `gutter = 16`, keeping the old names as deprecated aliases in the same way.
   - Type: add a `Brand.hero` font helper (rounded, semibold, scaled with Dynamic Type via `Font.system(.largeTitle, design: .rounded)` or a `@ScaledMetric`-friendly API) for the single hero amount, and a `.moneyStyle()` view modifier that applies `.monospacedDigit()`. Deprecate `number(_:)`, `display(_:)` and `eyebrow`, but leave them working.
2. **`CategoryPalette.swift`**: change only the hex values to the brief's table. **Keep the stored keys and the legacy mapping exactly as they are.** Add `CategoryPalette.tint(for:)`, returning the hue at about 14% opacity, for icon tiles.
3. **Check contrast.** Write a throwaway script or a unit test that computes WCAG contrast for `textPrimary` and `textSecondary` on `background` and `surface`, and `accent` on `surface`, plus `onAccent` on `accent`, in both modes. Each must be at least 4.5:1. Also check every category hue against `surface` is at least 3:1 (they're used as graphics). If a value fails, adjust it minimally, update `DESIGN-BRIEF.md` to match, and say so.

## Don't

- Restructure any view or component. Deprecation warnings at call sites are expected and are cleaned up in steps 3–8.
- Rename or migrate stored category keys.

## Done when

- The app builds and all tests pass.
- `scripts/screenshots.sh step2` runs. Compare it against `screenshots/before/`: colours are calmer and warmer in both modes, though the layout is unchanged. Call out any screen where the new colours make something unreadable.
