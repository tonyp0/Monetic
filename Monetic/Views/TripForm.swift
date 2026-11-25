import SwiftUI

/// The fields shared by Add Trip and Edit Trip. Validation lives on
/// `TripDraft`; this only lays the draft out.
struct TripForm: View {
    @Binding var draft: TripDraft
    var focusNameOnAppear: Bool = false
    /// The bundled per diem data; nil leaves the form as a typed-in total.
    var store: CostDataStore? = CostDataStore.shared

    private enum Field: Hashable { case name, destination, flights }
    @FocusState private var focusedField: Field?
    @FocusState private var amountFocused: Bool

    private var pickedLocation: CostLocation? {
        draft.locationID.flatMap { store?.location(id: $0) }
    }

    private var estimate: TripEstimate? {
        draft.estimate(location: pickedLocation)
    }

    private var searchResults: [CostLocation] {
        guard let store, pickedLocation == nil else { return [] }
        return store.search(draft.destination, limit: 5)
    }

    var body: some View {
        let estimate = self.estimate

        VStack(spacing: Brand.Space.stack) {
            BrandField(label: "Trip Name") {
                TextField("e.g. Spring Break 2027", text: $draft.name)
                    .font(Brand.display(16, .medium))
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .destination }
                    .accessibilityIdentifier("tripNameField")
            }

            destinationSection

            datesCard
            travelersCard

            if let estimate {
                styleCard
                roomsCard
                flightsField
                TripBreakdownCard(estimate: estimate)
            }

            totalSection(estimate)

            notesCard
        }
        .onAppear {
            if focusNameOnAppear { focusedField = .name }
        }
        .onChange(of: estimate) { old, new in
            draft.estimateChanged(from: old, to: new)
        }
        .onChange(of: draft.destination) { _, _ in
            draft.destinationEdited(pickedName: pickedLocation?.displayName)
        }
    }

    // MARK: Destination

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            BrandField(label: "Destination") {
                TextField("Search a city, e.g. Cancún", text: $draft.destination)
                    .font(Brand.display(16, .medium))
                    .focused($focusedField, equals: .destination)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .accessibilityIdentifier("tripDestinationField")
            }

            if let picked = pickedLocation {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Brand.positive)
                        .accessibilityHidden(true)
                    Text("Using per diem rates for \(picked.displayName)")
                        .foregroundStyle(Brand.textSecondary)
                }
                .font(.caption)
                .accessibilityIdentifier("pickedLocationNote")
            } else if focusedField == .destination, !searchResults.isEmpty {
                resultsList
            } else if store != nil, !draft.trimmedDestination.isEmpty {
                Text(searchResults.isEmpty
                     ? "No rates for this place. Enter your own total below."
                     : "Pick a match to get an estimate, or enter your own total below.")
                    .font(.caption)
                    .foregroundStyle(Brand.textTertiary)
                    .accessibilityIdentifier("noLocationMatchNote")
            }
        }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, location in
                if index > 0 {
                    Rectangle().fill(Brand.hairline).frame(height: 1)
                }
                Button {
                    draft.select(location)
                    focusedField = nil
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Brand.accent)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name)
                                .font(Brand.display(15, .medium))
                                .foregroundStyle(Brand.textPrimary)
                            Text(location.regionName.map { "\($0), \(location.country)" } ?? location.country)
                                .font(.caption)
                                .foregroundStyle(Brand.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("destinationResult_\(location.id)")
            }
        }
        .brandCard(padding: 12, radius: Brand.Radius.control)
    }

    // MARK: Estimator inputs

    private var styleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Travel Style").brandEyebrow()
            BrandSegmented(
                options: TravelStyle.allCases.map { ($0.rawValue, $0.label) },
                selection: Binding(
                    get: { draft.travelStyle.rawValue },
                    set: { draft.travelStyle = TravelStyle(rawValue: $0) ?? .standard }
                )
            )
            Text("Assumption: \(draft.travelStyle.assumptions.summary)")
                .font(.caption)
                .foregroundStyle(Brand.textTertiary)
                .accessibilityIdentifier("styleAssumptionNote")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var roomsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandStepper(
                title: "Rooms",
                value: Binding(get: { draft.rooms }, set: { draft.roomsOverride = $0 }),
                range: 1...max(draft.travelers, 1),
                unit: ("room", "rooms")
            )
            .accessibilityIdentifier("roomsStepper")

            HStack(spacing: 8) {
                let perRoom = draft.travelStyle.assumptions.peoplePerRoom
                Text(draft.roomsOverride == nil
                     ? "Assumption: \(perRoom == 1 ? "a room per traveler" : "\(perRoom) people share a room") for \(draft.travelStyle.label.lowercased()) trips."
                     : "You set the rooms. Lodging is priced per room.")
                    .font(.caption)
                    .foregroundStyle(Brand.textTertiary)
                if draft.roomsOverride != nil {
                    Spacer()
                    Button("Reset") { draft.roomsOverride = nil }
                        .font(Brand.display(13, .semibold))
                        .foregroundStyle(Brand.accent)
                        .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var flightsField: some View {
        BrandField(
            label: "Flights (total for group)",
            footnote: "Paste a fare you found for everyone going. Leave it empty if you haven't looked yet."
        ) {
            HStack(spacing: 6) {
                Text("USD")
                    .font(Brand.display(13, .semibold))
                    .foregroundStyle(Brand.textSecondary)
                TextField("0.00", text: $draft.flightsText)
                    .font(Brand.display(16, .medium))
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .flights)
                    .onChange(of: draft.flightsText) { _, newValue in
                        draft.flightsText = AmountInput.sanitize(newValue)
                    }
                    .accessibilityIdentifier("flightsField")
            }
        }
    }

    // MARK: Total

    @ViewBuilder
    private func totalSection(_ estimate: TripEstimate?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AmountEntryCard(amount: $draft.amountText, focus: $amountFocused,
                            label: estimate == nil ? "Estimated Total" : "Trip Total")

            if let estimate {
                if draft.isUsingEstimate(estimate) {
                    Text("From the estimate. Type a different amount to use your own.")
                        .font(.caption)
                        .foregroundStyle(Brand.textTertiary)
                } else {
                    HStack(spacing: 8) {
                        BrandTag(text: "Edited by you")
                            .accessibilityIdentifier("editedByYouTag")
                        Spacer()
                        Button("Use estimate (\(estimate.total.formatted(.currency(code: "USD"))))") {
                            draft.useEstimate(estimate)
                        }
                        .font(Brand.display(13, .semibold))
                        .foregroundStyle(Brand.accent)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("useEstimateButton")
                    }
                }
            }
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
