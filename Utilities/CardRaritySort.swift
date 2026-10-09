import Foundation

/// Sortier-Rang für TCGdex-Seltenheiten (EN + DE). Unbekannt → niedrig, dann Name.
enum CardRaritySort {
    /// Höher = seltener (Secret Rare oben).
    static func rank(_ rarity: String?) -> Int {
        guard let raw = rarity?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return 0
        }
        let key = normalize(raw)
        if let exact = table[key] { return exact }
        // Teiltreffer für „Holo Rare VMAX“ etc.
        for (pattern, value) in fuzzyOrdered where key.contains(pattern) {
            return value
        }
        return 5
    }

    static func compare(lhs: String?, rhs: String?, nameL: String, nameR: String) -> Bool {
        let rl = rank(lhs)
        let rr = rank(rhs)
        if rl != rr { return rl > rr }
        return nameL.localizedCaseInsensitiveCompare(nameR) == .orderedAscending
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
            .lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Exakte Keys (normalisiert).
    private static let table: [String: Int] = [
        "mega hyper rare": 100,
        "mega hyper selten": 100,
        "hyper rare": 95,
        "hyperselten": 95,
        "secret rare": 90,
        "versteckt selten": 90,
        "special illustration rare": 88,
        "selten besondere illustration": 88,
        "illustration rare": 85,
        "selten illustration": 85,
        "shiny ultra rare": 82,
        "ultraselten schillernd": 82,
        "shiny rare vmax": 80,
        "shiny rare v": 78,
        "shiny rare": 76,
        "ultra rare": 74,
        "ultra selten": 74,
        "full art trainer": 72,
        "vollkunsttrainer": 72,
        "radiant rare": 70,
        "selten strahlend": 70,
        "amazing rare": 68,
        "atemberaubend": 68,
        "holo rare vstar": 66,
        "holografisch selten vstar": 66,
        "holo rare vmax": 64,
        "holografisch selten vmax": 64,
        "holo rare v": 62,
        "holografisch selten v": 62,
        "rare holo": 58,
        "selten holografisch": 58,
        "holo rare": 56,
        "holografisch selten": 56,
        "double rare": 54,
        "doppelselten": 54,
        "rare": 50,
        "selten": 50,
        "uncommon": 30,
        "ungewöhnlich": 30,
        "common": 20,
        "häufig": 20,
        "promo": 15,
        "none": 1,
        "keine": 1
    ]

    private static let fuzzyOrdered: [(String, Int)] = [
        ("mega hyper", 100),
        ("hyper rare", 95),
        ("hyperselten", 95),
        ("secret", 90),
        ("versteckt", 90),
        ("special illustration", 88),
        ("besondere illustration", 88),
        ("illustration", 85),
        ("shiny ultra", 82),
        ("shiny rare vmax", 80),
        ("shiny rare v", 78),
        ("shiny rare", 76),
        ("ultra rare", 74),
        ("ultra selten", 74),
        ("full art", 72),
        ("vollkunst", 72),
        ("radiant", 70),
        ("strahlend", 70),
        ("amazing", 68),
        ("vstar", 66),
        ("vmax", 64),
        ("holo rare v", 62),
        ("holografisch selten v", 62),
        ("rare holo", 58),
        ("holo", 56),
        ("double rare", 54),
        ("doppelselten", 54),
        ("uncommon", 30),
        ("ungewöhnlich", 30),
        ("common", 20),
        ("häufig", 20),
        ("promo", 15)
    ]
}
