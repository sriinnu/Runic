import Foundation
import Helix
import RunicCore

extension RunicCLI {
    static func runUsage(_ invocation: CommandInvocation) async {
        let providerArg = invocation.parsedValues.options["provider"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"
        let isJson = invocation.parsedValues.flags.contains("json") || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")
        let useColor = !noColor

        let providers: [UsageProvider]
        if let providerName = providerArg?.lowercased() {
            providers = Self.resolveProviderList(
                providerName,
                defaultProviders: ProviderDescriptorRegistry.all.map(\.id))
        } else {
            providers = ProviderDescriptorRegistry.all.map(\.id)
        }

        let fetcher = UsageFetcher()
        var output = ""

        for provider in providers {
            do {
                let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
                let context = ProviderFetchContext(
                    runtime: .cli,
                    sourceMode: .cli,
                    includeCredits: true,
                    webTimeout: 60,
                    webDebugDumpHTML: false,
                    verbose: false,
                    env: ProcessInfo.processInfo.environment,
                    settings: nil,
                    fetcher: fetcher,
                    claudeFetcher: ClaudeUsageFetcher())

                let outcome = await descriptor.fetchOutcome(context: context)
                let result = try outcome.result.get()

                let header = "\(descriptor.metadata.sessionLabel)"
                let text = Self.renderUsageText(
                    provider: provider,
                    snapshot: result.usage,
                    credits: result.credits,
                    header: header,
                    useColor: useColor)

                if !output.isEmpty { output += "\n" }
                output += text
            } catch {
                let errorMsg = "Error fetching \(provider.rawValue): \(error.localizedDescription)"
                if !output.isEmpty { output += "\n" }
                output += errorMsg
            }
        }

        if isPretty, isJson {
            if let data = output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let prettyData = try? JSONSerialization.data(
                   withJSONObject: json,
                   options: [.prettyPrinted, .sortedKeys]),
               let pretty = String(data: prettyData, encoding: .utf8)
            {
                print(pretty)
            } else {
                print(output)
            }
        } else {
            print(output)
        }
    }

    static func runCost(_ invocation: CommandInvocation) async {
        let providerArg = invocation.parsedValues.options["provider"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"
        let isJson = invocation.parsedValues.flags.contains("json") || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")
        let useColor = !noColor
        let refreshRequested = invocation.parsedValues.flags.contains("refresh")
        let rebuild = invocation.parsedValues.flags.contains("rebuild")
        let mode: CostUsageLoadMode = rebuild ? .rebuildHistory : .refresh
        if refreshRequested, !rebuild {
            Self.printError(
                "runic cost: --refresh is accepted for compatibility; cost refreshes today's logs by default.")
        }

        let providers: [UsageProvider]
        if let providerName = providerArg?.lowercased() {
            providers = Self.resolveProviderList(providerName, defaultProviders: [.claude, .codex])
            if let unsupported = providers.first(where: { $0 != .claude && $0 != .codex }) {
                Self.exit(code: 1, message: "Cost is only supported for claude and codex, not \(unsupported.rawValue)")
            }
        } else {
            providers = [.claude, .codex]
        }

        let fetcher = CostUsageFetcher()
        var output = ""

        for provider in providers {
            do {
                let snapshot = try await fetcher.loadTokenSnapshot(provider: provider, mode: mode)
                let text = Self.renderCostText(provider: provider, snapshot: snapshot, useColor: useColor)
                if !output.isEmpty { output += "\n" }
                output += text
            } catch {
                let errorMsg = "Error fetching cost for \(provider.rawValue): \(error.localizedDescription)"
                if !output.isEmpty { output += "\n" }
                output += errorMsg
            }
        }

        if isPretty, isJson {
            print("{\"cost\": \"output available in text format\"}")
        } else {
            print(output)
        }
    }
}
