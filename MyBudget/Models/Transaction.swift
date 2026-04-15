import Foundation
import SwiftData

@Model
final class Transaction: Identifiable {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var date: Date
    var notes: String
    var category: BudgetCategory?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = Date(),
        notes: String = "",
        category: BudgetCategory? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        // FIX: Truncate date to the start of the day to ensure clean month-based comparisons
        self.date = Calendar.current.startOfDay(for: date)
        self.notes = notes
        self.category = category
        self.createdAt = createdAt
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
