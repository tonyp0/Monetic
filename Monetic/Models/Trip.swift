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

    /// Where `estimatedTotal` came from. Stored as its raw string, like
    /// `Transaction.recurringFrequency`, so new sources don't need a migration.
    enum EstimateSource: String {
        case manual
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
