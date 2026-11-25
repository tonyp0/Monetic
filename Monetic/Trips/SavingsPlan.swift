import Foundation

// MARK: - Cadence

/// How often someone puts money aside for a trip. Stored on `Trip` as its
/// raw string.
enum ContributionCadence: String, CaseIterable, Codable, Identifiable {
    case weekly, biweekly, monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly:   return "Weekly"
        case .biweekly: return "Every 2 weeks"
        case .monthly:  return "Monthly"
        }
    }

    /// "Save $42 a week".
    var perPeriodPhrase: String {
        switch self {
        case .weekly:   return "a week"
        case .biweekly: return "every 2 weeks"
        case .monthly:  return "a month"
        }
    }

    /// "Save $42 this week".
    var thisPeriodPhrase: String {
        switch self {
        case .weekly:   return "this week"
        case .biweekly: return "this fortnight"
        case .monthly:  return "this month"
        }
    }

    /// Periods in a year, used to scale a monthly budget to this cadence.
    var periodsPerYear: Int {
        switch self {
        case .weekly:   return 52
        case .biweekly: return 26
        case .monthly:  return 12
        }
    }

    /// The `n`th contribution date counting from `start` (n = 0 is `start`).
    /// Monthly dates are counted from the anchor each time, so a plan
    /// started on Jan 31 saves on Feb 28 and then Mar 31, not Mar 28.
    func date(_ n: Int, from start: Date, calendar: Calendar) -> Date? {
        let date: Date?
        switch self {
        case .weekly:   date = calendar.date(byAdding: .day, value: 7 * n, to: start)
        case .biweekly: date = calendar.date(byAdding: .day, value: 14 * n, to: start)
        case .monthly:  date = calendar.date(byAdding: .month, value: n, to: start)
        }
        return date.map { calendar.startOfDay(for: $0) }
    }
}

// MARK: - Plan

/// How much to put aside for a trip, and whether the saving is on track.
/// Built by `SavingsPlan.make`, a pure function of its inputs: no clock, no
/// stored settings. Money is worked out in whole cents.
struct SavingsPlan: Equatable {
    enum Status: String, Equatable, CaseIterable {
        case ahead, onTrack, behind, funded, departed

        var label: String {
            switch self {
            case .ahead:    return "Ahead"
            case .onTrack:  return "On track"
            case .behind:   return "Behind"
            case .funded:   return "Funded"
            case .departed: return "Trip started"
            }
        }
    }

    /// Why a plan can't honestly be met.
    enum Problem: Equatable {
        /// No contribution date is left before departure, but money is.
        case noDatesLeft
        /// Each contribution would be more than the whole monthly budget,
        /// scaled to the cadence (the scaled amount is attached).
        case moreThanBudget(budgetPerPeriod: Double)
    }

    /// Saved within this fraction of the expected amount counts as on track.
    static let onTrackTolerance = 0.05

    let goal: Double
    let saved: Double
    let cadence: ContributionCadence
    /// Still to save; never negative.
    let remaining: Double
    /// Contribution dates from today up to, but not including, departure.
    let periodsLeft: Int
    /// `remaining` split over `periodsLeft`, rounded up to the cent so the
    /// goal is actually reached. All of `remaining` when no dates are left.
    let perPeriodAmount: Double
    /// Where a straight line from the start date to departure says savings
    /// should be by today.
    let expectedSavedByNow: Double
    let status: Status
    /// What the next contribution would need to be to get back on track.
    /// Only set when `.behind` and there's a date left to make it.
    let catchUpAmount: Double?
    let nextContributionDate: Date?
    /// Whole days until departure; 0 once the trip has started.
    let daysToGo: Int
    let problem: Problem?

    var isUnrealistic: Bool { problem != nil }

    /// Saved as a fraction of the goal, for the ring. Not clamped.
    var progress: Double {
        goal > 0 ? saved / goal : (saved > 0 ? 1 : 0)
    }

    // MARK: Make

    static func make(
        goal: Double,
        saved: Double,
        startDate: Date,
        departureDate: Date,
        cadence: ContributionCadence,
        asOf: Date,
        calendar: Calendar,
        monthlyBudget: Double = 0
    ) -> SavingsPlan {
        let today = calendar.startOfDay(for: asOf)
        let start = calendar.startOfDay(for: startDate)
        let departure = calendar.startOfDay(for: departureDate)

        let goalCents = max(cents(goal), 0)
        let savedCents = cents(saved)
        let remainingCents = max(goalCents - savedCents, 0)

        let dates = contributionDates(start: start, departure: departure, cadence: cadence,
                                      from: today, calendar: calendar)
        let periodsLeft = dates.count
        let perPeriodCents = periodsLeft > 0 ? ceilDiv(remainingCents, periodsLeft) : remainingCents

        let expectedCents = expected(goalCents, on: today, start: start, departure: departure, calendar: calendar)

        let status: Status
        if today >= departure {
            status = .departed
        } else if savedCents >= goalCents {
            status = .funded
        } else {
            let difference = Double(savedCents - expectedCents)
            let tolerance = Double(expectedCents) * onTrackTolerance
            if abs(difference) <= tolerance {
                status = .onTrack
            } else {
                status = difference > 0 ? .ahead : .behind
            }
        }

        var catchUpCents: Int?
        if status == .behind, let next = dates.first {
            let needed = expected(goalCents, on: next, start: start, departure: departure, calendar: calendar)
            catchUpCents = min(max(needed - savedCents, 0), remainingCents)
        }

        var problem: Problem?
        if status != .departed && status != .funded && remainingCents > 0 {
            if periodsLeft == 0 {
                problem = .noDatesLeft
            } else if monthlyBudget > 0 {
                // The whole monthly budget, spread over a year and cut into
                // this cadence's periods: $1,300/month is $300 a week.
                let budgetPerPeriodCents = cents(monthlyBudget) * 12 / cadence.periodsPerYear
                if perPeriodCents > budgetPerPeriodCents {
                    problem = .moreThanBudget(budgetPerPeriod: dollars(budgetPerPeriodCents))
                }
            }
        }

        return SavingsPlan(
            goal: dollars(goalCents),
            saved: dollars(savedCents),
            cadence: cadence,
            remaining: dollars(remainingCents),
            periodsLeft: periodsLeft,
            perPeriodAmount: dollars(perPeriodCents),
            expectedSavedByNow: dollars(expectedCents),
            status: status,
            catchUpAmount: catchUpCents.map(dollars),
            nextContributionDate: dates.first,
            daysToGo: max(TripDates.daysBetween(today, departure, calendar: calendar), 0),
            problem: problem
        )
    }

    /// Contribution dates on the cadence from `start`, from `from` onward
    /// (inclusive) and strictly before `departure`.
    static func contributionDates(
        start: Date,
        departure: Date,
        cadence: ContributionCadence,
        from: Date,
        calendar: Calendar
    ) -> [Date] {
        let start = calendar.startOfDay(for: start)
        let departure = calendar.startOfDay(for: departure)
        let from = calendar.startOfDay(for: from)
        var dates: [Date] = []
        var n = 0
        // The cap only guards against a bad calendar; a 10-year plan saving
        // weekly is about 520 dates.
        while n < 10_000, let date = cadence.date(n, from: start, calendar: calendar), date < departure {
            if date >= from { dates.append(date) }
            n += 1
        }
        return dates
    }

    // MARK: Text

    /// "38 days to go", "1 day to go", "Trip started".
    var countdownText: String {
        if status == .departed { return "Trip started" }
        return daysToGo == 1 ? "1 day to go" : "\(daysToGo) days to go"
    }

    /// "Save $42.00 a week", or what to say when there's nothing to plan.
    func perPeriodText(currencyCode: String) -> String {
        switch status {
        case .departed: return "Saving for this trip has ended."
        case .funded:   return "You've saved the whole goal."
        default:
            let amount = perPeriodAmount.formatted(.currency(code: currencyCode))
            if periodsLeft == 0 { return "\(amount) still to save before you leave" }
            return "Save \(amount) \(cadence.perPeriodPhrase)"
        }
    }

    // MARK: Cents

    private static func cents(_ amount: Double) -> Int { Int((amount * 100).rounded()) }
    private static func dollars(_ cents: Int) -> Double { Double(cents) / 100 }

    private static func ceilDiv(_ value: Int, _ divisor: Int) -> Int {
        (value + divisor - 1) / divisor
    }

    /// The straight-line amount of `goalCents` expected by `day`.
    private static func expected(_ goalCents: Int, on day: Date, start: Date, departure: Date,
                                 calendar: Calendar) -> Int {
        let total = TripDates.daysBetween(start, departure, calendar: calendar)
        guard total > 0 else { return goalCents }
        let elapsed = min(max(TripDates.daysBetween(start, day, calendar: calendar), 0), total)
        return Int((Double(goalCents) * Double(elapsed) / Double(total)).rounded())
    }
}
