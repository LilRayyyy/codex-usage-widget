import Foundation

enum TestFixtures {
    static let repoRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static func data(named name: String) throws -> Data {
        try Data(contentsOf: fixtureURL(named: name))
    }

    static func text(named name: String) throws -> String {
        try String(contentsOf: fixtureURL(named: name), encoding: .utf8)
    }

    static func text(at relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    static func line(named name: String) throws -> Data {
        var data = try data(named: name)
        if data.last == 0x0A {
            data.removeLast()
        }
        return data
    }

    private static func fixtureURL(named name: String) -> URL {
        repoRoot
            .appendingPathComponent("Tests/CodexUsageCoreTests/Fixtures", isDirectory: true)
            .appendingPathComponent(name)
    }
}
