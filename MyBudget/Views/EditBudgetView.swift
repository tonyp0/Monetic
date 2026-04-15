import SwiftUI
import SwiftData

struct EditBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var category: BudgetCategory
    @State private var monthlyBudget: String = ""
    @State private var yearlyBudget: String = ""
    @State private var showingDeleteAlert = false
    @State private var isDarkMode = false

    init(category: BudgetCategory) {
        self.category = category
        _monthlyBudget = State(initialValue: category.monthlyBudget > 0 ? String(format: "%.2f", category.monthlyBudget) : "")
        _yearlyBudget = State(initialValue: category.budgetLimit > 0 ? String(format: "%.2f", category.budgetLimit) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Monthly Budget Section (reset at start of month)
                Section {
                    HStack {
                        Text("📅 Monthly Budget")
                        Spacer()
                        TextField("0", text: $monthlyBudget)
                            .font(.title2)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("💵 Monthly Spending Allowance")
                } footer: {
                    Text("🔄 Resets on the 1st of each month • Set how much you can spend this month")
                }

                // Yearly Total Budget Section
                Section {
                    HStack {
                        Text("🎯 Yearly Total Budget")
                        Spacer()
                        TextField("0", text: $yearlyBudget)
                            .font(.title2)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("📅 Total Budget for the Year")
                } footer: {
                    Text("📊 This can be used for long-term savings goals")
                }

                // Current Spending Info
                Section {
                    HStack {
                        Text("💰 Spent this month")
                        Spacer()
                        Text(formattedMonthlySpending)
                            .fontWeight(.semibold)
                    }

                    if category.monthlyBudget > 0 {
                        HStack {
                            Text("Remaining")
                            Spacer()
                            Text(formattedRemaining)
                                .fontWeight(.semibold)
                                .foregroundColor(remainingColor)
                        }

                        HStack {
                            Text("Progress")
                            Spacer()
                            Text("\(String(format: "%.0f%%", category.monthlySpendingPercentage() * 100))")
                                .fontWeight(.semibold)
                                .foregroundColor(progressColor)
                        }
                    }
                } header: {
                    Text("📈 Current Status")
                }

                // Yearly Budget Info
                Section {
                    HStack {
                        Text("Total Budget")
                        Spacer()
                        if category.budgetLimit > 0 {
                            Text(formattedYearlyBudget)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No limit set")
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("🏆 Yearly Goal")
                } footer: {
                    Text(category.budgetLimit > 0 ? "Use this for long-term tracking" : "No yearly budget target set")
                }

                // Delete Category (if not default)
                if !category.isDefault {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("🗑️ Delete Category", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("🎛️ Budget Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Button("Done") {
                            saveBudget()
                        }
                        .help("Save Changes")
                        if isDarkMode {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.yellow)
                        } else {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .alert("⚠️ Delete Category", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteCategory()
                }
            } message: {
                Text("Are you sure you want to delete \"\(category.name)\"? This will also delete all transactions in this category.")
            }
            .onChange(of: isDarkMode) { newValue in
                UserDefaults.standard.set(newValue, forKey: "MyBudget_darkMode")
            }
            .task {
                isDarkMode = UserDefaults.standard.bool(forKey: "MyBudget_darkMode")
            }
        }
    }

    private var monthlySpending: Double {
        category.monthlySpending()
    }

    private var remaining: Double {
        category.monthlyBudget - monthlySpending
    }

    private var formattedMonthlySpending: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: monthlySpending)) ?? String(format: "$%.2f", monthlySpending)
    }

    private var formattedRemaining: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        let value = abs(remaining)
        let prefix = remaining < 0 ? "+" : ""
        return prefix + (formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value))
    }

    private var formattedYearlyBudget: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: category.budgetLimit)) ?? String(format: "$%.2f", category.budgetLimit)
    }

    private var remainingColor: Color {
        remaining < 0 ? .red : .green
    }

    private var progressColor: Color {
        let percentage = category.monthlySpendingPercentage()
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }

    private func saveBudget() {
        if let monthly = Double(monthlyBudget) {
            category.monthlyBudget = monthly
        }
        if let yearly = Double(yearlyBudget) {
            category.budgetLimit = yearly
        }
        dismiss()
    }

    private func deleteCategory() {
        // Delete all transactions in this category first
        for transaction in category.transactions {
            modelContext.delete(transaction)
        }
        modelContext.delete(category)
        dismiss()
    }
}

#Preview {
    EditBudgetView(category: BudgetCategory(name: "Entertainment", budgetLimit: 100, monthlyBudget: 100))
        .modelContainer(for: [BudgetCategory.self, Transaction.self], inMemory: true)
}
