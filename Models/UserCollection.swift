import Foundation
import SwiftData

@Model
final class UserCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var collectionDescription: String?
    var isSmart: Bool
    var accentColorHex: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CollectionMembership.collection)
    var memberships: [CollectionMembership] = []

    @Relationship(deleteRule: .cascade, inverse: \CollectionRule.collection)
    var rules: [CollectionRule] = []

    init(
        id: UUID = UUID(),
        name: String,
        collectionDescription: String? = nil,
        isSmart: Bool = false,
        accentColorHex: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.collectionDescription = collectionDescription
        self.isSmart = isSmart
        self.accentColorHex = accentColorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
