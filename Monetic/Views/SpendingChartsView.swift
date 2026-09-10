import SwiftUI
import Charts

struct SpendingChartsView: View {
    let categories: [BudgetCategory]

    // Categories that have spending this month
    private var activeCategories: [BudgetCategory] {
        categories.filter { $0.monthlySpending() > 0 }
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
        VStack(alignment: .leading, spacing: 16) {
            // Donut (Pie) Chart
            VStack(alignment: .leading, spacing: 8) {
                Text("By Group")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Chart(activeCategories, id: \.id) { category in
                    SectorMark(
                        angle: .value("Spent", category.monthlySpending()),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Group", category.name))
                    .cornerRadius(4)
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
                .frame(height: 220)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)

            // Bar Chart — daily spending
            if !dailySpending.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Spending")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Chart(dailySpending) { item in
                        BarMark(
                            x: .value("Day", item.day),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel {
                                if let day = value.as(Int.self) {
                                    Text("\(day)")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(amount, format: .currency(code: Currency.code).precision(.fractionLength(0)))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
            }
        }
    }
}

struct DailySpend: Identifiable {
    var id: Int { day }
    let day: Int
    let amount: Double
}
