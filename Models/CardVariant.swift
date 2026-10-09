import Foundation

enum CardVariant: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal = "normal"
    case holo = "holo"
    case reverse = "reverse"
    case firstEdition = "firstEdition"
    case promo = "promo"
    case other = "other"

    var id: String { rawValue }

    var displayNameDE: String {
        switch self {
        case .normal: return "Normal"
        case .holo: return "Holo"
        case .reverse: return "Reverse Holo"
        case .firstEdition: return "1. Edition"
        case .promo: return "Promo"
        case .other: return "Sonstige"
        }
    }
}
