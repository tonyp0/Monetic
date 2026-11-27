import SwiftUI
import Testing
import UIKit
@testable import Monetic

/// WCAG contrast for the brand tokens in both modes, so a later colour tweak
/// can't quietly make text, chips or category graphics unreadable. Encodes the
/// amber rule: accentText for text (4.5:1), accent for fills and graphics (3:1).
@Suite("Brand contrast")
struct BrandContrastTests {
    static let styles: [UIUserInterfaceStyle] = [.light, .dark]

    @Test("Text pairs reach 4.5:1", arguments: styles)
    func textPairs(style: UIUserInterfaceStyle) {
        let pairs: [(String, Color, Color)] = [
            ("textPrimary on background", Brand.textPrimary, Brand.background),
            ("textPrimary on surface", Brand.textPrimary, Brand.surface),
            ("textSecondary on background", Brand.textSecondary, Brand.background),
            ("textSecondary on surface", Brand.textSecondary, Brand.surface),
            ("accentText on background", Brand.accentText, Brand.background),
            ("accentText on surface", Brand.accentText, Brand.surface),
            ("onAccent on accent", Brand.onAccent, Brand.accent),
            ("positive on surface", Brand.positive, Brand.surface),
            ("warning on surface", Brand.warning, Brand.surface),
            ("danger on surface", Brand.danger, Brand.surface),
        ]
        for (name, fg, bg) in pairs {
            let ratio = Self.contrast(fg, bg, style)
            #expect(ratio >= 4.5, "\(name) is \(ratio):1 in \(style == .dark ? "dark" : "light")")
        }
    }

    @Test("Accent fills and graphics reach 3:1", arguments: styles)
    func accentGraphics(style: UIUserInterfaceStyle) {
        for (name, bg) in [("background", Brand.background), ("surface", Brand.surface)] {
            let ratio = Self.contrast(Brand.accent, bg, style)
            #expect(ratio >= 3, "accent on \(name) is \(ratio):1 in \(style == .dark ? "dark" : "light")")
        }
    }

    @Test("Status chip text reaches 4.5:1 on its tint over surface", arguments: styles)
    func statusChips(style: UIUserInterfaceStyle) {
        let colors: [(String, Color)] = [
            ("positive", Brand.positive), ("warning", Brand.warning),
            ("danger", Brand.danger), ("accent", Brand.accent),
        ]
        for (name, color) in colors {
            let chip = StatusChip(title: name, color: color)
            let tint = Self.blend(color, opacity: 0.14, over: Brand.surface, style)
            let ratio = Self.contrast(Self.rgb(chip.textColor, style), tint)
            #expect(ratio >= 4.5, "\(name) chip is \(ratio):1 in \(style == .dark ? "dark" : "light")")
        }
    }

    @Test("An accent chip writes its text in accentText")
    func accentChipUsesAccentText() {
        #expect(StatusChip(title: "On track", color: Brand.accent).textColor == Brand.accentText)
        #expect(StatusChip(title: "Ahead", color: Brand.positive).textColor == Brand.positive)
    }

    @Test("Every category hue reaches 3:1 on surface", arguments: styles)
    func categoryHues(style: UIUserInterfaceStyle) {
        for key in CategoryPalette.keys {
            let ratio = Self.contrast(CategoryPalette.color(for: key), Brand.surface, style)
            #expect(ratio >= 3, "\(key) is \(ratio):1 in \(style == .dark ? "dark" : "light")")
        }
    }

    @Test("Self-check: black on white is 21:1")
    func formula() {
        #expect(abs(Self.contrast(.black, .white, .light) - 21) < 0.01)
    }

    typealias RGB = (r: Double, g: Double, b: Double)

    static func contrast(_ a: Color, _ b: Color, _ style: UIUserInterfaceStyle) -> Double {
        contrast(rgb(a, style), rgb(b, style))
    }

    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func rgb(_ color: Color, _ style: UIUserInterfaceStyle) -> RGB {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &alpha)
        return (Double(r), Double(g), Double(b))
    }

    /// `color` at `opacity` composited over an opaque background.
    static func blend(_ color: Color, opacity: Double, over background: Color, _ style: UIUserInterfaceStyle) -> RGB {
        let f = rgb(color, style), b = rgb(background, style)
        return (f.r * opacity + b.r * (1 - opacity),
                f.g * opacity + b.g * (1 - opacity),
                f.b * opacity + b.b * (1 - opacity))
    }

    static func luminance(_ c: RGB) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }
}
