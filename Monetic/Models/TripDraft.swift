import Foundation

// MARK: - Trip Draft
/// The editable state behind the Add Trip and Edit Trip screens. All the
/// rules for when Save is allowed live here, so they can be tested without
/// a view.
struct TripDraft: Equatable {
    static let travelerRange = 1...20

    var name: String = ""
    var destination: String = ""
    var startDate: Date
    var endDate: Date
    var travelers: Int = 1
    /// Raw text from the amount field, as typed.
    var amountText: String = ""
    var notes: String = ""

    init(
        name: String = "",
        destination: String = "",
        startDate: Date,
        endDate: Date,
        travelers: Int = 1,
        amountText: String = "",
        notes: String = ""
    ) {
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.travelers = travelers
        self.amountText = amountText
        self.notes = notes
    }

    /// A blank trip: leaving tomorrow, for a week.
    static func new(asOf date: Date = Date(), calendar: Calendar = .current) -> TripDraft {
        let today = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return TripDraft(startDate: start, endDate: end)
    }

    /// The current values of an existing trip, for editing.
    init(trip: Trip) {
        self.init(
            name: trip.name,
            destination: trip.destination,
            startDate: trip.startDate,
            endDate: trip.endDate,
            travelers: trip.travelers,
            amountText: String(format: "%.2f", trip.estimatedTotal),
            notes: trip.notes
        )
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedDestination: String { destination.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The typed total, or nil if it isn't a plain number.
    var estimatedTotal: Double? { AmountInput.parse(amountText) }

    func nights(calendar: Calendar = .current) -> Int {
        TripDates.nights(from: startDate, to: endDate, calendar: calendar)
    }

    /// Save is allowed only when every rule here holds.
    func isValid(calendar: Calendar = .current) -> Bool {
        !trimmedName.isEmpty
            && !trimmedDestination.isEmpty
            && TripDates.daysBetween(startDate, endDate, calendar: calendar) >= 0
            && Self.travelerRange.contains(travelers)
            && (estimatedTotal ?? 0) > 0
    }

    /// Keeps the end date from falling before a newly chosen start date.
    mutating func startDateChanged(calendar: Calendar = .current) {
        if TripDates.daysBetween(startDate, endDate, calendar: calendar) < 0 {
            endDate = startDate
        }
    }

    /// The trip Add Trip's Save inserts, or nil when the draft isn't valid.
    func makeTrip(calendar: Calendar = .current) -> Trip? {
        guard isValid(calendar: calendar), let total = estimatedTotal else { return nil }
        return Trip(
            name: trimmedName,
            destination: trimmedDestination,
            startDate: startDate,
            endDate: endDate,
            travelers: travelers,
            estimatedTotal: total,
            estimateSource: Trip.EstimateSource.manual.rawValue,
            notes: notes,
            calendar: calendar
        )
    }

    /// Writes the draft onto `trip`. Returns false, changing nothing, when the
    /// draft isn't valid.
    @discardableResult
    func apply(to trip: Trip, calendar: Calendar = .current) -> Bool {
        guard isValid(calendar: calendar), let total = estimatedTotal else { return false }
        let start = calendar.startOfDay(for: startDate)
        trip.name = trimmedName
        trip.destination = trimmedDestination
        trip.startDate = start
        trip.endDate = max(calendar.startOfDay(for: endDate), start)
        trip.travelers = travelers
        if total != trip.estimatedTotal {
            trip.estimatedTotal = total
            trip.estimateSource = Trip.EstimateSource.manual.rawValue
        }
        trip.notes = notes
        return true
    }
}
