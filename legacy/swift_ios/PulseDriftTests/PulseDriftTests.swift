import XCTest
@testable import PulseDrift

final class PulseDriftTests: XCTestCase {
    func testMultiplierCapsAtExpectedValue() {
        XCTAssertEqual(Balance.multiplier(for: 0), 1.0, accuracy: 0.001)
        XCTAssertEqual(Balance.multiplier(for: 25), 3.5, accuracy: 0.001)
    }

    func testSpeedScalesButStopsAtCap() {
        XCTAssertEqual(Balance.speed(for: 0), 300.0, accuracy: 0.001)
        XCTAssertEqual(Balance.speed(for: 11), 690.0, accuracy: 0.001)
        XCTAssertEqual(Balance.speed(for: 50), 820.0, accuracy: 0.001)
    }

    func testSpawnDelaysReachFloorValues() {
        XCTAssertEqual(Balance.gateSpawnDelay(for: 50), 0.42, accuracy: 0.001)
        XCTAssertEqual(Balance.sparkSpawnDelay(for: 80), 1.8, accuracy: 0.001)
    }
}
