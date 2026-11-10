import Foundation
import SwiftData
import Testing
@testable import Monetic

/// Shared fixtures for the unit tests. Every test builds its own in-memory
/// store and its own fixed dates, so nothing depends on today, the device
/// locale, or data left behind by a previous run.
enum TestSupport {
    /// A fresh, empty, in-memory store. Never touches the on-disk database.
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BudgetCategory.self, Transaction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// A fixed date in the current calendar — the same calendar the spending
    /// math uses. Noon keeps it well clear of midnight and DST changes.
    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        guard let date = Calendar.current.date(from: components) else {
            fatalError("Invalid test date \(year)-\(month)-\(day)")
        }
        return date
    }

    /// The decimal separator the amount field expects on this simulator.
    static var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }

    /// Writes an amount the way a user would type it on this device:
    /// `amountText("12.50")` is "12,50" on a German simulator.
    static func amountText(_ typed: String) -> String {
        typed.replacingOccurrences(of: ".", with: decimalSeparator)
    }

    /// Builds an expense through the same code path as the Add Expense
    /// screen's Save button, then inserts and saves it.
    @MainActor
    @discardableResult
    static func addExpense(
        _ typedAmount: String,
        to group: BudgetCategory,
        on date: Date,
        notes: String = "",
        isRecurring: Bool = false,
        recurringFrequency: String = "monthly",
        in context: ModelContext
    ) throws -> Transaction {
        let transaction = try #require(AddTransactionView.makeTransaction(
            amountText: amountText(typedAmount),
            date: date,
            notes: notes,
            category: group,
            isRecurring: isRecurring,
            recurringFrequency: recurringFrequency
        ))
        context.insert(transaction)
        try context.save()
        return transaction
    }

    /// A plain group for tests that only care about the spending math.
    @MainActor
    static func makeGroup(
        _ name: String = "Groceries",
        monthlyBudget: Double = 0,
        in context: ModelContext
    ) throws -> BudgetCategory {
        let group = BudgetCategory(name: name, monthlyBudget: monthlyBudget)
        context.insert(group)
        try context.save()
        return group
    }

    /// Adds a transaction directly (skipping the Add Expense validation) for
    /// spending-math tests.
    @MainActor
    @discardableResult
    static func addTransaction(
        _ amount: Double,
        to group: BudgetCategory,
        on date: Date,
        isRecurring: Bool = false,
        recurringFrequency: String = "",
        in context: ModelContext
    ) throws -> Transaction {
        let transaction = Transaction(
            amount: amount,
            date: date,
            category: group,
            isRecurring: isRecurring,
            recurringFrequency: recurringFrequency
        )
        context.insert(transaction)
        try context.save()
        return transaction
    }
}

/// One spending group to run the "add expense" tests against: either one of
/// the onboarding starters or a group the user made themselves.
struct GroupFixture: Sendable, CustomTestStringConvertible {
    let name: String
    let icon: String
    let isStarter: Bool

    var testDescription: String { name }

    /// Read from the app's own onboarding list, so a new starter group is
    /// picked up by these tests automatically.
    static let starters: [GroupFixture] = OnboardingView.defaultCategories.map {
        GroupFixture(name: $0.name, icon: $0.icon, isStarter: true)
    }

    static let custom = GroupFixture(name: "Savings", icon: "💰", isStarter: false)

    static let all: [GroupFixture] = starters + [custom]

    /// Creates the group the way the app does — through onboarding for a
    /// starter, or through the New Group screen for a custom one.
    @MainActor
    func insert(into context: ModelContext) throws -> BudgetCategory {
        if isStarter {
            OnboardingView.insertStarterGroups(named: [name], into: context)
        } else {
            let existing = try context.fetchCount(FetchDescriptor<BudgetCategory>())
            context.insert(AddCategoryView.makeCategory(name: name, icon: icon, existingCount: existing))
        }
        try context.save()

        let name = self.name
        let matches = try context.fetch(FetchDescriptor<BudgetCategory>(
            predicate: #Predicate { $0.name == name }
        ))
        return try #require(matches.first)
    }
}
