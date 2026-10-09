import Foundation

// MARK: - DTOs matching documented TCGdex REST v2 JSON (verified against api.tcgdex.net)

struct TCGdexCardSummary: Decodable, Sendable, Identifiable {
    let id: String
    let localId: String?
    let name: String
    let image: String?
}

struct TCGdexSetSummary: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
    let logo: String?
    let symbol: String?
    let cardCount: TCGdexCardCount?
}

struct TCGdexCardCount: Decodable, Sendable {
    let total: Int?
    let official: Int?
}

struct TCGdexCardDetail: Decodable, Sendable, Identifiable {
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
}

struct TCGdexEmbeddedSet: Decodable, Sendable {
    let id: String
    let name: String
    let logo: String?
    let symbol: String?
    let cardCount: TCGdexCardCount?
}

struct TCGdexVariantsFlags: Decodable, Sendable {
    let firstEdition: Bool?
    let holo: Bool?
    let normal: Bool?
    let reverse: Bool?
    let wPromo: Bool?
}

struct TCGdexPricing: Decodable, Sendable {
    let cardmarket: TCGdexCardmarketPricing?
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
}

struct TCGdexThirdParty: Decodable, Sendable {
    let cardmarket: Int?
    let tcgplayer: Int?
}

struct TCGdexSerieSummary: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
}
