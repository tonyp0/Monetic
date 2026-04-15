import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // When opened from a category, it's pre-set and locked
    let presetCategory: BudgetCategory?

    @Query(sort: \BudgetCategory.name) private var allCategories: [BudgetCategory]
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var selectedCategory: BudgetCategory?
    @FocusState private var amountFocused: Bool

    init(category: BudgetCategory? = nil) {
        self.presetCategory = category
    }

    private var effectiveCategory: BudgetCategory? {
        presetCategory ?? selectedCategory
    }

    private var isValid: Bool {
        (Double(amount) ?? 0) > 0 && effectiveCategory != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Amount
                Section("Amount") {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Locale.current.currencySymbol ?? "$")
                            .font(.title)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amount)
                            .font(.title)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .onChange(of: amount) { _, newValue in
                                amount = Self.sanitizeAmount(newValue)
                            }
                    }
                    .padding(.vertical, 4)
                }

                // Date
                Section("Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                }

                // Notes
                Section("Notes (optional)") {
                    TextField("What was this for?", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

                // Category
                Section("Group") {
                    if let preset = presetCategory {
                        // Locked to the category this was opened from
                        HStack(spacing: 12) {
                            CategoryIcon(icon: preset.icon, color: preset.color, size: 20, frame: 36)
                                .cornerRadius(8)
                            Text(preset.name)
                                .foregroundColor(.primary)
                        }
                    } else {
                        // Let user pick
                        if allCategories.isEmpty {
                            Text("No groups yet — add one first")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(allCategories) { cat in
                                Button(action: { selectedCategory = cat }) {
                                    HStack(spacing: 12) {
                                        CategoryIcon(icon: cat.icon, color: cat.color, size: 20, frame: 36)
                                            .cornerRadius(8)
                                        Text(cat.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedCategory?.id == cat.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Deduction")
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
            .onAppear {
                amountFocused = true
                if presetCategory == nil && selectedCategory == nil {
                    selectedCategory = allCategories.first
                }
            }
        }
    }

    private func save() {
        let normalized = amount.replacingOccurrences(of: ",", with: ".")
        guard let amountValue = Double(normalized), amountValue > 0,
              let category = effectiveCategory else { return }

        let transaction = Transaction(
            amount: amountValue,
            date: date,
            notes: notes,
            category: category
        )
        modelContext.insert(transaction)
        // Explicitly maintain the relationship both ways
        category.transactions.append(transaction)
        dismiss()
    }

    // Strips anything that isn't a digit or decimal separator; allows only one separator and max 2 decimal places.
    static func sanitizeAmount(_ input: String) -> String {
        let decimalSep: Character = Locale.current.decimalSeparator?.first ?? "."
        let allowed: Set<Character> = ["0","1","2","3","4","5","6","7","8","9", decimalSep]
        let result = String(input.filter { allowed.contains($0) })
        let parts = result.components(separatedBy: String(decimalSep))
        if parts.count > 1 {
            return parts[0] + String(decimalSep) + String(parts[1].prefix(2))
        }
        return result
    }
}
