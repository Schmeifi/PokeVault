import Foundation

/// Strukturierte OCR-Hinweise für die Kandidatensuche (kein Cloud-Matching).
struct OCRCardHints: Equatable, Sendable {
    var nameCandidates: [String]
    var localIds: [String]
    var setHints: [String]
    var rawLines: [String]
    var hp: Int? = nil
    /// Right side of `4/102` — the printed set size a person uses to name the set.
    var printedSetCount: Int? = nil
    var illustrator: String? = nil
    var regulationMark: String? = nil
    var evolvesFrom: String? = nil

    var isEmpty: Bool {
        nameCandidates.isEmpty && localIds.isEmpty && setHints.isEmpty
    }

    var primaryQueryLabel: String {
        let text = identityReadout.joined(separator: " · ")
        return text.isEmpty ? "—" : text
    }

    /// The fields a person reads on the card, not the raw OCR dump.
    var identityReadout: [String] {
        var lines: [String] = []
        if let name = nameCandidates.first { lines.append(name) }
        if let hp { lines.append("\(hp) KP") }
        if let number = localIds.first {
            if let printedSetCount {
                lines.append("#\(number)/\(printedSetCount)")
            } else {
                lines.append("#\(number)")
            }
        }
        if let evolvesFrom { lines.append("aus \(evolvesFrom)") }
        if let illustrator { lines.append("Illus. \(illustrator)") }
        if let regulationMark { lines.append("Marke \(regulationMark)") }
        return lines
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

        // Priority lines are the bottom number strip. Keep them out of the name band.
        let identity = CardIdentityParser.parse(orderedLines: cleaned + priority)
        return hints(from: identity, rawLines: cleaned, numberPriorityLines: priority)
    }

    /// Positioned OCR (0 = top of the card). Name is taken from the top band only.
    /// Upscaled bottom-strip lines are appended as bottom-of-card text so the
    /// collector number and illustrator still count when the full frame missed them.
    static func extractHints(positioned lines: [CardIdentityParser.Line], numberPriorityLines: [String] = []) -> OCRCardHints {
        var positioned = lines
        for (offset, text) in numberPriorityLines.enumerated() {
            positioned.append(
                CardIdentityParser.Line(
                    text: text,
                    topFraction: min(0.99, 0.84 + Double(offset) * 0.01)
                )
            )
        }
        let identity = CardIdentityParser.parse(positioned)
        let raw = lines.map(\.text)
        return hints(from: identity, rawLines: raw, numberPriorityLines: numberPriorityLines)
    }

    private static func hints(
        from identity: CardIdentityParser.Identity,
        rawLines: [String],
        numberPriorityLines: [String]
    ) -> OCRCardHints {
        // Only the left side of `005/078`. The 078 is the set size, not a card number.
        var localIds: [String] = []
        for line in numberPriorityLines {
            guard let pair = CardIdentityParser.collectorPair(in: line) else { continue }
            appendCollectorNumber(&localIds, pair.number)
        }
        for number in identity.collectorNumbers {
            appendCollectorNumber(&localIds, number)
        }

        var sets: [String] = []
        for line in rawLines where looksLikeSetCode(line) {
            appendUnique(&sets, line.lowercased())
        }

        return OCRCardHints(
            nameCandidates: Array(identity.nameCandidates.prefix(3)),
            localIds: Array(localIds.prefix(6)),
            setHints: Array(sets.prefix(3)),
            rawLines: rawLines,
            hp: identity.hp,
            printedSetCount: identity.printedSetCount,
            illustrator: identity.illustrator,
            regulationMark: identity.regulationMark,
            evolvesFrom: identity.evolvesFrom
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

        // Name first. A rules sentence used to become the query and the set size
        // (`078` in `005/078`) was searched as the collector number.
        if let name = hints.nameCandidates.first {
            let combined = TCGdexCardSearchQuery(
                name: name,
                setId: hints.setHints.first,
                localId: hints.localIds.first,
                page: 1,
                itemsPerPage: 12
            )
            absorb(try await provider.searchCardsBilingual(
                combined,
                localIdAlternates: Array(hints.localIds.dropFirst().prefix(2)),
                primaryLocale: primaryLocale,
                secondaryLocale: secondaryLocale
            ))
            if pool.count < 4 {
                let nameOnly = TCGdexCardSearchQuery(
                    name: name,
                    setId: nil,
                    localId: nil,
                    page: 1,
                    itemsPerPage: 12
                )
                absorb(try await provider.searchCards(nameOnly, locale: primaryLocale))
                if pool.count < 3 {
                    absorb(try await provider.searchCards(nameOnly, locale: secondaryLocale))
                }
            }
        }

        // 1) Nummer — nur die Sammlernummer, nie die Setgröße.
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

        var ranked = pool
            .map { score(card: $0, hints: hints) }
            .filter { $0.matchConfidence >= minDisplayConfidence }

        // Mit erkannter Nummer: nur Karten mit Nummer-Signal behalten (keine schwachen Namens-Treffer).
        let withName = ranked.filter { candidate in
            candidate.matchReasons.contains(where: { $0.hasPrefix("Name") })
        }
        if !hints.nameCandidates.isEmpty, !withName.isEmpty {
            ranked = withName
        } else if hasNumber {
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

        if hints.hp != nil || hints.illustrator != nil || hints.printedSetCount != nil || hints.regulationMark != nil {
            ranked = await refineWithPrintedIdentity(ranked, hints: hints, provider: provider, locale: primaryLocale)
        }

        // Harte Kappe: nie hunderte Treffer an die UI.
        return Array(ranked.prefix(maxCandidates))
    }

    /// Re-score the shortlist with the fields printed on the card (HP, illustrator, set size, mark).
    private static func refineWithPrintedIdentity(
        _ ranked: [RankedScanCandidate],
        hints: OCRCardHints,
        provider: TCGdexProvider,
        locale: String
    ) async -> [RankedScanCandidate] {
        let head = Array(ranked.prefix(6))
        let tail = Array(ranked.dropFirst(6))
        var refined: [RankedScanCandidate] = []
        for candidate in head {
            var copy = candidate
            var detail = try? await provider.fetchCard(id: candidate.card.id, locale: locale)
            if detail == nil, locale != "en" {
                detail = try? await provider.fetchCard(id: candidate.card.id, locale: "en")
            }
            if let detail {
                let adjustment = identityAdjustment(detail: detail, hints: hints)
                copy.matchConfidence = min(0.99, max(0, copy.matchConfidence + adjustment.delta))
                copy.matchReasons.append(contentsOf: adjustment.reasons)
                if copy.setName == nil {
                    copy.setName = detail.set?.name
                }
            }
            refined.append(copy)
        }
        return (refined + tail)
            .filter { $0.matchConfidence >= minDisplayConfidence }
            .sorted { lhs, rhs in
                if lhs.matchConfidence != rhs.matchConfidence {
                    return lhs.matchConfidence > rhs.matchConfidence
                }
                return lhs.card.name < rhs.card.name
            }
    }

    static func identityAdjustment(detail: TCGdexCardDetail, hints: OCRCardHints) -> (delta: Double, reasons: [String]) {
        var delta = 0.0
        var reasons: [String] = []
        if let hp = hints.hp, let cardHP = detail.hp {
            if hp == cardHP {
                delta += 0.12
                reasons.append("KP \(hp)")
            } else {
                delta -= 0.2
                reasons.append("KP weicht ab")
            }
        }
        if let illustrator = hints.illustrator, let cardIllustrator = detail.illustrator, !illustrator.isEmpty {
            if cardIllustrator.localizedCaseInsensitiveContains(illustrator)
                || illustrator.localizedCaseInsensitiveContains(cardIllustrator) {
                delta += 0.1
                reasons.append("Illustrator")
            }
        }
        if let count = hints.printedSetCount, let official = detail.set?.cardCount?.official, official > 0 {
            if count == official {
                delta += 0.14
                reasons.append("Setgröße \(official)")
            } else {
                delta -= 0.08
            }
        }
        if let mark = hints.regulationMark, let cardMark = detail.regulationMark, !cardMark.isEmpty {
            if mark.caseInsensitiveCompare(cardMark) == .orderedSame {
                delta += 0.06
                reasons.append("Marke \(mark)")
            } else {
                delta -= 0.1
            }
        }
        if let from = hints.evolvesFrom, let evolve = detail.evolveFrom, !evolve.isEmpty {
            if evolve.localizedCaseInsensitiveContains(from) || from.localizedCaseInsensitiveContains(evolve) {
                delta += 0.06
                reasons.append("Entwicklung")
            }
        }
        return (delta, reasons)
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

        // Ohne Nummer-Match abwerten, außer der Name selbst passt.
        // Sonst verdrängt eine falsch gelesene Ziffer die richtige Karte.
        let nameMatched = reasons.contains(where: { $0.hasPrefix("Name") })
        if !hints.localIds.isEmpty,
           !nameMatched,
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

    /// `005` → `005` and `5`. The right side of `005/078` is not passed in.
    private static func appendCollectorNumber(_ array: inout [String], _ number: String) {
        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appendUnique(&array, trimmed)
        if let stripped = trimmed.replacingOccurrences(of: "^0+", with: "", options: .regularExpression) as String?,
           !stripped.isEmpty, stripped != trimmed {
            appendUnique(&array, stripped)
        }
    }

    private static func appendUnique(_ array: inout [String], _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !array.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            array.append(trimmed)
        }
    }
}
