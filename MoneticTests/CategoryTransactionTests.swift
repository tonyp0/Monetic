import Foundation
import SwiftData
import Testing
@testable import Monetic

/// Proves that adding an expense works for every spending group — all nine
/// onboarding starters plus a group the user created themselves.
@Suite("Adding expenses to each group")
@MainActor
struct CategoryTransactionTests {
    // Swift Testing makes a new suite instance — and so a new, empty store —
    // for every test. The suite holds the container because a context alone
    // doesn't keep it alive.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try TestSupport.makeContainer()
    }

    private let march = TestSupport.date(2026, 3, 14)

    @Test("Onboarding offers nine starter groups and the tests cover all of them plus a custom group")
    func coversEveryGroup() {
        #expect(GroupFixture.starters.count == 9)
        #expect(Set(GroupFixture.all.map(\.name)).count == 10)
    }

    // MARK: Saving

    @Test("Saving an expense adds it to the group's expenses", arguments: GroupFixture.all)
    func expenseAppearsInGroup(_ fixture: GroupFixture) throws {
        let group = try fixture.insert(into: context)

        let expense = try TestSupport.addExpense("12.50", to: group, on: march, in: context)

        #expect(group.transactions.map(\.id) == [expense.id])
        #expect(expense.category?.id == group.id)
    }

    @Test("A saved expense reloads with the same amount, note, date, and group", arguments: GroupFixture.all)
    func expenseSurvivesFreshContext(_ fixture: GroupFixture) throws {
        let group = try fixture.insert(into: context)
        let expense = try TestSupport.addExpense(
            "12.50", to: group, on: TestSupport.date(2026, 3, 14, hour: 18, minute: 45),
            notes: "Lunch with Sam", in: context
        )

        let freshContext = ModelContext(container)
        let id = expense.id
        let reloaded = try #require(try freshContext.fetch(FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id }
        )).first)

        #expect(reloaded.amount == 12.50)
        #expect(reloaded.notes == "Lunch with Sam")
        #expect(reloaded.date == Calendar.current.startOfDay(for: march))
        #expect(reloaded.category?.id == group.id)
        #expect(reloaded.category?.name == fixture.name)
    }

    // MARK: Totals

    @Test("Monthly spending equals the expense amount", arguments: GroupFixture.all)
    func monthlySpendingMatchesExpense(_ fixture: GroupFixture) throws {
        let group = try fixture.insert(into: context)

        try TestSupport.addExpense("12.50", to: group, on: march, in: context)

        #expect(group.monthlySpending(asOf: march) == 12.50)
    }

    @Test("Several expenses in one group add up", arguments: GroupFixture.all)
    func multipleExpensesSum(_ fixture: GroupFixture) throws {
        let group = try fixture.insert(into: context)

        try TestSupport.addExpense("12.50", to: group, on: TestSupport.date(2026, 3, 1), in: context)
        try TestSupport.addExpense("7.25", to: group, on: TestSupport.date(2026, 3, 14), in: context)
        try TestSupport.addExpense("0.25", to: group, on: TestSupport.date(2026, 3, 31), in: context)

        #expect(group.transactions.count == 3)
        #expect(group.monthlySpending(asOf: march) == 20.00)
    }

    @Test("Expenses in one group never count toward another group", arguments: GroupFixture.all)
    func expensesDontLeakBetweenGroups(_ fixture: GroupFixture) throws {
        let group = try fixture.insert(into: context)
        let otherFixture = fixture.name == "Travel" ? GroupFixture.starters[0] : GroupFixture.starters[7]
        let other = try otherFixture.insert(into: context)

        try TestSupport.addExpense("12.50", to: group, on: march, in: context)
        try TestSupport.addExpense("40.00", to: other, on: march, in: context)

        #expect(group.monthlySpending(asOf: march) == 12.50)
        #expect(other.monthlySpending(asOf: march) == 40.00)
        #expect(group.transactions.count == 1)
        #expect(other.transactions.count == 1)
    }

    // MARK: Recurring

    @Test("Monthly and yearly recurring expenses are stored with their frequency", arguments: GroupFixture.all)
    func recurringExpensesKeepFrequency(_ fixture: GroupFixture) throws {
        let group = try fixture.insert(into: context)

        let monthly = try TestSupport.addExpense(
            "9.75", to: group, on: march, isRecurring: true, recurringFrequency: "monthly",
            in: context
        )
        let yearly = try TestSupport.addExpense(
            "120.00", to: group, on: march, isRecurring: true, recurringFrequency: "yearly",
            in: context
        )

        let freshContext = ModelContext(container)
        let byID = Dictionary(uniqueKeysWithValues: try freshContext.fetch(FetchDescriptor<Transaction>()).map { ($0.id, $0) })
        let reloadedMonthly = try #require(byID[monthly.id])
        let reloadedYearly = try #require(byID[yearly.id])

        #expect(reloadedMonthly.isRecurring)
        #expect(reloadedMonthly.recurringFrequency == "monthly")
        #expect(reloadedYearly.isRecurring)
        #expect(reloadedYearly.recurringFrequency == "yearly")
        #expect(group.monthlySpending(asOf: march) == 129.75)
    }

    // MARK: Validation (mirrors the Add Expense screen's Save button)

    @Test("Zero, negative, empty, and non-numeric amounts can't be saved", arguments: [
        "0", TestSupport.amountText("0.00"), "-5", "", "abc", TestSupport.decimalSeparator,
    ])
    func invalidAmountsAreRejected(_ amountText: String) throws {
        let group = try TestSupport.makeGroup(in: context)

        let transaction = AddTransactionView.makeTransaction(
            amountText: amountText, date: march, notes: "",
            category: group, isRecurring: false, recurringFrequency: "monthly"
        )

        #expect(transaction == nil)
    }

    @Test("An expense with no group can't be saved")
    func missingGroupIsRejected() {
        let transaction = AddTransactionView.makeTransaction(
            amountText: TestSupport.amountText("12.50"), date: march, notes: "",
            category: nil, isRecurring: false, recurringFrequency: "monthly"
        )

        #expect(transaction == nil)
    }

    @Test("A one-time expense is saved without a repeat frequency")
    func oneTimeExpenseClearsFrequency() throws {
        let group = try TestSupport.makeGroup(in: context)

        // The Add Expense screen's segmented control always holds "monthly",
        // even when the Recurring toggle is off.
        let expense = try TestSupport.addExpense(
            "12.50", to: group, on: march, isRecurring: false, recurringFrequency: "monthly", in: context
        )

        #expect(expense.isRecurring == false)
        #expect(expense.recurringFrequency == "")
    }

    // MARK: Creating groups

    @Test("A new group has a trimmed name, isn't a default, and goes to the end of the list")
    func newGroupFromAddGroupScreen() {
        let group = AddCategoryView.makeCategory(name: "  Savings  ", icon: "💰", existingCount: 4)

        #expect(group.name == "Savings")
        #expect(group.icon == "💰")
        #expect(group.isDefault == false)
        #expect(group.sortOrder == 4)
        #expect(group.color == CategoryPalette.key(forIndex: 4))
    }

    @Test("Onboarding adds every selected starter as a default group in listed order")
    func onboardingInsertsAllStarters() throws {
        OnboardingView.insertStarterGroups(named: Set(GroupFixture.starters.map(\.name)), into: context)
        try context.save()

        let groups = try context.fetch(FetchDescriptor<BudgetCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(groups.map(\.name) == GroupFixture.starters.map(\.name))
        #expect(groups.map(\.sortOrder) == Array(0..<9))
        #expect(groups.map(\.isDefault) == Array(repeating: true, count: 9))
    }

    @Test("Onboarding numbers a partial selection from zero in listed order")
    func onboardingInsertsSelectionSequentially() throws {
        // Picked in a different order than they're listed.
        OnboardingView.insertStarterGroups(named: ["Work", "Food & Dining", "Travel"], into: context)
        try context.save()

        let groups = try context.fetch(FetchDescriptor<BudgetCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(groups.map(\.name) == ["Food & Dining", "Travel", "Work"])
        #expect(groups.map(\.sortOrder) == [0, 1, 2])
    }
}
