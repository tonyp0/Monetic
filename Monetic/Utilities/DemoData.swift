#if DEBUG
import Foundation
import SwiftData

/// Realistic sample data for screenshots, behind the DEBUG-only
/// `-UITesting YES -SeedDemoData YES` launch arguments (see `MoneticApp.loadStore()`).
///
/// Lands on a finished-onboarding home screen: a $500 budget for this month,
/// about 57% used, Food & Dining over its own limit, and Shopping and Health
/// still at $0.
enum DemoData {
    static let monthlyBudget: Double = 500

    /// The onboarding screen's default selection, so emoji and colours match.
    static let groupNames: Set<String> = [
        "Food & Dining", "Entertainment", "Transport", "Shopping",
        "Bills & Fees", "Health", "Subscriptions",
    ]

    /// Per-group limits, so one group shows as near and one as over.
    static let groupLimits: [String: Double] = [
        "Food & Dining": 110,
        "Entertainment": 60,
    ]

    /// (group, note, amount, days ago, recurs monthly)
    static let expenses: [(group: String, note: String, amount: Double, daysAgo: Int, monthly: Bool)] = [
        ("Bills & Fees",  "Phone bill",      45.00, 13, true),
        ("Food & Dining", "Groceries",       42.18, 12, false),
        ("Transport",     "Bus pass",        25.00, 11, false),
        ("Subscriptions", "Music streaming", 10.99, 10, false),
        ("Food & Dining", "Pizza night",     18.50,  9, false),
        ("Entertainment", "Movie tickets",   24.00,  8, false),
        ("Food & Dining", "School lunch",     6.25,  6, false),
        ("Subscriptions", "Game pass",        9.99,  5, false),
        ("Transport",     "Gas",             34.60,  4, false),
        ("Food & Dining", "Groceries",       38.90,  3, false),
        ("Entertainment", "Mini golf",       16.00,  2, false),
        ("Food & Dining", "Tacos",           14.75,  1, false),
    ]

    @MainActor
    static func seed(into context: ModelContext, now: Date = Date()) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(monthlyBudget, forKey: "monthlyBudget")
        defaults.set(MonthKey.key(), forKey: "budgetSetMonth")

        OnboardingView.insertStarterGroups(named: groupNames, into: context)
        let groups = (try? context.fetch(FetchDescriptor<BudgetCategory>())) ?? []
        let byName = Dictionary(uniqueKeysWithValues: groups.map { ($0.name, $0) })

        for (name, limit) in groupLimits {
            byName[name]?.monthlyBudget = limit
        }

        // Clamp to the 1st so a run early in the month still counts every
        // expense against this month.
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        for expense in expenses {
            guard let group = byName[expense.group] else { continue }
            let day = calendar.date(byAdding: .day, value: -expense.daysAgo, to: now) ?? now
            let transaction = Transaction(
                amount: expense.amount,
                date: max(startOfMonth, day),
                notes: expense.note,
                category: group,
                isRecurring: expense.monthly,
                recurringFrequency: expense.monthly ? "monthly" : ""
            )
            context.insert(transaction)
        }

        try? context.save()
    }
}
#endif
