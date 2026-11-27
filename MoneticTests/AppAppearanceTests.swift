import Foundation
import SwiftUI
import Testing
@testable import Monetic

/// The stored appearance setting and the colour scheme it asks iOS for.
@Suite("App appearance")
struct AppAppearanceTests {
    @Test("Each stored value maps to its colour scheme", arguments: [
        ("system", nil),
        ("light", ColorScheme.light),
        ("dark", ColorScheme.dark),
    ] as [(String, ColorScheme?)])
    func storedValueMapsToScheme(stored: String, expected: ColorScheme?) {
        #expect(AppAppearance(rawValue: stored)?.colorScheme == expected)
    }

    @Test("Nothing stored or an unknown value follows the system", arguments: [nil, "sepia"] as [String?])
    func missingOrUnknownFollowsSystem(stored: String?) throws {
        let suite = "AppAppearanceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(stored, forKey: AppAppearance.storageKey)

        // The same @AppStorage declaration the app and Settings use.
        let appearance = AppStorage(wrappedValue: AppAppearance.system, AppAppearance.storageKey, store: defaults)
        #expect(appearance.wrappedValue == .system)
        #expect(appearance.wrappedValue.colorScheme == nil)
    }
}
