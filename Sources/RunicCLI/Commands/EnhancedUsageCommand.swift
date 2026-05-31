// EnhancedUsageCommand.swift
// Runic CLI - Enhanced Usage Display
//
// Enhanced version of the usage command with additional features:
// - Multiple display modes (summary, detailed, breakdown)
// - Historical trending
// - Cost projections
// - Comparative analysis across providers
//
// Usage:
//   runic usage-enhanced [options]
//
// Examples:
//   runic usage-enhanced --mode summary      # Quick overview
//   runic usage-enhanced --mode detailed     # Detailed breakdown
//   runic usage-enhanced --mode trending     # Usage trends

import Foundation
import Helix
import RunicCore

/// Enhanced usage command with additional analytics
public enum EnhancedUsageCommand {
    /// Command signature defining available options and flags
    public static var signature: CommandSignature {
        CommandSignature(
            options: [
                OptionDefinition(
                    label: "provider",
                    names: [.long("provider"), .short("p")],
                    help: "Filter by provider (claude, codex, etc.)"),
                OptionDefinition(
                    label: "mode",
                    names: [.long("mode"), .short("m")],
                    help: "Display mode: summary | detailed | breakdown | trending"),
                OptionDefinition(
                    label: "days",
                    names: [.long("days"), .short("d")],
                    help: "Number of days for trending analysis (default: 7)"),
                OptionDefinition(
                    label: "format",
                    names: [.long("format")],
                    help: "Output format: text | json"),
            ],
            flags: [
                FlagDefinition(
                    label: "json",
                    names: [.long("json"), .short("j")],
                    help: "Output in JSON format"),
                FlagDefinition(
                    label: "pretty",
                    names: [.long("pretty")],
                    help: "Pretty-print JSON output"),
                FlagDefinition(
                    label: "noColor",
                    names: [.long("no-color")],
                    help: "Disable ANSI color codes"),
                FlagDefinition(
                    label: "showCost",
                    names: [.long("show-cost")],
                    help: "Include cost information"),
                FlagDefinition(
                    label: "showProjected",
                    names: [.long("projected")],
                    help: "Show projected usage at current rate"),
                FlagDefinition(
                    label: "compare",
                    names: [.long("compare")],
                    help: "Compare usage across providers"),
            ])
    }

    /// Command descriptor for registration
    public static var descriptor: CommandDescriptor {
        CommandDescriptor(
            name: "usage-enhanced",
            abstract: "Enhanced usage display with analytics",
            discussion: """
            Enhanced version of the usage command with additional features:

            DISPLAY MODES:
              summary   - Quick overview of current usage (default)
              detailed  - Detailed breakdown with all windows
              breakdown - Token breakdown by type (input/output/cache)
              trending  - Historical usage trends

            EXAMPLES:
              runic usage-enhanced
                Show summary for all providers

              runic usage-enhanced --mode detailed --show-cost
                Detailed view with cost information

              runic usage-enhanced --mode trending --days 30
                Show 30-day usage trends

              runic usage-enhanced --compare --json
                Compare providers in JSON format

              runic usage-enhanced --projected
                Show projected usage based on current rate
            """,
            signature: signature)
    }

    /// Execute the enhanced usage command
    public static func run(_ invocation: CommandInvocation) async {
        let config = self.parseConfiguration(invocation)

        do {
            let data = try await loadUsageData(
                providers: config.providers,
                days: config.days,
                includeCost: config.showCost)

            if config.isJSON {
                self.outputJSON(data, config: config)
            } else {
                self.outputText(data, config: config)
            }
        } catch {
            self.exitWithError("Failed to load usage data: \(error.localizedDescription)")
        }
    }
}
