import Foundation
import SwiftData

/// Allgemeine Kartendaten (Katalog) – unabhängig vom Besitz.
@Model
final class CardCatalogEntry {
    @Attribute(.unique) var id: UUID
    var tcgdexId: String
    var cardmarketId: String?
    var name: String
    /// JSON-kodiertes Dictionary Sprache → Name, z. B. {"de":"…","en":"…"}.
    var localizedNamesJSON: String
    var cardmarketName: String?
    var setId: String
    var setName: String
    var number: String
    var rarity: String?
    /// JSON-Array von Typ-Strings.
    var typesJSON: String
    var illustrator: String?
    var imageURL: String?
    /// JSON-Array verfügbarer Varianten.
    var availableVariantsJSON: String
    var cardmarketURL: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \OwnedCard.catalogEntry)
    var ownedCards: [OwnedCard] = []

    @Relationship(deleteRule: .cascade, inverse: \PriceSnapshot.catalogEntry)
    var priceSnapshots: [PriceSnapshot] = []

    @Relationship(deleteRule: .nullify, inverse: \WishlistEntry.catalogEntry)
    var wishlistEntries: [WishlistEntry] = []

    init(
        id: UUID = UUID(),
        tcgdexId: String,
        cardmarketId: String? = nil,
        name: String,
        localizedNames: [String: String] = [:],
        cardmarketName: String? = nil,
        setId: String,
        setName: String = "",
        number: String,
        rarity: String? = nil,
        types: [String] = [],
        illustrator: String? = nil,
        imageURL: String? = nil,
        availableVariants: [String] = [],
        cardmarketURL: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.tcgdexId = tcgdexId
        self.cardmarketId = cardmarketId
        self.name = name
        self.localizedNamesJSON = Self.encodeStringDict(localizedNames)
        self.cardmarketName = cardmarketName
        self.setId = setId
        self.setName = setName
        self.number = number
        self.rarity = rarity
        self.typesJSON = Self.encodeStringArray(types)
        self.illustrator = illustrator
        self.imageURL = imageURL
        self.availableVariantsJSON = Self.encodeStringArray(availableVariants)
        self.cardmarketURL = cardmarketURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var localizedNames: [String: String] {
        get { Self.decodeStringDict(localizedNamesJSON) }
        set { localizedNamesJSON = Self.encodeStringDict(newValue) }
    }

    var types: [String] {
        get { Self.decodeStringArray(typesJSON) }
        set { typesJSON = Self.encodeStringArray(newValue) }
    }

    var availableVariants: [String] {
        get { Self.decodeStringArray(availableVariantsJSON) }
        set { availableVariantsJSON = Self.encodeStringArray(newValue) }
    }

    var displayName: String {
        localizedNames["de"] ?? name
    }

    var imageURLHigh: URL? {
        TCGdexImageURL.card(imageURL, quality: .high, format: .webp)
    }

    var imageURLLow: URL? {
        TCGdexImageURL.card(imageURL, quality: .low, format: .webp)
    }

    // MARK: - JSON helpers

    static func encodeStringDict(_ dict: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(dict),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    static func decodeStringDict(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func encodeStringArray(_ array: [String]) -> String {
        guard let data = try? JSONEncoder().encode(array),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    static func decodeStringArray(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
}
