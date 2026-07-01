import XCTest
@testable import CodexUsageCore

final class UsageModelsTests: XCTestCase {
    func testSnapshotTotalsCurrentMonthBuckets() {
        let calendar = Calendar(identifier: .gregorian)
        let buckets = [
            DailyUsageBucket(day: Date(timeIntervalSince1970: 1_767_008_800), inputTokens: 10, outputTokens: 20),
            DailyUsageBucket(day: Date(timeIntervalSince1970: 1_767_095_200), inputTokens: 30, outputTokens: 40)
        ]
        let snapshot = UsageSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_767_100_000),
            rateLimit: RateLimitSnapshot(usedPercent: 28, remainingPercent: 72, resetsAt: nil, planName: "Pro"),
            dailyBuckets: buckets,
            status: .ready
        )

        XCTAssertEqual(snapshot.totalTokens(in: calendar), 100)
        XCTAssertEqual(snapshot.todayTokens(on: buckets[1].day, calendar: calendar), 70)
        XCTAssertEqual(snapshot.rateLimit.remainingPercent, 72)
    }

    func testPercentFormatterClampsValues() {
        XCTAssertEqual(UsageFormatting.percentText(-5), "0%")
        XCTAssertEqual(UsageFormatting.percentText(72.4), "72%")
        XCTAssertEqual(UsageFormatting.percentText(101), "100%")
    }

    func testTimeUntilFormatterUsesFutureInterval() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(UsageFormatting.timeUntilText(Date(timeIntervalSince1970: 1_030), now: now), "less than 1m")
        XCTAssertEqual(UsageFormatting.timeUntilText(Date(timeIntervalSince1970: 1_600), now: now), "10m")
        XCTAssertEqual(UsageFormatting.timeUntilText(Date(timeIntervalSince1970: 8_200), now: now), "2h")
        XCTAssertEqual(UsageFormatting.timeUntilText(Date(timeIntervalSince1970: 174_000), now: now), "2d")
    }
}
