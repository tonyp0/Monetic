import SwiftUI
import SwiftData

// MARK: - Draft

/// The editable state behind Log What You Spent: one amount per estimate
/// line. A blank line means "didn't track it", not $0.
struct ActualsDraft: Equatable {
    var texts: [TripEstimate.Kind: String] = [:]

    init(actuals: TripActuals? = nil, code: String = Currency.code) {
        for item in actuals?.lineItems ?? [] {
            texts[item.kind] = AmountInput.text(cents: item.cents, code: code)
        }
    }

    /// The logged amounts, or nil when nothing usable was entered.
    func actuals(loggedAt: Date) -> TripActuals? {
        let items = TripEstimate.Kind.allCases.compactMap { kind -> TripEstimate.LineItem? in
            guard let text = texts[kind], !text.trimmingCharacters(in: .whitespaces).isEmpty,
                  let cents = AmountInput.cents(text), cents >= 0 else { return nil }
            return TripEstimate.LineItem(kind: kind, cents: cents)
        }
        return items.isEmpty ? nil : TripActuals(lineItems: items, loggedAt: loggedAt)
    }
}

/// Amounts are compared with a per diem breakdown in U.S. dollars, so
/// they're entered in dollars too; a typed-in total uses the user's currency.
private func actualsCurrency(for trip: Trip) -> String {
    trip.savedEstimate != nil ? "USD" : trip.totalCurrencyCode
}

// MARK: - Log what you spent

struct LogSpendingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let trip: Trip

    @State private var draft: ActualsDraft
    @FocusState private var focused: TripEstimate.Kind?

    init(trip: Trip) {
        self.trip = trip
        _draft = State(initialValue: ActualsDraft(actuals: trip.actuals, code: actualsCurrency(for: trip)))
    }

    private var code: String { actualsCurrency(for: trip) }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: Brand.Space.stack) {
                        Text("Add up what the trip really cost for everyone, by type. Leave a line empty if you didn't keep track of it.")
                            .font(.subheadline)
                            .foregroundStyle(Brand.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(TripEstimate.Kind.allCases, id: \.self) { kind in
                            field(kind)
                        }
                    }
                    .padding(.horizontal, Brand.Space.gutter)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("What You Spent")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                PlainToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Brand.accentText)
                }
                PlainToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Brand.accentText)
                        .disabled(draft.actuals(loggedAt: Date()) == nil)
                        .accessibilityIdentifier("saveSpendingButton")
                }
            }
        }
        .tint(Brand.accentText)
    }

    private func field(_ kind: TripEstimate.Kind) -> some View {
        let estimated = trip.savedEstimate?.lineItems.first { $0.kind == kind }
        return BrandField(
            label: kind.title,
            footnote: estimated.map { "Estimated \((Double($0.cents) / 100).formatted(.currency(code: code)))" }
        ) {
            HStack(spacing: 6) {
                Text(code)
                    .font(Brand.display(13, .semibold))
                    .foregroundStyle(Brand.textSecondary)
                TextField("Not tracked", text: Binding(
                    get: { draft.texts[kind] ?? "" },
                    set: { draft.texts[kind] = AmountInput.sanitize($0, code: code) }
                ))
                .font(Brand.display(16, .medium))
                .keyboardType(.decimalPad)
                .focused($focused, equals: kind)
                .accessibilityIdentifier("actualField_\(kind.rawValue)")
            }
        }
    }

    private func save() {
        guard let actuals = draft.actuals(loggedAt: Date()) else { return }
        trip.actuals = actuals
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Estimate vs actual

/// On a past trip: a prompt to log spending, then the comparison.
struct TripActualsCard: View {
    let trip: Trip
    let onLog: () -> Void

    private var code: String { actualsCurrency(for: trip) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Estimate vs actual").brandLabel()
                Spacer()
                if trip.actuals != nil {
                    Button("Edit", action: onLog)
                        .font(Brand.display(13, .semibold))
                        .foregroundStyle(Brand.accentText)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("editSpendingButton")
                }
            }

            if let comparison = trip.comparison {
                comparisonRows(comparison)
            } else {
                Text("How did it go? Log what you really spent to see how close the estimate was.")
                    .font(.subheadline)
                    .foregroundStyle(Brand.textSecondary)
                Button(action: onLog) {
                    Label("Log what you spent", systemImage: "list.bullet.clipboard")
                }
                .buttonStyle(SoftButtonStyle())
                .accessibilityIdentifier("logSpendingButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    @ViewBuilder
    private func comparisonRows(_ comparison: EstimateAccuracy.Comparison) -> some View {
        HStack {
            Spacer()
            Text("Estimate").frame(width: 84, alignment: .trailing)
            Text("Actual").frame(width: 84, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(Brand.textTertiary)
        .accessibilityHidden(true)

        ForEach(comparison.lines) { line in
            row(line.kind.title, estimated: line.estimatedCents, actual: line.actualCents, gap: line.error)
        }

        if let overall = comparison.overall {
            Rectangle().fill(Brand.hairline).frame(height: 1)
            row(comparison.comparedLines > 0 ? "Compared" : "Total", estimated: overall.estimatedCents,
                actual: overall.actualCents, gap: overall, bold: true)
                .accessibilityIdentifier("actualsOverall")
            if let line = summary(overall) {
                Text(line)
                    .font(Brand.display(14, .medium))
                    .foregroundStyle(Brand.textPrimary)
                    .accessibilityIdentifier("actualsSummary")
            }
            if comparison.comparedLines > 0,
               comparison.comparedLines < comparison.lines.count {
                Text("Covers the \(comparison.comparedLines) lines with both an estimate and an amount you logged.")
                    .font(.caption)
                    .foregroundStyle(Brand.textTertiary)
            }
        }
    }

    private func row(_ title: String, estimated: Int?, actual: Int?, gap: EstimateAccuracy.Gap?, bold: Bool = false) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack {
                Text(title)
                    .font(Brand.display(14, bold ? .semibold : .medium))
                    .foregroundStyle(Brand.textPrimary)
                Spacer()
                Text(money(estimated)).frame(width: 84, alignment: .trailing)
                    .foregroundStyle(Brand.textSecondary)
                Text(money(actual)).frame(width: 84, alignment: .trailing)
                    .foregroundStyle(Brand.textPrimary)
            }
            .font(Brand.number(14, bold ? .semibold : .regular))
            if let gap, gap.differenceCents != 0 {
                Text(gapText(gap))
                    .font(.caption)
                    .foregroundStyle(gap.differenceCents > 0 ? Brand.warning : Brand.positive)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func money(_ cents: Int?) -> String {
        cents.map { (Double($0) / 100).formatted(.currency(code: code)) } ?? "—"
    }

    /// "+$120.00 (18% over)"
    private func gapText(_ gap: EstimateAccuracy.Gap) -> String {
        let amount = (Double(gap.absoluteCents) / 100).formatted(.currency(code: code))
        let sign = gap.differenceCents > 0 ? "+" : "−"
        guard let percent = gap.absolutePercent else { return "\(sign)\(amount)" }
        return "\(sign)\(amount) (\(Int(percent.rounded()))% \(gap.differenceCents > 0 ? "over" : "under"))"
    }

    private func summary(_ gap: EstimateAccuracy.Gap) -> String? {
        guard let percent = gap.signedPercent else { return nil }
        let rounded = Int(percent.rounded())
        if rounded == 0 { return "Right on the estimate." }
        return "You spent \(abs(rounded))% \(rounded > 0 ? "more" : "less") than estimated."
    }
}
