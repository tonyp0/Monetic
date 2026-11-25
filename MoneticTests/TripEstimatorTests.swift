import Foundation
import Testing
@testable import Monetic

/// Trip cost math against the fixture dataset. Expected values are worked
/// out by hand in exact cents: a whole-dollar rate × a whole percent is cents.
@Suite("Trip cost estimator")
struct TripEstimatorTests {
    private let store: CostDataStore
    private let calendar = TripTests.calendar

    init() throws {
        store = try TestSupport.fixtureCostData()
    }

    private func location(_ id: String) throws -> CostLocation {
        try #require(store.location(id: id))
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { TripTests.date(y, m, d) }

    private func estimate(
        _ id: String = "TEST-CANCUN",
        nights: Int,
        travelers: Int,
        style: TravelStyle,
        flights: Double? = nil,
        start: Date? = nil,
        rooms: Int? = nil
    ) throws -> TripEstimate {
        TripEstimator.estimate(
            location: try location(id), nights: nights, travelers: travelers, style: style,
            flightTotal: flights, startDate: start ?? date(2027, 6, 1), rooms: rooms, calendar: calendar
        )
    }

    private func cents(_ e: TripEstimate, _ kind: TripEstimate.Kind) -> Int? {
        e.lineItems.first { $0.kind == kind }?.cents
    }

    // MARK: Assumptions

    @Test("The travel-style assumptions are the documented ones")
    func assumptionTable() {
        // Changing a product assumption should be deliberate: update this test too.
        #expect(TravelStyle.budget.assumptions == StyleAssumptions(
            lodgingPercent: 45, mealsPercent: 50, localTransportPercent: 15, activitiesPercent: 20, peoplePerRoom: 2))
        #expect(TravelStyle.standard.assumptions == StyleAssumptions(
            lodgingPercent: 75, mealsPercent: 80, localTransportPercent: 25, activitiesPercent: 40, peoplePerRoom: 2))
        #expect(TravelStyle.comfort.assumptions == StyleAssumptions(
            lodgingPercent: 100, mealsPercent: 100, localTransportPercent: 40, activitiesPercent: 70, peoplePerRoom: 1))
        #expect(TravelStyle.budget.assumptions.summary.contains("45%"))
    }

    // MARK: Per-style math

    @Test("Standard: 2 travelers, 7 nights in Cancún ($200 room, $100 M&IE)")
    func standardMath() throws {
        let e = try estimate(nights: 7, travelers: 2, style: .standard)
        #expect(e.rooms == 1)
        #expect(cents(e, .lodging) == 200 * 75 * 1 * 7)       // $1,050.00
        #expect(cents(e, .food) == 100 * 80 * 2 * 8)          // 8 days × 2 people
        #expect(cents(e, .localTransport) == 100 * 25 * 2 * 8)
        #expect(cents(e, .activities) == 100 * 40 * 2 * 8)
        #expect(e.totalCents == 337_000)
        #expect(e.perPersonCents == [168_500, 168_500])
        #expect(e.lineItems.map(\.kind) == [.lodging, .food, .localTransport, .activities])
    }

    @Test("Budget: 1 traveler, 3 nights")
    func budgetMath() throws {
        let e = try estimate(nights: 3, travelers: 1, style: .budget)
        #expect(cents(e, .lodging) == 200 * 45 * 3)
        #expect(cents(e, .food) == 100 * 50 * 4)
        #expect(cents(e, .localTransport) == 100 * 15 * 4)
        #expect(cents(e, .activities) == 100 * 20 * 4)
        #expect(e.totalCents == 61_000)
    }

    @Test("Comfort: 3 travelers, a room each")
    func comfortMath() throws {
        let e = try estimate(nights: 2, travelers: 3, style: .comfort)
        #expect(e.rooms == 3)
        #expect(cents(e, .lodging) == 200 * 100 * 3 * 2)
        #expect(cents(e, .food) == 100 * 100 * 3 * 3)
        #expect(e.totalCents == 120_000 + 90_000 + 36_000 + 63_000)
    }

    @Test("Every style follows its own percentages", arguments: TravelStyle.allCases)
    func styleFormula(style: TravelStyle) throws {
        let a = style.assumptions
        let e = try estimate(nights: 4, travelers: 2, style: style)
        let rooms = TripEstimator.defaultRooms(travelers: 2, style: style)
        #expect(cents(e, .lodging) == 200 * a.lodgingPercent * rooms * 4)
        #expect(cents(e, .food) == 100 * a.mealsPercent * 2 * 5)
        #expect(cents(e, .localTransport) == 100 * a.localTransportPercent * 2 * 5)
        #expect(cents(e, .activities) == 100 * a.activitiesPercent * 2 * 5)
    }

    @Test("Cheaper styles never cost more")
    func styleOrdering() throws {
        let totals = try TravelStyle.allCases.map { try estimate(nights: 5, travelers: 4, style: $0).totalCents }
        #expect(totals == totals.sorted())
    }

    @Test("A day trip has no lodging but still a day of meals")
    func dayTrip() throws {
        let e = try estimate(nights: 0, travelers: 1, style: .standard)
        #expect(cents(e, .lodging) == 0)
        #expect(cents(e, .food) == 100 * 80)
    }

    // MARK: Room sharing

    @Test("Default rooms: two to a room for budget and standard, one each for comfort", arguments: [
        (1, 1, 1), (2, 1, 2), (3, 2, 3), (5, 3, 5),
    ])
    func defaultRooms(travelers: Int, shared: Int, comfort: Int) {
        #expect(TripEstimator.defaultRooms(travelers: travelers, style: .budget) == shared)
        #expect(TripEstimator.defaultRooms(travelers: travelers, style: .standard) == shared)
        #expect(TripEstimator.defaultRooms(travelers: travelers, style: .comfort) == comfort)
    }

    @Test("Room sharing changes lodging only", arguments: [1, 2, 3, 5])
    func roomsDriveLodging(travelers: Int) throws {
        let e = try estimate(nights: 1, travelers: travelers, style: .budget)
        let rooms = (travelers + 1) / 2
        #expect(e.rooms == rooms)
        #expect(cents(e, .lodging) == 200 * 45 * rooms)
        #expect(cents(e, .food) == 100 * 50 * travelers * 2)
    }

    @Test("A chosen room count is kept between 1 and the number of travelers")
    func roomOverride() throws {
        #expect(try estimate(nights: 1, travelers: 4, style: .budget, rooms: 4).rooms == 4)
        #expect(try estimate(nights: 1, travelers: 4, style: .comfort, rooms: 1).rooms == 1)
        #expect(try estimate(nights: 1, travelers: 3, style: .budget, rooms: 9).rooms == 3)
        #expect(try estimate(nights: 1, travelers: 3, style: .budget, rooms: 0).rooms == 1)
    }

    // MARK: Seasons

    @Test("Each night is priced in its own season across a season boundary")
    func seasonBoundary() throws {
        // Ski Town: $150/$80 Apr 1–Nov 30, $400/$90 Dec 1–Mar 31.
        // Nights Nov 28, 29, 30 (summer) and Dec 1, 2 (winter); days Nov 28–Dec 3.
        let e = try estimate("TEST-SKI-TOWN", nights: 5, travelers: 1, style: .comfort, start: date(2027, 11, 28))
        #expect(cents(e, .lodging) == (3 * 150 + 2 * 400) * 100)
        #expect(cents(e, .food) == (3 * 80 + 3 * 90) * 100)
        #expect(cents(e, .localTransport) == (3 * 80 + 3 * 90) * 40)
    }

    @Test("A season that wraps the new year ends where it should")
    func wrappedSeasonEnd() throws {
        // Nights Mar 30, Mar 31 (winter), Apr 1 (summer).
        let e = try estimate("TEST-SKI-TOWN", nights: 3, travelers: 1, style: .comfort, start: date(2027, 3, 30))
        #expect(cents(e, .lodging) == (2 * 400 + 150) * 100)
    }

    @Test("February 29 uses February 28's rates")
    func leapDay() throws {
        // Leap City: $100/$50 to Feb 28, $120/$60 from Mar 1. Nights Feb 28, 29.
        let e = try estimate("TEST-LEAP", nights: 2, travelers: 1, style: .comfort, start: date(2028, 2, 28))
        #expect(cents(e, .lodging) == 200 * 100)
        #expect(cents(e, .food) == (50 + 50 + 60) * 100)
    }

    // MARK: Flights

    @Test("No flight price leaves flights out and flags the gap", arguments: [nil, 0.0, -5.0] as [Double?])
    func noFlights(flights: Double?) throws {
        let e = try estimate(nights: 2, travelers: 2, style: .standard, flights: flights)
        #expect(!e.includesFlights)
        #expect(cents(e, .flights) == nil)
        #expect(e.lineItems.count == 4)
    }

    @Test("A flight price is added to the total as typed")
    func withFlights() throws {
        let without = try estimate(nights: 2, travelers: 2, style: .standard)
        let with = try estimate(nights: 2, travelers: 2, style: .standard, flights: 850.50)
        #expect(with.includesFlights)
        #expect(cents(with, .flights) == 85_050)
        #expect(with.totalCents == without.totalCents + 85_050)
    }

    // MARK: Rounding

    @Test("Splitting a total gives shares that add up to the cent", arguments: [
        (100_000, 3, [33_334, 33_333, 33_333]),
        (1, 4, [1, 0, 0, 0]),
        (0, 2, [0, 0]),
        (999, 1, [999]),
        (10, 0, [10]),
    ])
    func split(total: Int, count: Int, expected: [Int]) {
        let shares = TripEstimate.split(total, among: count)
        #expect(shares == expected)
        #expect(shares.reduce(0, +) == total)
    }

    @Test("Per-person shares and line items always add up to the total")
    func estimateAddsUp() throws {
        // $101 room, $33 M&IE, 3 people sharing 2 rooms, plus an odd flight price:
        // 15,150 + 15,840 + 4,950 + 7,920 + 10,001 = 53,861 cents, not divisible by 3.
        let e = try estimate("TEST-ODD", nights: 1, travelers: 3, style: .standard, flights: 100.01)
        #expect(e.totalCents == 53_861)
        #expect(e.lineItems.reduce(0) { $0 + $1.cents } == e.totalCents)
        #expect(e.perPersonCents == [17_954, 17_954, 17_953])
        #expect(e.perPersonCents.reduce(0, +) == e.totalCents)
        #expect(!e.splitsEvenly)
        #expect(e.perPerson == 179.54)

        let shares = e.lineItems.map { e.share(of: $0) }.reduce(0, +)
        #expect(abs(shares - 1) < 0.000_001)
    }

    // MARK: Provenance

    @Test("The estimate carries where its rates came from")
    func sourceLine() throws {
        let e = try estimate(nights: 1, travelers: 1, style: .standard)
        #expect(e.locationID == "TEST-CANCUN")
        #expect(e.locationName == "Cancún, Mexico")
        #expect(e.sourceID == "dos")
        #expect(e.effective == "2024-08-01")
        let line = TripEstimator.sourceLine(for: e)
        #expect(line.hasPrefix("Based on U.S. government per diem rates (U.S. Department of State, effective"))
        #expect(line.contains("2024"))
    }

    @Test("An estimate survives being saved and read back")
    func codableRoundTrip() throws {
        let e = try estimate(nights: 3, travelers: 2, style: .budget, flights: 420)
        let decoded = try JSONDecoder().decode(TripEstimate.self, from: JSONEncoder().encode(e))
        #expect(decoded == e)
    }

    // MARK: Form rules

    private func draft() -> TripDraft {
        TripDraft(name: "Spring Break", destination: "canc", startDate: date(2027, 3, 20),
                  endDate: date(2027, 3, 27), travelers: 2)
    }

    @Test("Picking a place fills the total with the estimate and saves it as per diem")
    func pickAndSave() throws {
        var d = draft()
        let cancun = try location("TEST-CANCUN")
        d.select(cancun)
        #expect(d.destination == "Cancún, Mexico")
        #expect(d.locationID == "TEST-CANCUN")

        let e = try #require(d.estimate(location: cancun, calendar: calendar))
        d.estimateChanged(from: nil, to: e)
        #expect(d.isUsingEstimate(e))
        #expect(AmountInput.cents(d.amountText) == e.totalCents)
        #expect(d.isValid(calendar: calendar))

        let trip = try #require(d.makeTrip(estimate: e, calendar: calendar))
        #expect(trip.estimateSource == "perDiem")
        #expect(trip.locationID == "TEST-CANCUN")
        #expect(trip.travelStyle == "standard")
        #expect(trip.savedEstimate == e)
        #expect(trip.estimatedTotal == e.total)
        #expect(trip.totalCurrencyCode == "USD")
    }

    @Test("The total follows the estimate until the user types over it")
    func followThenOverride() throws {
        var d = draft()
        let cancun = try location("TEST-CANCUN")
        d.select(cancun)
        let standard = try #require(d.estimate(location: cancun, calendar: calendar))
        d.estimateChanged(from: nil, to: standard)

        d.travelStyle = .budget
        let budget = try #require(d.estimate(location: cancun, calendar: calendar))
        d.estimateChanged(from: standard, to: budget)
        #expect(AmountInput.cents(d.amountText) == budget.totalCents, "still following")

        d.amountText = TestSupport.amountText("1500")
        #expect(!d.isUsingEstimate(budget))
        d.travelStyle = .comfort
        let comfort = try #require(d.estimate(location: cancun, calendar: calendar))
        d.estimateChanged(from: budget, to: comfort)
        #expect(AmountInput.cents(d.amountText) == 150_000, "an edited total is kept")

        let trip = try #require(d.makeTrip(estimate: comfort, calendar: calendar))
        #expect(trip.estimateSource == "manual", "an override saves as manual")
        #expect(trip.savedEstimate == comfort, "the breakdown is still kept for reference")
        #expect(trip.estimatedTotal == 1500)

        d.useEstimate(comfort)
        #expect(d.isUsingEstimate(comfort))
    }

    @Test("Typing over a picked place unpicks it; free text needs a typed total")
    func freeText() throws {
        var d = draft()
        let cancun = try location("TEST-CANCUN")
        d.select(cancun)
        d.destinationEdited(pickedName: cancun.displayName)
        #expect(d.locationID == "TEST-CANCUN", "the picked name itself keeps the pick")

        d.destination = "Cancún, Mexico — Hotel Zone"
        d.destinationEdited(pickedName: cancun.displayName)
        #expect(d.locationID == nil)
        #expect(d.estimate(location: nil) == nil)
        #expect(!d.isValid(calendar: calendar), "no estimate and no total")

        d.amountText = "900"
        let trip = try #require(d.makeTrip(estimate: nil, calendar: calendar))
        #expect(trip.estimateSource == "manual")
        #expect(trip.locationID == nil)
        #expect(trip.savedEstimate == nil)
    }

    @Test("Rooms follow the style until chosen, and never exceed the travelers")
    func draftRooms() {
        var d = draft()
        d.travelers = 5
        #expect(d.rooms == 3)
        d.travelStyle = .comfort
        #expect(d.rooms == 5)
        d.roomsOverride = 4
        d.travelers = 2
        #expect(d.rooms == 2)
    }

    @Test("Empty or zero flights count as not entered")
    func draftFlights() {
        var d = draft()
        #expect(d.flightsTotal == nil)
        d.flightsText = "0"
        #expect(d.flightsTotal == nil)
        d.flightsText = TestSupport.amountText("612.40")
        #expect(d.flightsTotal == 612.40)
    }

    @Test("Editing a per diem trip refreshes its total from the current estimate")
    func editPerDiemTrip() throws {
        var d = draft()
        let cancun = try location("TEST-CANCUN")
        d.select(cancun)
        let e = try #require(d.estimate(location: cancun, calendar: calendar))
        d.estimateChanged(from: nil, to: e)
        let trip = try #require(d.makeTrip(estimate: e, calendar: calendar))

        let reopened = TripDraft(trip: trip, estimate: e)
        #expect(reopened.locationID == "TEST-CANCUN")
        #expect(reopened.travelStyle == .standard)
        #expect(reopened.isUsingEstimate(e))

        var edited = reopened
        edited.flightsText = "300"
        let withFlights = try #require(edited.estimate(location: cancun, calendar: calendar))
        edited.estimateChanged(from: e, to: withFlights)
        #expect(edited.apply(to: trip, estimate: withFlights, calendar: calendar))
        #expect(trip.estimateSource == "perDiem")
        #expect(trip.flightsTotal == 300)
        #expect(trip.savedEstimate?.includesFlights == true)
        #expect(trip.estimatedTotal == withFlights.total)
    }
    @Test("Editing a trip whose place left the data keeps its saved estimate")
    func placeMissingFromData() throws {
        var d = draft()
        let cancun = try location("TEST-CANCUN")
        d.select(cancun)
        let e = try #require(d.estimate(location: cancun, calendar: calendar))
        d.estimateChanged(from: nil, to: e)
        let trip = try #require(d.makeTrip(estimate: e, calendar: calendar))

        // Reopened with no current estimate, as when the ID isn't found.
        var edited = TripDraft(trip: trip, estimate: nil)
        edited.notes = "Booked the hotel"
        #expect(edited.apply(to: trip, estimate: nil, calendar: calendar))
        #expect(trip.estimateSource == "perDiem")
        #expect(trip.locationID == "TEST-CANCUN")
        #expect(trip.savedEstimate == e)
        #expect(trip.totalCurrencyCode == "USD")
        #expect(trip.notes == "Booked the hotel")

        edited.amountText = "999"
        #expect(edited.apply(to: trip, estimate: nil, calendar: calendar))
        #expect(trip.estimateSource == "manual", "a changed total is the user's own")
        #expect(trip.savedEstimate == e, "the old breakdown stays for reference")
    }
}
