import SwiftUI

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

    @State private var selection: Tab = .budget

    init() {
        BrandTabBar.applyAppearance()
    }

    var body: some View {
        TabView(selection: $selection) {
            ContentView()
                .tabItem {
                    Label("Budget", systemImage: "chart.pie.fill")
                        .accessibilityIdentifier("budgetTab")
                }
                .tag(Tab.budget)

            TripsView()
                .tabItem {
                    Label("Trips", systemImage: "airplane")
                        .accessibilityIdentifier("tripsTab")
                }
                .tag(Tab.trips)
        }
        .tint(Brand.accent)
    }
}
