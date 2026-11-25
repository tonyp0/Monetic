import Foundation
import Testing
@testable import Monetic

/// Records what would be scheduled instead of touching the notification center.
final class FakeReminderScheduler: ReminderScheduling {
    var pending: [String: SavingsReminder] = [:]
    var foreign: Set<String> = []
    var authorizationRequests = 0
    var grantAuthorization = true
    var removed: [String] = []

    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        return grantAuthorization
    }

    func pendingIdentifiers() async -> [String] { Array(pending.keys) + Array(foreign) }

    func add(_ reminders: [SavingsReminder]) async {
        for reminder in reminders { pending[reminder.identifier] = reminder }
    }

    func remove(identifiers: [String]) async {
        removed += identifiers
        for id in identifiers { pending[id] = nil; foreign.remove(id) }
    }

    var scheduledDays: [String] {
        pending.values
            .sorted { $0.identifier < $1.identifier }
            .map { "\($0.fireDate.month!)/\($0.fireDate.day!) \($0.fireDate.hour!):00" }
    }
}

@Suite("Savings reminders")
@MainActor
struct SavingsReminderTests {
    private let calendar = TripTests.calendar
    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date { TripTests.date(y, m, d, hour: hour) }

    /// $1,200 saved weekly from Mon Jan 4 to Mon Mar 29, 2027.
    private func trip(
        _ name: String = "Spring Break",
        id: UUID = UUID(),
        enabled: Bool = true,
        saved: Double = 0,
        start: Date? = nil,
        departure: Date? = nil,
        cadence: ContributionCadence = .weekly
    ) -> SavingsReminders.TripInfo {
        SavingsReminders.TripInfo(
            id: id, name: name, remindersEnabled: enabled, goal: 1200, saved: saved,
            savingsStart: start ?? date(2027, 1, 4), departure: departure ?? date(2027, 3, 29),
            cadence: cadence, currencyCode: "USD"
        )
    }

    private func labels(_ reminders: [SavingsReminder]) -> [String] {
        reminders.map { "\($0.fireDate.month!)/\($0.fireDate.day!) \($0.fireDate.hour!):00" }
    }

    // MARK: Planning

    @Test("The next few savings days, at 9 a.m., with the amount to put aside")
    func nextFew() throws {
        let reminders = SavingsReminders.plan([trip()], asOf: date(2027, 1, 4, hour: 8), calendar: calendar)
        #expect(labels(reminders) == ["1/4 9:00", "1/11 9:00", "1/18 9:00", "1/25 9:00"])
        let first = try #require(reminders.first)
        #expect(first.title == "Spring Break")
        #expect(first.body == "Spring Break: time to put \(100.0.formatted(.currency(code: "USD"))) aside.")
        #expect(first.identifier.hasPrefix(SavingsReminder.identifierPrefix))
        #expect(Set(reminders.map(\.identifier)).count == reminders.count)
    }

    @Test("A savings day whose 9 a.m. has passed is skipped")
    func pastNineSkipped() {
        let reminders = SavingsReminders.plan([trip()], asOf: date(2027, 1, 4, hour: 10), calendar: calendar)
        #expect(labels(reminders) == ["1/11 9:00", "1/18 9:00", "1/25 9:00", "2/1 9:00"])
    }

    @Test("Nothing for trips with reminders off, fully funded, or already started")
    func nothingToRemind() {
        let now = date(2027, 2, 1, hour: 8)
        #expect(SavingsReminders.plan([trip(enabled: false)], asOf: now, calendar: calendar).isEmpty)
        #expect(SavingsReminders.plan([trip(saved: 1200)], asOf: now, calendar: calendar).isEmpty)
        #expect(SavingsReminders.plan([trip()], asOf: date(2027, 3, 29), calendar: calendar).isEmpty)
    }

    @Test("Never a reminder on or after departure day")
    func stopsBeforeDeparture() {
        let reminders = SavingsReminders.plan([trip()], asOf: date(2027, 3, 10), calendar: calendar)
        #expect(labels(reminders) == ["3/15 9:00", "3/22 9:00"])
    }

    @Test("Many trips stay under iOS's 64 pending notifications, soonest first")
    func cap() {
        let trips = (0..<20).map { trip("Trip \($0)", start: date(2027, 1, 4 + ($0 % 7))) }
        let reminders = SavingsReminders.plan(trips, asOf: date(2027, 1, 1), calendar: calendar)
        #expect(reminders.count == SavingsReminders.totalLimit)
        #expect(SavingsReminders.totalLimit < 64)
        let fireDates = reminders.compactMap { calendar.date(from: $0.fireDate) }
        #expect(fireDates == fireDates.sorted())
        for trip in trips {
            #expect(reminders.filter { $0.tripID == trip.id }.count <= SavingsReminders.perTripLimit)
        }
    }

    // MARK: Syncing

    @Test("Syncing schedules the plan and leaves other notifications alone")
    func sync() async {
        let fake = FakeReminderScheduler()
        fake.foreign = ["someone-else"]
        let coordinator = SavingsReminderCoordinator(scheduler: fake)

        await coordinator.sync([trip()], asOf: date(2027, 1, 4, hour: 8), calendar: calendar)
        #expect(fake.scheduledDays == ["1/4 9:00", "1/11 9:00", "1/18 9:00", "1/25 9:00"])
        #expect(fake.foreign == ["someone-else"])
        #expect(fake.authorizationRequests == 0, "syncing never asks for permission")
    }

    @Test("Changing the cadence reschedules")
    func reschedule() async {
        let fake = FakeReminderScheduler()
        let coordinator = SavingsReminderCoordinator(scheduler: fake)
        let id = UUID()
        await coordinator.sync([trip(id: id)], asOf: date(2027, 1, 4, hour: 8), calendar: calendar)
        await coordinator.sync([trip(id: id, cadence: .monthly)], asOf: date(2027, 1, 4, hour: 8), calendar: calendar)
        #expect(fake.scheduledDays == ["1/4 9:00", "2/4 9:00", "3/4 9:00"])
        #expect(fake.pending.values.allSatisfy { $0.body.contains(400.0.formatted(.currency(code: "USD"))) })
    }

    @Test("Deleting a trip or funding it clears its reminders")
    func cleared() async {
        let fake = FakeReminderScheduler()
        let coordinator = SavingsReminderCoordinator(scheduler: fake)
        let keep = trip("Keep"), gone = trip("Gone"), funded = trip("Funded")
        let now = date(2027, 1, 4, hour: 8)
        await coordinator.sync([keep, gone, funded], asOf: now, calendar: calendar)
        #expect(Set(fake.pending.values.map(\.tripID)) == [keep.id, gone.id, funded.id])

        // "Gone" was deleted, "Funded" reached its goal.
        let nowFunded = trip("Funded", id: funded.id, saved: 1200)
        await coordinator.sync([keep, nowFunded], asOf: now, calendar: calendar)
        #expect(Set(fake.pending.values.map(\.tripID)) == [keep.id])

        await coordinator.sync([], asOf: now, calendar: calendar)
        #expect(fake.pending.isEmpty)
    }

    @Test("Permission is asked for only when the user turns reminders on")
    func permission() async {
        let fake = FakeReminderScheduler()
        fake.grantAuthorization = false
        let coordinator = SavingsReminderCoordinator(scheduler: fake)
        await coordinator.sync([trip(), trip(enabled: false)], asOf: date(2027, 1, 4), calendar: calendar)
        #expect(fake.authorizationRequests == 0)
        #expect(await coordinator.requestPermission() == false)
        #expect(fake.authorizationRequests == 1)
    }
}
