import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appAppearance") var appearance: String = "system"
    @AppStorage("repeatMonthlyBudget") private var repeatMonthlyBudget: Bool = false
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @AppStorage("budgetSetMonth") private var budgetSetMonth: String = ""

    var body: some View {
        NavigationStack {
            Form {
                // Appearance
                Section {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows your device's display settings.")
                }

                // Budget
                Section {
                    Toggle(isOn: $repeatMonthlyBudget) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Repeat Monthly Budget")
                            Text("Carry the same amount forward each month without prompting")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Budget")
                } footer: {
                    Text(repeatMonthlyBudget
                         ? "Your budget rolls over automatically on the 1st of each month."
                         : "You'll be prompted to set a new budget at the start of each month.")
                }

                // Current budget info
                if monthlyBudget > 0 {
                    Section {
                        HStack {
                            Text("Current Budget")
                            Spacer()
                            Text(monthlyBudget, format: .currency(code: Currency.code))
                                .foregroundColor(.secondary)
                        }
                        if !budgetSetMonth.isEmpty {
                            HStack {
                                Text("Set for")
                                Spacer()
                                Text(formattedMonth)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("This Month")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var formattedMonth: String {
        MonthKey.displayName(forKey: budgetSetMonth)
    }
}
