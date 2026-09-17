import SwiftUI
import Charts

struct SpendingChartsView: View {
    let categories: [BudgetCategory]
    // Computed once by the caller — `category.monthlySpending()` rescans a
    // category's whole transaction list, and this view used to call it from
    // the filter, the sort comparator, each chart mark, and the legend, so a
    // handful of categories turned into dozens of redundant full scans.
    let spendingByCategory: [UUID: Double]

    private func spending(for category: BudgetCategory) -> Double {
        spendingByCategory[category.id] ?? 0
    }

    // Categories that have spending this month
    private var activeCategories: [BudgetCategory] {
        categories
            .filter { spending(for: $0) > 0 }
            .sorted { spending(for: $0) > spending(for: $1) }
    }

    private var totalSpent: Double {
        activeCategories.reduce(0) { $0 + spending(for: $1) }
    }

    // All transactions this month across all categories, grouped by day
    private var dailySpending: [DailySpend] {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.dateComponents([.year, .month], from: now)

        var totals: [Int: Double] = [:]
        for category in categories {
            for transaction in category.transactions {
                let comps = calendar.dateComponents([.year, .month, .day], from: transaction.date)
                guard comps.year == currentMonth.year,
                      comps.month == currentMonth.month,
                      let day = comps.day else { continue }
                totals[day, default: 0] += transaction.amount
            }
        }

        return totals
            .map { DailySpend(day: $0.key, amount: $0.value) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.stack) {
            donutCard
            if !dailySpending.isEmpty {
                dailyCard
            }
        }
    }

    // MARK: Donut

    private var donutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By Group").brandEyebrow()

            Chart(activeCategories, id: \.id) { category in
                SectorMark(
                    angle: .value("Spent", spending(for: category)),
                    innerRadius: .ratio(0.66),
                    angularInset: 2.5
                )
                // Coloured per mark rather than through a style scale, so each
                // slice is guaranteed the hue its group is shown with elsewhere.
                .foregroundStyle(CategoryPalette.color(for: category.color))
                .cornerRadius(5)
            }
            .chartLegend(.hidden)
            .chartBackground { _ in
                // Dead space in the middle of a donut is the natural home for
                // the number the slices add up to.
                VStack(spacing: 2) {
                    Text("Total").brandEyebrow()
                    Text(totalSpent, format: .currency(code: Currency.code))
                        .font(Brand.number(22))
                        .foregroundStyle(Brand.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)

            legend
        }
        .brandCard()
    }

    /// Replaces the stock chart legend, which can't show amounts and doesn't
    /// match anything else in the app.
    private var legend: some View {
        VStack(spacing: 9) {
            ForEach(activeCategories.prefix(6), id: \.id) { category in
                HStack(spacing: 9) {
                    Circle()
                        .fill(CategoryPalette.color(for: category.color))
                        .frame(width: 8, height: 8)

                    Text(category.name)
                        .font(.footnote)
                        .foregroundStyle(Brand.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(spending(for: category), format: .currency(code: Currency.code))
                        .font(Brand.number(13, .semibold))
                        .foregroundStyle(Brand.textPrimary)
                }
            }

            if activeCategories.count > 6 {
                HStack {
                    Text("+\(activeCategories.count - 6) more")
                        .font(.caption)
                        .foregroundStyle(Brand.textTertiary)
                    Spacer()
                }
            }
        }
    }

    // MARK: Daily bars

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Spending").brandEyebrow()

            Chart(dailySpending) { item in
                BarMark(
                    x: .value("Day", item.day),
                    y: .value("Amount", item.amount),
                    width: .fixed(6)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Brand.magenta, Brand.blue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisValueLabel {
                        if let day = value.as(Int.self) {
                            Text("\(day)")
                                .font(.caption2)
                                .foregroundStyle(Brand.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Brand.hairline)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: Currency.code).precision(.fractionLength(0)))
                                .font(.caption2)
                                .foregroundStyle(Brand.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 170)
        }
        .brandCard()
    }
}

struct DailySpend: Identifiable {
    var id: Int { day }
    let day: Int
    let amount: Double
}
