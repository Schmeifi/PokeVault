import XCTest
import SwiftData
@testable import PokeVault

@MainActor
final class CollectionValueServiceTests: XCTestCase {
    func testUnavailableWhenNoPrices() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext

        let entry = CardCatalogEntry(
            tcgdexId: "test-1",
            name: "Test",
            setId: "s1",
            number: "1"
        )
        context.insert(entry)
        let owned = OwnedCard(catalogEntry: entry, quantity: 2)
        context.insert(owned)

        let stats = CollectionValueService.compute(owned: [owned])
        XCTAssertEqual(stats.totalOwnedCards, 2)
        XCTAssertNil(stats.estimatedValueEUR)
        XCTAssertEqual(stats.cardsWithoutPrice, 2)
        XCTAssertFalse(stats.usesSampleData)
    }

    func testManualValuePreferred() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext

        let entry = CardCatalogEntry(
            tcgdexId: "test-2",
            name: "Manual",
            setId: "s1",
            number: "2"
        )
        context.insert(entry)
        let owned = OwnedCard(catalogEntry: entry, quantity: 1, manualValue: 4.5)
        context.insert(owned)

        let stats = CollectionValueService.compute(owned: [owned])
        XCTAssertEqual(stats.estimatedValueEUR, 4.5)
        XCTAssertEqual(stats.cardsWithoutPrice, 0)
    }

    func testSampleDataFlag() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let loaded = SampleDataSeeder.loadSampleData(in: context, force: true)
        XCTAssertTrue(loaded)

        let owned = try context.fetch(FetchDescriptor<OwnedCard>())
        let stats = CollectionValueService.compute(owned: owned)
        XCTAssertTrue(stats.totalOwnedCards > 0)
        XCTAssertTrue(stats.usesSampleData)
    }

    func testSeedIfNeededDoesNotInsertCards() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        SampleDataSeeder.seedIfNeeded(in: context)
        let ownedCount = try context.fetchCount(FetchDescriptor<OwnedCard>())
        XCTAssertEqual(ownedCount, 0)
        let settingsCount = try context.fetchCount(FetchDescriptor<AppSettings>())
        XCTAssertEqual(settingsCount, 1)
    }
}
