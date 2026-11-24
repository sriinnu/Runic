import Foundation
import Helix
import RunicCore

private struct CLIUsageJSONEntry: Encodable {
    let provider: UsageProvider
    let displayName: String
    let source: String?
    let snapshot: UsageSnapshot?
    let credits: CreditsSnapshot?
    let error: String?
}

extension RunicCLI {
    static func runUsage(_ invocation: CommandInvocation) async {
        let providerArg = invocation.parsedValues.options["provider"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"
        let isJson = invocation.parsedValues.flags.contains("json") || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")
        let useColor = !noColor

        let explicitFilter = providerArg != nil
        let providers: [UsageProvider] = if let providerName = providerArg?.lowercased() {
            Self.resolveProviderList(
                providerName,
                defaultProviders: ProviderDescriptorRegistry.all.map(\.id))
        } else {
            ProviderDescriptorRegistry.all.map(\.id)
        }

        let fetcher = UsageFetcher()
        var textBlocks: [String] = []
        var jsonEntries: [CLIUsageJSONEntry] = []

        for provider in providers {
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            if !descriptor.metadata.providesLiveSnapshot {
                if explicitFilter {
                    let note = "Provider uses local logs only (no live snapshot)."
                    if isJson {
                        jsonEntries.append(CLIUsageJSONEntry(
                            provider: provider,
                            displayName: descriptor.metadata.displayName,
                            source: "ledger-only",
                            snapshot: nil,
                            credits: nil,
                            error: nil))
                    } else {
                        textBlocks.append("\(descriptor.metadata.displayName)\n\(note)")
                    }
                }
                continue
            }

            do {
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

                if isJson {
                    jsonEntries.append(CLIUsageJSONEntry(
                        provider: provider,
                        displayName: descriptor.metadata.displayName,
                        source: result.sourceLabel,
                        snapshot: result.usage.scoped(to: provider),
                        credits: result.credits,
                        error: nil))
                } else {
                    let header = descriptor.metadata.displayName
                    let text = Self.renderUsageText(
                        provider: provider,
                        snapshot: result.usage,
                        credits: result.credits,
                        header: header,
                        useColor: useColor)
                    textBlocks.append(text)
                }
            } catch {
                if isJson {
                    jsonEntries.append(CLIUsageJSONEntry(
                        provider: provider,
                        displayName: descriptor.metadata.displayName,
                        source: nil,
                        snapshot: nil,
                        credits: nil,
                        error: error.localizedDescription))
                } else {
                    textBlocks.append("Error fetching \(provider.rawValue): \(error.localizedDescription)")
                }
            }
        }

        if isJson {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if isPretty {
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }
            if let data = try? encoder.encode(jsonEntries),
               let encoded = String(data: data, encoding: .utf8)
            {
                print(encoded)
            } else {
                print("[]")
            }
        } else {
            print(textBlocks.joined(separator: "\n"))
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
