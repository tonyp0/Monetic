import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "Describe your trip": turns a `TripIntent` into form values. Everything
/// here is deterministic; the only model call is behind `TripIntentExtracting`.
enum TripAssistant {

    // MARK: Availability

    enum Availability: Equatable {
        case available
        /// Older than iOS 26: no on-device model.
        case unsupportedOS
        /// The device can't run Apple Intelligence.
        case deviceNotEligible
        /// Apple Intelligence is turned off in Settings.
        case appleIntelligenceOff
        /// Still downloading, or otherwise not ready yet.
        case modelNotReady
        /// A reason newer than this app.
        case unavailable
    }

    static func availability() -> Availability {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return .unsupportedOS }
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.deviceNotEligible): return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): return .appleIntelligenceOff
        case .unavailable(.modelNotReady): return .modelNotReady
        case .unavailable: return .unavailable
        }
        #else
        return .unsupportedOS
        #endif
    }

    /// The extractor Add Trip should offer, or nil to show only the form.
    static func makeExtractor() -> (any TripIntentExtracting)? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-UITestingFakeTripAssistant") { return CannedTripIntentExtractor() }
        // UI tests never depend on whether this simulator has the model.
        if arguments.contains("-UITesting") { return nil }
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), availability() == .available {
            return SystemTripIntentExtractor()
        }
        #endif
        return nil
    }

    // MARK: Extraction

    enum Failure: Error, Equatable {
        case timedOut
    }

    static let defaultTimeout: Duration = .seconds(10)

    /// Runs the extractor off the main actor, giving up after `timeout`.
    static func extract(
        _ text: String,
        using extractor: any TripIntentExtracting,
        today: Date,
        calendar: Calendar = .current,
        timeout: Duration = defaultTimeout
    ) async throws -> TripIntent {
        try await withThrowingTaskGroup(of: TripIntent.self) { group in
            group.addTask { try await extractor.extract(from: text, today: today, calendar: calendar) }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw Failure.timedOut
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw Failure.timedOut }
            return first
        }
    }

    // MARK: Filling the form

    /// The values the assistant put in the form. A field shows as filled
    /// from the description while the draft still holds this value, so the
    /// mark goes away as soon as the user changes it.
    struct Fill: Equatable {
        var name: String?
        var destination: String?
        /// The destination matched more than one place: show the choices.
        var destinationIsAmbiguous = false
        var startDate: Date?
        var endDate: Date?
        var travelers: Int?
        var style: TravelStyle?
        /// A flight price the user wrote, shown as "you said".
        var flightsText: String?
        /// Things the description said that the form couldn't take.
        var problems: [String] = []

        var isEmpty: Bool {
            name == nil && destination == nil && startDate == nil && travelers == nil
                && style == nil && flightsText == nil
        }
    }

    static let maxDestinationLength = 120
    static let maxQuotedFlights = 1_000_000.0

    /// Applies what the description said to `draft`. Only fields the intent
    /// mentions change. No amount comes from the intent except a flight price
    /// that appears in `text`; the total is left to the estimator.
    static func apply(
        _ intent: TripIntent,
        text: String,
        to draft: inout TripDraft,
        store: CostDataStore?,
        today: Date,
        calendar: Calendar = .current
    ) -> Fill {
        var fill = Fill()

        if let query = intent.destinationQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
           !query.isEmpty, query.count <= maxDestinationLength {
            let matches = store?.search(query, limit: 5) ?? []
            if matches.count == 1, let only = matches.first {
                draft.select(only)
            } else {
                draft.destination = query
                draft.locationID = nil
                fill.destinationIsAmbiguous = matches.count > 1
            }
            fill.destination = draft.destination
            if draft.trimmedName.isEmpty {
                let place = matches.count == 1 ? matches[0].name : String(query.split(separator: ",")[0])
                draft.name = "\(place) trip"
                fill.name = draft.name
            }
        }

        if let dates = resolveDates(start: intent.startDate, end: intent.endDate,
                                    tripNights: draft.nights(calendar: calendar), today: today, calendar: calendar) {
            draft.startDate = dates.start
            draft.endDate = dates.end
            fill.startDate = dates.start
            fill.endDate = dates.end
        } else if intent.startDate != nil || intent.endDate != nil {
            fill.problems.append("Couldn't work out the dates. Set them below.")
        }

        if let travelers = intent.travelers {
            if TripDraft.travelerRange.contains(travelers) {
                draft.travelers = travelers
                fill.travelers = travelers
            } else {
                fill.problems.append("Trips can have 1 to \(TripDraft.travelerRange.upperBound) travelers. Set the number below.")
            }
        }

        if let style = intent.style.flatMap({ TravelStyle(rawValue: $0.lowercased()) }) {
            draft.travelStyle = style
            fill.style = style
        }

        if let flights = intent.quotedFlightTotal, flights > 0, flights <= maxQuotedFlights,
           mentions(flights, in: text) {
            draft.flightsText = AmountInput.text(cents: Int((flights * 100).rounded()))
            fill.flightsText = draft.flightsText
        }

        return fill
    }

    /// True when `amount` is a number the user actually wrote, so a price
    /// the model made up never reaches the form. "$1,200" and "1200.00" both
    /// count for 1200.
    static func mentions(_ amount: Double, in text: String) -> Bool {
        let numbers = text.matches(of: #/\d[\d,]*(?:\.\d+)?/#).compactMap {
            Double($0.output.replacingOccurrences(of: ",", with: ""))
        }
        return numbers.contains { abs($0 - amount) < 0.005 }
    }

    // MARK: Dates

    /// Turns the days the user wrote into trip dates, relative to `today`.
    /// Without a year, a day means its next occurrence: "March" in November
    /// is next March. A missing end keeps the trip's current length; an end
    /// with no month takes the start's month ("March 14–21"), or the next
    /// month when the day is earlier ("March 28–3"). Returns nil when the
    /// days don't make a trip.
    static func resolveDates(
        start: TripIntent.Day?,
        end: TripIntent.Day?,
        tripNights: Int,
        today: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        let today = calendar.startOfDay(for: today)
        let nights = max(tripNights, 0)

        let startDate: Date
        let endDate: Date
        if let start {
            guard let resolved = resolve(start, onOrAfter: today, calendar: calendar) else { return nil }
            startDate = resolved
            if let end {
                var day = end
                if day.month == nil, day.day != nil {
                    let startMonth = calendar.component(.month, from: startDate)
                    let startDay = calendar.component(.day, from: startDate)
                    day.month = (day.day ?? 0) < startDay ? startMonth % 12 + 1 : startMonth
                }
                guard let resolvedEnd = resolve(day, onOrAfter: startDate, calendar: calendar) else { return nil }
                endDate = resolvedEnd
            } else {
                endDate = calendar.date(byAdding: .day, value: nights, to: startDate) ?? startDate
            }
        } else if let end {
            guard let resolvedEnd = resolve(end, onOrAfter: today, calendar: calendar) else { return nil }
            endDate = resolvedEnd
            startDate = max(calendar.date(byAdding: .day, value: -nights, to: endDate) ?? endDate, today)
        } else {
            return nil
        }

        let length = TripDates.daysBetween(startDate, endDate, calendar: calendar)   // unclamped: catches backwards trips
        guard length >= 0, length <= 365 else { return nil }
        return (startDate, endDate)
    }

    /// One day, given a month. No day means the 1st (or tomorrow, for the
    /// current month). No year means the first such day on or after `floor`.
    private static func resolve(_ day: TripIntent.Day, onOrAfter floor: Date, calendar: Calendar) -> Date? {
        guard let month = day.month, (1...12).contains(month) else { return nil }
        if let d = day.day, !(1...31).contains(d) { return nil }

        func make(_ year: Int) -> Date? {
            let components = DateComponents(year: year, month: month, day: day.day ?? 1)
            guard let date = calendar.date(from: components),
                  calendar.component(.month, from: date) == month else { return nil }   // e.g. Feb 30
            return calendar.startOfDay(for: date)
        }

        if let year = day.year {
            guard (2000...2100).contains(year) else { return nil }
            return make(year)
        }
        let year = calendar.component(.year, from: floor)
        if day.day == nil, month == calendar.component(.month, from: floor) {
            // "in November", said in November: from tomorrow, not the 1st.
            return calendar.date(byAdding: .day, value: 1, to: floor)
        }
        // Feb 29 may only exist in a later year, so look a few years ahead.
        for candidateYear in year...(year + 4) {
            if let date = make(candidateYear), date >= floor { return date }
        }
        return nil
    }
}

#if DEBUG
/// UI tests' stand-in for the model (`-UITestingFakeTripAssistant`): always
/// reads the same Cancún trip, so the test sentence must quote "$1,200".
struct CannedTripIntentExtractor: TripIntentExtracting {
    func extract(from text: String, today: Date, calendar: Calendar) async throws -> TripIntent {
        if text.localizedCaseInsensitiveContains("fail") { throw TripAssistant.Failure.timedOut }
        return TripIntent(
            destinationQuery: "Cancun",
            startDate: .init(month: 3, day: 14),
            endDate: .init(month: 3, day: 21),
            travelers: 5,
            style: "budget",
            quotedFlightTotal: 1200
        )
    }
}
#endif
