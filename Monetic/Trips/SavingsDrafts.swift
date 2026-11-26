import Foundation
import SwiftData

// MARK: - Contribution draft

/// The editable state behind Add to Savings and Edit Contribution. The rules
/// for when Save is allowed live here so they can be tested without a view.
struct ContributionDraft: Equatable {
    var amountText: String = ""
    var isWithdrawal: Bool = false
    var date: Date
    var notes: String = ""

    init(amountText: String = "", isWithdrawal: Bool = false, date: Date, notes: String = "") {
        self.amountText = amountText
        self.isWithdrawal = isWithdrawal
        self.date = date
        self.notes = notes
    }

    /// The current values of a saved contribution, for editing.
    init(contribution: SavingsContribution) {
        self.init(
            amountText: AmountInput.text(cents: abs(Int((contribution.amount * 100).rounded())),
                                        code: contribution.trip?.totalCurrencyCode ?? Currency.code),
            isWithdrawal: contribution.isWithdrawal,
            date: contribution.date,
            notes: contribution.notes
        )
    }

    /// The typed amount with its sign: negative for a withdrawal.
    var signedAmount: Double? {
        guard let cents = AmountInput.cents(amountText), cents > 0 else { return nil }
        return Double(isWithdrawal ? -cents : cents) / 100
    }

    /// Save needs a positive amount, a date no later than today, and a
    /// withdrawal no bigger than what's saved. `savedExcludingThis` is the
    /// trip's total without the contribution being edited.
    func isValid(savedExcludingThis: Double, asOf today: Date, calendar: Calendar = .current) -> Bool {
        guard let amount = signedAmount else { return false }
        guard TripDates.daysBetween(date, today, calendar: calendar) >= 0 else { return false }
        return Int(((savedExcludingThis + amount) * 100).rounded()) >= 0
    }

    /// Why Save is off, when the reason isn't obvious.
    func problem(savedExcludingThis: Double, currencyCode: String) -> String? {
        guard let amount = signedAmount,
              Int(((savedExcludingThis + amount) * 100).rounded()) < 0 else { return nil }
        if amount < 0 {
            let saved = max(savedExcludingThis, 0).formatted(.currency(code: currencyCode))
            return "You can take out at most \(saved), what's saved so far."
        }
        // Lowering a deposit that later withdrawals depend on.
        let minimum = (-savedExcludingThis).formatted(.currency(code: currencyCode))
        return "This has to be at least \(minimum), or your withdrawals would take out more than you saved."
    }

    /// Inserts the contribution into `context` and links it to `trip`, in that
    /// order: on iOS 17/18, SwiftData drops a link set before insert when the
    /// trip has unsaved changes in the same save.
    @discardableResult
    func insertContribution(for trip: Trip, in context: ModelContext, createdAt: Date,
                            calendar: Calendar = .current) -> SavingsContribution? {
        guard let amount = signedAmount else { return nil }
        let contribution = SavingsContribution(amount: amount, date: date, notes: trimmedNotes,
                                               createdAt: createdAt, calendar: calendar)
        context.insert(contribution)
        contribution.trip = trip
        return contribution
    }

    @discardableResult
    func apply(to contribution: SavingsContribution, calendar: Calendar = .current) -> Bool {
        guard let amount = signedAmount else { return false }
        contribution.amount = amount
        contribution.date = calendar.startOfDay(for: date)
        contribution.notes = trimmedNotes
        return true
    }

    private var trimmedNotes: String { notes.trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Plan draft

/// The editable state behind the Savings Plan settings sheet.
struct SavingsPlanDraft: Equatable {
    var goalText: String
    var cadence: ContributionCadence
    var startDate: Date
    var remindersEnabled: Bool

    init(trip: Trip, calendar: Calendar = .current) {
        goalText = AmountInput.text(cents: Int((trip.effectiveSavingsGoal * 100).rounded()), code: trip.totalCurrencyCode)
        cadence = trip.cadence
        startDate = trip.savingsStart(calendar: calendar)
        remindersEnabled = trip.remindersEnabled
    }

    var goal: Double? {
        AmountInput.cents(goalText).flatMap { $0 > 0 ? Double($0) / 100 : nil }
    }

    func isValid(departure: Date, calendar: Calendar = .current) -> Bool {
        goal != nil && TripDates.daysBetween(startDate, departure, calendar: calendar) >= 0
    }

    @discardableResult
    func apply(to trip: Trip, calendar: Calendar = .current) -> Bool {
        guard isValid(departure: trip.startDate, calendar: calendar), let goal else { return false }
        trip.savingsGoal = goal
        trip.contributionCadence = cadence.rawValue
        trip.savingsStartDate = calendar.startOfDay(for: startDate)
        trip.remindersEnabled = remindersEnabled
        return true
    }
}
