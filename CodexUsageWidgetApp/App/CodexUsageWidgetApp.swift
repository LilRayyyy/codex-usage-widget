import SwiftUI
import WidgetKit
import CodexUsageCore

@main
struct CodexUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppPreferences.showMenuBarIconKey) private var showMenuBarIcon = AppPreferences.defaultShowMenuBarIcon
    @StateObject private var model = UsageDashboardModel.shared

    init() {
        AppPreferences.registerDefaults()
        Task {
            await UsageDashboardModel.shared.refresh()
        }
    }

    var body: some Scene {
        WindowGroup("Codex Usage", id: "main") {
            ContentView(
                snapshot: model.snapshot,
                isRefreshing: model.isRefreshing,
                statusText: model.statusText,
                onRefresh: {
                    Task {
                        await model.refresh()
                    }
                }
            )
                .frame(minWidth: 520, minHeight: 420)
                .onAppear {
                    Task {
                        await model.refresh()
                    }
                }
                .task {
                    await model.refresh()
                }
        }

        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarStatusView(
                snapshot: model.snapshot,
                isRefreshing: model.isRefreshing,
                onRefresh: {
                    Task {
                        await model.refresh()
                    }
                },
                onOpenDashboard: {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            )
        } label: {
            Text(UsageFormatting.percentText(model.snapshot.rateLimit.remainingPercent))
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

@MainActor
final class UsageDashboardModel: ObservableObject {
    static let shared = UsageDashboardModel()

    @Published private(set) var snapshot = UsageSnapshot.preview
    @Published private(set) var isRefreshing = false
    @Published private(set) var statusText = "Preview data"
    @Published private(set) var lastRefreshError: String?
    @Published private(set) var lastRefreshAttempt: Date?

    private var autoRefreshTask: Task<Void, Never>?

    private init() {
        startAutoRefresh()
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastRefreshAttempt = Date()
        statusText = "Refreshing..."
        defer { isRefreshing = false }

        do {
            if AppPreferences.usesTestData {
                let snapshot = UsageSnapshot.makePreviewSnapshot(now: Date())
                try UsageCacheStore(directory: Self.cacheDirectory()).write(snapshot)
                self.snapshot = snapshot
                statusText = "Test data"
                lastRefreshError = nil
                WidgetCenter.shared.reloadAllTimelines()
                return
            }

            let executableURL = URL(fileURLWithPath: AppPreferences.codexExecutablePath)
            let client = DefaultCodexAppServerClient(transport: CodexStdioTransport(executableURL: executableURL))
            let store = UsageStore(client: client, cache: UsageCacheStore(directory: Self.cacheDirectory()))
            snapshot = try await store.refresh()
            statusText = Self.statusText(for: snapshot.status)
            lastRefreshError = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            statusText = "Refresh failed: \(error.localizedDescription)"
            lastRefreshError = error.localizedDescription
        }
    }

    var cachePath: String {
        Self.cacheDirectory().path
    }

    var appGroupStatus: String {
        AppGroup.containerURL() == nil ? "Unavailable, using Application Support fallback" : "Available"
    }

    var codexExecutablePath: String {
        AppPreferences.codexExecutablePath
    }

    private func startAutoRefresh() {
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = AppPreferences.refreshIntervalSeconds
                let nanoseconds = UInt64(max(interval, 60) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    private static func cacheDirectory() -> URL {
        if let groupURL = AppGroup.containerURL() {
            return groupURL
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("CodexUsageWidget", isDirectory: true)
    }

    private static func statusText(for status: RefreshStatus) -> String {
        switch status {
        case .ready:
            return "Live Codex data"
        case .stale:
            return "Showing cached Codex data"
        case .unsupportedAuth:
            return "Codex usage is not available for this account"
        case .missingCodex:
            return "Codex app is not installed"
        case .unauthenticated:
            return "Sign in to Codex to load usage"
        case .failed(let message):
            return "Refresh failed: \(message)"
        }
    }
}

extension UsageSnapshot {
    static func makePreviewSnapshot(now: Date) -> UsageSnapshot {
        UsageSnapshot(
        generatedAt: now,
        rateLimit: RateLimitSnapshot(
            usedPercent: 28,
            remainingPercent: 72,
            resetsAt: nil,
            planName: "Pro",
            weeklyUsedPercent: 42,
            weeklyRemainingPercent: 58,
            weeklyResetsAt: Calendar.current.date(byAdding: .day, value: 3, to: now)
        ),
        dailyBuckets: (0..<28).map { offset in
            DailyUsageBucket(
                day: Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now,
                inputTokens: (offset + 2) * 95,
                outputTokens: (offset % 5 + 1) * 140
            )
        },
        status: .ready
        )
    }

    static let preview = makePreviewSnapshot(now: Date())
}
