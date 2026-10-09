import Foundation
import SwiftData

/// Speichert und liest echte Preis-Snapshots — keine erfundenen Historienpunkte.
@MainActor
enum PriceHistoryService {
    static func snapshots(for entry: CardCatalogEntry) -> [PriceSnapshot] {
        entry.priceSnapshots
            .filter { $0.amountEUR != nil }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    @discardableResult
    static func refreshFromTCGdex(
        entry: CardCatalogEntry,
        locale: String,
        in context: ModelContext,
        provider: TCGdexProvider = .shared
    ) async throws -> FetchedPrice {
        let price = try await PriceProviderChain.default.fetchFirstAvailable(
            for: entry.tcgdexId,
            locale: locale
        )
        CatalogImportService(provider: provider).storePriceSnapshot(
            for: entry,
            price: price,
            in: context
        )
        try context.save()
        return price
    }
}
