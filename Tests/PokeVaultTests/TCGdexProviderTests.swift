import XCTest
@testable import PokeVault

final class TCGdexProviderTests: XCTestCase {
    func testPriceSourceDisplayNamesAreGerman() {
        XCTAssertEqual(PriceSource.unavailable.displayNameDE, "Kein Marktpreis verfügbar")
        XCTAssertTrue(PriceSource.tcgdexCardmarket.isRealMarketData)
        XCTAssertFalse(PriceSource.sample.isRealMarketData)
    }

    func testFetchedPriceUnavailableFactory() {
        let price = FetchedPrice.unavailable
        XCTAssertNil(price.amountEUR)
        XCTAssertEqual(price.source, .unavailable)
    }
}
