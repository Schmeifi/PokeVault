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

    /// Aktueller Einzelwert: TCGdex-/Markt-Snapshot wenn vorhanden, sonst manuell, sonst fehlend.
    /// Erfindet niemals Preise.
    func resolvedUnitValue(preferring snapshots: [PriceSnapshot] = []) -> (value: Double?, source: PriceSource) {
        let relevant = snapshots
            .filter { $0.catalogEntry?.id == catalogEntry?.id }
            .sorted { $0.capturedAt > $1.capturedAt }
        if let latest = relevant.first, let amount = latest.amountEUR {
            return (amount, PriceSource(rawValue: latest.sourceRaw) ?? .lastStored)
        }
        if let catalog = catalogEntry,
           let latest = catalog.priceSnapshots
            .filter({ $0.amountEUR != nil })
            .sorted(by: { $0.capturedAt > $1.capturedAt })
            .first,
           let amount = latest.amountEUR {
            return (amount, PriceSource(rawValue: latest.sourceRaw) ?? .lastStored)
        }
        if let manualValue {
            return (manualValue, .manual)
        }
        return (nil, .unavailable)
    }

    /// Zeilen-P&L für dieses Exemplar (Anzahl berücksichtigt). Ohne Kaufpreis oder ohne aktuellen Wert → nil.
    func portfolioLine() -> CardPortfolioLine {
        let qty = Double(max(1, quantity))
        let purchaseUnit = purchasePrice
        let resolved = resolvedUnitValue()
        let currentUnit = resolved.value
        let purchaseTotal = purchaseUnit.map { $0 * qty }
        let currentTotal = currentUnit.map { $0 * qty }
        let difference: Double?
        let percent: Double?
        if let purchaseTotal, let currentTotal {
            let diff = currentTotal - purchaseTotal
            difference = diff
            percent = purchaseTotal != 0 ? (diff / purchaseTotal) * 100 : nil
        } else {
            difference = nil
            percent = nil
        }
        let latestSnapshot = catalogEntry?.priceSnapshots
            .sorted(by: { $0.capturedAt > $1.capturedAt })
            .first
        return CardPortfolioLine(
            purchaseTotal: purchaseTotal,
            currentTotal: currentTotal,
            difference: difference,
            percent: percent,
            source: resolved.source,
            updatedAt: resolved.source == .manual ? updatedAt : latestSnapshot?.capturedAt,
            metric: latestSnapshot?.metric,
            hasPurchase: purchaseUnit != nil,
            hasCurrent: currentUnit != nil
        )
    }
}

struct CardPortfolioLine: Sendable, Equatable {
    var purchaseTotal: Double?
    var currentTotal: Double?
    var difference: Double?
    var percent: Double?
    var source: PriceSource
    var updatedAt: Date?
    var metric: String?
    var hasPurchase: Bool
    var hasCurrent: Bool
}
