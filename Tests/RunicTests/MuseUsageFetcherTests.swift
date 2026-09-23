import Foundation
import Testing
@testable import RunicCore

struct MuseUsageFetcherTests {
    private static let modelsJSON = #"{"object":"list","data":[{"id":"muse-1"},{"id":"muse-1-mini"}]}"#

    private static func models() throws -> MuseModelsResponse {
        try JSONDecoder().decode(MuseModelsResponse.self, from: Data(self.modelsJSON.utf8))
    }

    @Test
    func `rate limit headers parse case-insensitively`() {
        let limits = MuseRateLimits.parse(headers: [
            "X-RateLimit-Limit-Requests": "60",
            "x-ratelimit-remaining-requests": "45",
            "X-RATELIMIT-LIMIT-TOKENS": "100000",
            "x-ratelimit-remaining-tokens": " 25000 ",
            "Content-Type": "application/json",
        ])

        #expect(limits.requestLimit == 60)
        #expect(limits.requestRemaining == 45)
        #expect(limits.tokenLimit == 100_000)
        #expect(limits.tokenRemaining == 25000)
        #expect(!limits.isEmpty)
    }

    @Test
    func `headers become per-minute windows with requests primary`() throws {
        let limits = MuseRateLimits.parse(headers: [
            "x-ratelimit-limit-requests": "60",
            "x-ratelimit-remaining-requests": "45",
            "x-ratelimit-limit-tokens": "100000",
            "x-ratelimit-remaining-tokens": "25000",
        ])
        let snapshot = try MuseModelsResult(models: Self.models(), rateLimits: limits).toUsageSnapshot()

        #expect(snapshot.primary.windowMinutes == 1)
        #expect(snapshot.primary.hasKnownLimit == true)
        #expect(abs(snapshot.primary.usedPercent - 25) < 1e-9)
        #expect(snapshot.primary.label == "Requests/min")
        let secondary = try #require(snapshot.secondary)
        #expect(secondary.windowMinutes == 1)
        #expect(abs(secondary.usedPercent - 75) < 1e-9)
        #expect(secondary.label == "Tokens/min")
    }

    @Test
    func `missing headers fall back to informational model count`() throws {
        let limits = MuseRateLimits.parse(headers: ["Content-Type": "application/json"])
        let snapshot = try MuseModelsResult(models: Self.models(), rateLimits: limits).toUsageSnapshot()

        #expect(limits.isEmpty)
        #expect(snapshot.primary.hasKnownLimit == false)
        #expect(snapshot.primary.resetDescription?.hasPrefix("2 models available") == true)
        #expect(snapshot.secondary == nil)
    }

    @Test
    func `402 maps to out of credits billing error`() {
        let body = Data(#"{"error":{"type":"billing_error","message":"Insufficient credits"}}"#.utf8)
        let error = MuseAPIError.from(statusCode: 402, body: body)

        #expect(error == .outOfCredits)
        #expect(error?.errorDescription == "Out of Meta Model API credits — add billing at dev.meta.ai.")
        #expect(MuseAPIError.from(statusCode: 402, body: nil) == .outOfCredits)
    }

    @Test
    func `401 maps to invalid key and 200 to no error`() {
        #expect(MuseAPIError.from(statusCode: 401, body: nil) == .invalidKey(statusCode: 401))
        #expect(MuseAPIError.from(statusCode: 401, body: nil)?.errorDescription?
            .contains("rejected the API key") == true)
        #expect(MuseAPIError.from(statusCode: 200, body: nil) == nil)
        #expect(MuseAPIError.from(statusCode: 500, body: nil) == .httpError(statusCode: 500))
    }
}
