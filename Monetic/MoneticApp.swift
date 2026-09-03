import SwiftUI
import SwiftData

@main
struct MoneticApp: App {
    @AppStorage("appAppearance") var appearance: String = "system"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BudgetCategory.self,
            Transaction.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema changed during development — wipe the old store so the app
            // doesn't crash on launch. Data is re-created fresh on next run.
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeURL = appSupport.appendingPathComponent("default.store")
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not recreate ModelContainer after migration failure: \(error)")
            }
        }
    }()

    var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
