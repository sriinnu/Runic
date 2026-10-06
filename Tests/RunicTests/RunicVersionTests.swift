import Foundation
import RunicCore
import Testing

struct RunicVersionTests {
    /// The CLI and MCP server report `RunicVersion.marketing`; the app bundle
    /// reports `version.env`. They have drifted before (the CLI said 1.0.0 at 2.9.1).
    @Test
    func `marketing version matches version env`() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let env = try String(contentsOf: root.appendingPathComponent("version.env"), encoding: .utf8)
        let marketing = env.split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix("MARKETING_VERSION=") }?
            .dropFirst("MARKETING_VERSION=".count)
        #expect(marketing.map(String.init) == RunicVersion.marketing)
    }
}
