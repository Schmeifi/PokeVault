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
        let tcgdexId = detail.id
        let descriptor = FetchDescriptor<CardCatalogEntry>(
            predicate: #Predicate { $0.tcgdexId == tcgdexId }
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
        let fromFlags = Self.variants(from: detail.variants)
        entry.availableVariants = fromFlags.isEmpty ? detail.availableVariantLabels : fromFlags
        if let productId = detail.pricing?.cardmarket?.idProduct {
            entry.cardmarketId = String(productId)
            // Keine Cardmarket-Produkt-URL erfinden — nur ID speichern.
        } else if let productId = detail.variants_detailed?.compactMap(\.thirdParty?.cardmarket).first {
            entry.cardmarketId = String(productId)
        }
        entry.updatedAt = .now

        if existing == nil {
            context.insert(entry)
        }

        // Set-Metadaten mitziehen, sofern im Detail vorhanden.
        if let embedded = detail.set {
            let setId = embedded.id
            let setDescriptor = FetchDescriptor<PokemonSet>(
                predicate: #Predicate { $0.tcgdexSetId == setId }
            )
            let existingSet = try context.fetch(setDescriptor).first
            let set = existingSet ?? PokemonSet(tcgdexSetId: embedded.id, name: embedded.name)
            set.name = embedded.name
            set.logoURL = embedded.logo
            set.symbolURL = embedded.symbol
            set.cardCountOfficial = embedded.cardCount?.official
            set.cardCountTotal = embedded.cardCount?.total
            set.updatedAt = .now
            if existingSet == nil {
                context.insert(set)
            }
        }

        return entry
    }

    /// Importiert Kartendetail + optionalen TCGdex-Preis-Snapshot (nur vorhandene Felder).
    @discardableResult
    func importCard(
        id: String,
        locale: String,
        storePrice: Bool = true,
        in context: ModelContext
    ) async throws -> CardCatalogEntry {
        let detail = try await provider.fetchCard(id: id, locale: locale)
        let entry = try upsertCatalogEntry(from: detail, locale: locale, in: context)
        if storePrice, let price = try await provider.fetchPrice(for: id, locale: locale) {
            storePriceSnapshot(for: entry, price: price, in: context)
        }
        try context.save()
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
