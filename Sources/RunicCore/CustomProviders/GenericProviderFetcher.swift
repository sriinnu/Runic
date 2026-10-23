import Foundation

/// Generic fetcher for custom API provider usage and balance data
public actor GenericProviderFetcher {
    let config: CustomProviderConfig
    let keychainService = RunicKeychainService.providerCredentials
    let log = RunicLog.logger("generic-provider-fetcher")
    let session = URLSession(
        configuration: .ephemeral,
        delegate: CustomProviderRedirectDelegate(),
        delegateQueue: nil)

    public init(config: CustomProviderConfig) {
        self.config = config
    }
}

private final class CustomProviderRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void)
    {
        completionHandler(nil)
    }
}
