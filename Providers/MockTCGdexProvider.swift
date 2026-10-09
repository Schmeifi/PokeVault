import Foundation

/// Deterministischer Mock für Unit-Tests (kein Netz).
actor MockTCGdexProvider {
    var cardsByLocale: [String: [TCGdexCardSummary]] = [
        "de": [
            TCGdexCardSummary(id: "swsh9tg-TG22", localId: "TG22", name: "Nachtara V", image: nil),
            TCGdexCardSummary(id: "swsh3-136", localId: "136", name: "Furret", image: "https://assets.tcgdex.net/en/swsh/swsh3/136")
        ],
        "en": [
            TCGdexCardSummary(id: "swsh9tg-TG22", localId: "TG22", name: "Umbreon V", image: nil),
            TCGdexCardSummary(id: "swsh3-136", localId: "136", name: "Furret", image: "https://assets.tcgdex.net/en/swsh/swsh3/136")
        ]
    ]

    var shouldFail = false

    func setShouldFail(_ value: Bool) {
        shouldFail = value
    }

    func search(localId: String?, name: String?, locale: String) throws -> [TCGdexCardSummary] {
        if shouldFail { throw TCGdexError.httpStatus(500) }
        let pool = cardsByLocale[locale] ?? []
        return pool.filter { card in
            if let localId, card.localId?.caseInsensitiveCompare(localId) != .orderedSame {
                return false
            }
            if let name, !card.name.localizedCaseInsensitiveContains(name) {
                return false
            }
            return true
        }
    }
}
