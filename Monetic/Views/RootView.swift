import SwiftUI
import SwiftData

/// The app's top level: the monthly budget and trip planning, side by side.
///
/// Onboarding stays where it was, as a `fullScreenCover` on `ContentView`. A
/// full-screen cover is presented over the whole window, so it still covers
/// this tab bar, and `ContentView` is the first tab, so it's on screen at
/// launch to present it.
struct RootView: View {
    enum Tab: Hashable {
        case budget, trips
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: Tab = .budget
    /// A trip the Budget tab asked to open on the Trips tab.
    @State private var tripToOpen: UUID?

    // Trip links. Held until onboarding and the month's budget prompt are
    // out of the way, so the join sheet never fights them for the screen.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("budgetSetMonth") private var budgetSetMonth = ""
    @State private var incomingShare: IncomingShare?
    @State private var shareError: TripShareError?

    struct IncomingShare: Identifiable {
        let id = UUID()
        let share: TripShare
        let existing: Trip?
    }

    private var readyForLinks: Bool {
        hasCompletedOnboarding && budgetSetMonth == MonthKey.key()
    }

    init() {
        BrandTabBar.applyAppearance()
    }

    var body: some View {
        TabView(selection: $selection) {
            ContentView(onOpenTrip: { id in
                tripToOpen = id
                selection = .trips
            })
                .tabItem {
                    Label("Budget", systemImage: "chart.pie.fill")
                        .accessibilityIdentifier("budgetTab")
                }
                .tag(Tab.budget)

            TripsView(tripToOpen: $tripToOpen)
                .tabItem {
                    Label("Trips", systemImage: "airplane")
                        .accessibilityIdentifier("tripsTab")
                }
                .tag(Tab.trips)
        }
        .tint(Brand.accent)
        .onOpenURL(perform: open)
        .onAppear(perform: openLaunchArgumentURL)
        .sheet(item: Binding(
            get: { readyForLinks ? incomingShare : nil },
            set: { incomingShare = $0 }
        )) { incoming in
            JoinTripView(share: incoming.share, existing: incoming.existing) { goal in
                join(incoming, goal: goal)
            }
        }
        .alert(
            shareError?.title ?? "",
            isPresented: Binding(
                get: { readyForLinks && shareError != nil },
                set: { if !$0 { shareError = nil } }
            ),
            presenting: shareError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
        .onChange(of: scenePhase) { _, phase in
            // Only the next few reminders per trip are scheduled (iOS caps
            // pending notifications), so top them up whenever the app is opened.
            if phase == .active {
                SavingsReminderCoordinator.shared.syncAll(in: modelContext)
            }
        }
    }
    // MARK: Trip links

    /// Validates a link and shows the join sheet, or a friendly error.
    private func open(_ url: URL) {
        do {
            let share = try TripShare.decode(url, store: CostDataStore.shared)
            let trips = (try? modelContext.fetch(FetchDescriptor<Trip>())) ?? []
            incomingShare = IncomingShare(share: share, existing: TripShareImport.existingTrip(for: share, in: trips))
            shareError = nil
        } catch let error as TripShareError {
            shareError = error
        } catch {
            shareError = .malformed
        }
    }

    /// UI tests can't tap a link, so in debug builds
    /// `-UITestingOpenURL <url>` is handled as if the link had been opened.
    private func openLaunchArgumentURL() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-UITestingOpenURL"), index + 1 < arguments.count,
           let url = URL(string: arguments[index + 1]) {
            open(url)
        }
        #endif
    }

    private func join(_ incoming: IncomingShare, goal: Double) {
        let trip: Trip
        if let existing = incoming.existing {
            TripShareImport.update(existing, from: incoming.share, goal: goal)
            trip = existing
        } else {
            let trips = (try? modelContext.fetch(FetchDescriptor<Trip>())) ?? []
            trip = TripShareImport.makeTrip(from: incoming.share, goal: goal,
                                            cadence: TripShareImport.preferredCadence(from: trips), now: Date())
            modelContext.insert(trip)
        }
        try? modelContext.save()
        SavingsReminderCoordinator.shared.syncAll(in: modelContext)
        tripToOpen = trip.id
        selection = .trips
    }
}
