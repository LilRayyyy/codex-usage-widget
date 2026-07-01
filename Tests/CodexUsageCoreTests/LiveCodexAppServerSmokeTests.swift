import XCTest
@testable import CodexUsageCore

final class LiveCodexAppServerSmokeTests: XCTestCase {
    func testReadsLiveUsageAndRateLimitsWhenEnabled() async throws {
        guard ProcessInfo.processInfo.environment["LIVE_CODEX_APP_SERVER_TEST"] == "1" else {
            throw XCTSkip("Set LIVE_CODEX_APP_SERVER_TEST=1 to run the live Codex app-server smoke test.")
        }

        let executableURL = URL(fileURLWithPath: "/Applications/Codex.app/Contents/Resources/codex")
        let client = DefaultCodexAppServerClient(transport: CodexStdioTransport(executableURL: executableURL))

        let usage = try await client.readUsage()
        let rateLimit = try await client.readRateLimits()

        XCTAssertFalse(usage.isEmpty)
        XCTAssertGreaterThanOrEqual(rateLimit.remainingPercent, 0)
        XCTAssertLessThanOrEqual(rateLimit.remainingPercent, 100)
    }
}
