import Foundation
import SwiftData

@Model
final class PokemonSet {
    @Attribute(.unique) var id: UUID
    var tcgdexSetId: String
    var name: String
    var seriesName: String?
    var logoURL: String?
    var symbolURL: String?
    var cardCountOfficial: Int?
    var cardCountTotal: Int?
    var releaseDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        tcgdexSetId: String,
        name: String,
        seriesName: String? = nil,
        logoURL: String? = nil,
        symbolURL: String? = nil,
        cardCountOfficial: Int? = nil,
        cardCountTotal: Int? = nil,
        releaseDate: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.tcgdexSetId = tcgdexSetId
        self.name = name
        self.seriesName = seriesName
        self.logoURL = logoURL
        self.symbolURL = symbolURL
        self.cardCountOfficial = cardCountOfficial
        self.cardCountTotal = cardCountTotal
        self.releaseDate = releaseDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
