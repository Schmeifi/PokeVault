import Foundation
import SwiftData

@MainActor
enum CollectionMembershipService {
    static func add(_ card: OwnedCard, to collection: UserCollection, in context: ModelContext) {
        let alreadyMember = collection.memberships.contains { $0.ownedCard?.id == card.id }
        guard !alreadyMember else { return }
        let membership = CollectionMembership(collection: collection, ownedCard: card)
        context.insert(membership)
        collection.updatedAt = .now
    }

    static func remove(_ card: OwnedCard, from collection: UserCollection, in context: ModelContext) {
        for membership in collection.memberships where membership.ownedCard?.id == card.id {
            context.delete(membership)
        }
        collection.updatedAt = .now
    }
}
