import SwiftUI

/// The compact "next trip" card on the Budget dashboard. It only reads trip
/// savings; it never feeds into the budget hero's numbers.
struct UpcomingTripCard: View {
    let trip: Trip
    let plan: SavingsPlan
    /// Other upcoming trips after this one.
    let moreCount: Int
    let onOpen: () -> Void
    let onAdd: () -> Void

    private var code: String { trip.totalCurrencyCode }

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(percentage: plan.progress, lineWidth: 6, tone: .goal) {
                Image(systemName: "airplane")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Brand.accentText)
            }
            .frame(width: 50, height: 50)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Next trip · \(plan.countdownText)")
                    .brandLabel()
                    .accessibilityIdentifier("dashboardTripCountdown")
                Text(trip.name)
                    .font(Brand.display(16, .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .lineLimit(1)
                    .accessibilityIdentifier("dashboardTripName")
                Text(periodText)
                    .font(.caption)
                    .foregroundStyle(plan.isUnrealistic ? Brand.warning : Brand.textSecondary)
                    .lineLimit(2)
                    .accessibilityIdentifier("dashboardTripSavings")
                if moreCount > 0 {
                    Text(moreCount == 1 ? "+1 more upcoming trip" : "+\(moreCount) more upcoming trips")
                        .font(.caption2)
                        .foregroundStyle(Brand.textTertiary)
                }
            }

            Spacer(minLength: 6)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Brand.accentText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Brand.accent.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add to savings for \(trip.name)")
            .accessibilityIdentifier("dashboardAddSavingsButton")
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
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboardTripCard")
    }

    private var periodText: String {
        let saved = plan.saved.formatted(.currency(code: code))
        let goal = plan.goal.formatted(.currency(code: code))
        switch plan.status {
        case .funded:
            return "Fully saved: \(goal)"
        default:
            if plan.periodsLeft == 0 {
                return "\(plan.remaining.formatted(.currency(code: code))) still to save · \(saved) of \(goal)"
            }
            return "Save \(plan.perPeriodAmount.formatted(.currency(code: code))) \(plan.cadence.thisPeriodPhrase) · \(saved) of \(goal)"
        }
    }

    /// The trip the dashboard shows: the soonest that hasn't started yet,
    /// plus how many more come after it. nil when there are none.
    static func pick(from trips: [Trip], asOf date: Date, calendar: Calendar = .current) -> (trip: Trip, more: Int)? {
        let upcoming = TripList.sections(trips, asOf: date, calendar: calendar).upcoming
            .filter { $0.status(asOf: date, calendar: calendar) == .upcoming }
        guard let first = upcoming.first else { return nil }
        return (first, upcoming.count - 1)
    }
}
