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
        extractHints(from: lines, numberPriorityLines: [])
    }

    /// `numberPriorityLines` = OCR from bottom/corner ROI — numbers there win.
    static func extractHints(from lines: [String], numberPriorityLines: [String]) -> OCRCardHints {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let priority = numberPriorityLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var localIds: [String] = []
        var names: [String] = []
        var sets: [String] = []

        // 1) Numbers from ROI first (TG22, 025/189, GG70, …)
        for num in CardSearchQueryParser.extractCardNumbers(from: priority + cleaned, preferEarlier: true) {
            appendUnique(&localIds, num)
        }

        for line in cleaned {
            if let slashNumber = extractNumberFromSlashLine(line) {
                appendUnique(&localIds, slashNumber)
            }
            if looksLikeSetCode(line) {
                appendUnique(&sets, line.lowercased())
                continue
            }
            if looksLikeCardName(line), !CardSearchQueryParser.looksLikeCardNumber(line) {
                appendUnique(&names, line)
            }
        }

        return OCRCardHints(
            nameCandidates: Array(names.prefix(4)),
            localIds: Array(localIds.prefix(8)),
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

        let hasNumber = !hints.localIds.isEmpty

        // 1) Nummer zuerst — jede Variante eng suchen (kein Name-Spam).
        if hasNumber {
            let setId = hints.setHints.first
            for localId in hints.localIds.prefix(4) {
                let numberOnly = TCGdexCardSearchQuery(
                    name: nil,
                    setId: setId,
                    localId: localId,
                    page: 1,
                    itemsPerPage: 16
                )
                absorb(try await provider.searchCardsBilingual(
                    numberOnly,
                    localIdAlternates: [],
                    primaryLocale: primaryLocale,
                    secondaryLocale: secondaryLocale
                ))
                if pool.count >= maxCandidates * 2 { break }
            }

            // Optional: Nummer + Name nur zum Nachschärfen, nicht als erster Query.
            if pool.count < 3, let name = hints.nameCandidates.first, let localId = hints.localIds.first {
                let combined = TCGdexCardSearchQuery(
                    name: name,
                    setId: setId,
                    localId: localId,
                    page: 1,
                    itemsPerPage: 12
                )
                absorb(try await provider.searchCardsBilingual(
                    combined,
                    localIdAlternates: Array(hints.localIds.dropFirst().prefix(3)),
                    primaryLocale: primaryLocale,
                    secondaryLocale: secondaryLocale
                ))
            }
        }

        // 2) Nur Name, wenn keine Nummer erkannt — kleine Seite.
        if pool.isEmpty, !hasNumber, let name = hints.nameCandidates.first {
            let query = TCGdexCardSearchQuery(
                name: name,
                setId: hints.setHints.first,
                localId: nil,
                page: 1,
                itemsPerPage: 12
            )
            absorb(try await provider.searchCards(query, locale: primaryLocale))
            if pool.count < 3 {
                absorb(try await provider.searchCards(query, locale: secondaryLocale))
            }
        }

        var ranked = pool
            .map { score(card: $0, hints: hints) }
            .filter { $0.matchConfidence >= minDisplayConfidence }

        // Mit erkannter Nummer: nur Karten mit Nummer-Signal behalten (keine schwachen Namens-Treffer).
        if hasNumber {
            let withNumber = ranked.filter { candidate in
                candidate.matchReasons.contains(where: { $0.localizedCaseInsensitiveContains("Nummer") })
            }
            if !withNumber.isEmpty {
                ranked = withNumber
            }
        }

        ranked.sort { lhs, rhs in
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

        // Nummer: stärkstes Signal (inkl. Zero-Pad / Prefix-Varianten)
        if !hints.localIds.isEmpty, !cardLocal.isEmpty {
            if hints.localIds.contains(where: { localIdsMatch($0, cardLocal) }) {
                score += 0.62
                reasons.append("Nummer \(cardLocal)")
            } else if hints.localIds.contains(where: { cardLocal.localizedCaseInsensitiveContains($0) || $0.localizedCaseInsensitiveContains(cardLocal) }) {
                score += 0.28
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

        // Starke Abwertung ohne Nummer-Match, wenn OCR eine Nummer hatte
        if !hints.localIds.isEmpty,
           !hints.localIds.contains(where: { localIdsMatch($0, cardLocal) }) {
            score *= 0.35
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

    private static func localIdsMatch(_ a: String, _ b: String) -> Bool {
        if a.caseInsensitiveCompare(b) == .orderedSame { return true }
        let na = normalizeLocalId(a)
        let nb = normalizeLocalId(b)
        return na.caseInsensitiveCompare(nb) == .orderedSame
    }

    private static func normalizeLocalId(_ value: String) -> String {
        let prefix = String(value.prefix { $0.isLetter }).uppercased()
        let digits = String(value.drop { $0.isLetter })
        let stripped = digits.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        return prefix + (stripped.isEmpty ? digits : stripped)
    }

    private static func appendUnique(_ array: inout [String], _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !array.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            array.append(trimmed)
        }
    }
}
