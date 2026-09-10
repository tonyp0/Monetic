import SwiftUI
import SwiftData

@main
struct MoneticApp: App {
    @AppStorage("appAppearance") var appearance: String = "system"

    private let store: Result<ModelContainer, Error>

    init() {
        store = Self.loadStore()
    }

    var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                ContentView()
                    .preferredColorScheme(preferredScheme)
                    .modelContainer(container)
            case .failure(let error):
                StoreUnavailableView(error: error)
                    .preferredColorScheme(preferredScheme)
            }
        }
    }

    private static func loadStore() -> Result<ModelContainer, Error> {
        let schema = Schema([
            BudgetCategory.self,
            Transaction.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return .success(try ModelContainer(for: schema, configurations: [configuration]))
        } catch {
            #if DEBUG
            // Schema changes during development leave an incompatible store behind.
            // Wiping it is only ever acceptable here — in a release build the same
            // failure could be transient, and destroying real budget history to
            // recover from it is far worse than reporting the error.
            removeStore()
            if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
                return .success(container)
            }
            #endif
            return .failure(error)
        }
    }

    #if DEBUG
    private static func removeStore() {
        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first else { return }

        let storeURL = appSupport.appendingPathComponent("default.store")
        for url in [storeURL,
                    storeURL.appendingPathExtension("shm"),
                    storeURL.appendingPathExtension("wal")] {
            try? FileManager.default.removeItem(at: url)
        }
    }
    #endif
}

// MARK: - Store Unavailable
/// Shown when the database can't be opened. Deliberately offers no "reset"
/// action — the store is left untouched so the data is still recoverable.
struct StoreUnavailableView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("Can't Open Your Budget", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Monetic couldn't load its data. Your information hasn't been deleted. Try restarting the app — if this keeps happening, restarting your device or reinstalling from a backup usually resolves it.")
        }
        .padding()
    }
}
