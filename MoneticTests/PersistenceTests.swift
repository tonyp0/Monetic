import Foundation
import SwiftData
import Testing
@testable import Monetic

/// Create, edit, delete, and reorder — the database operations behind the
/// group and expense screens.
@Suite("Saving, editing, and deleting")
@MainActor
struct PersistenceTests {
    // Swift Testing makes a new suite instance — and so a new, empty store —
    // for every test. The suite holds the container because a context alone
    // doesn't keep it alive.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try TestSupport.makeContainer()
    }

    private let march = TestSupport.date(2026, 3, 14)

    @Test("Deleting a group also deletes its expenses")
    func deletingGroupCascades() throws {
        let group = try TestSupport.makeGroup("Food", in: context)
        try TestSupport.addTransaction(10, to: group, on: march, in: context)
        try TestSupport.addTransaction(20, to: group, on: march, in: context)

        context.delete(group)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<BudgetCategory>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
    }

    @Test("Deleting a group leaves other groups' expenses alone")
    func deletingGroupKeepsOtherGroups() throws {
        let food = try TestSupport.makeGroup("Food", in: context)
        let travel = try TestSupport.makeGroup("Travel", in: context)
        try TestSupport.addTransaction(10, to: food, on: march, in: context)
        try TestSupport.addTransaction(20, to: travel, on: march, in: context)

        context.delete(food)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Transaction>())
        #expect(remaining.map(\.amount) == [20])
        #expect(travel.monthlySpending(asOf: march) == 20)
    }

    @Test("Deleting an expense removes it from its group and lowers the total")
    func deletingExpenseLowersTotal() throws {
        let group = try TestSupport.makeGroup(in: context)
        let keep = try TestSupport.addTransaction(40, to: group, on: march, in: context)
        let remove = try TestSupport.addTransaction(12.5, to: group, on: march, in: context)

        context.delete(remove)
        try context.save()

        #expect(group.transactions.map(\.id) == [keep.id])
        #expect(group.monthlySpending(asOf: march) == 40)
    }

    @Test("Changing an expense's amount updates its group's total")
    func editingAmountUpdatesTotal() throws {
        let group = try TestSupport.makeGroup(in: context)
        let expense = try TestSupport.addTransaction(40, to: group, on: march, in: context)

        expense.amount = 55.5
        try context.save()

        #expect(group.monthlySpending(asOf: march) == 55.5)
    }

    @Test("Moving an expense to another month moves it out of this month's total")
    func editingDateMovesTotal() throws {
        let group = try TestSupport.makeGroup(in: context)
        let expense = try TestSupport.addTransaction(40, to: group, on: march, in: context)
        let april = TestSupport.date(2026, 4, 2)

        // Same normalization EditTransactionView.save() applies.
        expense.date = Calendar.current.startOfDay(for: april)
        try context.save()

        #expect(group.monthlySpending(asOf: march) == 0)
        #expect(group.monthlySpending(asOf: april) == 40)
    }

    // MARK: Reordering

    @Test("Dragging the last group to the top renumbers every group")
    func reorderMovesLastToFirst() throws {
        let groups = try makeGroups(["A", "B", "C", "D"], in: context)

        ContentView.reorder(groups, from: IndexSet(integer: 3), to: 0)

        #expect(sortedNames(groups) == ["D", "A", "B", "C"])
        #expect(groups.map(\.sortOrder).sorted() == [0, 1, 2, 3])
    }

    @Test("Dragging the first group to the bottom renumbers every group")
    func reorderMovesFirstToLast() throws {
        let groups = try makeGroups(["A", "B", "C", "D"], in: context)

        ContentView.reorder(groups, from: IndexSet(integer: 0), to: 4)

        #expect(sortedNames(groups) == ["B", "C", "D", "A"])
        #expect(groups.map(\.sortOrder).sorted() == [0, 1, 2, 3])
    }

    @Test("Reordering closes gaps in the sort order")
    func reorderClosesGaps() throws {
        let groups = try makeGroups(["A", "B", "C"], in: context)
        groups[1].sortOrder = 5
        groups[2].sortOrder = 9

        ContentView.reorder(groups, from: IndexSet(integer: 2), to: 1)

        #expect(sortedNames(groups) == ["A", "C", "B"])
        #expect(groups.map(\.sortOrder).sorted() == [0, 1, 2])
    }

    @Test("Reordered positions are still there after reloading")
    func reorderPersists() throws {
        let groups = try makeGroups(["A", "B", "C"], in: context)

        ContentView.reorder(groups, from: IndexSet(integer: 2), to: 0)
        try context.save()

        let reloaded = try ModelContext(container).fetch(
            FetchDescriptor<BudgetCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        #expect(reloaded.map(\.name) == ["C", "A", "B"])
    }

    // MARK: Helpers

    private func makeGroups(_ names: [String], in context: ModelContext) throws -> [BudgetCategory] {
        let groups = names.enumerated().map { BudgetCategory(name: $1, sortOrder: $0) }
        groups.forEach(context.insert)
        try context.save()
        return groups
    }

    private func sortedNames(_ groups: [BudgetCategory]) -> [String] {
        groups.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
    }
}
