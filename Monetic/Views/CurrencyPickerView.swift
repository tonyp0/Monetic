import SwiftUI

/// Settings → Currency: a searchable list of every supported currency.
/// Device Default first, then a short common group, then the rest by name.
/// Picking one only relabels amounts; nothing is converted.
struct CurrencyPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let locale = Locale.current
    private var common: [String] { Currency.commonOptions(device: Currency.deviceCode) }
    private var others: [String] {
        let commonSet = Set(common)
        return Currency.options.filter { !commonSet.contains($0) }
    }

    var body: some View {
        ZStack {
            BrandBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Brand.Space.stack) {
                    if query.isEmpty {
                        section(nil, rows: [""])
                        section("Common", rows: common)
                        section("All currencies", rows: others)
                    } else {
                        let matches = Currency.options.filter { Currency.matches($0, query: query, locale: locale) }
                        if matches.isEmpty {
                            Text("No currency matches “\(query)”.")
                                .font(.subheadline)
                                .foregroundStyle(Brand.textSecondary)
                        } else {
                            section(nil, rows: matches)
                        }
                    }
                }
                .padding(.horizontal, Brand.Space.gutter)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name or code")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Currency")
                    .font(Brand.display(16, .semibold))
                    .foregroundStyle(Brand.textPrimary)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String?, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title).brandEyebrow()
            }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element) { index, code in
                    if index > 0 {
                        Rectangle().fill(Brand.hairline).frame(height: 1)
                    }
                    row(code)
                }
            }
            .brandCard()
        }
    }

    /// "" is Device Default.
    private func row(_ code: String) -> some View {
        let shown = code.isEmpty ? Currency.deviceCode : code
        let name = Currency.name(for: shown, locale: locale)
        let title = code.isEmpty ? "Device Default" : name
        let detail = code.isEmpty
            ? "\(name) · \(shown)"
            : "\(shown) · \(Currency.symbol(for: shown, locale: locale))"
        let selected = selection == code
        return Button {
            selection = code
            dismiss()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Brand.display(15, .medium))
                        .foregroundStyle(Brand.textPrimary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Brand.textSecondary)
                }
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Brand.accent)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(code.isEmpty ? "Device Default, \(name)" : name)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("currencyRow_\(code.isEmpty ? "device" : code)")
    }
}
