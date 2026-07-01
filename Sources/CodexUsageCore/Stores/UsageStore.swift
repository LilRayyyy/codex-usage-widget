import Foundation

public struct UsageStore<Client: CodexAppServerClient>: Sendable {
    public let client: Client
    public let cache: UsageCacheStore

    public init(client: Client, cache: UsageCacheStore) {
        self.client = client
        self.cache = cache
    }

    public func refresh(now: Date = Date()) async throws -> UsageSnapshot {
        do {
            let usage = try await client.readUsage()
            let rateLimit = try await client.readRateLimits()
            let snapshot = UsageSnapshot(
                generatedAt: now,
                rateLimit: rateLimit,
                dailyBuckets: usage,
                status: .ready
            )
            try cache.write(snapshot)
            return snapshot
        } catch CodexClientError.unsupportedAuth {
            let snapshot = emptySnapshot(now: now, status: .unsupportedAuth)
            try cache.write(snapshot)
            return snapshot
        } catch CodexClientError.unauthenticated {
            let snapshot = emptySnapshot(now: now, status: .unauthenticated)
            try cache.write(snapshot)
            return snapshot
        } catch {
            let snapshot = emptySnapshot(now: now, status: .failed(error.localizedDescription))
            try cache.write(snapshot)
            return snapshot
        }
    }

    private func emptySnapshot(now: Date, status: RefreshStatus) -> UsageSnapshot {
        UsageSnapshot(
            generatedAt: now,
            rateLimit: RateLimitSnapshot(usedPercent: 0, remainingPercent: 0, resetsAt: nil, planName: nil),
            dailyBuckets: [],
            status: status
        )
    }
}
