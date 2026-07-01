import XCTest
@testable import CodexUsageCore

final class CodexAppServerTransportTests: XCTestCase {
    func testBuildsNullParamsRequest() throws {
        let data = try CodexStdioTransport.encodeRequest(id: 7, method: "account/usage/read")
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["id"] as? Int, 7)
        XCTAssertEqual(payload["method"] as? String, "account/usage/read")
        XCTAssertTrue(payload["params"] is NSNull)
        XCTAssertNil(payload["jsonrpc"])
    }
}
