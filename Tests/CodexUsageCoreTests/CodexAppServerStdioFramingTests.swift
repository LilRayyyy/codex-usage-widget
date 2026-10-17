import XCTest
@testable import CodexUsageCore

final class CodexAppServerStdioFramingTests: XCTestCase {
    func testSessionInputSpeaksTheInitializeHandshake() throws {
        let data = try CodexAppServerStdioFraming.sessionInput(method: "account/rateLimits/read")
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.last, "")
        let messages = lines.filter { !$0.isEmpty }
        XCTAssertEqual(messages.count, 3)

        let initialize = try jsonObject(messages[0])
        XCTAssertEqual(initialize["id"] as? Int, 1)
        XCTAssertEqual(initialize["method"] as? String, "initialize")
        XCTAssertNil(initialize["jsonrpc"])
        let params = try XCTUnwrap(initialize["params"] as? [String: Any])
        XCTAssertNil(params["capabilities"])
        let clientInfo = try XCTUnwrap(params["clientInfo"] as? [String: Any])
        XCTAssertEqual(clientInfo["name"] as? String, "CodexUsageWidget")
        XCTAssertEqual(clientInfo["title"] as? String, "Codex Usage Widget")
        XCTAssertEqual(clientInfo["version"] as? String, "0.1.0")

        XCTAssertEqual(messages[1], #"{"method":"initialized"}"#)

        let request = try jsonObject(messages[2])
        XCTAssertEqual(request["id"] as? Int, 2)
        XCTAssertEqual(request["method"] as? String, "account/rateLimits/read")
        XCTAssertNil(request["params"])
        XCTAssertNil(request["jsonrpc"])
    }

    func testTranscriptIgnoresNoiseUntilTheMethodResult() throws {
        let text = try TestFixtures.text(named: "stdio-usage-transcript.txt")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { Data($0.utf8) }
        var tokens: [Int]?

        for line in lines {
            switch CodexAppServerStdioFraming.interpret(line: line, as: GetAccountTokenUsageResponse.self) {
            case .ignore:
                continue
            case .success(let response):
                XCTAssertNil(tokens)
                tokens = try DefaultCodexAppServerClient.mapUsage(response).map(\.inputTokens)
            case .failure(let error):
                XCTFail("Unexpected framing error: \(error)")
            }
        }

        XCTAssertEqual(tokens, [1200, 50])
    }

    func testUnauthorizedWinsOverAnUnsupportedMessage() throws {
        let effect = try effect(named: "stdio-error-unauthorized.txt", as: GetAccountTokenUsageResponse.self)
        XCTAssertEqual(try clientError(effect), .unauthenticated)
    }

    func testUnsupportedMessageMapsToUnsupportedAuth() throws {
        let effect = try effect(named: "stdio-error-unsupported.txt", as: GetAccountRateLimitsResponse.self)
        XCTAssertEqual(try clientError(effect), .unsupportedAuth)
    }

    func testOtherRPCErrorsKeepTheServerMessage() throws {
        let effect = try effect(named: "stdio-error-other.txt", as: GetAccountRateLimitsResponse.self)
        XCTAssertEqual(try clientError(effect), .invalidResponse("boom"))
    }

    func testAnErrorPayloadWinsWhenAResultIsAlsoPresent() throws {
        let effect = try effect(named: "stdio-error-and-result.txt", as: GetAccountTokenUsageResponse.self)
        XCTAssertEqual(try clientError(effect), .unauthenticated)
    }

    func testAMismatchedResultBecomesAnInvalidResponse() throws {
        let effect = try effect(named: "stdio-type-mismatch.txt", as: GetAccountTokenUsageResponse.self)
        guard case .invalidResponse(let message) = try clientError(effect) else {
            return XCTFail("Expected invalidResponse")
        }
        XCTAssertTrue(message.contains("Type mismatch"), message)
    }

    func testInvalidJSONAndEmptyPayloadsAreIgnored() throws {
        let invalid = try CodexAppServerStdioFraming.interpret(
            line: TestFixtures.line(named: "stdio-invalid-json.txt"),
            as: GetAccountTokenUsageResponse.self
        )
        let emptyPayload = try CodexAppServerStdioFraming.interpret(
            line: TestFixtures.line(named: "stdio-id-without-payload.txt"),
            as: GetAccountTokenUsageResponse.self
        )

        guard case .ignore = invalid, case .ignore = emptyPayload else {
            return XCTFail("Expected both lines to be ignored")
        }
    }

    private func effect<Result: Decodable>(
        named name: String,
        as type: Result.Type
    ) throws -> CodexAppServerStdioFraming.LineEffect<Result> {
        CodexAppServerStdioFraming.interpret(line: try TestFixtures.line(named: name), as: type)
    }

    private func clientError<Result>(_ effect: CodexAppServerStdioFraming.LineEffect<Result>) throws -> CodexClientError {
        guard case .failure(let error as CodexClientError) = effect else {
            XCTFail("Expected CodexClientError, got \(effect)")
            throw FixtureTestError.unexpectedEffect
        }
        return error
    }

    private func jsonObject(_ line: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: Data(line.utf8))
        return try XCTUnwrap(object as? [String: Any])
    }
}

private enum FixtureTestError: Error {
    case unexpectedEffect
}
