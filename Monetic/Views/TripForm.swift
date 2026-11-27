import SwiftUI
import SwiftData

/// The fields shared by Add Trip and Edit Trip. Validation lives on
/// `TripDraft`; this only lays the draft out.
struct TripForm: View {
    @Binding var draft: TripDraft
    var focusNameOnAppear: Bool = false
    /// The bundled per diem data; nil leaves the form as a typed-in total.
    var store: CostDataStore? = CostDataStore.shared
    /// What "Describe your trip" filled in; those fields are marked until edited.
    var fill: TripAssistant.Fill? = nil

    /// Past trips, for the "your trips ran over" hint.
    @Query private var trips: [Trip]
    @AppStorage("dismissedEstimateHints") private var dismissedHints = ""

    private enum Field: Hashable { case name, destination, flights }
    @FocusState private var focusedField: Field?
    @FocusState private var amountFocused: Bool

    private var pickedLocation: CostLocation? {
        draft.locationID.flatMap { store?.location(id: $0) }
    }

    private var estimate: TripEstimate? {
        draft.estimate(location: pickedLocation)
    }

    /// How hotel prices at the picked place compare in the trip's month: the
    /// month of the middle night, so a trip over a month's end goes by
    /// where most of it falls.
    private var seasonalHint: String? {
        guard let index = pickedLocation?.activeSeasonalIndex else { return nil }
        let calendar = Calendar.current
        let middle = calendar.date(byAdding: .day, value: draft.nights() / 2, to: draft.startDate) ?? draft.startDate
        return TripEstimator.seasonalHint(index, month: calendar.component(.month, from: middle))
    }

    private var searchResults: [CostLocation] {
        guard let store, pickedLocation == nil else { return [] }
        return store.search(draft.destination, limit: 5)
    }

    var body: some View {
        let estimate = self.estimate

        VStack(spacing: Brand.Space.stack) {
            BrandField(label: "Trip name") {
                TextField("e.g. Spring Break 2027", text: $draft.name)
                    .font(Brand.display(16, .medium))
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .destination }
                    .accessibilityIdentifier("tripNameField")
            }
            .overlay(alignment: .topTrailing) { filledMark(fill?.name != nil && fill?.name == draft.name, id: "name") }

            destinationSection

            datesCard
            travelersCard

            if let estimate {
                styleCard
                roomsCard
                flightsField
                TripBreakdownCard(estimate: estimate)
                if let hint = accuracyHint {
                    hintRow(hint)
                }
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
            .overlay(alignment: .topTrailing) {
                filledMark(fill?.destination != nil && fill?.destination == draft.destination, id: "destination")
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
            } else if focusedField == .destination || showFilledMatches, !searchResults.isEmpty {
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

    /// The description named a place with several matches: list them
    /// until the user picks one or changes the text.
    private var showFilledMatches: Bool {
        (fill?.destinationIsAmbiguous ?? false) && fill?.destination == draft.destination
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
                            .foregroundStyle(Brand.accentText)
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
            HStack {
                Text("Travel style").brandLabel()
                Spacer()
                filledMark(fill?.style != nil && fill?.style == draft.travelStyle, id: "style")
            }
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
                        .foregroundStyle(Brand.accentText)
                        .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var flightsField: some View {
        VStack(alignment: .trailing, spacing: 6) {
            flightsInput
            if let said = fill?.flightsText, said == draft.flightsText,
               let amount = AmountInput.parse(said) {
                BrandTag(text: "You said \(amount.formatted(.currency(code: "USD")))", tint: Brand.textSecondary)
                    .accessibilityIdentifier("filledMark_flights")
            }
        }
    }

    private var flightsInput: some View {
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
                        draft.flightsText = AmountInput.sanitize(newValue, code: "USD")
                    }
                    .accessibilityIdentifier("flightsField")
            }
        }
    }

    // MARK: Total

    @ViewBuilder
    private func totalSection(_ estimate: TripEstimate?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // A total that follows the estimate is in USD; one typed over
            // it is a manual total in the user's currency.
            AmountEntryCard(amount: $draft.amountText, focus: $amountFocused,
                            label: estimate == nil ? "Estimated total" : "Trip total",
                            currencyCode: draft.isUsingEstimate(estimate) ? "USD" : Currency.code)

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
                        .foregroundStyle(Brand.accentText)
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
                Text("Leaving").brandLabel()
                Spacer()
                DatePicker("Leaving", selection: $draft.startDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Brand.accentText)
                    .accessibilityIdentifier("tripStartDatePicker")
            }

            Rectangle().fill(Brand.hairline).frame(height: 1)

            HStack {
                Text("Returning").brandLabel()
                Spacer()
                DatePicker("Returning", selection: $draft.endDate, in: draft.startDate..., displayedComponents: .date)
                    .labelsHidden()
                    .tint(Brand.accentText)
                    .accessibilityIdentifier("tripEndDatePicker")
            }

            HStack {
                Text(TripList.nightsText(draft.nights()))
                    .font(.caption)
                    .foregroundStyle(Brand.textTertiary)
                Spacer()
                filledMark(fill?.startDate != nil && fill?.startDate == draft.startDate
                           && fill?.endDate == draft.endDate, id: "dates")
            }

            if let hint = seasonalHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Brand.textSecondary)
                    .accessibilityIdentifier("seasonalHint")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .onChange(of: draft.startDate) { _, _ in
            draft.startDateChanged()
        }
    }

    // MARK: Travelers

    private var travelersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            BrandStepper(
                title: "Travelers",
                value: $draft.travelers,
                range: TripDraft.travelerRange,
                unit: ("traveler", "travelers")
            )
            .accessibilityIdentifier("tripTravelersStepper")
            filledMark(fill?.travelers != nil && fill?.travelers == draft.travelers, id: "travelers")
        }
        .brandCard()
    }

    // MARK: How past estimates did

    /// Shown, never applied: the estimate itself doesn't change.
    private var accuracyHint: EstimateAccuracy.Hint? {
        let hint = EstimateAccuracy.hint(for: draft.travelStyle, samples: trips.compactMap(\.accuracySample))
        guard let hint, !dismissedHints.split(separator: ",").contains(Substring(hint.id)) else { return nil }
        return hint
    }

    private func hintRow(_ hint: EstimateAccuracy.Hint) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(Brand.accentText)
                .accessibilityHidden(true)
            Text(hint.text)
                .font(.caption)
                .foregroundStyle(Brand.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("estimateAccuracyHint")
            Button {
                dismissedHints = (dismissedHints.isEmpty ? "" : dismissedHints + ",") + hint.id
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Brand.textTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityIdentifier("dismissEstimateHint")
        }
        .brandCard(padding: 12, radius: Brand.Radius.control)
    }

    // MARK: Filled from the description

    /// A small tag on a field the assistant filled, so it's clear what to
    /// check. Gone once the user changes the value.
    @ViewBuilder
    private func filledMark(_ isFilled: Bool, id: String) -> some View {
        if isFilled {
            HStack(spacing: 4) {
                Image(systemName: "sparkles").accessibilityHidden(true)
                Text("From your description")
            }
            .font(Brand.display(11, .semibold))
            .foregroundStyle(Brand.accentText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Brand.accent.opacity(0.14)))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("filledMark_\(id)")
        }
    }

    // MARK: Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Flights, where you're staying, who's going…", text: $draft.notes, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
