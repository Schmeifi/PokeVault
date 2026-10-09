import Foundation

/// Zerlegt Nutzereingaben in TCGdex-Filter (dokumentierte Query-Keys).
enum CardSearchQueryParser {
    struct Parsed: Equatable {
        var name: String?
        var localId: String?
        /// Zusätzliche localId-Varianten (z. B. aus `TG22/TG30` → `TG22`).
        var localIdAlternates: [String] = []
        var setId: String?
        var looksLikeCardNumber: Bool
    }

    /// `TG22`, `TG22/TG30`, `136`, `SWSH9-TG22`, reine Nummern, alphanumerische Kartennummern.
    static func parse(
        freeText: String,
        numberField: String = "",
        setField: String = ""
    ) -> Parsed {
        let free = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let numberRaw = numberField.trimmingCharacters(in: .whitespacesAndNewlines)
        let setRaw = setField.trimmingCharacters(in: .whitespacesAndNewlines)

        var name: String?
        var localId: String?
        var alternates: [String] = []
        var looksLikeNumber = false

        if !numberRaw.isEmpty {
            let parts = splitCardNumber(numberRaw)
            localId = parts.primary
            alternates = parts.alternates
            looksLikeNumber = true
        }

        if !free.isEmpty {
            if localId == nil, looksLikeCardNumber(free) {
                let parts = splitCardNumber(free)
                localId = parts.primary
                alternates = parts.alternates
                looksLikeNumber = true
                // Zusätzlich: vollständige ID wie swsh9tg-TG22
                if free.contains("-"), let maybeId = extractLocalIdFromCardId(free) {
                    if localId != maybeId {
                        alternates.append(contentsOf: [localId, maybeId].compactMap { $0 })
                        localId = maybeId
                    }
                }
            } else if localId == nil {
                name = free
            } else {
                // Nummer bereits gesetzt – Freitext als Name, sofern es kein Nummern-Muster ist.
                if !looksLikeCardNumber(free) {
                    name = free
                }
            }
        }

        alternates = Array(Set(alternates.filter { !$0.isEmpty && $0 != localId })).sorted()

        return Parsed(
            name: name,
            localId: localId,
            localIdAlternates: alternates,
            setId: setRaw.isEmpty ? nil : setRaw,
            looksLikeCardNumber: looksLikeNumber || (localId != nil && name == nil)
        )
    }

    static func looksLikeCardNumber(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        // TG22/TG30, SM123, 136, GG70, swsh9tg-TG22
        if value.contains("/") { return true }
        if value.range(of: #"^[A-Za-z]{1,5}\d{1,4}$"#, options: .regularExpression) != nil {
            return true
        }
        if value.range(of: #"^\d{1,4}[A-Za-z]?$"#, options: .regularExpression) != nil {
            return true
        }
        if value.contains("-"), extractLocalIdFromCardId(value) != nil {
            return true
        }
        return false
    }

    static func splitCardNumber(_ raw: String) -> (primary: String, alternates: [String]) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // TG22/TG30 → primary TG22, also keep full string as alternate attempt
        if let slash = normalized.firstIndex(of: "/") {
            let left = String(normalized[..<slash]).trimmingCharacters(in: .whitespacesAndNewlines)
            let right = String(normalized[normalized.index(after: slash)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var alts: [String] = []
            if !right.isEmpty { alts.append(right) }
            // „22“ falls Nutzer TG22 meint aber 22 tippt – nicht automatisch, nur explizite Teile
            if let fromId = extractLocalIdFromCardId(left) {
                return (fromId, alts)
            }
            return (left, alts)
        }
        if let fromId = extractLocalIdFromCardId(normalized) {
            return (fromId, [])
        }
        return (normalized, [])
    }

    /// Kartendatei-ID `setId-localId` → localId (TCGdex-Konvention).
    static func extractLocalIdFromCardId(_ cardId: String) -> String? {
        guard let idx = cardId.lastIndex(of: "-") else { return nil }
        let local = String(cardId[cardId.index(after: idx)...])
        return local.isEmpty ? nil : local
    }

    static func extractSetIdFromCardId(_ cardId: String, localId: String?) -> String? {
        if let localId, cardId.hasSuffix("-\(localId)") {
            return String(cardId.dropLast(localId.count + 1))
        }
        guard let idx = cardId.lastIndex(of: "-") else { return nil }
        return String(cardId[..<idx])
    }
}
