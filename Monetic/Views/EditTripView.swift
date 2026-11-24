import SwiftUI
import SwiftData

struct EditTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let trip: Trip

    @State private var draft: TripDraft

    init(trip: Trip) {
        self.trip = trip
        _draft = State(initialValue: TripDraft(trip: trip))
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
        guard draft.apply(to: trip) else { return }
        // Saved explicitly, like EditTransactionView, so the edit is committed
        // before the sheet dismisses.
        try? modelContext.save()
        dismiss()
    }
}
