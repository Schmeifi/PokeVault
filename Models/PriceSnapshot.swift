import Foundation
import SwiftData

/// Gespeicherter Preisstand – nie erfunden, immer mit Quelle und Zeitpunkt.
@Model
final class PriceSnapshot {
    @Attribute(.unique) var id: UUID
    var amountEUR: Double?
    var sourceRaw: String
    var metric: String?
    var languageCode: String?
    var variantRaw: String?
    var availabilityNote: String?
    var isSampleData: Bool
    var capturedAt: Date
    var note: String?

    var catalogEntry: CardCatalogEntry?

    init(
        id: UUID = UUID(),
        catalogEntry: CardCatalogEntry? = nil,
        amountEUR: Double?,
        source: PriceSource,
        metric: String? = nil,
        languageCode: String? = nil,
        variant: CardVariant? = nil,
        availabilityNote: String? = nil,
        isSampleData: Bool = false,
        capturedAt: Date = .now,
        note: String? = nil
    ) {
        self.id = id
        self.catalogEntry = catalogEntry
        self.amountEUR = amountEUR
        self.sourceRaw = source.rawValue
        self.metric = metric
        self.languageCode = languageCode
        self.variantRaw = variant?.rawValue
        self.availabilityNote = availabilityNote
        self.isSampleData = isSampleData
        self.capturedAt = capturedAt
        self.note = note
    }

    var source: PriceSource {
        get { PriceSource(rawValue: sourceRaw) ?? .unavailable }
        set { sourceRaw = newValue.rawValue }
    }
}
