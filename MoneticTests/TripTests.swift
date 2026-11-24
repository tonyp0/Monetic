import Foundation
import Testing
@testable import Monetic

/// Trip date math, status, per-person cost, and the Add/Edit Trip form rules.
///
/// Everything runs against a fixed New York calendar so DST changes land on
/// known dates (2027: clocks go forward Sun Mar 14, back Sun Nov 7), whatever
/// the simulator's own time zone is.
@Suite("Trips")
struct TripTests {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    private var calendar: Calendar { Self.calendar }

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        guard let date = calendar.date(from: components) else {
            fatalError("Invalid test date \(year)-\(month)-\(day)")
        }
        return date
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        Self.date(year, month, day, hour: hour, minute: minute)
    }

    private func trip(
        from start: Date,
        to end: Date,
        travelers: Int = 1,
        total: Double = 2400,
        name: String = "Spring Break"
    ) -> Trip {
        Trip(
            name: name,
            destination: "Cancún, Mexico",
            startDate: start,
            endDate: end,
            travelers: travelers,
            estimatedTotal: total,
            calendar: calendar
        )
    }

    // MARK: Normalization

    @Test("Start and end dates are stored as the start of their day")
    func datesNormalizedToStartOfDay() {
        let t = trip(from: date(2027, 3, 14, hour: 15, minute: 30), to: date(2027, 3, 21, hour: 9))
        #expect(t.startDate == calendar.startOfDay(for: date(2027, 3, 14)))
        #expect(t.endDate == calendar.startOfDay(for: date(2027, 3, 21)))
        #expect(calendar.component(.hour, from: t.startDate) == 0)
        #expect(calendar.component(.hour, from: t.endDate) == 0)
    }

    @Test("An end date before the start is pulled up to the start")
    func endBeforeStartIsClamped() {
        let t = trip(from: date(2027, 3, 14), to: date(2027, 3, 10))
        #expect(t.endDate == t.startDate)
        #expect(t.nights(calendar: calendar) == 0)
    }

    @Test("A trip always has at least one traveler")
    func travelersAtLeastOne() {
        #expect(trip(from: date(2027, 3, 14), to: date(2027, 3, 21), travelers: 0).travelers == 1)
        #expect(trip(from: date(2027, 3, 14), to: date(2027, 3, 21), travelers: -3).travelers == 1)
    }

    @Test("New trips record a manual estimate")
    func defaultEstimateSourceIsManual() {
        #expect(trip(from: date(2027, 3, 14), to: date(2027, 3, 21)).estimateSource == "manual")
    }

    // MARK: Nights and days

    struct Span: Sendable, CustomTestStringConvertible {
        let label: String
        let start: (Int, Int, Int)
        let end: (Int, Int, Int)
        let nights: Int
        var testDescription: String { label }
    }

    static let spans: [Span] = [
        Span(label: "Mar 14 → Mar 21 (clocks go forward on the 14th)", start: (2027, 3, 14), end: (2027, 3, 21), nights: 7),
        Span(label: "Mar 13 → Mar 15, around the spring-forward night", start: (2027, 3, 13), end: (2027, 3, 15), nights: 2),
        Span(label: "Nov 6 → Nov 8, around the fall-back night", start: (2027, 11, 6), end: (2027, 11, 8), nights: 2),
        Span(label: "Jan 28 → Feb 3, across a month boundary", start: (2027, 1, 28), end: (2027, 2, 3), nights: 6),
        Span(label: "Feb 26 → Mar 2 in a leap year", start: (2028, 2, 26), end: (2028, 3, 2), nights: 5),
        Span(label: "Dec 28 → Jan 4, across a year boundary", start: (2027, 12, 28), end: (2028, 1, 4), nights: 7),
        Span(label: "Same-day trip", start: (2027, 6, 1), end: (2027, 6, 1), nights: 0),
    ]

    @Test("Nights and days count calendar days, not elapsed hours", arguments: spans)
    func nightsAndDays(span: Span) {
        let t = trip(
            from: date(span.start.0, span.start.1, span.start.2, hour: 18),
            to: date(span.end.0, span.end.1, span.end.2, hour: 7)
        )
        #expect(t.nights(calendar: calendar) == span.nights)
        #expect(t.days(calendar: calendar) == span.nights + 1)
    }

    @Test("The spring-forward week really is an hour short, and still counts as 7 nights")
    func dstWeekIsShortButCountsSevenNights() {
        let t = trip(from: date(2027, 3, 14), to: date(2027, 3, 21))
        let hours = t.endDate.timeIntervalSince(t.startDate) / 3600
        #expect(hours == 7 * 24 - 1)
        #expect(t.nights(calendar: calendar) == 7)
    }

    // MARK: Countdown and status

    struct Moment: Sendable, CustomTestStringConvertible {
        let label: String
        let asOf: Date
        let daysUntil: Int
        let status: Trip.Status
        let countdown: String
        var testDescription: String { label }
    }

    // Trip runs Sat Mar 20 → Sat Mar 27, 2027.
    static let moments: [Moment] = [
        Moment(label: "Weeks before", asOf: date(2027, 2, 6), daysUntil: 42, status: .upcoming, countdown: "in 42 days"),
        Moment(label: "Before, across the spring-forward change", asOf: date(2027, 3, 13, hour: 23, minute: 30), daysUntil: 7, status: .upcoming, countdown: "in 7 days"),
        Moment(label: "Last minute of the day before", asOf: date(2027, 3, 19, hour: 23, minute: 59), daysUntil: 1, status: .upcoming, countdown: "in 1 day"),
        Moment(label: "Midnight on the start day", asOf: date(2027, 3, 20, hour: 0), daysUntil: 0, status: .inProgress, countdown: "Happening now"),
        Moment(label: "During", asOf: date(2027, 3, 23), daysUntil: 0, status: .inProgress, countdown: "Happening now"),
        Moment(label: "Late on the end day", asOf: date(2027, 3, 27, hour: 23, minute: 59), daysUntil: 0, status: .inProgress, countdown: "Happening now"),
        Moment(label: "Midnight after the end day", asOf: date(2027, 3, 28, hour: 0), daysUntil: 0, status: .past, countdown: "Ended"),
        Moment(label: "Months after", asOf: date(2027, 8, 1), daysUntil: 0, status: .past, countdown: "Ended"),
    ]

    @Test("Days until departure, status and countdown text on fixed dates", arguments: moments)
    func countdown(moment: Moment) {
        let t = trip(from: date(2027, 3, 20), to: date(2027, 3, 27))
        #expect(t.daysUntilDeparture(asOf: moment.asOf, calendar: calendar) == moment.daysUntil)
        #expect(t.status(asOf: moment.asOf, calendar: calendar) == moment.status)
        #expect(TripList.countdownText(for: t, asOf: moment.asOf, calendar: calendar) == moment.countdown)
    }

    @Test("A same-day trip is in progress all that day")
    func sameDayTripStatus() {
        let t = trip(from: date(2027, 6, 1), to: date(2027, 6, 1))
        #expect(t.status(asOf: date(2027, 5, 31, hour: 23), calendar: calendar) == .upcoming)
        #expect(t.status(asOf: date(2027, 6, 1, hour: 0), calendar: calendar) == .inProgress)
        #expect(t.status(asOf: date(2027, 6, 1, hour: 23), calendar: calendar) == .inProgress)
        #expect(t.status(asOf: date(2027, 6, 2, hour: 0), calendar: calendar) == .past)
    }

    @Test("Trip length reads as a day trip, 1 night or N nights")
    func nightsText() {
        #expect(TripList.nightsText(0) == "Day trip")
        #expect(TripList.nightsText(1) == "1 night")
        #expect(TripList.nightsText(7) == "7 nights")
    }

    // MARK: Per person

    @Test("Per-person total splits the estimate evenly", arguments: [
        (2400.0, 1, 2400.0),
        (2400.0, 4, 600.0),
        (1000.0, 3, 1000.0 / 3),
        (0.0, 2, 0.0),
    ])
    func perPersonTotal(total: Double, travelers: Int, expected: Double) {
        let t = trip(from: date(2027, 3, 20), to: date(2027, 3, 27), travelers: travelers, total: total)
        #expect(t.perPersonTotal == expected)
    }

    // MARK: List ordering

    @Test("Upcoming trips are soonest first; past trips are most recent first")
    func listSections() {
        let now = date(2027, 3, 1)
        let later = trip(from: date(2027, 7, 1), to: date(2027, 7, 8), name: "Later")
        let soon = trip(from: date(2027, 3, 10), to: date(2027, 3, 12), name: "Soon")
        let now_ = trip(from: date(2027, 2, 27), to: date(2027, 3, 3), name: "Now")
        let longAgo = trip(from: date(2026, 6, 1), to: date(2026, 6, 5), name: "Long ago")
        let recent = trip(from: date(2027, 2, 1), to: date(2027, 2, 4), name: "Recent")

        let sections = TripList.sections([later, longAgo, soon, recent, now_], asOf: now, calendar: calendar)
        #expect(sections.upcoming.map(\.name) == ["Now", "Soon", "Later"])
        #expect(sections.past.map(\.name) == ["Recent", "Long ago"])
    }

    // MARK: Form rules

    private func validDraft() -> TripDraft {
        TripDraft(
            name: "Spring Break 2027",
            destination: "Cancún, Mexico",
            startDate: date(2027, 3, 20),
            endDate: date(2027, 3, 27),
            travelers: 2,
            amountText: TestSupport.amountText("2400.50"),
            notes: "Flights booked"
        )
    }

    @Test("A complete draft is valid")
    func validDraftIsValid() {
        #expect(validDraft().isValid(calendar: calendar))
    }

    struct Breakage: Sendable, CustomTestStringConvertible {
        let label: String
        let apply: @Sendable (inout TripDraft) -> Void
        var testDescription: String { label }
    }

    static let breakages: [Breakage] = [
        Breakage(label: "Empty name") { $0.name = "" },
        Breakage(label: "Whitespace-only name") { $0.name = "  \n " },
        Breakage(label: "Empty destination") { $0.destination = "" },
        Breakage(label: "Whitespace-only destination") { $0.destination = "   " },
        Breakage(label: "End before start") { $0.endDate = TripTests.date(2027, 3, 19) },
        Breakage(label: "Zero total") { $0.amountText = "0" },
        Breakage(label: "No total") { $0.amountText = "" },
        Breakage(label: "Total that isn't a number") { $0.amountText = "abc" },
        Breakage(label: "Negative total") { $0.amountText = "-5" },
        Breakage(label: "No travelers") { $0.travelers = 0 },
        Breakage(label: "More than 20 travelers") { $0.travelers = 21 },
    ]

    @Test("Save stays disabled when a rule is broken", arguments: breakages)
    func invalidDrafts(breakage: Breakage) {
        var draft = validDraft()
        breakage.apply(&draft)
        #expect(!draft.isValid(calendar: calendar))
        #expect(draft.makeTrip(calendar: calendar) == nil)
    }

    @Test("Same-day trips, 1 traveler and 20 travelers are all allowed")
    func boundaryDraftsAreValid() {
        var draft = validDraft()
        draft.endDate = draft.startDate
        #expect(draft.isValid(calendar: calendar))
        draft.travelers = 1
        #expect(draft.isValid(calendar: calendar))
        draft.travelers = 20
        #expect(draft.isValid(calendar: calendar))
    }

    @Test("End later in the same day as start still counts as end ≥ start")
    func endEarlierClockTimeSameDayIsValid() {
        var draft = validDraft()
        draft.startDate = date(2027, 3, 20, hour: 18)
        draft.endDate = date(2027, 3, 20, hour: 7)
        #expect(draft.isValid(calendar: calendar))
    }

    @Test("Saving a draft trims the text and normalizes the dates")
    func makeTripTrimsAndNormalizes() throws {
        var draft = validDraft()
        draft.name = "  Spring Break 2027 "
        draft.destination = "\nCancún, Mexico  "
        let t = try #require(draft.makeTrip(calendar: calendar))
        #expect(t.name == "Spring Break 2027")
        #expect(t.destination == "Cancún, Mexico")
        #expect(t.startDate == calendar.startOfDay(for: date(2027, 3, 20)))
        #expect(t.endDate == calendar.startOfDay(for: date(2027, 3, 27)))
        #expect(t.travelers == 2)
        #expect(t.estimatedTotal == 2400.50)
        #expect(t.estimateSource == "manual")
        #expect(t.notes == "Flights booked")
    }

    @Test("Moving the start past the end pulls the end along")
    func startDateChangeBumpsEnd() {
        var draft = validDraft()
        draft.startDate = date(2027, 4, 2)
        draft.startDateChanged(calendar: calendar)
        #expect(draft.endDate == draft.startDate)

        draft.startDate = date(2027, 3, 30)
        draft.startDateChanged(calendar: calendar)
        #expect(draft.endDate == date(2027, 4, 2), "an end still after the start is left alone")
    }

    @Test("A new draft leaves tomorrow for a week and isn't savable yet")
    func newDraftDefaults() {
        let draft = TripDraft.new(asOf: date(2027, 3, 31, hour: 22), calendar: calendar)
        #expect(draft.startDate == calendar.startOfDay(for: date(2027, 4, 1)))
        #expect(draft.endDate == calendar.startOfDay(for: date(2027, 4, 8)))
        #expect(draft.travelers == 1)
        #expect(!draft.isValid(calendar: calendar))
    }

    @Test("Editing round-trips a trip's values through the form")
    func editRoundTrip() throws {
        let original = try #require(validDraft().makeTrip(calendar: calendar))
        var draft = TripDraft(trip: original)
        #expect(draft.isValid(calendar: calendar))
        #expect(draft.estimatedTotal == 2400.50)

        draft.name = "Spring Break (moved)"
        draft.startDate = date(2027, 4, 3)
        draft.startDateChanged(calendar: calendar)
        draft.travelers = 3
        draft.amountText = "3000"
        #expect(draft.apply(to: original, calendar: calendar))
        #expect(original.name == "Spring Break (moved)")
        #expect(original.startDate == calendar.startOfDay(for: date(2027, 4, 3)))
        #expect(original.endDate == original.startDate)
        #expect(original.travelers == 3)
        #expect(original.estimatedTotal == 3000)
        #expect(original.perPersonTotal == 1000)
    }

    @Test("An invalid edit changes nothing")
    func invalidEditChangesNothing() throws {
        let original = try #require(validDraft().makeTrip(calendar: calendar))
        var draft = TripDraft(trip: original)
        draft.name = "Renamed"
        draft.amountText = "0"
        #expect(!draft.apply(to: original, calendar: calendar))
        #expect(original.name == "Spring Break 2027")
        #expect(original.estimatedTotal == 2400.50)
    }
}
