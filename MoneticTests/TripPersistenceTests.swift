import Foundation
import SwiftData
import Testing
@testable import Monetic

/// Saving, editing and deleting trips, and keeping trips and the budget apart.
@Suite("Saving, editing, and deleting trips")
@MainActor
struct TripPersistenceTests {
    // A new suite instance — and so a new, empty store — per test.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try TestSupport.makeContainer()
    }

    private let march = TestSupport.date(2027, 3, 14)

    private func makeDraft(name: String = "Spring Break", total: String = "2400") -> TripDraft {
        TripDraft(
            name: name,
            destination: "Cancún, Mexico",
            startDate: TestSupport.date(2027, 3, 20),
            endDate: TestSupport.date(2027, 3, 27),
            travelers: 2,
            amountText: TestSupport.amountText(total),
            notes: "All-inclusive"
        )
    }

    /// Inserts a trip through the same path as the Add Trip screen's Save.
    @discardableResult
    private func addTrip(name: String = "Spring Break", total: String = "2400") throws -> Trip {
        let trip = try #require(makeDraft(name: name, total: total).makeTrip())
        context.insert(trip)
        try context.save()
        return trip
    }

    /// Reads trips back through a separate context, so nothing comes from
    /// the inserting context's in-memory objects.
    private func fetchTripsFresh() throws -> [Trip] {
        try ModelContext(container).fetch(FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.startDate)]))
    }

    @Test("A saved trip reads back with every field intact")
    func insertAndFetch() throws {
        let saved = try addTrip()

        let fetched = try fetchTripsFresh()
        #expect(fetched.count == 1)
        let trip = try #require(fetched.first)
        #expect(trip.id == saved.id)
        #expect(trip.name == "Spring Break")
        #expect(trip.destination == "Cancún, Mexico")
        #expect(trip.startDate == Calendar.current.startOfDay(for: TestSupport.date(2027, 3, 20)))
        #expect(trip.endDate == Calendar.current.startOfDay(for: TestSupport.date(2027, 3, 27)))
        #expect(trip.travelers == 2)
        #expect(trip.estimatedTotal == 2400)
        #expect(trip.estimateSource == "manual")
        #expect(trip.notes == "All-inclusive")
        #expect(trip.perPersonTotal == 1200)
    }

    @Test("Edits made through the Edit Trip rules are saved")
    func editPersists() throws {
        let trip = try addTrip()

        var draft = TripDraft(trip: trip)
        draft.name = "Spring Break 2027"
        draft.travelers = 4
        draft.amountText = TestSupport.amountText("3200.80")
        #expect(draft.apply(to: trip))
        try context.save()

        let fetched = try #require(try fetchTripsFresh().first)
        #expect(fetched.name == "Spring Break 2027")
        #expect(fetched.travelers == 4)
        #expect(fetched.estimatedTotal == 3200.80)
        #expect(fetched.perPersonTotal == 800.20)
    }

    @Test("Deleting a trip removes only that trip")
    func deleteRemovesOnlyThatTrip() throws {
        let spring = try addTrip(name: "Spring Break")
        try addTrip(name: "Summer")

        context.delete(spring)
        try context.save()

        #expect(try fetchTripsFresh().map(\.name) == ["Summer"])
    }

    @Test("Trips don't show up in, or change, the budget")
    func tripsDontAffectBudget() throws {
        let group = try TestSupport.makeGroup("Travel", monthlyBudget: 500, in: context)
        try TestSupport.addTransaction(120, to: group, on: march, in: context)
        let spentBefore = group.monthlySpending(asOf: march)

        try addTrip(name: "Spring Break", total: "2400")
        try addTrip(name: "Summer", total: "5000")

        #expect(try context.fetchCount(FetchDescriptor<BudgetCategory>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 1)
        #expect(group.monthlySpending(asOf: march) == spentBefore)
        #expect(group.monthlySpending(asOf: march) == 120)
    }

    @Test("Budget groups and expenses don't show up in, or change, trips")
    func budgetDoesntAffectTrips() throws {
        try addTrip(name: "Spring Break", total: "2400")

        let group = try TestSupport.makeGroup("Travel", in: context)
        try TestSupport.addTransaction(999, to: group, on: march, in: context)

        let trips = try fetchTripsFresh()
        #expect(trips.count == 1)
        #expect(trips.first?.estimatedTotal == 2400)
    }

    @Test("Deleting groups leaves trips alone, and deleting trips leaves groups alone")
    func deletesDontCrossOver() throws {
        let group = try TestSupport.makeGroup("Travel", in: context)
        try TestSupport.addTransaction(50, to: group, on: march, in: context)
        let trip = try addTrip()

        context.delete(group)
        try context.save()
        #expect(try fetchTripsFresh().count == 1)

        let keep = try TestSupport.makeGroup("Food", in: context)
        try TestSupport.addTransaction(30, to: keep, on: march, in: context)
        context.delete(trip)
        try context.save()

        #expect(try fetchTripsFresh().isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<BudgetCategory>()) == 1)
        #expect(keep.monthlySpending(asOf: march) == 30)
    }
}
