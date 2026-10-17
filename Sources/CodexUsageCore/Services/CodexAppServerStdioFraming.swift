import Foundation

/// Newline-delimited handshake used by `CodexStdioTransport`.
///
/// The bytes and the id filter are the contract with the local Codex app
/// server. `runRequest` only feeds a process; fixture tests drive this type
/// without launching Codex.
enum CodexAppServerStdioFraming {
    enum LineEffect<Result> {
        case ignore
        case success(Result)
        case failure(Error)
    }

    static func sessionInput(method: String) throws -> Data {
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
        input.append(Data(#"{"method":"initialized"}"#.utf8))
        input.append(0x0A)
        input.append(try encoder.encode(request))
        input.append(0x0A)
        return input
    }

    static func interpret<Result: Decodable>(line: Data, as _: Result.Type) -> LineEffect<Result> {
        if line.isEmpty {
            return .ignore
        }
        guard responseID(from: line) == 2 else {
            return .ignore
        }

        do {
            let response = try JSONDecoder().decode(JSONRPCResponse<Result>.self, from: line)
            if let error = response.error {
                return .failure(DefaultCodexAppServerClient.mapRPCError(error))
            } else if let result = response.result {
                return .success(result)
            } else {
                return .ignore
            }
        } catch {
            return .failure(CodexClientError.invalidResponse(describeDecodingError(error)))
        }
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
