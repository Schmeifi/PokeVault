import SwiftUI
import SwiftData

@main
struct PokeVaultApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainerFactory.make()
            SampleDataSeeder.seedIfNeeded(in: container.mainContext)
        } catch {
            fatalError("SwiftData-Container konnte nicht erstellt werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
