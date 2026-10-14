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

    func testExtractCardNumbersFromNoisyOCR() {
        let nums = CardSearchQueryParser.extractCardNumbers(from: [
            "Illus. AKIRA",
            "TG22/TG30",
            "025/189",
            "HP 70"
        ])
        XCTAssertTrue(nums.contains("TG22"), nums.description)
        XCTAssertTrue(nums.contains(where: { $0 == "025" || $0 == "25" }), nums.description)
    }

    func testNumberZoneHintsPreferCollectorNumber() {
        let hints = ScanMatchService.extractHints(
            from: ["Pikachu", "HP 60", "Electric"],
            numberPriorityLines: ["TG22/TG30"]
        )
        XCTAssertEqual(hints.localIds.first, "TG22")
    }

    func testIdentityReadsCollectorNumberHPAndIllustrator() {
        let identity = CardIdentityParser.parse([
            .init(text: "Glurak", topFraction: 0.06),
            .init(text: "120 KP", topFraction: 0.08),
            .init(text: "Feuersturm", topFraction: 0.48),
            .init(text: "Illus. Mitsuhiro Arita", topFraction: 0.86),
            .init(text: "4/102", topFraction: 0.9)
        ])
        XCTAssertEqual(identity.nameCandidates, ["Glurak"])
        XCTAssertEqual(identity.hp, 120)
        XCTAssertEqual(identity.collectorNumbers.first, "4")
        XCTAssertEqual(identity.printedSetCount, 102)
        XCTAssertEqual(identity.illustrator, "Mitsuhiro Arita")
        XCTAssertFalse(identity.nameCandidates.contains("Feuersturm"))
    }

    func testHintsExposeIdentityInsteadOfAttackText() {
        let hints = ScanMatchService.extractHints(positioned: [
            .init(text: "Umbreon V", topFraction: 0.05),
            .init(text: "HP 180", topFraction: 0.08),
            .init(text: "Moonlight", topFraction: 0.5),
            .init(text: "TG22/TG30", topFraction: 0.9)
        ])
        XCTAssertEqual(hints.nameCandidates, ["Umbreon V"])
        XCTAssertEqual(hints.hp, 180)
        XCTAssertEqual(hints.localIds.first, "TG22")
        XCTAssertNil(hints.printedSetCount)
        XCTAssertTrue(hints.identityReadout.contains("Umbreon V"))
        XCTAssertFalse(hints.nameCandidates.contains("Moonlight"))
    }

    func testBottomStripSuppliesNumberAndIllustrator() {
        let hints = ScanMatchService.extractHints(
            positioned: [
                .init(text: "Glurak", topFraction: 0.07)
            ],
            numberPriorityLines: ["Illus. Mitsuhiro Arita", "4/102"]
        )
        XCTAssertEqual(hints.nameCandidates, ["Glurak"])
        XCTAssertEqual(hints.localIds.first, "4")
        XCTAssertEqual(hints.printedSetCount, 102)
        XCTAssertEqual(hints.illustrator, "Mitsuhiro Arita")
        XCTAssertTrue(hints.identityReadout.contains("#4/102"))
    }

    func testKokoweiIgnoresRuleTextAndSetSize() {
        let hints = ScanMatchService.extractHints(positioned: [
            .init(text: "Alola-Kokowei V KP 240", topFraction: 0.08),
            .init(text: "BASIS", topFraction: 0.14),
            .init(text: "In die Höhe sprießen", topFraction: 0.46),
            .init(text: "Wenn dein Pokémon-V kampfunfähig", topFraction: 0.78),
            .init(text: "Illus. tr. MUGENUP", topFraction: 0.90),
            .init(text: "005/078", topFraction: 0.93)
        ])
        XCTAssertEqual(hints.nameCandidates, ["Alola-Kokowei V"])
        XCTAssertEqual(hints.hp, 240)
        XCTAssertEqual(hints.localIds.first, "005")
        XCTAssertFalse(hints.localIds.contains("5"))
        XCTAssertFalse(hints.localIds.contains("78"))
        XCTAssertFalse(hints.localIds.contains("078"))
        XCTAssertEqual(hints.printedSetCount, 78)
        XCTAssertEqual(hints.illustrator, "MUGENUP")
        XCTAssertFalse(hints.nameCandidates.contains(where: { $0.contains("kampfunfähig") }))
    }

    func testGluedKokoweiNumberSplitsIntoCollectorAndSetSize() {
        let hints = ScanMatchService.extractHints(positioned: [
            .init(text: "Alola-Kokowei", topFraction: 0.08),
            .init(text: "Illus. MUGENUP", topFraction: 0.88),
            .init(text: "005778", topFraction: 0.93),
            .init(text: "F", topFraction: 0.96)
        ])
        XCTAssertEqual(hints.nameCandidates, ["Alola-Kokowei"])
        XCTAssertEqual(hints.localIds.first, "005")
        XCTAssertFalse(hints.localIds.contains("5"))
        XCTAssertFalse(hints.localIds.contains("778"))
        XCTAssertFalse(hints.localIds.contains("005778"))
        XCTAssertEqual(hints.printedSetCount, 778)
        XCTAssertEqual(hints.illustrator, "MUGENUP")
        XCTAssertEqual(hints.regulationMark, "F")
        XCTAssertTrue(hints.identityReadout.contains("#005"))
        XCTAssertFalse(hints.identityReadout.contains("#005/778"))
    }

    func testShiftedSlashIsReadAsThreePlusThree() {
        XCTAssertEqual(CardIdentityParser.collectorPair(in: "0057/78")?.number, "005")
        XCTAssertEqual(CardIdentityParser.collectorPair(in: "0057/78")?.setCount, 778)
        XCTAssertEqual(CardIdentityParser.collectorPair(in: "005/078")?.number, "005")
        XCTAssertEqual(CardIdentityParser.collectorPair(in: "005/078")?.setCount, 78)
        XCTAssertEqual(CardIdentityParser.collectorPair(in: "005/778")?.number, "005")
        XCTAssertEqual(CardIdentityParser.collectorPair(in: "005/778")?.setCount, 778)
        XCTAssertEqual(CardIdentityParser.collectorPair(in: "4/102")?.number, "4")
        XCTAssertEqual(CardIdentityParser.collectorPair(in: "4/102")?.setCount, 102)
        XCTAssertEqual(CardIdentityParser.collectorPair(in: "TG22/TG30")?.number, "TG22")
        XCTAssertNil(CardIdentityParser.collectorPair(in: "TG22/TG30")?.setCount)
    }

    func testKokoweiSpeciesOutranksPapunga() {
        let hints = OCRCardHints(
            nameCandidates: ["Alola-Kokowei"],
            localIds: ["005", "5"],
            setHints: [],
            rawLines: [],
            printedSetCount: 78,
            illustrator: "MUGENUP",
            regulationMark: "F"
        )
        let v = TCGdexCardSummary(id: "swsh10.5-005", localId: "005", name: "Alola-Kokowei V", image: nil)
        let otherPrint = TCGdexCardSummary(id: "swsh10.5-071", localId: "071", name: "Alola-Kokowei V", image: nil)
        let papunga = TCGdexCardSummary(id: "xy11-5", localId: "5", name: "Papungha", image: nil)
        let plain = TCGdexCardSummary(id: "sm6-2", localId: "2", name: "Alola-Kokowei", image: nil)
        let ranked = ScanMatchService.preferMatchingCandidates(
            [papunga, plain, otherPrint, v].map { ScanMatchService.score(card: $0, hints: hints) },
            hints: hints
        )
        XCTAssertEqual(ranked.first?.card.id, "swsh10.5-005")
        XCTAssertFalse(ranked.contains { $0.card.id == "xy11-5" })
        XCTAssertGreaterThan(
            ScanMatchService.score(card: v, hints: hints).matchConfidence,
            ScanMatchService.score(card: papunga, hints: hints).matchConfidence
        )
    }

    func testSpacedNameStillMatchesHyphenatedSpecies() {
        let hints = OCRCardHints(
            nameCandidates: ["Alola Kokowei"],
            localIds: ["005778"],
            setHints: [],
            rawLines: []
        )
        let v = TCGdexCardSummary(id: "swsh10.5-005", localId: "005", name: "Alola-Kokowei V", image: nil)
        let papunga = TCGdexCardSummary(id: "xy11-5", localId: "5", name: "Papungha", image: nil)
        let scored = ScanMatchService.score(card: v, hints: hints)
        XCTAssertGreaterThanOrEqual(scored.matchConfidence, ScanMatchService.minDisplayConfidence)
        XCTAssertTrue(scored.matchReasons.contains { $0.hasPrefix("Name") })
        let ranked = ScanMatchService.preferMatchingCandidates(
            [papunga, v].map { ScanMatchService.score(card: $0, hints: hints) },
            hints: hints
        )
        XCTAssertEqual(ranked.first?.card.id, "swsh10.5-005")
        XCTAssertEqual(
            ScanMatchService.nameQueryVariants("Alola Kokowei").first?.lowercased(),
            "alola-kokowei"
        )
        XCTAssertEqual(ScanMatchService.likeNameQuery("Alola-Kokowei"), "like:alola-kokowei")
        XCTAssertEqual(ScanMatchService.searchableLocalIds(["005", "5"]), ["005"])
    }

    func testPaddedNumberDoesNotPromoteAnotherCardFive() {
        let hints = OCRCardHints(
            nameCandidates: ["Alola-Kokowei"],
            localIds: ["005"],
            setHints: [],
            rawLines: [],
            illustrator: "MUGENUP",
            regulationMark: "F"
        )
        let v = TCGdexCardSummary(id: "swsh10.5-005", localId: "005", name: "Alola-Kokowei V", image: nil)
        let sumpex = TCGdexCardSummary(id: "pop1-5", localId: "5", name: "Sumpex", image: nil)
        let ranked = ScanMatchService.preferMatchingCandidates(
            [sumpex, v].map { ScanMatchService.score(card: $0, hints: hints) },
            hints: hints
        )
        XCTAssertEqual(ranked.first?.card.id, "swsh10.5-005")
        XCTAssertFalse(ranked.contains { $0.card.id == "pop1-5" })
        XCTAssertGreaterThan(
            ScanMatchService.score(card: v, hints: hints).matchConfidence,
            ScanMatchService.score(card: sumpex, hints: hints).matchConfidence
        )
    }

    func testImplausibleSetCountDoesNotPenalizeTheRealSet() {
        let hints = OCRCardHints(
            nameCandidates: ["Alola-Kokowei"],
            localIds: ["005"],
            setHints: [],
            rawLines: [],
            printedSetCount: 778,
            illustrator: "MUGENUP",
            regulationMark: "F"
        )
        let detail = TCGdexCardDetail(
            id: "swsh10.5-005",
            localId: "005",
            name: "Alola-Kokowei V",
            image: nil,
            illustrator: "MUGENUP",
            rarity: nil,
            category: nil,
            types: nil,
            set: TCGdexEmbeddedSet(
                id: "swsh10.5",
                name: "Pokémon GO",
                logo: nil,
                symbol: nil,
                cardCount: TCGdexCardCount(
                    total: 88,
                    official: 78,
                    firstEd: nil,
                    holo: nil,
                    normal: nil,
                    reverse: nil
                )
            ),
            variants: nil,
            pricing: nil,
            variants_detailed: nil,
            hp: 240,
            stage: nil,
            evolveFrom: nil,
            description: nil,
            regulationMark: "F",
            legal: nil,
            updated: nil
        )
        let wrongIllustrator = TCGdexCardDetail(
            id: "sm6-2",
            localId: "2",
            name: "Alola-Kokowei",
            image: nil,
            illustrator: "Satoshi Shirai",
            rarity: nil,
            category: nil,
            types: nil,
            set: nil,
            variants: nil,
            pricing: nil,
            variants_detailed: nil,
            hp: 160,
            stage: nil,
            evolveFrom: nil,
            description: nil,
            regulationMark: nil,
            legal: nil,
            updated: nil
        )
        let match = ScanMatchService.identityAdjustment(detail: detail, hints: hints)
        XCTAssertGreaterThan(match.delta, 0)
        XCTAssertTrue(match.reasons.contains("Illustrator"))
        XCTAssertTrue(match.reasons.contains("Marke F"))
        XCTAssertFalse(match.reasons.contains { $0.contains("Setgröße") })
        let miss = ScanMatchService.identityAdjustment(detail: wrongIllustrator, hints: hints)
        XCTAssertLessThan(miss.delta, 0)
    }

    func testScoreOrdersExactNumberAboveNameOnly() {
        let hints = OCRCardHints(
            nameCandidates: ["Pikachu"],
            localIds: ["58"],
            setHints: [],
            rawLines: []
        )
        let numbered = TCGdexCardSummary(id: "base1-58", localId: "58", name: "Raichu", image: nil)
        let named = TCGdexCardSummary(id: "base1-58b", localId: "60", name: "Pikachu", image: nil)
        let a = ScanMatchService.score(card: numbered, hints: hints)
        let b = ScanMatchService.score(card: named, hints: hints)
        XCTAssertGreaterThan(a.matchConfidence, b.matchConfidence)
    }

}
