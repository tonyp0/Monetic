import Foundation
import SwiftData

// MARK: - Trip
/// A planned trip: where, when, for how many people, and what it's expected
/// to cost. The estimate is typed in by the user for now; later work fills it
/// from data and adds savings toward it.
@Model
final class Trip: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String            // "Spring Break 2027"
    var destination: String     // free text for now: "Cancún, Mexico"
    var startDate: Date         // normalized to start of day
    var endDate: Date           // normalized to start of day, >= startDate
    var travelers: Int          // >= 1
    var estimatedTotal: Double  // whole trip, all travelers
    var estimateSource: String  // see `Trip.EstimateSource`
    var notes: String
    var createdAt: Date

    // Estimator inputs and result (prompt 2). Every new property has a
    // default so stores saved before it existed migrate automatically.
    /// The `CostLocation` the estimate used, or nil for a free-text destination.
    var locationID: String? = nil
    /// `TravelStyle` raw value.
    var travelStyle: String = TravelStyle.standard.rawValue
    /// Rooms the user chose; nil means the travel style's default.
    var roomsOverride: Int? = nil
    /// Flights for the whole group, as typed; nil when left empty.
    var flightsTotal: Double? = nil
    /// The `TripEstimate` saved with the trip, JSON-encoded.
    var estimateBreakdown: Data? = nil

    // Savings (prompt 3), also defaulted for migration.
    /// What the user is saving: their share of the trip by default. 0 on
    /// trips saved before savings existed, which then use their share.
    var savingsGoal: Double = 0
    /// The day saving started. nil on older trips, which use the day they
    /// were created.
    var savingsStartDate: Date? = nil
    /// `ContributionCadence` raw value.
    var contributionCadence: String = ContributionCadence.weekly.rawValue
    /// Local reminders on each contribution date. Off until the user turns
    /// them on.
    var remindersEnabled: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \SavingsContribution.trip)
    var contributions: [SavingsContribution] = []

    // Sharing (prompt 4).
    /// The plan's identity across phones: everyone who joins from the same
    /// link gets the same one. Set when the organizer first shares, or when
    /// a trip is joined from a link.
    var shareID: UUID? = nil
    /// When the organizer last opened the share sheet.
    var sharedAt: Date? = nil
    /// When this trip was joined from a friend's link; nil for your own trips.
    var joinedAt: Date? = nil

    // Actual spending (prompt 5): the `TripActuals` logged after the trip,
    // JSON-encoded. nil until the user logs it.
    var actualSpending: Data? = nil

    /// Shared out or joined in: planned with friends.
    var isGroupTrip: Bool { shareID != nil }

    /// Where `estimatedTotal` came from. Stored as its raw string, like
    /// `Transaction.recurringFrequency`, so new sources don't need a migration.
    enum EstimateSource: String {
        /// Typed in, or an estimate the user then edited.
        case manual
        /// Exactly the per diem estimate in `estimateBreakdown`.
        case perDiem
    }

    /// Where a trip sits relative to a given day.
    enum Status: Equatable {
        case upcoming, inProgress, past
    }

    init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        travelers: Int = 1,
        estimatedTotal: Double = 0,
        estimateSource: String = EstimateSource.manual.rawValue,
        notes: String = "",
        createdAt: Date = Date(),
        locationID: String? = nil,
        travelStyle: TravelStyle = .standard,
        roomsOverride: Int? = nil,
        flightsTotal: Double? = nil,
        estimate: TripEstimate? = nil,
        calendar: Calendar = .current
    ) {
        let start = calendar.startOfDay(for: startDate)
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = start
        self.endDate = max(calendar.startOfDay(for: endDate), start)
        self.travelers = max(travelers, 1)
        self.estimatedTotal = estimatedTotal
        self.estimateSource = estimateSource
        self.notes = notes
        self.createdAt = createdAt
        self.locationID = locationID
        self.travelStyle = travelStyle.rawValue
        self.roomsOverride = roomsOverride
        self.flightsTotal = flightsTotal
        self.estimateBreakdown = estimate.flatMap { try? JSONEncoder().encode($0) }
        self.savingsGoal = Self.defaultSavingsGoal(total: estimatedTotal, travelers: self.travelers)
        self.savingsStartDate = calendar.startOfDay(for: createdAt)
    }

    /// The breakdown saved with the trip, if it was estimated.
    var savedEstimate: TripEstimate? {
        get { estimateBreakdown.flatMap { try? JSONDecoder().decode(TripEstimate.self, from: $0) } }
        set { estimateBreakdown = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var style: TravelStyle { TravelStyle(rawValue: travelStyle) ?? .standard }

    /// Per diem estimates are in U.S. dollars and Monetic doesn't convert
    /// currencies, so they're always shown in USD. Totals the user typed are
    /// in their own currency.
    var totalCurrencyCode: String {
        estimateSource == EstimateSource.perDiem.rawValue ? "USD" : Currency.code
    }

    /// Nights away: Mar 14 → Mar 21 is 7.
    func nights(calendar: Calendar = .current) -> Int {
        TripDates.nights(from: startDate, to: endDate, calendar: calendar)
    }

    /// Calendar days covered, counting both ends: Mar 14 → Mar 21 is 8.
    func days(calendar: Calendar = .current) -> Int {
        nights(calendar: calendar) + 1
    }

    /// Whole days from `asOf` until the first day of the trip; 0 once it has started.
    func daysUntilDeparture(asOf date: Date = Date(), calendar: Calendar = .current) -> Int {
        max(TripDates.daysBetween(date, startDate, calendar: calendar), 0)
    }

    func status(asOf date: Date = Date(), calendar: Calendar = .current) -> Status {
        TripDates.status(start: startDate, end: endDate, asOf: date, calendar: calendar)
    }

    /// The estimate split evenly across travelers.
    var perPersonTotal: Double {
        estimatedTotal / Double(max(travelers, 1))
    }

    // MARK: Savings

    /// One traveler's share, rounded up to the cent so the shares cover the total.
    static func defaultSavingsGoal(total: Double, travelers: Int) -> Double {
        (total * 100 / Double(max(travelers, 1))).rounded(.up) / 100
    }

    /// True while the goal is still the automatic share, so it should follow
    /// changes to the total or the number of travelers.
    var savingsGoalFollowsShare: Bool {
        savingsGoal <= 0
            || abs(savingsGoal - Self.defaultSavingsGoal(total: estimatedTotal, travelers: travelers)) < 0.005
    }

    var effectiveSavingsGoal: Double {
        savingsGoal > 0 ? savingsGoal : Self.defaultSavingsGoal(total: estimatedTotal, travelers: travelers)
    }

    var cadence: ContributionCadence {
        ContributionCadence(rawValue: contributionCadence) ?? .weekly
    }

    func savingsStart(calendar: Calendar = .current) -> Date {
        savingsStartDate ?? calendar.startOfDay(for: createdAt)
    }

    /// Deposits minus withdrawals, added up in cents.
    var totalSaved: Double {
        Double(contributions.reduce(0) { $0 + Int(($1.amount * 100).rounded()) }) / 100
    }

    /// Contributions, newest first.
    var sortedContributions: [SavingsContribution] {
        contributions.sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
    }

    func savingsPlan(asOf date: Date, calendar: Calendar = .current, monthlyBudget: Double = 0) -> SavingsPlan {
        SavingsPlan.make(
            goal: effectiveSavingsGoal,
            saved: totalSaved,
            startDate: savingsStart(calendar: calendar),
            departureDate: startDate,
            cadence: cadence,
            asOf: date,
            calendar: calendar,
            monthlyBudget: monthlyBudget
        )
    }
}

// MARK: - Date math
/// Day-level date math shared by `Trip` and `TripDraft`. Everything works on
/// calendar days, never on elapsed seconds, so a 23- or 25-hour day across a
/// DST change still counts as one day.
enum TripDates {
    /// Calendar days from the day containing `from` to the day containing `to`.
    /// Negative when `to` is earlier.
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Nights between two trip days, never negative.
    static func nights(from start: Date, to end: Date, calendar: Calendar) -> Int {
        max(daysBetween(start, end, calendar: calendar), 0)
    }

    static func status(start: Date, end: Date, asOf date: Date, calendar: Calendar) -> Trip.Status {
        if daysBetween(date, start, calendar: calendar) > 0 { return .upcoming }
        if daysBetween(end, date, calendar: calendar) > 0 { return .past }
        return .inProgress
    }
}

// MARK: - List ordering
/// How the Trips list splits and orders trips. Kept out of the view so it can
/// be tested against fixed dates.
enum TripList {
    /// Upcoming and in-progress trips, soonest departure first, and past trips,
    /// most recently finished first.
    static func sections(
        _ trips: [Trip],
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> (upcoming: [Trip], past: [Trip]) {
        var upcoming: [Trip] = []
        var past: [Trip] = []
        for trip in trips {
            if trip.status(asOf: date, calendar: calendar) == .past {
                past.append(trip)
            } else {
                upcoming.append(trip)
            }
        }
        upcoming.sort { ($0.startDate, $0.createdAt) < ($1.startDate, $1.createdAt) }
        past.sort { ($0.endDate, $0.createdAt) > ($1.endDate, $1.createdAt) }
        return (upcoming, past)
    }

    /// The short countdown shown on a trip row: "in 42 days", "Happening now", "Ended".
    static func countdownText(for trip: Trip, asOf date: Date = Date(), calendar: Calendar = .current) -> String {
        switch trip.status(asOf: date, calendar: calendar) {
        case .upcoming:
            let days = trip.daysUntilDeparture(asOf: date, calendar: calendar)
            return days == 1 ? "in 1 day" : "in \(days) days"
        case .inProgress:
            return "Happening now"
        case .past:
            return "Ended"
        }
    }

    /// "Day trip", "1 night", "7 nights".
    static func nightsText(_ nights: Int) -> String {
        switch nights {
        case ..<1: return "Day trip"
        case 1:    return "1 night"
        default:   return "\(nights) nights"
        }
    }

    /// "Mar 14 – 21, 2027" in the user's locale.
    static func dateRangeText(start: Date, end: Date) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: start, to: end)
    }
}
