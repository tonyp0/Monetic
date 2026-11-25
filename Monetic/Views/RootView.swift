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
        .onChange(of: scenePhase) { _, phase in
            // Only the next few reminders per trip are scheduled (iOS caps
            // pending notifications), so top them up whenever the app is opened.
            if phase == .active {
                SavingsReminderCoordinator.shared.syncAll(in: modelContext)
            }
        }
    }
}
