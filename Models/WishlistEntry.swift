import Foundation
import SwiftData

@Model
final class WishlistEntry {
    @Attribute(.unique) var id: UUID
    var priority: Int
    var maxPriceEUR: Double?
    var note: String?
    var desiredConditionRaw: String
    var desiredLanguageRaw: String
    var targetPriceEUR: Double?
    var isBought: Bool
    var createdAt: Date
    var updatedAt: Date

    var catalogEntry: CardCatalogEntry?

    init(
        id: UUID = UUID(),
        catalogEntry: CardCatalogEntry? = nil,
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
