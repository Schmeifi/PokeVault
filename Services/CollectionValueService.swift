import Foundation
import SwiftData

struct CollectionStats: Sendable, Equatable {
    var totalOwnedCards: Int
    var uniqueCatalogCards: Int
    var estimatedValueEUR: Double?
    var valueSourceSummary: String
    var usesSampleData: Bool
    var cardsWithoutPrice: Int

    /// Summe aller hinterlegten Kaufpreise × Anzahl (Karten ohne Kaufpreis ausgeschlossen).
    var totalPurchaseCostEUR: Double?
    /// Anzahl Exemplare ohne Kaufpreis.
    var cardsWithoutPurchasePrice: Int
    /// Summe aktueller Werte nur für bewertete Karten.
    var currentPortfolioValueEUR: Double?
    /// Unrealisierter GuV nur für Karten mit Kaufpreis UND aktuellem Wert.
    var unrealizedGainLossEUR: Double?
    /// Prozentuale Entwicklung auf Basis der GuV-Teilmenge (nil wenn Kaufsumme 0/fehlt).
    var unrealizedGainLossPercent: Double?
    /// Exemplare in der GuV-Teilmenge.
    var cardsInPnL: Int
    /// Exemplare mit aktuellem Wert (Markt oder manuell).
    var cardsWithCurrentValue: Int
    var marketValuedCards: Int
    var manuallyValuedCards: Int
}

@MainActor
enum CollectionValueService {
    static func compute(owned: [OwnedCard]) -> CollectionStats {
        let total = owned.reduce(0) { $0 + $1.quantity }
        let unique = Set(owned.compactMap { $0.catalogEntry?.id }).count

        var currentSum: Double = 0
        var pricedUnits = 0
        var missingCurrentUnits = 0
        var purchaseSum: Double = 0
        var purchaseUnits = 0
        var missingPurchaseUnits = 0
        var pnlPurchaseSum: Double = 0
        var pnlCurrentSum: Double = 0
        var pnlUnits = 0
        var usesSample = false
        var sources = Set<PriceSource>()
        var marketUnits = 0
        var manualUnits = 0

        for card in owned {
            let qty = card.quantity
            let line = card.portfolioLine()
            let resolved = card.resolvedUnitValue()

            if let purchase = card.purchasePrice {
                purchaseSum += purchase * Double(qty)
                purchaseUnits += qty
            } else {
                missingPurchaseUnits += qty
            }

            if let value = resolved.value {
                currentSum += value * Double(qty)
                pricedUnits += qty
                sources.insert(resolved.source)
                if resolved.source.isRealMarketData || resolved.source == .lastStored {
                    marketUnits += qty
                } else if resolved.source == .manual {
                    manualUnits += qty
                }
                if resolved.source == .sample {
                    usesSample = true
                }
                if let snapshots = card.catalogEntry?.priceSnapshots,
                   snapshots.contains(where: \.isSampleData) {
                    usesSample = true
                }
            } else {
                missingCurrentUnits += qty
            }

            // GuV nur wenn beide Seiten vorhanden – keine Null-Erfindung.
            if line.hasPurchase, line.hasCurrent,
               let p = line.purchaseTotal, let c = line.currentTotal {
                pnlPurchaseSum += p
                pnlCurrentSum += c
                pnlUnits += qty
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

        let unrealized: Double? = pnlUnits > 0 ? (pnlCurrentSum - pnlPurchaseSum) : nil
        let unrealizedPercent: Double?
        if pnlUnits > 0, pnlPurchaseSum != 0 {
            unrealizedPercent = ((pnlCurrentSum - pnlPurchaseSum) / pnlPurchaseSum) * 100
        } else {
            unrealizedPercent = nil
        }

        return CollectionStats(
            totalOwnedCards: total,
            uniqueCatalogCards: unique,
            estimatedValueEUR: pricedUnits > 0 ? currentSum : nil,
            valueSourceSummary: sourceSummary,
            usesSampleData: usesSample,
            cardsWithoutPrice: missingCurrentUnits,
            totalPurchaseCostEUR: purchaseUnits > 0 ? purchaseSum : nil,
            cardsWithoutPurchasePrice: missingPurchaseUnits,
            currentPortfolioValueEUR: pricedUnits > 0 ? currentSum : nil,
            unrealizedGainLossEUR: unrealized,
            unrealizedGainLossPercent: unrealizedPercent,
            cardsInPnL: pnlUnits,
            cardsWithCurrentValue: pricedUnits,
            marketValuedCards: marketUnits,
            manuallyValuedCards: manualUnits
        )
    }
}
