import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var hasCompletedOnboarding: Bool

    /// The starter groups offered on first launch. Static so tests can iterate
    /// the same list the app ships instead of keeping a copy of it.
    nonisolated static let defaultCategories: [(name: String, icon: String, color: String)] = [
        ("Food & Dining",  "🍔", "amber"),
        ("Entertainment",  "🎉", "violet"),
        ("Transport",      "🚗", "mint"),
        ("Shopping",       "🛒", "rose"),
        ("Bills & Fees",   "📋", "coral"),
        ("Health",         "💪", "azure"),
        ("Subscriptions",  "📱", "cyan"),
        ("Travel",         "🧳", "indigo"),
        ("Work",           "💼", "magenta"),
    ]

    @State private var selected: Set<String> = [
        "Food & Dining", "Entertainment", "Transport", "Shopping", "Bills & Fees", "Health", "Subscriptions"
    ]

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 9) {
                        ForEach(Self.defaultCategories, id: \.name) { cat in
                            categoryRow(cat)
                        }
                    }
                    .padding(.horizontal, Brand.Space.gutter)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)

                footer
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            BrandLogoMark(size: 72)

            VStack(spacing: 7) {
                MoneticWordmark(size: 19)

                Text("Pick the groups you want to start with.\nYou can change these any time.")
                    .font(.subheadline)
                    .foregroundStyle(Brand.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(.top, 54)
        .padding(.bottom, 26)
        .padding(.horizontal, 32)
    }

    // MARK: Rows

    private func categoryRow(_ cat: (name: String, icon: String, color: String)) -> some View {
        let isSelected = selected.contains(cat.name)
        let hue = CategoryPalette.color(for: cat.color)

        return Button(action: { toggle(cat.name) }) {
            HStack(spacing: 13) {
                CategoryTile(icon: cat.icon, colorKey: cat.color, size: 40)

                Text(cat.name)
                    .font(Brand.display(15, .medium))
                    .foregroundStyle(Brand.textPrimary)

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.clear : Brand.hairline, lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Brand.gradientDiagonal)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: Brand.Radius.row, style: .continuous)
                    .fill(Brand.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.row, style: .continuous)
                    .strokeBorder(isSelected ? hue.opacity(0.4) : Brand.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: saveAndContinue) {
                Text(selected.isEmpty ? "Skip for Now" : "Get Started")
            }
            .buttonStyle(GradientButtonStyle())
            .accessibilityIdentifier("getStartedButton")

            Text(selected.isEmpty
                 ? "You can add groups whenever you're ready."
                 : "\(selected.count) group\(selected.count == 1 ? "" : "s") selected")
                .font(.caption)
                .foregroundStyle(Brand.textTertiary)
        }
        .padding(.horizontal, Brand.Space.gutter)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            // Keeps the CTA readable when rows scroll underneath it.
            Brand.background.opacity(0.94)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func toggle(_ name: String) {
        if selected.contains(name) {
            selected.remove(name)
        } else {
            selected.insert(name)
        }
    }

    private func saveAndContinue() {
        Self.insertStarterGroups(named: selected, into: modelContext)
        try? modelContext.save()
        hasCompletedOnboarding = true
    }

    /// Inserts the chosen starter groups in their listed order.
    static func insertStarterGroups(named selected: Set<String>, into modelContext: ModelContext) {
        let toAdd = defaultCategories.filter { selected.contains($0.name) }
        for (index, cat) in toAdd.enumerated() {
            let category = BudgetCategory(
                name: cat.name,
                color: cat.color,
                icon: cat.icon,
                budgetLimit: 0,
                monthlyBudget: 0,
                isDefault: true,
                sortOrder: index
            )
            modelContext.insert(category)
        }
    }
}
