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
    var order: Int
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
    }(), isDefault: Bool = false, order: Int = 0, transactions: [Transaction] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.budgetLimit = budgetLimit
        self.monthlyBudget = monthlyBudget
        self.monthlyResetDate = monthlyResetDate
        self.isDefault = isDefault
        self.order = order
        self.transactions = transactions
        self.createdAt = createdAt
    }

    func monthlySpending(asOf referenceDate: Date = Date()) -> Double {
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: referenceDate)

        return transactions
            .filter { transaction in
                let transactionComponents = calendar.dateComponents([.year, .month], from: transaction.date)
                return transactionComponents.year == monthComponents.year &&
                    transactionComponents.month == monthComponents.month
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
