import Foundation

public struct DailyUsageBucket: Codable, Equatable, Identifiable, Sendable {
    public var id: Date { day }
    public let day: Date
    public let inputTokens: Int
    public let outputTokens: Int

    public init(day: Date, inputTokens: Int, outputTokens: Int) {
        self.day = day
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public var totalTokens: Int {
        inputTokens + outputTokens
    }
}

public struct RateLimitSnapshot: Codable, Equatable, Sendable {
    public let usedPercent: Double
    public let remainingPercent: Double
    public let resetsAt: Date?
    public let planName: String?
    public let weeklyUsedPercent: Double?
    public let weeklyRemainingPercent: Double?
    public let weeklyResetsAt: Date?

    public init(
        usedPercent: Double,
        remainingPercent: Double,
        resetsAt: Date?,
        planName: String?,
        weeklyUsedPercent: Double? = nil,
        weeklyRemainingPercent: Double? = nil,
        weeklyResetsAt: Date? = nil
    ) {
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
        self.planName = planName
        self.weeklyUsedPercent = weeklyUsedPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.weeklyResetsAt = weeklyResetsAt
    }
}

public enum RefreshStatus: Codable, Equatable, Sendable {
    case ready
    case stale
    case unsupportedAuth
    case missingCodex
    case unauthenticated
    case failed(String)
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let rateLimit: RateLimitSnapshot
    public let dailyBuckets: [DailyUsageBucket]
    public let status: RefreshStatus

    public init(generatedAt: Date, rateLimit: RateLimitSnapshot, dailyBuckets: [DailyUsageBucket], status: RefreshStatus) {
        self.generatedAt = generatedAt
        self.rateLimit = rateLimit
        self.dailyBuckets = dailyBuckets
        self.status = status
    }

    public func totalTokens(in calendar: Calendar) -> Int {
        let generatedComponents = calendar.dateComponents([.year, .month], from: generatedAt)
        return dailyBuckets
            .filter { calendar.dateComponents([.year, .month], from: $0.day) == generatedComponents }
            .reduce(0) { $0 + $1.totalTokens }
    }

    public func todayTokens(on date: Date = Date(), calendar: Calendar) -> Int {
        dailyBuckets
            .filter { calendar.isDate($0.day, inSameDayAs: date) }
            .reduce(0) { $0 + $1.totalTokens }
    }
}
