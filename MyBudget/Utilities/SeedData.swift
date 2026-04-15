import Foundation
import SwiftData

actor SeedData {
    static let shared = SeedData()
    private var hasSeeded = false

    func seedIfNeeded(context: ModelContext) {
        guard !hasSeeded else { return }

        // Check if categories already exist
        let descriptor = FetchDescriptor<BudgetCategory>()
        if let existingBudgetCategories = try? context.fetch(descriptor), !existingBudgetCategories.isEmpty {
            hasSeeded = true
            return
        }

        // Create default categories
        // Note: monthlyBudget defaults to the same as budgetLimit (yearly)
        // Users can adjust monthlyBudget separately for each category
        let defaultCategories = [
            BudgetCategory(name: "Food & Dining", color: "orange", icon: "🍔", budgetLimit: 0, monthlyBudget: 0, isDefault: true),
            BudgetCategory(name: "Entertainment", color: "purple", icon: "🎉", budgetLimit: 0, monthlyBudget: 0, isDefault: true),
            BudgetCategory(name: "Transport", color: "green", icon: "🚗", budgetLimit: 0, monthlyBudget: 0, isDefault: true),
            BudgetCategory(name: "Shopping", color: "pink", icon: "🛒", budgetLimit: 0, monthlyBudget: 0, isDefault: true),
            BudgetCategory(name: "Bills & Fees", color: "red", icon: "📋", budgetLimit: 0, monthlyBudget: 0, isDefault: true),
            BudgetCategory(name: "Health", color: "blue", icon: "💪", budgetLimit: 0, monthlyBudget: 0, isDefault: true)
        ]

        for category in defaultCategories {
            context.insert(category)
        }

        hasSeeded = true

        try? context.save()
    }
}
