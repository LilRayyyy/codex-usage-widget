import Foundation

/// Timeline state for the desktop widget.
///
/// The WidgetKit target only adapts this value. It does not decide reload
/// timing or how a missing cache differs from a missing App Group.
public struct WidgetTimelineEntry: Equatable, Sendable {
    public let date: Date
    public let snapshot: UsageSnapshot?
    public let unavailableReason: WidgetUnavailableReason?

    public init(date: Date, snapshot: UsageSnapshot?, unavailableReason: WidgetUnavailableReason?) {
        self.date = date
        self.snapshot = snapshot
        self.unavailableReason = unavailableReason
    }
}

public enum WidgetUnavailableReason: Equatable, Sendable {
    case needsFirstRefresh
    case missingAppGroup
    case unauthenticated
    case unsupportedAuth
    case failed(String)

    public init?(status: RefreshStatus) {
        switch status {
        case .ready, .stale:
            return nil
        case .unauthenticated:
            self = .unauthenticated
        case .unsupportedAuth:
            self = .unsupportedAuth
        case .missingCodex:
            self = .failed("Codex app is not installed.")
        case .failed(let message):
            self = .failed(message)
        }
    }

    public var title: String {
        switch self {
        case .needsFirstRefresh:
            return "Open app"
        case .missingAppGroup:
            return "Setup needed"
        case .unauthenticated:
            return "Sign in"
        case .unsupportedAuth:
            return "Unavailable"
        case .failed:
            return "Refresh failed"
        }
    }

    public var message: String {
        switch self {
        case .needsFirstRefresh:
            return "Open Codex Usage Widget and refresh once."
        case .missingAppGroup:
            return "App and widget need the same App Group."
        case .unauthenticated:
            return "Sign in to Codex, then refresh the app."
        case .unsupportedAuth:
            return "This Codex account does not expose usage data."
        case .failed(let message):
            return message.isEmpty ? "Open the app to inspect diagnostics." : message
        }
    }
}

public enum WidgetTimeline {
    /// Absolute fallback used when `Calendar` cannot add five minutes.
    public static let reloadInterval: TimeInterval = 5 * 60

    public static func placeholder(now: Date) -> WidgetTimelineEntry {
        WidgetTimelineEntry(date: now, snapshot: nil, unavailableReason: .needsFirstRefresh)
    }

    /// Five civil minutes after `date`, matching the widget's previous policy.
    public static func nextReloadDate(after date: Date, calendar: Calendar = Calendar.current) -> Date {
        calendar.date(byAdding: .minute, value: 5, to: date) ?? date.addingTimeInterval(reloadInterval)
    }

    /// Loads the snapshot the widget should render.
    ///
    /// A readable snapshot is returned even when its status is an error. The
    /// widget view derives that empty state from `RefreshStatus`. Only a
    /// missing container is `missingAppGroup`; a missing or unreadable cache
    /// is `needsFirstRefresh`.
    public static func loadEntry(
        now: Date,
        containerURL: URL?,
        readSnapshot: (URL) throws -> UsageSnapshot = { url in
            try UsageCacheStore(directory: url).read()
        }
    ) -> WidgetTimelineEntry {
        guard let containerURL else {
            return WidgetTimelineEntry(date: now, snapshot: nil, unavailableReason: .missingAppGroup)
        }

        do {
            let snapshot = try readSnapshot(containerURL)
            return WidgetTimelineEntry(date: now, snapshot: snapshot, unavailableReason: nil)
        } catch {
            return WidgetTimelineEntry(date: now, snapshot: nil, unavailableReason: .needsFirstRefresh)
        }
    }
}
