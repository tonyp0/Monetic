import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var category: BudgetCategory

    @State private var showingAddTransaction = false
    @State private var showingEditCategory = false
    @State private var showingDeleteConfirm = false
    @State private var selectedTransaction: Transaction?

    private var sortedTransactions: [Transaction] {
        category.transactions.sorted { $0.date > $1.date }
    }

    private var monthlySpent: Double { category.monthlySpending() }
    private var hasLimit: Bool { category.monthlyBudget > 0 }
    private var isOver: Bool { category.isOverBudget() }
    private var hue: Color { CategoryPalette.color(for: category.color) }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, Brand.Space.gutter)
                        .padding(.bottom, 14)

                    if sortedTransactions.isEmpty {
                        emptyState
                    } else {
                        transactionList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(category.name)
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Brand.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showingEditCategory = true }) {
                            Label("Edit Group", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                            Label("Delete Group", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Brand.textSecondary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: { showingAddTransaction = true }) {
                    Label("Add Expense", systemImage: "plus")
                }
                .buttonStyle(GradientButtonStyle())
                .accessibilityIdentifier("addExpenseButton")
                .padding(.horizontal, Brand.Space.gutter)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Brand.background.opacity(0.94).ignoresSafeArea(edges: .bottom))
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView(category: category)
            }
            .sheet(item: $selectedTransaction) { transaction in
                EditTransactionView(transaction: transaction)
            }
            .sheet(isPresented: $showingEditCategory) {
                EditCategoryView(category: category)
            }
            .confirmationDialog(
                "Delete \"\(category.name)\"?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Group & All Expenses", role: .destructive) {
                    modelContext.delete(category)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the group and all \(category.transactions.count) expense\(category.transactions.count == 1 ? "" : "s") inside it.")
            }
        }
        .tint(Brand.accent)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                CategoryTile(icon: category.icon, colorKey: category.color, size: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.name)
                        .font(Brand.display(19, .bold))
                        .foregroundStyle(Brand.textPrimary)
                        .lineLimit(1)
                    Text("\(category.transactions.count) expense\(category.transactions.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Brand.textTertiary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("This Month").brandEyebrow()
                    Text(monthlySpent, format: .currency(code: Currency.code))
                        .accessibilityIdentifier("groupMonthlySpent")
                        .font(Brand.number(20))
                        .foregroundStyle(isOver ? Brand.danger : Brand.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }

            if hasLimit {
                VStack(spacing: 7) {
                    BrandProgressBar(
                        percentage: category.monthlySpendingPercentage(),
                        tint: isOver ? Brand.danger : hue,
                        height: 6
                    )

                    HStack {
                        Text(isOver ? "Over limit" : "Monthly limit")
                            .font(.caption)
                            .foregroundStyle(isOver ? Brand.danger : Brand.textTertiary)
                        Spacer()
                        Text(category.monthlyBudget, format: .currency(code: Currency.code))
                            .font(Brand.number(12, .semibold))
                            .foregroundStyle(Brand.textSecondary)
                    }
                }
            }
        }
        .brandCard()
    }

    // MARK: List

    private var transactionList: some View {
        List {
            ForEach(sortedTransactions) { transaction in
                TransactionRow(transaction: transaction)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTransaction = transaction }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: 4, leading: Brand.Space.gutter,
                        bottom: 4, trailing: Brand.Space.gutter
                    ))
            }
            .onDelete(perform: deleteTransactions)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Brand.textTertiary)
            Text("No expenses yet")
                .font(Brand.display(16, .semibold))
                .foregroundStyle(Brand.textPrimary)
            Text("Everything you log in this group shows up here.")
                .font(.subheadline)
                .foregroundStyle(Brand.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteTransactions(at offsets: IndexSet) {
        Self.deleteTransactions(at: offsets, from: sortedTransactions, in: modelContext)
    }

    /// Deletes swiped rows. `offsets` index into `rows` as displayed.
    static func deleteTransactions(at offsets: IndexSet, from rows: [Transaction], in modelContext: ModelContext) {
        for index in offsets {
            modelContext.delete(rows[index])
        }
        // Until the context saves, the group's `transactions` still includes
        // the deleted rows, so its count and total would lag behind the list.
        try? modelContext.save()
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(transaction.notes.isEmpty ? "Expense" : transaction.notes)
                        .font(Brand.display(15, .medium))
                        .foregroundStyle(Brand.textPrimary)
                        .lineLimit(1)

                    if transaction.isRecurring {
                        Text(transaction.recurringFrequency.capitalized)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                                    .fill(Brand.accent.opacity(0.16))
                            )
                            .foregroundStyle(Brand.accent)
                    }
                }

                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(Brand.textTertiary)
            }

            Spacer(minLength: 8)

            Text(transaction.amount, format: .currency(code: Currency.code))
                .font(Brand.number(16, .semibold))
                .foregroundStyle(Brand.textPrimary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: Brand.Radius.row, style: .continuous)
                .fill(Brand.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.row, style: .continuous)
                .strokeBorder(Brand.hairline, lineWidth: 1)
        )
    }
}
