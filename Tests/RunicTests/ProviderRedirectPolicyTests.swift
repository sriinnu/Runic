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

    func testRedirectTargetResolvesSignInBounces() throws {
        let siliconFlow = try XCTUnwrap(HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://cloud.siliconflow.com/biz-server/api/v1/user/info")),
            statusCode: 307,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": "https://account.siliconflow.com/login?redirect=x"]))
        XCTAssertEqual(ProviderRequestSession.redirectTarget(of: siliconFlow)?.host, "account.siliconflow.com")

        let ollama = try XCTUnwrap(HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://ollama.com/settings")),
            statusCode: 303,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": "/signin"]))
        XCTAssertEqual(ProviderRequestSession.redirectTarget(of: ollama)?.absoluteString, "https://ollama.com/signin")

        let ok = try XCTUnwrap(HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://ollama.com/settings")),
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": "/signin"]))
        XCTAssertNil(ProviderRequestSession.redirectTarget(of: ok))
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
