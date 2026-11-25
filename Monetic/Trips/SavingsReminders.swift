import Foundation
import UserNotifications

// MARK: - Reminder

/// One local notification on a contribution date.
struct SavingsReminder: Equatable {
    static let identifierPrefix = "savings-reminder."

    let identifier: String
    let tripID: UUID
    /// Year, month, day, hour and minute in the user's calendar.
    let fireDate: DateComponents
    let title: String
    let body: String
}

/// What the app needs from the notification system. Tests use a fake so
/// they can check what would be scheduled without touching
/// `UNUserNotificationCenter`.
protocol ReminderScheduling: AnyObject {
    /// Asks the user for permission. Only called when they turn reminders on.
    func requestAuthorization() async -> Bool
    func pendingIdentifiers() async -> [String]
    func add(_ reminders: [SavingsReminder]) async
    func remove(identifiers: [String]) async
}

// MARK: - Planning

/// Which reminders should be pending. Pure: everything comes in as values.
enum SavingsReminders {
    /// Reminders go off at 9 a.m. on a contribution date.
    static let hour = 9
    /// Only the next few per trip are scheduled; `sync` tops them up each
    /// time the app becomes active.
    static let perTripLimit = 4
    /// iOS keeps at most 64 pending local notifications per app; stay under it.
    static let totalLimit = 60

    /// A trip's savings settings, copied out of the model.
    struct TripInfo: Equatable {
        let id: UUID
        let name: String
        let remindersEnabled: Bool
        let goal: Double
        let saved: Double
        let savingsStart: Date
        let departure: Date
        let cadence: ContributionCadence
        let currencyCode: String
    }

    static func plan(_ trips: [TripInfo], asOf now: Date, calendar: Calendar,
                     perTrip: Int = perTripLimit, total: Int = totalLimit) -> [SavingsReminder] {
        var reminders: [(date: Date, reminder: SavingsReminder)] = []

        for trip in trips where trip.remindersEnabled {
            let plan = SavingsPlan.make(
                goal: trip.goal, saved: trip.saved, startDate: trip.savingsStart,
                departureDate: trip.departure, cadence: trip.cadence, asOf: now, calendar: calendar
            )
            guard plan.status != .funded, plan.status != .departed, plan.remaining > 0 else { continue }

            let amount = plan.perPeriodAmount.formatted(.currency(code: trip.currencyCode))
            let dates = SavingsPlan.contributionDates(
                start: trip.savingsStart, departure: trip.departure, cadence: trip.cadence,
                from: now, calendar: calendar
            )
            var added = 0
            for day in dates where added < perTrip {
                guard let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                      fire > now else { continue }
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let key = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
                reminders.append((fire, SavingsReminder(
                    identifier: "\(SavingsReminder.identifierPrefix)\(trip.id.uuidString).\(key)",
                    tripID: trip.id,
                    fireDate: components,
                    title: trip.name,
                    body: "\(trip.name): time to put \(amount) aside."
                )))
                added += 1
            }
        }

        return reminders
            .sorted { ($0.date, $0.reminder.identifier) < ($1.date, $1.reminder.identifier) }
            .prefix(max(total, 0))
            .map(\.reminder)
    }
}

extension Trip {
    var reminderInfo: SavingsReminders.TripInfo {
        SavingsReminders.TripInfo(
            id: id, name: name, remindersEnabled: remindersEnabled, goal: effectiveSavingsGoal,
            saved: totalSaved, savingsStart: savingsStart(), departure: startDate,
            cadence: cadence, currencyCode: totalCurrencyCode
        )
    }
}

// MARK: - Syncing

/// Keeps pending notifications matching the trips. Every change (a new
/// contribution, a new cadence, a deleted or funded trip) is handled the
/// same way: replace Monetic's pending savings reminders with the plan.
@MainActor
final class SavingsReminderCoordinator {
    static let shared = SavingsReminderCoordinator(scheduler: SystemReminderScheduler())

    let scheduler: ReminderScheduling

    init(scheduler: ReminderScheduling) {
        self.scheduler = scheduler
    }

    /// Never asks for permission: that only happens in `requestPermission`.
    func sync(_ trips: [SavingsReminders.TripInfo], asOf now: Date, calendar: Calendar = .current) async {
        let wanted = SavingsReminders.plan(trips, asOf: now, calendar: calendar)
        let ours = await scheduler.pendingIdentifiers().filter { $0.hasPrefix(SavingsReminder.identifierPrefix) }
        if !ours.isEmpty { await scheduler.remove(identifiers: ours) }
        if !wanted.isEmpty { await scheduler.add(wanted) }
    }

    func sync(_ trips: [Trip], asOf now: Date) async {
        await sync(trips.map(\.reminderInfo), asOf: now)
    }

    /// Called when the user turns reminders on for a trip.
    func requestPermission() async -> Bool {
        await scheduler.requestAuthorization()
    }
}

// MARK: - System

/// The real notification center.
final class SystemReminderScheduler: ReminderScheduling {
    private var center: UNUserNotificationCenter { .current() }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func add(_ reminders: [SavingsReminder]) async {
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.fireDate, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.identifier,
                                                        content: content, trigger: trigger))
        }
    }

    func remove(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
