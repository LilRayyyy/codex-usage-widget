import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var model: UsageDashboardModel

    @AppStorage(AppPreferences.refreshIntervalMinutesKey) private var refreshIntervalMinutes = AppPreferences.defaultRefreshIntervalMinutes
    @AppStorage(AppPreferences.showMenuBarIconKey) private var showMenuBarIcon = AppPreferences.defaultShowMenuBarIcon
    @AppStorage(AppPreferences.useTestDataKey) private var useTestData = AppPreferences.defaultUseTestData
    @AppStorage(AppPreferences.codexExecutablePathKey) private var codexExecutablePath = AppPreferences.defaultCodexExecutablePath

    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)
    @State private var launchAtLoginError: String?

    var body: some View {
        TabView {
            Form {
                Section("Refresh") {
                    Stepper("Refresh every \(refreshIntervalMinutes) minute\(refreshIntervalMinutes == 1 ? "" : "s")", value: $refreshIntervalMinutes, in: 1...60)
                    Toggle("Use test data", isOn: $useTestData)
                    TextField("Codex executable", text: $codexExecutablePath)
                }

                Section("System") {
                    Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                    if let launchAtLoginError {
                        Text(launchAtLoginError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Button("Refresh now") {
                    Task {
                        await model.refresh()
                    }
                }
                .disabled(model.isRefreshing)
            }
            .padding(20)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            DiagnosticsView(model: model)
                .padding(20)
                .tabItem {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
        }
        .frame(width: 520, height: 360)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            launchAtLogin
        } set: { enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLogin = enabled
                launchAtLoginError = nil
            } catch {
                launchAtLogin = (SMAppService.mainApp.status == .enabled)
                launchAtLoginError = error.localizedDescription
            }
        }
    }
}

private struct DiagnosticsView: View {
    @ObservedObject var model: UsageDashboardModel

    var body: some View {
        Form {
            Section("Refresh") {
                DiagnosticRow(title: "Status", value: model.statusText)
                DiagnosticRow(title: "Last attempt", value: lastAttemptText)
                DiagnosticRow(title: "Last error", value: model.lastRefreshError ?? "None")
            }

            Section("Storage") {
                DiagnosticRow(title: "App Group", value: model.appGroupStatus)
                DiagnosticRow(title: "Cache path", value: model.cachePath)
            }

            Section("Codex") {
                DiagnosticRow(title: "Executable", value: model.codexExecutablePath)
                DiagnosticRow(title: "Mode", value: UserDefaults.standard.bool(forKey: AppPreferences.useTestDataKey) ? "Test data" : "Live Codex data")
            }
        }
    }

    private var lastAttemptText: String {
        guard let date = model.lastRefreshAttempt else {
            return "Never"
        }
        return Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

private struct DiagnosticRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
