import XCTest
@testable import CodexUsageCore

final class HeatmapScaleTests: XCTestCase {
    func testIntensityUsesZeroForNoUsage() {
        XCTAssertEqual(HeatmapScale.intensity(for: 0, maximum: 100), 0)
    }

    func testIntensityClampsIntoFourLevels() {
        XCTAssertEqual(HeatmapScale.intensity(for: 1, maximum: 100), 1)
        XCTAssertEqual(HeatmapScale.intensity(for: 35, maximum: 100), 2)
        XCTAssertEqual(HeatmapScale.intensity(for: 70, maximum: 100), 3)
        XCTAssertEqual(HeatmapScale.intensity(for: 100, maximum: 100), 4)
        XCTAssertEqual(HeatmapScale.intensity(for: 200, maximum: 100), 4)
    }
}
