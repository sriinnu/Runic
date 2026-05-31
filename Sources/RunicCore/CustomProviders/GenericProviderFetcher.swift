import Foundation

/// Generic fetcher for custom API provider usage and balance data
public actor GenericProviderFetcher {
    let config: CustomProviderConfig
    let keychainService = RunicKeychainService.providerCredentials
    let log = RunicLog.logger("generic-provider-fetcher")

    public init(config: CustomProviderConfig) {
        self.config = config
    }
}
