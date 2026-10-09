import Foundation
import SwiftData

/// Ergebnis eines lokalen Scans (Phase 1: Platzhalter-Persistenz, keine Cloud-KI).
@Model
final class CardScanResult {
    @Attribute(.unique) var id: UUID
    var recognizedText: String?
    var suggestedTcgdexId: String?
    var confidence: Double?
    var imagePath: String?
    var statusRaw: String
    var createdAt: Date
    var note: String?

    init(
        id: UUID = UUID(),
        recognizedText: String? = nil,
        suggestedTcgdexId: String? = nil,
        confidence: Double? = nil,
        imagePath: String? = nil,
        status: ScanStatus = .pending,
        createdAt: Date = .now,
        note: String? = nil
    ) {
        self.id = id
        self.recognizedText = recognizedText
        self.suggestedTcgdexId = suggestedTcgdexId
        self.confidence = confidence
        self.imagePath = imagePath
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.note = note
    }

    var status: ScanStatus {
        get { ScanStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

enum ScanStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case matched
    case needsReview
    case failed

    var displayNameDE: String {
        switch self {
        case .pending: return "Ausstehend"
        case .matched: return "Zugeordnet"
        case .needsReview: return "Prüfung nötig"
        case .failed: return "Fehlgeschlagen"
        }
    }
}
