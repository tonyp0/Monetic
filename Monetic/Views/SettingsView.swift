import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appAppearance") var appearance: String = "dark"
    @AppStorage("repeatMonthlyBudget") private var repeatMonthlyBudget: Bool = false
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @AppStorage("budgetSetMonth") private var budgetSetMonth: String = ""
    @AppStorage("lastMonthlyBudget") private var lastMonthlyBudget: Double = 0
    // new property
    @AppStorage("selectedCurrencyCode") private var selectedCurrencyCode: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: Brand.Space.stack) {
                        appearanceCard
                        currencyCard
                        budgetCard
                        if monthlyBudget > 0 {
                            thisMonthCard
                        }
                        about
                    }
                    .padding(.horizontal, Brand.Space.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Brand.display(15, .semibold))
                        .foregroundStyle(Brand.accent)
                }
            }
        }
        .tint(Brand.accent)
    }

    // MARK: Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance").brandEyebrow()

            AppearanceSelector(selection: $appearance)

            Text("Monetic is designed for dark mode. Light mode is fully supported if you prefer it.")
                .font(.caption)
                .foregroundStyle(Brand.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
    
    // MARK: Currency
    
    private var currencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currency").brandEyebrow()
            
            
            Picker("Currency", selection: $selectedCurrencyCode) {
                Text("Device Default").tag("")
                Text("USD").tag("USD")
                Text("EUR").tag("EUR")
                Text("GBP").tag("GBP")
                Text("JPY").tag("JPY")
            }
                      .pickerStyle(.menu)
                      .tint(Brand.accent)
            
            Text(selectedCurrencyCode.isEmpty
                ? "Amounts follow your device's region."
                : "Amounts are shown in \(selectedCurrencyCode).")
                .font(.caption)
                .foregroundStyle(Brand.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
    

    // MARK: Budget

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget").brandEyebrow()

            Toggle(isOn: $repeatMonthlyBudget) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Repeat Monthly Budget")
                        .font(Brand.display(15, .medium))
                        .foregroundStyle(Brand.textPrimary)
                    Text("Carry the same amount forward each month")
                        .font(.caption)
                        .foregroundStyle(Brand.textSecondary)
                }
            }
            .tint(Brand.accent)

            Text(repeatMonthlyBudget
                 ? "You'll be offered the option to roll over last month's budget at the start of each month."
                 : "You'll be prompted to set a new budget at the start of each month.")
                .font(.caption)
                .foregroundStyle(Brand.textTertiary)

            if repeatMonthlyBudget && lastMonthlyBudget > 0 && lastMonthlyBudget != monthlyBudget {
                Rectangle().fill(Brand.hairline).frame(height: 1)

                Button(action: rollOverLastMonth) {
                    HStack {
                        Text("Roll Over Last Month's Budget")
                            .font(Brand.display(15, .medium))
                            .foregroundStyle(Brand.accent)
                        Spacer()
                        Text(lastMonthlyBudget, format: .currency(code: Currency.code))
                            .font(Brand.number(15, .semibold))
                            .foregroundStyle(Brand.accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func rollOverLastMonth() {
        monthlyBudget = lastMonthlyBudget
    }

    // MARK: This month

    private var thisMonthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This Month").brandEyebrow()

            row("Current Budget") {
                Text(monthlyBudget, format: .currency(code: Currency.code))
                    .font(Brand.number(15, .semibold))
                    .foregroundStyle(Brand.textPrimary)
            }

            if !budgetSetMonth.isEmpty {
                Rectangle().fill(Brand.hairline).frame(height: 1)

                row("Set for") {
                    Text(MonthKey.displayName(forKey: budgetSetMonth))
                        .font(Brand.display(15, .medium))
                        .foregroundStyle(Brand.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func row<Trailing: View>(
        _ label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            Text(label)
                .font(Brand.display(15, .medium))
                .foregroundStyle(Brand.textPrimary)
            Spacer()
            trailing()
        }
    }

    // MARK: About

    private var about: some View {
        VStack(spacing: 8) {
            MoneticWordmark(size: 13)
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Version \(version)")
                    .font(.caption2)
                    .foregroundStyle(Brand.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
    }
}

// MARK: - Appearance Selector
/// A segmented control with the brand gradient riding the selection, rather
/// than the stock grey `.segmented` picker.
struct AppearanceSelector: View {
    @Binding var selection: String
    @Namespace private var indicator

    private let options: [(tag: String, label: String, icon: String)] = [
        ("dark",   "Dark",   "moon.fill"),
        ("light",  "Light",  "sun.max.fill"),
        ("system", "System", "iphone"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.tag) { option in
                let isSelected = selection == option.tag

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = option.tag
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: option.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(option.label)
                            .font(Brand.display(13, .semibold))
                    }
                    .foregroundStyle(isSelected ? Color.white : Brand.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Brand.gradientDiagonal)
                                .matchedGeometryEffect(id: "appearance", in: indicator)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Brand.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Brand.hairline, lineWidth: 1)
        )
    }
}


