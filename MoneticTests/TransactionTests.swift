import Foundation
import SwiftData
import Testing
@testable import Monetic

@Suite("Transaction")
@MainActor
struct TransactionTests {
    // Swift Testing makes a new suite instance — and so a new, empty store —
    // for every test. The suite holds the container because a context alone
    // doesn't keep it alive.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try TestSupport.makeContainer()
    }

    @Test("The date is stored as the start of its day")
    func dateNormalizedToStartOfDay() throws {
        let afternoon = TestSupport.date(2025, 6, 9, hour: 17, minute: 42)

        let transaction = Transaction(amount: 10, date: afternoon)
        context.insert(transaction)

        #expect(transaction.date == Calendar.current.startOfDay(for: afternoon))
    }

    @Test("A one-time transaction drops any repeat frequency it was given")
    func frequencyClearedWhenNotRecurring() throws {
        let transaction = Transaction(amount: 10, isRecurring: false, recurringFrequency: "monthly")
        context.insert(transaction)

        #expect(transaction.recurringFrequency == "")
    }

    @Test("A recurring transaction keeps its repeat frequency")
    func frequencyKeptWhenRecurring() throws {
        let transaction = Transaction(amount: 10, isRecurring: true, recurringFrequency: "yearly")
        context.insert(transaction)

        #expect(transaction.recurringFrequency == "yearly")
    }
}
