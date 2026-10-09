import Foundation
import SwiftData

@Model
final class WishlistEntry {
    @Attribute(.unique) var id: UUID
    var priority: Int
    var maxPriceEUR: Double?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    var catalogEntry: CardCatalogEntry?

    init(
        id: UUID = UUID(),
        catalogEntry: CardCatalogEntry? = nil,
        priority: Int = 3,
        maxPriceEUR: Double? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.catalogEntry = catalogEntry
        self.priority = priority
        self.maxPriceEUR = maxPriceEUR
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
