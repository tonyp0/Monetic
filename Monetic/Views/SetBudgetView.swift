import SwiftUI

struct SetBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var monthlyBudget: Double
    @Binding var budgetSetMonth: String
    @Binding var isNewMonthPrompt: Bool

    @AppStorage("repeatMonthlyBudget") private var repeatMonthlyBudget: Bool = false
    @State private var input: String = ""
    @FocusState private var isFocused: Bool

    private var currentMonthName: String {
        MonthKey.displayName()
    }

    private var parsedAmount: Double {
        AmountInput.parse(input) ?? 0
    }

    private var isEmpty: Bool { input.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                VStack(spacing: 28) {
                    Spacer(minLength: 12)

                    VStack(spacing: 9) {
                        Text(isNewMonthPrompt ? "New Month" : "Monthly Budget")
                            .font(Brand.display(24, .bold))
                            .foregroundStyle(Brand.textPrimary)

                        Text(isNewMonthPrompt
                             ? "Set your budget for \(currentMonthName)."
                             : "How much do you plan to spend in \(currentMonthName)?")
                            .font(.subheadline)
                            .foregroundStyle(Brand.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }

                    amountDisplay

                    // Hidden field — the big number above is the visible target.
                    TextField("", text: $input)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .accessibilityIdentifier("budgetAmountField")
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .onChange(of: input) { _, newValue in
                            input = AmountInput.sanitize(newValue)
                        }

                    Spacer()

                    VStack(spacing: 12) {
                        // When the user repeats their budget month to month, lead
                        // with the roll-over action instead of an empty entry field —
                        // it's the choice they've already told us they want.
                        if isNewMonthPrompt && repeatMonthlyBudget && monthlyBudget > 0 {
                            Button(action: keepSame) {
                                Text("Roll Over Last Month's Budget (")
                                    + Text(monthlyBudget, format: .currency(code: Currency.code))
                                    + Text(")")
                            }
                            .buttonStyle(GradientButtonStyle())

                            Button("Set a Different Amount", action: save)
                                .buttonStyle(SoftButtonStyle())
                                .disabled(parsedAmount <= 0)
                        } else {
                            Button("Save Budget", action: save)
                                .buttonStyle(GradientButtonStyle())
                                .disabled(parsedAmount <= 0)
                                .accessibilityIdentifier("saveBudgetButton")

                            // The new-month prompt has no Cancel, so it always needs one
                            // other way out — otherwise a user with no previous budget
                            // is stuck here on first launch.
                            if isNewMonthPrompt {
                                Button(action: keepSame) {
                                    Text(monthlyBudget > 0 ? "Keep Last Month's Budget" : "Skip for Now")
                                }
                                .buttonStyle(SoftButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, Brand.Space.gutter)
                    .padding(.bottom, 10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(currentMonthName).brandEyebrow()
                }
                if !isNewMonthPrompt {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Brand.textSecondary)
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
        .tint(Brand.accent)
    }

    /// The one screen in the app that's mostly a single number, so it gets the
    /// full gradient treatment.
    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(Currency.symbol)
                .font(Brand.number(34, .medium))
                .foregroundStyle(isEmpty ? Brand.textTertiary : Brand.textSecondary)

            Text(isEmpty ? "0" : input)
                .font(Brand.number(64))
                .foregroundStyle(isEmpty ? AnyShapeStyle(Brand.textTertiary) : AnyShapeStyle(Brand.gradient))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
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
