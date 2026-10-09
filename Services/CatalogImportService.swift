import Foundation
import SwiftData

/// Mappt TCGdex-Karten in lokale Katalogeinträge und optionale Preis-Snapshots.
@MainActor
final class CatalogImportService {
    private let provider: TCGdexProvider

    init(provider: TCGdexProvider = .shared) {
        self.provider = provider
    }

    func upsertCatalogEntry(
        from detail: TCGdexCardDetail,
        locale: String,
        in context: ModelContext
    ) throws -> CardCatalogEntry {
        let descriptor = FetchDescriptor<CardCatalogEntry>(
            predicate: #Predicate { $0.tcgdexId == detail.id }
        )
        let existing = try context.fetch(descriptor).first
        let entry = existing ?? CardCatalogEntry(
            tcgdexId: detail.id,
            name: detail.name,
            setId: detail.set?.id ?? "",
            number: detail.localId ?? ""
        )

        entry.name = detail.name
        var names = entry.localizedNames
        names[locale] = detail.name
        entry.localizedNames = names
        entry.setId = detail.set?.id ?? entry.setId
        entry.setName = detail.set?.name ?? entry.setName
        entry.number = detail.localId ?? entry.number
        entry.rarity = detail.rarity
        entry.types = detail.types ?? []
        entry.illustrator = detail.illustrator
        entry.imageURL = detail.image
        entry.availableVariants = Self.variants(from: detail.variants)
        if let productId = detail.pricing?.cardmarket?.idProduct {
            entry.cardmarketId = String(productId)
        } else if let productId = detail.variants_detailed?.compactMap(\.thirdParty?.cardmarket).first {
            entry.cardmarketId = String(productId)
        }
        entry.updatedAt = .now

        if existing == nil {
            context.insert(entry)
        }
        return entry
    }

    func storePriceSnapshot(
        for entry: CardCatalogEntry,
        price: FetchedPrice,
        in context: ModelContext
    ) {
        let snapshot = PriceSnapshot(
            catalogEntry: entry,
            amountEUR: price.amountEUR,
            source: price.source,
            metric: price.metric,
            isSampleData: price.source == .sample,
            capturedAt: price.updatedAt ?? .now,
            note: price.note
        )
        context.insert(snapshot)
    }

    private static func variants(from flags: TCGdexVariantsFlags?) -> [String] {
        guard let flags else { return [] }
        var result: [String] = []
        if flags.normal == true { result.append(CardVariant.normal.rawValue) }
        if flags.holo == true { result.append(CardVariant.holo.rawValue) }
        if flags.reverse == true { result.append(CardVariant.reverse.rawValue) }
        if flags.firstEdition == true { result.append(CardVariant.firstEdition.rawValue) }
        if flags.wPromo == true { result.append(CardVariant.promo.rawValue) }
        return result
    }
}
