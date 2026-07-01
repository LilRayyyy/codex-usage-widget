import SwiftUI
import CodexUsageCore

struct UsageProgressView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LimitProgressRow(
                title: "Overall remaining",
                value: snapshot.rateLimit.remainingPercent,
                detail: snapshot.rateLimit.planName ?? "Codex"
            )

            LimitProgressRow(
                title: "Weekly remaining",
                value: snapshot.rateLimit.weeklyRemainingPercent,
                detail: weeklyDetail
            )
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var weeklyDetail: String {
        guard let resetsAt = snapshot.rateLimit.weeklyResetsAt else {
            return snapshot.rateLimit.weeklyRemainingPercent == nil ? "Weekly limit unavailable" : "Weekly limit"
        }
        return "Resets in \(UsageFormatting.timeUntilText(resetsAt))"
    }
}

private struct LimitProgressRow: View {
    let title: String
    let value: Double?
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(value.map(UsageFormatting.percentText) ?? "--")
                    .font(.title3.monospacedDigit().weight(.semibold))
            }

            ProgressView(value: value ?? 0, total: 100)
                .tint(tint)

            Text(detail)
                .foregroundStyle(.secondary)
        }
    }

    private var tint: Color {
        guard let value else { return .secondary }
        return value > 20 ? .green : .orange
    }
}
