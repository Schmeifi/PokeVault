import XCTest
@testable import PokeVault

final class MockProviderTests: XCTestCase {
    func testMockFindsTG22() async throws {
        let mock = MockTCGdexProvider()
        let cards = try await mock.search(localId: "TG22", name: nil, locale: "de")
        XCTAssertEqual(cards.first?.name, "Nachtara V")
    }

    func testMockError() async {
        let mock = MockTCGdexProvider()
        await mock.setShouldFail(true)
        do {
            _ = try await mock.search(localId: "TG22", name: nil, locale: "de")
            XCTFail("expected error")
        } catch {
            // ok
        }
    }
}
