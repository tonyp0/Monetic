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
        #expect(names == ["BudgetCategory", "Transaction", "Trip"])
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
}
