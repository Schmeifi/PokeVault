import XCTest
@testable import PokeVault

final class CardRaritySortTests: XCTestCase {
    func testSecretRanksAboveCommon() {
        XCTAssertGreaterThan(CardRaritySort.rank("Secret Rare"), CardRaritySort.rank("Common"))
        XCTAssertGreaterThan(CardRaritySort.rank("Versteckt Selten"), CardRaritySort.rank("Häufig"))
    }

    func testIllustrationAboveRare() {
        XCTAssertGreaterThan(CardRaritySort.rank("Illustration rare"), CardRaritySort.rank("Rare"))
        XCTAssertGreaterThan(
            CardRaritySort.rank("Special illustration rare"),
            CardRaritySort.rank("Illustration rare")
        )
    }

    func testUnknownIsLowButAboveNil() {
        XCTAssertGreaterThan(CardRaritySort.rank("Mystery Fancy"), CardRaritySort.rank(nil))
    }

    func testCompareOrdersSecretFirst() {
        XCTAssertTrue(
            CardRaritySort.compare(lhs: "Secret Rare", rhs: "Common", nameL: "B", nameR: "A")
        )
    }
}

final class DiscoverCategoryTests: XCTestCase {
    func testPrefixes() {
        XCTAssertEqual(DiscoverCategory.trainerGallery.localIdPrefix, "TG")
        XCTAssertEqual(DiscoverCategory.galarianGallery.localIdPrefix, "GG")
        XCTAssertEqual(DiscoverCategory.shinyVault.localIdPrefix, "SV")
        XCTAssertNil(DiscoverCategory.illustrationRare.localIdPrefix)
    }

    func testRarityTokensDE() {
        let tokens = DiscoverCategory.secretRare.rarityLikeTokens(locale: "de")
        XCTAssertTrue(tokens.contains(where: { $0.localizedCaseInsensitiveContains("Versteckt") || $0.localizedCaseInsensitiveContains("Secret") }))
    }
}
