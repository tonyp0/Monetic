import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppAppearance.storageKey) var appearance: AppAppearance = .system
    @AppStorage("repeatMonthlyBudget") private var repeatMonthlyBudget: Bool = false
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @AppStorage("budgetSetMonth") private var budgetSetMonth: String = ""
    @AppStorage("lastMonthlyBudget") private var lastMonthlyBudget: Double = 0
    @AppStorage(Currency.storageKey) private var selectedCurrencyCode: String = ""

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
                PlainToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Brand.accentText)
                }
            }
        }
        .tint(Brand.accentText)
    }

    // MARK: Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance").brandLabel()

            AppearanceSelector(selection: $appearance)

            Text("Matches your iPhone unless you pick Light or Dark.")
                .font(.caption)
                .foregroundStyle(Brand.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
    
    // MARK: Currency
    
    private var currencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currency").brandLabel()

            NavigationLink {
                CurrencyPickerView(selection: currencySelection)
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currencySelection.wrappedValue.isEmpty ? "Device Default" : Currency.name(for: Currency.code))
                            .font(Brand.display(15, .medium))
                            .foregroundStyle(Brand.textPrimary)
                        Text("\(Currency.isSelectable(selectedCurrencyCode) ? "" : "\(Currency.name(for: Currency.code)) · ")\(Currency.code) · \(Currency.symbol)")
                            .font(.caption)
                            .foregroundStyle(Brand.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Brand.textTertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Currency, \(currencySelection.wrappedValue.isEmpty ? "Device Default, " : "")\(Currency.name(for: Currency.code))")
            .accessibilityIdentifier("currencyRow")

            VStack(alignment: .leading, spacing: 4) {
                Text(currencySelection.wrappedValue.isEmpty
                    ? "Amounts follow your device's region."
                    : "Amounts are shown in \(Currency.code).")
                if currencySelection.wrappedValue.isEmpty && Currency.deviceCodeIsUnsupported {
                    Text("Your region's currency uses three decimal places, which Monetic can't store, so it uses US dollars.")
                }
                Text("Changing currency doesn't convert amounts you've already entered.")
            }
            .font(.caption)
            .foregroundStyle(Brand.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
    

    /// The stored choice, or "" (Device Default) when it holds a code that's
    /// no longer offered.
    private var currencySelection: Binding<String> {
        Binding(
            get: { Currency.isSelectable(selectedCurrencyCode) ? selectedCurrencyCode : "" },
            set: { selectedCurrencyCode = $0 }
        )
    }

    // MARK: Budget

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget").brandLabel()

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
                            .foregroundStyle(Brand.accentText)
                        Spacer()
                        Text(lastMonthlyBudget, format: .currency(code: Currency.code))
                            .font(Brand.number(15, .semibold))
                            .foregroundStyle(Brand.accentText)
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
            Text("This month").brandLabel()

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
            MoneticWordmark()
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
/// System, Light or Dark, on the shared segmented control.
struct AppearanceSelector: View {
    @Binding var selection: AppAppearance

    private static let options: [(tag: AppAppearance, label: String)] = [
        (.system, "System"),
        (.light, "Light"),
        (.dark, "Dark"),
    ]

    var body: some View {
        BrandSegmented(options: Self.options, selection: $selection) { tag in
            switch tag {
            case .system: "iphone"
            case .light:  "sun.max.fill"
            case .dark:   "moon.fill"
            }
        }
    }
}
