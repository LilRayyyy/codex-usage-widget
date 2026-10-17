import Foundation
import Security

public enum AppGroup {
    /// Open-source placeholder. Both entitlements files must contain this exact
    /// value, including `$(AppIdentifierPrefix)`. `AppGroupPlaceholderTests`
    /// fails when a target drifts. Forks replace the constant and both files
    /// together; do not commit a personal Team ID.
    public static let placeholderIdentifier = "$(AppIdentifierPrefix)group.com.example.CodexUsageWidget"

    public static func firstEntitledIdentifier() -> String? {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.security.application-groups" as CFString,
                nil
              ) else {
            return nil
        }

        if let identifiers = value as? [String] {
            return identifiers.first
        }

        return nil
    }

    public static func containerURL() -> URL? {
        guard let identifier = firstEntitledIdentifier() else {
            return nil
        }

        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
