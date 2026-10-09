import Foundation
import SwiftData

enum ModelContainerFactory {
    static let storeName = "PokeVault"

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

    struct LaunchResult {
        let container: ModelContainer
        /// True when an incompatible on-disk store was wiped (sideload upgrade / schema mismatch).
        let didResetStore: Bool
        /// True when only an in-memory store could be opened (last-resort; data will not persist).
        let isEphemeral: Bool
    }

    /// Opens the on-disk store; on schema/migration failure deletes the store and retries.
    /// Never throws for launch — falls back to in-memory so `@main` never `fatalError`s.
    static func makeResilient() -> LaunchResult {
        do {
            let container = try make(inMemory: false)
            return LaunchResult(container: container, didResetStore: false, isEphemeral: false)
        } catch {
            NSLog("[PokeVault] ModelContainer open failed: \(error). Wiping store and retrying.")
        }

        destroyPersistentStore()

        do {
            let container = try make(inMemory: false)
            return LaunchResult(container: container, didResetStore: true, isEphemeral: false)
        } catch {
            NSLog("[PokeVault] ModelContainer recreate failed: \(error). Using in-memory fallback.")
        }

        // Named in-memory config, then anonymous — both must succeed for a valid schema.
        if let container = try? make(inMemory: true) {
            return LaunchResult(container: container, didResetStore: true, isEphemeral: true)
        }
        let fallback = (try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )) ?? (try! ModelContainer(for: schema))
        return LaunchResult(container: fallback, didResetStore: true, isEphemeral: true)
    }

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Removes SwiftData store files for `storeName` (and common sidecar suffixes).
    static func destroyPersistentStore() {
        let config = ModelConfiguration(storeName, schema: schema, isStoredInMemoryOnly: false)
        let url = config.url
        let fm = FileManager.default
        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent

        let candidates: [URL] = [
            url,
            URL(fileURLWithPath: url.path + "-shm"),
            URL(fileURLWithPath: url.path + "-wal"),
            directory.appendingPathComponent(baseName + ".store"),
            directory.appendingPathComponent(baseName + ".store-shm"),
            directory.appendingPathComponent(baseName + ".store-wal"),
            directory.appendingPathComponent(baseName + ".sqlite"),
            directory.appendingPathComponent(baseName + ".sqlite-shm"),
            directory.appendingPathComponent(baseName + ".sqlite-wal")
        ]

        for fileURL in candidates {
            if fm.fileExists(atPath: fileURL.path) {
                try? fm.removeItem(at: fileURL)
                NSLog("[PokeVault] Removed store file: \(fileURL.lastPathComponent)")
            }
        }

        // Also clear any remaining files that share the store basename in Application Support.
        if let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for fileURL in contents where fileURL.lastPathComponent.hasPrefix(baseName) {
                try? fm.removeItem(at: fileURL)
                NSLog("[PokeVault] Removed related store file: \(fileURL.lastPathComponent)")
            }
        }
    }

    /// Preview-/Test-Container mit Beispieldaten (always in-memory; never touches the device store).
    @MainActor
    static func previewContainer() -> ModelContainer {
        do {
            let container = try make(inMemory: true)
            SampleDataSeeder.loadSampleData(in: container.mainContext, force: true)
            return container
        } catch {
            let launch = makeResilient()
            SampleDataSeeder.loadSampleData(in: launch.container.mainContext, force: true)
            return launch.container
        }
    }
}
