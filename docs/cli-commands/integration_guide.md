# Integration Guide for New Runic CLI Commands

This guide provides step-by-step instructions for integrating the new tracking commands into the Runic CLI.

## Prerequisites

Before integrating, ensure you have:
- All command files in `/Sources/RunicCLI/Commands/`
- Existing CLI infrastructure in `/Sources/RunicCLI/CLIEntry.swift`
- Helix framework dependency configured
- RunicCore module available

## Integration Steps

### 1. Update CLIEntry.swift

Open `/Sources/RunicCLI/CLIEntry.swift` and make the following changes:

#### A. Add Command Signatures

After the existing `insightsSignature` definition (around line 57), add:

```swift
// Models command signature
let modelsSignature = CommandSignature(
    options: [
        OptionDefinition(label: "provider", names: [.long("provider"), .short("p")],
                        help: "Filter by provider (claude, codex, gemini, etc.)"),
        OptionDefinition(label: "days", names: [.long("days"), .short("d")],
                        help: "Number of days to analyze (default: 30)"),
        OptionDefinition(label: "format", names: [.long("format")],
                        help: "Output format: text | json"),
    ],
    flags: [
        FlagDefinition(label: "json", names: [.long("json"), .short("j")],
                      help: "Output in JSON format"),
        FlagDefinition(label: "pretty", names: [.long("pretty")],
                      help: "Pretty-print JSON output"),
        FlagDefinition(label: "noColor", names: [.long("no-color")],
                      help: "Disable ANSI color codes"),
        FlagDefinition(label: "groupByProject", names: [.long("by-project")],
                      help: "Group results by project"),
    ])

// Projects command signature
let projectsSignature = CommandSignature(
    options: [
        OptionDefinition(label: "stats", names: [.long("stats"), .short("s")],
                        help: "Show detailed stats for a specific project ID"),
        OptionDefinition(label: "provider", names: [.long("provider"), .short("p")],
                        help: "Filter by provider"),
        OptionDefinition(label: "days", names: [.long("days"), .short("d")],
                        help: "Number of days to analyze (default: 30)"),
        OptionDefinition(label: "format", names: [.long("format")],
                        help: "Output format: text | json"),
    ],
    flags: [
        FlagDefinition(label: "list", names: [.long("list"), .short("l")],
                      help: "List all projects (default behavior)"),
        FlagDefinition(label: "json", names: [.long("json"), .short("j")],
                      help: "Output in JSON format"),
        FlagDefinition(label: "pretty", names: [.long("pretty")],
                      help: "Pretty-print JSON output"),
        FlagDefinition(label: "noColor", names: [.long("no-color")],
                      help: "Disable ANSI color codes"),
        FlagDefinition(label: "sortByName", names: [.long("sort-name")],
                      help: "Sort projects alphabetically by name"),
    ])

// Alerts command signature
let alertsSignature = CommandSignature(
    options: [
        OptionDefinition(label: "provider", names: [.long("provider"), .short("p")],
                        help: "Filter alerts by provider"),
        OptionDefinition(label: "format", names: [.long("format")],
                        help: "Output format: text | json"),
    ],
    flags: [
        FlagDefinition(label: "active", names: [.long("active"), .short("a")],
                      help: "Show only active alerts (default)"),
        FlagDefinition(label: "history", names: [.long("history"), .short("h")],
                      help: "Show alert history"),
        FlagDefinition(label: "clear", names: [.long("clear"), .short("c")],
                      help: "Clear resolved alerts from history"),
        FlagDefinition(label: "json", names: [.long("json"), .short("j")],
                      help: "Output in JSON format"),
        FlagDefinition(label: "pretty", names: [.long("pretty")],
                      help: "Pretty-print JSON output"),
        FlagDefinition(label: "noColor", names: [.long("no-color")],
                      help: "Disable ANSI color codes"),
    ])

// Reset command signature
let resetSignature = CommandSignature(
    options: [
        OptionDefinition(label: "when", names: [.long("when"), .short("w")],
                        help: "Show reset timing for specific provider"),
        OptionDefinition(label: "format", names: [.long("format")],
                        help: "Output format: text | json"),
    ],
    flags: [
        FlagDefinition(label: "all", names: [.long("all"), .short("a")],
                      help: "Show all providers (default)"),
        FlagDefinition(label: "json", names: [.long("json"), .short("j")],
                      help: "Output in JSON format"),
        FlagDefinition(label: "pretty", names: [.long("pretty")],
                      help: "Pretty-print JSON output"),
        FlagDefinition(label: "noColor", names: [.long("no-color")],
                      help: "Disable ANSI color codes"),
        FlagDefinition(label: "compact", names: [.long("compact"), .short("c")],
                      help: "Show compact output"),
    ])

// Enhanced usage command signature
let usageEnhancedSignature = CommandSignature(
    options: [
        OptionDefinition(label: "provider", names: [.long("provider"), .short("p")],
                        help: "Filter by provider"),
        OptionDefinition(label: "mode", names: [.long("mode"), .short("m")],
                        help: "Display mode: summary | detailed | breakdown | trending"),
        OptionDefinition(label: "days", names: [.long("days"), .short("d")],
                        help: "Number of days for trending (default: 7)"),
        OptionDefinition(label: "format", names: [.long("format")],
                        help: "Output format: text | json"),
    ],
    flags: [
        FlagDefinition(label: "json", names: [.long("json"), .short("j")],
                      help: "Output in JSON format"),
        FlagDefinition(label: "pretty", names: [.long("pretty")],
                      help: "Pretty-print JSON output"),
        FlagDefinition(label: "noColor", names: [.long("no-color")],
                      help: "Disable ANSI color codes"),
        FlagDefinition(label: "showCost", names: [.long("show-cost")],
                      help: "Include cost information"),
        FlagDefinition(label: "showProjected", names: [.long("projected")],
                      help: "Show projected usage at current rate"),
        FlagDefinition(label: "compare", names: [.long("compare")],
                      help: "Compare usage across providers"),
    ])
```

#### B. Create Command Descriptors

After the descriptors (around line 75), add:

```swift
let modelsDescriptor = CommandDescriptor(
    name: "models",
    abstract: "Show model usage breakdown across providers",
    discussion: nil,
    signature: modelsSignature)

let projectsDescriptor = CommandDescriptor(
    name: "projects",
    abstract: "Track usage across different projects",
    discussion: nil,
    signature: projectsSignature)

let alertsDescriptor = CommandDescriptor(
    name: "alerts",
    abstract: "Manage usage threshold alerts",
    discussion: nil,
    signature: alertsSignature)

let resetDescriptor = CommandDescriptor(
    name: "reset",
    abstract: "Show when usage limits reset",
    discussion: nil,
    signature: resetSignature)

let usageEnhancedDescriptor = CommandDescriptor(
    name: "usage-enhanced",
    abstract: "Enhanced usage display with analytics",
    discussion: nil,
    signature: usageEnhancedSignature)
```

#### C. Update Program Initialization

Replace line 77 with:

```swift
let program = Program(descriptors: [
    usageDescriptor,
    costDescriptor,
    insightsDescriptor,
    modelsDescriptor,
    projectsDescriptor,
    alertsDescriptor,
    resetDescriptor,
    usageEnhancedDescriptor,
])
```

#### D. Add Command Handlers

In the switch statement (around line 82), update to:

```swift
switch invocation.descriptor.name {
case "usage":
    await self.runUsage(invocation)
case "cost":
    await self.runCost(invocation)
case "insights":
    await self.runInsights(invocation)
case "models":
    await self.runModels(invocation)
case "projects":
    await self.runProjects(invocation)
case "alerts":
    await self.runAlerts(invocation)
case "reset":
    await self.runReset(invocation)
case "usage-enhanced":
    await self.runUsageEnhanced(invocation)
default:
    Self.exit(code: 1, message: "Unknown command")
}
```

#### E. Implement Command Methods

Add these methods after the existing command methods (after `runInsights`):

```swift
// MARK: - New Commands

private static func runModels(_ invocation: CommandInvocation) async {
    await ModelsCommand.run(invocation)
}

private static func runProjects(_ invocation: CommandInvocation) async {
    await ProjectsCommand.run(invocation)
}

private static func runAlerts(_ invocation: CommandInvocation) async {
    await AlertsCommand.run(invocation)
}

private static func runReset(_ invocation: CommandInvocation) async {
    await ResetCommand.run(invocation)
}

private static func runUsageEnhanced(_ invocation: CommandInvocation) async {
    await EnhancedUsageCommand.run(invocation)
}
```

### 2. Build and Test

#### Build the CLI
```bash
cd /Users/srinivaspendela/Sriinnu/AI/Runic
swift build --target RunicCLI
```

#### Test Commands
```bash
# Test help
.build/debug/RunicCLI --help

# Test each command
.build/debug/RunicCLI models
.build/debug/RunicCLI projects
.build/debug/RunicCLI alerts
.build/debug/RunicCLI reset
.build/debug/RunicCLI usage-enhanced

# Test with options
.build/debug/RunicCLI models --provider claude --json --pretty
.build/debug/RunicCLI projects --list
.build/debug/RunicCLI alerts --active
.build/debug/RunicCLI reset --compact
.build/debug/RunicCLI usage-enhanced --mode trending --days 30
```

### 3. Troubleshooting

#### Common Issues

**Issue: "Unknown command" error**
- Verify the command descriptor is added to the Program initialization
- Check the case statement includes the command name

**Issue: Compilation errors**
- Ensure all command files are in the correct directory
- Verify imports are correct
- Check that RunicCore exports required types

**Issue: "No such module" errors**
- Verify Package.swift includes all dependencies
- Run `swift package clean && swift build`

**Issue: Color output not working**
- Check terminal supports ANSI colors
- Use `--no-color` flag to disable colors

### 4. Optional: Add to Package.swift

If you want to build the commands as a separate module (optional):

```swift
.target(
    name: "RunicCLICommands",
    dependencies: [
        "RunicCore",
        .product(name: "Helix", package: "Helix"),
    ],
    path: "Sources/RunicCLI/Commands",
    swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
    ]),
```

Then update RunicCLI target:
```swift
.executableTarget(
    name: "RunicCLI",
    dependencies: [
        "RunicCore",
        "RunicCLICommands",  // Add this
        .product(name: "Helix", package: "Helix"),
    ],
    // ...
```

### 5. Documentation

Update the main README or CLI documentation to include:
- List of new commands
- Usage examples
- Feature descriptions
- Sample output

## Verification Checklist

- [ ] All command files are in `/Sources/RunicCLI/Commands/`
- [ ] CLIEntry.swift has been updated
- [ ] Code compiles without errors
- [ ] All commands respond to `--help`
- [ ] Commands produce correct output
- [ ] JSON output is valid
- [ ] Color output works in terminal
- [ ] Error messages are clear
- [ ] Exit codes are correct

## Next Steps

1. **Testing**: Write unit tests for each command
2. **Documentation**: Add detailed user documentation
3. **Examples**: Create example scripts showing common workflows
4. **Integration**: Consider CI/CD integration for automated testing
5. **Performance**: Profile command execution times
6. **Features**: Implement additional features as needed

## Support

For questions or issues:
1. Check the README.md in this directory
2. Review command source code
3. Check existing CLI patterns in CLIEntry.swift
4. Consult Helix documentation for argument parsing

## Notes

- All commands use async/await for data fetching
- Commands are designed to be composable (output can be piped)
- JSON output is suitable for scripting and automation
- Error handling follows CLI best practices
- Color codes are compatible with most terminal emulators
