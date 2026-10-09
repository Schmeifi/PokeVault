import Foundation

/// Leichtgewichtiges DTO für Dashboard/Charts (Phase 1 ohne Historie-Erfindung).
struct CollectionStatsSnapshot: Identifiable, Sendable, Equatable {
    let id: UUID
    let capturedAt: Date
    let stats: CollectionStats
    let isSampleDerived: Bool

    init(id: UUID = UUID(), capturedAt: Date = .now, stats: CollectionStats) {
        self.id = id
        self.capturedAt = capturedAt
        self.stats = stats
        self.isSampleDerived = stats.usesSampleData
    }
}
