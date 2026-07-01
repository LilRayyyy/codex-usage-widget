import Foundation

public protocol CodexAppServerClient: Sendable {
    func readUsage() async throws -> [DailyUsageBucket]
    func readRateLimits() async throws -> RateLimitSnapshot
}

public protocol CodexAppServerTransport: Sendable {
    func send<Result: Decodable>(method: String, resultType: Result.Type) async throws -> Result
}

public enum CodexClientError: Error, Equatable {
    case unsupportedAuth
    case unauthenticated
    case serverUnavailable
    case invalidResponse(String)
}

extension CodexClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedAuth:
            return "This Codex account does not expose usage data through the app server."
        case .unauthenticated:
            return "Codex is not authenticated."
        case .serverUnavailable:
            return "Codex app-server is unavailable."
        case .invalidResponse(let message):
            return message
        }
    }
}

public struct DefaultCodexAppServerClient: CodexAppServerClient {
    public let transport: CodexAppServerTransport

    public init(transport: CodexAppServerTransport) {
        self.transport = transport
    }

    public func readUsage() async throws -> [DailyUsageBucket] {
        let response = try await transport.send(method: "account/usage/read", resultType: GetAccountTokenUsageResponse.self)
        return try Self.mapUsage(response)
    }

    public func readRateLimits() async throws -> RateLimitSnapshot {
        let response = try await transport.send(method: "account/rateLimits/read", resultType: GetAccountRateLimitsResponse.self)
        return Self.mapRateLimits(response)
    }

    public static func mapRPCError(_ error: JSONRPCError) -> CodexClientError {
        if error.code == 401 { return .unauthenticated }
        if error.message.localizedCaseInsensitiveContains("unsupported") { return .unsupportedAuth }
        return .invalidResponse(error.message)
    }

    public static func mapUsage(_ response: GetAccountTokenUsageResponse) throws -> [DailyUsageBucket] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return try (response.dailyUsageBuckets ?? []).map { bucket in
            guard let day = formatter.date(from: bucket.startDate) else {
                throw CodexClientError.invalidResponse("Invalid usage bucket date: \(bucket.startDate)")
            }
            return DailyUsageBucket(day: day, inputTokens: Int(bucket.tokens), outputTokens: 0)
        }
    }

    public static func mapRateLimits(_ response: GetAccountRateLimitsResponse) -> RateLimitSnapshot {
        let source = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits
        let usedPercent: Int
        if let primaryUsed = source.primary?.usedPercent {
            usedPercent = primaryUsed
        } else if let individualRemaining = source.individualLimit?.remainingPercent {
            usedPercent = 100 - individualRemaining
        } else {
            usedPercent = 0
        }

        let remainingPercent = source.individualLimit.map { Double($0.remainingPercent) } ?? max(0, 100 - Double(usedPercent))
        let resetSeconds = source.primary?.resetsAt ?? source.individualLimit?.resetsAt
        let weeklyUsedPercent = source.secondary.map { Double($0.usedPercent) }
        let weeklyRemainingPercent = weeklyUsedPercent.map { max(0, 100 - $0) }
        let weeklyResetSeconds = source.secondary?.resetsAt

        return RateLimitSnapshot(
            usedPercent: Double(usedPercent),
            remainingPercent: remainingPercent,
            resetsAt: resetSeconds.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            planName: source.planType,
            weeklyUsedPercent: weeklyUsedPercent,
            weeklyRemainingPercent: weeklyRemainingPercent,
            weeklyResetsAt: weeklyResetSeconds.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }
}

public struct GetAccountTokenUsageResponse: Decodable, Sendable {
    public let dailyUsageBuckets: [AccountTokenUsageDailyBucket]?
}

public struct AccountTokenUsageDailyBucket: Decodable, Sendable {
    public let startDate: String
    public let tokens: Int64
}

public struct GetAccountRateLimitsResponse: Decodable, Sendable {
    public let rateLimits: CodexRateLimitSnapshot
    public let rateLimitsByLimitId: [String: CodexRateLimitSnapshot]?
}

public struct CodexRateLimitSnapshot: Decodable, Sendable {
    public let limitId: String?
    public let limitName: String?
    public let planType: String?
    public let primary: CodexRateLimitWindow?
    public let secondary: CodexRateLimitWindow?
    public let individualLimit: CodexSpendControlLimitSnapshot?
}

public struct CodexRateLimitWindow: Decodable, Sendable {
    public let usedPercent: Int
    public let resetsAt: Int64?
    public let windowDurationMins: Int64?
}

public struct CodexSpendControlLimitSnapshot: Decodable, Sendable {
    public let limit: String
    public let used: String
    public let remainingPercent: Int
    public let resetsAt: Int64
}

public struct CodexStdioTransport: CodexAppServerTransport {
    public let executableURL: URL

    public init(executableURL: URL) {
        self.executableURL = executableURL
    }

    public func send<Result: Decodable>(method: String, resultType: Result.Type) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try Self.runRequest(executableURL: executableURL, method: method))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public static func encodeRequest(id: Int, method: String) throws -> Data {
        let request = JSONRPCRequest(id: id, method: method, params: NullParams())
        return try JSONEncoder().encode(request)
    }

    private static func runRequest<Result: Decodable>(executableURL: URL, method: String) throws -> Result {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.environment = Self.environmentWithSystemProxy()

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        let initialize = InitializeRequest(
            id: 1,
            params: InitializeParams(
                clientInfo: ClientInfo(name: "CodexUsageWidget", title: "Codex Usage Widget", version: "0.1.0"),
                capabilities: nil
            )
        )
        let request = MethodRequest(id: 2, method: method)
        let encoder = JSONEncoder()
        var input = Data()
        input.append(try encoder.encode(initialize))
        input.append(0x0A)
        input.append(#"{"method":"initialized"}"#.data(using: .utf8)!)
        input.append(0x0A)
        input.append(try encoder.encode(request))
        input.append(0x0A)

        let decoder = JSONDecoder()
        let lock = NSLock()
        let responseSemaphore = DispatchSemaphore(value: 0)
        var stdoutBuffer = Data()
        var stderrBuffer = Data()
        var decodedResult: Result?
        var decodedError: Error?

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            lock.lock()
            defer { lock.unlock() }
            stdoutBuffer.append(data)

            while let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) {
                let lineData = stdoutBuffer[..<newlineIndex]
                stdoutBuffer.removeSubrange(...newlineIndex)
                guard !lineData.isEmpty else { continue }
                guard Self.responseID(from: Data(lineData)) == 2 else { continue }

                do {
                    let response = try decoder.decode(JSONRPCResponse<Result>.self, from: Data(lineData))
                    if let error = response.error {
                        decodedError = DefaultCodexAppServerClient.mapRPCError(error)
                    } else if let result = response.result {
                        decodedResult = result
                    } else {
                        continue
                    }
                    responseSemaphore.signal()
                } catch {
                    decodedError = CodexClientError.invalidResponse(Self.describeDecodingError(error))
                    responseSemaphore.signal()
                }
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            lock.lock()
            stderrBuffer.append(data)
            lock.unlock()
        }

        stdin.fileHandleForWriting.write(input)
        let waitResult = responseSemaphore.wait(timeout: .now() + 10)

        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        try? stdin.fileHandleForWriting.close()

        if process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()

        lock.lock()
        let result = decodedResult
        let error = decodedError
        let serverError = String(data: stderrBuffer, encoding: .utf8)
        lock.unlock()

        if let error {
            throw error
        }

        if let result {
            return result
        }

        if waitResult == .timedOut {
            throw CodexClientError.invalidResponse("Timed out waiting for Codex app-server response for \(method).")
        }

        throw CodexClientError.invalidResponse(serverError ?? "Codex app-server did not return a response for \(method).")
    }

    private static func responseID(from data: Data) -> Int? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return nil
        }

        return dictionary["id"] as? Int
    }

    private static func describeDecodingError(_ error: Error) -> String {
        switch error {
        case DecodingError.keyNotFound(let key, let context):
            let path = (context.codingPath + [key]).map(\.stringValue).joined(separator: ".")
            return "Missing field at \(path): \(context.debugDescription)"
        case DecodingError.valueNotFound(_, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Missing value at \(path): \(context.debugDescription)"
        case DecodingError.typeMismatch(_, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Type mismatch at \(path): \(context.debugDescription)"
        case DecodingError.dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Corrupt data at \(path): \(context.debugDescription)"
        default:
            return error.localizedDescription
        }
    }

    private static func environmentWithSystemProxy() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let proxy = systemProxySettings()

        if environment["HTTP_PROXY"] == nil, let httpProxy = proxy.httpProxy {
            environment["HTTP_PROXY"] = httpProxy
            environment["http_proxy"] = httpProxy
        }

        if environment["HTTPS_PROXY"] == nil, let httpsProxy = proxy.httpsProxy ?? proxy.httpProxy {
            environment["HTTPS_PROXY"] = httpsProxy
            environment["https_proxy"] = httpsProxy
        }

        if environment["ALL_PROXY"] == nil, let socksProxy = proxy.socksProxy {
            environment["ALL_PROXY"] = socksProxy
            environment["all_proxy"] = socksProxy
        }

        return environment
    }

    private static func systemProxySettings() -> SystemProxySettings {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        process.arguments = ["--proxy"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0, let output = String(data: data, encoding: .utf8) else {
                return SystemProxySettings()
            }
            return SystemProxySettings(scutilOutput: output)
        } catch {
            return SystemProxySettings()
        }
    }
}

private struct SystemProxySettings {
    var httpProxy: String?
    var httpsProxy: String?
    var socksProxy: String?

    init(httpProxy: String? = nil, httpsProxy: String? = nil, socksProxy: String? = nil) {
        self.httpProxy = httpProxy
        self.httpsProxy = httpsProxy
        self.socksProxy = socksProxy
    }

    init(scutilOutput: String) {
        httpProxy = nil
        httpsProxy = nil
        socksProxy = nil

        let values = Dictionary(
            uniqueKeysWithValues: scutilOutput
                .split(separator: "\n")
                .compactMap { line -> (String, String)? in
                    let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                    guard parts.count == 2 else { return nil }
                    return (parts[0], parts[1])
                }
        )

        if values["HTTPEnable"] == "1", let host = values["HTTPProxy"], let port = values["HTTPPort"] {
            httpProxy = "http://\(host):\(port)"
        }

        if values["HTTPSEnable"] == "1", let host = values["HTTPSProxy"], let port = values["HTTPSPort"] {
            httpsProxy = "http://\(host):\(port)"
        }

        if values["SOCKSEnable"] == "1", let host = values["SOCKSProxy"], let port = values["SOCKSPort"] {
            socksProxy = "socks5://\(host):\(port)"
        }
    }
}

private struct MethodRequest: Encodable {
    let id: Int
    let method: String
}

private struct InitializeRequest: Encodable {
    let id: Int
    let method = "initialize"
    let params: InitializeParams
}

private struct InitializeParams: Encodable {
    let clientInfo: ClientInfo
    let capabilities: EmptyCapabilities?
}

private struct ClientInfo: Encodable {
    let name: String
    let title: String
    let version: String
}

private struct EmptyCapabilities: Encodable {}
