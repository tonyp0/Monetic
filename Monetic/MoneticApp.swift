import SwiftUI
import SwiftData

@main
struct MoneticApp: App {
    // Dark is the mode the brand is designed for, so it's the default for
    // anyone who hasn't explicitly chosen otherwise.
    @AppStorage("appAppearance") var appearance: String = "dark"

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
                    .tint(Brand.accent)
                    .modelContainer(container)
            case .failure(let error):
                StoreUnavailableView(error: error)
                    .preferredColorScheme(preferredScheme)
                    .tint(Brand.accent)
            }
        }
    }

    private static func loadStore() -> Result<ModelContainer, Error> {
        let schema = Schema([
            BudgetCategory.self,
            Transaction.self
        ])

        #if DEBUG
        // Automated tests launch with -UITesting so every run starts from an
        // empty, throwaway store and first-launch settings, never real data.
        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            resetSettingsForTesting()
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return Result { try ModelContainer(for: schema, configurations: [inMemory]) }
        }
        #endif

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
    private static func resetSettingsForTesting() {
        let keys = [
            "hasCompletedOnboarding",
            "monthlyBudget",
            "budgetSetMonth",
            "repeatMonthlyBudget",
            "lastMonthlyBudget",
            "selectedCurrencyCode",
            "appAppearance",
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

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
        ZStack {
            BrandBackground()

            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Brand.warning)

                Text("Can't Open Your Budget")
                    .font(Brand.display(20, .bold))
                    .foregroundStyle(Brand.textPrimary)

                Text("Monetic couldn't load its data. Your information hasn't been deleted. Try restarting the app — if this keeps happening, restarting your device or reinstalling from a backup usually resolves it.")
                    .font(.subheadline)
                    .foregroundStyle(Brand.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .brandCard(padding: 24)
            .padding(Brand.Space.gutter)
        }
    }
}
