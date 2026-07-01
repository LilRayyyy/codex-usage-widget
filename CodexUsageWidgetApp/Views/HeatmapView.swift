import SwiftUI
import CodexUsageCore

struct HeatmapView: View {
    let generatedAt: Date
    let buckets: [DailyUsageBucket]
    let calendar: Calendar

    private var days: [MonthUsageDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: generatedAt),
              let dayRange = calendar.range(of: .day, in: .month, for: generatedAt) else {
            return []
        }

        let bucketsByDay = Dictionary(grouping: buckets) { bucket in
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
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(14), spacing: 5), count: 7), spacing: 5) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color(for: day.tokens))
                    .frame(width: 14, height: 14)
                    .help("\(Self.dateFormatter.string(from: day.date)): \(day.tokens) tokens")
            }
        }
        .accessibilityLabel("Monthly Codex usage heatmap")
    }

    private func color(for tokens: Int) -> Color {
        switch HeatmapScale.intensity(for: tokens, maximum: maximum) {
        case 0: return Color.secondary.opacity(0.18)
        case 1: return Color.accentColor.opacity(0.30)
        case 2: return Color.accentColor.opacity(0.50)
        case 3: return Color.accentColor.opacity(0.72)
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
