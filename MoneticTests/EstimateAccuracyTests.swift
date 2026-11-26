import Foundation
import SwiftData
import Testing
@testable import Monetic

@Suite("Estimate accuracy")
struct EstimateAccuracyTests {
    typealias Gap = EstimateAccuracy.Gap

    /// A breakdown in cents: lodging, food, transport, activities, and flights if given.
    static func estimate(_ cents: [Int], style: TravelStyle = .budget) -> TripEstimate {
        let kinds = TripEstimate.Kind.allCases
        let items = zip(kinds, cents).map { TripEstimate.LineItem(kind: $0, cents: $1) }
        let total = cents.reduce(0, +)
        return TripEstimate(lineItems: items, totalCents: total, perPersonCents: [total], travelers: 1,
                            nights: 3, rooms: 1, style: style, includesFlights: cents.count == 5,
                            locationID: "TEST-CANCUN", locationName: "Cancún, Mexico", sourceID: "dos",
                            effective: "2024-08-01")
    }

    static func actuals(_ pairs: [(TripEstimate.Kind, Int)]) -> TripActuals {
        TripActuals(lineItems: pairs.map { TripEstimate.LineItem(kind: $0.0, cents: $0.1) },
                    loggedAt: TestSupport.date(2027, 4, 1))
    }

    // MARK: Error math

    @Test("Over, under and exact")
    func gaps() {
        let over = Gap(estimatedCents: 10_000, actualCents: 11_800)
        #expect(over.differenceCents == 1_800)
        #expect(over.absoluteCents == 1_800)
        #expect(over.signedPercent == 18)
        #expect(over.absolutePercent == 18)

        let under = Gap(estimatedCents: 20_000, actualCents: 15_000)
        #expect(under.differenceCents == -5_000)
        #expect(under.absoluteCents == 5_000)
        #expect(under.signedPercent == -25)
        #expect(under.absolutePercent == 25)

        #expect(Gap(estimatedCents: 500, actualCents: 500).signedPercent == 0)
    }

    @Test("A zero estimate has a dollar gap but no percentage")
    func zeroEstimate() {
        let gap = Gap(estimatedCents: 0, actualCents: 4_000)
        #expect(gap.differenceCents == 4_000)
        #expect(gap.signedPercent == nil)
        #expect(gap.absolutePercent == nil)
        #expect(Gap(estimatedCents: 0, actualCents: 0).signedPercent == nil)
    }

    // MARK: One trip

    @Test("Line by line, with untracked lines left out of the overall")
    func compareLines() {
        let estimate = Self.estimate([40_000, 20_000, 5_000, 10_000])
        let actuals = Self.actuals([(.lodging, 50_000), (.food, 18_000), (.flights, 30_000)])
        let comparison = EstimateAccuracy.compare(estimate: estimate, plannedTotalCents: 75_000, actuals: actuals)

        #expect(comparison.lines.map(\.kind) == [.lodging, .food, .localTransport, .activities, .flights])
        #expect(comparison.lines[0].error == Gap(estimatedCents: 40_000, actualCents: 50_000))
        #expect(comparison.lines[2].actualCents == nil, "transport wasn't tracked")
        #expect(comparison.lines[2].error == nil)
        #expect(comparison.lines[4].estimatedCents == nil, "no flights were estimated")
        #expect(comparison.lines[4].error == nil)

        // Lodging + food only: 60,000 estimated, 68,000 spent.
        #expect(comparison.overall == Gap(estimatedCents: 60_000, actualCents: 68_000))
        #expect(comparison.comparedLines == 2)
    }

    @Test("Without a breakdown, totals only")
    func compareTotals() {
        let actuals = Self.actuals([(.lodging, 30_000), (.food, 12_000)])
        let comparison = EstimateAccuracy.compare(estimate: nil, plannedTotalCents: 40_000, actuals: actuals)
        #expect(comparison.overall == Gap(estimatedCents: 40_000, actualCents: 42_000))
        #expect(comparison.comparedLines == 0)
        #expect(comparison.lines.allSatisfy { $0.estimatedCents == nil })
    }

    @Test("Nothing logged on the matching lines: no overall")
    func nothingComparable() {
        let comparison = EstimateAccuracy.compare(estimate: Self.estimate([1, 2, 3, 4]), plannedTotalCents: 10,
                                                  actuals: Self.actuals([(.flights, 100)]))
        #expect(comparison.overall == nil)
        #expect(EstimateAccuracy.compare(estimate: nil, plannedTotalCents: 10, actuals: Self.actuals([])).overall == nil)
    }

    @Test("Samples leave flights out and need something estimated")
    func samples() throws {
        let estimate = Self.estimate([40_000, 20_000, 0, 0, 30_000])
        let actuals = Self.actuals([(.lodging, 44_000), (.food, 22_000), (.flights, 90_000)])
        let sample = try #require(EstimateAccuracy.sample(estimate: estimate, actuals: actuals, endDate: .now))
        #expect(sample.error == Gap(estimatedCents: 60_000, actualCents: 66_000))
        #expect(sample.error.signedPercent == 10)
        #expect(sample.style == .budget)

        let onlyFlights = Self.actuals([(.flights, 90_000)])
        #expect(EstimateAccuracy.sample(estimate: estimate, actuals: onlyFlights, endDate: .now) == nil)
        let zero = Self.estimate([0, 0, 0, 0])
        #expect(EstimateAccuracy.sample(estimate: zero, actuals: Self.actuals([(.lodging, 5)]), endDate: .now) == nil)
    }

    // MARK: Across trips

    private func sample(_ style: TravelStyle, percent: Int, daysAgo: Int) -> EstimateAccuracy.Sample {
        EstimateAccuracy.Sample(
            style: style,
            endDate: TestSupport.date(2027, 6, 1).addingTimeInterval(Double(-daysAgo) * 86_400),
            error: Gap(estimatedCents: 10_000, actualCents: 10_000 + percent * 100)
        )
    }

    @Test("Stats are grouped by style")
    func stats() {
        let stats = EstimateAccuracy.stats([
            sample(.budget, percent: 20, daysAgo: 1), sample(.budget, percent: -10, daysAgo: 2),
            sample(.comfort, percent: 5, daysAgo: 3),
        ])
        #expect(stats.map(\.style) == [.budget, .comfort])
        #expect(stats[0].trips == 2)
        #expect(stats[0].meanSignedPercent == 5)
        #expect(stats[0].meanAbsolutePercent == 15)
        #expect(stats[1].trips == 1)
        #expect(EstimateAccuracy.stats([]).isEmpty)
    }

    @Test("The hint needs at least three comparable trips")
    func hintNeedsThree() {
        let two = [sample(.budget, percent: 20, daysAgo: 1), sample(.budget, percent: 16, daysAgo: 2)]
        #expect(EstimateAccuracy.hint(for: .budget, samples: two) == nil)

        let otherStyle = two + [sample(.standard, percent: 30, daysAgo: 3)]
        #expect(EstimateAccuracy.hint(for: .budget, samples: otherStyle) == nil, "a standard trip doesn't count for budget")

        let three = two + [sample(.budget, percent: 18, daysAgo: 3)]
        let hint = EstimateAccuracy.hint(for: .budget, samples: three)
        #expect(hint == EstimateAccuracy.Hint(style: .budget, trips: 3, percent: 18))
        #expect(hint?.text == "Your last 3 budget-style trips ran 18% over the estimate, not counting flights.")
    }

    @Test("Running under says so")
    func hintUnder() {
        let samples = (1...4).map { sample(.comfort, percent: -12, daysAgo: $0) }
        let hint = EstimateAccuracy.hint(for: .comfort, samples: samples)
        #expect(hint?.percent == -12)
        #expect(hint?.text.contains("12% under") == true)
    }

    @Test("No hint for mixed or small misses")
    func noHint() {
        let mixed = [20, -15, 30].enumerated().map { sample(.budget, percent: $1, daysAgo: $0) }
        #expect(EstimateAccuracy.hint(for: .budget, samples: mixed) == nil)
        let small = [5, 8, 4].enumerated().map { sample(.budget, percent: $1, daysAgo: $0) }
        #expect(EstimateAccuracy.hint(for: .budget, samples: small) == nil)
    }

    @Test("Only the five most recent trips count")
    func hintWindow() {
        let old = (10...14).map { sample(.budget, percent: -40, daysAgo: $0) }
        let recent = (1...5).map { sample(.budget, percent: 20, daysAgo: $0) }
        #expect(EstimateAccuracy.hint(for: .budget, samples: old + recent)?.percent == 20)
        #expect(EstimateAccuracy.hint(for: .budget, samples: old + recent)?.trips == 5)
    }

    // MARK: Logging

    @Test("Blank means not tracked; zero is a real amount")
    func draft() throws {
        var draft = ActualsDraft()
        #expect(draft.actuals(loggedAt: .now) == nil)
        draft.texts[.lodging] = "  "
        draft.texts[.food] = "abc"
        #expect(draft.actuals(loggedAt: .now) == nil)
        draft.texts[.activities] = "0"
        draft.texts[.lodging] = TestSupport.amountText("412.50")
        let actuals = try #require(draft.actuals(loggedAt: .now))
        #expect(actuals.lineItems == [.init(kind: .lodging, cents: 41_250), .init(kind: .activities, cents: 0)])
        #expect(ActualsDraft(actuals: actuals).actuals(loggedAt: actuals.loggedAt) == actuals)
    }

    @Test("Actuals are saved with the trip and feed the stats")
    @MainActor
    func persistence() throws {
        let container = try TestSupport.makeContainer()
        let context = ModelContext(container)
        let estimate = Self.estimate([40_000, 20_000, 5_000, 10_000], style: .standard)
        let trip = Trip(name: "Past", destination: "Cancún", startDate: TestSupport.date(2026, 3, 1),
                        endDate: TestSupport.date(2026, 3, 4), estimatedTotal: 750,
                        estimateSource: Trip.EstimateSource.perDiem.rawValue, estimate: estimate)
        context.insert(trip)
        try context.save()
        #expect(trip.actuals == nil)
        #expect(trip.comparison == nil)

        trip.actuals = Self.actuals([(.lodging, 46_000), (.food, 23_000), (.localTransport, 5_750), (.activities, 11_500)])
        try context.save()

        let fresh = try #require(try ModelContext(container).fetch(FetchDescriptor<Trip>()).first)
        #expect(fresh.actuals?.totalCents == 86_250)
        #expect(fresh.comparison?.overall?.signedPercent == 15)
        #expect(fresh.accuracySample?.style == .standard)
        #expect(fresh.accuracySample?.error.signedPercent == 15)
    }
}
