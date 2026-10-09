import Foundation

/// Herkunft eines Preiswerts – nie vermischen oder erfinden.
enum PriceSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case tcgdexCardmarket = "tcgdex_cardmarket"
    case manual = "manual"
    case lastStored = "last_stored"
    case sample = "sample"
    case unavailable = "unavailable"

    var id: String { rawValue }

    var displayNameDE: String {
        switch self {
        case .tcgdexCardmarket:
            return "TCGdex (Cardmarket-Referenz)"
        case .manual:
            return "Manuelle Bewertung"
        case .lastStored:
            return "Zuletzt gespeicherter Stand"
        case .sample:
            return "Beispieldaten (keine Marktdaten)"
        case .unavailable:
            return "Kein Marktpreis verfügbar"
        }
    }

    var isRealMarketData: Bool {
        self == .tcgdexCardmarket
    }
}
