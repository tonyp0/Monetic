import Foundation
import Testing
@testable import Monetic

/// Decoding and searching the per diem dataset: the fixture for behavior, and
/// the real bundled file for "does it ship intact".
@Suite("Per diem data")
struct CostDataStoreTests {
    private let store: CostDataStore

    init() throws {
        store = try TestSupport.fixtureCostData()
    }

    private func names(_ query: String) -> [String] {
        store.search(query).map(\.name)
    }

    // MARK: Decoding

    @Test("The fixture decodes with its sources, aliases and seasons")
    func decodes() throws {
        #expect(store.meta.currency == "USD")
        #expect(store.meta.sources.map(\.id) == ["gsa", "dos"])
        #expect(store.locations.count == 6)

        let cancun = try #require(store.location(id: "TEST-CANCUN"))
        #expect(cancun.aliases == ["Cancun"])
        #expect(cancun.region == nil)
        #expect(cancun.displayName == "Cancún, Mexico")
        #expect(store.source(for: cancun)?.id == "dos")

        let ski = try #require(store.location(id: "TEST-SKI-TOWN"))
        #expect(ski.displayName == "Ski Town, CO")
        #expect(ski.seasons.count == 2)
        #expect(ski.seasons[1].start == MonthDay(month: 12, day: 1))
        #expect(ski.seasons[1].end == MonthDay(month: 3, day: 31))
    }

    @Test("A season that wraps past December 31 covers both ends of the year")
    func wrappingSeason() throws {
        let winter = try #require(store.location(id: "TEST-SKI-TOWN")?.seasons[1])
        #expect(winter.contains(MonthDay(month: 12, day: 1)))
        #expect(winter.contains(MonthDay(month: 1, day: 15)))
        #expect(winter.contains(MonthDay(month: 3, day: 31)))
        #expect(!winter.contains(MonthDay(month: 4, day: 1)))
        #expect(!winter.contains(MonthDay(month: 11, day: 30)))
    }

    @Test("A malformed month-day is rejected")
    func badMonthDay() {
        let json = Data(#"{"meta":{"currency":"USD","generatedAt":"x","sources":[]},"locations":[{"id":"X","name":"X","country":"X","source":"gsa","effective":"2026-01-01","seasons":[{"start":"13-01","end":"12-31","lodgingPerNight":1,"mealsPerDay":1}]}]}"#.utf8)
        #expect(throws: DecodingError.self) { try CostDataStore(data: json) }
    }

    @Test("Unknown IDs find nothing")
    func unknownID() {
        #expect(store.location(id: "NOPE") == nil)
    }

    // MARK: Search

    @Test("Search ignores accents and case", arguments: ["cancun", "CANCUN", "Cancún", "cAnCúN", "canc"])
    func accentInsensitive(query: String) {
        #expect(names(query).first == "Cancún")
    }

    @Test("Accented names are found from plain typing")
    func plainFindsAccented() {
        #expect(names("sao paulo") == ["São Paulo"])
        #expect(names("São Paulo") == ["São Paulo"])
    }

    @Test("Aliases match")
    func aliases() {
        #expect(names("ski village") == ["Ski Town"])
    }

    @Test("Country and state names match, with every word required")
    func countryAndState() {
        #expect(names("colorado") == ["Ski Town"])
        #expect(names("co") .contains("Ski Town"))
        #expect(Set(names("mexico")) == ["Cancún", "Other areas"])
        #expect(names("Cancún, Mexico") == ["Cancún"], "a typed 'City, Country' still finds the city")
        #expect(names("cancun brazil").isEmpty)
    }

    @Test("Name matches rank ahead of country matches")
    func ranking() {
        // "mexico" only matches by country, so both rank equally and sort by name.
        #expect(names("mexico") == ["Cancún", "Other areas"])
        // "o" prefixes "Odd Town" and "Other areas" (rank 0), and is inside other names.
        let results = names("o")
        #expect(Array(results.prefix(2)) == ["Odd Town", "Other areas"])
    }

    @Test("No match, blank queries and punctuation return nothing", arguments: ["zzz", "", "   ", ",,,"])
    func noMatch(query: String) {
        #expect(store.search(query).isEmpty)
    }

    @Test("Results are capped at the limit")
    func limit() {
        #expect(store.search("e", limit: 2).count == 2)
    }

    // MARK: Real data

    @Test("The bundled dataset decodes, names its sources, and has only positive rates")
    func realBundledData() throws {
        let real = try #require(CostDataStore.shared, "cost-data.json missing from the app bundle")
        #expect(!real.meta.sources.isEmpty)
        #expect(real.meta.sources.allSatisfy { !$0.url.isEmpty && !$0.effective.isEmpty })
        #expect(real.meta.currency == "USD")
        #expect(real.locations.count > 100)

        let badRates = real.locations.filter { location in
            location.seasons.isEmpty
                || location.seasons.contains { $0.lodgingPerNight <= 0 || $0.mealsPerDay <= 0 }
        }
        #expect(badRates.isEmpty, "zero or negative rates: \(badRates.map(\.id))")
        #expect(real.locations.allSatisfy { real.source(for: $0) != nil })
        #expect(real.locations.allSatisfy { CostDataStore.date(fromDay: $0.effective) != nil })
        #expect(Set(real.locations.map(\.id)).count == real.locations.count, "IDs must be unique")
    }

    @Test("The bundled dataset covers every day of the year for every location")
    func realDataCoversTheYear() throws {
        let real = try #require(CostDataStore.shared)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))
        let days = (0..<365).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let gaps = real.locations.filter { location in
            days.contains { location.season(on: $0, calendar: calendar) == nil }
        }
        #expect(gaps.isEmpty, "locations with uncovered days: \(gaps.map(\.id))")
    }
}
