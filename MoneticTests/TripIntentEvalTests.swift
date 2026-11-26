import Foundation
import Testing
@testable import Monetic

/// Accuracy eval for "Describe your trip" against the real on-device model.
/// Not part of CI: it only runs when `TRIP_INTENT_EVAL=1` is set, which
/// `scripts/eval-trip-intent/run.sh` does. Cases live in
/// `scripts/eval-trip-intent/trip-intent-cases.json`, bundled into the tests.
///
/// It scores the whole pipeline a user gets: model extraction, then the
/// app's date resolution and destination search. An expected `null` means
/// the field must be left empty, which catches invented values.
@Suite("Trip intent eval", .enabled(if: ProcessInfo.processInfo.environment["TRIP_INTENT_EVAL"] == "1"))
struct TripIntentEvalTests {

    @Test("Score the on-device model on every case")
    func evaluate() async throws {
        let availability = TripAssistant.availability()
        guard #available(iOS 26.0, *), availability == .available else {
            Issue.record("TRIP-INTENT-EVAL model unavailable: \(availability)")
            return
        }
        let store = try #require(CostDataStore.shared)
        let url = try #require(Bundle(for: FixtureBundleToken.self).url(forResource: "trip-intent-cases", withExtension: "json"))
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let calendar = Calendar.current
        let today = try #require(Self.day(root["today"] as? String, calendar))
        let nights = root["tripNights"] as? Int ?? 7
        let cases = try #require(root["cases"] as? [[String: Any]])

        let extractor = SystemTripIntentExtractor()
        var right: [String: Int] = [:], total: [String: Int] = [:]
        var perfect = 0, failures = 0

        for (index, testCase) in cases.enumerated() {
            let text = testCase["text"] as? String ?? ""
            let expected = testCase["expected"] as? [String: Any] ?? [:]
            var draft = TripDraft.new(asOf: today, calendar: calendar)
            draft.endDate = calendar.date(byAdding: .day, value: nights, to: draft.startDate) ?? draft.endDate

            var fill = TripAssistant.Fill()
            var failure = ""
            do {
                let intent = try await TripAssistant.extract(text, using: extractor, today: today, calendar: calendar,
                                                             timeout: .seconds(30))
                fill = TripAssistant.apply(intent, text: text, to: &draft, store: store, today: today, calendar: calendar)
            } catch {
                failures += 1
                failure = " [error: \(error)]"
            }

            var misses: [String] = []
            for (field, want) in expected.sorted(by: { $0.key < $1.key }) {
                let got = Self.actual(field, draft: draft, fill: fill, store: store, calendar: calendar)
                let ok = Self.matches(field, want: want, got: got, draft: draft, store: store)
                total[field, default: 0] += 1
                if ok { right[field, default: 0] += 1 } else { misses.append("\(field) expected \(Self.describe(want)) got \(got ?? "nothing")") }
            }
            if misses.isEmpty { perfect += 1 }
            print(String(format: "TRIP-INTENT-EVAL case %02d %@ %@%@ | %@", index + 1, misses.isEmpty ? "✓" : "✗",
                         misses.joined(separator: "; "), failure, text))
        }

        func pct(_ a: Int, _ b: Int) -> String { String(format: "%d/%d (%.1f%%)", a, b, b == 0 ? 0 : Double(a) / Double(b) * 100) }
        for field in total.keys.sorted() {
            print("TRIP-INTENT-EVAL field \(field) \(pct(right[field, default: 0], total[field]!))")
        }
        print("TRIP-INTENT-EVAL fields \(pct(right.values.reduce(0, +), total.values.reduce(0, +)))")
        print("TRIP-INTENT-EVAL cases fully right \(pct(perfect, cases.count)); extraction errors or timeouts \(failures)")
    }

    // MARK: Scoring

    /// What the form ended up with for a field, as text; nil when the
    /// assistant didn't fill it.
    private static func actual(_ field: String, draft: TripDraft, fill: TripAssistant.Fill,
                               store: CostDataStore, calendar: Calendar) -> String? {
        switch field {
        case "destination": return fill.destination == nil ? nil : (draft.locationID ?? draft.destination)
        case "start": return fill.startDate.map { dayString($0, calendar) }
        case "end": return fill.endDate.map { dayString($0, calendar) }
        case "travelers": return fill.travelers.map(String.init)
        case "style": return fill.style?.rawValue
        case "flights": return fill.flightsText.flatMap(AmountInput.parse).map { String(format: "%.2f", $0) }
        default: return nil
        }
    }

    private static func matches(_ field: String, want: Any, got: String?, draft: TripDraft, store: CostDataStore) -> Bool {
        if want is NSNull { return got == nil }
        guard let got else { return false }
        switch want {
        case let place as [String: Any]:
            if let id = place["locationID"] as? String {
                // Picked, or offered among the choices when the name is ambiguous.
                return draft.locationID == id
                    || (draft.locationID == nil && store.search(draft.destination, limit: 5).contains { $0.id == id })
            }
            let text = place["text"] as? String ?? ""
            return draft.locationID == nil && draft.destination.localizedCaseInsensitiveContains(text)
        case let number as NSNumber where field == "flights":
            return got == String(format: "%.2f", number.doubleValue)
        case let number as NSNumber:
            return got == number.stringValue
        case let text as String:
            return got == text
        default:
            return false
        }
    }

    private static func describe(_ want: Any) -> String {
        if want is NSNull { return "nothing" }
        if let place = want as? [String: Any] { return (place["locationID"] ?? place["text"]).map { "\($0)" } ?? "?" }
        return "\(want)"
    }

    private static func dayString(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func day(_ text: String?, _ calendar: Calendar) -> Date? {
        guard let parts = text?.split(separator: "-").compactMap({ Int($0) }), parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}
