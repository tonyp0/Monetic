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

    private var monthlySpent: Double {
        category.monthlySpending()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 16) {
                    CategoryIcon(icon: category.icon, color: category.color, size: 36, frame: 64)
                        .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(category.transactions.count) expense\(category.transactions.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("This Month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(monthlySpent, format: .currency(code: Currency.code))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))

                // List
                if sortedTransactions.isEmpty {
                    ContentUnavailableView(
                        "No Expenses Yet",
                        systemImage: "tray",
                        description: Text("Tap \"Add Expense\" to record your first expense")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sortedTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedTransaction = transaction }
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }
                        .onDelete(perform: deleteTransactions)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showingEditCategory = true }) {
                            Label("Edit Name & Emoji", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                            Label("Delete Group", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: { showingAddTransaction = true }) {
                    Label("Add Expense", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(Color(.systemGroupedBackground))
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
    }

    private func deleteTransactions(at offsets: IndexSet) {
        let sorted = sortedTransactions
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(transaction.notes.isEmpty ? "Expense" : transaction.notes)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if transaction.isRecurring {
                        Text(transaction.recurringFrequency.capitalized)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(transaction.amount, format: .currency(code: Currency.code))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 2)
    }
}
