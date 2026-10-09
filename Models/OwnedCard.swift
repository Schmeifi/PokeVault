import Foundation
import SwiftData

/// Ein konkretes Exemplar im Besitz des Nutzers.
/// Mehrere Exemplare derselben Katalogkarte (Zustand/Sprache/Variante) bleiben getrennt.
@Model
final class OwnedCard {
    @Attribute(.unique) var id: UUID
    var quantity: Int
    var conditionRaw: String
    var languageRaw: String
    var variantRaw: String
    var purchasePrice: Double?
    var purchaseDate: Date?
    var manualValue: Double?
    var note: String?
    var frontImagePath: String?
    var backImagePath: String?
    var storageLocation: String?
    var createdAt: Date
    var updatedAt: Date

    var catalogEntry: CardCatalogEntry?

    @Relationship(deleteRule: .cascade, inverse: \CollectionMembership.ownedCard)
    var memberships: [CollectionMembership] = []

    init(
        id: UUID = UUID(),
        catalogEntry: CardCatalogEntry? = nil,
        quantity: Int = 1,
        condition: CardCondition = .nearMint,
        language: CardLanguage = .de,
        variant: CardVariant = .normal,
        purchasePrice: Double? = nil,
        purchaseDate: Date? = nil,
        manualValue: Double? = nil,
        note: String? = nil,
        frontImagePath: String? = nil,
        backImagePath: String? = nil,
        storageLocation: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.catalogEntry = catalogEntry
        self.quantity = max(1, quantity)
        self.conditionRaw = condition.rawValue
        self.languageRaw = language.rawValue
        self.variantRaw = variant.rawValue
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.manualValue = manualValue
        self.note = note
        self.frontImagePath = frontImagePath
        self.backImagePath = backImagePath
        self.storageLocation = storageLocation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var condition: CardCondition {
        get { CardCondition(rawValue: conditionRaw) ?? .nearMint }
        set { conditionRaw = newValue.rawValue }
    }

    var language: CardLanguage {
        get { CardLanguage(rawValue: languageRaw) ?? .de }
        set { languageRaw = newValue.rawValue }
    }

    var variant: CardVariant {
        get { CardVariant(rawValue: variantRaw) ?? .normal }
        set { variantRaw = newValue.rawValue }
    }

    /// Effektiver Einzelwert: manuell > letzter Snapshot > nil (kein erfundener Preis).
    func resolvedUnitValue(preferring snapshots: [PriceSnapshot] = []) -> (value: Double?, source: PriceSource) {
        if let manualValue {
            return (manualValue, .manual)
        }
        let relevant = snapshots
            .filter { $0.catalogEntry?.id == catalogEntry?.id }
            .sorted { $0.capturedAt > $1.capturedAt }
        if let latest = relevant.first, latest.amountEUR != nil {
            return (latest.amountEUR, PriceSource(rawValue: latest.sourceRaw) ?? .lastStored)
        }
        if let catalog = catalogEntry,
           let latest = catalog.priceSnapshots.sorted(by: { $0.capturedAt > $1.capturedAt }).first,
           latest.amountEUR != nil {
            return (latest.amountEUR, PriceSource(rawValue: latest.sourceRaw) ?? .lastStored)
        }
        return (nil, .unavailable)
    }
}
