import SwiftUI
import SwiftData

struct AddTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft = TripDraft.new()

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    TripForm(draft: $draft, focusNameOnAppear: true)
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
                    Text("New Trip")
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
        guard let trip = draft.makeTrip() else { return }
        modelContext.insert(trip)
        // Saved explicitly, like the other add screens, so the new trip is
        // committed before the sheet dismisses instead of waiting on autosave.
        try? modelContext.save()
        dismiss()
    }
}
