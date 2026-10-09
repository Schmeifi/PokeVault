import XCTest
@testable import PokeVault

final class TCGdexImageURLTests: XCTestCase {
    func testCardHighWebP() {
        let url = TCGdexImageURL.card(
            "https://assets.tcgdex.net/en/swsh/swsh3/136",
            quality: .high,
            format: .webp
        )
        XCTAssertEqual(
            url?.absoluteString,
            "https://assets.tcgdex.net/en/swsh/swsh3/136/high.webp"
        )
    }

    func testCardLowPng() {
        let url = TCGdexImageURL.card(
            "https://assets.tcgdex.net/en/swsh/swsh3/136",
            quality: .low,
            format: .png
        )
        XCTAssertEqual(
            url?.absoluteString,
            "https://assets.tcgdex.net/en/swsh/swsh3/136/low.png"
        )
    }

    func testSetLogoHasNoQualitySegment() {
        let url = TCGdexImageURL.setAsset("https://assets.tcgdex.net/en/swsh/swsh3/logo")
        XCTAssertEqual(
            url?.absoluteString,
            "https://assets.tcgdex.net/en/swsh/swsh3/logo.webp"
        )
    }

    func testNilAndEmpty() {
        XCTAssertNil(TCGdexImageURL.card(nil))
        XCTAssertNil(TCGdexImageURL.card("  "))
        XCTAssertNil(TCGdexImageURL.setAsset(nil))
    }

    func testAlreadyHasExtension() {
        let url = TCGdexImageURL.card("https://example.com/card.webp")
        XCTAssertEqual(url?.absoluteString, "https://example.com/card.webp")
    }
}
