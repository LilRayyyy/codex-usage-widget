import AppKit
import SwiftUI
import CodexUsageCore

struct MenuBarStatusView: View {
    let snapshot: UsageSnapshot
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onOpenDashboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Remaining \(UsageFormatting.percentText(snapshot.rateLimit.remainingPercent))")
            Text("Today \(snapshot.todayTokens(calendar: .current)) tokens")
                .foregroundStyle(.secondary)
            Divider()
            Button(isRefreshing ? "Refreshing..." : "Refresh", action: onRefresh)
                .disabled(isRefreshing)
            Button("Open Dashboard") {
                onOpenDashboard()
            }
            SettingsLink()
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(8)
    }
}
