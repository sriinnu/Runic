import Foundation

@main
enum RunicCLI {
    static func main() async {
        let rawArgv = Array(CommandLine.arguments.dropFirst())
        let argv = Self.effectiveArgv(rawArgv)

        // Handle help/version
        if argv.contains("-h") || argv.contains("--help") {
            let command = argv.first { $0 != "-h" && $0 != "--help" && !$0.hasPrefix("-") }
            Self.printHelp(for: command)
        }
        if argv.contains("-V") || argv.contains("--version") {
            Self.printVersion()
        }

        do {
            let invocation = try Self.program.resolve(argv: argv)
            switch invocation.descriptor.name {
            case "usage":
                await self.runUsage(invocation)
            case "cost":
                await self.runCost(invocation)
            case "insights":
                await self.runInsights(invocation)
            case "otel-collect":
                await self.runOTelCollect(invocation)
            default:
                Self.exit(code: 1, message: "Unknown command")
            }
        } catch {
            Self.exit(code: 1, message: error.localizedDescription)
        }
    }
}
