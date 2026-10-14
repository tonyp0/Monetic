import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @State private var selectedCategory: BudgetCategory?
    @State private var showingAddCategory = false
    @State private var showingAddTransaction = false
    @State private var showingSetBudget = false
    @State private var isNewMonthPrompt = false
    @State private var showingSettings = false
    @State private var chartsExpanded: Bool = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @AppStorage("budgetSetMonth") private var budgetSetMonth: String = ""
    @AppStorage("repeatMonthlyBudget") private var repeatMonthlyBudget: Bool = false
    @AppStorage("lastMonthlyBudget") private var lastMonthlyBudget: Double = 0

    init() {}

    var body: some View {
        // Computed once per render and threaded through instead of letting
        // every row and chart call `category.monthlySpending()` on its own —
        // that method rescans a category's whole transaction list, so N
        // independent call sites turned one render into an O(categories ×
        // transactions) scan and was the source of the lag after adding an
        // expense.
        let categorySpending = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.id, $0.monthlySpending()) }
        )
        let totalSpent = categorySpending.values.reduce(0, +)
        let remaining = monthlyBudget - totalSpent
        // Unclamped on purpose — the ring needs to know it has been *passed*,
        // not just that it's full.
        let ratio = monthlyBudget > 0 ? totalSpent / monthlyBudget : 0
        let hasSpending = categorySpending.values.contains { $0 > 0 }

        NavigationStack {
            ZStack {
                BrandBackground()

                List {
                    Group {
                        BudgetHeroCard(
                            monthlyBudget: monthlyBudget,
                            totalSpent: totalSpent,
                            remaining: remaining,
                            ratio: ratio,
                            onSetBudget: {
                                isNewMonthPrompt = false
                                showingSetBudget = true
                            }
                        )
                        .padding(.top, 4)
                        .padding(.bottom, 10)

                        if hasSpending {
                            chartsSection(spendingByCategory: categorySpending)
                        }

                        BrandSectionHeader(title: "Groups") {
                            Button(action: { showingAddCategory = true }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Add")
                                        .font(Brand.display(13, .semibold))
                                }
                                .foregroundStyle(Brand.accent)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(Brand.accent.opacity(0.14))
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("addGroupButton")
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 6)
                    }
                    .brandListRow()

                    if categories.isEmpty {
                        NoGroupsCard(onAdd: { showingAddCategory = true })
                            .brandListRow()
                    } else {
                        ForEach(categories) { category in
                            GroupCard(category: category, spent: categorySpending[category.id] ?? 0)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedCategory = category }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteCategory(category)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .brandListRow(vertical: 5)
                        }
                        .onMove(perform: reorderCategories)
                    }

                    Color.clear
                        .frame(height: 24)
                        .brandListRow(vertical: 0)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 0)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    MoneticWordmark()
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Brand.textSecondary)
                    }
                    .accessibilityIdentifier("settingsButton")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                        .font(Brand.display(15, .medium))
                    Button(action: { showingAddTransaction = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Brand.accent)
                    }
                    .accessibilityIdentifier("addTransactionButton")
                }
            }
            .tint(Brand.accent)
            .sheet(isPresented: $showingSetBudget) {
                SetBudgetView(
                    monthlyBudget: $monthlyBudget,
                    budgetSetMonth: $budgetSetMonth,
                    isNewMonthPrompt: $isNewMonthPrompt
                )
                // A new-month prompt has its own explicit exits, so it can't be
                // swiped away without recording the month — that was the nag loop.
                .interactiveDismissDisabled(isNewMonthPrompt)
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
            .onChange(of: hasCompletedOnboarding) { _, completed in
                // The budget-rollover check runs from onAppear, which fires
                // once at launch — at the same moment the onboarding
                // fullScreenCover is first presented. Triggering the New
                // Month sheet then races the cover: both end up "presented"
                // in SwiftUI's state at once, so only one renders while the
                // other sits beneath it, still reporting as on-screen to
                // accessibility/automation even though it isn't visible or
                // interactive. Re-run the check once onboarding actually
                // finishes so the budget prompt reliably shows afterward
                // instead of racing it.
                if completed {
                    checkMonthRollover()
                }
            }
        }
    }

    @ViewBuilder
    private func chartsSection(spendingByCategory: [UUID: Double]) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) { chartsExpanded.toggle() }
        }) {
            BrandSectionHeader(title: "Spending Overview") {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Brand.textSecondary)
                    .rotationEffect(.degrees(chartsExpanded ? 0 : -90))
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
        .padding(.bottom, 8)

        if chartsExpanded {
            SpendingChartsView(categories: categories, spendingByCategory: spendingByCategory)
                .transition(.opacity.combined(with: .move(edge: .top)))
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
        // Don't race the onboarding fullScreenCover — it only makes sense to
        // prompt for a budget once onboarding has actually finished.
        guard hasCompletedOnboarding else { return }
        let currentMonth = MonthKey.key()
        guard budgetSetMonth != currentMonth else { return }

        if monthlyBudget > 0 {
            lastMonthlyBudget = monthlyBudget
        }
        isNewMonthPrompt = true
        showingSetBudget = true
    }
}

// MARK: - List row styling
/// The home screen is a `List` so that swipe-to-delete and drag-to-reorder keep
/// working; these modifiers strip the stock chrome so it doesn't look like one.
private extension View {
    func brandListRow(vertical: CGFloat = 0) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: vertical,
                leading: Brand.Space.gutter,
                bottom: vertical,
                trailing: Brand.Space.gutter
            ))
    }
}

// MARK: - Budget Hero

struct BudgetHeroCard: View {
    let monthlyBudget: Double
    let totalSpent: Double
    let remaining: Double
    let ratio: Double
    let onSetBudget: () -> Void

    private var isOver: Bool { remaining < 0 }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(MonthKey.displayName()).brandEyebrow()
                Spacer()
                if monthlyBudget > 0 {
                    Button(action: onSetBudget) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Brand.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Brand.track))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit monthly budget")
                }
            }

            if monthlyBudget > 0 {
                ring
                statsRow
            } else {
                emptyBudgetPrompt
            }
        }
        .brandCard(padding: 20)
    }

    private var ring: some View {
        BudgetRing(percentage: ratio, lineWidth: 15) {
            VStack(spacing: 3) {
                Text(isOver ? "Over by" : "Remaining").brandEyebrow()

                Text(abs(remaining), format: .currency(code: Currency.code))
                    .font(Brand.number(34))
                    .foregroundStyle(isOver ? Brand.danger : Brand.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 12)

                Text("\(Int((ratio * 100).rounded()))% used")
                    .font(Brand.display(12, .medium))
                    .foregroundStyle(Brand.textTertiary)
            }
        }
        .frame(width: 196, height: 196)
        .padding(.vertical, 2)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(label: "Spent", value: totalSpent, tint: Brand.textPrimary)

            Rectangle()
                .fill(Brand.hairline)
                .frame(width: 1, height: 30)

            stat(label: "Budget", value: monthlyBudget, tint: Brand.textPrimary)
        }
    }

    private func stat(label: String, value: Double, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).brandEyebrow()
            Text(value, format: .currency(code: Currency.code))
                .font(Brand.number(17, .semibold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyBudgetPrompt: some View {
        VStack(spacing: 14) {
            Text("No budget set")
                .font(Brand.display(21, .bold))
                .foregroundStyle(Brand.textPrimary)

            Text("Give yourself a number to spend against this month.")
                .font(.subheadline)
                .foregroundStyle(Brand.textSecondary)
                .multilineTextAlignment(.center)

            Button("Set Monthly Budget", action: onSetBudget)
                .buttonStyle(GradientButtonStyle())
                .padding(.top, 2)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Group Card

struct GroupCard: View {
    let category: BudgetCategory
    // Computed once by the caller and passed in — `category.monthlySpending()`
    // rescans every transaction, so each row calling it independently turns an
    // O(categories) list into an O(categories × transactions) one.
    let spent: Double

    private var hasLimit: Bool { category.monthlyBudget > 0 }
    private var isOver: Bool { hasLimit && spent > category.monthlyBudget }
    private var hue: Color { CategoryPalette.color(for: category.color) }

    var body: some View {
        HStack(spacing: 13) {
            CategoryTile(icon: category.icon, colorKey: category.color)

            VStack(alignment: .leading, spacing: 5) {
                Text(category.name)
                    .font(Brand.display(15, .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .lineLimit(1)

                if hasLimit {
                    Text("of \(category.monthlyBudget, format: .currency(code: Currency.code))")
                        .font(.caption)
                        .foregroundStyle(isOver ? Brand.danger : Brand.textTertiary)

                    BrandProgressBar(
                        percentage: category.monthlyBudget > 0 ? spent / category.monthlyBudget : 0,
                        tint: isOver ? Brand.danger : hue
                    )
                    .padding(.top, 1)
                } else {
                    Text("\(category.transactions.count) expense\(category.transactions.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Brand.textTertiary)
                }
            }

            Spacer(minLength: 8)

            Text(spent, format: .currency(code: Currency.code))
                .font(Brand.number(16, .semibold))
                .foregroundStyle(isOver ? Brand.danger : (spent > 0 ? Brand.textPrimary : Brand.textTertiary))

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Brand.textTertiary)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: Brand.Radius.row, style: .continuous)
                .fill(Brand.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.row, style: .continuous)
                .strokeBorder(isOver ? Brand.danger.opacity(0.35) : Brand.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Empty state

struct NoGroupsCard: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Brand.accent.opacity(0.12))
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Brand.accent)
                )

            Text("No groups yet")
                .font(Brand.display(17, .semibold))
                .foregroundStyle(Brand.textPrimary)

            Text("Groups are how Monetic sorts your spending — food, rent, fun money.")
                .font(.subheadline)
                .foregroundStyle(Brand.textSecondary)
                .multilineTextAlignment(.center)

            Button("Add Your First Group", action: onAdd)
                .buttonStyle(GradientButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .brandCard(padding: 22)
    }
}
