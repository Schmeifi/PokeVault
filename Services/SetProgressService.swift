import Foundation
import SwiftData

struct SetProgress: Sendable, Equatable {
    var setId: String
    var setName: String
    var ownedDistinct: Int
    var totalOfficial: Int
    var missingLocalIds: [String]
    var completionRule: CompletionRule

    var fraction: Double {
        guard totalOfficial > 0 else { return 0 }
        return min(1, Double(ownedDistinct) / Double(totalOfficial))
    }

    var percentLabel: String {
        String(format: "%.0f %%", fraction * 100)
    }
}

enum CompletionRule: String, CaseIterable, Identifiable, Sendable {
    case officialCount
    case totalCount

    var id: String { rawValue }

    var displayNameDE: String {
        switch self {
        case .officialCount: return "Offizielle Setgröße"
        case .totalCount: return "Gesamt inkl. Secret"
        }
    }
}

@MainActor
enum SetProgressService {
    static func progress(
        for detail: TCGdexSetDetail,
        owned: [OwnedCard],
        rule: CompletionRule = .officialCount
    ) -> SetProgress {
        let cards = detail.cards ?? []
        let allLocal = cards.compactMap(\.localId)
        let ownedIds = Set(
            owned.compactMap { card -> String? in
                guard card.catalogEntry?.setId == detail.id else { return nil }
                return card.catalogEntry?.number
            }
        )
        let missing = allLocal.filter { !ownedIds.contains($0) }
        let total: Int
        switch rule {
        case .officialCount:
            total = detail.cardCount?.official ?? allLocal.count
        case .totalCount:
            total = detail.cardCount?.total ?? allLocal.count
        }
        return SetProgress(
            setId: detail.id,
            setName: detail.name,
            ownedDistinct: ownedIds.count,
            totalOfficial: total,
            missingLocalIds: missing,
            completionRule: rule
        )
    }
}
