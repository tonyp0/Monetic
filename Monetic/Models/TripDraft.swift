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

    // Estimator inputs (prompt 2).
    /// The picked `CostLocation`; nil for free text, which needs a typed total.
    var locationID: String? = nil
    var travelStyle: TravelStyle = .standard
    /// Rooms the user chose; nil follows the style's default.
    var roomsOverride: Int? = nil
    /// Flights for the whole group, as typed.
    var flightsText: String = ""

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

    /// The current values of an existing trip, for editing. A trip whose
    /// total was the estimate keeps following it (`estimate` is the fresh one).
    init(trip: Trip, estimate: TripEstimate? = nil) {
        self.init(
            name: trip.name,
            destination: trip.destination,
            startDate: trip.startDate,
            endDate: trip.endDate,
            travelers: trip.travelers,
            amountText: AmountInput.text(cents: Int((trip.estimatedTotal * 100).rounded()), code: trip.totalCurrencyCode),
            notes: trip.notes
        )
        locationID = trip.locationID
        travelStyle = trip.style
        roomsOverride = trip.roomsOverride
        flightsText = trip.flightsTotal.map { AmountInput.text(cents: Int(($0 * 100).rounded()), code: "USD") } ?? ""
        if trip.estimateSource == Trip.EstimateSource.perDiem.rawValue, let estimate {
            amountText = AmountInput.text(cents: estimate.totalCents, code: "USD")
        }
    }

    // MARK: Estimate

    var flightsTotal: Double? {
        AmountInput.parse(flightsText).flatMap { $0 > 0 ? $0 : nil }
    }

    var rooms: Int {
        min(max(roomsOverride ?? TripEstimator.defaultRooms(travelers: travelers, style: travelStyle), 1),
            max(travelers, 1))
    }

    func estimate(location: CostLocation?, calendar: Calendar = .current) -> TripEstimate? {
        guard let location else { return nil }
        return TripEstimator.estimate(
            location: location, nights: nights(calendar: calendar), travelers: travelers,
            style: travelStyle, flightTotal: flightsTotal, startDate: startDate,
            rooms: roomsOverride, calendar: calendar
        )
    }

    /// True when the total field holds exactly the estimate.
    func isUsingEstimate(_ estimate: TripEstimate?) -> Bool {
        guard let estimate else { return false }
        return AmountInput.cents(amountText) == estimate.totalCents
    }

    /// Keeps the total following the estimate until the user edits it: an
    /// empty field, or one still showing the old estimate, takes the new one.
    mutating func estimateChanged(from old: TripEstimate?, to new: TripEstimate?) {
        guard let new else { return }
        let blank = amountText.trimmingCharacters(in: .whitespaces).isEmpty
        if blank || (old.map { AmountInput.cents(amountText) == $0.totalCents } ?? false) {
            amountText = AmountInput.text(cents: new.totalCents, code: "USD")
        }
    }

    mutating func useEstimate(_ estimate: TripEstimate) {
        amountText = AmountInput.text(cents: estimate.totalCents, code: "USD")
    }

    mutating func select(_ location: CostLocation) {
        locationID = location.id
        destination = location.displayName
    }

    /// Typing over a picked place's name unpicks it.
    mutating func destinationEdited(pickedName: String?) {
        if let pickedName, destination != pickedName { locationID = nil }
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
    func makeTrip(estimate: TripEstimate? = nil, calendar: Calendar = .current) -> Trip? {
        guard isValid(calendar: calendar), let total = estimatedTotal else { return nil }
        let source: Trip.EstimateSource = isUsingEstimate(estimate) ? .perDiem : .manual
        return Trip(
            name: trimmedName,
            destination: trimmedDestination,
            startDate: startDate,
            endDate: endDate,
            travelers: travelers,
            estimatedTotal: total,
            estimateSource: source.rawValue,
            notes: notes,
            locationID: estimate == nil ? nil : locationID,
            travelStyle: travelStyle,
            roomsOverride: roomsOverride,
            flightsTotal: flightsTotal,
            estimate: estimate,
            calendar: calendar
        )
    }

    /// Writes the draft onto `trip`. Returns false, changing nothing, when the
    /// draft isn't valid.
    @discardableResult
    func apply(to trip: Trip, estimate: TripEstimate? = nil, calendar: Calendar = .current) -> Bool {
        guard isValid(calendar: calendar), let total = estimatedTotal else { return false }
        let goalFollowsShare = trip.savingsGoalFollowsShare
        let start = calendar.startOfDay(for: startDate)
        trip.name = trimmedName
        trip.destination = trimmedDestination
        trip.startDate = start
        trip.endDate = max(calendar.startOfDay(for: endDate), start)
        trip.travelers = travelers
        trip.travelStyle = travelStyle.rawValue
        trip.roomsOverride = roomsOverride
        trip.flightsTotal = flightsTotal
        trip.notes = notes

        if let estimate {
            trip.estimateSource = (isUsingEstimate(estimate) ? Trip.EstimateSource.perDiem : .manual).rawValue
            trip.locationID = locationID
            trip.savedEstimate = estimate
        } else if locationID != nil, locationID == trip.locationID {
            // The picked place is no longer in the bundled data, so nothing
            // can be re-estimated. Keep the saved breakdown, and keep the total
            // a per diem one (in USD) unless the user changed it.
            if AmountInput.cents(amountText) != Int((trip.estimatedTotal * 100).rounded()) {
                trip.estimateSource = Trip.EstimateSource.manual.rawValue
            }
        } else {
            trip.estimateSource = Trip.EstimateSource.manual.rawValue
            trip.locationID = nil
            trip.savedEstimate = nil
        }
        trip.estimatedTotal = total
        if goalFollowsShare {
            trip.savingsGoal = Trip.defaultSavingsGoal(total: total, travelers: travelers)
        }
        return true
    }
}
