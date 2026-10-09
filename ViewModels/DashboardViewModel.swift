import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    var stats: CollectionStats = CollectionStats(
        totalOwnedCards: 0,
        uniqueCatalogCards: 0,
        estimatedValueEUR: nil,
        valueSourceSummary: PriceSource.unavailable.displayNameDE,
        usesSampleData: false,
        cardsWithoutPrice: 0,
        totalPurchaseCostEUR: nil,
        cardsWithoutPurchasePrice: 0,
        currentPortfolioValueEUR: nil,
        unrealizedGainLossEUR: nil,
        unrealizedGainLossPercent: nil,
        cardsInPnL: 0,
        cardsWithCurrentValue: 0,
        marketValuedCards: 0,
        manuallyValuedCards: 0
    )

    func refresh(owned: [OwnedCard]) {
        stats = CollectionValueService.compute(owned: owned)
    }
}
