import SwiftUI
import SwiftData

/// How the app chooses Light or Dark.
/// Existing users: anyone who picked Dark or Light has it stored and keeps it.
/// Anyone who never touched the setting has nothing stored and now follows the
/// system, so no migration is needed. Unknown stored values also fall back to
/// system, because @AppStorage uses its default when init(rawValue:) fails.
enum AppAppearance: String, CaseIterable {
    case system, light, dark

    static let storageKey = "appAppearance"

    /// `nil` hands the choice to iOS.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

@main
struct MoneticApp: App {
    @AppStorage(AppAppearance.storageKey) var appearance: AppAppearance = .system

    private let store: Result<ModelContainer, Error>

    init() {
        store = Self.loadStore()
    }

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                RootView()
                    .preferredColorScheme(appearance.colorScheme)
                    .tint(Brand.accentText)
                    .modelContainer(container)
            case .failure(let error):
                StoreUnavailableView(error: error)
                    .preferredColorScheme(appearance.colorScheme)
                    .tint(Brand.accentText)
            }
        }
    }

    /// Every model the app stores. Adding a model here is a lightweight
    /// migration — `StoreMigrationTests` proves an older store still opens.
    static let schema = Schema([
        BudgetCategory.self,
        Transaction.self,
        Trip.self,
        SavingsContribution.self
    ])

    private static func loadStore() -> Result<ModelContainer, Error> {
        let schema = Self.schema

        #if DEBUG
        // Automated tests launch with -UITesting so every run starts from an
        // empty, throwaway store and first-launch settings, never real data.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-UITesting") {
            resetSettingsForTesting()
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let result = Result { try ModelContainer(for: schema, configurations: [inMemory]) }
            // Screenshot runs start from a lived-in month instead of onboarding.
            if arguments.contains("-SeedDemoData"), case .success(let container) = result {
                DemoData.seed(into: container.mainContext)
            }
            return result
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
            AppAppearance.storageKey,
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
