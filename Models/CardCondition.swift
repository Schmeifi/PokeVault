import Foundation

/// Kartenzustand gemäß gängiger TCG-/Cardmarket-Stufen.
enum CardCondition: String, Codable, CaseIterable, Identifiable, Sendable {
    case mint = "Mint"
    case nearMint = "Near Mint"
    case excellent = "Excellent"
    case good = "Good"
    case lightPlayed = "Light Played"
    case played = "Played"
    case poor = "Poor"

    var id: String { rawValue }

    var displayNameDE: String {
        switch self {
        case .mint: return "Mint"
        case .nearMint: return "Near Mint"
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .lightPlayed: return "Light Played"
        case .played: return "Played"
        case .poor: return "Poor"
        }
    }

    var sortOrder: Int {
        switch self {
        case .mint: return 0
        case .nearMint: return 1
        case .excellent: return 2
        case .good: return 3
        case .lightPlayed: return 4
        case .played: return 5
        case .poor: return 6
        }
    }
}
