import Foundation
import SwiftData

// MARK: - Category
@Model
final class BudgetCategory: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String
    var icon: String
    var budgetLimit: Double      // Total yearly budget
    var monthlyBudget: Double    // Monthly spending allowance
    var monthlyResetDate: Date   // Date this month's budget resets (start of month by default)
    var isDefault: Bool
    var sortOrder: Int
    @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
    var transactions: [Transaction]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, color: String = "blue", icon: String = "tag", budgetLimit: Double = 0, monthlyBudget: Double = 0, monthlyResetDate: Date = {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return now
        }
        return startOfMonth
    }(), isDefault: Bool = false, sortOrder: Int = 0, transactions: [Transaction] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.budgetLimit = budgetLimit
        self.monthlyBudget = monthlyBudget
        self.monthlyResetDate = monthlyResetDate
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.transactions = transactions
        self.createdAt = createdAt
    }

    func monthlySpending(asOf referenceDate: Date = Date()) -> Double {
        let calendar = Calendar.current
        let refYear  = calendar.component(.year,  from: referenceDate)
        let refMonth = calendar.component(.month, from: referenceDate)
        // Start of the reference month (used for "started on or before" check)
        let startOfRefMonth = calendar.date(from: DateComponents(year: refYear, month: refMonth, day: 1)) ?? referenceDate

        return transactions
            .filter { tx in
                let txYear  = calendar.component(.year,  from: tx.date)
                let txMonth = calendar.component(.month, from: tx.date)

                if tx.isRecurring {
                    switch tx.recurringFrequency {
                    case "monthly":
                        // Count every month on or after the transaction's start month
                        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfRefMonth) ?? referenceDate
                        return tx.date < startOfNextMonth
                    case "yearly":
                        // Count in the same calendar month, for every year since it started
                        return txMonth == refMonth && txYear <= refYear
                    default:
                        return txYear == refYear && txMonth == refMonth
                    }
                } else {
                    return txYear == refYear && txMonth == refMonth
                }
            }
            .reduce(0) { $0 + $1.amount }
    }

    func monthlySpendingPercentage(asOf referenceDate: Date = Date()) -> Double {
        guard monthlyBudget > 0 else { return 0 }
        return monthlySpending(asOf: referenceDate) / monthlyBudget
    }

    func isOverBudget(asOf referenceDate: Date = Date()) -> Bool {
        monthlyBudget > 0 && monthlySpending(asOf: referenceDate) > monthlyBudget
    }
}
