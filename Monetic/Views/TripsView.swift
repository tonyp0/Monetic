import SwiftUI
import SwiftData

/// The Trips tab: upcoming trips, soonest first, then past trips folded away.
struct TripsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]

    @State private var showingAddTrip = false
    @State private var selectedTrip: Trip?
    @State private var tripPendingDeletion: Trip?
    @State private var pastExpanded = false

    var body: some View {
        let sections = TripList.sections(trips)
        let now = Date()

        NavigationStack {
            ZStack {
                BrandBackground()

                List {
                    if sections.upcoming.isEmpty {
                        BrandEmptyStateCard(
                            systemImage: "airplane.departure",
                            title: trips.isEmpty ? "No trips yet" : "No upcoming trips",
                            message: "Plan a trip to see what it'll cost and how long you have to save.",
                            actionTitle: "Plan a trip",
                            actionIdentifier: "planTripButton",
                            action: { showingAddTrip = true }
                        )
                        .padding(.top, 4)
                        .brandListRow(vertical: 5)
                    } else {
                        BrandSectionHeader(title: "Upcoming") { EmptyView() }
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                            .brandListRow()

                        ForEach(sections.upcoming) { trip in
                            row(for: trip, asOf: now)
                        }
                    }

                    if !sections.past.isEmpty {
                        pastHeader(count: sections.past.count)
                            .brandListRow()

                        if pastExpanded {
                            ForEach(sections.past) { trip in
                                row(for: trip, asOf: now)
                            }
                        }
                    }

                    Color.clear
                        .frame(height: 24)
                        .brandListRow(vertical: 0)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 0)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Trips")
                        .font(Brand.display(17, .bold))
                        .foregroundStyle(Brand.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddTrip = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Brand.accent)
                    }
                    .accessibilityLabel("Add Trip")
                    .accessibilityIdentifier("addTripButton")
                }
            }
            .navigationDestination(item: $selectedTrip) { trip in
                TripDetailView(trip: trip)
            }
            .sheet(isPresented: $showingAddTrip) {
                AddTripView()
            }
            .confirmationDialog(
                "Delete this trip?",
                isPresented: Binding(
                    get: { tripPendingDeletion != nil },
                    set: { if !$0 { tripPendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: tripPendingDeletion
            ) { trip in
                Button("Delete \(trip.name)", role: .destructive) { delete(trip) }
                Button("Cancel", role: .cancel) {}
            }
        }
        .tint(Brand.accent)
    }

    private func row(for trip: Trip, asOf now: Date) -> some View {
        Button { selectedTrip = trip } label: {
            TripRow(trip: trip, asOf: now)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tripRow_\(trip.name)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                tripPendingDeletion = trip
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .brandListRow(vertical: 5)
    }

    private func pastHeader(count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { pastExpanded.toggle() }
        } label: {
            BrandSectionHeader(title: "Past trips") {
                HStack(spacing: 8) {
                    Text("\(count)")
                        .font(Brand.display(13, .semibold))
                        .foregroundStyle(Brand.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Brand.textSecondary)
                        .rotationEffect(.degrees(pastExpanded ? 0 : -90))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(pastExpanded ? "Expanded" : "Collapsed")
        .accessibilityIdentifier("pastTripsHeader")
        .padding(.top, 18)
        .padding(.bottom, 2)
    }

    private func delete(_ trip: Trip) {
        if selectedTrip?.id == trip.id { selectedTrip = nil }
        modelContext.delete(trip)
        try? modelContext.save()
        tripPendingDeletion = nil
    }
}

// MARK: - Trip Row

struct TripRow: View {
    let trip: Trip
    let asOf: Date

    private var status: Trip.Status { trip.status(asOf: asOf) }

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Brand.accent.opacity(status == .past ? 0.06 : 0.14))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: status == .past ? "checkmark" : "airplane")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(status == .past ? Brand.textTertiary : Brand.accent)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.name)
                    .font(Brand.display(15, .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .lineLimit(1)

                Text(trip.destination)
                    .font(.caption)
                    .foregroundStyle(Brand.textSecondary)
                    .lineLimit(1)

                Text(TripList.dateRangeText(start: trip.startDate, end: trip.endDate))
                    .font(.caption)
                    .foregroundStyle(Brand.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(trip.estimatedTotal, format: .currency(code: trip.totalCurrencyCode))
                    .font(Brand.number(16, .semibold))
                    .foregroundStyle(status == .past ? Brand.textSecondary : Brand.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(TripList.countdownText(for: trip, asOf: asOf))
                    .font(Brand.display(12, .semibold))
                    .foregroundStyle(countdownTint)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Brand.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: Brand.Radius.row, style: .continuous)
                .fill(Brand.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.row, style: .continuous)
                .strokeBorder(Brand.hairline, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var countdownTint: Color {
        switch status {
        case .upcoming:   return Brand.accent
        case .inProgress: return Brand.positive
        case .past:       return Brand.textTertiary
        }
    }
}
