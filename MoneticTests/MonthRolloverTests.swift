import Testing
@testable import Monetic

/// When the home screen asks for a new month's budget. Month keys are passed
/// in, so these never depend on today's date.
@Suite("New-month budget prompt")
@MainActor
struct MonthRolloverTests {
    @Test("No prompt before onboarding is finished")
    func noPromptDuringOnboarding() {
        let rollover = ContentView.monthRollover(
            hasCompletedOnboarding: false, budgetSetMonth: "", currentMonth: "2026-03", monthlyBudget: 0
        )

        #expect(rollover.shouldPrompt == false)
    }

    @Test("No prompt when the budget was already set this month")
    func noPromptWhenSetThisMonth() {
        let rollover = ContentView.monthRollover(
            hasCompletedOnboarding: true, budgetSetMonth: "2026-03", currentMonth: "2026-03", monthlyBudget: 450
        )

        #expect(rollover.shouldPrompt == false)
        #expect(rollover.lastMonthlyBudget == nil)
    }

    @Test("Prompt when the budget was set in an earlier month or never", arguments: ["2026-02", "2025-03", ""])
    func promptWhenMonthChanged(_ budgetSetMonth: String) {
        let rollover = ContentView.monthRollover(
            hasCompletedOnboarding: true, budgetSetMonth: budgetSetMonth, currentMonth: "2026-03", monthlyBudget: 0
        )

        #expect(rollover.shouldPrompt)
    }

    @Test("Last month's budget is remembered when there was one")
    func remembersLastBudget() {
        let rollover = ContentView.monthRollover(
            hasCompletedOnboarding: true, budgetSetMonth: "2026-02", currentMonth: "2026-03", monthlyBudget: 450
        )

        #expect(rollover.lastMonthlyBudget == 450)
    }

    @Test("Last month's budget is left alone when there wasn't one")
    func keepsLastBudgetWhenNone() {
        let rollover = ContentView.monthRollover(
            hasCompletedOnboarding: true, budgetSetMonth: "2026-02", currentMonth: "2026-03", monthlyBudget: 0
        )

        #expect(rollover.lastMonthlyBudget == nil)
    }
}
