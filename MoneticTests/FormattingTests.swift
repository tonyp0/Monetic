import Foundation
import Testing
@testable import Monetic

/// Amount entry, month keys, currency, and icons. Separator-sensitive tests
/// read the simulator's decimal separator so they pass in any locale.
@Suite("Formatting")
struct FormattingTests {
    private let sep = TestSupport.decimalSeparator

    // MARK: AmountInput.sanitize

    @Test("Sanitize strips letters and symbols")
    func sanitizeStripsNonDigits() {
        #expect(AmountInput.sanitize("$1a2b3!") == "123")
    }

    @Test("Sanitize keeps only the first decimal separator")
    func sanitizeKeepsOneSeparator() {
        #expect(AmountInput.sanitize("1\(sep)2\(sep)3") == "1\(sep)2")
    }

    @Test("Sanitize cuts off anything past two decimal places")
    func sanitizeTruncatesToCents() {
        #expect(AmountInput.sanitize("12\(sep)345") == "12\(sep)34")
    }

    @Test("Sanitize keeps a trailing separator so the user can keep typing")
    func sanitizeKeepsTrailingSeparator() {
        #expect(AmountInput.sanitize("5\(sep)") == "5\(sep)")
    }

    @Test("Sanitize leaves empty input empty")
    func sanitizeEmpty() {
        #expect(AmountInput.sanitize("") == "")
    }

    // MARK: AmountInput.parse

    @Test("Parse accepts a dot or a comma as the decimal separator", arguments: ["12.5", "12,5"])
    func parseEitherSeparator(_ input: String) {
        #expect(AmountInput.parse(input) == 12.5)
    }

    @Test("Parse returns nil for text that isn't a number", arguments: ["", "abc", "12.5.1", "$5"])
    func parseRejectsGarbage(_ input: String) {
        #expect(AmountInput.parse(input) == nil)
    }

    @Test("Parse rejects number spellings that aren't money amounts", arguments: ["inf", "nan", "1e3", "0x10", "+5", " 5"])
    func parseRejectsNonDecimalSpellings(_ input: String) {
        // Double(_:) accepts most of these, which once let parse() turn "inf"
        // into an infinite amount.
        #expect(AmountInput.parse(input) == nil)
    }

    @Test("Parse still reads negative amounts so the Save button can reject them")
    func parseReadsNegative() {
        #expect(AmountInput.parse("-5") == -5)
    }

    @Test("Sanitizing first turns non-decimal spellings into nothing parseable", arguments: ["inf", "nan", "infinity"])
    func sanitizeThenParseRejectsNonDecimalSpellings(_ input: String) {
        #expect(AmountInput.parse(AmountInput.sanitize(input)) == nil)
    }

    // MARK: MonthKey

    @Test("Month key is year-month with a four-digit year and two-digit month", arguments: [
        (year: 2026, month: 3, expected: "2026-03"),
        (year: 2025, month: 12, expected: "2025-12"),
    ])
    func monthKeyFormat(_ example: (year: Int, month: Int, expected: String)) throws {
        // Built in the Gregorian calendar so the expected key holds even on a
        // simulator set to another calendar.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .current
        let date = try #require(gregorian.date(from: DateComponents(year: example.year, month: example.month, day: 15, hour: 12)))

        #expect(MonthKey.key(for: date) == example.expected)
    }

    @Test("Month display name falls back to the raw key when it can't be read", arguments: ["", "not-a-month", "March 2026"])
    func monthDisplayNameFallback(_ key: String) {
        #expect(MonthKey.displayName(forKey: key) == key)
    }

    @Test("Month display name for a valid key matches the name for that month's date")
    func monthDisplayNameForValidKey() throws {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .current
        let date = try #require(gregorian.date(from: DateComponents(year: 2026, month: 3, day: 1)))

        #expect(MonthKey.displayName(forKey: "2026-03") == MonthKey.displayName(for: date))
        #expect(MonthKey.displayName(forKey: "2026-03") != "2026-03")
    }

    // MARK: isEmojiIcon

    @Test("Emoji icons are recognized as emoji", arguments: ["🍔", "💰", "✈️", "🧳"])
    func emojiIcons(_ icon: String) {
        #expect(icon.isEmojiIcon)
    }

    @Test("SF Symbol names aren't emoji", arguments: ["tag", "fork.knife", "cart.fill", ""])
    func symbolIcons(_ icon: String) {
        #expect(icon.isEmojiIcon == false)
    }
}

/// Writes to UserDefaults, so these run one at a time and put the previous
/// value back afterwards.
@Suite("Currency", .serialized)
struct CurrencyTests {
    private static let key = "selectedCurrencyCode"

    private func withStoredCurrency(_ value: String?, _ body: () -> Void) {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: Self.key)
        defer { defaults.set(previous, forKey: Self.key) }

        defaults.set(value, forKey: Self.key)
        body()
    }

    @Test("Currency code uses the currency picked in Settings")
    func prefersStoredCode() {
        withStoredCurrency("EUR") {
            #expect(Currency.code == "EUR")
        }
    }

    @Test("Currency code falls back to the device's currency when none is picked", arguments: [nil, ""] as [String?])
    func fallsBackToLocale(_ stored: String?) {
        withStoredCurrency(stored) {
            #expect(Currency.code == (Locale.current.currency?.identifier ?? "USD"))
        }
    }
}

/// More currencies: the list, decimal places, and amount entry per currency.
/// Names and order use a fixed locale; the device region never matters.
@Suite("Currency options")
struct CurrencyOptionsTests {
    private let en = Locale(identifier: "en_US")
    private let sep = TestSupport.decimalSeparator

    @Test("Options include the usual currencies, once each, and no three-decimal ones")
    func options() {
        let options = Currency.options(locale: en, device: "USD")
        for code in ["USD", "EUR", "MXN", "JPY", "GBP", "INR", "KRW"] {
            #expect(options.contains(code), "\(code)")
        }
        #expect(Set(options).count == options.count, "duplicates")
        for code in ["KWD", "BHD", "OMR", "JOD", "TND"] {
            #expect(!options.contains(code), "\(code) has three decimal places")
        }
        #expect(options.allSatisfy { Currency.fractionDigits(for: $0) <= 2 })
        #expect(options.count > 100)
    }

    @Test("Common currencies come first, then the rest by name")
    func order() {
        let options = Currency.options(locale: en, device: "USD")
        #expect(Array(options.prefix(8)) == ["USD", "EUR", "GBP", "CAD", "AUD", "MXN", "JPY", "INR"])
        let names = options.dropFirst(8).map { Currency.name(for: $0, locale: en) }
        #expect(zip(names, names.dropFirst()).allSatisfy {
            $0.compare($1, options: [.caseInsensitive, .diacriticInsensitive], locale: en) != .orderedDescending
        })
    }

    @Test("The device's own currency joins the common group")
    func deviceInCommon() {
        let options = Currency.options(locale: en, device: "BRL")
        #expect(options[8] == "BRL")
        #expect(options.filter { $0 == "BRL" }.count == 1)
        #expect(Currency.commonOptions(device: "EUR") == Currency.common)
    }

    @Test("Decimal places come from the currency", arguments: [("JPY", 0), ("KRW", 0), ("USD", 2), ("EUR", 2), ("KWD", 3)])
    func fractionDigits(_ code: String, _ digits: Int) {
        #expect(Currency.fractionDigits(for: code) == digits)
    }

    @Test("A stored code that isn't offered falls back to Device Default")
    func unsupportedStoredCode() {
        #expect(Currency.resolve(stored: "MXN", device: "EUR") == "MXN")
        #expect(Currency.resolve(stored: "KWD", device: "EUR") == "EUR")
        #expect(Currency.resolve(stored: "XYZ", device: "EUR") == "EUR")
        #expect(Currency.resolve(stored: "", device: "EUR") == "EUR")
        #expect(Currency.resolve(stored: nil, device: nil) == "USD")
        #expect(!Currency.isSelectable("XYZ"))
    }

    @Test("A three-decimal device currency means US dollars")
    func threeDecimalDevice() {
        #expect(Currency.resolve(stored: nil, device: "KWD") == "USD")
        #expect(Currency.deviceCode("BHD") == "USD")
        #expect(Currency.deviceCode("JPY") == "JPY")
    }

    @Test("Search matches name or code")
    func search() {
        #expect(Currency.matches("MXN", query: "mexican", locale: en))
        #expect(Currency.matches("MXN", query: "mxn", locale: en))
        #expect(Currency.matches("MXN", query: "", locale: en))
        #expect(!Currency.matches("MXN", query: "euro", locale: en))
        #expect(Currency.name(for: "MXN", locale: en) == "Mexican Peso")
    }

    // MARK: Amount entry

    @Test("Yen: no decimals typed, none shown, hundredths unchanged")
    func yenEntry() {
        #expect(AmountInput.sanitize("1500\(sep)5", code: "JPY") == "1500")
        #expect(AmountInput.sanitize("1500\(sep)", code: "JPY") == "1500")
        #expect(AmountInput.sanitize("¥1,5a00", code: "JPY") == (sep == "," ? "1" : "1500"))
        #expect(AmountInput.text(cents: 150_000, code: "JPY") == "1500")
        #expect(AmountInput.text(cents: 150_050, code: "JPY") == "1501")
        #expect(AmountInput.text(cents: 0, code: "KRW") == "0")
        #expect(AmountInput.cents("1500") == 150_000)
    }

    @Test("Re-sanitizing prefilled text never multiplies it", arguments: ["USD", "EUR", "GBP", "JPY", "KRW", "MXN"])
    func prefillRoundTrip(_ code: String) {
        for cents in [0, 1, 99, 150_000, 123_456] {
            let text = AmountInput.text(cents: cents, code: code)
            #expect(AmountInput.sanitize(text, code: code) == text)
            let back = AmountInput.cents(text) ?? -1
            #expect(abs(back - cents) < (Currency.fractionDigits(for: code) == 0 ? 100 : 1), "\(code) \(cents)")
        }
        // A two-decimal value typed before switching to yen: "1500.00" → 1500, not 150000.
        #expect(AmountInput.cents(AmountInput.sanitize("1500\(sep)00", code: "JPY")) == 150_000)
    }

    @Test("Dollars and euros keep two decimals, exactly as before", arguments: ["USD", "EUR", "GBP"])
    func twoDecimals(_ code: String) {
        #expect(AmountInput.sanitize("12\(sep)345", code: code) == "12\(sep)34")
        #expect(AmountInput.text(cents: 150_000, code: code) == "1500\(sep)00")
        #expect(AmountInput.text(cents: -205, code: code) == "-2\(sep)05")
    }
}
