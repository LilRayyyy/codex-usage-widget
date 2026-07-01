import WidgetKit
import SwiftUI
import CodexUsageCore

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
    let unavailableReason: WidgetUnavailableReason?
}

struct UsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: nil, unavailableReason: .needsFirstRefresh)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> UsageEntry {
        guard let container = AppGroup.containerURL() else {
            return UsageEntry(date: Date(), snapshot: nil, unavailableReason: .missingAppGroup)
        }

        do {
            let snapshot = try UsageCacheStore(directory: container).read()
            return UsageEntry(date: Date(), snapshot: snapshot, unavailableReason: nil)
        } catch {
            return UsageEntry(date: Date(), snapshot: nil, unavailableReason: .needsFirstRefresh)
        }
    }
}

struct CodexUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: UsageEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            if let reason = WidgetUnavailableReason(status: snapshot.status) {
                UnavailableWidgetView(reason: reason)
                    .widgetSurface()
            } else {
                content(for: snapshot)
                    .widgetSurface()
            }
        } else {
            UnavailableWidgetView(reason: entry.unavailableReason ?? .needsFirstRefresh)
                .widgetSurface()
        }
    }

    @ViewBuilder
    private func content(for snapshot: UsageSnapshot) -> some View {
        switch family {
        case .systemSmall:
            SmallUsageWidget(snapshot: snapshot, date: entry.date)
        case .systemMedium:
            MediumUsageWidget(snapshot: snapshot, date: entry.date)
        default:
            LargeUsageWidget(snapshot: snapshot, date: entry.date)
        }
    }
}

private struct SmallUsageWidget: View {
    let snapshot: UsageSnapshot
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(snapshot: snapshot, date: date)
            Spacer(minLength: 0)
            Text(UsageFormatting.percentText(snapshot.rateLimit.remainingPercent))
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .monospacedDigit()
            ProgressView(value: snapshot.rateLimit.remainingPercent, total: 100)
                .tint(progressTint)
            Text("Remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var progressTint: Color {
        snapshot.rateLimit.remainingPercent > 20 ? .green : .orange
    }
}

private struct MediumUsageWidget: View {
    let snapshot: UsageSnapshot
    let date: Date

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(snapshot: snapshot, date: date)
                Text(UsageFormatting.percentText(snapshot.rateLimit.remainingPercent))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                ProgressView(value: snapshot.rateLimit.remainingPercent, total: 100)
                    .tint(snapshot.rateLimit.remainingPercent > 20 ? .green : .orange)
                Text("Remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let weeklyRemaining = snapshot.rateLimit.weeklyRemainingPercent {
                    WidgetLimitProgress(title: "Weekly", value: weeklyRemaining)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                StatPill(title: "Today", value: compactTokens(snapshot.todayTokens(on: date, calendar: .current)))
                StatPill(title: "Month", value: compactTokens(snapshot.totalTokens(in: .current)))
            }
            .frame(width: 94)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct LargeUsageWidget: View {
    let snapshot: UsageSnapshot
    let date: Date

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WidgetHeader(snapshot: snapshot, date: date)

            HStack(alignment: .lastTextBaseline) {
                Text(UsageFormatting.percentText(snapshot.rateLimit.remainingPercent))
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ProgressView(value: snapshot.rateLimit.remainingPercent, total: 100)
                .tint(snapshot.rateLimit.remainingPercent > 20 ? .green : .orange)

            if let weeklyRemaining = snapshot.rateLimit.weeklyRemainingPercent {
                WidgetLimitProgress(title: "Weekly remaining", value: weeklyRemaining)
            }

            HStack(spacing: 16) {
                StatPill(title: "Today", value: compactTokens(snapshot.todayTokens(on: date, calendar: calendar)))
                StatPill(title: "Month", value: compactTokens(snapshot.totalTokens(in: calendar)))
                StatPill(title: "Reset", value: resetText)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily usage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    WidgetHeatmap(snapshot: snapshot, columns: 7, cellSize: 12, spacing: 5)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("7-day trend")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    WidgetSevenDayTrend(snapshot: snapshot)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var resetText: String {
        if let weeklyReset = snapshot.rateLimit.weeklyResetsAt {
            return UsageFormatting.timeUntilText(weeklyReset, now: date)
        }
        if let reset = snapshot.rateLimit.resetsAt {
            return UsageFormatting.timeUntilText(reset, now: date)
        }
        return "N/A"
    }
}

private struct WidgetHeader: View {
    let snapshot: UsageSnapshot
    let date: Date

    var body: some View {
        HStack(spacing: 6) {
            Text("Codex")
                .font(.headline)
            if let planName = snapshot.rateLimit.planName {
                Text(planName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(UsageFormatting.relativeRefreshText(snapshot.generatedAt, now: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WidgetHeatmap: View {
    let snapshot: UsageSnapshot
    let columns: Int
    let cellSize: CGFloat
    let spacing: CGFloat

    private var days: [MonthUsageDay] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: snapshot.generatedAt),
              let dayRange = calendar.range(of: .day, in: .month, for: snapshot.generatedAt) else {
            return []
        }

        let bucketsByDay = Dictionary(grouping: snapshot.dailyBuckets) { bucket in
            calendar.startOfDay(for: bucket.day)
        }

        return dayRange.compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) else {
                return nil
            }

            let tokens = bucketsByDay[calendar.startOfDay(for: date), default: []]
                .reduce(0) { $0 + $1.totalTokens }
            return MonthUsageDay(date: date, tokens: tokens)
        }
    }

    private var maximum: Int {
        max(days.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color(for: day.tokens))
                    .frame(width: cellSize, height: cellSize)
                    .accessibilityLabel("\(Self.dateFormatter.string(from: day.date)): \(day.tokens) tokens")
            }
        }
    }

    private func color(for tokens: Int) -> Color {
        switch HeatmapScale.intensity(for: tokens, maximum: maximum) {
        case 0: return Color.secondary.opacity(0.18)
        case 1: return Color.accentColor.opacity(0.30)
        case 2: return Color.accentColor.opacity(0.52)
        case 3: return Color.accentColor.opacity(0.76)
        default: return Color.accentColor
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct MonthUsageDay: Identifiable {
    let date: Date
    let tokens: Int

    var id: Date { date }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct WidgetLimitProgress: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(UsageFormatting.percentText(value))
                    .font(.caption2.monospacedDigit().weight(.semibold))
            }
            ProgressView(value: value, total: 100)
                .tint(value > 20 ? .green : .orange)
        }
    }
}

private struct WidgetSevenDayTrend: View {
    let snapshot: UsageSnapshot

    private var days: [MonthUsageDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: snapshot.generatedAt)
        let bucketsByDay = Dictionary(grouping: snapshot.dailyBuckets) { bucket in
            calendar.startOfDay(for: bucket.day)
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else {
                return nil
            }

            let tokens = bucketsByDay[date, default: []].reduce(0) { $0 + $1.totalTokens }
            return MonthUsageDay(date: date, tokens: tokens)
        }
    }

    private var maximum: Int {
        max(days.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 3)
                    .fill(day.tokens == 0 ? Color.secondary.opacity(0.18) : Color.accentColor.opacity(0.70))
                    .frame(width: 9, height: barHeight(for: day.tokens))
                    .accessibilityLabel("\(day.tokens) tokens")
            }
        }
        .frame(height: 80, alignment: .bottom)
    }

    private func barHeight(for tokens: Int) -> CGFloat {
        max(7, CGFloat(tokens) / CGFloat(maximum) * 76)
    }
}

private struct UnavailableWidgetView: View {
    let reason: WidgetUnavailableReason

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Codex")
                .font(.headline)
            Spacer(minLength: 0)
            Text(reason.title)
                .font(.title3.weight(.semibold))
            Text(reason.message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

enum WidgetUnavailableReason {
    case needsFirstRefresh
    case missingAppGroup
    case unauthenticated
    case unsupportedAuth
    case failed(String)

    init?(status: RefreshStatus) {
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

    var title: String {
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

    var message: String {
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

private extension View {
    func widgetSurface() -> some View {
        self
            .padding(14)
            .foregroundStyle(.primary)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.18))
            .containerBackground(.background, for: .widget)
    }
}

private func compactTokens(_ tokens: Int) -> String {
    if tokens >= 1_000_000 {
        return String(format: "%.1fM", Double(tokens) / 1_000_000)
    }
    if tokens >= 1_000 {
        return String(format: "%.1fK", Double(tokens) / 1_000)
    }
    return "\(tokens)"
}

struct CodexUsageWidget: Widget {
    let kind = "CodexUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageProvider()) { entry in
            CodexUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("Codex Usage")
        .description("Shows local Codex usage and remaining allowance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
