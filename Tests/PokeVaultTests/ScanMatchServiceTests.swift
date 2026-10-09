import XCTest
@testable import PokeVault

final class ScanMatchServiceTests: XCTestCase {
    func testExtractHintsFindsNumberAndName() {
        let hints = ScanMatchService.extractHints(from: [
            "Umbreon V",
            "TG22/TG30",
            "HP 180"
        ])
        XCTAssertTrue(hints.localIds.contains("TG22"))
        XCTAssertTrue(hints.nameCandidates.contains(where: { $0.localizedCaseInsensitiveContains("Umbreon") }))
        XCTAssertFalse(hints.isEmpty)
    }

    func testScorePrefersExactNumberAndName() {
        let hints = OCRCardHints(
            nameCandidates: ["Umbreon V"],
            localIds: ["TG22"],
            setHints: ["swsh9tg"],
            rawLines: []
        )
        let good = TCGdexCardSummary(id: "swsh9tg-TG22", localId: "TG22", name: "Umbreon V", image: nil)
        let bad = TCGdexCardSummary(id: "swsh10tg-TG22", localId: "TG22", name: "Zamazenta V", image: nil)
        let goodScore = ScanMatchService.score(card: good, hints: hints)
        let badScore = ScanMatchService.score(card: bad, hints: hints)
        XCTAssertGreaterThan(goodScore.matchConfidence, badScore.matchConfidence)
        XCTAssertGreaterThanOrEqual(goodScore.matchConfidence, 0.7)
    }

    func testWrongNumberIsPenalized() {
        let hints = OCRCardHints(
            nameCandidates: ["Pikachu"],
            localIds: ["58"],
            setHints: [],
            rawLines: []
        )
        let wrong = TCGdexCardSummary(id: "base1-4", localId: "4", name: "Charizard", image: nil)
        let scored = ScanMatchService.score(card: wrong, hints: hints)
        XCTAssertLessThan(scored.matchConfidence, 0.5)
    }

    func testOverallConfidenceIsTopMatch() {
        let ranked = [
            RankedScanCandidate(
                card: TCGdexCardSummary(id: "a", localId: "1", name: "A", image: nil),
                setName: nil,
                matchConfidence: 0.91,
                matchReasons: ["test"]
            ),
            RankedScanCandidate(
                card: TCGdexCardSummary(id: "b", localId: "2", name: "B", image: nil),
                setName: nil,
                matchConfidence: 0.4,
                matchReasons: []
            )
        ]
        XCTAssertEqual(ScanMatchService.overallConfidence(from: ranked), 0.91)
        XCTAssertEqual(ScanMatchService.overallConfidence(from: []), 0)
    }
}
