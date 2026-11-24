import Foundation
import Helix
import RunicCore

struct CLIUsageQueryOptions {
    let explicitFilter: Bool
    let isJson: Bool
    let isPretty: Bool
    let useColor: Bool
}

struct CLIUsageCommandOutput: Equatable {
    let stdout: String?
    let stderrErrors: [String]
    let exitCode: Int32
}

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

        let normalizedProviderArg = providerArg?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let explicitFilter = normalizedProviderArg.map { !$0.isEmpty && $0 != "all" } ?? false
        let providers: [UsageProvider] = if let normalizedProviderArg, !normalizedProviderArg.isEmpty {
            Self.resolveProviderList(
                normalizedProviderArg,
                defaultProviders: ProviderDescriptorRegistry.all.map(\.id))
        } else {
            ProviderDescriptorRegistry.all.map(\.id)
        }

        let fetcher = UsageFetcher()
        let options = CLIUsageQueryOptions(
            explicitFilter: explicitFilter,
            isJson: isJson,
            isPretty: isPretty,
            useColor: useColor)
        let outcome = await Self.executeUsageQuery(providers: providers, options: options) { provider in
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
            let result = try await descriptor.fetchOutcome(context: context).result.get()
            return (sourceLabel: result.sourceLabel, usage: result.usage, credits: result.credits)
        }

        if let stdout = outcome.stdout {
            print(stdout)
            fflush(Foundation.stdout)
        }
        for errorMessage in outcome.stderrErrors {
            Self.printError(errorMessage)
        }
        if outcome.exitCode != 0 {
            Foundation.exit(outcome.exitCode)
        }
    }

    static func executeUsageQuery(
        providers: [UsageProvider],
        options: CLIUsageQueryOptions,
        fetchProvider: @Sendable (UsageProvider) async throws -> (
            sourceLabel: String,
            usage: UsageSnapshot,
            credits: CreditsSnapshot?)) async -> CLIUsageCommandOutput
    {
        var textBlocks: [String] = []
        var textErrors: [String] = []
        var jsonEntries: [CLIUsageJSONEntry] = []
        var attemptedLiveCount = 0
        var failedLiveCount = 0

        for provider in providers {
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            if !descriptor.metadata.providesLiveSnapshot {
                if options.explicitFilter {
                    let note = "Provider uses local logs only (no live snapshot)."
                    if options.isJson {
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

            attemptedLiveCount += 1
            do {
                let fetched = try await fetchProvider(provider)

                if options.isJson {
                    jsonEntries.append(CLIUsageJSONEntry(
                        provider: provider,
                        displayName: descriptor.metadata.displayName,
                        source: fetched.sourceLabel,
                        snapshot: fetched.usage.scoped(to: provider),
                        credits: fetched.credits,
                        error: nil))
                } else {
                    let header = descriptor.metadata.displayName
                    let text = Self.renderUsageText(
                        provider: provider,
                        snapshot: fetched.usage,
                        credits: fetched.credits,
                        header: header,
                        useColor: options.useColor)
                    textBlocks.append(text)
                }
            } catch {
                failedLiveCount += 1
                if options.isJson {
                    jsonEntries.append(CLIUsageJSONEntry(
                        provider: provider,
                        displayName: descriptor.metadata.displayName,
                        source: nil,
                        snapshot: nil,
                        credits: nil,
                        error: error.localizedDescription))
                } else {
                    textErrors.append("Error fetching \(provider.rawValue): \(error.localizedDescription)")
                }
            }
        }

        let shouldFail = (options.explicitFilter && failedLiveCount > 0)
            || (attemptedLiveCount > 0 && failedLiveCount == attemptedLiveCount)

        if options.isJson {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if options.isPretty {
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }
            if let data = try? encoder.encode(jsonEntries),
               let encoded = String(data: data, encoding: .utf8)
            {
                return CLIUsageCommandOutput(
                    stdout: encoded,
                    stderrErrors: textErrors,
                    exitCode: shouldFail ? 1 : 0)
            }
            return CLIUsageCommandOutput(
                stdout: nil,
                stderrErrors: textErrors + ["Failed to encode usage JSON output."],
                exitCode: 1)
        }

        let stdout = textBlocks.isEmpty ? nil : textBlocks.joined(separator: "\n")
        return CLIUsageCommandOutput(
            stdout: stdout,
            stderrErrors: textErrors,
            exitCode: shouldFail ? 1 : 0)
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
