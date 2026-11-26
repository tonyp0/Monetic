import Foundation

// MARK: - Currency
/// The currency amounts are labeled with. Monetic never converts: changing it
/// relabels the same stored numbers. Amounts are stored in hundredths, so
/// only currencies with at most two decimal places can be offered.
enum Currency {
    static let storageKey = "selectedCurrencyCode"

    /// The currency picked in Settings, or the device's when none is picked
    /// or the stored code is no longer offered.
    static var code: String {
        resolve(stored: UserDefaults.standard.string(forKey: storageKey), device: Locale.current.currency?.identifier)
    }

    /// The device region's currency, or USD when it has none or it has three
    /// decimal places (see `deviceCodeIsUnsupported`).
    static var deviceCode: String { deviceCode(Locale.current.currency?.identifier) }

    /// True when the device's own currency can't be used (e.g. KWD), so
    /// Device Default means US dollars; Settings says so.
    static var deviceCodeIsUnsupported: Bool {
        Locale.current.currency.map { fractionDigits(for: $0.identifier) > 2 } ?? false
    }

    /// Whether a code can be picked (and so kept as the stored choice).
    static func isSelectable(_ code: String) -> Bool { selectable.contains(code) }

    /// `code` for a stored value a view already observes with @AppStorage.
    static func code(stored: String) -> String {
        resolve(stored: stored, device: Locale.current.currency?.identifier)
    }

    static func resolve(stored: String?, device: String?) -> String {
        if let stored, !stored.isEmpty, selectable.contains(stored) { return stored }
        return deviceCode(device)
    }

    static func deviceCode(_ device: String?) -> String {
        guard let device, fractionDigits(for: device) <= 2 else { return "USD" }
        return device
    }

    /// Currency symbol for the current currency, falling back to "$".
    static var symbol: String { symbol(for: code) }

    static func symbol(for code: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? locale.currencySymbol ?? "$"
    }

    /// Decimal places the currency is written with: 0 for JPY or KRW, 2 for
    /// most, 3 for a few like KWD.
    static func fractionDigits(for code: String) -> Int {
        digitsCache[code] ?? computeDigits(code)
    }

    private static func computeDigits(_ code: String) -> Int {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.maximumFractionDigits
    }

    private static let digitsCache: [String: Int] =
        Dictionary(uniqueKeysWithValues: Locale.commonISOCurrencyCodes.map { ($0, computeDigits($0)) })

    /// Every currency that can be picked. Currencies with three decimal
    /// places (KWD, BHD, OMR, JOD, TND, ...) are left out: amounts are
    /// stored in hundredths, which can't hold their thousandths. Read from
    /// each currency's own decimal places rather than a hand-written list.
    private static let selectable: Set<String> =
        Set(Locale.commonISOCurrencyCodes.filter { computeDigits($0) <= 2 })

    /// The short list shown first, plus the device's own currency.
    static let common = ["USD", "EUR", "GBP", "CAD", "AUD", "MXN", "JPY", "INR"]

    static func commonOptions(device: String?) -> [String] {
        let device = deviceCode(device)
        return common.contains(device) ? common : common + [device]
    }

    /// The picker's order: the common group, then the rest by localized name.
    static var options: [String] { options(locale: .current, device: Locale.current.currency?.identifier) }

    static func options(locale: Locale, device: String?) -> [String] {
        let first = commonOptions(device: device).filter(selectable.contains)
        let rest = selectable.subtracting(first).sorted {
            let a = name(for: $0, locale: locale), b = name(for: $1, locale: locale)
            return a == b ? $0 < $1 : a.compare(b, options: [.caseInsensitive, .diacriticInsensitive], locale: locale) == .orderedAscending
        }
        return first + rest
    }

    /// "Mexican Peso", or the code when the locale has no name for it.
    static func name(for code: String, locale: Locale = .current) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }

    /// Search by name or code, ignoring case and accents.
    static func matches(_ code: String, query: String, locale: Locale = .current) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return code.range(of: query, options: .caseInsensitive) != nil
            || name(for: code, locale: locale).range(of: query, options: [.caseInsensitive, .diacriticInsensitive],
                                                      locale: locale) != nil
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
    /// allowing a single separator and no more decimal places than the
    /// currency has. With none (JPY), the separator and anything after it are
    /// dropped, so "1500.5" becomes "1500", never "15005".
    static func sanitize(_ input: String, code: String = Currency.code) -> String {
        let separator: Character = Locale.current.decimalSeparator?.first ?? "."
        let allowed: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", separator]
        let filtered = String(input.filter { allowed.contains($0) })
        let parts = filtered.components(separatedBy: String(separator))
        guard parts.count > 1 else { return filtered }
        let digits = min(Currency.fractionDigits(for: code), 2)
        guard digits > 0 else { return parts[0] }
        return parts[0] + String(separator) + String(parts[1].prefix(digits))
    }

    /// Text for a pre-filled amount field, with the locale's decimal
    /// separator so later typing isn't stripped by `sanitize`: "2400.50" or
    /// "2400,50", or "2401" for a currency without decimals (rounded half up:
    /// the stored hundredths don't change unless the field is edited).
    static func text(cents: Int, code: String = Currency.code) -> String {
        let separator = Locale.current.decimalSeparator ?? "."
        let sign = cents < 0 ? "-" : ""
        let magnitude = abs(cents)
        switch min(Currency.fractionDigits(for: code), 2) {
        case 0:
            let whole = (magnitude + 50) / 100
            return "\(whole == 0 ? "" : sign)\(whole)"
        case 1:
            let tenths = (magnitude + 5) / 10
            return "\(sign)\(tenths / 10)\(separator)\(tenths % 10)"
        default:
            let fraction = magnitude % 100
            return "\(sign)\(magnitude / 100)\(separator)\(fraction < 10 ? "0" : "")\(fraction)"
        }
    }

    /// The typed amount in whole cents, or nil if it isn't a plain number.
    static func cents(_ input: String) -> Int? {
        parse(input).map { Int(($0 * 100).rounded()) }
    }

    /// Parses sanitized input, tolerating either decimal separator.
    /// Only plain decimal amounts are accepted — `Double(_:)` on its own would
    /// also take "inf", "nan", exponents like "1e3" and hex like "0x10".
    static func parse(_ input: String) -> Double? {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        let unsigned = normalized.hasPrefix("-") ? normalized.dropFirst() : Substring(normalized)
        guard unsigned.allSatisfy({ ("0"..."9").contains($0) || $0 == "." }) else { return nil }
        return Double(normalized)
    }
}

// MARK: - Icons
extension String {
    /// SF Symbol names are ASCII only, so any non-ASCII scalar means an emoji icon.
    var isEmojiIcon: Bool {
        unicodeScalars.contains { $0.value > 127 }
    }
}
