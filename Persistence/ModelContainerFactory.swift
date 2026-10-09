import Foundation
import SwiftData

enum ModelContainerFactory {
    static let schema = Schema([
        CardCatalogEntry.self,
        OwnedCard.self,
        PokemonSet.self,
        UserCollection.self,
        CollectionMembership.self,
        CollectionRule.self,
        PriceSnapshot.self,
        WishlistEntry.self,
        ThemeTag.self,
        CardScanResult.self,
        AppSettings.self
    ])

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "PokeVault",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Preview-/Test-Container mit Beispieldaten.
    @MainActor
    static func previewContainer() -> ModelContainer {
        do {
            let container = try make(inMemory: true)
            SampleDataSeeder.seedIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("Preview-ModelContainer fehlgeschlagen: \(error)")
        }
    }
}
