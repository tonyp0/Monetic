import SwiftUI
import UIKit

// MARK: - Hex Colors

extension Color {
    /// 0xRRGGBB literal, e.g. `Color(hex: 0x1B6EF3)`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Resolves to a different hex per interface style, so every surface in the app
/// can be declared once and still be correct in both modes.
private func adaptive(light: UInt32, dark: UInt32, opacity: Double = 1) -> Color {
    Color(uiColor: UIColor { traits in
        let hex = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8)  & 0xFF) / 255,
            blue:  CGFloat( hex        & 0xFF) / 255,
            alpha: CGFloat(opacity)
        )
    })
}

// MARK: - Brand

/// The single source of truth for Monetic's visual language: a "pocket
/// notebook" of warm paper, dark ink and one confident accent colour (a sunny
/// amber).
///
/// Amber rule: `accent` for fills and graphics, `accentText` for text and
/// icons, `onAccent` for labels on an amber fill.
/// Values come from `docs/prompts/ui-overhaul/DESIGN-BRIEF.md`; both modes are
/// first-class, and `BrandContrastTests` guards their readability.
enum Brand {

    // MARK: Accent

    /// The amber brand colour, for fills and graphics only: the primary button,
    /// `ProgressRing`, selected chips and segments, tab selection, chart marks
    /// and toggles. Never for text: light amber is too pale to read (3:1).
    static let accent     = adaptive(light: 0xC27C00, dark: 0xF2B13C)
    /// Amber for text and icons on `background` or `surface`: links, toolbar
    /// and plain buttons, secondary buttons. Deep enough to reach 4.5:1.
    static let accentText = adaptive(light: 0x8F5300, dark: 0xF2B13C)
    /// Labels on an `accent` fill: always dark, never white.
    static let onAccent   = adaptive(light: 0x1F1400, dark: 0x1F1400)

    // MARK: Surfaces

    /// Screen background: flat, no gradient.
    static let background    = adaptive(light: 0xF7F5F0, dark: 0x141312)
    /// List groups and the one card a screen may have.
    static let surface       = adaptive(light: 0xFFFFFF, dark: 0x1E1D1B)
    /// Floating elements (the Add button, menus).
    static let surfaceRaised = adaptive(light: 0xFFFFFF, dark: 0x272523)
    /// Input wells and segmented-control tracks.
    static let surfaceSunken = adaptive(light: 0xEFECE5, dark: 0x0F0E0D)

    /// Row dividers only, not card borders.
    static let hairline = adaptive(light: 0x000000, dark: 0xFFFFFF, opacity: 0.08)

    /// Empty part of any progress bar.
    static let track = adaptive(light: 0x000000, dark: 0xFFFFFF, opacity: 0.07)

    // MARK: Text

    static let textPrimary   = adaptive(light: 0x1C1B18, dark: 0xF3F1EC)
    /// Supporting text (meets 4.5:1).
    static let textSecondary = adaptive(light: 0x6B675F, dark: 0xA9A49A)
    /// Placeholders and decoration only, never essential text.
    static let textTertiary  = adaptive(light: 0x9C978D, dark: 0x6E6A63)

    // MARK: Status

    /// Under budget, on track.
    static let positive = adaptive(light: 0x18784F, dark: 0x4CC38A)
    /// Close to budget (80% or more). Burnt orange, so it never reads as the accent.
    static let warning  = adaptive(light: 0xBA3E0C, dark: 0xFB8B5A)
    /// Over budget, destructive actions. Crimson, kept apart from `warning`.
    static let danger   = adaptive(light: 0xB4233A, dark: 0xFF6B81)

    // MARK: Metrics

    /// Two radii only.
    enum Radius {
        /// Tiles, controls, chips.
        static let small: CGFloat = 12
        /// List groups, sheets, the one card.
        static let large: CGFloat = 20

        @available(*, deprecated, message: "Use Radius.small/large")
        static let card: CGFloat = large
        @available(*, deprecated, message: "Use Radius.small/large")
        static let row: CGFloat = large
        @available(*, deprecated, message: "Use Radius.small/large")
        static let control: CGFloat = small
        @available(*, deprecated, message: "Use Radius.small/large")
        static let chip: CGFloat = small
    }

    /// Spacing scale: 4, 8, 12, 16, 24, 32.
    enum Space {
        static let xs: CGFloat  = 4
        static let s: CGFloat   = 8
        static let m: CGFloat   = 12
        static let l: CGFloat   = 16
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
        /// Screen edge inset.
        static let gutter: CGFloat = 16

        @available(*, deprecated, message: "Use Space.xs…xxl")
        static let card: CGFloat = l
        @available(*, deprecated, message: "Use Space.xs…xxl")
        static let tight: CGFloat = s
        @available(*, deprecated, message: "Use Space.xs…xxl")
        static let stack: CGFloat = m
    }

    // MARK: Type
    // Use SF Pro text styles (.body, .headline…) so Dynamic Type works.
    // Rounded is reserved for the single hero amount on a screen.

    /// The one hero amount on a screen. Scales with Dynamic Type.
    static let hero: Font = .system(.largeTitle, design: .rounded, weight: .semibold)

    @available(*, deprecated, message: "Use a text style; Brand.hero for the hero amount")
    static func number(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    @available(*, deprecated, message: "Use a text style such as .headline or .title2")
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Small all-caps labels. Tracking is applied at the call site via `.brandEyebrow()`.
    @available(*, deprecated, message: "Use sentence case: .subheadline in textSecondary")
    static let eyebrow: Font = .system(size: 11, weight: .semibold, design: .rounded)
}

extension View {
    /// Money amounts: monospaced digits so columns line up.
    func moneyStyle() -> some View {
        monospacedDigit()
    }
}
