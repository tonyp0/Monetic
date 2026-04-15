import SwiftUI
import SwiftData

struct EditCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var category: BudgetCategory

    @State private var name: String
    @State private var selectedEmoji: String
    @State private var showingEmojiPicker = false

    init(category: BudgetCategory) {
        self.category = category
        _name = State(initialValue: category.name)
        _selectedEmoji = State(initialValue: category.icon)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    // Emoji preview
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

                        TextField("Group name", text: $name)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerSheet(selectedEmoji: $selectedEmoji)
            }
        }
    }

    private func save() {
        category.name = name.trimmingCharacters(in: .whitespaces)
        category.icon = selectedEmoji
        try? modelContext.save()
        dismiss()
    }
}
