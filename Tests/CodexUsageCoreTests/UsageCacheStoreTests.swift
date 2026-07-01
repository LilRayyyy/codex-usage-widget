import XCTest
@testable import CodexUsageCore

final class UsageCacheStoreTests: XCTestCase {
    func testWritesAndReadsSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = UsageCacheStore(directory: directory)
        let snapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_767_100_000.123456))

        try store.write(snapshot)
        let loaded = try store.read()

        XCTAssertEqual(loaded, snapshot)
    }

    func testRepeatedWritesReadLatestSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = UsageCacheStore(directory: directory)
        let firstSnapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_767_100_000.123456), planName: "Team")
        let secondSnapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_767_100_123.654321), planName: "Enterprise")

        try store.write(firstSnapshot)
        try store.write(secondSnapshot)

        XCTAssertEqual(try store.read(), secondSnapshot)
    }

    func testUsesCustomFileName() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = UsageCacheStore(directory: directory, fileName: "custom-snapshot.json")
        let snapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_767_100_000.123456))

        try store.write(snapshot)

        XCTAssertEqual(store.fileURL.lastPathComponent, "custom-snapshot.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(try store.read(), snapshot)
    }

    func testWritesDatesAsSecondsSince1970Numbers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = UsageCacheStore(directory: directory)
        let snapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_767_100_000.123456))

        try store.write(snapshot)

        let data = try Data(contentsOf: store.fileURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let generatedAt = try XCTUnwrap(json["generatedAt"] as? Double)
        XCTAssertEqual(generatedAt, snapshot.generatedAt.timeIntervalSince1970)
    }

    private func makeSnapshot(generatedAt: Date, planName: String = "Team") -> UsageSnapshot {
        UsageSnapshot(
            generatedAt: generatedAt,
            rateLimit: RateLimitSnapshot(usedPercent: 20, remainingPercent: 80, resetsAt: nil, planName: planName),
            dailyBuckets: [DailyUsageBucket(day: Date(timeIntervalSince1970: 1_767_095_200.123456), inputTokens: 12, outputTokens: 8)],
            status: .ready
        )
    }
}
