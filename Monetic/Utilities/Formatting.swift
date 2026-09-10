import Foundation

// MARK: - Currency
enum Currency {
    /// Currency code for the user's locale, falling back to USD.
    static var code: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// Currency symbol for the user's locale, falling back to "$".
    static var symbol: String {
        Locale.current.currencySymbol ?? "$"
    }
}

// MARK: - Month Keys
/// Handles the "yyyy-MM" string used to track which month a budget was set for.
enum MonthKey {
    /// Fixed-format parsing must not follow the user's calendar, or the stored
    /// key would change meaning between locales.
    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    /// Display formatting follows the user's locale.
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    /// "yyyy-MM" identifier for the month containing `date`.
    static func key(for date: Date = Date()) -> String {
        keyFormatter.string(from: date)
    }

    /// "September 2026" for a date.
    static func displayName(for date: Date = Date()) -> String {
        displayFormatter.string(from: date)
    }

    /// "September 2026" for a stored key, or the raw key if it can't be parsed.
    static func displayName(forKey key: String) -> String {
        guard let date = keyFormatter.date(from: key) else { return key }
        return displayFormatter.string(from: date)
    }
}

// MARK: - Icons
extension String {
    /// SF Symbol names are ASCII only, so any non-ASCII scalar means an emoji icon.
    var isEmojiIcon: Bool {
        unicodeScalars.contains { $0.value > 127 }
    }
}
