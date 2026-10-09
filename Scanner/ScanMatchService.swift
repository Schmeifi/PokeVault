import Foundation

/// Strukturierte OCR-Hinweise für die Kandidatensuche (kein Cloud-Matching).
struct OCRCardHints: Equatable, Sendable {
    var nameCandidates: [String]
    var localIds: [String]
    var setHints: [String]
    var rawLines: [String]

    var isEmpty: Bool {
        nameCandidates.isEmpty && localIds.isEmpty && setHints.isEmpty
    }

    var primaryQueryLabel: String {
        let parts = [
            nameCandidates.first,
            localIds.first.map { "#\($0)" },
            setHints.first
        ].compactMap { $0 }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

/// Rangierter Suchkandidat — Konfidenz = Match-Qualität, nicht OCR-Textmenge.
struct RankedScanCandidate: Identifiable, Hashable, Sendable {
    var id: String { card.id }
    var card: TCGdexCardSummary
    var setName: String?
    /// 0…1 — wie gut Name/Nummer/Set zur OCR passen.
    var matchConfidence: Double
    var matchReasons: [String]

    var hit: CardSearchHit {
        CardSearchHit(
            card: card,
            setId: card.inferredSetId,
            setName: setName,
            localeUsed: "de",
            matchConfidence: matchConfidence,
            priceEUR: nil,
            priceLabel: nil
        )
    }
}

/// OCR → wenige, gerankte TCGdex-Kandidaten. Max. 5–15 Treffer.
enum ScanMatchService {
    static let maxCandidates = 12
    static let minDisplayConfidence = 0.35

    // MARK: - OCR parsing

    static func extractHints(from lines: [String]) -> OCRCardHints {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var localIds: [String] = []
        var names: [String] = []
        var sets: [String] = []

        for line in cleaned {
            if CardSearchQueryParser.looksLikeCardNumber(line) {
                let parts = CardSearchQueryParser.splitCardNumber(line)
                appendUnique(&localIds, parts.primary)
                for alt in parts.alternates { appendUnique(&localIds, alt) }
                continue
            }

            // „136/189“, „TG22/TG30“ oft als Ratio-Zeile
            if let slashNumber = extractNumberFromSlashLine(line) {
                appendUnique(&localIds, slashNumber)
                continue
            }

            // Set-Codes / Abkürzungen (SWSH3, sv3, base1)
            if looksLikeSetCode(line) {
                appendUnique(&sets, line.lowercased())
                continue
            }

            // Pokémon-/Kartennamen: Buchstaben, Länge begrenzt, kein reiner Noise
            if looksLikeCardName(line) {
                appendUnique(&names, line)
            }
        }

        // Nummer oft in derselben Zeile wie Name: „Umbreon V TG22“
        for line in cleaned {
            let tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for token in tokens where CardSearchQueryParser.looksLikeCardNumber(token) {
                let parts = CardSearchQueryParser.splitCardNumber(token)
                appendUnique(&localIds, parts.primary)
            }
        }

        return OCRCardHints(
            nameCandidates: Array(names.prefix(4)),
            localIds: Array(localIds.prefix(4)),
            setHints: Array(sets.prefix(3)),
            rawLines: cleaned
        )
    }

    // MARK: - Search + rank

    static func findCandidates(
        hints: OCRCardHints,
        provider: TCGdexProvider = .shared,
        primaryLocale: String = "de",
        secondaryLocale: String = "en"
    ) async throws -> [RankedScanCandidate] {
        guard !hints.isEmpty else { return [] }

        var pool: [TCGdexCardSummary] = []
        var seen = Set<String>()

        func absorb(_ cards: [TCGdexCardSummary]) {
            for card in cards where seen.insert(card.id).inserted {
                pool.append(card)
            }
        }

        // 1) Nummer zuerst (eng), optional mit Name — vermeidet Broad-Name-Spam.
        if let localId = hints.localIds.first {
            let name = hints.nameCandidates.first
            let setId = hints.setHints.first
            let query = TCGdexCardSearchQuery(
                name: name,
                setId: setId,
                localId: localId,
                page: 1,
                itemsPerPage: 24
            )
            absorb(try await provider.searchCardsBilingual(
                query,
                localIdAlternates: Array(hints.localIds.dropFirst()),
                primaryLocale: primaryLocale,
                secondaryLocale: secondaryLocale
            ))

            // Wenn Name+Nummer zu eng war und leer: Nummer allein.
            if pool.isEmpty, name != nil {
                let numberOnly = TCGdexCardSearchQuery(
                    name: nil,
                    setId: setId,
                    localId: localId,
                    page: 1,
                    itemsPerPage: 24
                )
                absorb(try await provider.searchCardsBilingual(
                    numberOnly,
                    localIdAlternates: Array(hints.localIds.dropFirst()),
                    primaryLocale: primaryLocale,
                    secondaryLocale: secondaryLocale
                ))
            }
        }

        // 2) Nur Name, wenn keine Nummer — kleine Seite, kein id=like-Spam.
        if pool.isEmpty, let name = hints.nameCandidates.first {
            let query = TCGdexCardSearchQuery(
                name: name,
                setId: hints.setHints.first,
                localId: nil,
                page: 1,
                itemsPerPage: 20
            )
            // Ein Locale zuerst; zweites nur wenn nötig.
            absorb(try await provider.searchCards(query, locale: primaryLocale))
            if pool.count < 3 {
                absorb(try await provider.searchCards(query, locale: secondaryLocale))
            }
        }

        let ranked = pool
            .map { score(card: $0, hints: hints) }
            .filter { $0.matchConfidence >= minDisplayConfidence }
            .sorted { lhs, rhs in
                if lhs.matchConfidence != rhs.matchConfidence {
                    return lhs.matchConfidence > rhs.matchConfidence
                }
                return lhs.card.name < rhs.card.name
            }

        // Harte Kappe: nie hunderte Treffer an die UI.
        return Array(ranked.prefix(maxCandidates))
    }

    /// Gesamtkonfidenz für die UI = Top-Match (oder 0).
    static func overallConfidence(from ranked: [RankedScanCandidate]) -> Double {
        ranked.first?.matchConfidence ?? 0
    }

    // MARK: - Scoring

    static func score(card: TCGdexCardSummary, hints: OCRCardHints) -> RankedScanCandidate {
        var score = 0.0
        var reasons: [String] = []

        let cardLocal = (card.localId ?? CardSearchQueryParser.extractLocalIdFromCardId(card.id) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cardName = card.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cardSet = (card.inferredSetId ?? "").lowercased()

        // Nummer: stärkstes Signal
        if !hints.localIds.isEmpty, !cardLocal.isEmpty {
            if hints.localIds.contains(where: { $0.caseInsensitiveCompare(cardLocal) == .orderedSame }) {
                score += 0.55
                reasons.append("Nummer \(cardLocal)")
            } else if hints.localIds.contains(where: { cardLocal.localizedCaseInsensitiveContains($0) || $0.localizedCaseInsensitiveContains(cardLocal) }) {
                score += 0.25
                reasons.append("Nummer ähnlich")
            }
        }

        // Name
        if let bestName = bestNameScore(cardName: cardName, candidates: hints.nameCandidates) {
            score += bestName.points
            reasons.append(bestName.reason)
        }

        // Set
        if !hints.setHints.isEmpty, !cardSet.isEmpty {
            if hints.setHints.contains(where: { cardSet == $0 || cardSet.contains($0) || $0.contains(cardSet) }) {
                score += 0.20
                reasons.append("Set \(cardSet)")
            }
        }

        // Leichte Abwertung ohne Nummer-Match, wenn OCR eine Nummer hatte
        if !hints.localIds.isEmpty,
           !hints.localIds.contains(where: { $0.caseInsensitiveCompare(cardLocal) == .orderedSame }) {
            score *= 0.55
        }

        let clamped = min(0.99, max(0, score))
        return RankedScanCandidate(
            card: card,
            setName: nil,
            matchConfidence: clamped,
            matchReasons: reasons
        )
    }

    // MARK: - Helpers

    private static func bestNameScore(cardName: String, candidates: [String]) -> (points: Double, reason: String)? {
        guard !candidates.isEmpty else { return nil }
        let lowerCard = cardName.lowercased()
        var best = 0.0
        var reason = "Name"

        for raw in candidates {
            let lower = raw.lowercased()
            if lowerCard == lower {
                best = max(best, 0.40)
                reason = "Name exakt"
            } else if lowerCard.contains(lower) || lower.contains(lowerCard) {
                best = max(best, 0.28)
                reason = "Name enthält"
            } else {
                let dist = normalizedSimilarity(lowerCard, lower)
                if dist >= 0.75 {
                    best = max(best, 0.22 * dist)
                    reason = "Name ähnlich"
                }
            }
        }
        return best > 0 ? (best, reason) : nil
    }

    /// Grobe Token-Ähnlichkeit ohne externe Libs (0…1).
    private static func normalizedSimilarity(_ a: String, _ b: String) -> Double {
        let ta = Set(a.split(separator: " ").map(String.init))
        let tb = Set(b.split(separator: " ").map(String.init))
        guard !ta.isEmpty, !tb.isEmpty else { return 0 }
        let inter = ta.intersection(tb).count
        let uni = ta.union(tb).count
        return uni == 0 ? 0 : Double(inter) / Double(uni)
    }

    private static func extractNumberFromSlashLine(_ line: String) -> String? {
        // „22/189“ oder „TG22/TG30“
        guard let slash = line.firstIndex(of: "/") else { return nil }
        let left = String(line[..<slash]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty else { return nil }
        if CardSearchQueryParser.looksLikeCardNumber(left) {
            return CardSearchQueryParser.splitCardNumber(left).primary
        }
        if left.range(of: #"^\d{1,4}$"#, options: .regularExpression) != nil {
            return left
        }
        return nil
    }

    private static func looksLikeSetCode(_ line: String) -> Bool {
        let v = line.trimmingCharacters(in: .whitespacesAndNewlines)
        // swsh3, sv3pt5, base1, xy12 — kurz, alphanumerisch
        return v.range(of: #"^[A-Za-z]{2,6}\d{0,3}[A-Za-z]{0,4}\d{0,2}$"#, options: .regularExpression) != nil
            && v.count <= 12
            && v.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private static func looksLikeCardName(_ line: String) -> Bool {
        let v = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard v.count >= 3, v.count <= 42 else { return false }
        // Ablehnen: reine Zahlen, URLs, „HP“, Energy-Zeilen
        if v.range(of: #"^\d+$"#, options: .regularExpression) != nil { return false }
        let lower = v.lowercased()
        let noise: Set<String> = ["hp", "weakness", "resistance", "retreat", "illustrator", "©", "pokemon", "pokémon tcg"]
        if noise.contains(lower) { return false }
        let letters = v.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        return letters >= 3
    }

    private static func appendUnique(_ array: inout [String], _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !array.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            array.append(trimmed)
        }
    }
}
