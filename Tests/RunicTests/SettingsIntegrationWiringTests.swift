import Foundation
import Testing
@testable import Runic

struct SettingsIntegrationWiringTests {
    @Test @MainActor
    func `insights command resolves a worktree git directory and quotes its path`() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-settings-'\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = root.appendingPathComponent("repository", isDirectory: true)
        let gitDirectory = root.appendingPathComponent("actual-git", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: gitDirectory, withIntermediateDirectories: true)
        try "gitdir: ../actual-git\n".write(
            to: repository.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        #expect(IntegrationsPane.gitDirectory(for: repository.path) == gitDirectory.path)
        let command = IntegrationsPane.insightsCommand(for: repository.path)
        #expect(command.contains("--git-directory"))
        #expect(command.contains("'\"'\"'"))
        #expect(command.contains("--json --pretty"))
        #expect(!command.contains("--format"))
    }
}
