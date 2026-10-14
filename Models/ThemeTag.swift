import Foundation
import SwiftData

@Model
final class ThemeTag: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String?
    var createdAt: Date
    /// TCGdex-IDs der Karten, die der Nutzer diesem Thema zugeordnet hat.
    var linkedTcgdexIdsJSON: String?

    var linkedTcgdexIds: [String] {
        get {
            guard let linkedTcgdexIdsJSON,
                  let data = linkedTcgdexIdsJSON.data(using: .utf8),
                  let ids = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return ids
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                linkedTcgdexIdsJSON = json
            } else {
                linkedTcgdexIdsJSON = "[]"
            }
        }
    }

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
