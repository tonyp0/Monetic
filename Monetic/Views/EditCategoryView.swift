import SwiftUI
import SwiftData

struct EditCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var category: BudgetCategory

    @State private var name: String
    @State private var selectedEmoji: String
    @State private var monthlyLimit: String
    @State private var showingEmojiPicker = false

    init(category: BudgetCategory) {
        self.category = category
        _name = State(initialValue: category.name)
        _selectedEmoji = State(initialValue: category.icon)
        _monthlyLimit = State(initialValue: category.monthlyBudget > 0
                              ? String(format: "%.2f", category.monthlyBudget)
                              : "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        Button(action: { showingEmojiPicker = true }) {
                            VStack(spacing: 10) {
                                CategoryTile(icon: selectedEmoji, colorKey: category.color, size: 108)

                                HStack(spacing: 4) {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Tap to change")
                                        .font(Brand.display(13, .medium))
                                }
                                .foregroundStyle(Brand.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 18) {
                            BrandField(label: "Group name") {
                                TextField("Group name", text: $name)
                                    .font(Brand.display(16, .medium))
                            }

                            BrandField(
                                label: "Monthly limit",
                                footnote: "Leave empty for no limit. Groups over their limit are highlighted on the home screen."
                            ) {
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text(Currency.symbol)
                                        .font(Brand.number(16, .medium))
                                        .foregroundStyle(Brand.textSecondary)
                                    TextField("No limit", text: $monthlyLimit)
                                        .font(Brand.number(16, .semibold))
                                        .keyboardType(.decimalPad)
                                        .onChange(of: monthlyLimit) { _, newValue in
                                            monthlyLimit = AmountInput.sanitize(newValue)
                                        }
                                }
                            }
                        }
                        .padding(.horizontal, Brand.Space.gutter)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Group")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                PlainToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Brand.accentText)
                }
                PlainToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Brand.accentText)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerSheet(selectedEmoji: $selectedEmoji)
            }
        }
        .tint(Brand.accentText)
    }

    private func save() {
        category.name = name.trimmingCharacters(in: .whitespaces)
        category.icon = selectedEmoji
        // An empty field clears the limit rather than leaving the old one behind.
        category.monthlyBudget = AmountInput.parse(monthlyLimit) ?? 0
        try? modelContext.save()
        dismiss()
    }
}
