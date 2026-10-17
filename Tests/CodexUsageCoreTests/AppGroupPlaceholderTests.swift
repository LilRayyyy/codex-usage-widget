import Foundation
import XCTest
@testable import CodexUsageCore

final class AppGroupPlaceholderTests: XCTestCase {
    func testEntitlementsAndBundleIDsStayOnTheOpenSourcePlaceholder() throws {
        XCTAssertEqual(
            AppGroup.placeholderIdentifier,
            "$(AppIdentifierPrefix)group.com.example.CodexUsageWidget"
        )

        let entitlements = try entitlementURLs()
        XCTAssertEqual(
            entitlements.map(\.lastPathComponent).sorted(),
            [
                "CodexUsageWidgetApp.entitlements",
                "CodexUsageWidgetWidget.entitlements"
            ]
        )

        for url in entitlements {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(
                occurrenceCount(of: AppGroup.placeholderIdentifier, in: text),
                1,
                url.path
            )
            XCTAssertEqual(
                groupIdentifiers(in: text),
                ["group.com.example.CodexUsageWidget"],
                url.path
            )
        }

        let project = try TestFixtures.text(at: "project.yml")
        XCTAssertTrue(project.contains("bundleIdPrefix: com.example\n"))
        XCTAssertTrue(project.contains("PRODUCT_BUNDLE_IDENTIFIER: com.example.CodexUsageWidget\n"))
        XCTAssertTrue(project.contains("PRODUCT_BUNDLE_IDENTIFIER: com.example.CodexUsageWidget.Widget\n"))
    }

    private func entitlementURLs() throws -> [URL] {
        let root = TestFixtures.repoRoot
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let skipped: Set<String> = [".build", "DerivedData", "release", "SignedDerivedData"]
        var urls: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if skipped.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            if url.pathExtension == "entitlements" {
                urls.append(url)
            }
        }
        return urls
    }

    private func occurrenceCount(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func groupIdentifiers(in text: String) -> [String] {
        var found: [String] = []
        var rest = text[...]
        while let range = rest.range(of: "group.") {
            var end = range.upperBound
            while end < rest.endIndex {
                let character = rest[end]
                if character.isLetter || character.isNumber || character == "." {
                    end = rest.index(after: end)
                } else {
                    break
                }
            }
            found.append(String(rest[range.lowerBound..<end]))
            rest = rest[end...]
        }
        return found
    }
}
