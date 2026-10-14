import Foundation

// MARK: - DTOs matching documented TCGdex REST v2 JSON (verified against api.tcgdex.net / tcgdex.dev)

struct TCGdexCardSummary: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let localId: String?
    let name: String
    let image: String?
    /// Filled when the card was loaded from a series/set that knows the serie id.
    var serieId: String? = nil

    var inferredSetId: String? {
        CardSearchQueryParser.extractSetIdFromCardId(id, localId: localId)
    }

    var imageURLLow: URL? {
        TCGdexImageURL.card(image, quality: .low, format: .webp)
    }

    var imageURLHigh: URL? {
        TCGdexImageURL.card(image, quality: .high, format: .webp)
    }

    var imageCandidatesLow: [URL] {
        imageCandidateURLs(preferredQuality: .low)
    }

    var imageCandidatesHigh: [URL] {
        imageCandidateURLs(preferredQuality: .high)
    }

    func withImage(_ newImage: String?) -> TCGdexCardSummary {
        TCGdexCardSummary(id: id, localId: localId, name: name, image: newImage ?? image, serieId: serieId)
    }

    func resolvingImage(serieId explicitSerie: String? = nil) -> TCGdexCardSummary {
        if let image, !image.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return self
        }
        let serie = explicitSerie ?? serieId
        guard let base = TCGdexImageURL.fallbackCardBases(
            serieId: serie,
            setId: inferredSetId,
            localId: localId
        ).first else {
            return self
        }
        return withImage(base)
    }

    func imageCandidateURLs(preferredQuality: TCGdexImageURL.Quality) -> [URL] {
        let resolved = resolvingImage()
        var urls = TCGdexImageURL.cardCandidates(fromImageField: resolved.image, preferredQuality: preferredQuality)
        if image == nil {
            let bases = TCGdexImageURL.fallbackCardBases(
                serieId: serieId,
                setId: inferredSetId,
                localId: localId
            )
            for base in bases {
                urls.append(contentsOf: TCGdexImageURL.cardCandidates(
                    fromImageField: base,
                    preferredQuality: preferredQuality
                ))
            }
        }
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
}

/// UI-Suchtreffer mit Set-Kontext zur Unterscheidung von Druckungen.
struct CardSearchHit: Identifiable, Hashable, Sendable {
    var id: String { card.id }
    var card: TCGdexCardSummary
    var setId: String?
    var setName: String?
    var localeUsed: String
    /// Optional: Match-Qualität (Scanner) 0…1.
    var matchConfidence: Double? = nil
    /// Optional: freier TCGdex-Cardmarket-EUR-Betrag (wenn vorhanden).
    var priceEUR: Double? = nil
    /// Anzeigezeile, z. B. „2,40 € · Trend“ oder „Kein Marktpreis verfügbar“.
    var priceLabel: String? = nil

    var printingLabel: String {
        let number = card.localId.map { "#\($0)" } ?? ""
        let setPart = setName ?? setId ?? card.inferredSetId ?? "—"
        return [setPart, number].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var displayPriceLine: String {
        if let priceLabel, !priceLabel.isEmpty { return priceLabel }
        if let priceEUR { return CurrencyFormat.euro(priceEUR) }
        return PriceSource.unavailable.displayNameDE
    }
}

struct TCGdexSetSummary: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let logo: String?
    let symbol: String?
    let cardCount: TCGdexCardCount?
    /// Not part of the flat `/sets` payload. Set when loaded via `/series/{id}`.
    var serieId: String? = nil

    var logoURL: URL? { TCGdexImageURL.setAsset(logo) }
    var symbolURL: URL? { TCGdexImageURL.setAsset(symbol) }

    var iconCandidates: [URL] {
        TCGdexImageURL.setAssetCandidates(logo: logo, symbol: symbol, serieId: serieId, setId: id)
    }

    func withSerieId(_ serie: String) -> TCGdexSetSummary {
        TCGdexSetSummary(
            id: id,
            name: name,
            logo: logo,
            symbol: symbol,
            cardCount: cardCount,
            serieId: serie
        )
    }

    func fillingAssets(from source: TCGdexSetSummary) -> TCGdexSetSummary {
        TCGdexSetSummary(
            id: id,
            name: name,
            logo: logo ?? source.logo,
            symbol: symbol ?? source.symbol,
            cardCount: cardCount ?? source.cardCount,
            serieId: serieId ?? source.serieId
        )
    }
}

struct TCGdexCardCount: Decodable, Sendable, Hashable {
    let total: Int?
    let official: Int?
    let firstEd: Int?
    let holo: Int?
    let normal: Int?
    let reverse: Int?
}

struct TCGdexSerieBrief: Decodable, Sendable, Hashable {
    let id: String
    let name: String
}

struct TCGdexLegal: Decodable, Sendable, Hashable {
    let standard: Bool?
    let expanded: Bool?
}

struct TCGdexSetAbbreviation: Decodable, Sendable, Hashable {
    let official: String?
}

/// Full set payload from GET /v2/{locale}/sets/{id}
struct TCGdexSetDetail: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
    let logo: String?
    let symbol: String?
    let cardCount: TCGdexCardCount?
    let releaseDate: String?
    let serie: TCGdexSerieBrief?
    let legal: TCGdexLegal?
    let tcgOnline: String?
    let abbreviation: TCGdexSetAbbreviation?
    let cards: [TCGdexCardSummary]?

    var logoURL: URL? { TCGdexImageURL.setAsset(logo) }
    var symbolURL: URL? { TCGdexImageURL.setAsset(symbol) }

    var iconCandidates: [URL] {
        TCGdexImageURL.setAssetCandidates(
            logo: logo,
            symbol: symbol,
            serieId: serie?.id,
            setId: id
        )
    }

    var parsedReleaseDate: Date? {
        guard let releaseDate else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: releaseDate)
    }
}

struct TCGdexCardDetail: Decodable, Sendable, Identifiable, Hashable {
    static func == (lhs: TCGdexCardDetail, rhs: TCGdexCardDetail) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: String
    let localId: String?
    let name: String
    let image: String?
    let illustrator: String?
    let rarity: String?
    let category: String?
    let types: [String]?
    let set: TCGdexEmbeddedSet?
    let variants: TCGdexVariantsFlags?
    let pricing: TCGdexPricing?
    let variants_detailed: [TCGdexVariantDetailed]?
    let hp: Int?
    let stage: String?
    let evolveFrom: String?
    let description: String?
    let regulationMark: String?
    let legal: TCGdexLegal?
    let updated: String?

    var imageURLLow: URL? {
        TCGdexImageURL.card(image, quality: .low, format: .webp)
    }

    var imageURLHigh: URL? {
        TCGdexImageURL.card(image, quality: .high, format: .webp)
    }

    var imageCandidatesLow: [URL] {
        imageCandidateURLs(preferredQuality: .low)
    }

    var imageCandidatesHigh: [URL] {
        imageCandidateURLs(preferredQuality: .high)
    }

    func imageCandidateURLs(preferredQuality: TCGdexImageURL.Quality) -> [URL] {
        var urls = TCGdexImageURL.cardCandidates(fromImageField: image, preferredQuality: preferredQuality)
        if image == nil {
            let bases = TCGdexImageURL.fallbackCardBases(
                serieId: nil,
                setId: set?.id,
                localId: localId
            )
            for base in bases {
                urls.append(contentsOf: TCGdexImageURL.cardCandidates(
                    fromImageField: base,
                    preferredQuality: preferredQuality
                ))
            }
        }
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }

    /// Druckvarianten aus Flags + detaillierten Einträgen (nur vorhandene API-Felder).
    var availableVariantLabels: [String] {
        var labels: [String] = []
        if let flags = variants {
            if flags.normal == true { labels.append(CardVariant.normal.rawValue) }
            if flags.holo == true { labels.append(CardVariant.holo.rawValue) }
            if flags.reverse == true { labels.append(CardVariant.reverse.rawValue) }
            if flags.firstEdition == true { labels.append(CardVariant.firstEdition.rawValue) }
            if flags.wPromo == true { labels.append(CardVariant.promo.rawValue) }
        }
        if let detailed = variants_detailed {
            for item in detailed {
                guard let type = item.type?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !type.isEmpty else { continue }
                let mapped: String
                switch type.lowercased() {
                case "normal": mapped = CardVariant.normal.rawValue
                case "holo", "holofoil": mapped = CardVariant.holo.rawValue
                case "reverse", "reverse-holofoil", "reverseholo": mapped = CardVariant.reverse.rawValue
                case "firstedition", "first-edition", "first_edition": mapped = CardVariant.firstEdition.rawValue
                case "wpromo", "promo": mapped = CardVariant.promo.rawValue
                default: mapped = type
                }
                if !labels.contains(mapped) {
                    labels.append(mapped)
                }
            }
        }
        return labels
    }

    var printingSummary: String {
        let variantsText = availableVariantLabels.isEmpty
            ? "keine Variantenangabe"
            : availableVariantLabels.joined(separator: ", ")
        let setPart = [set?.name, localId.map { "#\($0)" }].compactMap { $0 }.joined(separator: " · ")
        let rarityPart = rarity ?? "—"
        return "\(setPart.isEmpty ? id : setPart) · \(rarityPart) · \(variantsText)"
    }
}

struct TCGdexEmbeddedSet: Decodable, Sendable, Hashable {
    let id: String
    let name: String
    let logo: String?
    let symbol: String?
    let cardCount: TCGdexCardCount?
}

struct TCGdexVariantsFlags: Decodable, Sendable, Hashable {
    let firstEdition: Bool?
    let holo: Bool?
    let normal: Bool?
    let reverse: Bool?
    let wPromo: Bool?
}

struct TCGdexPricing: Decodable, Sendable {
    let cardmarket: TCGdexCardmarketPricing?
    // tcgplayer bewusst dekodierbar aber ungenutzt (USD) – Phase 3 / keine erfundenen EUR.
}

struct TCGdexCardmarketPricing: Decodable, Sendable {
    let updated: String?
    let unit: String?
    let idProduct: Int?
    let avg: Double?
    let low: Double?
    let trend: Double?
    let avg1: Double?
    let avg7: Double?
    let avg30: Double?
}

struct TCGdexVariantDetailed: Decodable, Sendable {
    let type: String?
    let size: String?
    let thirdParty: TCGdexThirdParty?
    let pricing: TCGdexPricing?
    let variantId: String?
}

struct TCGdexThirdParty: Decodable, Sendable {
    let cardmarket: Int?
    let tcgplayer: Int?
}

struct TCGdexSerieSummary: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct TCGdexSerieDetail: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
    let sets: [TCGdexSetSummary]?
}

/// Suchparameter für GET /v2/{locale}/cards (nur dokumentierte Query-Keys).
struct TCGdexCardSearchQuery: Sendable, Equatable {
    var name: String?
    var setId: String?
    var localId: String?
    /// Optional: `like:` / freier rarity-Filter (TCGdex-Feld `rarity`).
    var rarity: String?
    /// Optional: `eq:`/`like:` auf `category` (Pokemon, Trainer, Energy).
    var category: String?
    var page: Int = 1
    var itemsPerPage: Int = 24

    var isEmpty: Bool {
        let n = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let s = setId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let l = localId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let r = rarity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let c = category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty && s.isEmpty && l.isEmpty && r.isEmpty && c.isEmpty
    }
}

/// Angereicherte Set-Karte (Seltenheit + EUR-Preis aus Detail, nie erfunden).
struct SetCardEnrichment: Identifiable, Hashable, Sendable {
    var id: String { summary.id }
    var summary: TCGdexCardSummary
    var rarity: String?
    var category: String?
    var priceEUR: Double?
    var priceLabel: String?

    var displayRarity: String { rarity ?? "—" }
}
