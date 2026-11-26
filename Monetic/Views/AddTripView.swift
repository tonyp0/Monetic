import SwiftUI
import SwiftData

struct AddTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft = TripDraft.new()

    // "Describe your trip". The extractor is nil when the on-device model
    // isn't available, and then only the normal form shows.
    @State private var extractor: (any TripIntentExtracting)? = TripAssistant.makeExtractor()
    @State private var description = ""
    @State private var fill: TripAssistant.Fill?
    @State private var isReading = false
    @State private var readFailed = false
    @FocusState private var describeFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: Brand.Space.stack) {
                        if extractor != nil { describeCard }
                        TripForm(draft: $draft, focusNameOnAppear: extractor == nil, fill: fill)
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

    // MARK: Describe your trip

    private var describeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandField(label: "Describe your trip") {
                TextField("Spring break in Cancún with 4 friends, cheap, March 14–21",
                          text: $description, axis: .vertical)
                    .font(Brand.display(15, .medium))
                    .lineLimit(2...4)
                    .submitLabel(.go)
                    .focused($describeFocused)
                    .onSubmit(read)
                    .accessibilityIdentifier("describeTripField")
            }

            Button(action: read) {
                HStack(spacing: 8) {
                    if isReading {
                        ProgressView().tint(Brand.accent)
                    } else {
                        Image(systemName: "sparkles").accessibilityHidden(true)
                    }
                    Text(isReading ? "Reading…" : "Fill in the form")
                }
            }
            .buttonStyle(SoftButtonStyle())
            .disabled(isReading || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("fillFromDescriptionButton")

            if readFailed {
                Text("Couldn't read that, fill it in below.")
                    .font(.caption)
                    .foregroundStyle(Brand.warning)
                    .accessibilityIdentifier("describeTripFailed")
            }
            ForEach(fill?.problems ?? [], id: \.self) { problem in
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(Brand.warning)
            }

            Text("Read on this iPhone with Apple Intelligence. Costs come from government rates and what you type, never from AI. Check the form before saving.")
                .font(.caption)
                .foregroundStyle(Brand.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    /// Reads the description and fills the form. On any failure the form is
    /// left exactly as it was.
    private func read() {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let extractor, !text.isEmpty, !isReading else { return }
        describeFocused = false   // so the filled form isn't hidden under the keyboard
        isReading = true
        readFailed = false
        Task {
            defer { isReading = false }
            let today = Date()
            guard let intent = try? await TripAssistant.extract(text, using: extractor, today: today) else {
                readFailed = true
                return
            }
            var updated = draft
            let result = TripAssistant.apply(intent, text: text, to: &updated, store: CostDataStore.shared, today: today)
            guard !result.isEmpty else {
                readFailed = true
                fill = TripAssistant.Fill(problems: result.problems)
                return
            }
            draft = updated
            fill = result
        }
    }

    private func save() {
        let location = draft.locationID.flatMap { CostDataStore.shared?.location(id: $0) }
        guard let trip = draft.makeTrip(estimate: draft.estimate(location: location)) else { return }
        modelContext.insert(trip)
        // Saved explicitly, like the other add screens, so the new trip is
        // committed before the sheet dismisses instead of waiting on autosave.
        try? modelContext.save()
        dismiss()
    }
}
