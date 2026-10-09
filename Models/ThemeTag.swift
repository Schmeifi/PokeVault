import Foundation
import SwiftData

@Model
final class ThemeTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
