import Foundation

/// Keeps provider credentials on the endpoint that the caller selected.
public enum ProviderRequestSession {
    public static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request, delegate: NoRedirectDelegate())
    }

    /// Where a rejected 3xx pointed, resolved against the request URL. Session-cookie fetchers use it
    /// to recognize a bounce to a sign-in page without following it.
    public static func redirectTarget(of response: HTTPURLResponse) -> URL? {
        guard (300..<400).contains(response.statusCode),
              let location = response.value(forHTTPHeaderField: "Location")
        else { return nil }
        return URL(string: location, relativeTo: response.url)?.absoluteURL
    }
}

final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void)
    {
        completionHandler(nil)
    }
}
