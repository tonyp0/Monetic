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

    private let autoColors = ["blue", "orange", "green", "purple", "pink", "red", "teal", "indigo"]

    private var nextAutoColor: String {
        autoColors[existingCategories.count % autoColors.count]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Emoji preview + name entry
                VStack(spacing: 24) {
                    // Selected emoji preview
                    Button(action: { showingEmojiPicker = true }) {
                        VStack(spacing: 8) {
                            Text(selectedEmoji)
                                .font(.system(size: 72))
                                .frame(width: 120, height: 120)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(28)

                            Text("Tap to change emoji")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 32)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Group Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)

                        TextField("e.g. Groceries, Rent, Fun Money", text: $name)
                            .focused($nameFocused)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerSheet(selectedEmoji: $selectedEmoji)
            }
            .onAppear { nameFocused = true }
        }
    }

    private func save() {
        let category = BudgetCategory(
            name: name.trimmingCharacters(in: .whitespaces),
            color: nextAutoColor,
            icon: selectedEmoji,
            budgetLimit: 0,
            monthlyBudget: 0,
            isDefault: false,
            order: existingCategories.count
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

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Preview of current selection
                    HStack {
                        Spacer()
                        Text(selectedEmoji)
                            .font(.system(size: 56))
                            .frame(width: 90, height: 90)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(20)
                        Spacer()
                    }
                    .padding(.top, 8)

                    // Emoji grid by section
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(section.emojis, id: \.self) { emoji in
                                    Button(action: {
                                        selectedEmoji = emoji
                                        dismiss()
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 30))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                selectedEmoji == emoji
                                                    ? Color.accentColor.opacity(0.25)
                                                    : Color(.secondarySystemGroupedBackground)
                                            )
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
