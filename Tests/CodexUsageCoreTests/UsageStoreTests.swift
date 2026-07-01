import XCTest
@testable import CodexUsageCore

private struct MockClient: CodexAppServerClient {
    var usage: Result<[DailyUsageBucket], Error>
    var rateLimit: Result<RateLimitSnapshot, Error>

    func readUsage() async throws -> [DailyUsageBucket] {
        try usage.get()
    }

    func readRateLimits() async throws -> RateLimitSnapshot {
        try rateLimit.get()
    }
}

final class UsageStoreTests: XCTestCase {
    func testRefreshWritesReadySnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = UsageCacheStore(directory: directory)
        let client = MockClient(
            usage: .success([DailyUsageBucket(day: Date(timeIntervalSince1970: 1_767_095_200), inputTokens: 1, outputTokens: 2)]),
            rateLimit: .success(RateLimitSnapshot(usedPercent: 25, remainingPercent: 75, resetsAt: nil, planName: "Pro"))
        )
        let store = UsageStore(client: client, cache: cache)

        let snapshot = try await store.refresh(now: Date(timeIntervalSince1970: 1_767_100_000))
        let cached = try cache.read()

        XCTAssertEqual(snapshot.status, .ready)
        XCTAssertEqual(cached.rateLimit.remainingPercent, 75)
        XCTAssertEqual(cached.dailyBuckets.first?.totalTokens, 3)
    }

    func testUnsupportedAuthMapsToStatus() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = UsageCacheStore(directory: directory)
        let client = MockClient(
            usage: .failure(CodexClientError.unsupportedAuth),
            rateLimit: .success(RateLimitSnapshot(usedPercent: 0, remainingPercent: 0, resetsAt: nil, planName: nil))
        )
        let store = UsageStore(client: client, cache: cache)

        let snapshot = try await store.refresh(now: Date(timeIntervalSince1970: 1_767_100_000))

        XCTAssertEqual(snapshot.status, .unsupportedAuth)
    }
}
