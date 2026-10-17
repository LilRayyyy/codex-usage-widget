import XCTest
@testable import CodexUsageCore

final class WidgetTimelineTests: XCTestCase {
    func testPlaceholderAsksForAFirstRefresh() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = WidgetTimeline.placeholder(now: now)

        XCTAssertEqual(entry.date, now)
        XCTAssertNil(entry.snapshot)
        XCTAssertEqual(entry.unavailableReason, .needsFirstRefresh)
    }

    func testNextReloadIsFiveMinutes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let next = WidgetTimeline.nextReloadDate(after: now, calendar: calendar)

        XCTAssertEqual(WidgetTimeline.reloadInterval, 300)
        XCTAssertEqual(next.timeIntervalSince(now), 300)
    }

    func testMissingContainerIsAppGroupSetup() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = WidgetTimeline.loadEntry(now: now, containerURL: nil)

        XCTAssertEqual(entry.date, now)
        XCTAssertNil(entry.snapshot)
        XCTAssertEqual(entry.unavailableReason, .missingAppGroup)
    }

    func testMissingCacheAsksForAFirstRefresh() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let entry = WidgetTimeline.loadEntry(now: now, containerURL: directory)

        XCTAssertNil(entry.snapshot)
        XCTAssertEqual(entry.unavailableReason, .needsFirstRefresh)
    }

    func testUnreadableCacheAsksForAFirstRefresh() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("usage-snapshot.json"))
        defer { try? FileManager.default.removeItem(at: directory) }

        let entry = WidgetTimeline.loadEntry(now: now, containerURL: directory)

        XCTAssertNil(entry.snapshot)
        XCTAssertEqual(entry.unavailableReason, .needsFirstRefresh)
    }

    func testAnyReadErrorAsksForAFirstRefresh() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = WidgetTimeline.loadEntry(
            now: now,
            containerURL: URL(fileURLWithPath: "/tmp/codex-usage-widget-tests")
        ) { _ in
            throw TestReadError()
        }

        XCTAssertNil(entry.snapshot)
        XCTAssertEqual(entry.unavailableReason, .needsFirstRefresh)
    }

    func testCachedErrorStatusStaysOnTheSnapshot() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = makeSnapshot(status: .unauthenticated, now: now)
        try UsageCacheStore(directory: directory).write(snapshot)

        let entry = WidgetTimeline.loadEntry(now: now, containerURL: directory)

        XCTAssertEqual(entry.snapshot, snapshot)
        XCTAssertNil(entry.unavailableReason)
        XCTAssertEqual(WidgetUnavailableReason(status: snapshot.status), .unauthenticated)
    }

    func testStatusMappingAndCopy() {
        XCTAssertNil(WidgetUnavailableReason(status: .ready))
        XCTAssertNil(WidgetUnavailableReason(status: .stale))
        XCTAssertEqual(WidgetUnavailableReason(status: .unauthenticated), .unauthenticated)
        XCTAssertEqual(WidgetUnavailableReason(status: .unsupportedAuth), .unsupportedAuth)
        XCTAssertEqual(
            WidgetUnavailableReason(status: .missingCodex),
            .failed("Codex app is not installed.")
        )
        XCTAssertEqual(WidgetUnavailableReason(status: .failed("nope")), .failed("nope"))

        let copies: [(WidgetUnavailableReason, String, String)] = [
            (.needsFirstRefresh, "Open app", "Open Codex Usage Widget and refresh once."),
            (.missingAppGroup, "Setup needed", "App and widget need the same App Group."),
            (.unauthenticated, "Sign in", "Sign in to Codex, then refresh the app."),
            (.unsupportedAuth, "Unavailable", "This Codex account does not expose usage data."),
            (.failed(""), "Refresh failed", "Open the app to inspect diagnostics."),
            (.failed("disk full"), "Refresh failed", "disk full"),
            (.failed("Codex app is not installed."), "Refresh failed", "Codex app is not installed.")
        ]
        for item in copies {
            XCTAssertEqual(item.0.title, item.1)
            XCTAssertEqual(item.0.message, item.2)
        }
    }

    private func makeSnapshot(status: RefreshStatus, now: Date) -> UsageSnapshot {
        UsageSnapshot(
            generatedAt: now,
            rateLimit: RateLimitSnapshot(
                usedPercent: 28,
                remainingPercent: 72,
                resetsAt: nil,
                planName: "Pro"
            ),
            dailyBuckets: [],
            status: status
        )
    }
}

private struct TestReadError: Error {}
