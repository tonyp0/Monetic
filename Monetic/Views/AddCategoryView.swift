import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingCategories: [BudgetCategory]

    @State private var name: String = ""
    @State private var selectedEmoji: String = "📦"
    @State private var showingEmojiPicker = false
    @FocusState private var nameFocused: Bool

    /// Groups cycle through the brand palette in creation order, so two groups
    /// made back to back never land on neighbouring hues.
    private var nextColorKey: String {
        CategoryPalette.key(forIndex: existingCategories.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(spacing: 26) {
                        emojiPreview

                        BrandField(label: "Group Name") {
                            TextField("e.g. Groceries, Rent, Fun Money", text: $name)
                                .font(Brand.display(16, .medium))
                                .focused($nameFocused)
                        }
                        .padding(.horizontal, Brand.Space.gutter)
                    }
                    .padding(.top, 26)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Group")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Brand.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { save() }
                        .font(Brand.display(15, .semibold))
                        .foregroundStyle(Brand.accent)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("saveGroupButton")
                }
            }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerSheet(selectedEmoji: $selectedEmoji)
            }
            .onAppear { nameFocused = true }
        }
        .tint(Brand.accent)
    }

    /// Previewed in the hue the group will actually be assigned, so the choice
    /// isn't a surprise once it lands on the home screen.
    private var emojiPreview: some View {
        Button(action: { showingEmojiPicker = true }) {
            VStack(spacing: 10) {
                CategoryTile(icon: selectedEmoji, colorKey: nextColorKey, size: 108)

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
    }

    private func save() {
        let category = BudgetCategory(
            name: name.trimmingCharacters(in: .whitespaces),
            color: nextColorKey,
            icon: selectedEmoji,
            budgetLimit: 0,
            monthlyBudget: 0,
            isDefault: false,
            sortOrder: existingCategories.count
        )
        modelContext.insert(category)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Emoji Picker Sheet
struct EmojiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String

    let sections: [(title: String, emojis: [String])] = [
        ("Food & Drink",  ["🍔","🍕","🌮","🍣","🍜","🥗","🍱","☕","🧃","🍺","🍷","🛒","🥦","🍰","🍿"]),
        ("Transport",     ["🚗","🚌","🚇","✈️","🚲","🛵","🚕","🛻","⛽","🚁","🛳️","🚂"]),
        ("Home",          ["🏠","🛋️","💡","🔧","🧹","🛁","🏡","📦","🪴","🔑","🛏️","🧺"]),
        ("Health",        ["💊","🏥","🏋️","💆","🦷","👶","🐾","🧘","🩺","💉","🩹"]),
        ("Entertainment", ["🎬","🎵","🎮","📚","🎭","🎨","🏖️","⚽","🎲","🎤","🎧","🎻","🎰"]),
        ("Shopping",      ["👗","👟","💄","🛍️","💍","👔","🧴","👜","🕶️","🧢","👠"]),
        ("Finance",       ["💰","💳","🏦","📈","💵","🪙","📉","💎","🏧"]),
        ("Work",          ["💼","🖥️","📊","✏️","📱","📋","🖨️","📎","🗂️","🏢"]),
        ("Travel",        ["🌍","🏕️","🏨","🗺️","🎒","🗼","🏝️","🎡"]),
        ("Other",         ["🎁","⭐","❤️","🎓","🏆","🌟","🙏","✨","🔔","🌈","🦋"]),
    ]

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(sections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title)
                                    .brandEyebrow()
                                    .padding(.horizontal, Brand.Space.gutter)

                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(section.emojis, id: \.self) { emoji in
                                        emojiButton(emoji)
                                    }
                                }
                                .padding(.horizontal, Brand.Space.gutter)
                            }
                        }
                    }
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Choose Emoji")
                        .font(Brand.display(16, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Brand.textSecondary)
                }
            }
        }
        .tint(Brand.accent)
    }

    private func emojiButton(_ emoji: String) -> some View {
        let isSelected = selectedEmoji == emoji

        return Button {
            selectedEmoji = emoji
            dismiss()
        } label: {
            Text(emoji)
                .font(.system(size: 28))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    EmojiCellBackground(isSelected: isSelected)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Selection chrome for an emoji cell.
private struct EmojiCellBackground: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Brand.surface)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? AnyShapeStyle(Brand.gradientDiagonal) : AnyShapeStyle(Brand.hairline),
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }
}
