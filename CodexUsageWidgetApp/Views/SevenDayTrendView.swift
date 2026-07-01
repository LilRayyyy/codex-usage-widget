import SwiftUI
import CodexUsageCore

struct SevenDayTrendView: View {
    let snapshot: UsageSnapshot
    let calendar: Calendar

    private var days: [TrendDay] {
        let today = calendar.startOfDay(for: snapshot.generatedAt)
        let bucketsByDay = Dictionary(grouping: snapshot.dailyBuckets) { bucket in
            calendar.startOfDay(for: bucket.day)
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else {
                return nil
            }

            let tokens = bucketsByDay[date, default: []].reduce(0) { $0 + $1.totalTokens }
            return TrendDay(date: date, tokens: tokens)
        }
    }

    private var maximum: Int {
        max(days.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 7 days")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { day in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.tokens == 0 ? Color.secondary.opacity(0.18) : Color.accentColor.opacity(0.72))
                            .frame(width: 16, height: barHeight(for: day.tokens))
                            .help("\(Self.dateFormatter.string(from: day.date)): \(day.tokens) tokens")
                        Text(Self.weekdayFormatter.string(from: day.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 24, height: 88, alignment: .bottom)
                }
            }
            .accessibilityLabel("Last 7 days Codex usage trend")
        }
    }

    private func barHeight(for tokens: Int) -> CGFloat {
        let ratio = CGFloat(tokens) / CGFloat(maximum)
        return max(8, 64 * ratio)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
}

private struct TrendDay: Identifiable {
    let date: Date
    let tokens: Int

    var id: Date { date }
}
