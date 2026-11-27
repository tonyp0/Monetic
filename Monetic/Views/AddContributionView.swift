import SwiftUI
import SwiftData

/// Add to Savings, or Edit Contribution when given one. Money put aside here
/// is a `SavingsContribution`, never a `Transaction`, so it doesn't touch the
/// monthly budget.
struct AddContributionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    var contribution: SavingsContribution? = nil

    @State private var draft: ContributionDraft
    @FocusState private var amountFocused: Bool

    init(trip: Trip, contribution: SavingsContribution? = nil) {
        self.trip = trip
        self.contribution = contribution
        _draft = State(initialValue: contribution.map(ContributionDraft.init(contribution:))
                       ?? ContributionDraft(date: Date()))
    }

    private var savedExcludingThis: Double {
        trip.totalSaved - (contribution?.amount ?? 0)
    }

    private var code: String { trip.totalCurrencyCode }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: Brand.Space.stack) {
                        BrandSegmented(
                            options: [("deposit", "Put aside"), ("withdrawal", "Take out")],
                            selection: Binding(
                                get: { draft.isWithdrawal ? "withdrawal" : "deposit" },
                                set: { draft.isWithdrawal = $0 == "withdrawal" }
                            )
                        )
                        .accessibilityIdentifier("contributionKindPicker")

                        AmountEntryCard(amount: $draft.amountText, focus: $amountFocused,
                                        label: draft.isWithdrawal ? "Amount taken out" : "Amount put aside",
                                        currencyCode: code)

                        if let problem = draft.problem(savedExcludingThis: savedExcludingThis, currencyCode: code) {
                            Text(problem)
                                .font(.caption)
                                .foregroundStyle(Brand.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("contributionProblem")
                        }

                        HStack {
                            Text("Date").brandLabel()
                            Spacer()
                            DatePicker("Date", selection: $draft.date, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .tint(Brand.accentText)
                                .accessibilityIdentifier("contributionDatePicker")
                        }
                        .brandCard()

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Birthday money, side gig…", text: $draft.notes, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(1...3)
                                .accessibilityIdentifier("contributionNotesField")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .brandCard()

                        Text("Savings for \(trip.name) are kept apart from your monthly budget and don't count as spending.")
                            .font(.caption)
                            .foregroundStyle(Brand.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if contribution != nil {
                            Button(role: .destructive, action: delete) {
                                Label("Delete", systemImage: "trash")
                            }
                            .buttonStyle(DestructiveButtonStyle())
                            .accessibilityIdentifier("deleteContributionButton")
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
                    Text(contribution == nil ? "Add to Savings" : "Edit Contribution")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                PlainToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Brand.accentText)
                }
                PlainToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .foregroundStyle(Brand.accentText)
                        .disabled(!draft.isValid(savedExcludingThis: savedExcludingThis, asOf: Date()))
                        .accessibilityIdentifier("saveContributionButton")
                }
            }
            .onAppear { if contribution == nil { amountFocused = true } }
        }
        .tint(Brand.accentText)
    }

    private func save() {
        if let contribution {
            draft.apply(to: contribution)
        } else if draft.insertContribution(for: trip, in: modelContext, createdAt: Date()) == nil {
            return
        }
        try? modelContext.save()
        SavingsReminderCoordinator.shared.syncAll(in: modelContext)
        dismiss()
    }

    private func delete() {
        guard let contribution else { return }
        modelContext.delete(contribution)
        try? modelContext.save()
        SavingsReminderCoordinator.shared.syncAll(in: modelContext)
        dismiss()
    }
}
