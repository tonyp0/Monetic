import SwiftUI
import SwiftData

struct EditTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let trip: Trip

    @State private var draft: TripDraft

    init(trip: Trip) {
        self.trip = trip
        var draft = TripDraft(trip: trip)
        // A trip that saved the estimate keeps following it: refresh it
        // from today's data so the total and breakdown agree.
        if let location = trip.locationID.flatMap({ CostDataStore.shared?.location(id: $0) }) {
            draft = TripDraft(trip: trip, estimate: draft.estimate(location: location))
        }
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    TripForm(draft: $draft)
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
                    Text("Edit Trip")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Brand.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(Brand.display(15, .semibold))
                        .foregroundStyle(Brand.accent)
                        .disabled(!draft.isValid())
                        .accessibilityIdentifier("saveTripButton")
                }
            }
        }
        .tint(Brand.accent)
    }

    private func save() {
        let location = draft.locationID.flatMap { CostDataStore.shared?.location(id: $0) }
        guard draft.apply(to: trip, estimate: draft.estimate(location: location)) else { return }
        // Saved explicitly, like EditTransactionView, so the edit is committed
        // before the sheet dismisses.
        try? modelContext.save()
        // New dates or a new goal change the savings dates and amounts.
        SavingsReminderCoordinator.shared.syncAll(in: modelContext)
        dismiss()
    }
}
