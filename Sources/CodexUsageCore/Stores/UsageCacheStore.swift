import Foundation

public struct UsageCacheStore: Sendable {
    public let directory: URL
    public let fileName: String

    public init(directory: URL, fileName: String = "usage-snapshot.json") {
        self.directory = directory
        self.fileName = fileName
    }

    public var fileURL: URL {
        directory.appendingPathComponent(fileName, isDirectory: false)
    }

    public func read() throws -> UsageSnapshot {
        let data = try Data(contentsOf: fileURL)
        return try Self.makeDecoder().decode(UsageSnapshot.self, from: data)
    }

    public func write(_ snapshot: UsageSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.makeEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSince1970)
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }

            if let string = try? container.decode(String.self) {
                if let date = makeFractionalSecondsDateFormatter().date(from: string) {
                    return date
                }
                if let date = makeWholeSecondsDateFormatter().date(from: string) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected seconds-since-1970 timestamp or legacy ISO8601 date string."
            )
        }
        return decoder
    }

    private static func makeFractionalSecondsDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func makeWholeSecondsDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
