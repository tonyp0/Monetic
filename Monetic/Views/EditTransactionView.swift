import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var transaction: Transaction

    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var isRecurring: Bool = false
    @State private var recurringFrequency: String = "monthly"
    @State private var showingDeleteConfirm = false
    @FocusState private var amountFocused: Bool

    init(transaction: Transaction) {
        self.transaction = transaction
        _amount             = State(initialValue: String(format: "%.2f", transaction.amount))
        _date               = State(initialValue: transaction.date)
        _notes              = State(initialValue: transaction.notes)
        _isRecurring        = State(initialValue: transaction.isRecurring)
        _recurringFrequency = State(initialValue: transaction.recurringFrequency.isEmpty ? "monthly" : transaction.recurringFrequency)
    }

    private var isValid: Bool {
        (AmountInput.parse(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: Brand.Space.stack) {
                        AmountEntryCard(amount: $amount, focus: $amountFocused)

                        if let cat = transaction.category {
                            groupCard(cat)
                        }

                        detailsCard
                        repeatCard

                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete Expense", systemImage: "trash")
                                .font(Brand.display(15, .semibold))
                                .foregroundStyle(Brand.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                                        .fill(Brand.danger.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
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
                    Text("Edit Expense")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Brand.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(Brand.display(15, .semibold))
                        .foregroundStyle(Brand.accent)
                        .disabled(!isValid)
                }
            }
            .confirmationDialog("Delete this expense?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .tint(Brand.accent)
    }

    private func groupCard(_ cat: BudgetCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group").brandEyebrow()
            HStack(spacing: 11) {
                CategoryTile(icon: cat.icon, colorKey: cat.color, size: 38)
                Text(cat.name)
                    .font(Brand.display(15, .medium))
                    .foregroundStyle(Brand.textPrimary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Date").brandEyebrow()
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Brand.accent)
            }

            Rectangle().fill(Brand.hairline).frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("Note").brandEyebrow()
                TextField("What was this for?", text: $notes, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $isRecurring.animation(.easeOut(duration: 0.2))) {
                Text("Recurring Expense")
                    .font(Brand.display(15, .medium))
                    .foregroundStyle(Brand.textPrimary)
            }
            .tint(Brand.accent)

            if isRecurring {
                BrandSegmented(
                    options: [("monthly", "Monthly"), ("yearly", "Yearly")],
                    selection: $recurringFrequency
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func save() {
        guard Self.saveEdits(
            amountText: amount,
            date: date,
            notes: notes,
            isRecurring: isRecurring,
            recurringFrequency: recurringFrequency,
            to: transaction,
            in: modelContext
        ) else { return }
        dismiss()
    }

    /// Writes the edited fields onto `transaction`. Returns false,
    /// changing nothing, when the amount isn't a positive number.
    @discardableResult
    static func saveEdits(
        amountText: String,
        date: Date,
        notes: String,
        isRecurring: Bool,
        recurringFrequency: String,
        to transaction: Transaction,
        in modelContext: ModelContext
    ) -> Bool {
        guard let amountValue = AmountInput.parse(amountText), amountValue > 0 else { return false }
        transaction.amount = amountValue
        transaction.date = Calendar.current.startOfDay(for: date)
        transaction.notes = notes
        transaction.isRecurring = isRecurring
        transaction.recurringFrequency = isRecurring ? recurringFrequency : ""
        return true
    }

    private func delete() {
        modelContext.delete(transaction)
        dismiss()
    }
}
