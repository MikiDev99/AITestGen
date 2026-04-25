import XCTest
@testable import AITestGenCore

final class AITestGenCoreTests: XCTestCase {
    func testVersion() {
        XCTAssertFalse(AITestGenCore.version.isEmpty)
    }
}
