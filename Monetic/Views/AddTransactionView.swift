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
    @State private var isRecurring: Bool = false
    @State private var recurringFrequency: String = "monthly"
    @FocusState private var amountFocused: Bool

    init(category: BudgetCategory? = nil) {
        self.presetCategory = category
    }

    private var effectiveCategory: BudgetCategory? {
        presetCategory ?? selectedCategory
    }

    private var isValid: Bool {
        (AmountInput.parse(amount) ?? 0) > 0 && effectiveCategory != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: Brand.Space.stack) {
                        AmountEntryCard(amount: $amount, focus: $amountFocused)
                        groupCard
                        detailsCard
                        repeatCard
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
                    Text("Add Expense")
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
            .onAppear {
                amountFocused = true
                if presetCategory == nil && selectedCategory == nil {
                    selectedCategory = allCategories.first
                }
            }
        }
        .tint(Brand.accent)
    }

    // MARK: Group

    private var groupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group").brandEyebrow()

            if let preset = presetCategory {
                // Locked to the category this was opened from
                HStack(spacing: 11) {
                    CategoryTile(icon: preset.icon, colorKey: preset.color, size: 38)
                    Text(preset.name)
                        .font(Brand.display(15, .medium))
                        .foregroundStyle(Brand.textPrimary)
                    Spacer()
                }
            } else if allCategories.isEmpty {
                Text("No groups yet — add one first.")
                    .font(.subheadline)
                    .foregroundStyle(Brand.textSecondary)
            } else {
                // A horizontal rail keeps the picker to one row no matter how
                // many groups exist, instead of pushing everything else down.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(allCategories) { cat in
                            groupChip(cat)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func groupChip(_ cat: BudgetCategory) -> some View {
        let isSelected = selectedCategory?.id == cat.id
        let hue = CategoryPalette.color(for: cat.color)

        return Button {
            selectedCategory = cat
        } label: {
            VStack(spacing: 7) {
                CategoryTile(icon: cat.icon, colorKey: cat.color, size: 44)
                Text(cat.name)
                    .font(Brand.display(11, .medium))
                    .foregroundStyle(isSelected ? Brand.textPrimary : Brand.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 66)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? hue.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? hue.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: Details

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

    // MARK: Repeat

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $isRecurring.animation(.easeOut(duration: 0.2))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recurring Expense")
                        .font(Brand.display(15, .medium))
                        .foregroundStyle(Brand.textPrimary)
                    Text("Counts automatically every period")
                        .font(.caption)
                        .foregroundStyle(Brand.textSecondary)
                }
            }
            .tint(Brand.accent)

            if isRecurring {
                BrandSegmented(
                    options: [("monthly", "Monthly"), ("yearly", "Yearly")],
                    selection: $recurringFrequency
                )

                Text(recurringFrequency == "monthly"
                     ? "This amount will count toward your budget every month."
                     : "This amount will count every year in the same month.")
                    .font(.caption)
                    .foregroundStyle(Brand.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func save() {
        guard let amountValue = AmountInput.parse(amount), amountValue > 0,
              let category = effectiveCategory else { return }

        // Setting `category` is enough — SwiftData maintains the inverse
        // relationship, so appending to category.transactions as well is redundant.
        let transaction = Transaction(
            amount: amountValue,
            date: date,
            notes: notes,
            category: category,
            isRecurring: isRecurring,
            recurringFrequency: recurringFrequency
        )
        modelContext.insert(transaction)
        // Every other insert path in the app (onboarding, AddCategoryView)
        // explicitly saves right after inserting — this one didn't, so
        // dismiss() could fire before autosave committed the new
        // transaction, leaving the category's spend reflecting stale data
        // for a beat (or, observed in practice, not catching up at all
        // within the dismiss/re-render window).
        try? modelContext.save()
        dismiss()
    }
}
