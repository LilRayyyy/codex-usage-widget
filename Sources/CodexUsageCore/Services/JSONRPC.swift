import Foundation

public struct EmptyParams: Codable, Equatable, Sendable {
    public init() {}
}

public struct NullParams: Encodable, Sendable {
    public init() {}

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

public struct JSONRPCRequest<Params: Encodable>: Encodable {
    public let id: Int
    public let method: String
    public let params: Params

    public init(id: Int = 1, method: String, params: Params) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct JSONRPCResponse<Result: Decodable>: Decodable {
    public let id: Int?
    public let result: Result?
    public let error: JSONRPCError?
}

public struct JSONRPCError: Decodable, Equatable, Sendable {
    public let code: Int
    public let message: String
}
