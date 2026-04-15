import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var transaction: Transaction

    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var showingDeleteConfirm = false

    init(transaction: Transaction) {
        self.transaction = transaction
        _amount = State(initialValue: String(format: "%.2f", transaction.amount))
        _date   = State(initialValue: transaction.date)
        _notes  = State(initialValue: transaction.notes)
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
                    Button("Delete Deduction", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Edit Deduction")
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
            .confirmationDialog("Delete this deduction?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
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
        dismiss()
    }

    private func delete() {
        modelContext.delete(transaction)
        dismiss()
    }
}
