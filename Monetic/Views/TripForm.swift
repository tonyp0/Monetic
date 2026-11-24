import SwiftUI

/// The fields shared by Add Trip and Edit Trip. Validation lives on
/// `TripDraft`; this only lays the draft out.
struct TripForm: View {
    @Binding var draft: TripDraft
    var focusNameOnAppear: Bool = false

    private enum Field: Hashable { case name, destination }
    @FocusState private var focusedField: Field?
    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(spacing: Brand.Space.stack) {
            BrandField(label: "Trip Name") {
                TextField("e.g. Spring Break 2027", text: $draft.name)
                    .font(Brand.display(16, .medium))
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .destination }
                    .accessibilityIdentifier("tripNameField")
            }

            BrandField(label: "Destination") {
                TextField("e.g. Cancún, Mexico", text: $draft.destination)
                    .font(Brand.display(16, .medium))
                    .focused($focusedField, equals: .destination)
                    .submitLabel(.done)
                    .accessibilityIdentifier("tripDestinationField")
            }

            datesCard
            travelersCard

            AmountEntryCard(amount: $draft.amountText, focus: $amountFocused, label: "Estimated Total")

            notesCard
        }
        .onAppear {
            if focusNameOnAppear { focusedField = .name }
        }
    }

    // MARK: Dates

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Leaving").brandEyebrow()
                Spacer()
                DatePicker("Leaving", selection: $draft.startDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Brand.accent)
                    .accessibilityIdentifier("tripStartDatePicker")
            }

            Rectangle().fill(Brand.hairline).frame(height: 1)

            HStack {
                Text("Returning").brandEyebrow()
                Spacer()
                DatePicker("Returning", selection: $draft.endDate, in: draft.startDate..., displayedComponents: .date)
                    .labelsHidden()
                    .tint(Brand.accent)
                    .accessibilityIdentifier("tripEndDatePicker")
            }

            Text(TripList.nightsText(draft.nights()))
                .font(.caption)
                .foregroundStyle(Brand.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .onChange(of: draft.startDate) { _, _ in
            draft.startDateChanged()
        }
    }

    // MARK: Travelers

    private var travelersCard: some View {
        BrandStepper(
            title: "Travelers",
            value: $draft.travelers,
            range: TripDraft.travelerRange,
            unit: ("traveler", "travelers")
        )
        .accessibilityIdentifier("tripTravelersStepper")
        .brandCard()
    }

    // MARK: Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").brandEyebrow()
            TextField("Flights, where you're staying, who's going…", text: $draft.notes, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
