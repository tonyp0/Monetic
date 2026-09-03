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

    init(transaction: Transaction) {
        self.transaction = transaction
        _amount             = State(initialValue: String(format: "%.2f", transaction.amount))
        _date               = State(initialValue: transaction.date)
        _notes              = State(initialValue: transaction.notes)
        _isRecurring        = State(initialValue: transaction.isRecurring)
        _recurringFrequency = State(initialValue: transaction.recurringFrequency.isEmpty ? "monthly" : transaction.recurringFrequency)
    }

    private var isValid: Bool {
        (Double(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Locale.current.currencySymbol ?? "$")
                            .font(.title)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amount)
                            .font(.title)
                            .keyboardType(.decimalPad)
                            .onChange(of: amount) { _, newValue in
                                amount = AddTransactionView.sanitizeAmount(newValue)
                            }
                    }
                    .padding(.vertical, 4)
                }

                Section("Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                }

                Section("Notes (optional)") {
                    TextField("What was this for?", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

                Section("Repeat") {
                    Toggle("Recurring Expense", isOn: $isRecurring)
                    if isRecurring {
                        Picker("Frequency", selection: $recurringFrequency) {
                            Text("Monthly").tag("monthly")
                            Text("Yearly").tag("yearly")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if let cat = transaction.category {
                    Section("Group") {
                        HStack(spacing: 12) {
                            CategoryIcon(icon: cat.icon, color: cat.color, size: 20, frame: 36)
                                .cornerRadius(8)
                            Text(cat.name)
                        }
                    }
                }

                Section {
                    Button("Delete Expense", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .confirmationDialog("Delete this expense?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        transaction.amount = amountValue
        transaction.date = Calendar.current.startOfDay(for: date)
        transaction.notes = notes
        transaction.isRecurring = isRecurring
        transaction.recurringFrequency = isRecurring ? recurringFrequency : ""
        dismiss()
    }

    private func delete() {
        modelContext.delete(transaction)
        dismiss()
    }
}
