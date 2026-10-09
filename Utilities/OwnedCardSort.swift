import Foundation

/// Sortieroptionen für „Meine Karten“.
enum OwnedCardSort: String, CaseIterable, Identifiable, Sendable {
    case updatedDesc
    case nameAsc
    case nameDesc
    case setAsc
    case numberAsc
    case rarityAsc
    case valueDesc
    case valueAsc
    case conditionAsc
    case createdDesc
    case createdAsc
    case purchaseDateDesc

    var id: String { rawValue }

    var titleDE: String {
        switch self {
        case .updatedDesc: return "Zuletzt geändert"
        case .nameAsc: return "Name A–Z"
        case .nameDesc: return "Name Z–A"
        case .setAsc: return "Set"
        case .numberAsc: return "Nummer"
        case .rarityAsc: return "Seltenheit"
        case .valueDesc: return "Wert ↓"
        case .valueAsc: return "Wert ↑"
        case .conditionAsc: return "Zustand"
        case .createdDesc: return "Hinzugefügt ↓"
        case .createdAsc: return "Hinzugefügt ↑"
        case .purchaseDateDesc: return "Kaufdatum"
        }
    }

    func sorted(_ cards: [OwnedCard]) -> [OwnedCard] {
        switch self {
        case .updatedDesc:
            return cards.sorted { $0.updatedAt > $1.updatedAt }
        case .nameAsc:
            return cards.sorted {
                ($0.catalogEntry?.displayName ?? "").localizedCaseInsensitiveCompare($1.catalogEntry?.displayName ?? "") == .orderedAscending
            }
        case .nameDesc:
            return cards.sorted {
                ($0.catalogEntry?.displayName ?? "").localizedCaseInsensitiveCompare($1.catalogEntry?.displayName ?? "") == .orderedDescending
            }
        case .setAsc:
            return cards.sorted {
                let a = $0.catalogEntry?.setName ?? ""
                let b = $1.catalogEntry?.setName ?? ""
                if a != b { return a.localizedCaseInsensitiveCompare(b) == .orderedAscending }
                return ($0.catalogEntry?.number ?? "").localizedStandardCompare($1.catalogEntry?.number ?? "") == .orderedAscending
            }
        case .numberAsc:
            return cards.sorted {
                ($0.catalogEntry?.number ?? "").localizedStandardCompare($1.catalogEntry?.number ?? "") == .orderedAscending
            }
        case .rarityAsc:
            return cards.sorted {
                rarityRank($0.catalogEntry?.rarity) < rarityRank($1.catalogEntry?.rarity)
            }
        case .valueDesc:
            return cards.sorted {
                ($0.resolvedUnitValue().value ?? -1) > ($1.resolvedUnitValue().value ?? -1)
            }
        case .valueAsc:
            return cards.sorted {
                ($0.resolvedUnitValue().value ?? Double.greatestFiniteMagnitude)
                    < ($1.resolvedUnitValue().value ?? Double.greatestFiniteMagnitude)
            }
        case .conditionAsc:
            return cards.sorted { $0.condition.sortOrder < $1.condition.sortOrder }
        case .createdDesc:
            return cards.sorted { $0.createdAt > $1.createdAt }
        case .createdAsc:
            return cards.sorted { $0.createdAt < $1.createdAt }
        case .purchaseDateDesc:
            return cards.sorted {
                ($0.purchaseDate ?? .distantPast) > ($1.purchaseDate ?? .distantPast)
            }
        }
    }

    private func rarityRank(_ raw: String?) -> Int {
        let v = (raw ?? "").lowercased()
        if v.contains("secret") || v.contains("illustration") { return 0 }
        if v.contains("ultra") || v.contains("amazing") { return 1 }
        if v.contains("rare holo") || v.contains("holo rare") { return 2 }
        if v.contains("rare") { return 3 }
        if v.contains("uncommon") { return 4 }
        if v.contains("common") { return 5 }
        return 6
    }
}
