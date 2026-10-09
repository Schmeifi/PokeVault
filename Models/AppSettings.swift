import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var preferredLanguageRaw: String
    var defaultConditionRaw: String
    /// Ob Beispieldaten im Dashboard hervorgehoben werden.
    var showSampleDataBanner: Bool
    var lastCatalogSyncAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        preferredLanguage: CardLanguage = .de,
        defaultCondition: CardCondition = .nearMint,
        showSampleDataBanner: Bool = false,
        lastCatalogSyncAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.preferredLanguageRaw = preferredLanguage.rawValue
        self.defaultConditionRaw = defaultCondition.rawValue
        self.showSampleDataBanner = showSampleDataBanner
        self.lastCatalogSyncAt = lastCatalogSyncAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var preferredLanguage: CardLanguage {
        get { CardLanguage(rawValue: preferredLanguageRaw) ?? .de }
        set { preferredLanguageRaw = newValue.rawValue }
    }

    var defaultCondition: CardCondition {
        get { CardCondition(rawValue: defaultConditionRaw) ?? .nearMint }
        set { defaultConditionRaw = newValue.rawValue }
    }
}
