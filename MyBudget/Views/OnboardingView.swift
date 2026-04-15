import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var hasCompletedOnboarding: Bool

    private let defaultCategories: [(name: String, icon: String, color: String)] = [
        ("Food & Dining",  "🍔", "orange"),
        ("Entertainment",  "🎉", "purple"),
        ("Transport",      "🚗", "green"),
        ("Shopping",       "🛒", "pink"),
        ("Bills & Fees",   "📋", "red"),
        ("Health",         "💪", "blue"),
        ("Travel",         "🧳", "teal"),
        ("Work",           "💼", "indigo"),
    ]

    @State private var selected: Set<String> = [
        "Food & Dining", "Entertainment", "Transport", "Shopping", "Bills & Fees", "Health"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Text("👋")
                        .font(.system(size: 56))
                    Text("Welcome to MyBudget")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Choose which groups to start with.\nYou can add or remove more later.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)
                .padding(.bottom, 24)
                .padding(.horizontal, 32)

                // Category list
                List {
                    ForEach(defaultCategories, id: \.name) { cat in
                        Button(action: { toggle(cat.name) }) {
                            HStack(spacing: 14) {
                                Text(cat.icon)
                                    .font(.system(size: 28))
                                    .frame(width: 36)
                                Text(cat.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: selected.contains(cat.name) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundColor(selected.contains(cat.name) ? .accentColor : Color(.tertiaryLabel))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // CTA button
                Button(action: saveAndContinue) {
                    Text(selected.isEmpty ? "Skip for Now" : "Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationBarHidden(true)
        }
    }

    private func toggle(_ name: String) {
        if selected.contains(name) {
            selected.remove(name)
        } else {
            selected.insert(name)
        }
    }

    private func saveAndContinue() {
        var orderIndex = 0
        for cat in defaultCategories where selected.contains(cat.name) {
            let category = BudgetCategory(
                name: cat.name,
                color: cat.color,
                icon: cat.icon,
                budgetLimit: 0,
                monthlyBudget: 0,
                isDefault: true,
                order: orderIndex
            )
            modelContext.insert(category)
            orderIndex += 1
        }
        try? modelContext.save()
        hasCompletedOnboarding = true
    }
}
