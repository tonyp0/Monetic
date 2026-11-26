import Foundation
import Testing
@testable import Monetic

/// "Describe your trip" with a scripted extractor: no test here depends on
/// a language model, or on whether this device has one.
struct FakeTripIntentExtractor: TripIntentExtracting {
    var intent = TripIntent()
    var error: TripAssistant.Failure?
    var delay: Duration = .zero

    func extract(from text: String, today: Date, calendar: Calendar) async throws -> TripIntent {
        if delay > .zero { try await Task.sleep(for: delay) }
        if let error { throw error }
        return intent
    }
}

@Suite("Trip assistant")
struct TripAssistantTests {
    private let store: CostDataStore
    /// Wednesday, Nov 25, 2026.
    private let today = TestSupport.date(2026, 11, 25)
    private var calendar: Calendar { .current }

    init() throws {
        store = try TestSupport.fixtureCostData()
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.startOfDay(for: TestSupport.date(y, m, d))
    }

    private func apply(_ intent: TripIntent, text: String = "", to draft: inout TripDraft) -> TripAssistant.Fill {
        TripAssistant.apply(intent, text: text, to: &draft, store: store, today: today)
    }

    private var blank: TripDraft { TripDraft.new(asOf: today) }

    // MARK: Field mapping

    @Test("A full description fills every field it mentions")
    func fullMapping() {
        var draft = blank
        let intent = TripIntent(destinationQuery: "Cancun", startDate: .init(month: 3, day: 14),
                                endDate: .init(month: 3, day: 21), travelers: 5, style: "budget",
                                quotedFlightTotal: 1200)
        let fill = apply(intent, text: "spring break in Cancún with 4 friends, cheap, March 14–21, flights $1,200",
                         to: &draft)

        #expect(draft.locationID == "TEST-CANCUN", "one match is picked, so the estimate runs")
        #expect(draft.destination == "Cancún, Mexico")
        #expect(draft.name == "Cancún trip")
        #expect(draft.startDate == day(2027, 3, 14))
        #expect(draft.endDate == day(2027, 3, 21))
        #expect(draft.travelers == 5)
        #expect(draft.travelStyle == .budget)
        #expect(draft.flightsText == "1200.00")

        #expect(fill.name == draft.name)
        #expect(fill.destination == draft.destination)
        #expect(!fill.destinationIsAmbiguous)
        #expect(fill.startDate == draft.startDate && fill.endDate == draft.endDate)
        #expect(fill.travelers == 5)
        #expect(fill.style == .budget)
        #expect(fill.flightsText == "1200.00")
        #expect(fill.problems.isEmpty)
    }

    @Test("The total always comes from the estimator, never the description")
    func totalFromEstimator() throws {
        var draft = blank
        _ = apply(TripIntent(destinationQuery: "cancun", travelers: 4, style: "standard", quotedFlightTotal: 800),
                  text: "Cancún for 4, flights 800", to: &draft)
        #expect(draft.amountText.isEmpty, "the assistant never writes the total")

        // The total the form then shows is TripEstimator's, flights included.
        let location = try #require(store.location(id: "TEST-CANCUN"))
        let estimate = try #require(draft.estimate(location: location))
        let expected = TripEstimator.estimate(location: location, nights: draft.nights(), travelers: 4,
                                              style: .standard, flightTotal: 800, startDate: draft.startDate)
        #expect(estimate == expected)
        draft.estimateChanged(from: nil, to: estimate)
        #expect(AmountInput.cents(draft.amountText) == expected.totalCents)
    }

    @Test("A flight price the user didn't write is dropped", arguments: [
        ("Cancún for 4 in March", 950.0),          // no number at all
        ("Cancún for 4, March 14", 1400.0),        // numbers, but not this one
        ("flights were about 1.2k", 1200.0),       // unreadable as written: stay safe
    ])
    func inventedFlightsDropped(text: String, flights: Double) {
        var draft = blank
        let fill = apply(TripIntent(quotedFlightTotal: flights), text: text, to: &draft)
        #expect(draft.flightsText.isEmpty)
        #expect(fill.flightsText == nil)
    }

    @Test("Flight prices count however they're written", arguments: [
        ("flights $1,200", 1200.0), ("1200 for flights", 1200.0), ("fares 1,234.50 total", 1234.5),
    ])
    func quotedFlights(text: String, flights: Double) {
        #expect(TripAssistant.mentions(flights, in: text))
    }

    @Test("Out-of-range flight prices are refused", arguments: [0.0, -50.0, 2_000_000.0])
    func flightRange(flights: Double) {
        var draft = blank
        _ = apply(TripIntent(quotedFlightTotal: flights), text: "flights \(flights) 0 -50 2000000", to: &draft)
        #expect(draft.flightsText.isEmpty)
    }

    @Test("The intent has no money fields besides a quoted flight price")
    func noCostFields() {
        let fields = Set(Mirror(reflecting: TripIntent()).children.compactMap(\.label))
        #expect(fields == ["destinationQuery", "startDate", "endDate", "travelers", "style", "quotedFlightTotal"])
    }

    @Test("Style is only ever one of the app's travel styles")
    func styles() {
        var draft = blank
        _ = apply(TripIntent(style: "Comfort"), to: &draft)
        #expect(draft.travelStyle == .comfort)

        var other = blank
        let fill = apply(TripIntent(style: "luxury"), to: &other)
        #expect(other.travelStyle == .standard)
        #expect(fill.style == nil)
    }

    // MARK: Destinations

    @Test("Several matching places are offered, not guessed")
    func ambiguousDestination() {
        var draft = blank
        let fill = apply(TripIntent(destinationQuery: "town"), to: &draft)
        #expect(draft.locationID == nil)
        #expect(draft.destination == "town")
        #expect(fill.destinationIsAmbiguous)
        #expect(store.search("town", limit: 5).count == 2, "Ski Town and Odd Town")
    }

    @Test("A place with no rates stays as a typed-in destination")
    func unknownDestination() {
        var draft = blank
        let fill = apply(TripIntent(destinationQuery: "Atlantis, Ocean"), to: &draft)
        #expect(draft.locationID == nil)
        #expect(draft.destination == "Atlantis, Ocean")
        #expect(draft.name == "Atlantis trip")
        #expect(!fill.destinationIsAmbiguous)
    }

    @Test("A name the user already typed is kept")
    func keepsName() {
        var draft = blank
        draft.name = "Spring Break"
        let fill = apply(TripIntent(destinationQuery: "cancun"), to: &draft)
        #expect(draft.name == "Spring Break")
        #expect(fill.name == nil)
    }

    @Test("Empty or absurd destinations are ignored", arguments: ["   ", String(repeating: "x", count: 121)])
    func badDestination(query: String) {
        var draft = blank
        let fill = apply(TripIntent(destinationQuery: query), to: &draft)
        #expect(draft == blank)
        #expect(fill.isEmpty)
    }

    // MARK: Missing fields

    @Test("Only what was mentioned changes")
    func missingFields() {
        var draft = blank
        draft.name = "Mine"
        draft.travelStyle = .comfort
        let before = draft
        let fill = apply(TripIntent(travelers: 3), to: &draft)
        #expect(draft.travelers == 3)
        var expected = before
        expected.travelers = 3
        #expect(draft == expected)
        #expect(fill.destination == nil && fill.startDate == nil && fill.style == nil && fill.flightsText == nil)
    }

    @Test("Nothing understood: nothing changes, and the form says so")
    func nothingFound() {
        var draft = blank
        let fill = apply(TripIntent(), to: &draft)
        #expect(fill.isEmpty)
        #expect(draft == blank)
    }

    @Test("Out-of-range travelers are rejected, not clamped", arguments: [0, -2, 21, 300])
    func travelersOutOfRange(travelers: Int) {
        var draft = blank
        let fill = apply(TripIntent(travelers: travelers), to: &draft)
        #expect(draft.travelers == 1)
        #expect(fill.travelers == nil)
        #expect(fill.problems.count == 1)
    }

    // MARK: Dates

    private func resolve(_ start: TripIntent.Day?, _ end: TripIntent.Day?, nights: Int = 7) -> (Date, Date)? {
        TripAssistant.resolveDates(start: start, end: end, tripNights: nights, today: today).map { ($0.start, $0.end) }
    }

    @Test("A month without a year means its next occurrence")
    func nextOccurrence() throws {
        let march = try #require(resolve(.init(month: 3, day: 14), .init(month: 3, day: 21)))
        #expect(march == (day(2027, 3, 14), day(2027, 3, 21)), "March, asked in November, is next March")

        let december = try #require(resolve(.init(month: 12, day: 20), .init(month: 12, day: 27)))
        #expect(december == (day(2026, 12, 20), day(2026, 12, 27)), "still to come this year")

        let today = try #require(resolve(.init(month: 11, day: 25), .init(month: 11, day: 26)))
        #expect(today.0 == day(2026, 11, 25), "today counts")
        let earlier = try #require(resolve(.init(month: 11, day: 20), nil))
        #expect(earlier.0 == day(2027, 11, 20), "a day already gone this year is next year's")
    }

    @Test("Trips across New Year end in the next year")
    func yearBoundary() throws {
        let trip = try #require(resolve(.init(month: 12, day: 28), .init(month: 1, day: 3)))
        #expect(trip == (day(2026, 12, 28), day(2027, 1, 3)))
    }

    @Test("A bare month starts on the 1st and keeps the trip's length")
    func bareMonth() throws {
        let trip = try #require(resolve(.init(month: 3), nil, nights: 5))
        #expect(trip == (day(2027, 3, 1), day(2027, 3, 6)))

        let thisMonth = try #require(resolve(.init(month: 11), nil, nights: 2))
        #expect(thisMonth == (day(2026, 11, 26), day(2026, 11, 28)), "this month starts tomorrow, not in the past")
    }

    @Test("An end day with no month takes the start's month, or the next")
    func endDayOnly() throws {
        let sameMonth = try #require(resolve(.init(month: 3, day: 14), .init(day: 21)))
        #expect(sameMonth.1 == day(2027, 3, 21))
        let nextMonth = try #require(resolve(.init(month: 3, day: 28), .init(day: 3)))
        #expect(nextMonth.1 == day(2027, 4, 3))
        let december = try #require(resolve(.init(month: 12, day: 30), .init(day: 2)))
        #expect(december.1 == day(2027, 1, 2), "December to January wraps the year")
    }

    @Test("Explicit years are used as written")
    func explicitYear() throws {
        let trip = try #require(resolve(.init(month: 6, day: 1, year: 2028), .init(month: 6, day: 5, year: 2028)))
        #expect(trip == (day(2028, 6, 1), day(2028, 6, 5)))
    }

    @Test("Only an end date: the trip ends then, keeping its length")
    func endOnly() throws {
        let trip = try #require(resolve(nil, .init(month: 1, day: 10), nights: 3))
        #expect(trip == (day(2027, 1, 7), day(2027, 1, 10)))
    }

    @Test("February 29 waits for a leap year")
    func leapDay() throws {
        let trip = try #require(resolve(.init(month: 2, day: 29), nil, nights: 1))
        #expect(trip.0 == day(2028, 2, 29))
    }

    @Test("Days that aren't trips are rejected", arguments: [
        (TripIntent.Day(month: 2, day: 30), TripIntent.Day?.none),           // no such day
        (TripIntent.Day(month: 13, day: 1), nil),                             // no such month
        (TripIntent.Day(month: 3, day: 0), nil),
        (TripIntent.Day(day: 14), nil),                                       // no month at all
        (TripIntent.Day(month: 3, day: 14, year: 1999), nil),                 // absurd year
        (TripIntent.Day(month: 3, day: 21, year: 2027), TripIntent.Day(month: 3, day: 14, year: 2027)),  // backwards
        (TripIntent.Day(month: 1, day: 1, year: 2027), TripIntent.Day(month: 6, day: 1, year: 2028)),    // > 365 nights
    ])
    func badDates(start: TripIntent.Day, end: TripIntent.Day?) {
        #expect(resolve(start, end) == nil)
    }

    @Test("Dates the form can't use leave the dates alone, with a note")
    func badDatesKeepForm() {
        var draft = blank
        let fill = apply(TripIntent(startDate: .init(month: 2, day: 30)), to: &draft)
        #expect(draft.startDate == blank.startDate && draft.endDate == blank.endDate)
        #expect(fill.startDate == nil)
        #expect(fill.problems.count == 1)
    }

    // MARK: Running the extractor

    @Test("A slow model times out instead of hanging the form")
    func timeout() async {
        let slow = FakeTripIntentExtractor(intent: TripIntent(travelers: 2), delay: .seconds(30))
        let clock = ContinuousClock()
        let started = clock.now
        await #expect(throws: TripAssistant.Failure.timedOut) {
            try await TripAssistant.extract("anything", using: slow, today: today, timeout: .milliseconds(100))
        }
        #expect(clock.now - started < .seconds(5))
    }

    @Test("A fast answer comes back intact")
    func fastAnswer() async throws {
        let intent = TripIntent(destinationQuery: "Cancun", travelers: 2)
        let result = try await TripAssistant.extract("x", using: FakeTripIntentExtractor(intent: intent), today: today)
        #expect(result == intent)
    }

    @Test("Extractor errors reach the caller, so the form can say so")
    func errors() async {
        let failing = FakeTripIntentExtractor(error: .timedOut)
        await #expect(throws: TripAssistant.Failure.self) {
            try await TripAssistant.extract("x", using: failing, today: today)
        }
    }
}
