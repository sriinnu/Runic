import Foundation
import Helix
import RunicCore

extension EnhancedUsageCommand {
    struct Configuration {
        let providers: [UsageProvider]
        let mode: DisplayMode
        let days: Int
        let isJSON: Bool
        let isPretty: Bool
        let useColor: Bool
        let showCost: Bool
        let showProjected: Bool
        let compare: Bool

        enum DisplayMode: String {
            case summary
            case detailed
            case breakdown
            case trending
        }
    }

    static func parseConfiguration(_ invocation: CommandInvocation) -> Configuration {
        let providerArg = invocation.parsedValues.options["provider"]?.first
        let modeArg = invocation.parsedValues.options["mode"]?.first ?? "summary"
        let daysArg = invocation.parsedValues.options["days"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"

        let isJSON = invocation.parsedValues.flags.contains("json")
            || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")
        let showCost = invocation.parsedValues.flags.contains("showCost")
        let showProjected = invocation.parsedValues.flags.contains("showProjected")
        let compare = invocation.parsedValues.flags.contains("compare")

        let mode = Configuration.DisplayMode(rawValue: modeArg.lowercased()) ?? .summary
        let days = daysArg.flatMap(Int.init) ?? 7
        let providers = self.resolveProviders(providerArg)

        return Configuration(
            providers: providers,
            mode: mode,
            days: days,
            isJSON: isJSON,
            isPretty: isPretty,
            useColor: !noColor,
            showCost: showCost,
            showProjected: showProjected,
            compare: compare)
    }

    static func resolveProviders(_ arg: String?) -> [UsageProvider] {
        guard let arg = arg?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return ProviderDescriptorRegistry.all.map(\.id)
        }

        if arg == "all" {
            return ProviderDescriptorRegistry.all.map(\.id)
        }

        guard let provider = UsageProvider(rawValue: arg) else {
            self.exitWithError("Unknown provider: \(arg)")
        }

        return [provider]
    }
}
