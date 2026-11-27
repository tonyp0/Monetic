import SwiftUI
import SwiftData

/// Every contribution to a trip, newest first. Swipe to edit or delete.
struct ContributionsListView: View {
    @Environment(\.modelContext) private var modelContext
    let trip: Trip

    @State private var editing: SavingsContribution?
    @State private var adding = false

    var body: some View {
        let contributions = trip.sortedContributions

        ZStack {
            BrandBackground()

            List {
                HStack {
                    Text("Saved").brandLabel()
                    Spacer()
                    Text(trip.totalSaved, format: .currency(code: trip.totalCurrencyCode))
                        .font(Brand.number(17, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                .brandCard()
                .padding(.top, 4)
                .brandListRow(vertical: 5)

                if contributions.isEmpty {
                    Text("Nothing put aside yet.")
                        .font(.subheadline)
                        .foregroundStyle(Brand.textSecondary)
                        .brandListRow(vertical: 10)
                }

                ForEach(contributions) { contribution in
                    Button { editing = contribution } label: {
                        ContributionRow(contribution: contribution, currencyCode: trip.totalCurrencyCode)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: Brand.Radius.row, style: .continuous)
                                    .fill(Brand.surface)
                            )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { delete(contribution) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { editing = contribution } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(Brand.accent)
                    }
                    .brandListRow(vertical: 4)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Savings")
                    .font(Brand.display(16, .semibold))
                    .foregroundStyle(Brand.textPrimary)
            }
            PlainToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Brand.accentText)
                }
                .accessibilityLabel("Add to savings")
            }
        }
        .sheet(item: $editing) { contribution in
            AddContributionView(trip: trip, contribution: contribution)
        }
        .sheet(isPresented: $adding) {
            AddContributionView(trip: trip)
        }
    }

    private func delete(_ contribution: SavingsContribution) {
        modelContext.delete(contribution)
        try? modelContext.save()
        SavingsReminderCoordinator.shared.syncAll(in: modelContext)
    }
}
