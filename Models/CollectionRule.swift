import Foundation
import SwiftData

/// Regel für smarte Sammlungen (z. B. setId == "swsh3").
@Model
final class CollectionRule {
    @Attribute(.unique) var id: UUID
    var field: String
    /// Vergleichsoperator als String, z. B. "==", "contains".
    var operatorSymbol: String
    var value: String
    var createdAt: Date

    var collection: UserCollection?

    init(
        id: UUID = UUID(),
        field: String,
        operatorSymbol: String,
        value: String,
        collection: UserCollection? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.field = field
        self.operatorSymbol = operatorSymbol
        self.value = value
        self.collection = collection
        self.createdAt = createdAt
    }
}
