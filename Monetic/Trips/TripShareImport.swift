import Foundation

/// Turning a validated `TripShare` into a trip, or updating the one already
/// joined from the same link. Savings are never part of a share: a new trip
/// starts at zero, and an update leaves contributions and savings settings
/// exactly as they were.
enum TripShareImport {
    /// The trip already joined (or shared) under this link, if any.
    static func existingTrip(for share: TripShare, in trips: [Trip]) -> Trip? {
        trips.first { $0.shareID == share.shareID }
    }

    /// The cadence the user picked most recently, so a joined trip saves the
    /// way they already do. Weekly if they have no trips.
    static func preferredCadence(from trips: [Trip]) -> ContributionCadence {
        trips.max { $0.createdAt < $1.createdAt }?.cadence ?? .weekly
    }

    static func makeTrip(
        from share: TripShare,
        goal: Double,
        cadence: ContributionCadence,
        now: Date,
        calendar: Calendar = .current
    ) -> Trip {
        let trip = Trip(
            name: share.name,
            destination: share.destination,
            startDate: share.startDate,
            endDate: share.endDate,
            travelers: share.travelers,
            estimatedTotal: share.total,
            estimateSource: share.source.rawValue,
            createdAt: now,
            locationID: share.locationID,
            travelStyle: share.style,
            roomsOverride: share.rooms,
            flightsTotal: share.flightsTotal,
            estimate: share.estimate,
            calendar: calendar
        )
        trip.savingsGoal = goal
        trip.contributionCadence = cadence.rawValue
        trip.shareID = share.shareID
        trip.joinedAt = now
        return trip
    }

    /// Replaces the plan on `trip` with the shared one. Contributions,
    /// cadence, savings start, reminders and notes are left alone.
    static func update(_ trip: Trip, from share: TripShare, goal: Double, calendar: Calendar = .current) {
        trip.name = share.name
        trip.destination = share.destination
        trip.startDate = calendar.startOfDay(for: share.startDate)
        trip.endDate = max(calendar.startOfDay(for: share.endDate), trip.startDate)
        trip.travelers = share.travelers
        trip.estimatedTotal = share.total
        trip.estimateSource = share.source.rawValue
        trip.locationID = share.locationID
        trip.travelStyle = share.style.rawValue
        trip.roomsOverride = share.rooms
        trip.flightsTotal = share.flightsTotal
        trip.savedEstimate = share.estimate
        trip.savingsGoal = goal
        trip.shareID = share.shareID
    }
}
