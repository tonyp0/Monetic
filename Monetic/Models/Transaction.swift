import Foundation
import SwiftData

@Model
final class Transaction: Identifiable {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var date: Date
    var notes: String
    var category: BudgetCategory?
    var isRecurring: Bool
    var recurringFrequency: String   // "monthly" | "yearly" | "" if not recurring
    var createdAt: Date

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = Date(),
        notes: String = "",
        category: BudgetCategory? = nil,
        isRecurring: Bool = false,
        recurringFrequency: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.date = Calendar.current.startOfDay(for: date)
        self.notes = notes
        self.category = category
        self.isRecurring = isRecurring
        self.recurringFrequency = isRecurring ? recurringFrequency : ""
        self.createdAt = createdAt
    }
}
