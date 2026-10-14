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

    func testSymbolUnivRewritesToEnglishAsset() {
        let urls = TCGdexImageURL.setAssetCandidates(
            logo: nil,
            symbol: "https://assets.tcgdex.net/univ/swsh/swsh3/symbol"
        ).map(\.absoluteString)
        XCTAssertTrue(urls.contains("https://assets.tcgdex.net/en/swsh/swsh3/symbol.webp"))
        XCTAssertTrue(urls.contains("https://assets.tcgdex.net/en/swsh/swsh3/symbol.png"))
    }

    func testMissingGermanCardImageUsesEnglishSeriePath() {
        let bases = TCGdexImageURL.fallbackCardBases(serieId: "base", setId: "base1", localId: "4")
        XCTAssertEqual(bases.first, "https://assets.tcgdex.net/en/base/base1/4")
    }

    func testTrainerGalleryUsesParentSet() {
        let bases = TCGdexImageURL.fallbackCardBases(serieId: "swsh", setId: "swsh9tg", localId: "TG01")
        XCTAssertEqual(bases.first, "https://assets.tcgdex.net/en/swsh/swsh9/TG01")
    }

    func testCelebrationsUsesSerieNotLetterPrefix() {
        let bases = TCGdexImageURL.fallbackCardBases(serieId: "swsh", setId: "cel25", localId: "1")
        XCTAssertEqual(bases.first, "https://assets.tcgdex.net/en/swsh/cel25/1")
    }

    func testGalleryParentSetId() {
        XCTAssertEqual(TCGdexImageURL.galleryParentSetId("swsh9tg"), "swsh9")
        XCTAssertNil(TCGdexImageURL.galleryParentSetId("base1"))
    }
}
