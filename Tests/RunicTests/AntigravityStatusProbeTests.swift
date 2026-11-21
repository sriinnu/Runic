import XCTest
@testable import RunicCore

final class AntigravityStatusProbeTests: XCTestCase {
    func test_parsesUserStatusResponse() throws {
        let json = """
        {
          "code": 0,
          "userStatus": {
            "email": "test@example.com",
            "planStatus": {
              "planInfo": {
                "planName": "Pro"
              }
            },
            "cascadeModelConfigData": {
              "clientModelConfigs": [
                {
                  "label": "Claude 3.5 Sonnet",
                  "modelOrAlias": { "model": "claude-3-5-sonnet" },
                  "quotaInfo": { "remainingFraction": 0.5, "resetTime": "2025-12-24T10:00:00Z" }
                },
                {
                  "label": "Gemini Pro Low",
                  "modelOrAlias": { "model": "gemini-pro-low" },
                  "quotaInfo": { "remainingFraction": 0.8, "resetTime": "2025-12-24T11:00:00Z" }
                },
                {
                  "label": "Gemini Flash",
                  "modelOrAlias": { "model": "gemini-flash" },
                  "quotaInfo": { "remainingFraction": 0.2, "resetTime": "2025-12-24T12:00:00Z" }
                }
              ]
            }
          }
        }
        """

        let data = Data(json.utf8)
        let snapshot = try AntigravityStatusProbe.parseUserStatusResponse(data)
        XCTAssertEqual(snapshot.accountEmail, "test@example.com")
        XCTAssertEqual(snapshot.accountPlan, "Pro")
        XCTAssertEqual(snapshot.modelQuotas.count, 3)

        let usage = try snapshot.toUsageSnapshot()
        XCTAssertEqual(usage.primary.remainingPercent.rounded(), 20)
        XCTAssertEqual(usage.secondary?.remainingPercent.rounded(), 50)
        XCTAssertEqual(usage.tertiary?.remainingPercent.rounded(), 80)
    }

    /// A quota whose remainingFraction is absent is UNKNOWN, not depleted: it must
    /// be dropped instead of rendered as 0% remaining (which fires a false
    /// "session depleted" notification and sorts first as most-constrained).
    func test_dropsQuotaWithUnknownRemainingFraction() throws {
        let json = """
        {
          "code": 0,
          "userStatus": {
            "email": "test@example.com",
            "cascadeModelConfigData": {
              "clientModelConfigs": [
                {
                  "label": "Claude 3.5 Sonnet",
                  "modelOrAlias": { "model": "claude-3-5-sonnet" },
                  "quotaInfo": { "resetTime": "2025-12-24T10:00:00Z" }
                },
                {
                  "label": "Gemini Pro Low",
                  "modelOrAlias": { "model": "gemini-pro-low" },
                  "quotaInfo": { "remainingFraction": 0.8, "resetTime": "2025-12-24T11:00:00Z" }
                }
              ]
            }
          }
        }
        """

        let data = Data(json.utf8)
        let snapshot = try AntigravityStatusProbe.parseUserStatusResponse(data)
        XCTAssertEqual(snapshot.modelQuotas.count, 2)

        let usage = try snapshot.toUsageSnapshot()
        // Claude's unknown quota is dropped — the known Gemini quota leads.
        XCTAssertEqual(usage.primary.label, "Gemini Pro Low")
        XCTAssertEqual(usage.primary.remainingPercent.rounded(), 80)
        XCTAssertNil(usage.secondary)
    }

    func test_allQuotasUnknownRemainingFractionThrows() throws {
        let json = """
        {
          "code": 0,
          "userStatus": {
            "email": "test@example.com",
            "cascadeModelConfigData": {
              "clientModelConfigs": [
                {
                  "label": "Claude 3.5 Sonnet",
                  "modelOrAlias": { "model": "claude-3-5-sonnet" },
                  "quotaInfo": { "resetTime": "2025-12-24T10:00:00Z" }
                }
              ]
            }
          }
        }
        """

        let data = Data(json.utf8)
        let snapshot = try AntigravityStatusProbe.parseUserStatusResponse(data)
        // Unknown-only quotas must not become a 0%-remaining window.
        XCTAssertEqual(try snapshot.toUsageSnapshot().primary, .noLimitsReported)
    }

    func test_classifyProcessLinesDetectsStandaloneTokenUnavailable() throws {
        let psOutput = [
            "  6491 /Applications/Antigravity.app/Contents/Resources/bin/language_server",
            "--standalone --override_ide_name antigravity --override_ide_version 2.34.0",
            "--app_data_dir antigravity --read_host_bridge_token_from_stdin",
        ].joined(separator: " ")
        XCTAssertThrowsError(try AntigravityStatusProbe.classifyProcessLines(psOutput)) { error in
            XCTAssertEqual(
                error as? AntigravityStatusProbeError,
                .standaloneTokenUnavailable(version: "2.34.0"))
        }
    }

    func test_classifyProcessLinesDetectsLegacyMissingCSRFAndExtractsToken() throws {
        let legacyMissing = [
            "  1001 /Applications/Antigravity.app/Contents/Resources/bin/language_server_macos_arm",
            "--app_data_dir antigravity",
        ].joined(separator: " ")
        XCTAssertThrowsError(try AntigravityStatusProbe.classifyProcessLines(legacyMissing)) { error in
            XCTAssertEqual(error as? AntigravityStatusProbeError, .missingCSRFToken)
        }

        let legacyOK = [
            "  1002 /Applications/Antigravity.app/Contents/Resources/bin/language_server_macos_arm",
            "--app_data_dir antigravity --csrf_token tok-abc --extension_server_port 51234",
        ].joined(separator: " ")
        let results = try AntigravityStatusProbe.classifyProcessLines(legacyOK)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.csrfToken, "tok-abc")
        XCTAssertEqual(results.first?.extensionPort, 51234)
    }

    func test_parsesFractionalSecondAndEpochDatesInQuotaResetTime() throws {
        let json = """
        {
          "code": 0,
          "userStatus": {
            "email": "test@example.com",
            "cascadeModelConfigData": {
              "clientModelConfigs": [
                {
                  "label": "Gemini Pro",
                  "modelOrAlias": { "model": "gemini-pro" },
                  "quotaInfo": { "remainingFraction": 0.9, "resetTime": "2026-11-21T12:00:00.123Z" }
                },
                {
                  "label": "Claude",
                  "modelOrAlias": { "model": "claude" },
                  "quotaInfo": { "remainingFraction": 0.8, "resetTime": "2026-11-21T13:00:00Z" }
                },
                {
                  "label": "Gemini Flash",
                  "modelOrAlias": { "model": "gemini-flash" },
                  "quotaInfo": { "remainingFraction": 0.7, "resetTime": "1795266000" }
                }
              ]
            }
          }
        }
        """
        let snapshot = try AntigravityStatusProbe.parseUserStatusResponse(Data(json.utf8))
        XCTAssertEqual(snapshot.modelQuotas.count, 3)
        XCTAssertNotNil(snapshot.modelQuotas[0].resetTime)
        XCTAssertNotNil(snapshot.modelQuotas[1].resetTime)
        XCTAssertEqual(snapshot.modelQuotas[2].resetTime, Date(timeIntervalSince1970: 1_795_266_000))
    }
}
