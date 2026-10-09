import SwiftUI
import SwiftData

@main
struct PokeVaultApp: App {
    private let container: ModelContainer
    /// Set when an incompatible store was wiped on launch (e.g. 0.2 → 0.3 schema).
    private let didResetStore: Bool

    init() {
        // Never fatalError here — a failed ModelContainer used to crash before any UI painted.
        let launch = ModelContainerFactory.makeResilient()
        container = launch.container
        didResetStore = launch.didResetStore || launch.isEphemeral
        SampleDataSeeder.seedIfNeeded(in: container.mainContext)
        if didResetStore {
            NSLog("[PokeVault] Launched after store recovery (reset=\(launch.didResetStore), ephemeral=\(launch.isEphemeral)).")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
