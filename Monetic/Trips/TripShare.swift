import Foundation

// MARK: - Payload

/// What a trip link carries: the plan, never the money. No contributions,
/// notes, budget or savings settings ever go in here.
///
/// Encoded as compact JSON with one- or two-letter keys, then base64url,
/// in `monetic://trip?d=…`. Amounts are whole cents so there are no
/// floating-point values to validate.
struct TripSharePayload: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var shareID: UUID
    var name: String
    var destination: String
    var locationID: String?
    /// "yyyy-MM-dd" calendar days.
    var startDay: String
    var endDay: String
    var travelers: Int
    var style: String
    /// The whole trip, all travelers.
    var totalCents: Int
    /// Currency of the amounts: USD for per diem estimates.
    var currencyCode: String
    /// `Trip.EstimateSource` raw value.
    var source: String
    /// One traveler's share of the total.
    var perPersonCents: Int
    var rooms: Int?
    var flightsCents: Int?
    var breakdown: Breakdown?

    /// The estimate's line items in `TripEstimate.Kind` order (lodging, food,
    /// local transport, activities, then flights if included).
    struct Breakdown: Codable, Equatable {
        var cents: [Int]
        var sourceID: String
        var effective: String

        enum CodingKeys: String, CodingKey {
            case cents = "c", sourceID = "s", effective = "x"
        }
    }

    enum CodingKeys: String, CodingKey {
        case version = "v", shareID = "id", name = "n", destination = "d", locationID = "l"
        case startDay = "s", endDay = "e", travelers = "t", style = "y", totalCents = "a"
        case currencyCode = "c", source = "o", perPersonCents = "g", rooms = "r"
        case flightsCents = "f", breakdown = "b"
    }
}

// MARK: - Errors

/// Why a trip link couldn't be opened. Every message is safe to show as is.
enum TripShareError: Error, Equatable {
    case notATripLink
    case tooLong
    case malformed
    case newerVersion
    case invalid(field: String)

    var title: String {
        self == .newerVersion ? "Update Monetic to open this trip" : "This trip link doesn't work"
    }

    var message: String {
        switch self {
        case .notATripLink:
            return "Monetic can only open trip links."
        case .tooLong, .malformed:
            return "The link looks incomplete or damaged. Ask your friend to share it again."
        case .newerVersion:
            return "It was shared from a newer version of Monetic. Update the app from the App Store, then open the link again."
        case .invalid(let field):
            return "Part of the plan (\(field)) isn't valid, so it wasn't imported. Ask your friend to share it again."
        }
    }
}

// MARK: - Validated share

/// A trip link that has passed every check, with real types in place of the
/// payload's strings and cents.
struct TripShare: Equatable {
    static let scheme = "monetic"
    static let host = "trip"
    static let queryName = "d"

    // Limits for untrusted input.
    static let maxURLLength = 2_000
    static let maxNameLength = 80
    static let maxDestinationLength = 120
    static let maxLocationIDLength = 64
    static let maxNights = 365
    static let maxCents = 100_000_000   // $1,000,000

    let shareID: UUID
    let name: String
    let destination: String
    let locationID: String?
    let startDate: Date
    let endDate: Date
    let travelers: Int
    let style: TravelStyle
    let total: Double
    let currencyCode: String
    let source: Trip.EstimateSource
    let perPersonShare: Double
    let rooms: Int?
    let flightsTotal: Double?
    let estimate: TripEstimate?

    // MARK: Out

    /// The plan of `trip`, ready to share.
    static func payload(for trip: Trip, calendar: Calendar = .current) -> TripSharePayload {
        let estimate = trip.savedEstimate
        return TripSharePayload(
            version: TripSharePayload.currentVersion,
            shareID: trip.shareID ?? trip.id,
            name: trip.name,
            destination: trip.destination,
            locationID: estimate == nil ? nil : trip.locationID,
            startDay: dayString(trip.startDate, calendar: calendar),
            endDay: dayString(trip.endDate, calendar: calendar),
            travelers: trip.travelers,
            style: trip.style.rawValue,
            totalCents: cents(trip.estimatedTotal),
            currencyCode: trip.totalCurrencyCode,
            source: Trip.EstimateSource(rawValue: trip.estimateSource)?.rawValue ?? Trip.EstimateSource.manual.rawValue,
            perPersonCents: cents(Trip.defaultSavingsGoal(total: trip.estimatedTotal, travelers: trip.travelers)),
            rooms: estimate == nil ? nil : trip.roomsOverride,
            flightsCents: estimate == nil ? nil : trip.flightsTotal.map(cents),
            breakdown: estimate.map {
                .init(cents: $0.lineItems.map(\.cents), sourceID: $0.sourceID, effective: $0.effective)
            }
        )
    }

    static func url(for payload: TripSharePayload) -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let json = (try? encoder.encode(payload)) ?? Data()
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: queryName, value: base64URL(json))]
        return components.url!
    }

    static func url(for trip: Trip, calendar: Calendar = .current) -> URL {
        url(for: payload(for: trip, calendar: calendar))
    }

    /// "I'm planning Spring Break in Cancún, Mar 14 – 21. About $640 each.
    /// Join the plan in Monetic:" (the link follows).
    static func inviteMessage(for trip: Trip) -> String {
        let each = Trip.defaultSavingsGoal(total: trip.estimatedTotal, travelers: trip.travelers)
            .formatted(.currency(code: trip.totalCurrencyCode).precision(.fractionLength(0)))
        let dates = TripList.dateRangeText(start: trip.startDate, end: trip.endDate)
        let cost = trip.travelers > 1 ? "About \(each) each." : "About \(each)."
        return "I'm planning \(trip.name) in \(trip.destination), \(dates). \(cost) Join the plan in Monetic:"
    }

    // MARK: In

    /// Reads and validates a trip link. Throws a `TripShareError` for
    /// anything that isn't a complete, sensible plan; never traps.
    static func decode(_ url: URL, store: CostDataStore?, calendar: Calendar = .current) throws -> TripShare {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == host else {
            throw TripShareError.notATripLink
        }
        guard url.absoluteString.count <= maxURLLength else { throw TripShareError.tooLong }
        guard let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == queryName })?.value,
              let data = dataFromBase64URL(encoded) else {
            throw TripShareError.malformed
        }

        // Check the version on its own first: a newer payload may not decode
        // as this one at all.
        struct VersionOnly: Decodable { let v: Int }
        guard let version = try? JSONDecoder().decode(VersionOnly.self, from: data).v else {
            throw TripShareError.malformed
        }
        guard version <= TripSharePayload.currentVersion else { throw TripShareError.newerVersion }
        guard version >= 1 else { throw TripShareError.malformed }

        guard let payload = try? JSONDecoder().decode(TripSharePayload.self, from: data) else {
            throw TripShareError.malformed
        }
        return try validate(payload, store: store, calendar: calendar)
    }

    static func validate(_ p: TripSharePayload, store: CostDataStore?, calendar: Calendar = .current) throws -> TripShare {
        func invalid(_ field: String) -> TripShareError { .invalid(field: field) }

        let name = try cleanText(p.name, max: maxNameLength, field: "name")
        let destination = try cleanText(p.destination, max: maxDestinationLength, field: "destination")

        guard let start = date(fromDay: p.startDay, calendar: calendar) else { throw invalid("start date") }
        guard let end = date(fromDay: p.endDay, calendar: calendar) else { throw invalid("end date") }
        let nights = TripDates.daysBetween(start, end, calendar: calendar)
        guard nights >= 0 else { throw invalid("dates") }
        guard nights <= maxNights else { throw invalid("trip length") }

        guard TripDraft.travelerRange.contains(p.travelers) else { throw invalid("travelers") }
        guard let style = TravelStyle(rawValue: p.style) else { throw invalid("travel style") }
        guard let source = Trip.EstimateSource(rawValue: p.source) else { throw invalid("estimate source") }
        guard p.currencyCode.count == 3, p.currencyCode.allSatisfy({ $0.isASCII && $0.isUppercase }) else {
            throw invalid("currency")
        }

        guard (1...maxCents).contains(p.totalCents) else { throw invalid("total") }
        guard (0...p.totalCents).contains(p.perPersonCents) else { throw invalid("per-person goal") }
        if let rooms = p.rooms, !(1...p.travelers).contains(rooms) { throw invalid("rooms") }
        if let flights = p.flightsCents, !(0...maxCents).contains(flights) { throw invalid("flights") }

        // A location ID must be one this app's data knows.
        var location: CostLocation?
        if let id = p.locationID {
            guard !id.isEmpty, id.count <= maxLocationIDLength,
                  let found = store?.location(id: id) else { throw invalid("location") }
            location = found
        }

        var estimate: TripEstimate?
        if let breakdown = p.breakdown {
            guard let location else { throw invalid("estimate") }
            estimate = try makeEstimate(breakdown, payload: p, location: location, nights: nights, style: style)
        } else if source == .perDiem {
            throw invalid("estimate")
        }
        if source == .perDiem, estimate?.totalCents != p.totalCents { throw invalid("total") }

        return TripShare(
            shareID: p.shareID, name: name, destination: destination, locationID: location?.id,
            startDate: start, endDate: end, travelers: p.travelers, style: style,
            total: dollars(p.totalCents), currencyCode: p.currencyCode, source: source,
            perPersonShare: dollars(p.perPersonCents),
            rooms: estimate == nil ? nil : p.rooms,
            flightsTotal: estimate == nil ? nil : p.flightsCents.flatMap { $0 > 0 ? dollars($0) : nil },
            estimate: estimate
        )
    }

    private static func makeEstimate(_ b: TripSharePayload.Breakdown, payload p: TripSharePayload,
                                     location: CostLocation, nights: Int, style: TravelStyle) throws -> TripEstimate {
        let kinds = TripEstimate.Kind.allCases   // lodging, food, transport, activities, flights
        guard b.cents.count == kinds.count - 1 || b.cents.count == kinds.count,
              b.cents.allSatisfy({ (0...maxCents).contains($0) }) else { throw TripShareError.invalid(field: "estimate") }
        guard ["gsa", "dos"].contains(b.sourceID), CostDataStore.date(fromDay: b.effective) != nil else {
            throw TripShareError.invalid(field: "estimate")
        }
        let includesFlights = b.cents.count == kinds.count
        if includesFlights ? b.cents.last != p.flightsCents : (p.flightsCents ?? 0) > 0 {
            throw TripShareError.invalid(field: "flights")
        }

        let items = zip(kinds, b.cents).map { TripEstimate.LineItem(kind: $0, cents: $1) }
        let total = b.cents.reduce(0, +)
        guard total <= maxCents else { throw TripShareError.invalid(field: "estimate") }
        return TripEstimate(
            lineItems: items, totalCents: total,
            perPersonCents: TripEstimate.split(total, among: p.travelers),
            travelers: p.travelers, nights: nights,
            rooms: p.rooms ?? TripEstimator.defaultRooms(travelers: p.travelers, style: style),
            style: style, includesFlights: includesFlights,
            locationID: location.id, locationName: location.displayName,
            sourceID: b.sourceID, effective: b.effective
        )
    }

    // MARK: Helpers

    /// Trimmed, non-empty, not too long, no control characters.
    private static func cleanText(_ text: String, max: Int, field: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= max,
              trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw TripShareError.invalid(field: field)
        }
        return trimmed
    }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Strictly "yyyy-MM-dd" for a real day, as the start of that day.
    static func date(fromDay day: String, calendar: Calendar) -> Date? {
        let parts = day.split(separator: "-", omittingEmptySubsequences: false)
        guard day.count == 10, parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (2000...2100).contains(y) else { return nil }
        let components = DateComponents(year: y, month: m, day: d)
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else { return nil }
        return calendar.startOfDay(for: date)
    }

    private static func cents(_ amount: Double) -> Int { Int((amount * 100).rounded()) }
    private static func dollars(_ cents: Int) -> Double { Double(cents) / 100 }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func dataFromBase64URL(_ text: String) -> Data? {
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else {
            return nil
        }
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }
}
