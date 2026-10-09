import XCTest
import SwiftData
@testable import PokeVault

@MainActor
final class BackupServiceTests: XCTestCase {
    func testExportImportRoundTrip() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let entry = CardCatalogEntry(tcgdexId: "swsh9tg-TG22", name: "Nachtara V", setId: "swsh9tg", setName: "TG", number: "TG22")
        context.insert(entry)
        context.insert(OwnedCard(catalogEntry: entry, quantity: 1, purchasePrice: 40))
        try context.save()

        let owned = try context.fetch(FetchDescriptor<OwnedCard>())
        let payload = BackupService.makePayload(owned: owned, wishlist: [], catalog: [entry])
        let data = try BackupService.exportJSON(payload: payload)

        let container2 = try ModelContainerFactory.make(inMemory: true)
        let count = try BackupService.importJSON(data, into: container2.mainContext)
        XCTAssertEqual(count, 1)
        let imported = try container2.mainContext.fetch(FetchDescriptor<OwnedCard>())
        XCTAssertEqual(imported.first?.catalogEntry?.tcgdexId, "swsh9tg-TG22")
    }

    func testCSVContainsHeader() {
        let csv = BackupService.exportCSV(owned: [])
        XCTAssertTrue(csv.hasPrefix("tcgdexId,name"))
    }
}
