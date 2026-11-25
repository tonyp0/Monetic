import Foundation
import Testing
@testable import Monetic

/// Savings plan math against fixed dates in New York, so DST changes are real.
/// The base plan saves $1,200 over 12 weeks: Mon Jan 4 to Mon Mar 29, 2027.
@Suite("Savings plan")
struct SavingsPlanTests {
    private let calendar = TripTests.calendar
    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date { TripTests.date(y, m, d, hour: hour) }

    private var jan4: Date { date(2027, 1, 4) }
    private var mar29: Date { date(2027, 3, 29) }

    private func plan(
        goal: Double = 1200,
        saved: Double = 0,
        start: Date? = nil,
        departure: Date? = nil,
        cadence: ContributionCadence = .weekly,
        asOf: Date? = nil,
        monthlyBudget: Double = 0
    ) -> SavingsPlan {
        SavingsPlan.make(
            goal: goal, saved: saved, startDate: start ?? jan4, departureDate: departure ?? mar29,
            cadence: cadence, asOf: asOf ?? jan4, calendar: calendar, monthlyBudget: monthlyBudget
        )
    }

    private func days(_ dates: [Date]) -> [String] {
        dates.map {
            let c = calendar.dateComponents([.month, .day], from: $0)
            return "\(c.month!)/\(c.day!)"
        }
    }

    // MARK: Cadences

    @Test("Each cadence splits the goal over its dates before departure", arguments: [
        (ContributionCadence.weekly, 12, 100.0),
        (.biweekly, 6, 200.0),
        (.monthly, 3, 400.0),   // Jan 4, Feb 4, Mar 4
    ])
    func cadences(cadence: ContributionCadence, periods: Int, perPeriod: Double) {
        let p = plan(cadence: cadence)
        #expect(p.periodsLeft == periods)
        #expect(p.perPeriodAmount == perPeriod)
        #expect(p.remaining == 1200)
        #expect(p.status == .onTrack, "nothing is expected on day one")
        #expect(p.expectedSavedByNow == 0)
        #expect(p.daysToGo == 84)
        #expect(!p.isUnrealistic)
        #expect(p.nextContributionDate == calendar.startOfDay(for: jan4))
    }

    @Test("Monthly dates keep their day, clamped in short months")
    func monthLengths() {
        let dates = SavingsPlan.contributionDates(
            start: date(2027, 1, 31), departure: date(2027, 6, 15), cadence: .monthly,
            from: date(2027, 1, 31), calendar: calendar
        )
        #expect(days(dates) == ["1/31", "2/28", "3/31", "4/30", "5/31"])

        let leap = SavingsPlan.contributionDates(
            start: date(2028, 1, 31), departure: date(2028, 3, 1), cadence: .monthly,
            from: date(2028, 1, 1), calendar: calendar
        )
        #expect(days(leap) == ["1/31", "2/29"])
    }

    @Test("Weekly dates stay on midnight across both DST changes")
    func dstBoundaries() {
        // Clocks go forward Mar 14, 2027 and back Nov 7, 2027 in New York.
        for (start, departure) in [(date(2027, 3, 7), date(2027, 3, 28)), (date(2027, 10, 31), date(2027, 11, 21))] {
            let dates = SavingsPlan.contributionDates(start: start, departure: departure, cadence: .weekly,
                                                      from: start, calendar: calendar)
            #expect(dates.count == 3)
            #expect(dates.allSatisfy { calendar.component(.hour, from: $0) == 0 })
            #expect(zip(dates, dates.dropFirst()).allSatisfy {
                TripDates.daysBetween($0, $1, calendar: calendar) == 7
            })
        }
        let p = plan(goal: 300, start: date(2027, 3, 7), departure: date(2027, 3, 28), asOf: date(2027, 3, 14, hour: 3))
        #expect(p.periodsLeft == 2)   // Mar 14 and Mar 21
        #expect(p.perPeriodAmount == 150)
        #expect(p.daysToGo == 14)
    }

    // MARK: Start date

    @Test("A start date in the future: nothing expected yet, saving starts then")
    func futureStart() {
        let p = plan(start: date(2027, 2, 1), asOf: date(2027, 1, 10))
        #expect(p.expectedSavedByNow == 0)
        #expect(p.status == .onTrack)
        #expect(p.periodsLeft == 8)   // Feb 1 … Mar 22
        #expect(p.nextContributionDate == calendar.startOfDay(for: date(2027, 2, 1)))
        #expect(plan(saved: 50, start: date(2027, 2, 1), asOf: date(2027, 1, 10)).status == .ahead)
    }

    @Test("A start date in the past: only the dates left are counted")
    func pastStart() {
        // Four weeks in, a third of the way there.
        let p = plan(saved: 400, asOf: date(2027, 2, 1))
        #expect(p.expectedSavedByNow == 400)
        #expect(p.status == .onTrack)
        #expect(p.periodsLeft == 8)   // Feb 1 (today) … Mar 22
        #expect(p.perPeriodAmount == 100)
    }

    // MARK: Status

    @Test("Within 5% of the expected amount is on track", arguments: [
        (379.99, SavingsPlan.Status.behind),
        (380.00, .onTrack),
        (400.00, .onTrack),
        (420.00, .onTrack),
        (420.01, .ahead),
    ])
    func onTrackBand(saved: Double, status: SavingsPlan.Status) {
        // Expected by Feb 1: $1,200 × 28/84 days = $400, so the band is $380–$420.
        #expect(plan(saved: saved, asOf: date(2027, 2, 1)).status == status)
    }

    @Test("Behind: the catch-up is what the next contribution needs to get back on the line")
    func catchUp() {
        // Feb 1 is a savings day: $400 expected by today.
        #expect(plan(saved: 0, asOf: date(2027, 2, 1)).catchUpAmount == 400)
        // Feb 2 isn't; the next is Feb 8, when $1,200 × 35/84 = $500 is expected.
        #expect(plan(saved: 0, asOf: date(2027, 2, 2)).catchUpAmount == 500)
        #expect(plan(saved: 300, asOf: date(2027, 2, 2)).catchUpAmount == 200)
        #expect(plan(saved: 400, asOf: date(2027, 2, 1)).catchUpAmount == nil, "on track: no catch-up")
    }

    @Test("Funded, and over-funded, need nothing more")
    func funded() {
        let exact = plan(saved: 1200, asOf: date(2027, 2, 1))
        #expect(exact.status == .funded)
        #expect(exact.remaining == 0)
        #expect(exact.perPeriodAmount == 0)
        #expect(!exact.isUnrealistic)

        let over = plan(saved: 1500, asOf: date(2027, 2, 1))
        #expect(over.status == .funded)
        #expect(over.remaining == 0, "remaining is never negative")
        #expect(over.progress == 1.25)
    }

    @Test("A withdrawal that drops savings below the goal reopens the plan")
    func withdrawalBelowGoal() {
        let p = plan(saved: 1200 - 300, asOf: date(2027, 3, 1))
        #expect(p.status != .funded)
        #expect(p.remaining == 300)
        #expect(p.periodsLeft == 4)   // Mar 1, 8, 15, 22
        #expect(p.perPeriodAmount == 75)
    }

    @Test("Once the trip starts the plan is over")
    func departed() {
        let p = plan(saved: 100, asOf: mar29)
        #expect(p.status == .departed)
        #expect(p.daysToGo == 0)
        #expect(p.countdownText == "Trip started")
        #expect(!p.isUnrealistic)
        #expect(p.catchUpAmount == nil)
    }

    // MARK: Rounding

    @Test("Per-period amounts round up so the goal is actually reached")
    func roundsUp() {
        // Jan 4, 11, 18 before Jan 25.
        let p = plan(goal: 100, departure: date(2027, 1, 25))
        #expect(p.periodsLeft == 3)
        #expect(p.perPeriodAmount == 33.34)
        #expect(Int((p.perPeriodAmount * 100).rounded()) * 3 >= 10_000)
        #expect(plan(goal: 99.99, departure: date(2027, 1, 25)).perPeriodAmount == 33.33)
    }

    // MARK: Unrealistic

    @Test("Leaving tomorrow with no savings day left is unrealistic")
    func departureTomorrow() {
        let p = plan(asOf: date(2027, 3, 28))   // last savings day was Mar 22
        #expect(p.daysToGo == 1)
        #expect(p.countdownText == "1 day to go")
        #expect(p.periodsLeft == 0)
        #expect(p.perPeriodAmount == 1200, "all of it, honestly")
        #expect(p.problem == .noDatesLeft)

        // If today is a savings day, there's one left.
        let today = plan(start: date(2027, 3, 28), asOf: date(2027, 3, 28))
        #expect(today.periodsLeft == 1)
        #expect(today.problem == nil)
    }

    @Test("More per period than the whole monthly budget allows is unrealistic", arguments: [
        // $1,300 a month is $300 a week, $600 every 2 weeks, $1,300 a month.
        (ContributionCadence.weekly, 300.00, false),
        (.weekly, 300.01, true),
        (.biweekly, 600.00, false),
        (.biweekly, 600.01, true),
        (.monthly, 1300.00, false),
        (.monthly, 1300.01, true),
    ])
    func moreThanBudget(cadence: ContributionCadence, goal: Double, unrealistic: Bool) {
        // One savings date: start Jan 4, leave Jan 5.
        let p = plan(goal: goal, departure: date(2027, 1, 5), cadence: cadence, monthlyBudget: 1300)
        #expect(p.periodsLeft == 1)
        #expect(p.isUnrealistic == unrealistic)
        if unrealistic {
            let limit = Double(130_000 * 12 / cadence.periodsPerYear) / 100
            #expect(p.problem == .moreThanBudget(budgetPerPeriod: limit))
        }
    }

    @Test("Without a monthly budget there's nothing to compare against")
    func noBudget() {
        #expect(!plan(goal: 1_000_000, departure: date(2027, 1, 5), monthlyBudget: 0).isUnrealistic)
    }

    // MARK: Text

    @Test("The card's wording")
    func text() {
        let usd = { (v: Double) in v.formatted(.currency(code: "USD")) }
        #expect(plan().perPeriodText(currencyCode: "USD") == "Save \(usd(100)) a week")
        #expect(plan(cadence: .monthly).perPeriodText(currencyCode: "USD") == "Save \(usd(400)) a month")
        #expect(plan().countdownText == "84 days to go")
        #expect(plan(saved: 1200).perPeriodText(currencyCode: "USD") == "You've saved the whole goal.")
        #expect(plan(asOf: date(2027, 3, 28)).perPeriodText(currencyCode: "USD")
                == "\(usd(1200)) still to save before you leave")
    }
}
