import Foundation

enum AppPreferences {
    static let refreshIntervalMinutesKey = "refreshIntervalMinutes"
    static let showMenuBarIconKey = "showMenuBarIcon"
    static let useTestDataKey = "useTestData"
    static let codexExecutablePathKey = "codexExecutablePath"

    static let defaultRefreshIntervalMinutes = 1
    static let defaultShowMenuBarIcon = true
    static let defaultUseTestData = false
    static let defaultCodexExecutablePath = "/Applications/Codex.app/Contents/Resources/codex"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            refreshIntervalMinutesKey: defaultRefreshIntervalMinutes,
            showMenuBarIconKey: defaultShowMenuBarIcon,
            useTestDataKey: defaultUseTestData,
            codexExecutablePathKey: defaultCodexExecutablePath
        ])
    }

    static var refreshIntervalSeconds: TimeInterval {
        let minutes = UserDefaults.standard.integer(forKey: refreshIntervalMinutesKey)
        return TimeInterval(max(minutes, 1) * 60)
    }

    static var usesTestData: Bool {
        UserDefaults.standard.bool(forKey: useTestDataKey)
    }

    static var codexExecutablePath: String {
        let value = UserDefaults.standard.string(forKey: codexExecutablePathKey) ?? defaultCodexExecutablePath
        return value.isEmpty ? defaultCodexExecutablePath : value
    }
}
