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

    @Test("Parse rejects number spellings that aren't money amounts", arguments: ["inf", "nan", "1e3", "0x10"])
    func parseRejectsNonDecimalSpellings(_ input: String) {
        // Double(_:) accepts these, so parse() turns "inf" into an infinite
        // amount. Not reachable today because the amount field sanitizes
        // first (see the next test), but parse() alone doesn't guard it.
        withKnownIssue("AmountInput.parse accepts inf/nan/exponent/hex spellings") {
            #expect(AmountInput.parse(input) == nil)
        }
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
