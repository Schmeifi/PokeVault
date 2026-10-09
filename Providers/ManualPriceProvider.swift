import Foundation

/// Stub für manuelle / spätere Preisquellen (Phase 3 vertieft Pricing).
/// Liefert bewusst keine Netzpreise — nur die lokale manuelle Bewertung am Exemplar.
struct ManualPriceProvider: PriceProvider {
    let displayName = "Manuelle Bewertung"

    func fetchPrice(for tcgdexId: String, locale: String) async throws -> FetchedPrice? {
        // Kein API-Abruf. Manuelle Werte liegen am OwnedCard und werden dort gelesen.
        return FetchedPrice(
            amountEUR: nil,
            source: .manual,
            metric: nil,
            cardmarketProductId: nil,
            updatedAt: nil,
            note: "Manuelle Bewertung nur am Exemplar – kein Netzpreis"
        )
    }
}

/// Kette kostenloser Preisquellen. Phase 3 kann weitere legale Quellen ergänzen.
struct PriceProviderChain: Sendable {
    let providers: [any PriceProvider]

    static let `default` = PriceProviderChain(providers: [
        TCGdexProvider.shared,
        ManualPriceProvider()
    ])

    /// Erste nicht-leere, verfügbare Antwort (kein Preis erfinden).
    func fetchFirstAvailable(for tcgdexId: String, locale: String) async throws -> FetchedPrice {
        for provider in providers {
            if let price = try await provider.fetchPrice(for: tcgdexId, locale: locale),
               price.source != .unavailable || price.amountEUR != nil {
                if price.amountEUR != nil {
                    return price
                }
            }
        }
        // TCGdex kann explizit „unavailable“ mit Metadaten liefern — bevorzugen.
        if let tcgdex = providers.first(where: { $0 is TCGdexProvider }) {
            if let price = try await tcgdex.fetchPrice(for: tcgdexId, locale: locale) {
                return price
            }
        }
        return .unavailable
    }
}
