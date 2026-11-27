import SwiftUI
import UIKit

/// The hues a group can be tinted with.
///
/// Softer, mid-chroma, earthy hues that sit together without fighting. Each is
/// at least 3:1 against `Brand.surface` in both modes, since they're used as
/// graphics (`BrandContrastTests`).
enum CategoryPalette {

    /// Stable keys stored on `BudgetCategory.color`.
    static let keys = [
        "azure", "magenta", "mint", "amber",
        "violet", "cyan", "rose", "indigo", "coral"
    ]

    private static let hues: [String: (light: UInt32, dark: UInt32)] = [
        "azure":   (0x2F7FD1, 0x6AAAF0), // sky
        "indigo":  (0x5B5BD6, 0x8E8CF0), // iris
        "violet":  (0x7D5BBE, 0xAB8FE6), // lavender
        "magenta": (0x9A4A9E, 0xC77FCB), // plum
        "rose":    (0xC2477A, 0xE68AAE), // berry
        "coral":   (0xD9534A, 0xF07A6E), // tomato
        "amber":   (0xC7880B, 0xE8B04A), // saffron
        "mint":    (0x4F8A4A, 0x8DBA7A), // sage
        "cyan":    (0x1F8A88, 0x4DBDB8), // teal
    ]

    /// Maps the system color names stored by earlier versions onto the new
    /// palette. Nothing is rewritten on disk — resolution happens at read time,
    /// so existing groups simply start rendering in the new hues.
    private static let legacy: [String: String] = [
        "blue": "azure", "teal": "cyan", "green": "mint", "mint": "mint",
        "orange": "amber", "yellow": "amber", "brown": "amber",
        "purple": "violet", "pink": "rose", "red": "coral",
        "indigo": "indigo", "cyan": "cyan", "gray": "azure", "grey": "azure",
    ]

    /// Resolves a stored color string — new key, legacy system name, or
    /// anything unrecognized — to a brand hue. Never fails.
    static func color(for stored: String) -> Color {
        let key = resolvedKey(for: stored)
        guard let hue = hues[key] else { return Brand.accent }
        return adaptiveHue(hue)
    }

    /// The group's hue at about 14% opacity, for icon tile backgrounds.
    static func tint(for stored: String) -> Color {
        color(for: stored).opacity(0.14)
    }

    /// The hue to assign to the nth group created, cycling so that consecutive
    /// groups never land on neighbouring hues.
    static func key(forIndex index: Int) -> String {
        guard !keys.isEmpty else { return "azure" }
        return keys[abs(index) % keys.count]
    }

    private static func resolvedKey(for stored: String) -> String {
        let normalized = stored.lowercased()
        if hues[normalized] != nil { return normalized }
        if let mapped = legacy[normalized] { return mapped }
        // Unknown value (hand-edited data, a future key): hash it so the same
        // group always gets the same hue instead of flickering between launches.
        let bucket = abs(normalized.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 100_000 })
        return keys[bucket % keys.count]
    }

    private static func adaptiveHue(_ hue: (light: UInt32, dark: UInt32)) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? hue.dark : hue.light
            return UIColor(
                red:   CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8)  & 0xFF) / 255,
                blue:  CGFloat( hex        & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
