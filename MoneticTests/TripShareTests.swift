import Foundation
import SwiftData
import Testing
@testable import Monetic

/// Trip links: what goes in (the plan, never the money), what comes out, and
/// that every bad link is turned away with a message instead of a crash.
@Suite("Trip links")
@MainActor
struct TripShareTests {
    private let calendar = TripTests.calendar
    private let store: CostDataStore
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        store = try TestSupport.fixtureCostData()
        container = try TestSupport.makeContainer()
        context = ModelContext(container)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { TripTests.date(y, m, d) }

    /// Cancún, 4 travelers, Mar 14–21, standard style, with flights.
    private func estimatedTrip() throws -> Trip {
        var draft = TripDraft(name: "Spring Break", destination: "", startDate: date(2027, 3, 14),
                              endDate: date(2027, 3, 21), travelers: 4)
        let cancun = try #require(store.location(id: "TEST-CANCUN"))
        draft.select(cancun)
        draft.flightsText = "1600"
        let estimate = try #require(draft.estimate(location: cancun, calendar: calendar))
        draft.estimateChanged(from: nil, to: estimate)
        draft.notes = "SECRET hotel confirmation 8812"
        return try #require(draft.makeTrip(estimate: estimate, calendar: calendar))
    }

    private func manualPayload() -> TripSharePayload {
        TripSharePayload(
            version: 1, shareID: UUID(), name: "Ski Weekend", destination: "Breckenridge, CO",
            locationID: nil, startDay: "2027-01-15", endDay: "2027-01-18", travelers: 4,
            style: "standard", totalCents: 160_000, currencyCode: "USD", source: "manual",
            perPersonCents: 40_000, rooms: nil, flightsCents: nil, breakdown: nil
        )
    }

    private func decode(_ payload: TripSharePayload) throws -> TripShare {
        try TripShare.decode(TripShare.url(for: payload), store: store, calendar: calendar)
    }

    private func link(json: String) -> URL {
        URL(string: "monetic://trip?d=\(TripShare.base64URL(Data(json.utf8)))")!
    }

    // MARK: Round trip

    @Test("An estimated trip survives the round trip, breakdown and all")
    func roundTrip() throws {
        let trip = try estimatedTrip()
        let url = TripShare.url(for: trip, calendar: calendar)
        #expect(url.absoluteString.hasPrefix("monetic://trip?d="))

        let share = try TripShare.decode(url, store: store, calendar: calendar)
        #expect(share.shareID == trip.id, "an unshared trip uses its own ID")
        #expect(share.name == "Spring Break")
        #expect(share.destination == "Cancún, Mexico")
        #expect(share.locationID == "TEST-CANCUN")
        #expect(share.startDate == trip.startDate)
        #expect(share.endDate == trip.endDate)
        #expect(share.travelers == 4)
        #expect(share.style == .standard)
        #expect(share.source == .perDiem)
        #expect(share.currencyCode == "USD")
        #expect(share.total == trip.estimatedTotal)
        #expect(share.perPersonShare == Trip.defaultSavingsGoal(total: trip.estimatedTotal, travelers: 4))
        #expect(share.flightsTotal == 1600)
        #expect(share.estimate == trip.savedEstimate)
    }

    @Test("A typed-in total round-trips without an estimate")
    func manualRoundTrip() throws {
        let payload = manualPayload()
        let share = try decode(payload)
        #expect(share.source == .manual)
        #expect(share.estimate == nil)
        #expect(share.locationID == nil)
        #expect(share.total == 1600)
        #expect(share.perPersonShare == 400)
        #expect(TripShare.payload(for: TripShareImport.makeTrip(
            from: share, goal: 400, cadence: .weekly, now: date(2027, 1, 1), calendar: calendar
        ), calendar: calendar).shareID == payload.shareID, "a joined trip re-shares under the same ID")
    }

    @Test("Calendar days survive a trip to another time zone")
    func timeZones() throws {
        let url = TripShare.url(for: manualPayload())
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let share = try TripShare.decode(url, store: store, calendar: tokyo)
        let start = tokyo.dateComponents([.year, .month, .day], from: share.startDate)
        #expect((start.year, start.month, start.day) == (2027, 1, 15))
    }

    // MARK: Plan, never money

    @Test("A link carries the plan and nothing about anyone's money")
    func noMoney() throws {
        let trip = try estimatedTrip()
        trip.shareID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")
        context.insert(trip)
        try context.save()
        context.insert(SavingsContribution(amount: 987.65, date: date(2027, 1, 5), notes: "PRIVATE tip jar",
                                           trip: trip, createdAt: date(2027, 1, 5)))
        trip.savingsGoal = 4321
        trip.remindersEnabled = true
        try context.save()

        let url = TripShare.url(for: trip, calendar: calendar)
        let encoded = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value)
        let data = try #require(TripShare.dataFromBase64URL(encoded))
        let json = try #require(String(data: data, encoding: .utf8))
        for secret in ["SECRET", "8812", "PRIVATE", "98765", "987.65", "4321"] {
            #expect(!json.contains(secret), "\(secret) leaked into \(json)")
        }
        let keys = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]).keys
        #expect(Set(keys).isSubset(of: ["v", "id", "n", "d", "l", "s", "e", "t", "y", "a", "c", "o", "g", "r", "f", "b"]))
    }

    @Test("A realistic trip link fits comfortably in a message")
    func urlLength() throws {
        // Real data, a long name, flights, the full breakdown.
        let real = try #require(CostDataStore.shared)
        let cancun = try #require(real.location(id: "DOS-MEXICO-CANCUN"))
        var draft = TripDraft(name: "Spring Break 2027 with the whole floor", destination: "",
                              startDate: date(2027, 3, 14), endDate: date(2027, 3, 21), travelers: 6)
        draft.select(cancun)
        draft.travelStyle = .comfort
        draft.roomsOverride = 4
        draft.flightsText = "2489.37"
        let estimate = try #require(draft.estimate(location: cancun, calendar: calendar))
        draft.estimateChanged(from: nil, to: estimate)
        let trip = try #require(draft.makeTrip(estimate: estimate, calendar: calendar))

        let url = TripShare.url(for: trip, calendar: calendar)
        #expect(url.absoluteString.count < 1_000, "\(url.absoluteString.count) characters")
        let share = try TripShare.decode(url, store: real, calendar: calendar)
        #expect(share.rooms == 4)
        #expect(share.estimate == trip.savedEstimate)
    }

    @Test("The invite message names the trip, dates and each person's share")
    func inviteMessage() throws {
        let trip = Trip(name: "Spring Break", destination: "Cancún", startDate: date(2027, 3, 14),
                        endDate: date(2027, 3, 21), travelers: 4, estimatedTotal: 2560)
        let message = TripShare.inviteMessage(for: trip)
        #expect(message.hasPrefix("I'm planning Spring Break in Cancún, "))
        #expect(message.contains("About \(640.0.formatted(.currency(code: Currency.code).precision(.fractionLength(0)))) each."))
        #expect(message.hasSuffix("Join the plan in Monetic:"))
    }

    // MARK: Bad links

    @Test("Links that aren't trip links", arguments: [
        "https://example.com/trip?d=abc", "monetic://budget?d=abc", "mailto:someone@example.com",
    ])
    func notATripLink(link: String) {
        #expect(throws: TripShareError.notATripLink) {
            try TripShare.decode(URL(string: link)!, store: store)
        }
    }

    @Test("Damaged links: missing data, bad base64, not JSON, wrong shape", arguments: [
        "monetic://trip", "monetic://trip?x=1", "monetic://trip?d=", "monetic://trip?d=%21%21%21",
        "monetic://trip?d=a", "monetic://trip?d=bm90IGpzb24",          // "not json"
        "monetic://trip?d=WzEsMiwzXQ",                                 // [1,2,3]
        "monetic://trip?d=eyJ2IjoxfQ",                                 // {"v":1}
        "monetic://trip?d=eyJ2IjoiMSJ9",                               // {"v":"1"}
        "monetic://trip?d=eyJ2IjowfQ",                                 // {"v":0}
    ])
    func malformed(link: String) {
        #expect(throws: TripShareError.malformed) {
            try TripShare.decode(URL(string: link)!, store: store)
        }
    }

    @Test("A link from a newer version asks for an app update")
    func newerVersion() throws {
        var payload = manualPayload()
        payload.version = 2
        #expect(throws: TripShareError.newerVersion) { try decode(payload) }
        // Even when the rest is a shape this version can't read.
        #expect(throws: TripShareError.newerVersion) {
            try TripShare.decode(link(json: #"{"v":2,"everything":"different"}"#), store: store)
        }
        #expect(TripShareError.newerVersion.message.contains("Update"))
    }

    @Test("An oversized link is refused before it's decoded")
    func tooLong() {
        let url = URL(string: "monetic://trip?d=" + String(repeating: "A", count: TripShare.maxURLLength))!
        #expect(throws: TripShareError.tooLong) { try TripShare.decode(url, store: store) }
    }

    struct Mutation: CustomTestStringConvertible, @unchecked Sendable {
        let testDescription: String
        let field: String
        let apply: (inout TripSharePayload) -> Void
    }

    static let invalidPlans: [Mutation] = [
        .init(testDescription: "empty name", field: "name") { $0.name = "   " },
        .init(testDescription: "name too long", field: "name") { $0.name = String(repeating: "x", count: 81) },
        .init(testDescription: "control character", field: "name") { $0.name = "Spring\u{0}Break" },
        .init(testDescription: "no destination", field: "destination") { $0.destination = "" },
        .init(testDescription: "destination too long", field: "destination") { $0.destination = String(repeating: "y", count: 121) },
        .init(testDescription: "impossible start date", field: "start date") { $0.startDay = "2027-02-30" },
        .init(testDescription: "start date not yyyy-MM-dd", field: "start date") { $0.startDay = "27-1-15" },
        .init(testDescription: "start date out of range", field: "start date") { $0.startDay = "1999-12-31" },
        .init(testDescription: "garbage end date", field: "end date") { $0.endDay = "soon" },
        .init(testDescription: "ends before it starts", field: "dates") { $0.endDay = "2027-01-14" },
        .init(testDescription: "over a year long", field: "trip length") { $0.endDay = "2028-01-16" },
        .init(testDescription: "no travelers", field: "travelers") { $0.travelers = 0 },
        .init(testDescription: "21 travelers", field: "travelers") { $0.travelers = 21 },
        .init(testDescription: "unknown style", field: "travel style") { $0.style = "luxury" },
        .init(testDescription: "unknown source", field: "estimate source") { $0.source = "guess" },
        .init(testDescription: "lowercase currency", field: "currency") { $0.currencyCode = "usd" },
        .init(testDescription: "short currency", field: "currency") { $0.currencyCode = "US" },
        .init(testDescription: "zero total", field: "total") { $0.totalCents = 0 },
        .init(testDescription: "negative total", field: "total") { $0.totalCents = -500 },
        .init(testDescription: "absurd total", field: "total") { $0.totalCents = TripShare.maxCents + 1 },
        .init(testDescription: "share above the total", field: "per-person goal") { $0.perPersonCents = 160_001 },
        .init(testDescription: "negative share", field: "per-person goal") { $0.perPersonCents = -1 },
        .init(testDescription: "no rooms", field: "rooms") { $0.rooms = 0 },
        .init(testDescription: "more rooms than travelers", field: "rooms") { $0.rooms = 5 },
        .init(testDescription: "negative flights", field: "flights") { $0.flightsCents = -100 },
        .init(testDescription: "unknown location", field: "location") { $0.locationID = "NOWHERE" },
        .init(testDescription: "empty location", field: "location") { $0.locationID = "" },
        .init(testDescription: "per diem without a breakdown", field: "estimate") { $0.source = "perDiem" },
        .init(testDescription: "breakdown without a location", field: "estimate") {
            $0.breakdown = .init(cents: [1, 2, 3, 4], sourceID: "dos", effective: "2024-08-01")
        },
    ]

    @Test("Every field is checked", arguments: invalidPlans)
    func invalidPlan(_ mutation: Mutation) {
        var payload = manualPayload()
        mutation.apply(&payload)
        #expect(throws: TripShareError.invalid(field: mutation.field)) { try decode(payload) }
    }

    static let invalidEstimates: [Mutation] = [
        .init(testDescription: "too few line items", field: "estimate") { $0.breakdown?.cents = [1, 2, 3] },
        .init(testDescription: "too many line items", field: "estimate") { $0.breakdown?.cents = [1, 2, 3, 4, 5, 6] },
        .init(testDescription: "negative line item", field: "estimate") { $0.breakdown?.cents[0] = -1 },
        .init(testDescription: "unknown rate source", field: "estimate") { $0.breakdown?.sourceID = "made-up" },
        .init(testDescription: "bad effective date", field: "estimate") { $0.breakdown?.effective = "yesterday" },
        .init(testDescription: "flights don't match", field: "flights") { $0.flightsCents = 1 },
        .init(testDescription: "total doesn't match the breakdown", field: "total") { $0.totalCents += 1 },
    ]

    @Test("Estimate breakdowns are checked against the plan", arguments: invalidEstimates)
    func invalidEstimate(_ mutation: Mutation) throws {
        var payload = TripShare.payload(for: try estimatedTrip(), calendar: calendar)
        _ = try decode(payload)   // valid before the change
        mutation.apply(&payload)
        #expect(throws: TripShareError.invalid(field: mutation.field)) { try decode(payload) }
    }

    @Test("Without the rate data, a location can't be trusted")
    func noStore() throws {
        let payload = TripShare.payload(for: try estimatedTrip(), calendar: calendar)
        #expect(throws: TripShareError.invalid(field: "location")) {
            try TripShare.decode(TripShare.url(for: payload), store: nil, calendar: calendar)
        }
    }

    @Test("Every error has a message to show")
    func messages() {
        let errors: [TripShareError] = [.notATripLink, .tooLong, .malformed, .newerVersion, .invalid(field: "dates")]
        for error in errors {
            #expect(!error.title.isEmpty)
            #expect(!error.message.isEmpty)
        }
        #expect(TripShareError.invalid(field: "dates").message.contains("dates"))
    }

    // MARK: Importing

    @Test("Joining creates a trip with no savings, your cadence and the shared plan")
    func join() throws {
        let mine = Trip(name: "Mine", destination: "Home", startDate: date(2027, 5, 1), endDate: date(2027, 5, 2),
                        estimatedTotal: 100, createdAt: date(2026, 12, 1))
        mine.contributionCadence = ContributionCadence.monthly.rawValue
        context.insert(mine)
        try context.save()

        let share = try decode(manualPayload())
        let trips = try context.fetch(FetchDescriptor<Trip>())
        #expect(TripShareImport.existingTrip(for: share, in: trips) == nil)
        let joined = TripShareImport.makeTrip(from: share, goal: 450, cadence: TripShareImport.preferredCadence(from: trips),
                                              now: date(2027, 1, 2), calendar: calendar)
        context.insert(joined)
        try context.save()

        #expect(joined.shareID == share.shareID)
        #expect(joined.isGroupTrip)
        #expect(joined.joinedAt != nil)
        #expect(joined.totalSaved == 0)
        #expect(joined.contributions.isEmpty)
        #expect(joined.savingsGoal == 450, "the user's own share")
        #expect(joined.cadence == .monthly, "the cadence they already use")
        #expect(joined.travelers == 4)
        #expect(joined.estimatedTotal == 1600)
        #expect(joined.notes.isEmpty)
        #expect(!joined.remindersEnabled)
    }

    @Test("Opening the same link again updates the plan in place and leaves savings alone")
    func updateInPlace() throws {
        let original = manualPayload()
        let first = try decode(original)
        let trip = TripShareImport.makeTrip(from: first, goal: 400, cadence: .biweekly, now: date(2027, 1, 2),
                                            calendar: calendar)
        context.insert(trip)
        try context.save()
        // Added the way Add to Savings does, while the trip has unsaved
        // edits too: that combination lost the links on iOS 18.
        let deposit = ContributionDraft(amountText: "120", date: date(2027, 1, 3), notes: "Mine")
        deposit.insertContribution(for: trip, in: context, createdAt: date(2027, 1, 3), calendar: calendar)
        let withdrawal = ContributionDraft(amountText: "20", isWithdrawal: true, date: date(2027, 1, 4))
        withdrawal.insertContribution(for: trip, in: context, createdAt: date(2027, 1, 4), calendar: calendar)
        trip.notes = "My notes"
        trip.remindersEnabled = true
        try context.save()
        let start = trip.savingsStart()

        // The organizer moves the dates, adds a traveler and re-shares.
        var changed = original
        changed.name = "Ski Weekend (final)"
        changed.startDay = "2027-01-22"
        changed.endDay = "2027-01-25"
        changed.travelers = 5
        changed.totalCents = 175_000
        changed.perPersonCents = 35_000
        let update = try decode(changed)

        let trips = try context.fetch(FetchDescriptor<Trip>())
        let existing = try #require(TripShareImport.existingTrip(for: update, in: trips))
        #expect(existing.id == trip.id)
        TripShareImport.update(existing, from: update, goal: 350, calendar: calendar)
        try context.save()

        let fresh = ModelContext(container)
        let all = try fresh.fetch(FetchDescriptor<Trip>())
        #expect(all.count == 1, "no duplicate")
        let saved = try #require(all.first)
        #expect(saved.name == "Ski Weekend (final)")
        #expect(saved.travelers == 5)
        #expect(saved.estimatedTotal == 1750)
        #expect(saved.savingsGoal == 350)
        #expect(saved.startDate == TripShare.date(fromDay: "2027-01-22", calendar: calendar))
        // Untouched:
        #expect(saved.totalSaved == 100)
        #expect(saved.contributions.count == 2)
        #expect(Set(saved.contributions.map(\.notes)) == ["Mine", ""])
        #expect(saved.cadence == .biweekly)
        #expect(saved.savingsStart() == start)
        #expect(saved.notes == "My notes")
        #expect(saved.remindersEnabled)
        #expect(try fresh.fetchCount(FetchDescriptor<SavingsContribution>()) == 2)
    }

    @Test("Your own shared trip is recognised when you open its link")
    func organizerOpensOwnLink() throws {
        let trip = try estimatedTrip()
        trip.shareID = trip.id
        context.insert(trip)
        try context.save()
        let share = try TripShare.decode(TripShare.url(for: trip, calendar: calendar), store: store, calendar: calendar)
        #expect(TripShareImport.existingTrip(for: share, in: try context.fetch(FetchDescriptor<Trip>()))?.id == trip.id)
    }
}
