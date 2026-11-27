import SwiftUI
import Testing
@testable import Monetic

/// How `BudgetBar` reads the budget from its inputs. Drawing is checked in the screenshot tour.
@Suite("Budget bar")
struct BudgetBarTests {
    @Test("A single fraction is used as given")
    func singleFraction() {
        let bar = BudgetBar(fraction: 0.62)
        #expect(bar.fraction == 0.62)
        #expect(!bar.isOver)
    }

    @Test("Segments add up against the budget, ignoring empty and negative amounts")
    func segmentsSum() {
        let bar = BudgetBar(segments: [
            .init(color: .red, amount: 30),
            .init(color: .blue, amount: 0),
            .init(color: .green, amount: -5),
            .init(color: .orange, amount: 20),
        ], total: 200)
        #expect(bar.fraction == 0.25)
        #expect(!bar.isOver)
    }

    @Test("Spending past the budget is over")
    func overBudget() {
        let bar = BudgetBar(segments: [.init(color: .red, amount: 250)], total: 200)
        #expect(bar.isOver)
    }

    @Test("Spending with no budget set counts as over; nothing spent is empty")
    func noBudget() {
        #expect(BudgetBar(segments: [.init(color: .red, amount: 5)], total: 0).isOver)
        #expect(BudgetBar(segments: [], total: 0).fraction == 0)
    }
}
