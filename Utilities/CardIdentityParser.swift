import Foundation

/// How a person identifies a Pokémon card (collector number, set size, name, HP,
/// illustrator, regulation mark, evolution). Not a dump of the first OCR lines.
/// See https://help.tcgplayer.com/hc/en-us/articles/360025905754-How-do-I-identify-this-Pokémon-card
enum CardIdentityParser {
    struct Line: Equatable, Sendable {
        var text: String
        /// 0 = top edge of the card, 1 = bottom edge.
        var topFraction: Double
    }

    struct Identity: Equatable, Sendable {
        var nameCandidates: [String] = []
        var hp: Int?
        var collectorNumbers: [String] = []
        /// Printed total to the right of the slash (`4/102` → 102). Only plain integers.
        var printedSetCount: Int?
        var illustrator: String?
        var regulationMark: String?
        var evolvesFrom: String?
    }

    static func parse(_ lines: [Line]) -> Identity {
        let cleaned = lines
            .map { Line(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), topFraction: $0.topFraction) }
            .filter { !$0.text.isEmpty }

        var identity = Identity()
        var numbers: [String] = []

        for line in cleaned {
            if let hp = hpValue(in: line.text) {
                identity.hp = identity.hp ?? hp
            }
            if let pair = collectorPair(in: line.text) {
                appendUnique(&numbers, pair.number)
                if identity.printedSetCount == nil, let count = pair.setCount {
                    identity.printedSetCount = count
                }
            }
            if identity.illustrator == nil, let name = illustratorName(in: line.text) {
                identity.illustrator = name
            }
            if identity.evolvesFrom == nil, let from = evolvesFrom(in: line.text) {
                identity.evolvesFrom = from
            }
            if identity.regulationMark == nil, line.topFraction >= 0.62, let mark = regulationMark(in: line.text) {
                identity.regulationMark = mark
            }
        }

        // The title sits at the top, often on the same line as "KP 240".
        // Rules text ("Wenn dein Pokémon-V kampfunfähig") is never the name.
        let titled = cleaned.compactMap { line -> (Double, String)? in
            guard line.topFraction <= 0.42, let name = cardName(from: line.text) else { return nil }
            return (line.topFraction, name)
        }.sorted { $0.0 < $1.0 }
        for (_, name) in titled {
            appendUnique(&identity.nameCandidates, name)
            if identity.nameCandidates.count == 3 { break }
        }

        identity.collectorNumbers = numbers
        return identity
    }

    /// Lines without geometry: still parse HP, slash-number, illustrator and evolution
    /// from the whole text, and only treat the upper portion as a possible name.
    static func parse(orderedLines: [String]) -> Identity {
        let count = max(orderedLines.count, 1)
        let lines = orderedLines.enumerated().map { index, text in
            Line(text: text, topFraction: Double(index) / Double(count))
        }
        return parse(lines)
    }

    // MARK: - Field extractors

    static func hpValue(in line: String) -> Int? {
        let patterns = [
            #"(?i)\b(?:HP|KP)\s*[:.]?\s*(\d{2,4})\b"#,
            #"(?i)\b(\d{2,4})\s*(?:HP|KP)\b"#
        ]
        for pattern in patterns {
            if let value = firstInt(in: line, pattern: pattern) {
                return value
            }
        }
        return nil
    }

    /// `4/102` → number 4 and set size 102. `TG22/TG30` → number TG22, no set size.
    static func collectorPair(in line: String) -> (number: String, setCount: Int?)? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)\b((?:TG|GG|SV|SM|XY|BW|DP)\s*\d{1,4}|\d{1,4})\s*/\s*((?:TG|GG|SV|SM|XY|BW|DP)\s*\d{1,4}|\d{1,4})\b"#
        ) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let leftRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let left = line[leftRange].replacingOccurrences(of: " ", with: "")
        let right: String
        if let rightRange = Range(match.range(at: 2), in: line) {
            right = line[rightRange].replacingOccurrences(of: " ", with: "")
        } else {
            right = ""
        }
        let setCount = Int(right)
        let leftIsPlain = left.allSatisfy(\.isNumber)
        return (left, leftIsPlain ? setCount : nil)
    }

    static func illustratorName(in line: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)(?:illus(?:trator)?|ill)\.?\s*[:.]?\s*([A-Za-z][A-Za-z .'\-]{1,40})"#
        ) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let nameRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        var name = line[nameRange].trimmingCharacters(in: .whitespacesAndNewlines)
        // OCR often reads the credit as "Illus. tr. MUGENUP".
        if name.lowercased().hasPrefix("tr.") {
            name = String(name.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return name.count >= 3 ? name : nil
    }

    static func evolvesFrom(in line: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)(?:evolves from|entwickelt sich aus|entwickelt aus)\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .'\-]{1,32})"#
        ) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let nameRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let name = line[nameRange].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    static func regulationMark(in line: String) -> String? {
        let token = line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let marks: Set<String> = ["D", "E", "F", "G", "H", "I"]
        if marks.contains(token) { return token }
        return nil
    }

    /// Title with the HP suffix removed. "Alola-Kokowei V KP 240" → "Alola-Kokowei V".
    static func cardName(from line: String) -> String? {
        var value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let strips = [
            #"(?i)\b(?:HP|KP)\s*[:.]?\s*\d{2,4}\b"#,
            #"(?i)\b\d{2,4}\s*(?:HP|KP)\b"#
        ]
        for pattern in strips {
            value = value.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        value = value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeCardName(value) else { return nil }
        return value
    }

    static func looksLikeCardName(_ line: String) -> Bool {
        let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...42).contains(value.count) else { return false }
        if hpValue(in: value) != nil { return false }
        if collectorPair(in: value) != nil { return false }
        if illustratorName(in: value) != nil { return false }
        if evolvesFrom(in: value) != nil { return false }
        let lower = value.lowercased()
        let stageWords = [
            "weakness", "schwäche", "resistance", "resistenz", "retreat", "rückzug",
            "pokemon", "pokémon", "illustrator", "illus", "basic", "basis",
            "stage", "phase", "trainer", "energy", "energie", "ability", "fähigkeit"
        ]
        if stageWords.contains(where: { lower == $0 || lower.hasPrefix($0 + " ") }) {
            return false
        }
        let rules = ["kampfunfähig", "preiskarte", "v-regel", "wenn dein", "schaden"]
        if rules.contains(where: { lower.contains($0) }) {
            return false
        }
        let words = value.split(whereSeparator: { $0.isWhitespace })
        if words.count > 5 { return false }
        let letters = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let digits = value.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        return letters >= 3 && digits == 0
    }

    // MARK: - Helpers

    private static func firstInt(in line: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: line),
              let value = Int(line[valueRange]) else {
            return nil
        }
        return value
    }

    private static func appendUnique(_ array: inout [String], _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !array.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            array.append(trimmed)
        }
    }
}
