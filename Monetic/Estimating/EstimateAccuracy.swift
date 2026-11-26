import Foundation

// MARK: - Actuals

/// What a trip really cost, per estimate line, in cents. A line the user
/// left blank is absent (not tracked), which isn't the same as $0.
struct TripActuals: Codable, Equatable {
    var lineItems: [TripEstimate.LineItem]
    var loggedAt: Date

    func cents(for kind: TripEstimate.Kind) -> Int? {
        lineItems.first { $0.kind == kind }?.cents
    }

    var totalCents: Int { lineItems.reduce(0) { $0 + $1.cents } }
}

// MARK: - Accuracy

/// Estimate vs actual: pure math, no SwiftData, no clock.
enum EstimateAccuracy {

    /// The gap between one estimated amount and what was spent.
    struct Gap: Equatable {
        let estimatedCents: Int
        let actualCents: Int

        /// Positive when the trip ran over.
        var differenceCents: Int { actualCents - estimatedCents }
        var absoluteCents: Int { abs(differenceCents) }
        /// Over (+) or under (−) as a percent of the estimate; nil when the
        /// estimate was zero, since no percentage of nothing means anything.
        var signedPercent: Double? {
            estimatedCents > 0 ? Double(differenceCents) / Double(estimatedCents) * 100 : nil
        }
        var absolutePercent: Double? { signedPercent.map(abs) }
    }

    struct Line: Equatable, Identifiable {
        let kind: TripEstimate.Kind
        let estimatedCents: Int?
        let actualCents: Int?
        var id: TripEstimate.Kind { kind }

        /// Only when both sides are known.
        var error: Gap? {
            guard let estimatedCents, let actualCents else { return nil }
            return Gap(estimatedCents: estimatedCents, actualCents: actualCents)
        }
    }

    struct Comparison: Equatable {
        /// Every line that has an estimate or an actual, in estimate order.
        let lines: [Line]
        /// Over the lines that have both sides, or the whole total for a trip
        /// with no breakdown. nil when there's nothing to compare.
        let overall: Gap?
        /// How many lines `overall` covers, when it covers lines.
        let comparedLines: Int
    }

    /// Compares a trip's plan with its actuals. With a breakdown, line by
    /// line; without one (a typed-in total), the totals only.
    static func compare(estimate: TripEstimate?, plannedTotalCents: Int, actuals: TripActuals) -> Comparison {
        guard let estimate else {
            let overall = actuals.lineItems.isEmpty ? nil
                : Gap(estimatedCents: plannedTotalCents, actualCents: actuals.totalCents)
            let lines = TripEstimate.Kind.allCases.compactMap { kind in
                actuals.cents(for: kind).map { Line(kind: kind, estimatedCents: nil, actualCents: $0) }
            }
            return Comparison(lines: lines, overall: overall, comparedLines: 0)
        }

        let lines = TripEstimate.Kind.allCases.compactMap { kind -> Line? in
            let estimated = estimate.lineItems.first { $0.kind == kind }?.cents
            let actual = actuals.cents(for: kind)
            return estimated == nil && actual == nil ? nil : Line(kind: kind, estimatedCents: estimated, actualCents: actual)
        }
        let both = lines.compactMap(\.error)
        let overall = both.isEmpty ? nil : Gap(
            estimatedCents: both.reduce(0) { $0 + $1.estimatedCents },
            actualCents: both.reduce(0) { $0 + $1.actualCents }
        )
        return Comparison(lines: lines, overall: overall, comparedLines: both.count)
    }

    // MARK: Across trips

    /// One past trip's estimator error, for a travel style. Flights are left
    /// out: the estimator doesn't predict them, the user types them in.
    struct Sample: Equatable {
        let style: TravelStyle
        let endDate: Date
        let error: Gap
    }

    static func sample(estimate: TripEstimate, actuals: TripActuals, endDate: Date) -> Sample? {
        let lines = compare(estimate: estimate, plannedTotalCents: estimate.totalCents, actuals: actuals)
            .lines.filter { $0.kind != .flights }.compactMap(\.error)
        let estimated = lines.reduce(0) { $0 + $1.estimatedCents }
        guard estimated > 0 else { return nil }
        return Sample(style: estimate.style, endDate: endDate,
                      error: Gap(estimatedCents: estimated, actualCents: lines.reduce(0) { $0 + $1.actualCents }))
    }

    struct StyleStats: Equatable {
        let style: TravelStyle
        let trips: Int
        /// Average over (+) or under (−), in percent.
        let meanSignedPercent: Double
        /// Average size of the miss, either way, in percent.
        let meanAbsolutePercent: Double
    }

    /// Per-style averages, in `TravelStyle` order; styles with no trips are left out.
    static func stats(_ samples: [Sample]) -> [StyleStats] {
        TravelStyle.allCases.compactMap { style in
            let percents = samples.filter { $0.style == style }.compactMap(\.error.signedPercent)
            guard !percents.isEmpty else { return nil }
            let n = Double(percents.count)
            return StyleStats(style: style, trips: percents.count,
                              meanSignedPercent: percents.reduce(0, +) / n,
                              meanAbsolutePercent: percents.map(abs).reduce(0, +) / n)
        }
    }

    struct Hint: Equatable, Identifiable {
        let style: TravelStyle
        let trips: Int
        /// Rounded, signed: 18 is 18% over, −12 is 12% under.
        let percent: Int

        /// Changes whenever the numbers do, so a dismissed hint comes back
        /// only when there's something new to say.
        var id: String { "\(style.rawValue).\(trips).\(percent)" }

        var text: String {
            "Your last \(trips) \(style.label.lowercased())-style trips ran \(abs(percent))% \(percent > 0 ? "over" : "under") the estimate, not counting flights."
        }
    }

    /// A one-line nudge when the user's recent trips in `style` all missed in
    /// the same direction by a meaningful amount on average. Needs at least
    /// `minimumTrips` comparable trips; looks at the most recent `window`.
    static func hint(
        for style: TravelStyle,
        samples: [Sample],
        minimumTrips: Int = 3,
        window: Int = 5,
        thresholdPercent: Double = 10
    ) -> Hint? {
        let recent = samples
            .filter { $0.style == style }
            .sorted { $0.endDate > $1.endDate }
            .prefix(window)
            .compactMap(\.error.signedPercent)
        guard recent.count >= minimumTrips else { return nil }
        let allOver = recent.allSatisfy { $0 > 0 }
        let allUnder = recent.allSatisfy { $0 < 0 }
        guard allOver || allUnder else { return nil }
        let mean = recent.reduce(0, +) / Double(recent.count)
        guard abs(mean) >= thresholdPercent else { return nil }
        return Hint(style: style, trips: recent.count, percent: Int(mean.rounded()))
    }
}

extension Trip {
    /// What the trip really cost, once logged.
    var actuals: TripActuals? {
        get { actualSpending.flatMap { try? JSONDecoder().decode(TripActuals.self, from: $0) } }
        set { actualSpending = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var accuracySample: EstimateAccuracy.Sample? {
        guard let estimate = savedEstimate, let actuals else { return nil }
        return EstimateAccuracy.sample(estimate: estimate, actuals: actuals, endDate: endDate)
    }

    /// Estimate vs actual for this trip, once actuals are logged.
    var comparison: EstimateAccuracy.Comparison? {
        guard let actuals else { return nil }
        return EstimateAccuracy.compare(estimate: savedEstimate,
                                        plannedTotalCents: Int((estimatedTotal * 100).rounded()),
                                        actuals: actuals)
    }
}
