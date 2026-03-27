import Foundation
import Testing
@testable import RunicCore

struct CopilotVSCodeTokenReaderTests {
    @Test
    func `extracts token from session array payload`() {
        let token = "ghu_abcdefghijklmnopqrstuvwxyz1234567890"
        let json = """
        [
          {
            "id": "session-1",
            "account": {
              "label": "dev@example.com",
              "id": "123"
            },
            "scopes": ["read:user", "user:email"],
            "accessToken": "\(token)"
          }
        ]
        """

        let extracted = CopilotVSCodeTokenReader._extractTokenFromDecryptedJSONForTesting(json)
        #expect(extracted == token)
    }

    @Test
    func `extracts token from nested object payload`() {
        let token = "github_pat_abcdefghijklmnopqrstuvwxyz1234567890"
        let json = """
        {
          "version": 1,
          "sessions": [
            {
              "token": "\(token)",
              "scopes": ["repo", "workflow"]
            }
          ]
        }
        """

        let extracted = CopilotVSCodeTokenReader._extractTokenFromDecryptedJSONForTesting(json)
        #expect(extracted == token)
    }

    @Test
    func `ignores short token values`() {
        let json = """
        {
          "sessions": [
            {
              "accessToken": "short"
            }
          ]
        }
        """

        let extracted = CopilotVSCodeTokenReader._extractTokenFromDecryptedJSONForTesting(json)
        #expect(extracted == nil)
    }

    @Test
    func `normalizes node buffer secret wrapper`() {
        let raw = Data("""
        {
          "type": "Buffer",
          "data": [118, 49, 48, 65, 66, 67]
        }
        """.utf8)

        let payload = CopilotVSCodeTokenReader._normalizedPayloadForTesting(raw)
        #expect(payload == Data([118, 49, 48, 65, 66, 67]))
    }
}
