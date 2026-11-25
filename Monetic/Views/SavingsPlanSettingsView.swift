import SwiftUI
import SwiftData

/// The savings goal, how often to save, when saving started, and reminders.
struct SavingsPlanSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trip: Trip

    @State private var draft: SavingsPlanDraft
    @State private var permissionDenied = false
    @FocusState private var amountFocused: Bool

    init(trip: Trip) {
        self.trip = trip
        _draft = State(initialValue: SavingsPlanDraft(trip: trip))
    }

    private var code: String { trip.totalCurrencyCode }
    private var share: Double { Trip.defaultSavingsGoal(total: trip.estimatedTotal, travelers: trip.travelers) }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: Brand.Space.stack) {
                        VStack(alignment: .leading, spacing: 8) {
                            AmountEntryCard(amount: $draft.goalText, focus: $amountFocused, label: "Savings goal")
                            HStack {
                                Text(trip.travelers == 1
                                     ? "The trip's total is \(share.formatted(.currency(code: code)))."
                                     : "Your share of the trip is \(share.formatted(.currency(code: code))) (the total split \(trip.travelers) ways).")
                                    .font(.caption)
                                    .foregroundStyle(Brand.textTertiary)
                                if AmountInput.cents(draft.goalText) != Int((share * 100).rounded()) {
                                    Spacer()
                                    Button("Use share") {
                                        draft.goalText = AmountInput.text(cents: Int((share * 100).rounded()))
                                    }
                                    .font(Brand.display(13, .semibold))
                                    .foregroundStyle(Brand.accent)
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Save").brandEyebrow()
                            BrandSegmented(
                                options: ContributionCadence.allCases.map { ($0.rawValue, $0.label) },
                                selection: Binding(
                                    get: { draft.cadence.rawValue },
                                    set: { draft.cadence = ContributionCadence(rawValue: $0) ?? .weekly }
                                )
                            )
                            .accessibilityIdentifier("cadencePicker")
                        }
                        .brandCard()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Saving since").brandEyebrow()
                                Spacer()
                                DatePicker("Saving since", selection: $draft.startDate, in: ...trip.startDate,
                                           displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(Brand.accent)
                                    .accessibilityIdentifier("savingsStartDatePicker")
                            }
                            Text("Contributions fall on this day every \(draft.cadence == .monthly ? "month" : draft.cadence == .weekly ? "week" : "2 weeks"), and on-track is measured from it.")
                                .font(.caption)
                                .foregroundStyle(Brand.textTertiary)
                        }
                        .brandCard()

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: Binding(
                                get: { draft.remindersEnabled },
                                set: { turnOn in
                                    if turnOn { enableReminders() } else { draft.remindersEnabled = false }
                                }
                            )) {
                                Text("Remind me on savings days")
                                    .font(Brand.display(15, .medium))
                                    .foregroundStyle(Brand.textPrimary)
                            }
                            .tint(Brand.accent)
                            .accessibilityIdentifier("savingsRemindersToggle")

                            Text(permissionDenied
                                 ? "Notifications are off for Monetic. Turn them on in the Settings app to get reminders."
                                 : "A notification at 9 a.m. on each savings day until the goal is reached.")
                                .font(.caption)
                                .foregroundStyle(permissionDenied ? Brand.warning : Brand.textTertiary)
                        }
                        .brandCard()
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
                    Text("Savings Plan")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Brand.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .font(Brand.display(15, .semibold))
                        .foregroundStyle(Brand.accent)
                        .disabled(!draft.isValid(departure: trip.startDate))
                        .accessibilityIdentifier("saveSavingsPlanButton")
                }
            }
        }
        .tint(Brand.accent)
    }

    /// Permission is asked for here, when the user turns reminders on, and
    /// nowhere else.
    private func enableReminders() {
        draft.remindersEnabled = true
        Task {
            let granted = await SavingsReminderCoordinator.shared.requestPermission()
            permissionDenied = !granted
            if !granted { draft.remindersEnabled = false }
        }
    }

    private func save() {
        guard draft.apply(to: trip) else { return }
        try? modelContext.save()
        SavingsReminderCoordinator.shared.syncAll(in: modelContext)
        dismiss()
    }
}
