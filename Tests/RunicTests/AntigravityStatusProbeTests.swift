import RunicCore
import XCTest

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
        // Unknown-only quotas must surface as an error, not a 0%-remaining window.
        XCTAssertThrowsError(try snapshot.toUsageSnapshot())
    }
}
