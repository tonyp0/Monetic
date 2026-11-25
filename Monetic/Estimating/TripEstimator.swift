import Foundation

// MARK: - Travel style

/// How someone plans to travel. Stored on `Trip` as its raw string.
enum TravelStyle: String, CaseIterable, Codable, Identifiable {
    case budget, standard, comfort

    var id: String { rawValue }

    var label: String {
        switch self {
        case .budget:   return "Budget"
        case .standard: return "Standard"
        case .comfort:  return "Comfort"
        }
    }

    var assumptions: StyleAssumptions { StyleAssumptions.table[self]! }
}

// MARK: - Assumptions (product judgment, not data)

/// PRODUCT ASSUMPTIONS. Per diem rates are the most a government traveler may
/// claim for a hotel room and for meals and incidentals ("M&IE"), so they're a
/// ceiling for a business traveler, not what a student on spring break pays.
/// These percentages scale the published rates to a travel style. They are
/// Monetic's judgment, not published figures, and the UI labels them as
/// assumptions.
///
/// Local transport and activities have no government rate at all. Rather than
/// invent dollar amounts, they're expressed as a share of the location's M&IE
/// rate, which at least moves with local prices (a city with expensive meals
/// tends to have expensive taxis and tickets too).
///
/// Percentages are whole numbers so the money math stays in exact integer
/// cents: a whole-dollar rate × a percentage is a whole number of cents.
struct StyleAssumptions: Equatable {
    /// Share of the maximum lodging rate, per room per night.
    let lodgingPercent: Int
    /// Share of the M&IE rate, per person per day.
    let mealsPercent: Int
    /// Share of the M&IE rate spent on local transport, per person per day.
    let localTransportPercent: Int
    /// Share of the M&IE rate spent on activities, per person per day.
    let activitiesPercent: Int
    /// People sharing a room by default. The user can change the room count.
    let peoplePerRoom: Int

    static let table: [TravelStyle: StyleAssumptions] = [
        // Hostels, shared rooms, groceries, public transit, mostly free sights.
        // Judgment: a hostel or basic shared rental should come in well under
        // a business-hotel ceiling, so assume a bit under half; cooking most
        // meals, assume about half the meals rate.
        .budget: StyleAssumptions(lodgingPercent: 45, mealsPercent: 50,
                                  localTransportPercent: 15, activitiesPercent: 20, peoplePerRoom: 2),
        // Mid-range hotel or rental, eating out most meals, a paid activity
        // most days. Judgment: three quarters of the ceiling, since a
        // mid-range stay sits below the business hotels per diem allows for.
        .standard: StyleAssumptions(lodgingPercent: 75, mealsPercent: 80,
                                    localTransportPercent: 25, activitiesPercent: 40, peoplePerRoom: 2),
        // At the government ceiling: the hotel a business traveler would be
        // reimbursed for, every meal out, taxis, a room each.
        .comfort: StyleAssumptions(lodgingPercent: 100, mealsPercent: 100,
                                   localTransportPercent: 40, activitiesPercent: 70, peoplePerRoom: 1),
    ]

    /// The line under the style picker, e.g. "Assumes about 45% of the
    /// government lodging rate and 50% of its meals rate, 2 people per room."
    var summary: String {
        let rooms = peoplePerRoom == 1 ? "a room each" : "\(peoplePerRoom) people per room"
        return "Assumes about \(lodgingPercent)% of the government lodging rate and \(mealsPercent)% of its meals rate, \(rooms). Transport is \(localTransportPercent)% and activities \(activitiesPercent)% of the daily meals rate."
    }
}

// MARK: - Estimate

/// A trip cost breakdown. Amounts are exact U.S. cents. Codable so the
/// breakdown a trip was saved with can be shown later, even after the
/// bundled data is regenerated.
struct TripEstimate: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case lodging, food, localTransport, activities, flights

        var title: String {
            switch self {
            case .lodging:        return "Lodging"
            case .food:           return "Food & incidentals"
            case .localTransport: return "Local transport"
            case .activities:     return "Activities"
            case .flights:        return "Flights"
            }
        }
    }

    struct LineItem: Codable, Equatable, Identifiable {
        let kind: Kind
        let cents: Int
        var id: Kind { kind }
    }

    let lineItems: [LineItem]
    let totalCents: Int
    /// What each traveler pays. Adds up to `totalCents` exactly; when it
    /// doesn't divide evenly, the first few shares are a cent higher.
    let perPersonCents: [Int]

    let travelers: Int
    let nights: Int
    let rooms: Int
    let style: TravelStyle
    /// False when no flight price was entered: the total is "+ flights".
    let includesFlights: Bool

    // Where the rates came from, kept with the estimate.
    let locationID: String
    let locationName: String
    let sourceID: String
    let effective: String

    var total: Double { Double(totalCents) / 100 }
    /// The largest share, so "each" never understates what someone pays.
    var perPerson: Double { Double(perPersonCents.max() ?? 0) / 100 }
    var splitsEvenly: Bool { Set(perPersonCents).count <= 1 }

    func amount(_ item: LineItem) -> Double { Double(item.cents) / 100 }

    /// The line item's fraction of the total, 0...1.
    func share(of item: LineItem) -> Double {
        totalCents > 0 ? Double(item.cents) / Double(totalCents) : 0
    }

    /// Splits `cents` into `count` shares that add back up exactly.
    static func split(_ cents: Int, among count: Int) -> [Int] {
        let count = max(count, 1)
        let base = cents / count
        let remainder = cents % count
        return (0..<count).map { $0 < remainder ? base + 1 : base }
    }
}

// MARK: - Estimator

/// Pure trip-cost math over the bundled per diem rates. No SwiftUI, no
/// SwiftData, no clock: everything it needs is passed in.
enum TripEstimator {
    /// Rooms a style books by default: two to a room for budget and
    /// standard, one each for comfort.
    static func defaultRooms(travelers: Int, style: TravelStyle) -> Int {
        let travelers = max(travelers, 1)
        let perRoom = style.assumptions.peoplePerRoom
        return (travelers + perRoom - 1) / perRoom
    }

    /// - Parameters:
    ///   - nights: nights away; lodging is paid per night, everything else
    ///     per day (nights + 1, so a day trip still eats).
    ///   - flightTotal: the group's flights, as typed by the user. nil or 0
    ///     leaves flights out and marks the estimate "+ flights".
    ///   - rooms: the user's room count; nil uses the style's default. Kept
    ///     between 1 and the number of travelers.
    ///   - startDate: the first day; each night and day is priced at the rate
    ///     for the season it falls in.
    static func estimate(
        location: CostLocation,
        nights: Int,
        travelers: Int,
        style: TravelStyle,
        flightTotal: Double?,
        startDate: Date,
        rooms: Int? = nil,
        calendar: Calendar = .current
    ) -> TripEstimate {
        let nights = max(nights, 0)
        let travelers = max(travelers, 1)
        let rooms = min(max(rooms ?? defaultRooms(travelers: travelers, style: style), 1), travelers)
        let a = style.assumptions
        let firstDay = calendar.startOfDay(for: startDate)

        func rates(onDay offset: Int) -> CostLocation.Season? {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            return location.season(on: day, calendar: calendar)
        }

        // Whole dollars × whole percent = exact cents.
        var lodging = 0
        for night in 0..<nights {
            lodging += (rates(onDay: night)?.lodgingPerNight ?? 0) * a.lodgingPercent * rooms
        }

        var food = 0, transport = 0, activities = 0
        for day in 0...nights {
            let meals = rates(onDay: day)?.mealsPerDay ?? 0
            food += meals * a.mealsPercent * travelers
            transport += meals * a.localTransportPercent * travelers
            activities += meals * a.activitiesPercent * travelers
        }

        var items = [
            TripEstimate.LineItem(kind: .lodging, cents: lodging),
            TripEstimate.LineItem(kind: .food, cents: food),
            TripEstimate.LineItem(kind: .localTransport, cents: transport),
            TripEstimate.LineItem(kind: .activities, cents: activities),
        ]
        let flightCents = Int(((flightTotal ?? 0) * 100).rounded())
        let includesFlights = flightCents > 0
        if includesFlights {
            items.append(TripEstimate.LineItem(kind: .flights, cents: flightCents))
        }

        let total = items.reduce(0) { $0 + $1.cents }
        return TripEstimate(
            lineItems: items,
            totalCents: total,
            perPersonCents: TripEstimate.split(total, among: travelers),
            travelers: travelers,
            nights: nights,
            rooms: rooms,
            style: style,
            includesFlights: includesFlights,
            locationID: location.id,
            locationName: location.displayName,
            sourceID: location.source,
            effective: location.effective
        )
    }

    /// "Based on U.S. government per diem rates (U.S. Department of State,
    /// effective Aug 1, 2024)."
    static func sourceLine(for estimate: TripEstimate) -> String {
        let publisher: String
        switch estimate.sourceID {
        case "gsa": publisher = "U.S. General Services Administration"
        case "dos": publisher = "U.S. Department of State"
        default:    publisher = "U.S. government"
        }
        return "Based on U.S. government per diem rates (\(publisher), effective \(CostDataStore.displayDay(estimate.effective)))."
    }
}
