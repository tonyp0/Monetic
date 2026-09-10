import SwiftUI

struct SetBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var monthlyBudget: Double
    @Binding var budgetSetMonth: String
    let isNewMonthPrompt: Bool

    @AppStorage("repeatMonthlyBudget") private var repeatMonthlyBudget: Bool = false
    @State private var input: String = ""
    @FocusState private var isFocused: Bool

    private var currentMonthName: String {
        MonthKey.displayName()
    }

    private var parsedAmount: Double {
        AmountInput.parse(input) ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Text(isNewMonthPrompt ? "New Month" : "Monthly Budget")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(isNewMonthPrompt
                         ? "Set your budget for \(currentMonthName)"
                         : "How much do you plan to spend in \(currentMonthName)?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Large currency display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Currency.symbol)
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.secondary)
                    Text(input.isEmpty ? "0" : input)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }
                .onTapGesture { isFocused = true }

                // Hidden text field
                TextField("", text: $input)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .onChange(of: input) { _, newValue in
                        input = AmountInput.sanitize(newValue)
                    }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: save) {
                        Text("Save Budget")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(parsedAmount <= 0)

                    // The new-month prompt has no Cancel, so it always needs one
                    // other way out — otherwise a user with no previous budget
                    // is stuck here on first launch.
                    if isNewMonthPrompt {
                        Button(action: keepSame) {
                            Text(monthlyBudget > 0 ? "Keep Last Month's Budget" : "Skip for Now")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle(currentMonthName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isNewMonthPrompt {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .onAppear {
                if monthlyBudget > 0 {
                    input = String(format: "%.2f", monthlyBudget)
                }
                isFocused = true
            }
        }
    }

    private func save() {
        monthlyBudget = parsedAmount
        budgetSetMonth = MonthKey.key()
        dismiss()
    }

    private func keepSame() {
        budgetSetMonth = MonthKey.key()
        dismiss()
    }
}
