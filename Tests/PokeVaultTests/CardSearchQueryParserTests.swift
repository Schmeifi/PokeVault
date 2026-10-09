import XCTest
@testable import PokeVault

final class CardSearchQueryParserTests: XCTestCase {
    func testTG22FromFreeText() {
        let parsed = CardSearchQueryParser.parse(freeText: "TG22")
        XCTAssertEqual(parsed.localId, "TG22")
        XCTAssertNil(parsed.name)
        XCTAssertTrue(parsed.looksLikeCardNumber)
    }

    func testSlashForm() {
        let parsed = CardSearchQueryParser.parse(freeText: "TG22/TG30")
        XCTAssertEqual(parsed.localId, "TG22")
        XCTAssertTrue(parsed.localIdAlternates.contains("TG30"))
    }

    func testNameStillWorks() {
        let parsed = CardSearchQueryParser.parse(freeText: "Nachtara")
        XCTAssertEqual(parsed.name, "Nachtara")
        XCTAssertNil(parsed.localId)
    }

    func testNumberFieldPreferred() {
        let parsed = CardSearchQueryParser.parse(freeText: "Umbreon", numberField: "TG22")
        XCTAssertEqual(parsed.localId, "TG22")
        XCTAssertEqual(parsed.name, "Umbreon")
    }

    func testCardIdExtract() {
        XCTAssertEqual(CardSearchQueryParser.extractLocalIdFromCardId("swsh9tg-TG22"), "TG22")
        XCTAssertEqual(CardSearchQueryParser.extractSetIdFromCardId("swsh9tg-TG22", localId: "TG22"), "swsh9tg")
    }
}
