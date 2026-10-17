import XCTest
@testable import CodexUsageCore

final class CodexAppServerFixtureTests: XCTestCase {
    func testReadUsageDecodesFixtureAndRecordsTheMethod() async throws {
        let transport = FixtureTransport(results: [
            "account/usage/read": .success(try TestFixtures.data(named: "usage-daily-buckets.json"))
        ])
        let client = DefaultCodexAppServerClient(transport: transport)

        let buckets = try await client.readUsage()

        XCTAssertEqual(transport.recordedMethods(), ["account/usage/read"])
        XCTAssertEqual(buckets.map(\.inputTokens), [1200, 50])
        XCTAssertEqual(buckets.map(\.outputTokens), [0, 0])
        XCTAssertEqual(dayLabels(buckets.map(\.day)), ["2026-06-29", "2026-06-30"])
    }

    func testReadUsageTreatsAMissingBucketListAsEmpty() async throws {
        let client = try client(method: "account/usage/read", fixture: "usage-no-buckets.json")

        let buckets = try await client.readUsage()

        XCTAssertEqual(buckets, [])
    }

    func testReadUsageRejectsAnUnparseableBucketDate() async throws {
        let client = try client(method: "account/usage/read", fixture: "usage-invalid-date.json")

        do {
            _ = try await client.readUsage()
            XCTFail("Expected an invalid bucket date")
        } catch let error as CodexClientError {
            XCTAssertEqual(error, .invalidResponse("Invalid usage bucket date: 29-06-2026"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadRateLimitsUsesThePrimaryAndWeeklyWindows() async throws {
        let client = try client(method: "account/rateLimits/read", fixture: "rate-limits-primary-weekly.json")

        let snapshot = try await client.readRateLimits()

        XCTAssertEqual(snapshot.planName, "pro")
        XCTAssertEqual(snapshot.usedPercent, 28)
        XCTAssertEqual(snapshot.remainingPercent, 72)
        XCTAssertEqual(snapshot.resetsAt, Date(timeIntervalSince1970: 1_780_000_000))
        XCTAssertEqual(snapshot.weeklyUsedPercent, 41)
        XCTAssertEqual(snapshot.weeklyRemainingPercent, 59)
        XCTAssertEqual(snapshot.weeklyResetsAt, Date(timeIntervalSince1970: 1_780_500_000))
    }

    func testReadRateLimitsPrefersTheCodexLimitId() async throws {
        let client = try client(method: "account/rateLimits/read", fixture: "rate-limits-codex-limit-id.json")

        let snapshot = try await client.readRateLimits()

        XCTAssertEqual(snapshot.planName, "pro")
        XCTAssertEqual(snapshot.usedPercent, 10)
        XCTAssertEqual(snapshot.remainingPercent, 90)
        XCTAssertEqual(snapshot.resetsAt, Date(timeIntervalSince1970: 1_780_000_000))
        XCTAssertEqual(snapshot.weeklyUsedPercent, 15)
        XCTAssertEqual(snapshot.weeklyRemainingPercent, 85)
        XCTAssertEqual(snapshot.weeklyResetsAt, Date(timeIntervalSince1970: 1_780_500_000))
    }

    func testReadRateLimitsIgnoresLimitIdsOtherThanCodex() async throws {
        let client = try client(method: "account/rateLimits/read", fixture: "rate-limits-other-limit-id.json")

        let snapshot = try await client.readRateLimits()

        XCTAssertEqual(snapshot.planName, "pro")
        XCTAssertEqual(snapshot.usedPercent, 28)
        XCTAssertEqual(snapshot.remainingPercent, 72)
        XCTAssertNil(snapshot.weeklyUsedPercent)
    }

    func testReadRateLimitsDerivesUsageFromAnIndividualLimit() async throws {
        let client = try client(method: "account/rateLimits/read", fixture: "rate-limits-individual-only.json")

        let snapshot = try await client.readRateLimits()

        XCTAssertEqual(snapshot.planName, "plus")
        XCTAssertEqual(snapshot.usedPercent, 40)
        XCTAssertEqual(snapshot.remainingPercent, 60)
        XCTAssertEqual(snapshot.resetsAt, Date(timeIntervalSince1970: 1_780_000_000))
        XCTAssertNil(snapshot.weeklyRemainingPercent)
    }

    func testIndividualRemainingWinsWhenPrimaryUsedPercentIsAlsoPresent() async throws {
        let client = try client(
            method: "account/rateLimits/read",
            fixture: "rate-limits-primary-and-individual.json"
        )

        let snapshot = try await client.readRateLimits()

        XCTAssertEqual(snapshot.usedPercent, 28)
        XCTAssertEqual(snapshot.remainingPercent, 10)
        XCTAssertEqual(snapshot.resetsAt, Date(timeIntervalSince1970: 1_780_000_000))
        XCTAssertNil(snapshot.weeklyResetsAt)
    }

    func testEmptyRateLimitWindowReportsFullRemaining() async throws {
        let client = try client(method: "account/rateLimits/read", fixture: "rate-limits-empty.json")

        let snapshot = try await client.readRateLimits()

        XCTAssertEqual(snapshot.usedPercent, 0)
        XCTAssertEqual(snapshot.remainingPercent, 100)
        XCTAssertNil(snapshot.planName)
        XCTAssertNil(snapshot.resetsAt)
        XCTAssertNil(snapshot.weeklyUsedPercent)
        XCTAssertNil(snapshot.weeklyRemainingPercent)
        XCTAssertNil(snapshot.weeklyResetsAt)
    }

    func testReadRateLimitsThrowsWhenTheFixtureCannotDecode() async throws {
        let client = try client(
            method: "account/rateLimits/read",
            fixture: "rate-limits-used-percent-type-mismatch.json"
        )

        do {
            _ = try await client.readRateLimits()
            XCTFail("Expected a decode failure from the transport")
        } catch is DecodingError {
            // The client does not wrap decode failures from a transport.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadUsagePropagatesTransportFailures() async {
        let transport = FixtureTransport(results: [
            "account/usage/read": .failure(CodexClientError.unauthenticated)
        ])
        let client = DefaultCodexAppServerClient(transport: transport)

        do {
            _ = try await client.readUsage()
            XCTFail("Expected the transport error")
        } catch let error as CodexClientError {
            XCTAssertEqual(error, .unauthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFixtureRefreshWritesTheMappedSnapshot() async throws {
        let transport = FixtureTransport(results: [
            "account/usage/read": .success(try TestFixtures.data(named: "usage-daily-buckets.json")),
            "account/rateLimits/read": .success(try TestFixtures.data(named: "rate-limits-primary-weekly.json"))
        ])
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = UsageStore(
            client: DefaultCodexAppServerClient(transport: transport),
            cache: UsageCacheStore(directory: directory)
        )
        let now = Date(timeIntervalSince1970: 1_780_000_100)

        let snapshot = try await store.refresh(now: now)
        let cached = try UsageCacheStore(directory: directory).read()

        XCTAssertEqual(transport.recordedMethods(), ["account/usage/read", "account/rateLimits/read"])
        XCTAssertEqual(snapshot.status, .ready)
        XCTAssertEqual(snapshot.generatedAt, now)
        XCTAssertEqual(snapshot.dailyBuckets.map(\.totalTokens), [1200, 50])
        XCTAssertEqual(snapshot.rateLimit.weeklyRemainingPercent, 59)
        XCTAssertEqual(cached, snapshot)
    }

    private func client(method: String, fixture: String) throws -> DefaultCodexAppServerClient {
        let transport = FixtureTransport(results: [
            method: .success(try TestFixtures.data(named: fixture))
        ])
        return DefaultCodexAppServerClient(transport: transport)
    }

    private func dayLabels(_ dates: [Date]) -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return dates.map { formatter.string(from: $0) }
    }
}

private final class FixtureTransport: CodexAppServerTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var methods: [String] = []
    private let results: [String: Result<Data, Error>]

    init(results: [String: Result<Data, Error>]) {
        self.results = results
    }

    func send<Response: Decodable>(method: String, resultType _: Response.Type) async throws -> Response {
        lock.lock()
        methods.append(method)
        lock.unlock()

        switch results[method] {
        case .success(let data):
            return try JSONDecoder().decode(Response.self, from: data)
        case .failure(let error):
            throw error
        case nil:
            throw CodexClientError.invalidResponse("No fixture for \(method)")
        }
    }

    func recordedMethods() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return methods
    }
}
