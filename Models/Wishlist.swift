import Foundation
import SwiftData

/// Benannte Wunschliste (mehrere Listen pro Nutzer).
@Model
final class Wishlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WishlistEntry.wishlist)
    var entries: [WishlistEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Aktive (nicht gekaufte) Einträge.
    var activeCount: Int {
        entries.filter { !$0.isBought }.count
    }
}
