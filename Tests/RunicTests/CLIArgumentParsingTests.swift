import Helix
import Testing

@Suite
struct CLIArgumentParsingTests {
    @Test
    func usageCommandParsesProviderAndJsonFlags() throws {
        let signature = CommandSignature(
            options: [
                OptionDefinition(label: "provider", names: [.long("provider")], help: nil),
                OptionDefinition(label: "format", names: [.long("format")], help: nil),
            ],
            flags: [
                FlagDefinition(label: "json", names: [.long("json")], help: nil),
                FlagDefinition(label: "pretty", names: [.long("pretty")], help: nil),
                FlagDefinition(label: "noColor", names: [.long("no-color")], help: nil),
            ])
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--provider", "codex", "--json", "--pretty", "--no-color"])

        #expect(parsed.options["provider"] == ["codex"])
        #expect(parsed.flags.contains("json"))
        #expect(parsed.flags.contains("pretty"))
        #expect(parsed.flags.contains("noColor"))
    }

    @Test
    func costCommandParsesRefreshFlag() throws {
        let signature = CommandSignature(
            options: [
                OptionDefinition(label: "provider", names: [.long("provider")], help: nil),
            ],
            flags: [
                FlagDefinition(label: "refresh", names: [.long("refresh")], help: nil),
            ])
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--provider", "claude", "--refresh"])

        #expect(parsed.options["provider"] == ["claude"])
        #expect(parsed.flags.contains("refresh"))
    }

    @Test
    func insightsCommandParsesViewAndBudgetFlags() throws {
        let signature = CommandSignature(
            options: [
                OptionDefinition(label: "view", names: [.long("view")], help: nil),
                OptionDefinition(label: "project", names: [.long("project")], help: nil),
                OptionDefinition(label: "timezone", names: [.long("timezone")], help: nil),
            ],
            flags: [
                FlagDefinition(label: "budget", names: [.long("budget")], help: nil),
                FlagDefinition(label: "withCommits", names: [.long("with-commits")], help: nil),
            ])
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: [
            "--view", "projects",
            "--project", "runic",
            "--timezone", "America/Los_Angeles",
            "--budget",
            "--with-commits",
        ])

        #expect(parsed.options["view"] == ["projects"])
        #expect(parsed.options["project"] == ["runic"])
        #expect(parsed.options["timezone"] == ["America/Los_Angeles"])
        #expect(parsed.flags.contains("budget"))
        #expect(parsed.flags.contains("withCommits"))
    }
}
