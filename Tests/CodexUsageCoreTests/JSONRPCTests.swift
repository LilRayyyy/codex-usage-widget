import XCTest
@testable import CodexUsageCore

final class JSONRPCTests: XCTestCase {
    func testRequestEncodingIncludesMethodAndID() throws {
        let request = JSONRPCRequest(method: "account/rateLimits/read", params: EmptyParams())
        let data = try JSONEncoder().encode(request)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["method"] as? String, "account/rateLimits/read")
        XCTAssertEqual(payload["id"] as? Int, 1)
        XCTAssertNotNil(payload["params"] as? [String: Any])
        XCTAssertNil(payload["jsonrpc"])
    }

    func testRequestEncodingWithNullParamsIncludesNullParams() throws {
        let request = JSONRPCRequest(method: "account/usage/read", params: NullParams())
        let data = try JSONEncoder().encode(request)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["method"] as? String, "account/usage/read")
        XCTAssertEqual(payload["id"] as? Int, 1)
        XCTAssertTrue(payload["params"] is NSNull)
        XCTAssertNil(payload["jsonrpc"])
    }

    func testErrorResponseDecodes() throws {
        let data = Data(#"{"id":1,"error":{"code":401,"message":"not authenticated"}}"#.utf8)
        let response = try JSONDecoder().decode(JSONRPCResponse<EmptyParams>.self, from: data)

        XCTAssertEqual(response.error?.code, 401)
        XCTAssertEqual(response.error?.message, "not authenticated")
    }
}
