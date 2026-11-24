# Step 1: Follow the System Appearance

A small step: the app should match the iPhone's Light or Dark setting unless the user picks one.

---

Read `docs/prompts/ui-overhaul/DESIGN-BRIEF.md` first. In this step, change **only** how appearance is chosen.

## Read first

- `Monetic/MoneticApp.swift`: `@AppStorage("appAppearance")` defaults to `"dark"`, mapped by `preferredScheme`.
- `Monetic/Views/SettingsView.swift`: the same key (also defaulting to `"dark"`), `appearanceCard`, and `AppearanceSelector` (options are ordered Dark, Light, System).
- `resetSettingsForTesting()` in `MoneticApp.swift` and any tests that touch `appAppearance`.

## Do

1. Make `"system"` the default everywhere the key is declared. Better still, define the key and default once (for example a small `AppAppearance` enum with `rawValue`s `system`/`light`/`dark` and a `colorScheme` property) and use it in both places, so they can't drift apart again.
2. When the value is `system`, `.preferredColorScheme(nil)` must be applied so iOS decides. Unknown stored values also fall back to system.
3. **Existing users:** anyone who explicitly picked Dark or Light keeps their choice, because it's stored. Anyone who never touched the setting has nothing stored and now follows the system. Don't write a migration. Explain this in a code comment.
4. Reorder the selector to **System, Light, Dark**.
5. Replace the "Monetic is designed for dark mode…" caption with something like: "Matches your iPhone unless you pick Light or Dark."
6. Add a unit test for the stored-value → `ColorScheme?` mapping (including an unknown value) in `MoneticTests/`, following the existing Swift Testing style.

## Don't

- Restyle the selector or the Settings screen (that's step 7).

## Done when

- Fresh install with the simulator in Light shows the app in light, and in Dark shows it in dark (check with `xcrun simctl ui booted appearance light|dark`).
- Choosing Light or Dark in Settings overrides it, and choosing System hands control back.
- Unit and UI tests pass.
