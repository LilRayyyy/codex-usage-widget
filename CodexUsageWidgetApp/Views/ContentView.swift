import SwiftUI
import CodexUsageCore

struct ContentView: View {
    let snapshot: UsageSnapshot
    let isRefreshing: Bool
    let statusText: String
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Codex Usage")
                        .font(.title2.weight(.semibold))
                    Text("Updated \(UsageFormatting.relativeRefreshText(snapshot.generatedAt))")
                        .foregroundStyle(.secondary)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isRefreshing ? "Refreshing" : "Refresh", action: onRefresh)
                    .keyboardShortcut("r")
                    .disabled(isRefreshing)
            }

            UsageProgressView(snapshot: snapshot)
            HStack(alignment: .top, spacing: 28) {
                HeatmapView(generatedAt: snapshot.generatedAt, buckets: snapshot.dailyBuckets, calendar: .current)
                SevenDayTrendView(snapshot: snapshot, calendar: .current)
            }
            Spacer()
        }
        .padding(24)
    }
}
