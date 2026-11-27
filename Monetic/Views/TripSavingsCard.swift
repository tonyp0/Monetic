import SwiftUI
import SwiftData

// MARK: - Status chip

struct SavingsStatusTag: View {
    let status: SavingsPlan.Status

    var body: some View {
        StatusChip(title: status.label, color: tint)
            .accessibilityIdentifier("savingsStatus")
    }

    private var tint: Color {
        switch status {
        case .ahead, .funded: return Brand.positive
        case .onTrack:        return Brand.accent
        case .behind:         return Brand.warning
        case .departed:       return Brand.textSecondary
        }
    }
}

// MARK: - Savings card

/// The savings side of a trip: a ring of saved against the goal, what to put
/// aside each period, the countdown, honest warnings, and recent activity.
struct TripSavingsCard: View {
    let trip: Trip
    let plan: SavingsPlan
    let onAdd: () -> Void
    let onEditPlan: () -> Void
    let onEditTrip: () -> Void
    let onEditContribution: (SavingsContribution) -> Void

    private var code: String { trip.totalCurrencyCode }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Savings plan").brandLabel()
                Spacer()
                SavingsStatusTag(status: plan.status)
                Button(action: onEditPlan) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Brand.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Brand.track))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit savings plan")
                .accessibilityIdentifier("editSavingsPlanButton")
            }

            HStack(spacing: 18) {
                ProgressRing(percentage: plan.progress, lineWidth: 11, tone: .goal) {
                    Text("\(Int((min(plan.progress, 9.99) * 100).rounded()))%")
                        .font(Brand.number(20, .bold))
                        .foregroundStyle(Brand.textPrimary)
                        .accessibilityIdentifier("savingsPercent")
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(plan.saved.formatted(.currency(code: code))) saved of \(plan.goal.formatted(.currency(code: code)))")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("savingsProgressText")

                    Text(plan.perPeriodText(currencyCode: code))
                        .font(Brand.display(14, .medium))
                        .foregroundStyle(Brand.accentText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("savingsPerPeriod")

                    Text(plan.countdownText)
                        .font(.caption)
                        .foregroundStyle(Brand.textSecondary)
                        .accessibilityIdentifier("savingsCountdown")

                    if trip.remindersEnabled && plan.status != .funded && plan.status != .departed {
                        Label("Reminders on", systemImage: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(Brand.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }

            if let catchUp = plan.catchUpAmount, plan.problem == nil {
                note(
                    icon: "arrow.uturn.up",
                    tint: Brand.warning,
                    text: "Put \(catchUp.formatted(.currency(code: code))) aside next time to get back on track."
                )
                .accessibilityIdentifier("savingsCatchUpNote")
            }

            if let problem = plan.problem {
                unrealisticWarning(problem)
            }

            Button(action: onAdd) {
                Label("Add to savings", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("addSavingsButton")

            if !trip.contributions.isEmpty {
                recentActivity
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(padding: 18)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("savingsCard")
    }

    // MARK: Warning

    private func unrealisticWarning(_ problem: SavingsPlan.Problem) -> some View {
        let remaining = plan.remaining.formatted(.currency(code: code))
        let message: String
        switch problem {
        case .noDatesLeft:
            message = "There's no \(plan.cadence.label.lowercased()) savings date left before you leave, and \(remaining) is still to go."
        case .moreThanBudget(let budgetPerPeriod):
            message = "\(plan.perPeriodAmount.formatted(.currency(code: code))) \(plan.cadence.perPeriodPhrase) is more than your whole monthly budget allows (\(budgetPerPeriod.formatted(.currency(code: Currency.code))) \(plan.cadence.perPeriodPhrase))."
        }

        return VStack(alignment: .leading, spacing: 10) {
            note(icon: "exclamationmark.triangle.fill", tint: Brand.danger,
                 text: "\(message) Either set aside more than that, or lower the goal or move the dates.")
            HStack(spacing: 10) {
                Button("Lower the goal", action: onEditPlan)
                    .buttonStyle(SoftButtonStyle())
                    .accessibilityIdentifier("unrealisticEditPlanButton")
                Button("Change dates", action: onEditTrip)
                    .buttonStyle(SoftButtonStyle())
                    .accessibilityIdentifier("unrealisticEditTripButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("savingsUnrealisticWarning")
    }

    private func note(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Brand.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous).fill(tint.opacity(0.12)))
    }

    // MARK: Activity

    private var recentActivity: some View {
        let recent = Array(trip.sortedContributions.prefix(3))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recent").brandLabel()
                Spacer()
                NavigationLink {
                    ContributionsListView(trip: trip)
                } label: {
                    Text(trip.contributions.count > recent.count ? "See all \(trip.contributions.count)" : "Manage")
                        .font(Brand.display(13, .semibold))
                        .foregroundStyle(Brand.accentText)
                }
                .accessibilityIdentifier("seeAllContributionsButton")
            }
            ForEach(recent) { contribution in
                Button { onEditContribution(contribution) } label: {
                    ContributionRow(contribution: contribution, currencyCode: code)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Contribution row

struct ContributionRow: View {
    let contribution: SavingsContribution
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: contribution.isWithdrawal ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(contribution.isWithdrawal ? Brand.warning : Brand.positive)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(contribution.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(Brand.display(14, .medium))
                    .foregroundStyle(Brand.textPrimary)
                if !contribution.notes.isEmpty {
                    Text(contribution.notes)
                        .font(.caption)
                        .foregroundStyle(Brand.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text((contribution.isWithdrawal ? "−" : "+") + abs(contribution.amount).formatted(.currency(code: currencyCode)))
                .font(Brand.number(15, .semibold))
                .foregroundStyle(contribution.isWithdrawal ? Brand.warning : Brand.textPrimary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("contributionRow")
    }
}

// MARK: - Reminder sync from views

extension SavingsReminderCoordinator {
    /// Re-plans reminders for every trip in the store, as of now.
    func syncAll(in context: ModelContext) {
        let trips = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        let infos = trips.map(\.reminderInfo)
        Task { await sync(infos, asOf: Date()) }
    }
}
