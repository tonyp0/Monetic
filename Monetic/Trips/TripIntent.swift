import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Intent

/// What a trip description *says*: words turned into form inputs. The rule
/// is that AI understands words and data supplies numbers, so there are no
/// cost fields here apart from a flight price the user typed themselves
/// (`quotedFlightTotal`), and `TripAssistant` keeps even that only when the
/// number is in the user's own text. Every other amount comes from
/// `TripEstimator` or the user.
struct TripIntent: Equatable, Sendable {
    /// A calendar day as written: "March 14" has no year, "the 21st" no month.
    /// `TripAssistant.resolveDates` turns it into a date.
    struct Day: Equatable, Sendable {
        var month: Int?
        var day: Int?
        var year: Int?
    }

    var destinationQuery: String?
    var startDate: Day?
    var endDate: Day?
    var travelers: Int?
    /// A `TravelStyle` raw value.
    var style: String?
    /// The group's flight price, only when the user wrote one.
    var quotedFlightTotal: Double?
}

/// Reads a trip description. Behind a protocol so tests use a deterministic
/// fake and never depend on a language model.
protocol TripIntentExtracting: Sendable {
    func extract(from text: String, today: Date, calendar: Calendar) async throws -> TripIntent
}

// MARK: - On-device model (iOS 26+, Apple Intelligence)

#if canImport(FoundationModels)
@available(iOS 26.0, *)
extension TripIntent {
    /// The shape the on-device model fills in (guided generation). Mirrors
    /// `TripIntent`; the style is constrained to the app's `TravelStyle` cases.
    @Generable(description: "The details a person gave about a trip they're planning. Leave out anything they didn't say.")
    struct Generated {
        @Guide(description: "Where they're going, as written: a city, plus the state or country if they gave one. Not the trip's name or occasion.")
        var destinationQuery: String?

        @Guide(description: "The first day of the trip.")
        var startDate: GeneratedDay?

        @Guide(description: "The last day of the trip. For \"March 14-21\" this is March 21.")
        var endDate: GeneratedDay?

        @Guide(description: "How many people are going, counting the person writing. \"Me and 4 friends\" or \"with 4 friends\" is 5.")
        var travelers: Int?

        @Guide(description: "budget if they say cheap, budget, hostel, or on a shoestring; comfort if they say nice, fancy, luxury, or splurge; standard if they say mid-range. Leave out if they don't say.",
               .anyOf(TravelStyle.allCases.map(\.rawValue)))
        var style: String?

        @Guide(description: "The total flight price for the group, only if they wrote a number for flights. Never guess or estimate one.")
        var quotedFlightTotal: Double?
    }

    @Generable(description: "A calendar day as the person wrote it.")
    struct GeneratedDay {
        @Guide(description: "Month number, 1 to 12, if given.")
        var month: Int?
        @Guide(description: "Day of the month, 1 to 31, if given.")
        var day: Int?
        @Guide(description: "Four-digit year, only if they wrote one.")
        var year: Int?
    }

    init(_ generated: Generated) {
        func day(_ d: GeneratedDay?) -> Day? { d.map { Day(month: $0.month, day: $0.day, year: $0.year) } }
        self.init(
            destinationQuery: generated.destinationQuery,
            startDate: day(generated.startDate),
            endDate: day(generated.endDate),
            travelers: generated.travelers,
            style: generated.style,
            quotedFlightTotal: generated.quotedFlightTotal
        )
    }
}

/// Apple's on-device model. Nothing leaves the phone.
@available(iOS 26.0, *)
struct SystemTripIntentExtractor: TripIntentExtracting {
    static let instructions = """
        You read short descriptions of trips and pull out the destination, dates, number of travelers, \
        travel style, and a flight price only if the person wrote one. Use only what the person wrote. \
        Never estimate or invent prices, and leave out anything they didn't mention.
        """

    func extract(from text: String, today: Date, calendar: Calendar) async throws -> TripIntent {
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: "Today is \(Self.todayText(today, calendar: calendar)).\n\nTrip description: \(text)",
            generating: TripIntent.Generated.self,
            options: GenerationOptions(samplingMode: .greedy)
        )
        return TripIntent(response.content)
    }

    /// "Wednesday, November 25, 2026", so "next weekend" has an anchor.
    static func todayText(_ today: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: today)
    }
}
#endif
