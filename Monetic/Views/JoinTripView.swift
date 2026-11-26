import SwiftUI

/// "Join this trip?": the plan from a friend's link, with the user's own share
/// of the goal to adjust before saving. When the same link was joined
/// before, it offers to update that trip's plan instead.
struct JoinTripView: View {
    @Environment(\.dismiss) private var dismiss

    let share: TripShare
    /// The trip already joined from this link, if any.
    let existing: Trip?
    /// Called with the goal the user settled on.
    let onConfirm: (Double) -> Void

    @State private var goalText: String
    @FocusState private var amountFocused: Bool

    init(share: TripShare, existing: Trip?, onConfirm: @escaping (Double) -> Void) {
        self.share = share
        self.existing = existing
        self.onConfirm = onConfirm
        let goal = existing.map(\.effectiveSavingsGoal) ?? share.perPersonShare
        _goalText = State(initialValue: AmountInput.text(cents: Int((goal * 100).rounded()), code: share.currencyCode))
    }

    private var code: String { share.currencyCode }
    private var goal: Double? { AmountInput.cents(goalText).flatMap { $0 > 0 ? Double($0) / 100 : nil } }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: Brand.Space.stack) {
                        planCard

                        VStack(alignment: .leading, spacing: 8) {
                            AmountEntryCard(amount: $goalText, focus: $amountFocused, label: "Your share to save", currencyCode: code)
                            Text(share.travelers == 1
                                 ? "The plan is for one traveler. Change it if you're paying a different amount."
                                 : "The plan splits \(share.total.formatted(.currency(code: code))) \(share.travelers) ways: \(share.perPersonShare.formatted(.currency(code: code))) each. Change it if you're paying a different amount.")
                                .font(.caption)
                                .foregroundStyle(Brand.textTertiary)
                        }

                        if let estimate = share.estimate {
                            TripBreakdownCard(estimate: estimate)
                        }

                        privacyNote

                        Button(existing == nil ? "Join trip" : "Update plan") { confirm() }
                            .buttonStyle(GradientButtonStyle())
                            .disabled(goal == nil)
                            .accessibilityIdentifier("joinTripButton")
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
                    Text(existing == nil ? "Join this trip?" : "Update this trip?")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Brand.textSecondary)
                        .accessibilityIdentifier("cancelJoinButton")
                }
            }
        }
        .tint(Brand.accent)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
                Text("A friend's trip plan")
            }
            .brandEyebrow()

            Text(share.name)
                .font(Brand.display(22, .bold))
                .foregroundStyle(Brand.textPrimary)
                .accessibilityIdentifier("joinTripName")

            Text(share.destination)
                .font(Brand.display(15, .medium))
                .foregroundStyle(Brand.textSecondary)

            Text("\(TripList.dateRangeText(start: share.startDate, end: share.endDate)) · \(TripList.nightsText(TripDates.nights(from: share.startDate, to: share.endDate, calendar: .current)))")
                .font(.subheadline)
                .foregroundStyle(Brand.textSecondary)

            Rectangle().fill(Brand.hairline).frame(height: 1)

            HStack {
                Text(share.travelers == 1 ? "1 traveler" : "\(share.travelers) travelers")
                    .font(Brand.display(14, .medium))
                    .foregroundStyle(Brand.textPrimary)
                Spacer()
                Text(share.total, format: .currency(code: code))
                    .font(Brand.number(18, .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .accessibilityIdentifier("joinTripTotal")
            }

            if share.source == .manual, code != Currency.code {
                Text("Amounts are in \(code). Monetic doesn't convert currencies.")
                    .font(.caption)
                    .foregroundStyle(Brand.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(padding: 20)
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let existing {
                Text("You've already joined this trip. Updating changes the plan; the \(existing.totalSaved.formatted(.currency(code: existing.totalCurrencyCode))) you've saved and your savings settings stay as they are.")
                    .accessibilityIdentifier("joinUpdateNote")
            }
            Text("Only the plan was shared. What you save stays on your phone, and nobody else sees it.")
        }
        .font(.caption)
        .foregroundStyle(Brand.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func confirm() {
        guard let goal else { return }
        onConfirm(goal)
        dismiss()
    }
}
