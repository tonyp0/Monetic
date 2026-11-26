import Foundation
import Testing
@testable import Monetic

/// The seasonal lodging index, against `cost-data-seasonal-fixture.json`:
/// TEST DATA ONLY, hand-written indexes that aren't researched or real.
/// Expected cents are worked out by hand.
@Suite("Seasonal lodging index")
struct SeasonalIndexTests {
    private let store: CostDataStore
    private let calendar = TripTests.calendar

    init() throws {
        store = try CostDataStore(bundle: Bundle(for: FixtureBundleToken.self), resource: "cost-data-seasonal-fixture")
    }

    private func estimate(_ id: String, nights: Int, travelers: Int = 2, style: TravelStyle = .standard,
                          start: Date, rooms: Int? = nil) throws -> TripEstimate {
        TripEstimator.estimate(location: try #require(store.location(id: id)), nights: nights, travelers: travelers,
                               style: style, flightTotal: nil, startDate: start, rooms: rooms, calendar: calendar)
    }

    private func lodging(_ e: TripEstimate) -> Int? {
        e.lineItems.first { $0.kind == .lodging }?.cents
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { TripTests.date(y, m, d) }

    // MARK: Decoding

    @Test("A location decodes with and without a seasonal index")
    func decoding() throws {
        let beach = try #require(store.location(id: "TEST-BEACH"))
        let index = try #require(beach.seasonalIndex)
        #expect(index.lodgingPercentByMonth.count == 12)
        #expect(index.percent(month: 3) == 135)
        #expect(index.reviewedAt == "2000-01-01")
        #expect(index.sources == ["https://example.invalid/beach-hotels", "https://example.invalid/beach-tourism"])
        #expect(beach.activeSeasonalIndex == index)

        let plain = try #require(store.location(id: "TEST-BEACH-NO-INDEX"))
        #expect(plain.seasonalIndex == nil)
        #expect(plain.activeSeasonalIndex == nil)
    }

    @Test("Cheapest and priciest months; ties go to the earlier month")
    func extremes() throws {
        let beach = try #require(store.location(id: "TEST-BEACH")?.seasonalIndex)
        #expect(beach.cheapestMonth == 9)
        #expect(beach.priciestMonth == 3)
        let flat = try #require(store.location(id: "TEST-FLAT")?.seasonalIndex)
        #expect(flat.cheapestMonth == 1)
        #expect(flat.priciestMonth == 1)
    }

    // MARK: Unchanged without an index

    @Test("No index gives exactly today's cents, for every style", arguments: TravelStyle.allCases)
    func noIndexUnchanged(_ style: TravelStyle) throws {
        let e = try estimate("TEST-BEACH-NO-INDEX", nights: 7, travelers: 3, style: style, start: date(2027, 3, 10))
        let a = style.assumptions
        let rooms = TripEstimator.defaultRooms(travelers: 3, style: style)
        #expect(lodging(e) == 200 * a.lodgingPercent * rooms * 7)
        #expect(e.seasonalLodgingDeltaCents == 0)
        #expect(e.seasonalMonths.isEmpty)
        #expect(e.seasonalSources.isEmpty)
        #expect(!TripEstimator.sourceLine(for: e).contains("seasonal"))
    }

    @Test("Pinned: the original fixture's Cancún cases are unchanged")
    func pinnedOriginalCases() throws {
        let original = try TestSupport.fixtureCostData()
        let cancun = try #require(original.location(id: "TEST-CANCUN"))
        let standard = TripEstimator.estimate(location: cancun, nights: 7, travelers: 2, style: .standard,
                                              flightTotal: nil, startDate: date(2027, 6, 1), calendar: calendar)
        #expect(standard.totalCents == 105_000 + 2 * 8 * (8_000 + 2_500 + 4_000))
        let budget = TripEstimator.estimate(location: cancun, nights: 3, travelers: 1, style: .budget,
                                            flightTotal: nil, startDate: date(2027, 3, 1), calendar: calendar)
        #expect(lodging(budget) == 200 * 45 * 3)
        #expect(budget.seasonalLodgingDeltaCents == 0)
    }

    @Test("A place with seasonal per diem rates ignores its index")
    func multiSeasonIgnoresIndex() throws {
        let indexed = try #require(store.location(id: "TEST-SKI-INDEXED"))
        #expect(indexed.seasonalIndex != nil)
        #expect(indexed.activeSeasonalIndex == nil)

        let start = date(2027, 1, 10)
        let a = try estimate("TEST-SKI-INDEXED", nights: 5, start: start)
        let b = try estimate("TEST-SKI-PLAIN", nights: 5, start: start)
        #expect(a.lineItems == b.lineItems)
        #expect(lodging(a) == 300 * 75 * 5)
        #expect(a.seasonalLodgingDeltaCents == 0)
        #expect(a.seasonalMonths.isEmpty)
    }

    // MARK: Month by month

    @Test("Each night uses its own month across a month boundary")
    func twoMonths() throws {
        // Mar 30, Mar 31 at 135%, Apr 1, Apr 2 at 110%; $200 × 75% × 1 room = 15,000¢ a night.
        let e = try estimate("TEST-BEACH", nights: 4, start: date(2027, 3, 30))
        #expect(lodging(e) == 15_000 * (135 + 135 + 110 + 110) / 100)
        #expect(e.seasonalLodgingDeltaCents == 73_500 - 60_000)
        #expect(e.seasonalMonths == [3, 4])
        #expect(e.seasonalSources == ["https://example.invalid/beach-hotels", "https://example.invalid/beach-tourism"])
    }

    @Test("A trip over New Year wraps from December to January")
    func newYear() throws {
        // Dec 31 at 90%, Jan 1 at 120%.
        let e = try estimate("TEST-BEACH", nights: 2, start: date(2026, 12, 31))
        #expect(lodging(e) == 15_000 * (90 + 120) / 100)
        #expect(e.seasonalMonths == [12, 1])
    }

    @Test("February 29 is priced as February")
    func leapDay() throws {
        let e = try estimate("TEST-BEACH", nights: 1, start: date(2028, 2, 29))
        #expect(lodging(e) == 15_000 * 130 / 100)
        #expect(e.seasonalMonths == [2])
    }

    @Test("The delta is positive in peak season, negative in low season, 0 at 100%")
    func deltaSign() throws {
        let peak = try estimate("TEST-BEACH", nights: 7, start: date(2027, 3, 5))
        #expect(peak.seasonalLodgingDeltaCents == 15_000 * 7 * 35 / 100)
        let low = try estimate("TEST-BEACH", nights: 7, start: date(2027, 9, 5))
        #expect(low.seasonalLodgingDeltaCents == -15_000 * 7 * 20 / 100)
        let flat = try estimate("TEST-FLAT", nights: 7, start: date(2027, 9, 5))
        #expect(flat.seasonalLodgingDeltaCents == 0)
        #expect(flat.seasonalMonths == [9])
        #expect(TripEstimator.sourceLine(for: flat).contains("seasonal index"))
    }

    @Test("Same trip, same place: March costs more than September")
    func marchVersusSeptember() throws {
        let march = try estimate("TEST-BEACH", nights: 7, start: date(2027, 3, 5))
        let september = try estimate("TEST-BEACH", nights: 7, start: date(2027, 9, 5))
        #expect(march.totalCents > september.totalCents)
        // Only lodging moves.
        for kind in [TripEstimate.Kind.food, .localTransport, .activities] {
            #expect(march.lineItems.first { $0.kind == kind } == september.lineItems.first { $0.kind == kind })
        }
    }

    // MARK: Rounding

    @Test("Fractional cents round half up once per line, not per night")
    func roundingOncePerLine() throws {
        // Budget, 1 room: $33 × 45% = 1,485¢ a night.
        // January is 118%: 1,485 × 118 = 175,230 hundredths = 1,752.30¢ a night.
        // Rounded per night that would be 3 × 1,752 = 5,256¢; summed first it
        // is 5,256.90¢, which rounds to 5,257¢.
        let jan = try estimate("TEST-ODD", nights: 3, travelers: 1, style: .budget, start: date(2027, 1, 10))
        #expect(lodging(jan) == 5_257)

        // February is 110%: 1,485 × 110 = 163,350 hundredths, exactly half a
        // cent, which rounds up to 1,634¢.
        let feb = try estimate("TEST-ODD", nights: 1, travelers: 1, style: .budget, start: date(2027, 2, 10))
        #expect(lodging(feb) == 1_634)
        #expect(feb.seasonalLodgingDeltaCents == 1_634 - 1_485)
    }

    @Test("Per-person shares still add back to the total", arguments: [1, 2, 3, 7])
    func splitAddsUp(_ travelers: Int) throws {
        let e = try estimate("TEST-ODD", nights: 3, travelers: travelers, style: .budget, start: date(2027, 1, 10))
        #expect(e.perPersonCents.reduce(0, +) == e.totalCents)
        #expect(e.lineItems.reduce(0) { $0 + $1.cents } == e.totalCents)
    }

    // MARK: Saved estimates

    @Test("An estimate saved before the index existed decodes with no delta")
    func oldEstimateDecodes() throws {
        let e = try estimate("TEST-BEACH", nights: 4, start: date(2027, 3, 30))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(e)) as? [String: Any])
        for key in ["seasonalLodgingDeltaCents", "seasonalMonths", "seasonalSources"] {
            #expect(json.removeValue(forKey: key) != nil)
        }
        let old = try JSONDecoder().decode(TripEstimate.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.seasonalLodgingDeltaCents == 0)
        #expect(old.seasonalMonths.isEmpty)
        #expect(old.seasonalSources.isEmpty)
        #expect(old.lineItems == e.lineItems)

        let roundTrip = try JSONDecoder().decode(TripEstimate.self, from: JSONEncoder().encode(e))
        #expect(roundTrip == e)
    }

    // MARK: Form hint

    @Test("The form hint names the trip month's level and the cheapest month")
    func hint() throws {
        let index = try #require(store.location(id: "TEST-BEACH")?.seasonalIndex)
        let names = TripEstimator.monthNames
        #expect(TripEstimator.seasonalHint(index, month: 3)
                == "Hotels here run about 35% above average in \(names[2]). Cheapest month: \(names[8]).")
        #expect(TripEstimator.seasonalHint(index, month: 6)
                == "Hotels here run about 15% below average in \(names[5]). Cheapest month: \(names[8]).")
        #expect(TripEstimator.seasonalHint(index, month: 9)
                == "Hotels here run about 20% below average in \(names[8]). That's the cheapest month.")
        #expect(TripEstimator.seasonalHint(index, month: 8).contains("about 5% below"))
    }

    @Test("Month lists read naturally")
    func monthsText() {
        let names = TripEstimator.monthNames
        #expect(TripEstimator.monthsText([]) == "")
        #expect(TripEstimator.monthsText([3]) == names[2])
        #expect(TripEstimator.monthsText([3, 4]) == "\(names[2]) and \(names[3])")
        #expect(TripEstimator.monthsText([12, 1, 2]) == "\(names[11]) to \(names[1])")
    }

    // MARK: Bundled data

    @Test("Every index in the bundled data is valid and on a single-season place")
    func bundledIndexesValid() throws {
        let real = try #require(CostDataStore.shared)
        for location in real.locations {
            guard let index = location.seasonalIndex else { continue }
            #expect(location.seasons.count == 1, "\(location.id)")
            #expect(index.lodgingPercentByMonth.count == 12, "\(location.id)")
            #expect(index.lodgingPercentByMonth.allSatisfy { (60...200).contains($0) }, "\(location.id)")
            #expect(abs(index.lodgingPercentByMonth.reduce(0, +) - 1200) <= 12, "\(location.id)")
            #expect(!index.sources.isEmpty && index.sources.allSatisfy { $0.hasPrefix("https://") }, "\(location.id)")
        }
    }
}
