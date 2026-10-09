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

    /// Erste Antwort mit EUR-Betrag; sonst letzte „unavailable“-Metadaten — nie erfinden.
    func fetchFirstAvailable(for tcgdexId: String, locale: String) async throws -> FetchedPrice {
        var lastUnavailable: FetchedPrice = .unavailable
        for provider in providers {
            guard let price = try await provider.fetchPrice(for: tcgdexId, locale: locale) else {
                continue
            }
            if price.amountEUR != nil {
                return price
            }
            lastUnavailable = price
        }
        return lastUnavailable
    }
}
