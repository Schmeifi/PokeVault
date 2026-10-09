import Foundation
import SwiftData

@Model
final class WishlistEntry {
    @Attribute(.unique) var id: UUID
    var priority: Int
    var maxPriceEUR: Double?
    var note: String?
    /// Defaults enable lightweight migration when upgrading past 0.2.x stores.
    var desiredConditionRaw: String = CardCondition.nearMint.rawValue
    var desiredLanguageRaw: String = CardLanguage.de.rawValue
    var targetPriceEUR: Double?
    var isBought: Bool = false
    var createdAt: Date
    var updatedAt: Date

    var catalogEntry: CardCatalogEntry?

    /// Zugehörige benannte Wunschliste (optional für Migration vor 0.3.6).
    var wishlist: Wishlist?

    init(
        id: UUID = UUID(),
        catalogEntry: CardCatalogEntry? = nil,
        wishlist: Wishlist? = nil,
        priority: Int = 3,
        maxPriceEUR: Double? = nil,
        note: String? = nil,
        desiredCondition: CardCondition = .nearMint,
        desiredLanguage: CardLanguage = .de,
        targetPriceEUR: Double? = nil,
        isBought: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.catalogEntry = catalogEntry
        self.wishlist = wishlist
        self.priority = min(5, max(1, priority))
        self.maxPriceEUR = maxPriceEUR
        self.note = note
        self.desiredConditionRaw = desiredCondition.rawValue
        self.desiredLanguageRaw = desiredLanguage.rawValue
        self.targetPriceEUR = targetPriceEUR
        self.isBought = isBought
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var desiredCondition: CardCondition {
        get { CardCondition(rawValue: desiredConditionRaw) ?? .nearMint }
        set { desiredConditionRaw = newValue.rawValue }
    }

    var desiredLanguage: CardLanguage {
        get { CardLanguage(rawValue: desiredLanguageRaw) ?? .de }
        set { desiredLanguageRaw = newValue.rawValue }
    }
}
