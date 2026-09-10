import SwiftUI
import SwiftData
import Charts

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @State private var selectedCategory: BudgetCategory?
    @State private var showingAddCategory = false
    @State private var showingAddTransaction = false
    @State private var showingSetBudget = false
    @State private var showingSettings = false
    @State private var chartsExpanded: Bool = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @AppStorage("budgetSetMonth") private var budgetSetMonth: String = ""
    @AppStorage("repeatMonthlyBudget") private var repeatMonthlyBudget: Bool = false

    init() {}

    private var totalSpentThisMonth: Double {
        categories.reduce(0) { $0 + $1.monthlySpending() }
    }

    private var remaining: Double {
        monthlyBudget - totalSpentThisMonth
    }

    private var spendingPercentage: Double {
        guard monthlyBudget > 0 else { return 0 }
        return min(totalSpentThisMonth / monthlyBudget, 1.0)
    }

    var body: some View {
        NavigationStack {
            List {
                // Budget Summary Card
                BudgetSummaryCard(
                    monthlyBudget: monthlyBudget,
                    totalSpent: totalSpentThisMonth,
                    remaining: remaining,
                    percentage: spendingPercentage,
                    onSetBudget: { showingSetBudget = true }
                )
                .listRowBackground(Color(.systemGroupedBackground))
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))

                // Charts Section
                if !categories.isEmpty && categories.contains(where: { $0.monthlySpending() > 0 }) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) { chartsExpanded.toggle() }
                    }) {
                        HStack {
                            Text("Spending Overview")
                                .font(.title3).fontWeight(.semibold).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
                                .rotationEffect(.degrees(chartsExpanded ? 0 : -90))
                        }
                    }
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

                    if chartsExpanded {
                        SpendingChartsView(categories: categories)
                            .listRowBackground(Color(.systemGroupedBackground))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // Groups header
                HStack {
                    Text("Groups").font(.title3).fontWeight(.semibold)
                    Spacer()
                    Button(action: { showingAddCategory = true }) {
                        Label("Add Group", systemImage: "plus.circle.fill").font(.subheadline)
                    }
                }
                .listRowBackground(Color(.systemGroupedBackground))
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

                // Groups
                if categories.isEmpty {
                    ContentUnavailableView(
                        "No Groups Yet",
                        systemImage: "tray",
                        description: Text("Add a group to start organizing your expenses")
                    )
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(categories) { category in
                        GroupRow(category: category)
                            .onTapGesture { selectedCategory = category }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    }
                    .onMove(perform: reorderCategories)
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .scrollContentBackground(.hidden)
            .navigationTitle("My Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape").foregroundColor(.secondary)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                    Button(action: { showingAddTransaction = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSetBudget) {
                SetBudgetView(
                    monthlyBudget: $monthlyBudget,
                    budgetSetMonth: $budgetSetMonth,
                    isNewMonthPrompt: false
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView()
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category)
            }
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { if !$0 { hasCompletedOnboarding = true } }
            )) {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
            .onAppear {
                // Mark existing users as already onboarded so they skip onboarding
                if !hasCompletedOnboarding && !categories.isEmpty {
                    hasCompletedOnboarding = true
                }
                checkMonthRollover()
            }
        }
    }

    private func deleteCategory(_ category: BudgetCategory) {
        modelContext.delete(category)
        try? modelContext.save()
    }

    private func reorderCategories(from source: IndexSet, to destination: Int) {
        var items = Array(categories)
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }
        try? modelContext.save()
    }

    private func checkMonthRollover() {
        let currentMonth = MonthKey.key()
        guard budgetSetMonth != currentMonth else { return }

        if repeatMonthlyBudget && monthlyBudget > 0 {
            budgetSetMonth = currentMonth
        } else {
            showingSetBudget = true
        }
    }
}

// MARK: - Budget Summary Card
struct BudgetSummaryCard: View {
    let monthlyBudget: Double
    let totalSpent: Double
    let remaining: Double
    let percentage: Double
    let onSetBudget: () -> Void

    private var progressColor: Color {
        if percentage >= 1.0 { return .red }
        if percentage >= 0.8 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Budget")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    if monthlyBudget > 0 {
                        Text(monthlyBudget, format: .currency(code: Currency.code))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    } else {
                        Button(action: onSetBudget) {
                            Text("Tap to set budget")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                }
                Spacer()
                Button(action: onSetBudget) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            if monthlyBudget > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(progressColor)
                            .frame(width: max(geo.size.width * percentage, percentage > 0 ? 4 : 0), height: 10)
                    }
                }
                .frame(height: 10)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(totalSpent, format: .currency(code: Currency.code))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(remaining >= 0 ? "Remaining" : "Over Budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(abs(remaining), format: .currency(code: Currency.code))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(remaining < 0 ? .red : .primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Category Icon
/// Displays either an emoji or falls back to an SF Symbol for legacy data.
struct CategoryIcon: View {
    let icon: String
    let color: String
    let size: CGFloat
    let frame: CGFloat

    var body: some View {
        Group {
            if icon.isEmojiIcon {
                Text(icon)
                    .font(.system(size: size))
            } else {
                Image(systemName: icon)
                    .font(.system(size: size * 0.7))
                    .foregroundColor(Color(color))
            }
        }
        .frame(width: frame, height: frame)
        .background(Color(color).opacity(0.15))
    }
}

// MARK: - Group Row
struct GroupRow: View {
    let category: BudgetCategory

    private var spent: Double { category.monthlySpending() }

    var body: some View {
        HStack(spacing: 12) {
            // Emoji or SF Symbol — no background box
            Group {
                if category.icon.isEmojiIcon {
                    Text(category.icon)
                        .font(.system(size: 28))
                } else {
                    Image(systemName: category.icon)
                        .font(.system(size: 22))
                        .foregroundColor(Color(category.color))
                }
            }
            .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(category.transactions.count) expense\(category.transactions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(spent, format: .currency(code: Currency.code))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(spent > 0 ? .primary : .secondary)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 12)
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
