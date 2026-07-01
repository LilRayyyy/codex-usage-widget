import XCTest
@testable import CodexUsageCore

final class CodexAppServerClientTests: XCTestCase {
    func testMapsUnauthorizedError() async {
        let error = DefaultCodexAppServerClient.mapRPCError(JSONRPCError(code: 401, message: "not authenticated"))
        XCTAssertEqual(error, .unauthenticated)
    }

    func testMapsUsageDailyBuckets() throws {
        let data = Data(#"{"dailyUsageBuckets":[{"startDate":"2026-06-29","tokens":1200}],"summary":{"lifetimeTokens":1200}}"#.utf8)
        let response = try JSONDecoder().decode(GetAccountTokenUsageResponse.self, from: data)
        let buckets = try DefaultCodexAppServerClient.mapUsage(response)

        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets[0].totalTokens, 1200)
    }

    func testMapsRateLimitsFromPrimaryWindow() throws {
        let data = Data(#"{"rateLimits":{"planType":"pro","primary":{"usedPercent":28,"resetsAt":1780000000,"windowDurationMins":300},"secondary":{"usedPercent":41,"resetsAt":1780500000,"windowDurationMins":10080}}}"#.utf8)
        let response = try JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: data)
        let snapshot = DefaultCodexAppServerClient.mapRateLimits(response)

        XCTAssertEqual(snapshot.usedPercent, 28)
        XCTAssertEqual(snapshot.remainingPercent, 72)
        XCTAssertEqual(snapshot.planName, "pro")
        XCTAssertEqual(snapshot.weeklyUsedPercent, 41)
        XCTAssertEqual(snapshot.weeklyRemainingPercent, 59)
        XCTAssertEqual(snapshot.weeklyResetsAt, Date(timeIntervalSince1970: 1_780_500_000))
    }
}
