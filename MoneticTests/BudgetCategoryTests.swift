import Foundation
import SwiftData
import Testing
@testable import Monetic

/// The spending math behind every total in the app: which expenses count
/// toward a given month, and how that compares to the group's budget.
@Suite("Group spending math")
@MainActor
struct BudgetCategoryTests {
    // Swift Testing makes a new suite instance — and so a new, empty store —
    // for every test. The suite holds the container because a context alone
    // doesn't keep it alive.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try TestSupport.makeContainer()
    }

    private typealias Month = (year: Int, month: Int)

    private static func midMonth(_ month: Month) -> Date {
        TestSupport.date(month.year, month.month, 15)
    }

    // MARK: One-time expenses

    @Test("A one-time expense counts in its own month")
    func oneTimeCountsInOwnMonth() throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(40, to: group, on: TestSupport.date(2025, 3, 10), in: context)

        #expect(group.monthlySpending(asOf: TestSupport.date(2025, 3, 20)) == 40)
    }

    @Test("A one-time expense doesn't count in any other month", arguments: [
        (year: 2025, month: 2),  // month before
        (year: 2025, month: 4),  // month after
        (year: 2024, month: 3),  // same month, last year
        (year: 2026, month: 3),  // same month, next year
    ])
    func oneTimeIgnoredInOtherMonths(_ month: (year: Int, month: Int)) throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(40, to: group, on: TestSupport.date(2025, 3, 10), in: context)

        #expect(group.monthlySpending(asOf: Self.midMonth(month)) == 0)
    }

    // MARK: Monthly recurring

    @Test("A monthly expense counts in its start month and every month after", arguments: [
        (year: 2025, month: 3),
        (year: 2025, month: 4),
        (year: 2025, month: 12),
        (year: 2026, month: 1),
        (year: 2028, month: 7),
    ])
    func monthlyCountsFromStartOnward(_ month: (year: Int, month: Int)) throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(
            15, to: group, on: TestSupport.date(2025, 3, 10),
            isRecurring: true, recurringFrequency: "monthly", in: context
        )

        #expect(group.monthlySpending(asOf: Self.midMonth(month)) == 15)
    }

    @Test("A monthly expense doesn't count before it started", arguments: [
        (year: 2025, month: 2),
        (year: 2024, month: 12),
        (year: 2024, month: 3),
    ])
    func monthlyIgnoredBeforeStart(_ month: (year: Int, month: Int)) throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(
            15, to: group, on: TestSupport.date(2025, 3, 10),
            isRecurring: true, recurringFrequency: "monthly", in: context
        )

        #expect(group.monthlySpending(asOf: Self.midMonth(month)) == 0)
    }

    // MARK: Yearly recurring

    @Test("A yearly expense counts in the same month of its start year and later years", arguments: [
        (year: 2025, month: 3),
        (year: 2026, month: 3),
        (year: 2030, month: 3),
    ])
    func yearlyCountsInSameMonth(_ month: (year: Int, month: Int)) throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(
            99, to: group, on: TestSupport.date(2025, 3, 10),
            isRecurring: true, recurringFrequency: "yearly", in: context
        )

        #expect(group.monthlySpending(asOf: Self.midMonth(month)) == 99)
    }

    @Test("A yearly expense doesn't count in other months or before it started", arguments: [
        (year: 2025, month: 4),  // later month, start year
        (year: 2026, month: 2),  // other month, later year
        (year: 2024, month: 3),  // same month, earlier year
    ])
    func yearlyIgnoredElsewhere(_ month: (year: Int, month: Int)) throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(
            99, to: group, on: TestSupport.date(2025, 3, 10),
            isRecurring: true, recurringFrequency: "yearly", in: context
        )

        #expect(group.monthlySpending(asOf: Self.midMonth(month)) == 0)
    }

    // MARK: Unknown frequency

    @Test("A recurring expense with an unknown or empty frequency counts only in its own month", arguments: ["", "weekly"])
    func unknownFrequencyActsOneTime(_ frequency: String) throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(
            25, to: group, on: TestSupport.date(2025, 3, 10),
            isRecurring: true, recurringFrequency: frequency, in: context
        )

        #expect(group.monthlySpending(asOf: TestSupport.date(2025, 3, 20)) == 25)
        #expect(group.monthlySpending(asOf: TestSupport.date(2025, 4, 20)) == 0)
    }

    // MARK: Month boundaries

    @Test("An expense on the last day of a month counts in that month, not the next")
    func lastDayOfMonth() throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(30, to: group, on: TestSupport.date(2025, 1, 31, hour: 23, minute: 59), in: context)

        #expect(group.monthlySpending(asOf: TestSupport.date(2025, 1, 31, hour: 23, minute: 59)) == 30)
        #expect(group.monthlySpending(asOf: TestSupport.date(2025, 2, 1, hour: 0)) == 0)
    }

    @Test("An expense on the first day of a month counts in that month, not the one before")
    func firstDayOfMonth() throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(30, to: group, on: TestSupport.date(2025, 2, 1, hour: 0), in: context)

        #expect(group.monthlySpending(asOf: TestSupport.date(2025, 2, 1, hour: 0)) == 30)
        #expect(group.monthlySpending(asOf: TestSupport.date(2025, 1, 31, hour: 23, minute: 59)) == 0)
    }

    @Test("A December expense stays in December when the year rolls over")
    func decemberToJanuaryOneTime() throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(60, to: group, on: TestSupport.date(2024, 12, 31), in: context)

        #expect(group.monthlySpending(asOf: TestSupport.date(2024, 12, 15)) == 60)
        #expect(group.monthlySpending(asOf: TestSupport.date(2025, 1, 1)) == 0)
    }

    @Test("A monthly expense started in December carries into January of the next year")
    func decemberToJanuaryMonthly() throws {
        let group = try TestSupport.makeGroup(in: context)

        try TestSupport.addTransaction(
            15, to: group, on: TestSupport.date(2024, 12, 31),
            isRecurring: true, recurringFrequency: "monthly", in: context
        )

        #expect(group.monthlySpending(asOf: TestSupport.date(2025, 1, 1)) == 15)
        #expect(group.monthlySpending(asOf: TestSupport.date(2024, 11, 30)) == 0)
    }

    // MARK: Budget percentage

    @Test("Spending percentage is zero when the group has no budget")
    func percentageWithoutBudget() throws {
        let group = try TestSupport.makeGroup(monthlyBudget: 0, in: context)

        try TestSupport.addTransaction(50, to: group, on: TestSupport.date(2025, 3, 10), in: context)

        #expect(group.monthlySpendingPercentage(asOf: TestSupport.date(2025, 3, 20)) == 0)
    }

    @Test("Spending percentage is spending divided by the budget")
    func percentageWithBudget() throws {
        let group = try TestSupport.makeGroup(monthlyBudget: 200, in: context)

        try TestSupport.addTransaction(50, to: group, on: TestSupport.date(2025, 3, 10), in: context)

        #expect(group.monthlySpendingPercentage(asOf: TestSupport.date(2025, 3, 20)) == 0.25)
    }

    @Test("Spending percentage goes past 100% when over budget")
    func percentageOverBudget() throws {
        let group = try TestSupport.makeGroup(monthlyBudget: 200, in: context)

        try TestSupport.addTransaction(300, to: group, on: TestSupport.date(2025, 3, 10), in: context)

        #expect(group.monthlySpendingPercentage(asOf: TestSupport.date(2025, 3, 20)) == 1.5)
    }

    // MARK: Over budget

    @Test("A group with no budget is never over budget")
    func notOverWithoutBudget() throws {
        let group = try TestSupport.makeGroup(monthlyBudget: 0, in: context)

        try TestSupport.addTransaction(500, to: group, on: TestSupport.date(2025, 3, 10), in: context)

        #expect(group.isOverBudget(asOf: TestSupport.date(2025, 3, 20)) == false)
    }

    @Test("Spending exactly the budget isn't over budget")
    func notOverAtExactBudget() throws {
        let group = try TestSupport.makeGroup(monthlyBudget: 200, in: context)

        try TestSupport.addTransaction(200, to: group, on: TestSupport.date(2025, 3, 10), in: context)

        #expect(group.isOverBudget(asOf: TestSupport.date(2025, 3, 20)) == false)
    }

    @Test("Spending more than the budget is over budget")
    func overWhenExceeded() throws {
        let group = try TestSupport.makeGroup(monthlyBudget: 200, in: context)

        try TestSupport.addTransaction(200.01, to: group, on: TestSupport.date(2025, 3, 10), in: context)

        #expect(group.isOverBudget(asOf: TestSupport.date(2025, 3, 20)))
    }
}
