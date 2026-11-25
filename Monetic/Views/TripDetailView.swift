import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let trip: Trip

    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var showingAddSavings = false
    @State private var showingPlanSettings = false
    @State private var editingContribution: SavingsContribution?

    var body: some View {
        ZStack {
            BrandBackground()

            ScrollView {
                VStack(spacing: Brand.Space.stack) {
                    headerCard

                    if let estimate = trip.savedEstimate {
                        TripBreakdownCard(
                            estimate: estimate,
                            editedTotal: trip.estimateSource == Trip.EstimateSource.perDiem.rawValue
                                ? nil : trip.estimatedTotal,
                            editedCurrencyCode: trip.totalCurrencyCode
                        )
                    }

                    if !trip.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        notesCard
                    }

                    TripSavingsCard(
                        trip: trip,
                        plan: trip.savingsPlan(asOf: Date(), monthlyBudget: monthlyBudget),
                        onAdd: { showingAddSavings = true },
                        onEditPlan: { showingPlanSettings = true },
                        onEditTrip: { showingEdit = true },
                        onEditContribution: { editingContribution = $0 }
                    )

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Trip", systemImage: "trash")
                    }
                    .buttonStyle(DestructiveButtonStyle())
                    .accessibilityIdentifier("deleteTripButton")
                    .padding(.top, 4)
                }
                .padding(.horizontal, Brand.Space.gutter)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(trip.name)
                    .font(Brand.display(16, .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
                    .font(Brand.display(15, .medium))
                    .foregroundStyle(Brand.accent)
                    .accessibilityIdentifier("editTripButton")
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditTripView(trip: trip)
        }
        .sheet(isPresented: $showingAddSavings) {
            AddContributionView(trip: trip)
        }
        .sheet(isPresented: $showingPlanSettings) {
            SavingsPlanSettingsView(trip: trip)
        }
        .sheet(item: $editingContribution) { contribution in
            AddContributionView(trip: trip, contribution: contribution)
        }
        .confirmationDialog("Delete this trip?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Header

    private var headerCard: some View {
        let now = Date()

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(trip.destination)
                }
                .brandEyebrow()

                Text(TripList.dateRangeText(start: trip.startDate, end: trip.endDate))
                    .font(Brand.display(20, .bold))
                    .foregroundStyle(Brand.textPrimary)

                Text("\(TripList.nightsText(trip.nights())) · \(TripList.countdownText(for: trip, asOf: now))")
                    .font(Brand.display(14, .medium))
                    .foregroundStyle(Brand.textSecondary)
                    .accessibilityIdentifier("tripDetailCountdown")
            }

            Rectangle().fill(Brand.hairline).frame(height: 1)

            HStack(spacing: 0) {
                stat(label: "Estimated total", value: trip.estimatedTotal, identifier: "tripTotal")

                Rectangle()
                    .fill(Brand.hairline)
                    .frame(width: 1, height: 34)

                stat(
                    label: trip.travelers == 1 ? "Per person" : "Each, for \(trip.travelers)",
                    value: trip.perPersonTotal,
                    identifier: "tripPerPersonTotal"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(padding: 20)
    }

    private func stat(label: String, value: Double, identifier: String) -> some View {
        VStack(spacing: 4) {
            Text(label).brandEyebrow()
            Text(value, format: .currency(code: trip.totalCurrencyCode))
                .font(Brand.number(20, .semibold))
                .foregroundStyle(Brand.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").brandEyebrow()
            Text(trip.notes)
                .font(.subheadline)
                .foregroundStyle(Brand.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    // MARK: Delete

    private func delete() {
        modelContext.delete(trip)
        try? modelContext.save()
        SavingsReminderCoordinator.shared.syncAll(in: modelContext)
        dismiss()
    }
}
