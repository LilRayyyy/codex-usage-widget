import Foundation
import Security

public enum AppGroup {
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
