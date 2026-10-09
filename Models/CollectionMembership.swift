import Foundation
import SwiftData

@Model
final class CollectionMembership {
    @Attribute(.unique) var id: UUID
    var addedAt: Date
    var note: String?

    var collection: UserCollection?
    var ownedCard: OwnedCard?

    init(
        id: UUID = UUID(),
        collection: UserCollection? = nil,
        ownedCard: OwnedCard? = nil,
        addedAt: Date = .now,
        note: String? = nil
    ) {
        self.id = id
        self.collection = collection
        self.ownedCard = ownedCard
        self.addedAt = addedAt
        self.note = note
    }
}
