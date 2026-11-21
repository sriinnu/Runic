import Foundation
import Testing
@testable import RunicCore

@Suite(.serialized)
struct GeminiStatusProbePlanTests {
    @Test
    func `selects project id for quota requests`() async throws {
        let env = try GeminiTestEnvironment()
        defer { env.cleanup() }
        try env.writeCredentials(
            accessToken: "token",
            refreshToken: nil,
            expiry: Date().addingTimeInterval(3600),
            idToken: nil)

        let expectedProject = "gen-lang-client-123"
        let dataLoader = GeminiAPITestHelpers.dataLoader { request in
            guard let url = request.url, let host = url.host else {
                throw URLError(.badURL)
            }
            switch host {
            case "cloudresourcemanager.googleapis.com":
                let json = GeminiAPITestHelpers.jsonData([
                    "projects": [
                        ["projectId": expectedProject],
                    ],
                ])
                return GeminiAPITestHelpers.response(url: url.absoluteString, status: 200, body: json)
            case "cloudcode-pa.googleapis.com":
                if url.path == "/v1internal:loadCodeAssist" {
                    return GeminiAPITestHelpers.response(
                        url: url.absoluteString,
                        status: 200,
                        body: GeminiAPITestHelpers.loadCodeAssistFreeTierResponse())
                }
                if url.path != "/v1internal:retrieveUserQuota" {
                    return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
                }
                let bodyText = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                if !bodyText.contains(expectedProject) {
                    return GeminiAPITestHelpers.response(url: url.absoluteString, status: 400, body: Data())
                }
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.sampleFlashQuotaResponse())
            default:
                return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
            }
        }

        let probe = GeminiStatusProbe(timeout: 1, homeDirectory: env.homeURL.path, dataLoader: dataLoader)
        let snapshot = try await probe.fetch()
        #expect(snapshot.modelQuotas.contains { $0.percentLeft == 40 })
    }

    @Test
    func `detects paid from standard tier`() async throws {
        let env = try GeminiTestEnvironment()
        defer { env.cleanup() }
        try env.writeCredentials(
            accessToken: "token",
            refreshToken: nil,
            expiry: Date().addingTimeInterval(3600),
            idToken: nil)

        let dataLoader = GeminiAPITestHelpers.dataLoader { request in
            guard let url = request.url, let host = url.host else {
                throw URLError(.badURL)
            }
            switch host {
            case "cloudresourcemanager.googleapis.com":
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.jsonData(["projects": []]))
            case "cloudcode-pa.googleapis.com":
                if url.path == "/v1internal:loadCodeAssist" {
                    return GeminiAPITestHelpers.response(
                        url: url.absoluteString,
                        status: 200,
                        body: GeminiAPITestHelpers.loadCodeAssistStandardTierResponse())
                }
                if url.path != "/v1internal:retrieveUserQuota" {
                    return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
                }
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.sampleQuotaResponse())
            default:
                return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
            }
        }

        let probe = GeminiStatusProbe(timeout: 1, homeDirectory: env.homeURL.path, dataLoader: dataLoader)
        let snapshot = try await probe.fetch()
        #expect(snapshot.accountPlan == "Paid")
    }

    @Test
    func `detects workspace from free tier with hosted domain`() async throws {
        let env = try GeminiTestEnvironment()
        defer { env.cleanup() }
        let idToken = GeminiAPITestHelpers.makeIDToken(email: "user@company.com", hostedDomain: "company.com")
        try env.writeCredentials(
            accessToken: "token",
            refreshToken: nil,
            expiry: Date().addingTimeInterval(3600),
            idToken: idToken)

        let dataLoader = GeminiAPITestHelpers.dataLoader { request in
            guard let url = request.url, let host = url.host else {
                throw URLError(.badURL)
            }
            switch host {
            case "cloudresourcemanager.googleapis.com":
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.jsonData(["projects": []]))
            case "cloudcode-pa.googleapis.com":
                if url.path == "/v1internal:loadCodeAssist" {
                    return GeminiAPITestHelpers.response(
                        url: url.absoluteString,
                        status: 200,
                        body: GeminiAPITestHelpers.loadCodeAssistFreeTierResponse())
                }
                if url.path != "/v1internal:retrieveUserQuota" {
                    return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
                }
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.sampleQuotaResponse())
            default:
                return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
            }
        }

        let probe = GeminiStatusProbe(timeout: 1, homeDirectory: env.homeURL.path, dataLoader: dataLoader)
        let snapshot = try await probe.fetch()
        #expect(snapshot.accountPlan == "Workspace")
    }

    @Test
    func `detects free from free tier without hosted domain`() async throws {
        let env = try GeminiTestEnvironment()
        defer { env.cleanup() }
        let idToken = GeminiAPITestHelpers.makeIDToken(email: "user@gmail.com")
        try env.writeCredentials(
            accessToken: "token",
            refreshToken: nil,
            expiry: Date().addingTimeInterval(3600),
            idToken: idToken)

        let dataLoader = GeminiAPITestHelpers.dataLoader { request in
            guard let url = request.url, let host = url.host else {
                throw URLError(.badURL)
            }
            switch host {
            case "cloudresourcemanager.googleapis.com":
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.jsonData(["projects": []]))
            case "cloudcode-pa.googleapis.com":
                if url.path == "/v1internal:loadCodeAssist" {
                    return GeminiAPITestHelpers.response(
                        url: url.absoluteString,
                        status: 200,
                        body: GeminiAPITestHelpers.loadCodeAssistFreeTierResponse())
                }
                if url.path != "/v1internal:retrieveUserQuota" {
                    return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
                }
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.sampleFlashQuotaResponse())
            default:
                return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
            }
        }

        let probe = GeminiStatusProbe(timeout: 1, homeDirectory: env.homeURL.path, dataLoader: dataLoader)
        let snapshot = try await probe.fetch()
        #expect(snapshot.accountPlan == "Free")
    }

    @Test
    func `detects legacy from legacy tier`() async throws {
        let env = try GeminiTestEnvironment()
        defer { env.cleanup() }
        try env.writeCredentials(
            accessToken: "token",
            refreshToken: nil,
            expiry: Date().addingTimeInterval(3600),
            idToken: nil)

        let dataLoader = GeminiAPITestHelpers.dataLoader { request in
            guard let url = request.url, let host = url.host else {
                throw URLError(.badURL)
            }
            switch host {
            case "cloudresourcemanager.googleapis.com":
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.jsonData(["projects": []]))
            case "cloudcode-pa.googleapis.com":
                if url.path == "/v1internal:loadCodeAssist" {
                    return GeminiAPITestHelpers.response(
                        url: url.absoluteString,
                        status: 200,
                        body: GeminiAPITestHelpers.loadCodeAssistLegacyTierResponse())
                }
                if url.path != "/v1internal:retrieveUserQuota" {
                    return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
                }
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.sampleQuotaResponse())
            default:
                return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
            }
        }

        let probe = GeminiStatusProbe(timeout: 1, homeDirectory: env.homeURL.path, dataLoader: dataLoader)
        let snapshot = try await probe.fetch()
        #expect(snapshot.accountPlan == "Legacy")
    }

    @Test
    func `leaves blank when load code assist fails`() async throws {
        let env = try GeminiTestEnvironment()
        defer { env.cleanup() }
        try env.writeCredentials(
            accessToken: "token",
            refreshToken: nil,
            expiry: Date().addingTimeInterval(3600),
            idToken: nil)

        let dataLoader = GeminiAPITestHelpers.dataLoader { request in
            guard let url = request.url, let host = url.host else {
                throw URLError(.badURL)
            }
            switch host {
            case "cloudresourcemanager.googleapis.com":
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.jsonData(["projects": []]))
            case "cloudcode-pa.googleapis.com":
                if url.path == "/v1internal:loadCodeAssist" {
                    return GeminiAPITestHelpers.response(
                        url: url.absoluteString,
                        status: 500,
                        body: Data())
                }
                if url.path != "/v1internal:retrieveUserQuota" {
                    return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
                }
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.sampleQuotaResponse())
            default:
                return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
            }
        }

        let probe = GeminiStatusProbe(timeout: 1, homeDirectory: env.homeURL.path, dataLoader: dataLoader)
        let snapshot = try await probe.fetch()
        #expect(snapshot.accountPlan == nil)
    }

    @Test
    func `resolvePlan prefers paidTier ultra and pro over currentTier standard or free`() {
        let ultraOverStandard: [String: Any] = [
            "currentTier": ["id": "standard-tier", "name": "Standard"],
            "paidTier": ["id": "g1-ultra-tier", "name": "Google AI Ultra"],
        ]
        #expect(GeminiStatusProbe.resolvePlan(from: ultraOverStandard, hostedDomain: nil) == "Google AI Ultra")

        let ultraOverFree: [String: Any] = [
            "currentTier": ["id": "free-tier", "name": "Free"],
            "paidTier": ["id": "g1-ultra-tier", "name": "Gemini Code Assist in Google AI Ultra"],
        ]
        #expect(GeminiStatusProbe.resolvePlan(from: ultraOverFree, hostedDomain: nil) == "Google AI Ultra")

        let proPaidTier: [String: Any] = [
            "currentTier": ["id": "free-tier", "name": "Free"],
            "paidTier": ["id": "g1-pro-tier", "name": "Google AI Pro"],
        ]
        #expect(GeminiStatusProbe.resolvePlan(from: proPaidTier, hostedDomain: nil) == "Google AI Pro")

        let currentUltra: [String: Any] = [
            "currentTier": ["id": "g1-ultra-tier", "name": "Google AI Ultra"],
        ]
        #expect(GeminiStatusProbe.resolvePlan(from: currentUltra, hostedDomain: nil) == "Google AI Ultra")

        let personalFree: [String: Any] = [
            "currentTier": ["id": "free-tier", "name": "Free"],
        ]
        #expect(GeminiStatusProbe.resolvePlan(from: personalFree, hostedDomain: nil) == "Free")
        #expect(GeminiStatusProbe.resolvePlan(from: personalFree, hostedDomain: "acme.dev") == "Workspace")
    }

    @Test
    func `searchOAuthFile discovers bundled chunk JS in gemini-cli 0.68 layout`() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "gemini-bundle-test-\(UUID().uuidString)",
            isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let bundleDir = root
            .appendingPathComponent("libexec/lib/node_modules/@google/gemini-cli/bundle", isDirectory: true)
        try fm.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        let entryScript = bundleDir.appendingPathComponent("gemini.js")
        try "console.log('entry');".write(to: entryScript, atomically: true, encoding: .utf8)

        let unrelatedChunk = bundleDir.appendingPathComponent("chunk-AAAA0000.js")
        try "var unrelated = 'none';".write(to: unrelatedChunk, atomically: true, encoding: .utf8)

        let secretVar = "OAUTH_CLIENT_" + "SEC" + "RET"
        let oauthChunk = bundleDir.appendingPathComponent("chunk-TEST1234.js")
        let chunkBody = """
        const jwtInput = { client_id: OAUTH_CLIENT_ID };
        var OAUTH_CLIENT_ID = "12345.apps.googleusercontent.com", \(secretVar) = "dummy-test-cred-value";
        """
        try chunkBody.write(to: oauthChunk, atomically: true, encoding: .utf8)

        let extracted = GeminiStatusProbe.searchOAuthFile(realPath: entryScript.path, fm: fm)
        #expect(extracted?.clientId == "12345.apps.googleusercontent.com")
        #expect(extracted?.clientCredential == "dummy-test-cred-value")
    }

    @Test
    func `surfaces migration error when quota returns 403 for unsupported client`() async throws {
        let env = try GeminiTestEnvironment()
        defer { env.cleanup() }
        try env.writeCredentials(
            accessToken: "token",
            refreshToken: nil,
            expiry: Date().addingTimeInterval(3600),
            idToken: nil)

        let dataLoader = GeminiAPITestHelpers.dataLoader { request in
            guard let url = request.url, let host = url.host else {
                throw URLError(.badURL)
            }
            switch host {
            case "cloudresourcemanager.googleapis.com":
                return GeminiAPITestHelpers.response(
                    url: url.absoluteString,
                    status: 200,
                    body: GeminiAPITestHelpers.jsonData(["projects": []]))
            case "cloudcode-pa.googleapis.com":
                if url.path == "/v1internal:loadCodeAssist" {
                    let body = GeminiAPITestHelpers.jsonData([
                        "ineligibleTiers": [
                            [
                                "reasonCode": "UNSUPPORTED_CLIENT",
                                "reasonMessage": "Please migrate to Antigravity",
                                "tierId": "free-tier",
                            ],
                        ],
                    ])
                    return GeminiAPITestHelpers.response(url: url.absoluteString, status: 200, body: body)
                }
                if url.path == "/v1internal:retrieveUserQuota" {
                    let body = GeminiAPITestHelpers.jsonData([
                        "error": [
                            "code": 403,
                            "status": "PERMISSION_DENIED",
                            "message": "Subscription required",
                        ],
                    ])
                    return GeminiAPITestHelpers.response(url: url.absoluteString, status: 403, body: body)
                }
                return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
            default:
                return GeminiAPITestHelpers.response(url: url.absoluteString, status: 404, body: Data())
            }
        }

        let probe = GeminiStatusProbe(timeout: 1, homeDirectory: env.homeURL.path, dataLoader: dataLoader)
        do {
            _ = try await probe.fetch()
            #expect(Bool(false))
        } catch let error as GeminiStatusProbeError {
            guard case let .apiError(message) = error else {
                Issue.record("Expected apiError, got \(error)")
                return
            }
            #expect(message.contains("Antigravity"))
        }
    }
}
