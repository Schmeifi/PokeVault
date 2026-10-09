import Foundation
import SwiftData

struct CollectionStats: Sendable, Equatable {
    var totalOwnedCards: Int
    var uniqueCatalogCards: Int
    var estimatedValueEUR: Double?
    var valueSourceSummary: String
    var usesSampleData: Bool
    var cardsWithoutPrice: Int
}

@MainActor
enum CollectionValueService {
    static func compute(owned: [OwnedCard]) -> CollectionStats {
        let total = owned.reduce(0) { $0 + $1.quantity }
        let unique = Set(owned.compactMap { $0.catalogEntry?.id }).count

        var sum: Double = 0
        var pricedUnits = 0
        var missingUnits = 0
        var usesSample = false
        var sources = Set<PriceSource>()

        for card in owned {
            let resolved = card.resolvedUnitValue()
            if let value = resolved.value {
                sum += value * Double(card.quantity)
                pricedUnits += card.quantity
                sources.insert(resolved.source)
                if resolved.source == .sample {
                    usesSample = true
                }
                if let snapshots = card.catalogEntry?.priceSnapshots,
                   snapshots.contains(where: \.isSampleData) {
                    usesSample = true
                }
            } else {
                missingUnits += card.quantity
            }
        }

        let sourceSummary: String
        if pricedUnits == 0 {
            sourceSummary = PriceSource.unavailable.displayNameDE
        } else if usesSample {
            sourceSummary = "Gemischt – enthält Beispieldaten (keine Marktdaten)"
        } else {
            let names = sources.map(\.displayNameDE).sorted().joined(separator: ", ")
            sourceSummary = names.isEmpty ? PriceSource.unavailable.displayNameDE : names
        }

        return CollectionStats(
            totalOwnedCards: total,
            uniqueCatalogCards: unique,
            estimatedValueEUR: pricedUnits > 0 ? sum : nil,
            valueSourceSummary: sourceSummary,
            usesSampleData: usesSample,
            cardsWithoutPrice: missingUnits
        )
    }
}
