import SwiftUI
import Testing
import UIKit
@testable import Monetic

/// WCAG contrast for the brand tokens in both modes, so a later colour tweak
/// can't quietly make text or category graphics unreadable.
@Suite("Brand contrast")
struct BrandContrastTests {
    static let styles: [UIUserInterfaceStyle] = [.light, .dark]

    @Test("Text, accent and on-accent pairs reach 4.5:1", arguments: styles)
    func textPairs(style: UIUserInterfaceStyle) {
        let pairs: [(String, Color, Color)] = [
            ("textPrimary on background", Brand.textPrimary, Brand.background),
            ("textPrimary on surface", Brand.textPrimary, Brand.surface),
            ("textSecondary on background", Brand.textSecondary, Brand.background),
            ("textSecondary on surface", Brand.textSecondary, Brand.surface),
            ("accent on surface", Brand.accent, Brand.surface),
            ("onAccent on accent", Brand.onAccent, Brand.accent),
        ]
        for (name, fg, bg) in pairs {
            let ratio = Self.contrast(fg, bg, style)
            #expect(ratio >= 4.5, "\(name) is \(ratio):1 in \(style == .dark ? "dark" : "light")")
        }
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

    static func contrast(_ a: Color, _ b: Color, _ style: UIUserInterfaceStyle) -> Double {
        let la = luminance(a, style), lb = luminance(b, style)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func luminance(_ color: Color, _ style: UIUserInterfaceStyle) -> Double {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &alpha)
        func linear(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}
