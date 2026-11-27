import Foundation
import SwiftData
import Testing
@testable import Monetic

/// Contributions in a real (in-memory) store: they belong to their trip, they
/// add up, they never touch a group, and they come out of the monthly budget
/// for the month they were saved in.
@Suite("Savings contributions")
@MainActor
struct SavingsContributionTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let march = TestSupport.date(2027, 3, 10)

    init() throws {
        container = try TestSupport.makeContainer()
        context = ModelContext(container)
    }

    /// Saved before any contribution is added, as the app does.
    private func makeTrip(total: Double = 2400, travelers: Int = 2) throws -> Trip {
        let trip = Trip(name: "Spring Break", destination: "Cancún", startDate: TestSupport.date(2027, 6, 1),
                        endDate: TestSupport.date(2027, 6, 8), travelers: travelers, estimatedTotal: total,
                        createdAt: TestSupport.date(2027, 1, 4))
        context.insert(trip)
        try context.save()
        return trip
    }

    @discardableResult
    private func contribute(_ amount: Double, to trip: Trip, on date: Date? = nil, notes: String = "") throws -> SavingsContribution {
        let contribution = SavingsContribution(amount: amount, date: date ?? march, notes: notes, trip: trip,
                                               createdAt: date ?? march)
        context.insert(contribution)
        try context.save()
        return contribution
    }

    /// The dashboard's spent total, worked out exactly as `ContentView` does.
    private func dashboardTotal(asOf date: Date) throws -> Double {
        try context.fetch(FetchDescriptor<BudgetCategory>()).map { $0.monthlySpending(asOf: date) }.reduce(0, +)
    }

    // MARK: Budget isolation

    @Test("Saving for a trip never changes a group's spending or the spent total")
    func budgetUntouched() throws {
        let food = try TestSupport.makeGroup("Food", monthlyBudget: 400, in: context)
        let fun = try TestSupport.makeGroup("Fun", monthlyBudget: 200, in: context)
        try TestSupport.addTransaction(120.50, to: food, on: march, in: context)
        try TestSupport.addTransaction(60, to: fun, on: march, isRecurring: true, recurringFrequency: "monthly", in: context)

        let before = try dashboardTotal(asOf: march)
        let foodBefore = food.monthlySpending(asOf: march)
        let funBefore = fun.monthlySpending(asOf: march)
        let transactionsBefore = try context.fetchCount(FetchDescriptor<Transaction>())
        #expect(before == 180.50)

        let trip = try makeTrip()
        try contribute(500, to: trip)
        try contribute(250.25, to: trip, on: TestSupport.date(2027, 3, 1))
        try contribute(-100, to: trip)
        try contribute(75, to: trip, on: TestSupport.date(2027, 4, 2))

        #expect(try dashboardTotal(asOf: march) == before)
        #expect(food.monthlySpending(asOf: march) == foodBefore)
        #expect(fun.monthlySpending(asOf: march) == funBefore)
        #expect(food.isOverBudget(asOf: march) == false)
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == transactionsBefore)
        #expect(try dashboardTotal(asOf: TestSupport.date(2027, 4, 15)) == 60, "April: only the recurring expense")
        #expect(trip.totalSaved == 725.25)
    }

    @Test("Money put aside this month comes out of the monthly budget, net of withdrawals")
    func setAsideThisMonth() throws {
        let code = Currency.code
        let trip = try makeTrip()
        let other = try makeTrip()
        try contribute(500, to: trip)
        try contribute(250.25, to: other, on: TestSupport.date(2027, 3, 1))
        try contribute(-100, to: trip)
        try contribute(75, to: trip, on: TestSupport.date(2027, 4, 2))
        try contribute(40, to: trip, on: TestSupport.date(2026, 3, 10))   // same month, last year

        #expect(Trip.setAside(in: [trip, other], monthOf: march, currencyCode: code) == 650.25)
        #expect(Trip.setAside(in: [trip, other], monthOf: TestSupport.date(2027, 4, 30), currencyCode: code) == 75)
        #expect(Trip.setAside(in: [trip, other], monthOf: TestSupport.date(2027, 5, 1), currencyCode: code) == 0)
        #expect(Trip.setAside(in: [], monthOf: march, currencyCode: code) == 0)
    }

    @Test("Withdrawing earlier savings never adds to this month's budget")
    func withdrawalFloor() throws {
        let trip = try makeTrip()
        try contribute(300, to: trip, on: TestSupport.date(2027, 2, 10))
        try contribute(-200, to: trip)
        #expect(Trip.setAside(in: [trip], monthOf: march, currencyCode: Currency.code) == 0)
    }

    @Test("Trips in another currency don't come out of the budget")
    func otherCurrencyLeftOut() throws {
        let trip = Trip(name: "Paris", destination: "Paris", startDate: TestSupport.date(2027, 6, 1),
                        endDate: TestSupport.date(2027, 6, 8), travelers: 2, estimatedTotal: 3000,
                        estimateSource: Trip.EstimateSource.perDiem.rawValue, createdAt: TestSupport.date(2027, 1, 4))
        context.insert(trip)
        try context.save()
        try contribute(200, to: trip)

        #expect(trip.totalCurrencyCode == "USD")
        #expect(Trip.setAside(in: [trip], monthOf: march, currencyCode: "USD") == 200)
        #expect(Trip.setAside(in: [trip], monthOf: march, currencyCode: "EUR") == 0)
    }

    // MARK: Relationship

    @Test("Deleting a trip deletes its contributions")
    func cascadeDelete() throws {
        let trip = try makeTrip()
        let other = try makeTrip()
        try contribute(100, to: trip)
        try contribute(50, to: trip)
        try contribute(30, to: other)
        #expect(try context.fetchCount(FetchDescriptor<SavingsContribution>()) == 3)

        context.delete(trip)
        try context.save()

        let left = try context.fetch(FetchDescriptor<SavingsContribution>())
        #expect(left.count == 1)
        #expect(left.first?.trip?.id == other.id)
    }

    @Test("Deposits minus withdrawals, to the cent, and newest first")
    func totals() throws {
        let trip = try makeTrip()
        try contribute(0.10, to: trip, on: TestSupport.date(2027, 2, 1))
        try contribute(0.20, to: trip, on: TestSupport.date(2027, 3, 1))
        let withdrawal = try contribute(-0.05, to: trip, on: TestSupport.date(2027, 2, 15))
        #expect(trip.totalSaved == 0.25)
        #expect(trip.sortedContributions.map(\.amount) == [0.20, -0.05, 0.10])
        #expect(withdrawal.isWithdrawal)

        context.delete(withdrawal)
        try context.save()
        #expect(trip.totalSaved == 0.30)

        let fresh = try #require(try ModelContext(container).fetch(FetchDescriptor<Trip>()).first { $0.id == trip.id })
        #expect(fresh.totalSaved == 0.30)
    }

    // MARK: Goal

    @Test("The goal starts as one traveler's share and follows the total until changed")
    func goalFollowsShare() throws {
        let trip = try makeTrip(total: 1000, travelers: 3)
        #expect(trip.savingsGoal == 333.34, "rounded up so three shares cover the trip")
        #expect(trip.savingsGoalFollowsShare)

        var draft = TripDraft(trip: trip)
        draft.amountText = TestSupport.amountText("3000")
        #expect(draft.apply(to: trip))
        #expect(trip.savingsGoal == 1000)

        trip.savingsGoal = 800
        draft.amountText = TestSupport.amountText("6000")
        #expect(draft.apply(to: trip))
        #expect(trip.savingsGoal == 800, "a goal the user set is kept")
    }

    @Test("Trips from before savings existed use their share as the goal")
    func legacyGoal() throws {
        let trip = try makeTrip(total: 2400, travelers: 2)
        trip.savingsGoal = 0
        trip.savingsStartDate = nil
        #expect(trip.effectiveSavingsGoal == 1200)
        #expect(trip.savingsStart() == Calendar.current.startOfDay(for: trip.createdAt))
        #expect(trip.cadence == .weekly)
        #expect(!trip.remindersEnabled)
    }

    // MARK: Forms

    @Test("Add to Savings: a positive amount, not in the future, and no overdrawing")
    func contributionDraft() throws {
        let trip = try makeTrip()
        try contribute(100, to: trip)
        let today = TestSupport.date(2027, 3, 20)

        var draft = ContributionDraft(date: today)
        #expect(!draft.isValid(savedExcludingThis: 100, asOf: today))
        draft.amountText = TestSupport.amountText("40.50")
        #expect(draft.isValid(savedExcludingThis: 100, asOf: today))

        draft.isWithdrawal = true
        #expect(draft.signedAmount == -40.50)
        #expect(draft.isValid(savedExcludingThis: 100, asOf: today))
        draft.amountText = TestSupport.amountText("100.01")
        #expect(!draft.isValid(savedExcludingThis: 100, asOf: today))
        #expect(draft.problem(savedExcludingThis: 100, currencyCode: "USD") != nil)

        draft.amountText = "25"
        draft.date = TestSupport.date(2027, 3, 21)
        #expect(!draft.isValid(savedExcludingThis: 100, asOf: today), "no future contributions")

        draft.date = today
        draft.notes = "  ATM  "
        let made = try #require(draft.insertContribution(for: trip, in: context, createdAt: today))
        #expect(made.trip?.id == trip.id)
        #expect(made.amount == -25)
        #expect(made.notes == "ATM")
        #expect(made.date == Calendar.current.startOfDay(for: today))
    }

    @Test("Editing a contribution changes it in place")
    func editContribution() throws {
        let trip = try makeTrip()
        let contribution = try contribute(100, to: trip, notes: "Paycheck")
        var draft = ContributionDraft(contribution: contribution)
        #expect(AmountInput.cents(draft.amountText) == 10_000)
        #expect(!draft.isWithdrawal)
        #expect(draft.notes == "Paycheck")

        draft.amountText = TestSupport.amountText("80")
        #expect(draft.apply(to: contribution))
        try context.save()
        #expect(trip.totalSaved == 80)
        // It can't become an $80 withdrawal: there'd be nothing to take it from.
        draft.isWithdrawal = true
        #expect(!draft.isValid(savedExcludingThis: trip.totalSaved - contribution.amount, asOf: march))

        // A $50 withdrawal relies on that deposit: it can't drop below $50.
        try contribute(-50, to: trip)
        draft.isWithdrawal = false
        draft.amountText = TestSupport.amountText("40")
        let others = trip.totalSaved - contribution.amount
        #expect(others == -50)
        #expect(!draft.isValid(savedExcludingThis: others, asOf: march))
        let message = try #require(draft.problem(savedExcludingThis: others, currencyCode: "USD"))
        #expect(message.contains(50.0.formatted(.currency(code: "USD"))))
        draft.amountText = "50"
        #expect(draft.isValid(savedExcludingThis: others, asOf: march))
        #expect(draft.problem(savedExcludingThis: others, currencyCode: "USD") == nil)
    }

    @Test("The savings plan sheet saves goal, cadence, start and reminders")
    func planDraft() throws {
        let trip = try makeTrip()
        var draft = SavingsPlanDraft(trip: trip)
        #expect(AmountInput.cents(draft.goalText) == 120_000)
        draft.goalText = "900"
        draft.cadence = .monthly
        draft.startDate = TestSupport.date(2027, 2, 1)
        draft.remindersEnabled = true
        #expect(draft.apply(to: trip))
        #expect(trip.savingsGoal == 900)
        #expect(trip.cadence == .monthly)
        #expect(trip.savingsStart() == Calendar.current.startOfDay(for: TestSupport.date(2027, 2, 1)))
        #expect(trip.remindersEnabled)

        draft.goalText = "0"
        #expect(!draft.apply(to: trip))
        draft.goalText = "900"
        draft.startDate = TestSupport.date(2027, 7, 1)
        #expect(!draft.apply(to: trip), "saving can't start after departure")
    }

    // MARK: Dashboard card

    @Test("The dashboard shows the soonest trip that hasn't started, and counts the rest")
    func dashboardPick() throws {
        let now = TestSupport.date(2027, 3, 1)
        func trip(_ name: String, _ start: Date, _ end: Date) -> Trip {
            Trip(name: name, destination: "", startDate: start, endDate: end, estimatedTotal: 100)
        }
        #expect(UpcomingTripCard.pick(from: [], asOf: now) == nil)

        let past = trip("Past", TestSupport.date(2027, 1, 1), TestSupport.date(2027, 1, 5))
        let now1 = trip("Now", TestSupport.date(2027, 2, 27), TestSupport.date(2027, 3, 3))
        #expect(UpcomingTripCard.pick(from: [past, now1], asOf: now) == nil, "past and in-progress trips don't count")

        let later = trip("Later", TestSupport.date(2027, 8, 1), TestSupport.date(2027, 8, 5))
        let soon = trip("Soon", TestSupport.date(2027, 4, 1), TestSupport.date(2027, 4, 5))
        let one = try #require(UpcomingTripCard.pick(from: [past, later], asOf: now))
        #expect(one.trip.name == "Later")
        #expect(one.more == 0)

        let several = try #require(UpcomingTripCard.pick(from: [later, past, now1, soon], asOf: now))
        #expect(several.trip.name == "Soon")
        #expect(several.more == 1)
    }
}
