import Foundation
import SwiftData

/// Money set aside for a trip (positive) or taken back out (negative).
///
/// Kept apart from `Transaction` on purpose: saving for a trip isn't
/// spending, so it never counts toward the monthly budget or any group.
@Model
final class SavingsContribution: Identifiable {
    @Attribute(.unique) var id: UUID
    /// Positive for a deposit, negative for a withdrawal.
    var amount: Double
    /// Start of the day it was saved.
    var date: Date
    var notes: String
    var trip: Trip?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date,
        notes: String = "",
        trip: Trip? = nil,
        createdAt: Date,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.amount = amount
        self.date = calendar.startOfDay(for: date)
        self.notes = notes
        self.trip = trip
        self.createdAt = createdAt
    }

    var isWithdrawal: Bool { amount < 0 }
}
