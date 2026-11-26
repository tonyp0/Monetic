import Foundation
import SwiftData
import Testing
@testable import Monetic

/// Proves that adding `Trip` to the schema is a safe, lightweight migration:
/// a store written by the app before Trips existed opens with the new schema
/// and keeps all of its budget data.
@Suite("Opening a store from before Trips")
@MainActor
struct StoreMigrationTests {
    /// The schema the app shipped before Trips.
    private let oldSchema = Schema([BudgetCategory.self, Transaction.self])

    private let march = TestSupport.date(2026, 3, 14)

    @Test("The app's schema includes trips alongside the budget models")
    func currentSchemaHasTrips() {
        let names = Set(MoneticApp.schema.entities.map(\.name))
        #expect(names == ["BudgetCategory", "Transaction", "Trip", "SavingsContribution"])
    }

    @Test("An on-disk store without trips opens with its data intact")
    func oldStoreOpensWithNewSchema() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")

        // 1. Write a store the way the app did before Trips.
        let groupID = UUID()
        do {
            let container = try ModelContainer(
                for: oldSchema,
                configurations: [ModelConfiguration(schema: oldSchema, url: storeURL)]
            )
            let context = ModelContext(container)
            // Groups are saved before any expense is added to them, as the
            // app does (onboarding and New Group both save straight away).
            // On iOS 18, an expense inserted in the same save as a brand-new
            // group can lose its link to it — unrelated to this migration.
            let group = BudgetCategory(id: groupID, name: "Food & Dining", color: "amber", icon: "🍔", monthlyBudget: 400, sortOrder: 0)
            context.insert(group)
            context.insert(BudgetCategory(name: "Transport", color: "mint", icon: "🚗", sortOrder: 1))
            try context.save()
            context.insert(Transaction(amount: 42.5, date: march, notes: "Groceries", category: group))
            context.insert(Transaction(amount: 15, date: march, category: group, isRecurring: true, recurringFrequency: "monthly"))
            try context.save()
            // Confirms the old store was written correctly, so anything
            // missing after reopening is down to the migration.
            try #require(group.transactions.count == 2)
        }
        #expect(FileManager.default.fileExists(atPath: storeURL.path))

        // 2. Reopen it with today's schema.
        do {
            let container = try ModelContainer(
                for: MoneticApp.schema,
                configurations: [ModelConfiguration(schema: MoneticApp.schema, url: storeURL)]
            )
            let context = ModelContext(container)

            let groups = try context.fetch(FetchDescriptor<BudgetCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
            #expect(groups.map(\.name) == ["Food & Dining", "Transport"])

            let food = try #require(groups.first)
            #expect(food.id == groupID)
            #expect(food.icon == "🍔")
            #expect(food.monthlyBudget == 400)
            #expect(food.transactions.count == 2)
            #expect(food.monthlySpending(asOf: march) == 57.5)

            let transactions = try context.fetch(FetchDescriptor<Transaction>())
            #expect(transactions.count == 2)
            #expect(transactions.allSatisfy { $0.category?.id == groupID })
            #expect(transactions.contains { $0.isRecurring && $0.recurringFrequency == "monthly" })

            #expect(try context.fetchCount(FetchDescriptor<Trip>()) == 0)

            // The migrated store accepts trips.
            context.insert(Trip(name: "Spring Break", destination: "Cancún, Mexico",
                                startDate: TestSupport.date(2027, 3, 20), endDate: TestSupport.date(2027, 3, 27),
                                estimatedTotal: 2400))
            try context.save()
        }

        // 3. And keeps both after another relaunch.
        let container = try ModelContainer(
            for: MoneticApp.schema,
            configurations: [ModelConfiguration(schema: MoneticApp.schema, url: storeURL)]
        )
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<BudgetCategory>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 2)
        #expect(try context.fetch(FetchDescriptor<Trip>()).map(\.name) == ["Spring Break"])
    }
    @Test("A store saved by the first Trips release opens with estimator and savings fields defaulted")
    func promptOneTripsMigrate() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")

        let promptOne = Schema([BudgetCategory.self, Transaction.self, PromptOneTrips.Trip.self])
        let tripID = UUID()
        do {
            let container = try ModelContainer(for: promptOne,
                                               configurations: [ModelConfiguration(schema: promptOne, url: storeURL)])
            let context = ModelContext(container)
            context.insert(BudgetCategory(name: "Travel", sortOrder: 0))
            context.insert(PromptOneTrips.Trip(
                id: tripID, name: "Spring Break", destination: "Cancún, Mexico",
                startDate: TestSupport.date(2027, 3, 20), endDate: TestSupport.date(2027, 3, 27),
                travelers: 4, estimatedTotal: 2400, estimateSource: "manual", notes: "Booked", createdAt: march
            ))
            try context.save()
        }

        let container = try ModelContainer(
            for: MoneticApp.schema,
            configurations: [ModelConfiguration(schema: MoneticApp.schema, url: storeURL)]
        )
        let context = ModelContext(container)
        let trip = try #require(try context.fetch(FetchDescriptor<Trip>()).first)
        #expect(trip.id == tripID)
        #expect(trip.name == "Spring Break")
        #expect(trip.destination == "Cancún, Mexico")
        #expect(trip.travelers == 4)
        #expect(trip.estimatedTotal == 2400)
        #expect(trip.estimateSource == "manual")
        #expect(trip.notes == "Booked")
        #expect(trip.perPersonTotal == 600)
        // New in prompt 2, filled from their defaults:
        #expect(trip.locationID == nil)
        #expect(trip.travelStyle == "standard")
        #expect(trip.roomsOverride == nil)
        #expect(trip.flightsTotal == nil)
        #expect(trip.savedEstimate == nil)
        #expect(try context.fetchCount(FetchDescriptor<BudgetCategory>()) == 1)

        // New in prompt 3: savings, also defaulted.
        #expect(trip.savingsGoal == 0)
        #expect(trip.effectiveSavingsGoal == 600, "one traveler's share")
        #expect(trip.savingsStartDate == nil)
        #expect(trip.savingsStart() == Calendar.current.startOfDay(for: march))
        #expect(trip.cadence == .weekly)
        #expect(!trip.remindersEnabled)
        #expect(trip.contributions.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<SavingsContribution>()) == 0)

        // New in prompt 4: sharing, defaulted to a solo trip.
        #expect(trip.shareID == nil)
        #expect(trip.sharedAt == nil)
        #expect(trip.joinedAt == nil)
        #expect(!trip.isGroupTrip)

        // New in prompt 5: nothing logged yet.
        #expect(trip.actualSpending == nil)
        #expect(trip.actuals == nil)
        #expect(trip.accuracySample == nil)

        // And the migrated trip takes an estimate and savings.
        trip.travelStyle = TravelStyle.budget.rawValue
        trip.flightsTotal = 800
        try context.save()
        context.insert(SavingsContribution(amount: 150, date: march, trip: trip, createdAt: march))
        try context.save()
        let reopened = try #require(try ModelContext(container).fetch(FetchDescriptor<Trip>()).first)
        #expect(reopened.flightsTotal == 800)
        #expect(reopened.totalSaved == 150)
    }
}

/// `Trip` exactly as the first Trips release (prompt 1) stored it. SwiftData
/// names the entity after the class, so this writes a store the new `Trip`
/// model then has to migrate.
enum PromptOneTrips {
    @Model
    final class Trip {
        @Attribute(.unique) var id: UUID
        var name: String
        var destination: String
        var startDate: Date
        var endDate: Date
        var travelers: Int
        var estimatedTotal: Double
        var estimateSource: String
        var notes: String
        var createdAt: Date

        init(id: UUID, name: String, destination: String, startDate: Date, endDate: Date,
             travelers: Int, estimatedTotal: Double, estimateSource: String, notes: String, createdAt: Date) {
            self.id = id
            self.name = name
            self.destination = destination
            self.startDate = startDate
            self.endDate = endDate
            self.travelers = travelers
            self.estimatedTotal = estimatedTotal
            self.estimateSource = estimateSource
            self.notes = notes
            self.createdAt = createdAt
        }
    }
}
