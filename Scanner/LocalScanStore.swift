import Foundation
import SwiftData

/// Persistiert Scan-Metadaten lokal. Keine Cloud-Vision, keine kostenpflichtige API.
@MainActor
enum LocalScanStore {
    static func recordPendingScan(
        recognizedText: String?,
        imagePath: String?,
        in context: ModelContext
    ) -> CardScanResult {
        let result = CardScanResult(
            recognizedText: recognizedText,
            imagePath: imagePath,
            status: .pending,
            note: "Phase 1: Scan-Pipeline noch nicht aktiv"
        )
        context.insert(result)
        return result
    }
}
