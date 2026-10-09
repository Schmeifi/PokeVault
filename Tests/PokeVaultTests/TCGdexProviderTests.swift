import XCTest
@testable import PokeVault

final class TCGdexProviderTests: XCTestCase {
    func testPriceSourceDisplayNamesAreGerman() {
        XCTAssertEqual(PriceSource.unavailable.displayNameDE, "Kein Marktpreis verfügbar")
        XCTAssertTrue(PriceSource.tcgdexCardmarket.isRealMarketData)
        XCTAssertFalse(PriceSource.sample.isRealMarketData)
        XCTAssertFalse(PriceSource.manual.isRealMarketData)
    }

    func testFetchedPriceUnavailableFactory() {
        let price = FetchedPrice.unavailable
        XCTAssertNil(price.amountEUR)
        XCTAssertEqual(price.source, .unavailable)
    }

    func testSearchQueryEmptyDetection() {
        XCTAssertTrue(TCGdexCardSearchQuery().isEmpty)
        XCTAssertFalse(TCGdexCardSearchQuery(name: "Pikachu").isEmpty)
        XCTAssertFalse(TCGdexCardSearchQuery(setId: "swsh3").isEmpty)
        XCTAssertFalse(TCGdexCardSearchQuery(localId: "25").isEmpty)
        XCTAssertTrue(TCGdexCardSearchQuery(name: "  ").isEmpty)
    }

    func testVariantLabelsFromFlags() throws {
        let json = """
        {
          "id": "swsh3-136",
          "name": "Furret",
          "variants": {
            "firstEdition": false,
            "holo": false,
            "normal": true,
            "reverse": true,
            "wPromo": false
          }
        }
        """.data(using: .utf8)!
        let detail = try JSONDecoder().decode(TCGdexCardDetail.self, from: json)
        XCTAssertEqual(detail.availableVariantLabels, ["normal", "reverse"])
        XCTAssertTrue(detail.printingSummary.contains("reverse"))
    }
}
