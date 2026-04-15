import SwiftUI
import SwiftData
import Charts

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @State private var selectedCategory: BudgetCategory?
    @State private var showingAddCategory = false
    @State private var showingAddTransaction = false
    @State private var showingSetBudget = false
    @State private var showingSettings = false
    @State private var chartsExpanded: Bool = true
    @State private var isEditingOrder: Bool = false
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
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

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
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if chartsExpanded {
                        SpendingChartsView(categories: categories)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .transition(.opacity)
                    }
                }

                // Groups Header
                HStack {
                    Text("Groups").font(.title3).fontWeight(.semibold)
                    Spacer()
                    if isEditingOrder {
                        Button("Done") {
                            withAnimation { isEditingOrder = false }
                        }
                        .fontWeight(.semibold)
                    } else {
                        HStack(spacing: 16) {
                            if !categories.isEmpty {
                                Button(action: { withAnimation { isEditingOrder = true } }) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.subheadline)
                                }
                            }
                            Button(action: { showingAddCategory = true }) {
                                Label("Add Group", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Groups List
                if categories.isEmpty {
                    ContentUnavailableView(
                        "No Groups Yet",
                        systemImage: "tray",
                        description: Text("Add a group to start organizing your deductions")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(categories) { category in
                        GroupRow(category: category)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !isEditingOrder { selectedCategory = category }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onMove(perform: moveCategories)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .environment(\.editMode, Binding(
                get: { isEditingOrder ? EditMode.active : EditMode.inactive },
                set: { isEditingOrder = ($0 == .active) }
            ))
            .navigationTitle("My Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape").foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingAddCategory) { AddCategoryView() }
            .sheet(isPresented: $showingAddTransaction) { AddTransactionView() }
            .sheet(item: $selectedCategory) { category in CategoryDetailView(category: category) }
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { if !$0 { hasCompletedOnboarding = true } }
            )) {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
            .onAppear {
                if !hasCompletedOnboarding && !categories.isEmpty {
                    hasCompletedOnboarding = true
                }
                initializeOrdersIfNeeded()
                checkMonthRollover()
            }
        }
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, cat) in reordered.enumerated() {
            cat.order = index
        }
        try? modelContext.save()
    }

    private func initializeOrdersIfNeeded() {
        guard categories.count > 1 else { return }
        // If all orders are the same (uninitialized default), assign sequential values
        let allSameOrder = Set(categories.map { $0.order }).count == 1
        if allSameOrder {
            for (i, cat) in categories.enumerated() {
                cat.order = i
            }
            try? modelContext.save()
        }
    }

    private func deleteCategory(_ category: BudgetCategory) {
        modelContext.delete(category)
        try? modelContext.save()
    }

    private func checkMonthRollover() {
        let currentMonth = currentMonthKey()
        guard budgetSetMonth != currentMonth else { return }

        if repeatMonthlyBudget && monthlyBudget > 0 {
            budgetSetMonth = currentMonth
        } else {
            showingSetBudget = true
        }
    }

    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
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
                        Text(monthlyBudget, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
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
                        Text(totalSpent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(remaining >= 0 ? "Remaining" : "Over Budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(abs(remaining), format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
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

    private var isEmoji: Bool {
        // SF Symbol names are ASCII only; emoji contain non-ASCII scalars
        icon.unicodeScalars.contains { $0.value > 127 }
    }

    var body: some View {
        Group {
            if isEmoji {
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
    private var isEmoji: Bool { category.icon.unicodeScalars.contains { $0.value > 127 } }

    var body: some View {
        HStack(spacing: 12) {
            // Emoji or SF Symbol — no background box
            Group {
                if isEmoji {
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
                Text("\(category.transactions.count) deduction\(category.transactions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(spent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
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
