import Foundation

/// Flexibles Protokoll für Preisquellen (nur kostenlose, legale Quellen).
protocol PriceProvider: Sendable {
    var displayName: String { get }
    func fetchPrice(for tcgdexId: String, locale: String) async throws -> FetchedPrice?
}

struct FetchedPrice: Sendable, Equatable {
    let amountEUR: Double?
    let source: PriceSource
    let metric: String?
    let cardmarketProductId: String?
    let updatedAt: Date?
    let note: String?

    static let unavailable = FetchedPrice(
        amountEUR: nil,
        source: .unavailable,
        metric: nil,
        cardmarketProductId: nil,
        updatedAt: nil,
        note: "Kein Marktpreis verfügbar"
    )
}
