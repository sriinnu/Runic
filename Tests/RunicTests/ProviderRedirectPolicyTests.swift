import Foundation
import XCTest
@testable import RunicCore

final class ProviderRedirectPolicyTests: XCTestCase {
    func testProviderSessionRejectsRedirect() async throws {
        let redirected = try await self.redirectResult(using: NoRedirectDelegate())
        XCTAssertNil(redirected)
    }

    func testAntigravitySessionRejectsRedirect() async throws {
        let redirected = try await self.redirectResult(using: AntigravityLoopbackSessionDelegate())
        XCTAssertNil(redirected)
    }

    private func redirectResult(using delegate: URLSessionTaskDelegate) async throws -> URLRequest? {
        let source = try XCTUnwrap(URL(string: "https://127.0.0.1:4318/usage"))
        let destination = try XCTUnwrap(URL(string: "https://example.invalid/collect"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: source,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": destination.absoluteString]))
        let request = URLRequest(url: destination)
        let task = URLSession.shared.dataTask(with: source)
        return await withCheckedContinuation { continuation in
            delegate.urlSession?(
                URLSession.shared,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: request,
                completionHandler: { continuation.resume(returning: $0) })
        }
    }
}
