import RunicCore
import Helix
import Testing
@testable import RunicCLI

@Suite
struct CLIArgumentParsingTests {
    @Test
    func jsonShortcutDoesNotEnableJsonLogs() throws {
        let signature = RunicCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--json"])

        #expect(parsed.flags.contains("jsonShortcut"))
        #expect(!parsed.flags.contains("jsonOutput"))
        #expect(RunicCLI._decodeFormatForTesting(from: parsed) == .json)
    }

    @Test
    func jsonOutputFlagEnablesJsonLogs() throws {
        let signature = RunicCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--json-output"])

        #expect(parsed.flags.contains("jsonOutput"))
        #expect(!parsed.flags.contains("jsonShortcut"))
        #expect(RunicCLI._decodeFormatForTesting(from: parsed) == .text)
    }

    @Test
    func logLevelAndVerboseAreParsed() throws {
        let signature = RunicCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--log-level", "info", "--verbose"])

        #expect(parsed.flags.contains("verbose"))
        #expect(parsed.options["logLevel"] == ["info"])
    }

    @Test
    func resolvedLogLevelDefaultsToError() {
        #expect(RunicCLI.resolvedLogLevel(verbose: false, rawLevel: nil) == .error)
        #expect(RunicCLI.resolvedLogLevel(verbose: true, rawLevel: nil) == .debug)
        #expect(RunicCLI.resolvedLogLevel(verbose: false, rawLevel: "info") == .info)
    }

    @Test
    func formatOptionOverridesJsonShortcut() throws {
        let signature = RunicCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--json", "--format", "text"])

        #expect(parsed.flags.contains("jsonShortcut"))
        #expect(parsed.options["format"] == ["text"])
        #expect(RunicCLI._decodeFormatForTesting(from: parsed) == .text)
    }
}
