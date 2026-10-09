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
        // TG22/TG30, SM123, 136, GG70, SV017, swsh9tg-TG22
        if value.contains("/") { return true }
        if value.range(
            of: #"^(TG|GG|SV|SM|XY|BW|DP|PROMO)?\d{1,4}[A-Za-z]?$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return true
        }
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

    /// Pull collector numbers out of noisy OCR lines (prefer earlier = number-zone lines first).
    static func extractCardNumbers(from lines: [String], preferEarlier: Bool = true) -> [String] {
        var found: [String] = []
        let pattern = #"\b((?:TG|GG|SV|SM|XY|BW|DP)\s*\d{1,4}|\d{1,4}\s*/\s*(?:TG|GG|SV)?\d{1,4}|\d{1,4}[a-zA-Z]?)\b"#
        let ordered = preferEarlier ? lines : lines.reversed()
        for line in ordered {
            let upper = line.uppercased()
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(upper.startIndex..<upper.endIndex, in: upper)
            regex.enumerateMatches(in: upper, options: [], range: range) { match, _, _ in
                guard let match, let swiftRange = Range(match.range(at: 1), in: upper) else { return }
                let token = String(upper[swiftRange]).replacingOccurrences(of: " ", with: "")
                // Normalize „025/189“ → primary 025 (+ alt 25)
                let parts = splitCardNumber(token)
                appendUniqueNumber(&found, parts.primary)
                for alt in parts.alternates { appendUniqueNumber(&found, alt) }
                // Zero-pad / strip-pad variants for TCGdex localIds
                if let stripped = stripLeadingZeros(parts.primary), stripped != parts.primary {
                    appendUniqueNumber(&found, stripped)
                }
                if let padded = padLocalId(parts.primary), padded != parts.primary {
                    appendUniqueNumber(&found, padded)
                }
            }
            // Also whole-line patterns
            if looksLikeCardNumber(line) {
                let parts = splitCardNumber(line.replacingOccurrences(of: " ", with: ""))
                appendUniqueNumber(&found, parts.primary)
            }
        }
        return found
    }

    private static func stripLeadingZeros(_ value: String) -> String? {
        // Keep prefix letters: TG022 → TG22; 025 → 25
        let prefix = String(value.prefix { $0.isLetter })
        let digits = String(value.drop { $0.isLetter })
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        let stripped = digits.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        guard !stripped.isEmpty, stripped != digits else { return nil }
        return prefix + stripped
    }

    private static func padLocalId(_ value: String) -> String? {
        let prefix = String(value.prefix { $0.isLetter })
        let digits = String(value.drop { $0.isLetter })
        guard (1...2).contains(digits.count), digits.allSatisfy({ $0.isNumber }) else { return nil }
        let padded = String(repeating: "0", count: 3 - digits.count) + digits
        return prefix.isEmpty ? padded : prefix + padded
    }

    private static func appendUniqueNumber(_ array: inout [String], _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !array.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            array.append(trimmed)
        }
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
