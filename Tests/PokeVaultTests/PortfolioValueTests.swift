import XCTest
import SwiftData
@testable import PokeVault

@MainActor
final class PortfolioValueTests: XCTestCase {
    func testMarketPreferredOverManual() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let entry = CardCatalogEntry(tcgdexId: "swsh3-136", name: "Furret", setId: "swsh3", number: "136")
        context.insert(entry)
        let snapshot = PriceSnapshot(
            catalogEntry: entry,
            amountEUR: 1.25,
            source: .tcgdexCardmarket,
            metric: "trend"
        )
        context.insert(snapshot)
        let owned = OwnedCard(
            catalogEntry: entry,
            quantity: 2,
            purchasePrice: 0.50,
            manualValue: 9.99
        )
        context.insert(owned)

        let resolved = owned.resolvedUnitValue()
        XCTAssertEqual(resolved.value, 1.25)
        XCTAssertEqual(resolved.source, .tcgdexCardmarket)

        let line = owned.portfolioLine()
        XCTAssertEqual(line.purchaseTotal, 1.0)
        XCTAssertEqual(line.currentTotal, 2.5)
        XCTAssertEqual(line.difference, 1.5)
        XCTAssertEqual(line.percent!, 150.0, accuracy: 0.01)
    }

    func testManualFallbackWhenNoMarket() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let entry = CardCatalogEntry(tcgdexId: "local-1", name: "Manual", setId: "x", number: "1")
        context.insert(entry)
        let owned = OwnedCard(catalogEntry: entry, quantity: 1, purchasePrice: 3, manualValue: 5)
        context.insert(owned)

        let resolved = owned.resolvedUnitValue()
        XCTAssertEqual(resolved.value, 5)
        XCTAssertEqual(resolved.source, .manual)
    }

    func testPortfolioExcludesUnpricedFromCurrentButCountsThem() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext

        let pricedEntry = CardCatalogEntry(tcgdexId: "a", name: "A", setId: "s", number: "1")
        context.insert(pricedEntry)
        let priced = OwnedCard(catalogEntry: pricedEntry, quantity: 1, purchasePrice: 10, manualValue: 12)
        context.insert(priced)

        let bareEntry = CardCatalogEntry(tcgdexId: "b", name: "B", setId: "s", number: "2")
        context.insert(bareEntry)
        let bare = OwnedCard(catalogEntry: bareEntry, quantity: 3, purchasePrice: 1)
        context.insert(bare)

        let stats = CollectionValueService.compute(owned: [priced, bare])
        XCTAssertEqual(stats.totalOwnedCards, 4)
        XCTAssertEqual(stats.currentPortfolioValueEUR, 12)
        XCTAssertEqual(stats.cardsWithoutPrice, 3)
        XCTAssertEqual(stats.totalPurchaseCostEUR, 13) // 10 + 3*1
        XCTAssertEqual(stats.unrealizedGainLossEUR, 2) // only priced card in PnL
        XCTAssertEqual(stats.cardsInPnL, 1)
        XCTAssertEqual(stats.manuallyValuedCards, 1)
    }

    func testNoInventedZeroPurchase() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let entry = CardCatalogEntry(tcgdexId: "c", name: "C", setId: "s", number: "3")
        context.insert(entry)
        let owned = OwnedCard(catalogEntry: entry, quantity: 2, manualValue: 4)
        context.insert(owned)

        let stats = CollectionValueService.compute(owned: [owned])
        XCTAssertNil(stats.totalPurchaseCostEUR)
        XCTAssertEqual(stats.cardsWithoutPurchasePrice, 2)
        XCTAssertNil(stats.unrealizedGainLossEUR)
        XCTAssertEqual(stats.currentPortfolioValueEUR, 8)
    }
}
