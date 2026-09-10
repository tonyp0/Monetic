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

// MARK: - Amount Entry
/// Shared handling for the decimal-pad currency fields.
enum AmountInput {
    /// Strips anything that isn't a digit or the locale decimal separator,
    /// allowing a single separator and at most two decimal places.
    static func sanitize(_ input: String) -> String {
        let separator: Character = Locale.current.decimalSeparator?.first ?? "."
        let allowed: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", separator]
        let filtered = String(input.filter { allowed.contains($0) })
        let parts = filtered.components(separatedBy: String(separator))
        guard parts.count > 1 else { return filtered }
        return parts[0] + String(separator) + String(parts[1].prefix(2))
    }

    /// Parses sanitized input, tolerating either decimal separator.
    static func parse(_ input: String) -> Double? {
        Double(input.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Icons
extension String {
    /// SF Symbol names are ASCII only, so any non-ASCII scalar means an emoji icon.
    var isEmojiIcon: Bool {
        unicodeScalars.contains { $0.value > 127 }
    }
}
