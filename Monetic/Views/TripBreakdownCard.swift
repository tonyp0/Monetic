import SwiftUI

/// A trip cost breakdown: one row per line item with its amount and share of
/// the total, then the total, the per-person split, the "+ flights" gap and
/// where the rates came from. Used live in the trip form and, for a saved
/// estimate, on the trip's detail screen.
struct TripBreakdownCard: View {
    let estimate: TripEstimate
    /// The total the trip actually saved, when the user typed over the
    /// estimate. Shown in place of the estimate's total with "Edited by you".
    var editedTotal: Double? = nil
    var editedCurrencyCode: String = Currency.code

    private let usd = "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Estimate").brandEyebrow()
                Spacer()
                BrandTag(text: estimate.style.label)
            }

            ForEach(estimate.lineItems) { item in
                row(item)
            }

            if !estimate.includesFlights {
                HStack(spacing: 6) {
                    Image(systemName: "airplane")
                        .font(.system(size: 11, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("+ flights: not included until you add a fare")
                }
                .font(.caption)
                .foregroundStyle(Brand.warning)
                .accessibilityIdentifier("flightsGapNote")
            }

            Rectangle().fill(Brand.hairline).frame(height: 1)

            totals

            VStack(alignment: .leading, spacing: 4) {
                Text(TripEstimator.sourceLine(for: estimate))
                Text("Travel style percentages are Monetic's assumptions, not published rates.")
                if Currency.code != usd {
                    Text("Shown in US dollars: the per diem rates are in USD and Monetic doesn't convert currencies.")
                }
            }
            .font(.caption)
            .foregroundStyle(Brand.textTertiary)
            .accessibilityIdentifier("estimateSourceLine")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("breakdownCard")
    }

    private func row(_ item: TripEstimate.LineItem) -> some View {
        let share = estimate.share(of: item)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.kind.title)
                    .font(Brand.display(14, .medium))
                    .foregroundStyle(Brand.textPrimary)
                Spacer(minLength: 8)
                Text("\(Int((share * 100).rounded()))%")
                    .font(Brand.display(12, .medium))
                    .foregroundStyle(Brand.textTertiary)
                Text(estimate.amount(item), format: .currency(code: usd))
                    .font(Brand.number(15, .semibold))
                    .foregroundStyle(Brand.textPrimary)
            }
            BrandProgressBar(percentage: share, tint: Brand.accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("breakdownRow_\(item.kind.rawValue)")
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(editedTotal == nil ? "Total" : "Estimate")
                    .font(Brand.display(15, .semibold))
                    .foregroundStyle(Brand.textPrimary)
                Spacer()
                Text(estimate.total, format: .currency(code: usd))
                    .font(Brand.number(20, .bold))
                    .foregroundStyle(editedTotal == nil ? Brand.textPrimary : Brand.textSecondary)
                    .accessibilityIdentifier("breakdownTotal")
            }

            if let editedTotal {
                HStack(alignment: .firstTextBaseline) {
                    BrandTag(text: "Edited by you")
                    Spacer()
                    Text(editedTotal, format: .currency(code: editedCurrencyCode))
                        .font(Brand.number(20, .bold))
                        .foregroundStyle(Brand.textPrimary)
                }
            }

            Text(perPersonText)
                .font(.caption)
                .foregroundStyle(Brand.textSecondary)
                .accessibilityIdentifier("breakdownPerPerson")
        }
    }

    private var perPersonText: String {
        let each = estimate.perPerson.formatted(.currency(code: usd))
        let nights = TripList.nightsText(estimate.nights)
        let rooms = estimate.rooms == 1 ? "1 room" : "\(estimate.rooms) rooms"
        guard estimate.travelers > 1 else { return "\(nights) · \(rooms) · 1 traveler" }
        let split = estimate.splitsEvenly ? "\(each) each" : "up to \(each) each"
        return "\(split) for \(estimate.travelers) · \(nights) · \(rooms)"
    }
}
